Class Demo.Gate
{
ClassMethod Inspect(facts As %DynamicObject = "") As %DynamicObject
{
    Set hash="", revision=0, decision="hold_for_review"
    Try {
        Set active=##class(Demo.RuleTarget).Status(), hash=active.%Get("bundle_hash"), revision=active.revision
        If hash'="" {
            If ##class(Demo.RuleEngine).Hash(active.bundle)'=hash Do ##class(Demo.Protocol).Fail("Active bundle hash mismatch")
        }
        Set decision=##class(Demo.RuleEngine).Decision(active.bundle,facts)
    } Catch ex {
        Set sequence=$Increment(^DemoPolicy("audit"))
        Set ^DemoPolicy("audit",sequence)={"error":(ex.DisplayString()),"time":(##class(Demo.Protocol).Now()),"decision":"hold_for_review"}.%ToJSON()
    }
    Quit {"decision":(decision),"bundle_hash":(hash),"revision":(revision)}
}
}
