Class Contest.BusinessReviewTests Extends %UnitTest.TestProduction
{
Parameter PRODUCTION = "Contest.Production";
Method TestControl() As %Status { Quit $$$OK }

Method Packet() As %DynamicObject
{
    Quit {"case_id":"business-01","stage":"before_send","synthetic":true,"facts":[{"id":"purpose","text":"A verified provider requests a synthetic clinical result for treatment."}]}
}

Method Answer() As %DynamicObject
{
    Quit {"assessment":"no_finding","recommended_action":"continue_under_existing_controls","reason":"Limited treatment disclosure review, not certification.","findings":[{"fact_ids":["purpose"],"explanation":"Treatment context requires the disclosure permission and exception.","citations":[{"evidence_id":"evidence-0","quote":"A covered entity may disclose protected health information for treatment activities of a health care provider."}]}],"missing_information":[]}
}

Method Evidence() As %DynamicArray
{
    Quit [{"id":"evidence-0","record_id":"unit-record","text":"A covered entity may disclose protected health information for treatment activities of a health care provider.","metadata":{"kind":"regulation_snapshot","retrieval_scope":"normative","source_locator":"45 CFR 164.506"}}]
}

Method TestFactContract()
{
    Set packet=..Packet()
    Do $$$AssertTrue(##class(Contest.BusinessReview).ValidPacket(packet))
    Do packet.%Set("expected","no_finding")
    Do $$$AssertTrue('##class(Contest.BusinessReview).ValidPacket(packet),"Expected answers must not enter model packets")
    Do packet.%Remove("expected"), packet.%Set("synthetic",1)
    Do $$$AssertTrue('##class(Contest.BusinessReview).ValidPacket(packet),"Synthetic must be an explicit boolean")
}

Method TestCitationsAndFactReferences()
{
    Set packet=..Packet(), answer=..Answer(), evidence=..Evidence()
    Do $$$AssertTrue(##class(Contest.BusinessReview).ValidResult(answer,packet,evidence))
    Do answer.findings.%Get(0).citations.%Get(0).%Set("quote","A fabricated HIPAA quote not in evidence.")
    Do $$$AssertTrue('##class(Contest.BusinessReview).ValidResult(answer,packet,evidence))
    Set answer=..Answer()
    Do answer.findings.%Get(0).%Set("fact_ids",["unknown"])
    Do $$$AssertTrue('##class(Contest.BusinessReview).ValidResult(answer,packet,evidence))
    Do evidence.%Get(0).metadata.%Set("retrieval_scope","historical")
    Do $$$AssertTrue('##class(Contest.BusinessReview).ValidResult(..Answer(),packet,evidence))
}

Method TestStageAndMissingEvidence()
{
    Set packet=..Packet(), answer=..Answer()
    Set packet.stage="after_send"
    Do answer.%Set("recommended_action","hold_for_review")
    Do $$$AssertTrue('##class(Contest.BusinessReview).ValidResult(answer,packet,..Evidence()))
    Set answer={"assessment":"insufficient_evidence","recommended_action":"manual_review","reason":"Retrieval unavailable.","findings":[],"missing_information":["Normative evidence"]}
    Do $$$AssertTrue(##class(Contest.BusinessReview).ValidResult(answer,packet,[]))
    Do answer.%Set("assessment","no_finding")
    Do $$$AssertTrue('##class(Contest.BusinessReview).ValidResult(answer,packet,[]))
    Set answer=..Answer()
    Do answer.%Set("assessment","risk")
    Do $$$AssertTrue('##class(Contest.BusinessReview).ValidResult(answer,..Packet(),..Evidence()),"Risk must not recommend continuing")
}

Method TestContextIsolationAndQueryBudget()
{
    TStart
    Try {
        Set rejected=0
        Try { Set value=##class(Contest.BusinessTools).ReadBusinessFacts("not-bound") }
        Catch ex { Set rejected=1 }
        Do $$$AssertTrue(rejected)
        Set ^ContestBusinessContext($Job)="unit-run", ^ContestBusinessContext($Job,"facts")=..Packet().%ToJSON()
        Set value=##class(Contest.BusinessTools).ReadBusinessFacts("unit-run")
        Do $$$AssertEquals(value.%Get("case_id"),"business-01")
        Set ^ContestBusinessContext($Job,"queries")=3
        Set rejected=0
        Try { Set value=##class(Contest.BusinessTools).SearchBusinessEvidence("unit-run","treatment") }
        Catch ex { Set rejected=1 }
        Do $$$AssertTrue(rejected,"Fourth search must be rejected before vector retrieval")
        Set ^ContestBusinessContext($Job,"queries")=0, ^ContestBusinessContext($Job,"simulateUnavailable")=1
        Set value=##class(Contest.BusinessTools).SearchBusinessEvidence("unit-run","treatment")
        Do $$$AssertEquals(value.availability,"unavailable")
        Do $$$AssertEquals(value.evidence.%Size(),0)
        TRollback 1
    } Catch ex { TRollback 1 Throw ex }
}

Method TestCostAndReplay()
{
    Set body={"agent_id":"source","request_key":"unit-business","input_hash":($Justify("",64)),"acknowledge_cost":true,"max_model_requests":48}
    Do body.%Set("input_hash",$Translate(body.%Get("input_hash")," ","a"))
    Do $$$AssertTrue(##class(Contest.BusinessReview).ValidStart(body))
    Do body.%Set("max_model_requests",52)
    Do $$$AssertTrue('##class(Contest.BusinessReview).ValidStart(body))
    Set id="business-unit-"_$System.Util.CreateGUID()
    TStart
    Try {
        Set ^ContestBusinessReview("report",id)={"id":(id),"state":"running","boot":"old-boot","cases":[]}.%ToJSON()
        Do $$$AssertEquals(##class(Contest.BusinessReview).Status(id).state,"interrupted")
        Set rejected=0
        Try { Do ##class(Contest.BusinessReview).Run(id) }
        Catch ex { Set rejected=1 }
        Do $$$AssertTrue(rejected,"Old-boot jobs must not call the provider")
        TRollback 1
    } Catch ex { TRollback 1 Throw ex }
}

Method TestPreparedInputsAndRequestIdentity()
{
    Set prepared=##class(Contest.BusinessReview).Inputs()
    Do $$$AssertEquals(prepared.inputs.cases.%Size(),12)
    Do $$$AssertEquals($Length(prepared.%Get("input_hash")),64)
    For i=0:1:11 {
        Set packet=prepared.inputs.cases.%Get(i)
        Do $$$AssertTrue('packet.%IsDefined("oracle") && 'packet.%IsDefined("expected"))
    }
    Set id="business-unit-"_$System.Util.CreateGUID(), key="unit-"_$System.Util.CreateGUID()
    TStart
    Try {
        Set ^ContestBusinessReview("report",id)={"id":(id),"state":"completed","config":{"id":"source"},"input_hash":"unit-input","prompt_version":"hipaa-business-runtime-v1"}.%ToJSON()
        Set ^ContestBusinessReview("request",key)=id
        Set body={"agent_id":"source","request_key":(key),"input_hash":($Translate($Justify("",64)," ","a")),"acknowledge_cost":true,"max_model_requests":48}
        Set report={}.%FromJSON(^ContestBusinessReview("report",id))
        Do report.%Set("input_hash",body.%Get("input_hash"))
        Set ^ContestBusinessReview("report",id)=report.%ToJSON()
        Do $$$AssertEquals(##class(Contest.BusinessReview).Start(body).id,id,"Repeated request returns report without worker/model")
        Do body.%Set("agent_id","different")
        Set rejected=0
        Try { Set value=##class(Contest.BusinessReview).Start(body) }
        Catch ex { Set rejected=1 }
        Do $$$AssertTrue(rejected)
        TRollback 1
    } Catch ex { TRollback 1 Throw ex }
}

Method TestSdkToolContractWithoutModel()
{
    Set agent=##class(Contest.AgentService).NewAgent("unit-no-chat",1,"hipaa-business-runtime-v1")
    Do $$$AssertEquals(agent.SystemPrompt,##class(Contest.BusinessReview).Prompt())
    Do $$$AssertEquals(agent.MaxIterations,4)
    Set toolset=##class(Contest.BusinessToolSet).%New(), discovery=toolset.%Discover()
    Do $$$AssertEquals(discovery.tools.%Size(),2,"Only facts and contextual evidence tools may be discovered")
}

Method TestAuthorChecksDoNotBecomeLegalAcceptance()
{
    Set item={"case_id":"business-01","state":"completed","result":(..Answer()),"evidence":(..Evidence())}
    Set spec={"required_sections":["45 CFR 164.506"],"oracle":{"assessment":"no_finding","recommended_action":"continue_under_existing_controls","critical_fact_ids":["purpose"]}}
    Set checked=##class(Contest.BusinessReview).CheckCase(item,spec)
    Do $$$AssertTrue(checked.%Get("oracle_alignment"))
    Do $$$AssertTrue(checked.%Get("human_review_required"))
    Do item.evidence.%Get(0).metadata.%Set("source_locator","HTML article")
    Set checked=##class(Contest.BusinessReview).CheckCase(item,spec)
    Do $$$AssertTrue('checked.%Get("oracle_alignment"),"Relevant HHS guidance is not silently promoted to exact regulation coverage")
    Set item.state="failed"
    Do $$$AssertTrue('##class(Contest.BusinessReview).CheckCase(item,spec).%Get("oracle_alignment"))
}
}
