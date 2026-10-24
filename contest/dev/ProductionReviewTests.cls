Class Contest.ProductionReviewTests Extends %UnitTest.TestProduction
{
Parameter PRODUCTION = "Contest.Production";
Method TestControl() As %Status { Quit $$$OK }

Method Observation() As %DynamicObject
{
    Set pid=##class(Contest.ProductionMonitor).Key("OBSERVATION","Contest.StructuredProduction")
    Set value={"id":(##class(Contest.ProductionEvidence).Identity(pid,900001001)),"production_id":(pid),"namespace":"OBSERVATION","production":"Contest.StructuredProduction","observed_config_hash":(##class(Demo.Protocol).Hash("fixture")),"header":{"header_id":900001001,"source":"Source","target":"Receiver","session_id":900001000,"body_class":"Contest.StructuredRequest","body_id":"unit","message_type":1},"capture":{"state":"captured","facts":(##class(Contest.ProductionEvidence).Inspect({"patient_id":"NEVER-EXPORT","birthDate":"2000-01-01"},"json-object"))},"outcome":"attempted","delivery_evidence":"message_header_only","limits":["No receiver proof."]}
    Do value.%Set("record_hash",##class(Contest.ExportEvidence).Digest(value))
    Quit value
}

Method TestPacketProvenance()
{
    Set value=..Observation(), packet=##class(Contest.ProductionReview).Packet(value,[])
    Do $$$AssertEquals(packet.stage,"after_send")
    Do $$$AssertTrue(packet.synthetic,"Synthetic-only export contract")
    Do $$$AssertTrue(packet.%ToJSON()'["NEVER-EXPORT","No raw values")
    Set facts=##class(Contest.RiskReview).Facts(packet)
    Do $$$AssertEquals(facts.%Get("observed_fields").kind,"observation")
    Do $$$AssertEquals(facts.%Get("business_context").kind,"missing_information")
    Do $$$AssertTrue(packet.%ToJSON()["not receiver acceptance","Header does not prove delivery")
    Set context={"id":"optional","revision":1,"digest":"fixture","config":{"purpose":"Declared quality purpose"}}
    Set packet=##class(Contest.ProductionReview).Packet(value,[(context)]), facts=##class(Contest.RiskReview).Facts(packet)
    Do $$$AssertEquals(facts.%Get("declared_purpose").kind,"claim","Optional purpose is not an observed fact")
    Do $$$AssertEquals(facts.%Get("business_context").kind,"missing_information","Context does not prove recipient/use")
    Set value.capture.state="unsupported", rejected=0
    Try { Set ignored=##class(Contest.ProductionReview).Packet(value,[]) } Catch ex { Set rejected=1 }
    Do $$$AssertTrue(rejected,"No invented facts for unsupported evidence")
}

Method TestSampling()
{
    Do $$$AssertTrue(##class(Contest.ProductionReviewService).Selected(1,3),"First eligible body sampled")
    Do $$$AssertTrue('##class(Contest.ProductionReviewService).Selected(2,3),"Second body not sampled")
    Do $$$AssertTrue(##class(Contest.ProductionReviewService).Selected(4,3),"Every N eligible bodies")
    Set rejected=0
    Try { Set ignored=##class(Contest.ProductionReviewService).Selected(1,0) } Catch ex { Set rejected=1 }
    Do $$$AssertTrue(rejected,"Invalid sampling must fail")
}

Method TestReviewPaginationContract()
{
    If '$System.Security.Check("ContestMonitorDeploy","U") Quit
    Lock +^ContestProductionReview("worker"):2
    If '$Test Do ##class(Demo.Protocol).Fail("Review worker busy; isolated fixture test refused")
    TStart
    Try {
        Set value=..Observation(), pid=value.%Get("production_id")
        For i=1:1:30 {
            Set header=900002000+i, item={"id":(##class(Contest.ProductionEvidence).Identity(pid,header)),"production_id":(pid),"header_id":(header),"state":"unsupported","reserved_model_requests":0,"attempted_model_requests":0}
            Do ##class(Contest.ProductionReviewService).Save(item)
        }
        Set first=##class(Contest.ProductionReviewService).Page(pid), second=##class(Contest.ProductionReviewService).Page(pid,first.%Get("next_before"))
        Do $$$AssertEquals(first.items.%Size(),25)
        Do $$$AssertEquals(first.%GetTypeOf("next_before"),"number","Review cursor has a numeric JSON type")
        Do $$$AssertTrue(second.items.%Size()>0)
        Do $$$AssertTrue(second.items.%Get(0).%Get("header_id")<first.items.%Get(24).%Get("header_id"),"Review pages never overlap")
    } Catch ex { TRollback 1 Lock -^ContestProductionReview("worker") Throw ex }
    TRollback 1
    Lock -^ContestProductionReview("worker")
}

Method TestUnknownBusinessContextCannotBecomeAllClear()
{
    Set fixture=##class(Contest.RiskReviewTests).%New(""), packet=fixture.Packet(), packet.stage="after_send"
    Set questions=##class(Contest.RiskReviewV4).Questions(packet,fixture.Plan()), packages=fixture.Packages(questions)
    Set answer=##class(Contest.RiskReviewV4Tests).%New("").Answer(), issue=answer.issues.%Get(0), issue.status="no_signal_on_checked_issue"
    Do issue.%Set("condition_status","met")
    Set rejected=0
    Try { Set result=##class(Contest.ProductionReview).Resolve(packet,questions,packages,answer) } Catch ex { Set rejected=(ex.DisplayString()["cannot resolve actual business") }
    Do $$$AssertTrue(rejected,"An otherwise well-formed answer cannot invent established purpose/recipient")
    Set issue.status="unresolved", issue.applicability="unknown", issue.exceptions.status="unresolved"
    Do issue.%Set("condition_status","unknown"), issue.%Set("affirmative_fact_ids",[]), issue.%Set("applicability_fact_ids",[])
    Do answer.%Set("missing_information",["Establish actual recipient, business purpose and applicable permission."])
    Set result=##class(Contest.ProductionReview).Resolve(packet,questions,packages,answer)
    Do $$$AssertEquals(result.assessment,"information_required")
    Do $$$AssertTrue(result.summary.unresolved)
    Do $$$AssertTrue('result.summary.%Get("risk_detected"))
    Set rejected=0
    Try { Set agent=##class(Contest.ProductionReview).NewAgent("unit-no-chat","judge") } Catch ex { Set rejected=1 }
    Do $$$AssertTrue(rejected,"Cannot bypass collector authorization using runtime directly")
    Do $$$AssertEquals(##class(Contest.RiskReview).InputLimit(),80000,"Existing runtime input behavior preserved")
}

Method TestReservationAndIsolation()
{
    If '$System.Security.Check("ContestMonitorDeploy","U") Quit
    Lock +^ContestProductionReview("worker"):2
    If '$Test Do ##class(Demo.Protocol).Fail("Review worker busy; isolated fixture test refused")
    TStart
    Try {
        Set value=..Observation(), pid=value.%Get("production_id"), auth="unit-m3-reserve"
        Set grant={"authorization_id":(auth),"production_id":(pid),"enabled":true,"used_reviews":0,"definition":{"max_reviews":1,"expires_at":(##class(Demo.Protocol).Now()+60)}}
        Set ^ContestProductionReview("grant",pid,auth)=grant.%ToJSON()
        Set item={"id":(value.id),"production_id":(pid),"header_id":900001001,"observation_hash":(value.%Get("record_hash")),"authorization_id":(auth),"state":"pending","reserved_model_requests":0}
        Do $$$AssertTrue(##class(Contest.ProductionReviewService).Reserve(item),"Reserve before model call")
        Set saved={}.%FromJSON(^ContestProductionReview("grant",pid,auth))
        Do $$$AssertEquals(saved.%Get("used_reviews"),1)
        Do $$$AssertEquals(item.%Get("reserved_model_requests"),2)
        Do $$$AssertTrue('##class(Contest.ProductionReviewService).Reserve(item),"No replay of running item")
        Set item.state="pending", grant={}.%FromJSON(^ContestProductionReview("grant",pid,auth))
        Do grant.definition.%Set("max_reviews",2)
        Set ^ContestProductionReview("grant",pid,auth)=grant.%ToJSON()
        Do $$$AssertTrue('##class(Contest.ProductionReviewService).Reserve(item),"Persisted reservation prevents replay even with spare budget")
        Do grant.definition.%Set("max_reviews",1)
        Set ^ContestProductionReview("grant",pid,auth)=grant.%ToJSON()
        Set item.state="pending"
        Do item.%Set("header_id",900001002)
        Do $$$AssertTrue('##class(Contest.ProductionReviewService).Reserve(item),"Budget exhaustion cannot overspend")
        Do $$$AssertEquals(item.state,"blocked_budget")
        Set other=##class(Contest.ProductionMonitor).Key("DEMO","Demo.Production")
        Do $$$AssertTrue('$Data(^ContestProductionReview("grant",other,auth)),"Budget is Production isolated")
        Set grant.enabled=0
        Do grant.%Set("used_reviews",0)
        Set ^ContestProductionReview("grant",pid,auth)=grant.%ToJSON(), item.state="pending"
        Do $$$AssertTrue('##class(Contest.ProductionReviewService).Reserve(item),"Revocation blocks spending")
        Set grant.enabled=1
        Do grant.definition.%Set("expires_at",##class(Demo.Protocol).Now()-1)
        Set ^ContestProductionReview("grant",pid,auth)=grant.%ToJSON(), item.state="pending"
        Do $$$AssertTrue('##class(Contest.ProductionReviewService).Reserve(item),"Expired grant cannot spend")
    } Catch ex { TRollback 1 Lock -^ContestProductionReview("worker") Throw ex }
    TRollback 1
    Lock -^ContestProductionReview("worker")
}

Method TestInterruptedReservationsAreNeverReplayed()
{
    If '$System.Security.Check("ContestMonitorDeploy","U") Quit
    Lock +^ContestProductionReview("worker"):2
    If '$Test Do ##class(Demo.Protocol).Fail("Review worker busy; isolated fixture test refused")
    TStart
    Try {
        Set value=..Observation(), pid=value.%Get("production_id")
        Set item={"id":(##class(Contest.ProductionEvidence).Identity(pid,900001050)),"production_id":(pid),"header_id":900001050,"state":"running","reserved_model_requests":2,"attempted_model_requests":0}
        Do ##class(Contest.ProductionReviewService).Save(item), ##class(Contest.ProductionReviewService).Recover(pid)
        Set item=##class(Contest.ProductionReviewService).Lookup(pid,900001050)
        Do $$$AssertEquals(item.state,"interrupted")
        Do $$$AssertEquals(item.%Get("reserved_model_requests"),2,"Reserved budget is retained")
        Do $$$AssertEquals(item.%Get("attempted_model_requests"),0,"Recovery never calls provider")
        Do $$$AssertTrue('$Data(^ContestProductionReview("inflight",pid,900001050)))
        Set feed=##class(Contest.ProductionMonitor).Risks(pid), found=0
        For i=0:1:feed.items.%Size()-1 {
            Set finding=feed.items.%Get(i)
            If finding.id=item.id {
                Set found=1
                Do $$$AssertEquals(finding.category,"technical_failure")
            }
        }
        Do $$$AssertTrue(found,"M3 outcomes are visible in the existing Production risks feed")
        Set before=^ContestProductionReview("review",pid,900001050)
        Do ##class(Contest.ProductionReviewService).Recover(pid)
        Do $$$AssertEquals(^ContestProductionReview("review",pid,900001050),before,"Repeated recovery is idempotent")
    } Catch ex { TRollback 1 Lock -^ContestProductionReview("worker") Throw ex }
    TRollback 1
    Lock -^ContestProductionReview("worker")
}

Method Authorization() As %DynamicObject
{
    Set snapshot=##class(Contest.ProductionMonitor).Snapshot("OBSERVATION"), source="", id=""
    For {
        Set id=$Order(^ContestAgents("config",id))
        If id="" Quit
        Set candidate=##class(Contest.AgentService).Get(id)
        If ##class(Contest.PrivacyEvaluation).Eligible(candidate) { Set source=candidate Quit }
    }
    If '$IsObject(source) Do ##class(Demo.Protocol).Fail("Install an eligible reviewer Agent for builder-authorized policy tests")
    Quit {"authorization_id":"unit-m3-policy","production_id":(snapshot.id),"config_hash":(snapshot.%Get("config_hash")),"agent_id":(source.id),"source_revision":(source.revision),"agent_config_hash":(source.%Get("config_hash")),"contract_hash":(##class(Contest.ProductionReview).ContractHash()),"every_n":2,"max_reviews":1,"max_model_requests":2,"expires_at":((##class(Demo.Protocol).Now()\1)+600),"include_existing":true,"acknowledge_cost":true,"acknowledge_synthetic_data_export":true}
}

Method TestAuthorizationAndReadBoundaries()
{
    If '$System.Security.Check("ContestMonitorDeploy","U") {
        Set rejected=0
        Try { Set ignored=##class(Contest.ProductionReviewService).Authorize({}) } Catch ex { Set rejected=1 }
        Do $$$AssertTrue(rejected,"Restricted developer cannot authorize paid calls")
        Quit
    }
    Lock +^ContestProductionReview("worker"):2
    If '$Test Do ##class(Demo.Protocol).Fail("Review worker busy; isolated fixture test refused")
    TStart
    Try {
        Set body=..Authorization(), pid=body.%Get("production_id")
        Kill ^ContestProductionReview("active",pid)
        For field="acknowledge_cost","acknowledge_synthetic_data_export","every_n","max_reviews","max_model_requests","config_hash","agent_config_hash","contract_hash","expires_at" {
            Set bad={}.%FromJSON(body.%ToJSON()), rejected=0
            If (field="acknowledge_cost")||(field="acknowledge_synthetic_data_export") { Do bad.%Set(field,0,"boolean") }
            ElseIf (field="config_hash")||(field="agent_config_hash")||(field="contract_hash") { Do bad.%Set(field,"wrong") }
            Else { Do bad.%Set(field,0) }
            Try { Set ignored=##class(Contest.ProductionReviewService).Authorize(bad) } Catch ex { Set rejected=1 }
            Do $$$AssertTrue(rejected,field)
        }
        Set grant=##class(Contest.ProductionReviewService).Authorize(body)
        Do $$$AssertEquals(grant.%Get("used_reviews"),0,"Authorization itself calls no model")
        Set retry=##class(Contest.ProductionReviewService).Authorize(body)
        Do $$$AssertEquals(retry.%ToJSON(),grant.%ToJSON(),"Identical retry cannot replenish budget")
        Set bad={}.%FromJSON(body.%ToJSON()), rejected=0
        Do bad.%Set("every_n",1)
        Try { Set ignored=##class(Contest.ProductionReviewService).Authorize(bad) } Catch ex { Set rejected=1 }
        Do $$$AssertTrue(rejected,"Conflicting immutable identity rejected")
        Set revoked=##class(Contest.ProductionReviewService).Revoke({"production_id":(pid),"authorization_id":(body.%Get("authorization_id"))})
        Set retry=##class(Contest.ProductionReviewService).Authorize(body)
        Do $$$AssertTrue('retry.enabled,"Retry does not re-enable revoked consent")
        Set rejected=0
        Try { Set ignored=##class(Contest.ProductionReviewService).Page(pid,1.5) } Catch ex { Set rejected=1 }
        Do $$$AssertTrue(rejected,"Review cursor is strictly integer")
    } Catch ex { TRollback 1 Lock -^ContestProductionReview("worker") Throw ex }
    TRollback 1
    Lock -^ContestProductionReview("worker")
}

Method TestNoModelSamplingAndIsolation()
{
    If '$System.Security.Check("ContestMonitorDeploy","U") Quit
    Lock +^ContestProductionReview("worker"):2
    If '$Test Do ##class(Demo.Protocol).Fail("Review worker busy; isolated fixture test refused")
    TStart
    Try {
        Set body=..Authorization(), pid=body.%Get("production_id"), auth=body.%Get("authorization_id"), snapshot=##class(Contest.ProductionMonitor).Snapshot("OBSERVATION")
        Kill ^ContestProductionReview("active",pid)
        Set grant=##class(Contest.ProductionReviewService).Authorize(body)
        Do grant.%Set("used_reviews",1)
        Set ^ContestProductionReview("grant",pid,auth)=grant.%ToJSON(), ^ContestProductionReview("cursor",pid)=900001000
        For i=1:1:3 {
            Set value=..Observation()
            Do value.header.%Set("header_id",900001000+i), value.header.%Set("body_id","unit-"_i)
            Set value.id=##class(Contest.ProductionEvidence).Identity(pid,900001000+i)
            Do value.%Set("observed_config_hash",snapshot.%Get("config_hash")), value.%Remove("record_hash")
            Do value.%Set("record_hash",##class(Contest.ExportEvidence).Digest(value))
            Set ^ContestProductionEvidence("record",pid,900001000+i)=value.%ToJSON()
        }
        Do ##class(Contest.ProductionReviewService).Scan(pid)
        Set first=##class(Contest.ProductionReviewService).Lookup(pid,900001001), second=##class(Contest.ProductionReviewService).Lookup(pid,900001002), third=##class(Contest.ProductionReviewService).Lookup(pid,900001003)
        Do $$$AssertEquals(first.state,"blocked_budget","Budget blocked item remains visible")
        Do $$$AssertEquals(second.state,"not_sampled","Sampling disposition retained")
        Do $$$AssertEquals(third.state,"blocked_budget")
        Do $$$AssertEquals(first.%Get("attempted_model_requests"),0,"Exhaustion makes zero provider calls")
        Set before=^ContestProductionReview("review",pid,900001001)
        Set ^ContestProductionReview("cursor",pid)=900001000
        Do ##class(Contest.ProductionReviewService).Scan(pid)
        Do $$$AssertEquals(^ContestProductionReview("review",pid,900001001),before,"Terminal dispositions are not retried")
        Set page=##class(Contest.ProductionReviewService).Page(pid)
        Do $$$AssertTrue(page.counts.%Get("blocked_budget")>=2)
        Set other=##class(Contest.ProductionMonitor).Key("DEMO","Demo.Production")
        Set rejected=0
        Try { Set ignored=##class(Contest.ProductionReviewService).Detail(other,900001001) } Catch ex { Set rejected=1 }
        Do $$$AssertTrue(rejected,"Same numeric header never crosses Production boundary")
    } Catch ex { TRollback 1 Lock -^ContestProductionReview("worker") Throw ex }
    TRollback 1
    Lock -^ContestProductionReview("worker")
}
}
