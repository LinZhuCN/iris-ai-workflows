Class Contest.Utilization.Runtime
{
ClassMethod Prepared(record As %DynamicObject, request As Contest.Aggregation.SendRequest)
{
    If (record.state'="prepared")||(record.bundle.%ToJSON()'=request.Bundle)||(record.%Get("approval_id")'=request.ApprovalId)||(record.%Get("scope_hash")'=request.ScopeHash) Do ##class(Demo.Protocol).Fail("Prepared utilization scope conflict or replay")
    If record.%Get("source_hash")'=##class(Contest.Aggregation.Runtime).Digest(record.source) Do ##class(Demo.Protocol).Fail("Frozen utilization source integrity mismatch")
    Set expected=..Project(record.source)
    If expected.%ToJSON()'=request.Bundle Do ##class(Demo.Protocol).Fail("Utilization output differs from frozen source projection")
}

ClassMethod Project(rows As %DynamicArray) As %DynamicObject
{
    If '$IsObject(rows) Do ##class(Demo.Protocol).Fail("FHIR source array required")
    If 'rows.%IsA("%DynamicArray") Do ##class(Demo.Protocol).Fail("FHIR source array required")
    If rows.%Size()'=4 Do ##class(Demo.Protocol).Fail("Four-resource fixed utilization cohort required")
    Set bundle={"resourceType":"Bundle","type":"collection","entry":[]}
    For i=0:1:3 {
        Set row=rows.%Get(i), expectedType=$Select(i<2:"Patient",1:"Encounter"), expectedId=$Select(i=0:"agg-p1",i=1:"agg-p2",i=2:"agg-e1",1:"agg-e2")
        If (row.resourceType'=expectedType)||(row.id'=expectedId) Do ##class(Demo.Protocol).Fail("Unexpected FHIR source identity or order")
        If i<2 {
            Do ##class(Contest.Aggregation.Mapping).Date(row.birthDate)
            Set resource={"resourceType":"Patient","id":(row.id),"birthDate":($Extract(row.birthDate,1,4))}
        } Else {
            Set patient=$Select(i=2:"Patient/agg-p1",1:"Patient/agg-p2")
            If (row.subject.reference'=patient)||(row.status'="finished")||(row.class.code'="AMB")||(row.class.system'="http://terminology.hl7.org/CodeSystem/v3-ActCode") Do ##class(Demo.Protocol).Fail("Unexpected utilization encounter reference or classification")
            Set resource={"resourceType":"Encounter","id":(row.id),"status":(row.status),"class":{"system":(row.class.system),"code":(row.class.code)},"subject":{"reference":(patient)}}
        }
        Do bundle.entry.%Push({"resource":(resource)})
    }
    Quit bundle
}

ClassMethod Config() As %DynamicObject
{
    If $Namespace'="UTILIZATION" Do ##class(Demo.Protocol).Fail("UTILIZATION runtime required")
    Set production=##class(Ens.Config.Production).%OpenId("Contest.Utilization.Production")
    If '$IsObject(production) Do ##class(Demo.Protocol).Fail("Utilization Production not installed")
    Set items=[]
    For i=1:1:production.Items.Count() {
        Set item=production.Items.GetAt(i), settings=[]
        For j=1:1:item.Settings.Count() {
            Set setting=item.Settings.GetAt(j)
            Do settings.%Push({"target":(setting.Target),"name":(setting.Name),"value":(setting.Value)})
        }
        Do items.%Push({"name":(item.Name),"class":(item.ClassName),"enabled":(item.Enabled),"pool_size":(item.PoolSize),"settings":(settings)})
    }
    Quit {"namespace":"UTILIZATION","production":"Contest.Utilization.Production","items":(items),"source_endpoint":"gateway:80/csp/healthshare/fhirdemo/fhir/r4","read_identity":"ContestAggregationFHIR","cohort":"synthetic-four-resources-v1","projection":"utilization-year-and-encounter-v1","recipient":"local-analysis-receiver","receiver_table":"SQLUser.UtilizationReceipt","collector":"utilization-receipt-v1"}
}

ClassMethod Binding() As %DynamicObject
{
    Quit {"instance_id":"local-triage-real","namespace":"UTILIZATION","production":"Contest.Utilization.Production","source":"FHIRSource","sender":"AnalysisReceiver","point":"before_send","config_hash":(##class(Contest.Aggregation.Runtime).Digest(..Config())),"collector_version":"utilization-receipt-v1","policy_version":"utilization-exact-scope-v1"}
}

ClassMethod Approval(id As %String, digest As %String, batch As %String = "") As %DynamicObject
{
    If $Extract(id,1,16)="declaration-run-" Quit ##class(Contest.Utilization.DeclarationBridge).Approval(id,digest,batch,.key)
    Set binding=..Binding(), previous=$Namespace
    Try {
        Set $Namespace="TRIAGE"
        Set status=##class(Contest.RouteGovernance).Check(id,binding,digest)
        If status.state'="approved_scope" Do ##class(Demo.Protocol).Fail("Utilization approval is not applicable: "_status.state)
        Set dossier=##class(Contest.RouteGovernance).Read(id)
        If '$IsObject(dossier.approval.%Get("scenario")) Do ##class(Demo.Protocol).Fail("Approved internal organization scenario required")
    } Catch ex { Set $Namespace=previous Throw ex }
    Set $Namespace=previous, declaration=dossier.core.declaration
    If (declaration.kind'="utilization")||(declaration.%Get("purpose_code")'="internal-quality-improvement")||(declaration.recipient'="local-analysis-receiver")||(declaration.%Get("service_identity")'="local-utilization-service")||(declaration.scope.%Get("patient_selection")'="synthetic-four-resources-v1") Do ##class(Demo.Protocol).Fail("Approval does not cover the internal quality-improvement task")
    Quit dossier
}

ClassMethod Bucket(id As %String) As %String
{
    Quit $Select($Extract(id,1,16)="declaration-run-":"declarationBatch",1:"batch")
}

ClassMethod Source(Output pins As %DynamicArray) As %DynamicArray
{
    Set rows=[], pins=[]
    For path="Patient/agg-p1","Patient/agg-p2","Encounter/agg-e1","Encounter/agg-e2" {
        Set row=##class(Contest.Aggregation.Runtime).Http(path)
        If row.resourceType_"/"_row.id'=path Do ##class(Demo.Protocol).Fail("FHIR GET identity mismatch")
        Do rows.%Push(row), pins.%Push({"resource":(path),"version":(row.meta.versionId),"hash":(##class(Contest.Aggregation.Runtime).Digest(row))})
    }
    Quit rows
}

ClassMethod EnsureReceiver()
{
    If $Namespace'="UTILIZATION" Do ##class(Demo.Protocol).Fail("UTILIZATION receiver required")
    Set result=##class(%SQL.Statement).%ExecDirect(,"SELECT COUNT(*) AS N FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA='SQLUser' AND TABLE_NAME='UtilizationReceipt'")
    Do ##class(Contest.Aggregation.Data).Check(result)
    Set next=result.%Next()
    If result.%Get("N")=0 {
        Set result=##class(%SQL.Statement).%ExecDirect(,"CREATE TABLE SQLUser.UtilizationReceipt (BatchID VARCHAR(64) PRIMARY KEY, ScopeHash VARCHAR(64) NOT NULL, OutputHash VARCHAR(64) NOT NULL, Payload VARCHAR(100000) NOT NULL, ReceivedAt VARCHAR(40) NOT NULL)")
        Do ##class(Contest.Aggregation.Data).Check(result)
    }
}

ClassMethod ReadReceiver(batch As %String) As %DynamicObject
{
    If $Namespace'="UTILIZATION" Do ##class(Demo.Protocol).Fail("UTILIZATION receiver required")
    If '$Match(batch,"^[A-Za-z0-9-]{1,64}$") Do ##class(Demo.Protocol).Fail("Bounded batch identity required")
    Set result=##class(%SQL.Statement).%ExecDirect(,"SELECT ScopeHash,OutputHash,Payload,ReceivedAt FROM SQLUser.UtilizationReceipt WHERE BatchID=?",batch)
    Do ##class(Contest.Aggregation.Data).Check(result)
    If 'result.%Next() Do ##class(Demo.Protocol).Fail("Downstream receipt missing")
    Set payload={}.%FromJSON(result.%Get("Payload")), hash=##class(Contest.Aggregation.Runtime).Digest(payload)
    If hash'=result.%Get("OutputHash") Do ##class(Demo.Protocol).Fail("Downstream payload integrity mismatch")
    Quit {"batch_id":(batch),"scope_hash":(result.%Get("ScopeHash")),"output_hash":(hash),"payload":(payload),"received_at":(result.%Get("ReceivedAt"))}
}
}
