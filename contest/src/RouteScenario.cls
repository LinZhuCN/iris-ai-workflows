Class Contest.RouteScenario
{
ClassMethod ForDeclaration(declaration As %DynamicObject)
{
    Set kind=declaration.kind, purpose=declaration.%Get("purpose_code")
    If '(((kind="aggregation")&&(purpose="internal-consolidation"))||((kind="utilization")&&(purpose="internal-quality-improvement"))) Quit ""
    Set recipient=$Select(kind="aggregation":"local-fhir-center",1:"local-analysis-receiver"), identity=$Select(kind="aggregation":"ContestAggregationFHIR",1:"local-utilization-service")
    If (declaration.recipient'=recipient)||(declaration.%Get("service_identity")'=identity) Do ##class(Demo.Protocol).Fail("Internal policy requires its registered recipient and service identity")
    Quit {"synthetic":true,"policy_id":"DEMO-INTERNAL-USE-1","policy_version":1,"organization_id":"DEMO-HOSPITAL","organization_role":"simulated-covered-entity","recipient_relationship":"same-covered-entity","recipient":(recipient),"service_identity":(identity),"purpose_code":(purpose),"permitted_use":($Select(kind="aggregation":"Internal clinical data consolidation supporting approved hospital care and operations; no external export.",1:"Internal quality assessment and service improvement; not research to produce generalizable knowledge, marketing or external commercial reuse.")),"data_path":"controlled-identifiable-data","deidentification_required":false,"individual_authorization_required":false,"conditions":"Exact project approval, registered internal recipient, configured service identity, approved resources/fields/record limit and validity interval. Use only for the approved purpose. Stable identifiers are allowed within approved scope. A changed purpose, external recipient or broader dataset requires separate review.","authority":"Synthetic organization scenario, not a real legal authorization or certification."}
}

ClassMethod Validate(declaration As %DynamicObject, scenario As %DynamicObject)
{
    Set expected=..ForDeclaration(declaration)
    If '$IsObject(expected) Do ##class(Demo.Protocol).Fail("No registered organization policy for this purpose")
    If scenario.%ToJSON()'=expected.%ToJSON() Do ##class(Demo.Protocol).Fail("Approved organization scenario differs from registered policy")
}
}
