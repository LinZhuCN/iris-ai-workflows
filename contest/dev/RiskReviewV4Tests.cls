Class Contest.RiskReviewV4Tests Extends %UnitTest.TestProduction
{
Parameter PRODUCTION = "Contest.Production";
Method TestControl() As %Status { Quit $$$OK }

Method Answer() As %DynamicObject
{
    Quit {"issues":[{"question_id":"q1","status":"risk_signal","fact_ids":["destination"],"citations":[{"evidence_id":"e0","passage_id":"p0"}],"explanation":"Observed intended-recipient mismatch fails the established local recipient restriction; not proof of illegality.","applicability":"applicable","applicability_fact_ids":["destination"],"condition_status":"not_met","affirmative_fact_ids":["destination"],"exceptions":{"status":"resolved","explanation":"The scoped local recipient restriction has an observed mismatch, not an inferred missing legal permission."}}],"missing_information":[]}
}

Method TestUnknownCannotBePromotedToRisk()
{
    Set fixture=##class(Contest.RiskReviewTests).%New(""), packet=fixture.Packet(), questions=##class(Contest.RiskReviewV4).Questions(packet,fixture.Plan()), packages=fixture.Packages(questions)
    For variant="unknown","claim","missing","exception","status" {
        Set answer=..Answer(), issue=answer.issues.%Get(0), rejected=0
        If variant="unknown" Set issue.applicability="unknown"
        If variant="claim" {
            Do issue.%Set("fact_ids",["destination","approval"]), issue.%Set("affirmative_fact_ids",["approval"])
        }
        If variant="missing" {
            Set packet=fixture.Packet(), fact=packet.facts.%Get(0), fact.kind="missing_information", fact.verification="unknown"
        }
        If variant="exception" Set issue.exceptions.status="unresolved"
        If variant="status" Do issue.%Set("condition_status","unknown")
        Try { Set result=##class(Contest.RiskReviewV4).Resolve(packet,questions,packages,answer) } Catch ex { Set rejected=1 }
        Do $$$AssertTrue(rejected,variant)
        Set packet=fixture.Packet()
    }
}

Method TestAffirmativeIncidentAndMissingLegalBasisCanCoexist()
{
    Set fixture=##class(Contest.RiskReviewTests).%New(""), packet=fixture.Packet(), packet.stage="after_send"
    Set questions=##class(Contest.RiskReviewV4).Questions(packet,fixture.Plan()), packages=fixture.Packages(questions), answer=..Answer()
    Do answer.%Set("missing_information",["Applicable legal disclosure basis remains uncollected."])
    Set result=##class(Contest.RiskReviewV4).Resolve(packet,questions,packages,answer)
    Do $$$AssertTrue(result.summary.%Get("risk_detected"))
    Do $$$AssertTrue(result.summary.unresolved)
    Do $$$AssertEquals(result.summary.%Get("recommended_action"),"manual_review")
    Do $$$AssertEquals(result.issues.%Get(0).%Get("condition_status"),"not_met")
    Do $$$AssertEquals(result.issues.%Get(0).citations.%Get(0).quote,packages.%Get(0).evidence.%Get(0).text)
}

Method TestGenuineUnknownStaysUnresolvedWithoutAffirmativeFacts()
{
    Set fixture=##class(Contest.RiskReviewTests).%New(""), packet=fixture.Packet(), questions=##class(Contest.RiskReviewV4).Questions(packet,fixture.Plan()), packages=fixture.Packages(questions)
    Set answer=..Answer(), issue=answer.issues.%Get(0), issue.status="unresolved", issue.applicability="unknown"
    Do issue.%Set("condition_status","unknown"), issue.%Set("affirmative_fact_ids",[]), issue.%Set("applicability_fact_ids",[])
    Set issue.exceptions.status="unresolved"
    Do answer.%Set("missing_information",["Verify actual recipient role and applicable disclosure path."])
    Set result=##class(Contest.RiskReviewV4).Resolve(packet,questions,packages,answer)
    Do $$$AssertTrue('result.summary.%Get("risk_detected"))
    Do $$$AssertTrue(result.summary.unresolved)
    Set issue.status="no_signal_on_checked_issue", rejected=0
    Try { Set result=##class(Contest.RiskReviewV4).Resolve(packet,questions,packages,answer) } Catch ex { Set rejected=1 }
    Do $$$AssertTrue(rejected,"Unknown applicability is not an all-clear")
}

Method TestVersionAndConsentAreIsolated()
{
    Do $$$AssertEquals(##class(Contest.RiskReviewV4).Version(),"staged-risk-v4")
    Do $$$AssertTrue(##class(Contest.RiskReviewV4).ContractHash()'=##class(Contest.RiskReviewV3).ContractHash())
    Do $$$AssertTrue(##class(Contest.RiskReviewV4).Prompt("locate")["approved_scenario")
    Set packet=##class(Contest.RiskReviewTests).%New("").Packet(), config={"id":"unit","revision":1,"config_hash":"unit"}
    Set consent={"request_key":"unit-v4","agent_id":"unit","source_revision":1,"config_hash":"unit","input_hash":(##class(Demo.Protocol).Hash(packet.%ToJSON())),"contract_hash":(##class(Contest.RiskReviewV3).ContractHash()),"max_model_requests":2,"acknowledge_cost":true}, rejected=0
    Try { Do ##class(Contest.RiskReviewV4).ValidateConsent(consent,packet,config) } Catch ex { Set rejected=1 }
    Do $$$AssertTrue(rejected,"V4 cannot spend V3 consent")
    Do consent.%Set("contract_hash",##class(Contest.RiskReviewV4).ContractHash())
    Do ##class(Contest.RiskReviewV4).ValidateConsent(consent,packet,config)
}

Method TestScopedNoSignalIsNotSuppressed()
{
    Set fixture=##class(Contest.RiskReviewTests).%New(""), packet=fixture.Packet()
    Set packet.facts.%Get(0).text="The observed destination matches the approved destination under the stated synthetic local restriction."
    Set questions=##class(Contest.RiskReviewV4).Questions(packet,fixture.Plan()), packages=fixture.Packages(questions)
    Set answer=..Answer(), issue=answer.issues.%Get(0), issue.status="no_signal_on_checked_issue"
    Do issue.%Set("condition_status","met")
    Set issue.explanation="The observed recipient matches the established synthetic operational restriction, not overall legal permission."
    Set result=##class(Contest.RiskReviewV4).Resolve(packet,questions,packages,answer)
    Do $$$AssertTrue('result.summary.%Get("risk_detected"))
    Do $$$AssertTrue('result.summary.unresolved)
    Set issue.applicability="not_applicable"
    Do issue.%Set("condition_status","not_applicable"), issue.%Set("affirmative_fact_ids",[])
    Set result=##class(Contest.RiskReviewV4).Resolve(packet,questions,packages,answer)
    Do $$$AssertTrue('result.summary.%Get("risk_detected"),"Affirmative inapplicability is allowed by the contract, not a blanket forced unknown")
}

Method TestActualSdkRemainsOneIterationAndToolFree()
{
    For phase="locate","judge" {
        Set agent=##class(Contest.RiskReviewV4).NewAgent("unit-no-chat",phase)
        Do $$$AssertEquals(agent.MaxIterations,1)
        Do $$$AssertEquals(agent.SystemPrompt,##class(Contest.RiskReviewV4).Prompt(phase))
        Do $$$AssertEquals(agent.ToolManager.%Discover().%Size(),0)
    }

}

Method TestLocalPolicyCannotReplaceObservedGrounding()
{
    Set fixture=##class(Contest.RiskReviewTests).%New(""), packet=fixture.Packet()
    Do packet.facts.%Push({"id":"policy","kind":"local_policy","origin":"unit-policy","verification":"verified","text":"Synthetic local recipient restriction"})
    Do packet.%Get("required_questions").%Get(0).%Get("fact_ids").%Push("policy")
    Set questions=##class(Contest.RiskReviewV4).Questions(packet,fixture.Plan()), packages=fixture.Packages(questions)
    For target="applicability_fact_ids","affirmative_fact_ids" {
        Set answer=..Answer(), issue=answer.issues.%Get(0), rejected=0
        Set issue.status="no_signal_on_checked_issue"
        Do issue.%Set("condition_status","met"), issue.%Get("fact_ids").%Push("policy"), issue.%Set(target,["destination","policy"])
        Try { Set result=##class(Contest.RiskReviewV4).Resolve(packet,questions,packages,answer) } Catch ex { Set rejected=(ex.DisplayString()["verified observations") }
        Do $$$AssertTrue(rejected,target)
    }
    Set answer=..Answer()
    Do answer.issues.%Get(0).%Set("explanation",$Translate($Justify("",1001)," ","x"))
    Set rejected=0
    Try { Set result=##class(Contest.RiskReviewV4).Resolve(packet,questions,packages,answer) } Catch ex { Set rejected=1 }
    Do $$$AssertTrue(rejected,"Do not relax the output limit to rescue a real response")
}
}
