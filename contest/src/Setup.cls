Class Contest.Setup
{
ClassMethod Start() As %Status
{
    Quit ##class(Contest.Startup).EnsureProduction("Contest.Production")
}

ClassMethod Submit(externalId As %String, payload As %String, Output caseId As %Integer) As %Status
{
    Set request = ##class(Contest.Request).%New()
    Set request.ExternalId = externalId, request.Payload = payload
    Set sc = ##class(EnsLib.Testing.Service).SendTestRequest("TriageProcess",request,.reply,.session,1)
    If $$$ISOK(sc), $IsObject(reply) Set caseId = reply.CaseId
    Quit sc
}
}
