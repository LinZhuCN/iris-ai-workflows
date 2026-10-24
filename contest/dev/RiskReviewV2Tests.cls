Class Contest.RiskReviewV2Tests Extends %UnitTest.TestProduction
{
Parameter PRODUCTION = "Contest.Production";
Method TestControl() As %Status { Quit $$$OK }

Method TestOnlyLocatorChanges()
{
    Do $$$AssertEquals(##class(Contest.RiskReview).ContractHash(),"a3fada0771296b7fd57f0bc6725cd7a03ca2bab7be0ab414569f73e61b85b60d")
    Do $$$AssertEquals(##class(Contest.RiskReviewV2).Version(),"staged-risk-v2")
    Do $$$AssertTrue(##class(Contest.RiskReviewV2).ContractHash()'=##class(Contest.RiskReview).ContractHash())
    Do $$$AssertTrue(##class(Contest.RiskReviewV2).Prompt("locate")'=##class(Contest.RiskReview).Prompt("locate"))
    Do $$$AssertEquals(##class(Contest.RiskReviewV2).Prompt("judge"),##class(Contest.RiskReview).Prompt("judge"))
    For topic="recipient_purpose","deidentification","unclassified" {
        Do $$$AssertEquals(##class(Contest.RiskReviewV2).Template(topic).%ToJSON(),##class(Contest.RiskReview).Template(topic).%ToJSON())
    }
    Set packet=##class(Contest.RiskReviewTests).%New("").Packet()
    Do $$$AssertEquals(##class(Contest.RiskReviewV2).LocateInput(packet).%ToJSON(),##class(Contest.RiskReview).LocateInput(packet).%ToJSON())
}

Method TestSdkUsesV2LocatorButUnchangedJudge()
{
    For phase="locate","judge" {
        Set agent=##class(Contest.RiskReviewV2).NewAgent("unit-no-chat",phase)
        Do $$$AssertEquals(agent.SystemPrompt,##class(Contest.RiskReviewV2).Prompt(phase))
        Do $$$AssertEquals(agent.MaxIterations,1)
        Do $$$AssertEquals(agent.ToolManager.%Discover().%Size(),0)
    }
}

Method TestStrictShapeAndMandatoryRetentionNotSemanticFiltering()
{
    Set packet=##class(Contest.RiskReviewTests).%New("").Packet(), rejected=0
    Try { Set ignored=##class(Contest.RiskReviewV2).Questions(packet,[{"topic":"recipient_purpose","fact_ids":["destination"],"question":"An array must still fail."}]) }
    Catch ex { Set rejected=1 }
    Do $$$AssertTrue(rejected,"Never wrap the previously observed malformed array")
    Set retained=##class(Contest.RiskReviewV2).Questions(packet,{"questions":[]})
    Do $$$AssertEquals(retained.%Size(),1)
    Do $$$AssertEquals(retained.%Get(0).origin,"mandatory")
    Set supplied={"questions":[{"topic":"unclassified","fact_ids":["approval"],"question":"Speculative generic checklist with no independently established issue."}]}
    Set retained=##class(Contest.RiskReviewV2).Questions(packet,supplied)
    Do $$$AssertEquals(retained.%Size(),2,"No deterministic keyword filter may hide a model's extra question")
    Do $$$AssertEquals(retained.%Get(1).origin,"model")
}

Method TestVersionedConsentIsolation()
{
    Set packet=##class(Contest.RiskReviewTests).%New("").Packet(), config={"id":"unit","revision":1,"config_hash":"unit-pin"}
    Set consent={"request_key":"unit-v2-only","agent_id":"unit","source_revision":1,"config_hash":"unit-pin","input_hash":(##class(Demo.Protocol).Hash(packet.%ToJSON())),"contract_hash":(##class(Contest.RiskReview).ContractHash()),"acknowledge_cost":true,"max_model_requests":2}, rejected=0
    Try { Do ##class(Contest.RiskReviewV2).ValidateConsent(consent,packet,config) } Catch ex { Set rejected=1 }
    Do $$$AssertTrue(rejected,"A v1 allowance cannot authorize the new locator")
    Do consent.%Set("contract_hash",##class(Contest.RiskReviewV2).ContractHash())
    Do ##class(Contest.RiskReviewV2).ValidateConsent(consent,packet,config)
    Set rejected=0
    Try { Do ##class(Contest.RiskReview).ValidateConsent(consent,packet,config) } Catch ex { Set rejected=1 }
    Do $$$AssertTrue(rejected)
}
}
