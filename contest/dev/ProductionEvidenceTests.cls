Class Contest.ProductionEvidenceTests Extends %UnitTest.TestProduction
{
Parameter PRODUCTION = "Contest.Production";
Method TestControl() As %Status { Quit $$$OK }

Method TestMinimizedInspection()
{
    Set value={"resourceType":"Bundle","entry":[{"resource":{"resourceType":"Patient","id":"SYNTHETIC-ID","name":[{"family":"SYNTHETIC-NAME"}],"birthDate":"2001-02-03","unexpected":"SECRET-VALUE"}}]}
    Set result=##class(Contest.ProductionEvidence).Inspect(value,"fhir-r4")
    Do $$$AssertEquals(result.%Get("record_count"),1)
    Do $$$AssertEquals(result.%Get("identifier_present"),1)
    Do $$$AssertEquals(result.dates.%Get("full_date"),1,"Classify representation locally without dates in the facts")
    Do $$$AssertTrue(result.%Get("unknown_fields")>0,"Unknown fields are counted, never silently treated as absent")
    Do $$$AssertTrue(result.%ToJSON()'["SYNTHETIC-NAME","No values in minimized facts")
    Do $$$AssertTrue(result.%ToJSON()'["SECRET-VALUE","Unknown values never exported")
    Set json={"patient_id":"SYNTHETIC-ID","email":"synthetic@example.invalid","encounter":{"status":"finished"}}
    Set result=##class(Contest.ProductionEvidence).Inspect(json,"json-object")
    Do $$$AssertEquals(result.%Get("identifier_present"),1)
    Do $$$AssertTrue(result.%ToJSON()'["synthetic@example.invalid","JSON values remain local")
    For mode="array","empty","format","depth" {
        Set rejected=0, value={}, format="json-object"
        If mode="array" Set value=[]
        If mode="format" Set format="arbitrary"
        If mode="depth" {
            Set value={"encounter":{}}, child=value.encounter
            For i=1:1:20 { Set nested={} Do child.%Set("encounter",nested) Set child=nested }
        }
        Try { Set ignored=##class(Contest.ProductionEvidence).Inspect(value,format) } Catch ex { Set rejected=1 }
        Do $$$AssertTrue(rejected,mode)
    }

}

Method TestDuplicateIsolationAndFailureRecords()
    {
        If '$System.Security.Check("ContestMonitorDeploy","U") Quit
        Lock +^ContestProductionReview("worker"):2
        If '$Test Do ##class(Demo.Protocol).Fail("Review worker busy; rolled-back evidence fixture refused")
        TStart
        Try {
            Set snapshot=##class(Contest.ProductionMonitor).Snapshot("DEMO"), item=##class(Contest.ProductionMonitor).Record(snapshot.id)
            Set other=##class(Contest.ProductionMonitor).Key("UTILIZATION","Contest.Utilization.Production")
            For i=1:1:30 {
                Set row={"header_id":(900000000+i),"source":"DemoRouter","target":"UnitOnlyReceiver","session_id":900000000,"is_error":false,"status":0,"time":"unit-fixture","body_class":"Unit.Unsupported","body_id":"1","message_type":1,"corresponding_header":0}
                Do ##class(Contest.ProductionEvidence).Capture(item,row,snapshot)
            }
            Set first=##class(Contest.ProductionEvidence).Page(item.id), second=##class(Contest.ProductionEvidence).Page(item.id,first.%Get("next_before")), seen={}
            Do $$$AssertEquals(first.items.%Size(),25,"Evidence pagination bounded")
            Do $$$AssertEquals(first.%GetTypeOf("next_before"),"number","Evidence cursor has a numeric JSON type")
            For i=0:1:first.items.%Size()-1 Do seen.%Set(first.items.%Get(i).id,1)
            For i=0:1:second.items.%Size()-1 Do $$$AssertTrue('seen.%IsDefined(second.items.%Get(i).id),"Evidence pages do not overlap")
            Set original=^ContestProductionEvidence("record",item.id,900000030), before=^ContestProductionEvidence("count",item.id,"unsupported")
            Do ##class(Contest.ProductionEvidence).Capture(item,row,snapshot)
            Do $$$AssertEquals(^ContestProductionEvidence("record",item.id,900000030),original,"Repeated scan never overwrites frozen evidence")
            Do $$$AssertEquals(^ContestProductionEvidence("count",item.id,"unsupported"),before,"No duplicate counter increment")
            Set grouped=##class(Contest.ProductionEvidence).Page(other,0,"900000000")
            Do $$$AssertEquals(grouped.items.%Size(),0,"Same numeric session cannot cross Productions")
            Set value={}.%FromJSON(original)
            Do $$$AssertEquals(value.capture.state,"unsupported")
            Do $$$AssertEquals(value.%Get("delivery_evidence"),"message_header_only")
            Set value.outcome="received", ^ContestProductionEvidence("record",item.id,900000030)=value.%ToJSON(), rejected=0
            Try { Set ignored=##class(Contest.ProductionEvidence).Page(item.id) } Catch ex { Set rejected=1 }
            Do $$$AssertTrue(rejected,"Tampered observations fail explicitly")
            Set revoked=##class(Contest.ProductionEvidence).Revoke({"production_id":(item.id)})
            Do $$$AssertEquals(revoked.enabled,0,"Revocation disables future reads without deleting evidence")
        } Catch ex { TRollback 1 Lock -^ContestProductionReview("worker") Throw ex }
        TRollback 1
        Lock -^ContestProductionReview("worker")
    }

    Method TestConsentAndCaptureFailures()
    {
        If '$System.Security.Check("ContestMonitorDeploy","U") Quit
        Lock +^ContestProductionReview("worker"):2
        If '$Test Do ##class(Demo.Protocol).Fail("Review worker busy; rolled-back evidence fixture refused")
        TStart
        Try {
            Set snapshot=##class(Contest.ProductionMonitor).Snapshot("DEMO"), item=##class(Contest.ProductionMonitor).Record(snapshot.id), rejected=0
            Set body={"production_id":(item.id),"config_hash":(snapshot.%Get("config_hash")),"acknowledge_local_synthetic_inspection":false}
            Try { Set ignored=##class(Contest.ProductionEvidence).Authorize(body) } Catch ex { Set rejected=1 }
            Do $$$AssertTrue(rejected,"Enrollment does not imply payload consent")
            Do body.%Set("acknowledge_local_synthetic_inspection",1,"boolean")
            Set grant=##class(Contest.ProductionEvidence).Authorize(body)
            Do $$$AssertEquals(grant.%Get("config_hash"),snapshot.%Get("config_hash"))
            Set row={"header_id":900000100,"source":"DemoRouter","target":"UnitOnlyReceiver","session_id":900000001,"is_error":true,"status":0,"time":"unit-fixture","body_class":"Contest.StructuredRequest","body_id":"missing-unit-body","message_type":1,"corresponding_header":0}
            Do ##class(Contest.ProductionEvidence).Capture(item,row,snapshot)
            Set value={}.%FromJSON(^ContestProductionEvidence("record",item.id,900000100))
            Do $$$AssertEquals(value.capture.state,"evidence_failed","Missing persisted supported body is a visible failure")
            Do $$$AssertEquals(value.outcome,"failed","A failed header is not successful delivery")
            Do $$$AssertEquals(value.capture.%GetTypeOf("facts"),"null","A failure has no replacement facts")
            Set ignored=##class(Contest.ProductionEvidence).Revoke({"production_id":(item.id)})
            Do row.%Set("header_id",900000101)
            Do ##class(Contest.ProductionEvidence).Capture(item,row,snapshot)
            Set value={}.%FromJSON(^ContestProductionEvidence("record",item.id,900000101))
            Do $$$AssertEquals(value.capture.state,"not_authorized","Revoked body is not read or parsed")
            Do row.%Set("header_id",900000102)
            Set bad={}.%FromJSON(snapshot.%ToJSON())
            Set bad.production="Different.Production", rejected=0
            Try { Do ##class(Contest.ProductionEvidence).Capture(item,row,bad) } Catch ex { Set rejected=1 }
            Do $$$AssertTrue(rejected,"Mismatched Production snapshot is rejected")
        } Catch ex { TRollback 1 Lock -^ContestProductionReview("worker") Throw ex }
        TRollback 1
        Lock -^ContestProductionReview("worker")
    }

    Method TestIdentityAndPagination()
{
    Set a=##class(Contest.ProductionMonitor).Key("DEMO","Demo.Production"), b=##class(Contest.ProductionMonitor).Key("UTILIZATION","Contest.Utilization.Production")
    Do $$$AssertTrue(##class(Contest.ProductionEvidence).Identity(a,1)'=##class(Contest.ProductionEvidence).Identity(b,1),"Header IDs are isolated by Production")
    Set rejected=0
    Try { Set ignored=##class(Contest.ProductionEvidence).Identity(a,1.5) } Catch ex { Set rejected=1 }
    Do $$$AssertTrue(rejected,"Integer message header identity required")
    If '$System.Security.Check("ContestMonitorRead","U") Quit
    Set page=##class(Contest.ProductionEvidence).Page(a)
    Do $$$AssertEquals(page.%Get("production_id"),a)
    Do $$$AssertEquals(page.%Get("model_calls"),0)
    Do $$$AssertTrue(page.items.%Size()<=25,"Bounded evidence page")
    For i=0:1:page.items.%Size()-1 Do $$$AssertEquals(page.items.%Get(i).%Get("production_id"),a)
}

Method TestInspectionBounds()
{
    Set value={"name":[]}
    For i=1:1:1999 Do value.name.%Push("SYNTHETIC")
    Set result=##class(Contest.ProductionEvidence).Inspect(value,"json-object")
    Do $$$AssertEquals(result.%Get("identifier_present"),1,"Exactly 2000 visited nodes are accepted")
    Do value.name.%Push("SYNTHETIC")
    Set rejected=0
    Try { Set ignored=##class(Contest.ProductionEvidence).Inspect(value,"json-object") } Catch ex { Set rejected=1 }
    Do $$$AssertTrue(rejected,"2001 visited nodes fail, not silently truncate")
    Set value={"resourceType":"Bundle","entry":[]}
    For i=1:1:100 Do value.entry.%Push({"resource":{"resourceType":"Patient","id":"SYNTHETIC"}})
    Set result=##class(Contest.ProductionEvidence).Inspect(value,"fhir-r4")
    Do $$$AssertEquals(result.%Get("record_count"),100)
    Do value.entry.%Push({"resource":{"resourceType":"Patient","id":"SYNTHETIC"}})
    Set rejected=0
    Try { Set ignored=##class(Contest.ProductionEvidence).Inspect(value,"fhir-r4") } Catch ex { Set rejected=1 }
    Do $$$AssertTrue(rejected,"101 resources fail explicitly")
}
}
