Class Contest.MultiReview Extends Contest.HIPAAReview
{
ClassMethod Version() As %String { Quit "multi-organization-review-v1" }

ClassMethod Prompt(phase As %String) As %String
{
    Quit ##class(Contest.ProductionReview).Prompt(phase)_" This independent multi-organization packet uses approved_scenario and organization_context instead of demo_approval: confirmed profiles and business premises are established WITHIN this synthetic simulation. Actual_wire describes the specific branch's POST-TRANSFORMATION outbound content, not every field in the source FHIR patient. Receiver_evidence records acknowledgement plus readback of that output, not later use. Treat institution duties, purpose, relationship, safeguards and the stated release path as the supplied demo facts. Do not demand real-world integration or contracts solely because these are synthetic profiles. Keep local receiving-policy mismatches separate from HIPAA condition failures. An external treating provider's ordinary treatment disclosure does not require Safe Harbor; consider treatment permission and the treatment-provider minimum-necessary exception. A research export explicitly relying on Safe Harbor must be assessed against its actual identifiers and dates. Removing selected identifiers cannot prove complete Safe Harbor compliance. No action, replay or legal certification."
}

ClassMethod ContractHash() As %String
{
    Quit ##class(Demo.Protocol).Hash(..Version()_"|multi-org-v1|six-requests-per-run|"_..Prompt("locate")_"|"_..Prompt("judge"))
}

ClassMethod Guard()
{
    If '$Data(^ContestMultiAudit("context",$Job)) Do ##class(Demo.Protocol).Fail("Job-bound multi-organization audit authorization required")
    Set context={}.%FromJSON(^ContestMultiAudit("context",$Job)), record=##class(Contest.MultiOrganization).Read(context.id)
    If (record.%Get("audit_state")'="running")||(context.%Get("contract_hash")'=..ContractHash()) Do ##class(Demo.Protocol).Fail("Audit grant is no longer active or contract changed")
}

ClassMethod NewAgent(model As %String, phase As %String) As %AI.Agent
{
    Do ..Guard()
    Quit ##super(model,phase)
}

ClassMethod ValidateConsent(body As %DynamicObject, packet As %DynamicObject, config As %DynamicObject)
{
    Do ..Guard(), ##super(body,packet,config)
    Set context={}.%FromJSON(^ContestMultiAudit("context",$Job))
    If context.%Get("input_hash")'=body.%Get("input_hash") Do ##class(Demo.Protocol).Fail("Audit packet not bound to exact branch")
}
}
