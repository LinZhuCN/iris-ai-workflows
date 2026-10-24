Class Contest.RiskReviewFixture Extends Contest.RiskReview
{
ClassMethod NewAgent(model As %String, phase As %String) As %AI.Agent
{
    Do ##class(Demo.Protocol).Fail("Fixture must never create a provider or Agent")
}

ClassMethod CallPhase(model As %String, phase As %String, input As %DynamicObject, report As %DynamicObject) As %DynamicObject [ Private ]
{
    Do report.%Set("reserved_model_requests",report.%Get("reserved_model_requests")+1)
    Do report.phases.%Push({"phase":(phase),"input":(input),"fixture":true})
    If (phase="locate") && (model="fixture-fail-locate") Do ##class(Demo.Protocol).Fail("Explicit fixture transport failure")
    If phase="locate" Quit {"questions":[]}
    Quit {"issues":[{"question_id":"q1","status":"unresolved","fact_ids":["destination"],"citations":[],"explanation":"Fixture evidence is deliberately unavailable."}],"missing_information":["Review unavailable development evidence."]}
}

ClassMethod PrepareEvidence(runId As %String, config As %DynamicObject, questions As %DynamicArray) As %DynamicArray
{
    If config.model="fixture-fail-evidence" Do ##class(Demo.Protocol).Fail("Explicit fixture source-integrity failure")
    Quit [{"question_id":"q1","coverage":"unreviewed_partial","availability":"unavailable","evidence":[],"retrievals":[]}]
}
}
