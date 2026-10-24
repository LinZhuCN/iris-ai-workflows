Class Demo.Sink Extends Ens.BusinessOperation
{
Parameter INVOCATION = "Queue";

Method OnMessage(request As Demo.Message, Output response As Demo.Reply) As %Status
{
    If request.Scenario = "failure" Quit $$$ERROR($$$GeneralError,"Synthetic destination unavailable; no external system called")
    Lock +^DemoBusiness("sink",request.ExternalId):2
    If '$Test Quit $$$ERROR($$$GeneralError,"Demo sink busy")
    Set ^DemoBusiness("sink",request.ExternalId) = request.Scenario
    Lock -^DemoBusiness("sink",request.ExternalId)
    Set response = ##class(Demo.Reply).%New(), response.Outcome = "delivered"
    Quit $$$OK
}
}
