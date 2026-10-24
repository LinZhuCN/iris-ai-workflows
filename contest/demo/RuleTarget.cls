Class Demo.RuleTarget
{
ClassMethod Status() As %DynamicObject
{
    If $Namespace'="DEMO" Do ##class(Demo.Protocol).Fail("Rule target requires DEMO")
    If $Data(^DemoPolicy("active")) {
        Set active={}.%FromJSON(^DemoPolicy("active"))
        If (active.%GetTypeOf("revision")'="number") || (active.revision<1) || (active.revision\1'=active.revision) || (active.%GetTypeOf("bundle")'="object") Do ##class(Demo.Protocol).Fail("Active policy record is invalid")
        If ##class(Demo.RuleEngine).Hash(active.bundle)'=active.%Get("bundle_hash") Do ##class(Demo.Protocol).Fail("Active policy hash is invalid")
        Return active
    }
    If $Get(^DemoPolicy("everEnabled")) Do ##class(Demo.Protocol).Fail("Required active policy is missing; Gate is fail-closed")
    Quit {"revision":0,"bundle_hash":"","deployment_id":"","bundle":(##class(Demo.RuleEngine).Template(0)),"state":"not_enabled"}
}

ClassMethod Prepare(body As %DynamicObject) As %DynamicObject
{
    If (body.%Size()'=5) || (body.%GetTypeOf("deployment_id")'="string") || (body.%GetTypeOf("bundle_hash")'="string") || (body.%GetTypeOf("source_hash")'="string") || (body.%GetTypeOf("expected_revision")'="number") || (body.%GetTypeOf("bundle")'="object") Do ##class(Demo.Protocol).Fail("Exact rule preparation contract required")
    If '$Match(body.%Get("deployment_id"),"^rule-plan-[A-Za-z0-9-]+$") || '$Match(body.%Get("source_hash"),"^[a-f0-9]{64}$") Do ##class(Demo.Protocol).Fail("Invalid rule deployment identity")
    Set canonical=##class(Demo.RuleEngine).Canonical(body.bundle)
    If ##class(Demo.RuleEngine).Hash(canonical)'=body.%Get("bundle_hash") Do ##class(Demo.Protocol).Fail("Rule bundle hash mismatch")
    Lock +^DemoPolicy("lock"):2
    If '$Test Do ##class(Demo.Protocol).Fail("Rule target busy")
    Try {
        Set id=body.%Get("deployment_id"), snapshot=##class(Demo.Runtime).Snapshot(), current=..Status()
        If 'snapshot.supported || (snapshot.%Get("config_hash")'=body.%Get("source_hash")) Do ##class(Demo.Protocol).Fail("Source configuration changed")
        If $Data(^DemoPolicy("deployment",id)) {
            Set loaded={}.%FromJSON(^DemoPolicy("deployment",id))
            If loaded.%Get("bundle_hash")'=body.%Get("bundle_hash") Do ##class(Demo.Protocol).Fail("Rule deployment identity conflict")
            Lock -^DemoPolicy("lock")
            Return loaded
        }
        If $Data(^DemoPolicy("prepared",id)) {
            Set prepared={}.%FromJSON(^DemoPolicy("prepared",id))
            If (prepared.%Get("bundle_hash")'=body.%Get("bundle_hash")) || (prepared.%Get("source_hash")'=body.%Get("source_hash")) || (prepared.%Get("expected_revision")'=body.%Get("expected_revision")) Do ##class(Demo.Protocol).Fail("Prepared deployment identity conflict")
            Lock -^DemoPolicy("lock")
            Return prepared
        }
        If current.revision'=body.%Get("expected_revision") Do ##class(Demo.Protocol).Fail("Rule baseline changed")
        Set prepared=body, prepared.bundle=canonical, prepared.state="prepared"
        Set ^DemoPolicy("prepared",id)=prepared.%ToJSON()
    } Catch ex { Lock -^DemoPolicy("lock") Throw ex }
    Lock -^DemoPolicy("lock")
    Quit prepared
}

ClassMethod Activate(body As %DynamicObject) As %DynamicObject
{
    If (body.%Size()'=2) || (body.%GetTypeOf("deployment_id")'="string") || (body.%GetTypeOf("bundle_hash")'="string") Do ##class(Demo.Protocol).Fail("Exact activation identity required")
    Set id=body.%Get("deployment_id")
    If '$Match(id,"^rule-plan-[A-Za-z0-9-]+$") Do ##class(Demo.Protocol).Fail("Invalid rule deployment identity")
    Lock +^DemoPolicy("lock"):2
    If '$Test Do ##class(Demo.Protocol).Fail("Rule target busy")
    Set level=$TLevel
    Try {
        If $Data(^DemoPolicy("deployment",id)) {
            Set loaded={}.%FromJSON(^DemoPolicy("deployment",id))
            If loaded.%Get("bundle_hash")'=body.%Get("bundle_hash") Do ##class(Demo.Protocol).Fail("Rule activation hash conflict")
        } Else {
            If '$Data(^DemoPolicy("prepared",id)) Do ##class(Demo.Protocol).Fail("Rule deployment was not prepared")
            Set prepared={}.%FromJSON(^DemoPolicy("prepared",id)), current=..Status(), snapshot=##class(Demo.Runtime).Snapshot()
            If (prepared.%Get("bundle_hash")'=body.%Get("bundle_hash")) || (current.revision'=prepared.%Get("expected_revision")) || 'snapshot.supported || (snapshot.%Get("config_hash")'=prepared.%Get("source_hash")) Do ##class(Demo.Protocol).Fail("Rule baseline or source configuration changed")
            If ##class(Demo.RuleEngine).Hash(prepared.bundle)'=prepared.%Get("bundle_hash") Do ##class(Demo.Protocol).Fail("Prepared bundle corrupted")
            Set loaded={"deployment_id":(id),"revision":(current.revision+1),"bundle_hash":(prepared.%Get("bundle_hash")),"bundle":(prepared.bundle),"state":"loaded"}
            TStart
            If prepared.bundle.enabled Set ^DemoPolicy("everEnabled")=1
            Set ^DemoPolicy("active")=loaded.%ToJSON(), ^DemoPolicy("deployment",id)=loaded.%ToJSON()
            TCommit
        }
    } Catch ex {
        If $TLevel>level TRollback 1
        Lock -^DemoPolicy("lock")
        Throw ex
    }
    Lock -^DemoPolicy("lock")
    Quit loaded
}
}
