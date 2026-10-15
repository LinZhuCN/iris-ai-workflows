Class Contest.Setup
{
ClassMethod Start() As %Status
{
    If ##class(Ens.Director).IsProductionRunning(.name) {
        If name '= "Contest.Production" Quit $$$ERROR($$$GeneralError,"Another Production is already running in TRIAGE")
        Quit $$$OK
    }
    Quit ##class(Ens.Director).StartProduction("Contest.Production")
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
