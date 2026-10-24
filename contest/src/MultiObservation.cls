Class Contest.MultiObservation
{
ClassMethod Normalize(facts As %DynamicObject, branch As %String) As %DynamicObject
{
    Set result={"format":($Select(branch="clinic":"hl7-v2",1:"json-object")),"record_count":1,"fields":{},"identifier_present":false,"date_present":false,"dates":{"year_only":0,"full_date":0,"other":0},"unknown_fields":0,"classification":"registered_multi_org_wire_adapter","deidentification":"not_established"}
    For i=0:1:facts.fields.%Size()-1 Do result.fields.%Set(facts.fields.%Get(i),1)
    Do result.%Set("identifier_present",facts.%Get("identifier_present"),"boolean")
    If facts.%Get("full_date") {
        Do result.%Set("date_present",1,"boolean"), result.dates.%Set("full_date",1)
    } ElseIf result.fields.%IsDefined("birthYear") {
        Do result.%Set("date_present",1,"boolean"), result.dates.%Set("year_only",1)
    }
    Do result.%Set("multi_organization",{"branch":(branch),"scope":"Organization-aware receipts and AI audits are linked from the Distribution demo. This observation alone is not receiver evidence."})
    Quit result
}
}
