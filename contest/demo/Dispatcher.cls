Class Demo.Dispatcher Extends Ens.BusinessService
{
Parameter ADAPTER = "Ens.InboundAdapter";

Method OnProcessInput(input As %RegisteredObject, Output output As %RegisteredObject) As %Status
{
    Set id = "", count = 0
    For {
        Set id = $Order(^DemoMonitor("pending",id))
        Quit:id=""  Quit:count>=10
        If $Get(^DemoMonitor("outbox",id,"next")) > ##class(Demo.Protocol).Now() Continue
        Set count = count+1
        Set message = ##class(Demo.Envelope).%New(), message.ObservationId = id
        Set sc = ..SendRequestSync("ObservationSender",message,.reply,5)
        If $System.Status.IsOK(sc) {
            TSTART
            Set ^DemoMonitor("outbox",id,"state") = "acknowledged"
            Kill ^DemoMonitor("pending",id)
            TCOMMIT
        } Else {
            Set ^DemoMonitor("outbox",id,"state") = "retrying"
            Set ^DemoMonitor("outbox",id,"error") = $System.Status.GetErrorText(sc)
            Set attempts = $Increment(^DemoMonitor("outbox",id,"attempts"))
            Set ^DemoMonitor("outbox",id,"next") = ##class(Demo.Protocol).Now()+$Select(attempts<5:2**attempts,1:30)
        }
    }
    Set ^DemoMonitor("heartbeat") = $ZDATETIME($ZTIMESTAMP,3,1,3)
    Set ^DemoMonitor("heartbeatSeconds") = ##class(Demo.Protocol).Now()
    Quit $$$OK
}
}
