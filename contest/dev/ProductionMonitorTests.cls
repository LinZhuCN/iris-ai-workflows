Class Contest.ProductionMonitorTests Extends %UnitTest.TestProduction
{
Parameter PRODUCTION = "Contest.Production";
Method TestControl() As %Status { Quit $$$OK }

Method TestProductionScopeContract()
{
    Set scope=##class(Contest.ProductionMonitor).Scope()
    Do $$$AssertEquals(scope.unit,"production")
    Do $$$AssertEquals(scope.%Get("flow_registration_required"),0,"No per-flow registration prerequisite")
    Do $$$AssertEquals(scope.%GetTypeOf("flow_registration_required"),"boolean")
    Do $$$AssertEquals(scope.%Get("component_scope"),"all_current_components")
    Do $$$AssertEquals(scope.%Get("semantic_context"),"optional_not_a_collection_filter")
    Do $$$AssertEquals(scope.%Get("path_discovery"),"observed_edges_and_session_correlation","Only runtime edges, not guessed end-to-end paths")
    Do $$$AssertEquals(scope.%Get("payload_review"),"separately_authorized_sampled_ai_review","Enrollment never grants inspection or model funding")
}

Method TestProductionIdentityAndEnrollment()
{
    If '$System.Security.Check("ContestMonitorDeploy","U") Quit
    Set one=##class(Contest.ProductionMonitor).Snapshot("DEMO"), two=##class(Contest.ProductionMonitor).Snapshot("UTILIZATION")
    Do $$$AssertTrue(one.running&&two.running,"Use two actual active Productions")
    Do $$$AssertTrue(one.id'=two.id,"Namespace and Production are the observation identity")
    Do $$$AssertEquals(one.id,##class(Contest.ProductionMonitor).Key("DEMO",one.production))
    Do $$$AssertTrue(one.nodes.%Size()>0,"Actual component catalog")
    TStart
    Try {
        Set wrong={"namespace":"DEMO","production":(one.production),"config_hash":"wrong","acknowledge_monitoring":true}, rejected=0
        Try { Set ignored=##class(Contest.ProductionMonitor).Enroll(wrong) } Catch ex { Set rejected=1 }
        Do $$$AssertTrue(rejected,"Stale configuration enrollment is rejected")
        Set body={"namespace":"DEMO","production":(one.production),"config_hash":(one.%Get("config_hash")),"acknowledge_monitoring":false}, rejected=0
        Try { Set ignored=##class(Contest.ProductionMonitor).Enroll(body) } Catch ex { Set rejected=1 }
        Do $$$AssertTrue(rejected,"Discovery never enrolls automatically")
        Do body.%Set("acknowledge_monitoring",1,"boolean")
        Set first=##class(Contest.ProductionMonitor).Enroll(body), repeat=##class(Contest.ProductionMonitor).Enroll(body)
        Do $$$AssertEquals(first.id,repeat.id,"Repeated enrollment uses one managed object")
        Do $$$AssertEquals(first.%Get("enrolled_at"),repeat.%Get("enrolled_at"),"No cursor reset on duplicate enrollment")
        Do $$$AssertEquals(first.%Get("model_calls"),0)
        Set contextsBefore=$Data(^ContestProductionFlow("production",first.id))
        Set detail=##class(Contest.ProductionMonitor).Detail(first.id)
        Do $$$AssertEquals(detail.%Get("monitoring_scope").unit,"production")
        Do $$$AssertEquals(detail.%Get("monitoring_scope").%Get("flow_registration_required"),0)
        Do $$$AssertEquals($Data(^ContestProductionFlow("production",first.id)),contextsBefore,"Enrollment and detail do not create required flow registrations")
        Set second=##class(Contest.ProductionMonitor).Enroll({"namespace":"UTILIZATION","production":(two.production),"config_hash":(two.%Get("config_hash")),"acknowledge_monitoring":true})
        Do $$$AssertTrue(first.id'=second.id,"Independent enrollment")
        Do ##class(Contest.ProductionMonitor).Emit(first.id,"unit","coverage_gap","info","Synthetic isolation fixture",{})
        Set page=##class(Contest.ProductionMonitor).Events(second.id)
        For i=0:1:page.items.%Size()-1 Do $$$AssertTrue(page.items.%Get(i).%Get("source_key")'="unit","Events never leak across managed Productions")
        Set paused=##class(Contest.ProductionMonitor).Manage({"id":(first.id),"revision":(first.revision),"enabled":false})
        Do $$$AssertEquals(paused.enabled,0,"Pausing observer does not stop the business Production")
        Do $$$AssertEquals(paused.%GetTypeOf("enabled"),"boolean","Paused state retains JSON boolean type")
        Set current=##class(Contest.ProductionMonitor).Snapshot("DEMO")
        Do $$$AssertTrue(current.running,"Business Production remains running")
        Set rejected=0
        Try { Set ignored=##class(Contest.ProductionMonitor).Manage({"id":(first.id),"revision":(first.revision),"enabled":true}) } Catch ex { Set rejected=1 }
        Do $$$AssertTrue(rejected,"Stale management revision rejected")
    } Catch ex { TRollback 1 Throw ex }
    TRollback 1
}

Method TestEventIdentityAndNotes()
{
    If '$System.Security.Check("ContestMonitorDeploy","U") Quit
    TStart
    Try {
        Set snapshot=##class(Contest.ProductionMonitor).Snapshot("DEMO"), item=##class(Contest.ProductionMonitor).Enroll({"namespace":"DEMO","production":(snapshot.production),"config_hash":(snapshot.%Get("config_hash")),"acknowledge_monitoring":true})
        Do ##class(Contest.ProductionMonitor).Emit(item.id,"unit-action","configuration_change","warning","Synthetic fixture only",{"basis":"test"})
        Do ##class(Contest.ProductionMonitor).Emit(item.id,"unit-action","configuration_change","warning","Synthetic fixture only",{"basis":"test"})
        Set event=##class(Contest.ProductionMonitor).Event(item.id,"unit-action")
        Set result=##class(Contest.ProductionMonitor).Action({"production_id":(item.id),"source_key":"unit-action","revision":1,"action":"in_review","text":"Review configuration change"})
        Do $$$AssertEquals(result.revision,2)
        Do $$$AssertEquals(result.actions.%Size(),1)
        Set rejected=0
        Try { Set ignored=##class(Contest.ProductionMonitor).Action({"production_id":(item.id),"source_key":"unit-action","revision":1,"action":"resolved","text":"Stale"}) } Catch ex { Set rejected=1 }
        Do $$$AssertTrue(rejected,"Stale event action rejected")
        Do $$$AssertEquals(result.%Get("production_id"),item.id)
    } Catch ex { TRollback 1 Throw ex }
    TRollback 1
}

Method TestDiscoveryAndReviewIsolation()
{
    If '$System.Security.Check("ContestMonitorDeploy","U") Quit
    Set discovered=##class(Contest.ProductionMonitor).Discover(), seen={}
    Do $$$AssertEquals(discovered.%Get("model_calls"),0)
    Do $$$AssertTrue(discovered.items.%Size()>=2,"Discover multiple actual running Productions")
    For i=0:1:discovered.items.%Size()-1 {
        Set item=discovered.items.%Get(i)
        Do $$$AssertTrue(item.running,"Only active Productions are selectable")
        Do $$$AssertTrue('seen.%IsDefined(item.id),"Unique instance/namespace/Production identity")
        Do seen.%Set(item.id,1)
    }
    TStart
    Try {
        For ns="DEMO","UTILIZATION" {
            Set snapshot=##class(Contest.ProductionMonitor).Snapshot(ns), item=##class(Contest.ProductionMonitor).Enroll({"namespace":(ns),"production":(snapshot.production),"config_hash":(snapshot.%Get("config_hash")),"acknowledge_monitoring":true}), risks=##class(Contest.ProductionMonitor).Risks(item.id)
            Do $$$AssertEquals(risks.%Get("general_payload_assessment"),0,"No generic HIPAA verdict from metadata")
            For i=0:1:risks.items.%Size()-1 {
                Set review=risks.items.%Get(i)
                If ns="DEMO" Do $$$AssertEquals(review.source,"demo_observation","Other Production review adapter cannot leak into DEMO")
                If ns="UTILIZATION" Do $$$AssertTrue(review.source'="demo_observation","DEMO risk/event cannot leak into UTILIZATION")
            }
        }
    } Catch ex { TRollback 1 Throw ex }
    TRollback 1
}

Method TestEventPaginationAndDuplicateCapture()
{
    If '$System.Security.Check("ContestMonitorDeploy","U") Quit
    TStart
    Try {
        Set snapshot=##class(Contest.ProductionMonitor).Snapshot("DEMO"), item=##class(Contest.ProductionMonitor).Enroll({"namespace":"DEMO","production":(snapshot.production),"config_hash":(snapshot.%Get("config_hash")),"acknowledge_monitoring":true})
        For i=1:1:30 Do ##class(Contest.ProductionMonitor).Emit(item.id,"unit-page-"_i,"message_observed","info","Synthetic metadata fixture",{"header_id":(i)})
        Set first=##class(Contest.ProductionMonitor).Events(item.id)
        Do $$$AssertEquals(first.items.%Size(),25,"Bounded first page")
        Do $$$AssertTrue(first.%Get("next_before")>0,"Older cursor required")
        Do $$$AssertEquals(first.%GetTypeOf("next_before"),"number","Nonempty cursors must match the browser/API numeric contract")
        Set second=##class(Contest.ProductionMonitor).Events(item.id,first.%Get("next_before")), keys={}
        For i=0:1:first.items.%Size()-1 Do keys.%Set(first.items.%Get(i).%Get("source_key"),1)
        For i=0:1:second.items.%Size()-1 Do $$$AssertTrue('keys.%IsDefined(second.items.%Get(i).%Get("source_key")),"Pages do not duplicate events")
        Set original=##class(Contest.ProductionMonitor).Event(item.id,"unit-page-30")
        Do ##class(Contest.ProductionMonitor).Emit(item.id,"unit-page-30","message_error","warning","Do not overwrite captured event",{})
        Set again=##class(Contest.ProductionMonitor).Event(item.id,"unit-page-30")
        Do $$$AssertEquals(original.%ToJSON(),again.%ToJSON(),"Repeated scans cannot overwrite or duplicate source event")
    } Catch ex { TRollback 1 Throw ex }
    TRollback 1
}
}
