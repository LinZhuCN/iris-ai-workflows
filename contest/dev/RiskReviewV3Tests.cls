Class Contest.RiskReviewV3Tests Extends %UnitTest.TestProduction
{
Parameter PRODUCTION = "Contest.Production";
Method TestControl() As %Status { Quit $$$OK }

Method TestOnlyJudgePromptChanges()
{
    Do $$$AssertEquals(##class(Contest.RiskReviewV2).ContractHash(),"a305653fb3f84ea02e4ab7dc8b948afb82ccf72e8f75b51a7d4a427d44f7ab10")
    Do $$$AssertEquals(##class(Contest.RiskReviewV3).Version(),"staged-risk-v3")
    Do $$$AssertTrue(##class(Contest.RiskReviewV3).ContractHash()'=##class(Contest.RiskReviewV2).ContractHash())
    Do $$$AssertEquals(##class(Contest.RiskReviewV3).Prompt("locate"),##class(Contest.RiskReviewV2).Prompt("locate"))
    Do $$$AssertTrue(##class(Contest.RiskReviewV3).Prompt("judge")'=##class(Contest.RiskReviewV2).Prompt("judge"))
    For phase="locate","judge" {
        Set agent=##class(Contest.RiskReviewV3).NewAgent("unit-no-chat",phase)
        Do $$$AssertEquals(agent.SystemPrompt,##class(Contest.RiskReviewV3).Prompt(phase))
        Do $$$AssertEquals(agent.MaxIterations,1)
        Do $$$AssertEquals(agent.ToolManager.%Discover().%Size(),0)
    }
}

Method TestMissingInformationStillDrivesConservativeAggregation()
{
    Set fixture=##class(Contest.RiskReviewTests).%New(""), packet=fixture.Packet()
    Set questions=##class(Contest.RiskReviewV3).Questions(packet,fixture.Plan()), packages=fixture.Packages(questions)
    Set answer={"issues":[{"question_id":"q1","status":"risk_signal","fact_ids":["destination"],"citations":[{"evidence_id":"e0","passage_id":"p0"}],"explanation":"Observed route mismatch supports a scoped risk, not definite illegality."}],"missing_information":["Generic extra documentation remains visible if the model still requests it."]}
    Set result=##class(Contest.RiskReviewV3).Resolve(packet,questions,packages,answer)
    Do $$$AssertTrue(result.summary.%Get("unresolved"),"Do not filter missing information to manufacture a better score")
    Do $$$AssertTrue(result.summary.%Get("risk_detected"))
    Do $$$AssertEquals(result.%ToJSON(),##class(Contest.RiskReviewV2).Resolve(packet,questions,packages,answer).%ToJSON())
    Do answer.%Set("missing_information",[])
    Set result=##class(Contest.RiskReviewV3).Resolve(packet,questions,packages,answer)
    Do $$$AssertTrue('result.summary.%Get("unresolved"))
    Do $$$AssertTrue(result.summary.%Get("coverage_limited"))
    Do $$$AssertEquals(result.summary.%Get("recommended_action"),"hold_for_review")
    Set answer.issues.%Get(0).status="unresolved", rejected=0
    Try { Set result=##class(Contest.RiskReviewV3).Resolve(packet,questions,packages,answer) } Catch ex { Set rejected=1 }
    Do $$$AssertTrue(rejected,"True unresolved issues still need requested information")
}

Method TestConsentDoesNotReuseV2Allowance()
{
    Set packet=##class(Contest.RiskReviewTests).%New("").Packet(), config={"id":"unit","revision":1,"config_hash":"unit-pin"}
    Set consent={"request_key":"unit-v3-only","agent_id":"unit","source_revision":1,"config_hash":"unit-pin","input_hash":(##class(Demo.Protocol).Hash(packet.%ToJSON())),"contract_hash":(##class(Contest.RiskReviewV2).ContractHash()),"acknowledge_cost":true,"max_model_requests":2}, rejected=0
    Try { Do ##class(Contest.RiskReviewV3).ValidateConsent(consent,packet,config) } Catch ex { Set rejected=1 }
    Do $$$AssertTrue(rejected)
    Do consent.%Set("contract_hash",##class(Contest.RiskReviewV3).ContractHash())
    Do ##class(Contest.RiskReviewV3).ValidateConsent(consent,packet,config)
}
}
