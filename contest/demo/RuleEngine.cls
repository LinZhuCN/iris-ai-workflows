Class Demo.RuleEngine
{
ClassMethod Template(enabled As %Boolean = 1) As %DynamicObject
{
    Set rules=[]
    If enabled Do rules.%Push({"id":"hold-analytics-identifiers","all":[{"field":"purpose","op":"eq","value":"analytics"},{"field":"direct_identifiers","op":"eq","value":true}],"action":"hold_for_review"})
    Set bundle={"schema":1,"executor":"gate-v1","target":"local-demo/DEMO/Demo.Production/before_send","enabled":false,"default_action":"continue","unknown_action":"hold_for_review","rules":(rules)}
    Do bundle.%Set("enabled",enabled,"boolean")
    Quit bundle
}

ClassMethod Valid(bundle As %DynamicObject) As %Boolean
{
    If '$IsObject(bundle) Quit 0
    If 'bundle.%IsA("%DynamicObject") Quit 0
    If $Length($ZConvert(bundle.%ToJSON(),"O","UTF8"))>3000 Quit 0
    If (bundle.%Size()'=7) || (bundle.%GetTypeOf("schema")'="number") || (bundle.schema'=1) || (bundle.executor'="gate-v1") || (bundle.target'="local-demo/DEMO/Demo.Production/before_send") || (bundle.%GetTypeOf("enabled")'="boolean") || (bundle.%Get("default_action")'="continue") || (bundle.%Get("unknown_action")'="hold_for_review") || (bundle.%GetTypeOf("rules")'="array") Quit 0
    If (bundle.rules.%Size()>5) || (bundle.enabled && (bundle.rules.%Size()=0)) || ('bundle.enabled && (bundle.rules.%Size()'=0)) Quit 0
    Set ids={}
    For i=0:1:bundle.rules.%Size()-1 {
        If bundle.rules.%GetTypeOf(i)'="object" Return 0
        Set rule=bundle.rules.%Get(i)
        If (rule.%Size()'=3) || (rule.%GetTypeOf("id")'="string") || '$Match(rule.id,"^[A-Za-z0-9-]{1,60}$") || (rule.action'="hold_for_review") || (rule.%GetTypeOf("all")'="array") Return 0
        If ids.%IsDefined(rule.id) || (rule.all.%Size()<1) || (rule.all.%Size()>5) Return 0
        Do ids.%Set(rule.id,1)
        For j=0:1:rule.all.%Size()-1 {
            If rule.all.%GetTypeOf(j)'="object" Return 0
            Set condition=rule.all.%Get(j)
            If (condition.%Size()'=3) || (condition.%GetTypeOf("field")'="string") || (condition.%GetTypeOf("op")'="string") Return 0
            Set field=condition.field, op=condition.op
            If '((field="purpose") || (field="scenario") || (field="stage") || (field="direct_identifiers") || (field="purpose_known") || (field="deidentification_verified") || (field="authorization_known")) Return 0
            Set type=$Select((field="purpose") || (field="scenario") || (field="stage"):"string",1:"boolean")
            If op="exists" {
                If condition.%GetTypeOf("value")'="boolean" Return 0
            } ElseIf op="eq" {
                If condition.%GetTypeOf("value")'=type Return 0
                If (type="string") && (($Length(condition.value)>60) || (condition.value="")) Return 0
            } ElseIf op="in" {
                If condition.%GetTypeOf("value")'="array" Return 0
                If (condition.value.%Size()<1) || (condition.value.%Size()>5) Return 0
                For k=0:1:condition.value.%Size()-1 {
                    If condition.value.%GetTypeOf(k)'=type Return 0
                    If (type="string") && (($Length(condition.value.%Get(k))>60) || (condition.value.%Get(k)="")) Return 0
                }
            } Else { Return 0 }
        }
    }
    Quit 1
}

ClassMethod Canonical(bundle As %DynamicObject) As %DynamicObject
{
    If '..Valid(bundle) Do ##class(Demo.Protocol).Fail("Invalid bounded rule AST")
    Set rules=[]
    For i=0:1:bundle.rules.%Size()-1 {
        Set rule=bundle.rules.%Get(i), conditions=[]
        For j=0:1:rule.all.%Size()-1 {
            Set condition=rule.all.%Get(j), item={"field":(condition.field),"op":(condition.op)}
            Do item.%Set("value",condition.value,condition.%GetTypeOf("value")), conditions.%Push(item)
        }
        Do rules.%Push({"id":(rule.id),"all":(conditions),"action":"hold_for_review"})
    }
    Set result=..Template(bundle.enabled), result.rules=rules
    Quit result
}

ClassMethod Hash(bundle As %DynamicObject) As %String
{
    Quit ##class(Demo.Protocol).Hash(..Canonical(bundle).%ToJSON())
}

ClassMethod Match(rule As %DynamicObject, facts As %DynamicObject) As %Integer
{
    Set unknown=0
    For i=0:1:rule.all.%Size()-1 {
        Set condition=rule.all.%Get(i), field=condition.field, type=facts.%GetTypeOf(field), matched=0
        If condition.op="exists" {
            If (facts.%IsDefined(field) && (type'="null"))'=condition.value Return 0
            Continue
        }
        If (type="null") || (type="unassigned") || (type="undefined") || 'facts.%IsDefined(field) {
            Set unknown=1
            Continue
        }
        Set expectedType=$Select(condition.op="eq":condition.%GetTypeOf("value"),1:condition.value.%GetTypeOf(0))
        If type'=expectedType {
            Set unknown=1
            Continue
        }
        If condition.op="eq" {
            Set matched=(type=condition.%GetTypeOf("value")) && (facts.%Get(field)=condition.value)
        } Else {
            For j=0:1:condition.value.%Size()-1 {
                If (type=condition.value.%GetTypeOf(j)) && (facts.%Get(field)=condition.value.%Get(j)) Set matched=1
            }
        }
        If 'matched Return 0
    }
    Quit $Select(unknown:-1,1:1)
}

ClassMethod Decision(bundle As %DynamicObject, facts As %DynamicObject) As %String
{
    If '..Valid(bundle) Do ##class(Demo.Protocol).Fail("Invalid Gate bundle")
    If 'bundle.enabled Quit "continue"
    If '$IsObject(facts) Quit "hold_for_review"
    If (facts.%GetTypeOf("purpose_known")'="boolean") || 'facts.%Get("purpose_known") Quit "hold_for_review"
    If (facts.%GetTypeOf("purpose")'="string") || '((facts.purpose="analytics") || (facts.purpose="treatment")) Quit "hold_for_review"
    Set unknown=0
    For i=0:1:bundle.rules.%Size()-1 {
        Set match=..Match(bundle.rules.%Get(i),facts)
        If match=1 Return "hold_for_review"
        If match=-1 Set unknown=1
    }
    Quit $Select(unknown:"hold_for_review",1:"continue")
}
}
