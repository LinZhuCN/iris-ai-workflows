Class Demo.Sender Extends Ens.BusinessOperation
{
Parameter INVOCATION = "Queue";

Method OnMessage(request As Demo.Envelope, Output response As Demo.Reply) As %Status
{
    Try {
        Set body = {}.%FromJSON(^DemoMonitor("outbox",request.ObservationId,"body"))
        Set receipt = ##class(Demo.Protocol).Call("/api/monitor/inbox/observations","ContestDemoSource",body)
        If receipt.%Get("observation_id") '= request.ObservationId Do ##class(Demo.Protocol).Fail("Observation receipt mismatch")
        Set response = ##class(Demo.Reply).%New(), response.Outcome = "accepted"
        Return $$$OK
    } Catch ex {
        Return ex.AsStatus()
    }
}
}
