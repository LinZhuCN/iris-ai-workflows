Class Contest.Facts Extends %AI.Tool
{
ClassMethod Inspect(payload As %String) As %DynamicObject
{
    Set data = ##class(%DynamicObject).%FromJSON(payload)
    If 'data.%IsA("%DynamicObject") Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError,"Payload must be a JSON object"))
    Set facts = ##class(%DynamicObject).%New()
    Set required = 1
    If (data.%GetTypeOf("reference") '= "string") || (data.%Get("reference") = "") Set required = 0
    If (data.%GetTypeOf("code") '= "string") || (data.%Get("code") = "") Set required = 0
    If (data.%GetTypeOf("value") '= "string") || (data.%Get("value") = "") Set required = 0
    Do facts.%Set("has_required_fields",required,"boolean")
    Do facts.%Set("known_code",((data.%Get("code") = "OBS") || (data.%Get("code") = "LAB")),"boolean")
    Quit facts
}

ClassMethod GetTriageFacts(caseId As %String) As %DynamicObject
{
    If caseId '= $Get(^Contest.Context($Job)) Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError,"Tool case is outside the current request"))
    Set record = ##class(Contest.Case).%OpenId(caseId)
    If '$IsObject(record) Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError,"Unknown case"))
    Set facts = ##class(%DynamicObject).%FromJSON(record.Facts)
    Do facts.%Set("case_id",caseId)
    Set sc = ##class(Contest.Event).Add(caseId,"tool_facts","Read-only facts requested by AI Hub")
    $$$ThrowOnError(sc)
    Set ^Contest.Context($Job,"factsRead") = 1
    Quit facts
}
}
