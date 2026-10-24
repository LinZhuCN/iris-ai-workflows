Class Contest.RouteReviewTests Extends %UnitTest.TestProduction
{
Parameter PRODUCTION = "Contest.Production";
Method TestControl() As %Status { Quit $$$OK }

Method BeginFixture()
{
    Lock +^ContestRouteReview("worker"):10
    If '$Test Do ##class(Demo.Protocol).Fail("Automatic worker is active; run free fixture tests after it finishes")
    TStart
}

Method EndFixture()
{
    TRollback 1
    Lock -^ContestRouteReview("worker")
}

Method TestUnprivilegedReadIsDenied()
{
    If $System.Security.Check("ContestMonitorRead","U") {
        Do $$$AssertTrue($IsObject(##class(Contest.RouteReview).List()))
    } Else {
        Set rejected=0
        Try { Set value=##class(Contest.RouteReview).List() } Catch ex { Set rejected=(ex.DisplayString()["Route review capability required") }
        Do $$$AssertTrue(rejected)
    }
}

Method TestAutomaticCaptureIsIdempotentAndBudgetBlocked()
{
    If '$System.Security.Check("ContestMonitorDeploy","U") Quit
    Do ..BeginFixture()
    Try {
        Set key="utilization-utilization-quality-demo"
        Kill ^ContestRouteReview("review",key), ^ContestRouteReview("allow",key)
        Do ##class(Contest.RouteReview).Capture("utilization","utilization-quality-demo")
        Set first={}.%FromJSON(^ContestRouteReview("review",key))
        Do $$$AssertEquals(first.state,"blocked_budget")
        Do $$$AssertEquals(first.origin,"automatic_after_send")
        Do $$$AssertEquals(first.evidence.packet.stage,"after_send")
        Do $$$AssertEquals(first.evidence.packet.facts.%Size(),8)
        Do $$$AssertEquals(first.%Get("runtime_version"),"staged-risk-v4","Unfunded captures must not masquerade as the old reviewer")
        Do $$$AssertTrue('first.%IsDefined("report"))
        Do ##class(Contest.RouteReview).Capture("utilization","utilization-quality-demo")
        Do $$$AssertEquals(^ContestRouteReview("review",key),first.%ToJSON())
        Do $$$AssertTrue('##class(Contest.RouteReview).Reserve(key,first))
        Do $$$AssertEquals(first.state,"blocked_budget")
        Set listed=##class(Contest.RouteReview).List(), found=0
        For i=0:1:listed.items.%Size()-1 {
            If listed.items.%Get(i).id=key Set found=1
        }
        Do $$$AssertTrue(found,"Registry list serializes nested event objects")
    } Catch ex { Do ..EndFixture() Throw ex }
    Do ..EndFixture()
}

Method TestBudgetReservationCannotBeRepeated()
{
    If '$System.Security.Check("ContestMonitorDeploy","U") Quit
    Do ..BeginFixture()
    Try {
        Set key="unit-reservation", item={"state":"blocked_budget","receipt_hash":"pin"}
        Set ^ContestRouteReview("allow",key)={"receipt_hash":"pin","reserved":false}.%ToJSON()
        Do $$$AssertTrue(##class(Contest.RouteReview).Reserve(key,item))
        Do $$$AssertEquals(item.state,"running")
        Do $$$AssertEquals(item.%Get("reserved_model_requests"),2)
        Do $$$AssertTrue('##class(Contest.RouteReview).Reserve(key,item))
        Set grant={}.%FromJSON(^ContestRouteReview("allow",key))
        Do $$$AssertTrue(grant.reserved)
        Set item.state="failed"
        Do $$$AssertTrue('##class(Contest.RouteReview).Reserve(key,item))
    } Catch ex { Do ..EndFixture() Throw ex }
    Do ..EndFixture()
}

Method TestWrongPinDoesNotConsumeBudget()
{
    If '$System.Security.Check("ContestMonitorDeploy","U") Quit
    Do ..BeginFixture()
    Try {
        Set key="unit-pin", item={"state":"blocked_budget","receipt_hash":"actual"}
        Set ^ContestRouteReview("allow",key)={"receipt_hash":"different","reserved":false}.%ToJSON(), rejected=0
        Try { Set value=##class(Contest.RouteReview).Reserve(key,item) } Catch ex { Set rejected=(ex.DisplayString()["Authorized receipt changed") }
        Do $$$AssertTrue(rejected)
        Set grant={}.%FromJSON(^ContestRouteReview("allow",key))
        Do $$$AssertTrue('grant.reserved)
    } Catch ex { Do ..EndFixture() Throw ex }
    Do ..EndFixture()
}

Method TestMissingEvidenceIsTechnicalNotPrivacyFinding()
{
    If '$System.Security.Check("ContestMonitorDeploy","U") Quit
    Do ..BeginFixture()
    Try {
        Do ##class(Contest.RouteReview).Capture("utilization","unit-missing-batch")
        Set item={}.%FromJSON(^ContestRouteReview("review","utilization-unit-missing-batch"))
        Do $$$AssertEquals(item.state,"evidence_failed")
        Do $$$AssertTrue('item.%IsDefined("result"))
        Do $$$AssertEquals(item.event.category,"technical_failure")
    } Catch ex { Do ..EndFixture() Throw ex }
    Do ..EndFixture()
}

Method TestHumanActionRequiresExactRevisionAndDoesNotExecute()
{
    If '$System.Security.Check("ContestMonitorDeploy","U") Quit
    Do ..BeginFixture()
    Try {
        Set key="unit-action", event={"state":"open","revision":1,"category":"unresolved","actions":[]}
        Set ^ContestRouteReview("review",key)={"id":(key),"state":"completed","event":(event)}.%ToJSON()
        Set value=##class(Contest.RouteReview).Action({"id":(key),"revision":1,"action":"in_review","text":"Synthetic human triage"})
        Do $$$AssertEquals(value.event.state,"in_review")
        Do $$$AssertEquals(value.event.revision,2)
        Do $$$AssertEquals(value.event.actions.%Get(0).actor,$Username)
        Set rejected=0
        Try { Set value=##class(Contest.RouteReview).Action({"id":(key),"revision":1,"action":"resolved","text":"Stale"}) } Catch ex { Set rejected=(ex.DisplayString()["revision conflict") }
        Do $$$AssertTrue(rejected)
        Set rejected=0
        Try { Set value=##class(Contest.RouteReview).Action({"id":(key),"revision":2,"action":"deliver","text":"Must not execute"}) } Catch ex { Set rejected=(ex.DisplayString()["transition") }
        Do $$$AssertTrue(rejected)
    } Catch ex { Do ..EndFixture() Throw ex }
    Do ..EndFixture()
}

Method TestScanDiscoversAnUnseenCompletedBatchWithoutManualIntake()
{
    If '$System.Security.Check("ContestMonitorDeploy","U") Quit
    Do ..BeginFixture()
    Try {
        Set batch="unit-new-after-send", key="utilization-"_batch
        Set source={}.%FromJSON(^|"UTILIZATION"|ContestUtilization("batch","utilization-quality-demo"))
        Do source.%Set("batch_id",batch)
        Set ^|"UTILIZATION"|ContestUtilization("batch",batch)=source.%ToJSON()
        Do $$$AssertTrue('$Data(^ContestRouteReview("review",key)))
        Do ##class(Contest.RouteReview).Scan()
        Set item={}.%FromJSON(^ContestRouteReview("review",key))
        Do $$$AssertEquals(item.origin,"automatic_after_send")
        Do $$$AssertEquals(item.state,"evidence_failed")
        Do $$$AssertEquals(item.%Get("reserved_model_requests"),0)
        Do $$$AssertTrue('item.%IsDefined("result"),"Unverifiable cloned receipt is never a verdict")
    } Catch ex { Do ..EndFixture() Throw ex }
    Do ..EndFixture()
}

Method TestInterruptedWorkerCannotReplayConsumedGrant()
{
    If '$System.Security.Check("ContestMonitorDeploy","U") Quit
    Do ..BeginFixture()
    Try {
        Set key=""
        For {
            Set key=$Order(^ContestRouteReview("allow",key))
            If key="" Quit
            Set grant={}.%FromJSON(^ContestRouteReview("allow",key))
            If 'grant.reserved Do ##class(Demo.Protocol).Fail("Run interruption fixtures only after authorized work finishes")
        }
        Set key="unit-interrupted"
        Set ^ContestRouteReview("enabled")=1
        Set ^ContestRouteReview("allow",key)={"reserved":true,"receipt_hash":"unit"}.%ToJSON()
        Set ^ContestRouteReview("review",key)={"id":(key),"state":"running","reserved_model_requests":2,"event":{"category":"coverage_gap","state":"open","revision":1,"actions":[]}}.%ToJSON()
        Do ##class(Contest.RouteReview).Pump()
        Set item={}.%FromJSON(^ContestRouteReview("review",key))
        Do $$$AssertEquals(item.state,"interrupted")
        Do $$$AssertEquals(item.event.category,"technical_failure")
        Do $$$AssertTrue('item.%IsDefined("result"))
        Do $$$AssertEquals($Get(^ContestRiskReview("request","route-"_key)),"")
        Do ##class(Contest.RouteReview).Pump()
        Do $$$AssertEquals(^ContestRouteReview("review",key),item.%ToJSON())
    } Catch ex { Do ..EndFixture() Throw ex }
    Do ..EndFixture()
}

Method AcceptanceTargets() As %DynamicArray
{
    Set targets=[]
    For kind="aggregation","utilization" {
        Set batch=$Select(kind="aggregation":"aggregation-internal-demo",1:"utilization-quality-demo"), key=kind_"-"_batch
        Do targets.%Push({"kind":(kind),"batch":(batch),"receipt_hash":(^ContestRouteReview("pin",key))})
    }
    Do targets.%Push({"kind":"utilization","batch":"unit-acceptance-new","receipt_hash":""})
    Quit targets
}

Method TestAcceptanceIsNewIdentityAndNeverResetsOldBudget()
{
    If '$System.Security.Check("ContestMonitorDeploy","U") Quit
    Do ..BeginFixture()
    Try {
        If '$Data(^ContestRouteReview("allow","aggregation-aggregation-internal-demo")) {
            Set ^ContestRouteReview("allow","aggregation-aggregation-internal-demo")={"receipt_hash":(^ContestRouteReview("pin","aggregation-aggregation-internal-demo")),"reserved":true,"max_model_requests":2}.%ToJSON()
        }
        Set old=^ContestRouteReview("allow","aggregation-aggregation-internal-demo"), original=^ContestRouteReview("review","aggregation-aggregation-internal-demo")
        Set targets=..AcceptanceTargets()
        Do ##class(Contest.RouteReview).AuthorizeAcceptance("unit-v4",targets)
        Set key="aggregation-aggregation-internal-demo-unit-v4", grant={}.%FromJSON(^ContestRouteReview("allow",key))
        Do $$$AssertEquals(grant.%Get("max_model_requests"),2)
        Do $$$AssertEquals(grant.%Get("runtime_version"),"staged-risk-v4")
        Do $$$AssertTrue('grant.reserved)
        Set grant.reserved=1, ^ContestRouteReview("allow",key)=grant.%ToJSON()
        Do ##class(Contest.RouteReview).AuthorizeAcceptance("unit-v4",targets)
        Do $$$AssertEquals(^ContestRouteReview("allow",key),grant.%ToJSON())
        Do $$$AssertEquals(^ContestRouteReview("allow","aggregation-aggregation-internal-demo"),old)
        Do $$$AssertEquals(^ContestRouteReview("review","aggregation-aggregation-internal-demo"),original)
        Do $$$AssertTrue('$Data(^ContestRouteReview("review","utilization-unit-acceptance-new")),"New batch must be discovered only after real delivery")
        Set targets.%Get(2).batch="unit-different", rejected=0
        Try { Do ##class(Contest.RouteReview).AuthorizeAcceptance("unit-v4",targets) } Catch ex { Set rejected=1 }
        Do $$$AssertTrue(rejected,"Cannot substitute another batch under the same authorization")
    } Catch ex { Do ..EndFixture() Throw ex }
    Do ..EndFixture()
}

Method TestNewBatchGrantRequiresExpectedApprovalAndConfig()
{
    If '$System.Security.Check("ContestMonitorDeploy","U") Quit
    Do ..BeginFixture()
    Try {
        Set key="unit-fresh-guard", item={"state":"blocked_budget","receipt_hash":"actual","evidence":{"approved":{"record_id":"other","scope_hash":"wrong"},"provenance":{"config_hash":"wrong"}}}
        Set ^ContestRouteReview("allow",key)={"receipt_hash":"","mode":"new_batch","reserved":false,"expected_approval":"approved","expected_scope":"scope","expected_config":"config"}.%ToJSON(), rejected=0
        Try { Set reserved=##class(Contest.RouteReview).Reserve(key,item) } Catch ex { Set rejected=1 }
        Do $$$AssertTrue(rejected)
        Set grant={}.%FromJSON(^ContestRouteReview("allow",key))
        Do $$$AssertTrue('grant.reserved)
        Do item.evidence.approved.%Set("record_id","approved")
        Do item.evidence.approved.%Set("scope_hash","scope"), item.evidence.provenance.%Set("config_hash","config")
        Do $$$AssertTrue(##class(Contest.RouteReview).Reserve(key,item))
        Set grant={}.%FromJSON(^ContestRouteReview("allow",key))
        Do $$$AssertEquals(grant.%Get("receipt_hash"),"actual")
    } Catch ex { Do ..EndFixture() Throw ex }
    Do ..EndFixture()
}
}
