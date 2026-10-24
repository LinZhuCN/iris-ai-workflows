Class Contest.HIPAAReview Extends Contest.RiskReviewV4
{
ClassMethod Version() As %String { Quit "hipaa-conditions-v1" }
ClassMethod InputLimit() As %Integer { Quit 160000 }

ClassMethod Template(topic As %String) As %DynamicArray
{
    Quit ##class(Contest.DeclarationReview).Template(topic)
}

ClassMethod PrepareEvidence(runId As %String, config As %DynamicObject, questions As %DynamicArray) As %DynamicArray
{
    Quit ##class(Contest.DeclarationReview).PrepareEvidence(runId,config,questions)
}

ClassMethod Prompt(phase As %String) As %String
{
    Quit ##class(Contest.RiskReviewV4).Prompt(phase)_" Assess the HIPAA condition actually raised by supplied business evidence, not merely consistency with a fictional local rule. Distinguish applicable legal permission, an exception to an otherwise relevant requirement, affirmative absence and unknown evidence. Use supplied complete normative definitions, conditions and exceptions; never infer permission solely from a policy title or a component name. A stipulated synthetic observation is a premise to test, not proof that a real Production collector can establish it. Do not call an exception a violation, and do not manufacture an alternative basis when facts explicitly rule it out. Keep conclusions scoped and do not certify legal compliance or breach-notification duties."
}

ClassMethod ContractHash() As %String
{
    Quit ##class(Demo.Protocol).Hash(..Version()_"|v4-grounding|full-501-502-506-508-514|160000|2requests|"_..Prompt("locate")_"|"_..Prompt("judge")_"|"_..Template("recipient_purpose").%ToJSON()_"|"_..Template("deidentification").%ToJSON())
}
}
