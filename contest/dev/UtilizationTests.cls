Class Contest.UtilizationTests Extends %UnitTest.TestProduction
{
Parameter PRODUCTION = "Contest.Production";
Method TestControl() As %Status { Quit $$$OK }

Method Sources() As %DynamicArray
{
    Set bundle=##class(Contest.Aggregation.Mapping).Build(##class(Contest.Aggregation.Data).Fixture()), rows=[]
    For i=0:1:3 Do rows.%Push(bundle.entry.%Get(i).resource)
    Quit rows
}

Method TestProjectionUsesActualValues()
{
    Set rows=..Sources(), bundle=##class(Contest.Utilization.Runtime).Project(rows)
    Do $$$AssertEquals(bundle.entry.%Size(),4)
    Set patient=bundle.entry.%Get(0).resource
    Do $$$AssertEquals(patient.birthDate,"1980")
    Do $$$AssertTrue('patient.%IsDefined("identifier"))
    Do $$$AssertTrue('patient.%IsDefined("name"))
    Do $$$AssertEquals(bundle.entry.%Get(2).resource.subject.reference,"Patient/agg-p1")
    Set rows.%Get(0).birthDate="1975-02-03"
    Set changed=##class(Contest.Utilization.Runtime).Project(rows)
    Do $$$AssertEquals(changed.entry.%Get(0).resource.birthDate,"1975")
}

Method TestInvalidCohortFails()
{
    For variant="empty","date","identity","reference","type" {
        Set rows=..Sources(), rejected=0
        If variant="empty" Set rows=[]
        If variant="date" Set rows.%Get(0).birthDate="1980-02-31"
        If variant="identity" Set rows.%Get(0).id="other"
        If variant="reference" Set rows.%Get(2).subject.reference="Patient/other"
        If variant="type" Set rows.%Get(0).resourceType="Observation"
        Try { Set bundle=##class(Contest.Utilization.Runtime).Project(rows) } Catch ex { Set rejected=(ex.DisplayString()'["CLASS DOES NOT EXIST") }
        Do $$$AssertTrue(rejected,variant)
    }
}

Method TestActualProjectedFieldsCannotExpand()
{
    Set bundle=##class(Contest.Utilization.Runtime).Project(..Sources())
    Set dossier={"core":{"declaration":{"scope":{"resources":["Patient","Encounter"],"fields":["Patient.id","Patient.birthDate","Encounter.id","Encounter.status","Encounter.class.system","Encounter.class.code","Encounter.subject.reference"],"max_records":4}}}}
    Set check=##class(Contest.Aggregation.Runtime).Inspect(bundle,dossier)
    Do $$$AssertEquals(check.%Get("resource_counts").Patient,2)
    For variant="field","limit","resource" {
        Set changed={}.%FromJSON(bundle.%ToJSON()), approval={}.%FromJSON(dossier.%ToJSON()), rejected=0
        If variant="field" Set changed.entry.%Get(0).resource.name=[{"family":"SYNTHETIC"}]
        If variant="limit" Do approval.core.declaration.scope.%Set("max_records",3)
        If variant="resource" Set approval.core.declaration.scope.resources=["Patient"]
        Try { Set check=##class(Contest.Aggregation.Runtime).Inspect(changed,approval) } Catch ex { Set rejected=1 }
        Do $$$AssertTrue(rejected,variant)
    }
}

Method TestDurableReceiverReadAndGuards()
{
    If '$System.Security.Check("ContestMonitorDeploy","U") Quit
    Set previous=$Namespace, source=..Sources()
    TStart
    Try {
        Set $Namespace="UTILIZATION", batch="unit-util-"_$System.Util.CreateGUID()
        Set bundle=##class(Contest.Utilization.Runtime).Project(source), hash=##class(Contest.Aggregation.Runtime).Digest(bundle), digest=$Translate($Justify("",64)," ","a")
        Set result=##class(%SQL.Statement).%ExecDirect(,"INSERT INTO SQLUser.UtilizationReceipt (BatchID,ScopeHash,OutputHash,Payload,ReceivedAt) VALUES (?,?,?,?,?)",batch,digest,hash,bundle.%ToJSON(),##class(Demo.Protocol).Now())
        Do ##class(Contest.Aggregation.Data).Check(result)
        Set read=##class(Contest.Utilization.Runtime).ReadReceiver(batch)
        Do $$$AssertEquals(read.payload.%ToJSON(),bundle.%ToJSON())
        Set result=##class(%SQL.Statement).%ExecDirect(,"UPDATE SQLUser.UtilizationReceipt SET OutputHash=? WHERE BatchID=?","modified",batch)
        Do ##class(Contest.Aggregation.Data).Check(result)
        Set rejected=0
        Try { Set read=##class(Contest.Utilization.Runtime).ReadReceiver(batch) } Catch ex { Set rejected=1 }
        Do $$$AssertTrue(rejected,"Tampered SQL payload metadata is rejected")
        Set ref={}.%FromJSON(^ContestUtilization("registration")), rejected=0
        Try { Set value=##class(Contest.Utilization.Runtime).Approval(ref.id,digest) } Catch ex { Set rejected=1 }
        Do $$$AssertTrue(rejected,"Wrong intended scope cannot reuse registered approval")
    } Catch ex { TRollback 1 Set $Namespace=previous Throw ex }
    TRollback 1
    Set $Namespace=previous
}

Method TestPreparedSendCannotReplayOrChange()
{
    Set source=..Sources(), bundle=##class(Contest.Utilization.Runtime).Project(source), request=##class(Contest.Aggregation.SendRequest).%New()
    Set request.Bundle=bundle.%ToJSON(), request.ApprovalId="route-unit", request.ScopeHash="unit"
    Set record={"state":"prepared","source":(source),"source_hash":(##class(Contest.Aggregation.Runtime).Digest(source)),"bundle":(bundle),"approval_id":"route-unit","scope_hash":"unit"}
    Do ##class(Contest.Utilization.Runtime).Prepared(record,request)
    For variant="state","scope","source","output" {
        Set changed={}.%FromJSON(record.%ToJSON()), rejected=0
        If variant="state" Set changed.state="delivered"
        If variant="scope" Do changed.%Set("scope_hash","different")
        If variant="source" Set changed.source.%Get(0).birthDate="1970-01-01"
        If variant="output" Set changed.bundle.entry.%Get(0).resource.birthDate="1970"
        Try { Do ##class(Contest.Utilization.Runtime).Prepared(changed,request) } Catch ex { Set rejected=1 }
        Do $$$AssertTrue(rejected,variant)
    }
}
}
