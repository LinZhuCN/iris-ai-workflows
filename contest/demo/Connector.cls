Class Demo.Connector Extends %CSP.REST
{
Parameter UseSession = 0;
Parameter HandleCorsRequest = 0;
Parameter CHARSET = "utf-8";

XData UrlMap [ XMLNamespace = "http://www.intersystems.com/urlmap" ]
{
<Routes>
<Route Url="/health" Method="GET" Call="Health"/>
<Route Url="/snapshot" Method="GET" Call="Snapshot"/>
<Route Url="/transport" Method="GET" Call="Transport"/>
<Route Url="/deploy" Method="POST" Call="Deploy"/>
<Route Url="/messages" Method="POST" Call="Messages"/>
<Route Url="/rules/status" Method="GET" Call="RuleStatus"/>
<Route Url="/rules/prepare" Method="POST" Call="RulePrepare"/>
<Route Url="/rules/activate" Method="POST" Call="RuleActivate"/>
</Routes>
}

ClassMethod Reply(body As %DynamicObject, status As %String = "200 OK") As %Status
{
    Set %response.Status = status, %response.ContentType = "application/json"
    Do %response.SetHeader("Cache-Control","no-store")
    Write body.%ToJSON()
    Quit $$$OK
}

ClassMethod OnPreDispatch(url As %String, method As %String, ByRef continue As %Boolean) As %Status
{
    Set continue = 0
    If ($Namespace '= "DEMO") || '$System.Security.Check("ContestConnectorRead","U") Quit ..Reply({"message":"Connector access denied"},"403 Forbidden")
    If method = "POST" {
        If '$System.Security.Check("ContestConnectorDeploy","U") Quit ..Reply({"message":"Connector deployment permission required"},"403 Forbidden")
        If %request.Content.Size > 4096 Quit ..Reply({"message":"Body too large"},"413 Content Too Large")
        If $ZConvert($Piece(%request.GetCgiEnv("CONTENT_TYPE"),";",1),"L") '= "application/json" Quit ..Reply({"message":"JSON required"},"415 Unsupported Media Type")
    }
    Set continue = 1
    Quit $$$OK
}

ClassMethod Health() As %Status
{
    Quit ..Reply({"instance_id":"local-demo","namespaces":["DEMO"],"capability_version":1,"iris_version":($ZVERSION),"discovery":true,"preinstalled_observer":true,"arbitrary_instrumentation":false,"local_http_only":true})
}

ClassMethod Snapshot() As %Status
{
    Try { Return ..Reply(##class(Demo.Runtime).Snapshot()) }
    Catch ex { Return ..Failure(ex) }
}

ClassMethod Transport() As %Status
{
    Try { Return ..Reply(##class(Demo.Runtime).Transport()) }
    Catch ex { Return ..Failure(ex) }
}

ClassMethod Deploy() As %Status
{
    Try {
        Set body = {}.%FromJSON(%request.Content)
        If 'body.%IsA("%DynamicObject") Do ##class(Demo.Protocol).Fail("Object required")
        If (body.%Size() '= 4) || (body.%GetTypeOf("deployment_id") '= "string") || (body.%GetTypeOf("digest") '= "string") || (body.%GetTypeOf("expected_hash") '= "string") || (body.%GetTypeOf("expected_revision") '= "number") Do ##class(Demo.Protocol).Fail("Exact deployment contract required")
        If '$Match(body.%Get("deployment_id"),"^plan-[A-Za-z0-9-]+$") || '$Match(body.digest,"^[A-Fa-f0-9]{64}$") || '$Match(body.%Get("expected_hash"),"^[A-Fa-f0-9]{64}$") Do ##class(Demo.Protocol).Fail("Invalid deployment identity")
        Return ..Reply(##class(Demo.Runtime).Load(body))
    } Catch ex { Return ..Failure(ex) }
}

ClassMethod Messages() As %Status
{
    Try {
        Set body = {}.%FromJSON(%request.Content)
        If 'body.%IsA("%DynamicObject") Do ##class(Demo.Protocol).Fail("Object required")
        If (body.%Size() '= 2) || (body.%GetTypeOf("scenario") '= "string") || (body.%GetTypeOf("key") '= "string") Do ##class(Demo.Protocol).Fail("Exact synthetic submission contract required")
        If '$Match(body.key,"^[A-Za-z0-9-]{1,128}$") Do ##class(Demo.Protocol).Fail("Invalid submission key")
        Return ..Reply(##class(Demo.Runtime).Submit(body.scenario,body.key))
    } Catch ex { Return ..Failure(ex) }
}

ClassMethod RuleStatus() As %Status
{
    Try { Return ..Reply(##class(Demo.RuleTarget).Status()) }
    Catch ex { Return ..Failure(ex) }
}

ClassMethod RulePrepare() As %Status
{
    Try {
        Set body={}.%FromJSON(%request.Content)
        If '$IsObject(body) Do ##class(Demo.Protocol).Fail("Rule preparation object required")
        If 'body.%IsA("%DynamicObject") Do ##class(Demo.Protocol).Fail("Rule preparation object required")
        Return ..Reply(##class(Demo.RuleTarget).Prepare(body))
    } Catch ex { Return ..Failure(ex) }
}

ClassMethod RuleActivate() As %Status
{
    Try {
        Set body={}.%FromJSON(%request.Content)
        If '$IsObject(body) Do ##class(Demo.Protocol).Fail("Rule activation object required")
        If 'body.%IsA("%DynamicObject") Do ##class(Demo.Protocol).Fail("Rule activation object required")
        Return ..Reply(##class(Demo.RuleTarget).Activate(body))
    } Catch ex { Return ..Failure(ex) }
}

ClassMethod Failure(ex As %Exception.AbstractException) As %Status
{
    Set id = $Increment(^DemoMonitor("audit"))
    Set ^DemoMonitor("audit",id) = {"actor":($Username),"error":(ex.DisplayString()),"time":($ZDATETIME($ZTIMESTAMP,3,1,3))}.%ToJSON()
    Quit ..Reply({"message":"Connector operation rejected; inspect protected target audit"},"409 Conflict")
}
}
