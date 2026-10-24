Class Contest.MonitorInbox Extends Ens.BusinessService
{
Parameter ADAPTER = "Ens.InboundAdapter";

Method OnProcessInput(input As %RegisteredObject, Output output As %RegisteredObject) As %Status
{
    Try {
        Do ##class(Contest.MonitorService).Consume()
        Do ##class(Contest.RouteReview).Tick()
        Return $$$OK
    } Catch ex {
        Return ex.AsStatus()
    }
}
}
