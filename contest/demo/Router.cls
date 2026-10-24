Class Demo.Router Extends Ens.BusinessProcess
{
Method OnRequest(request As Demo.Message, Output response As Demo.Reply) As %Status
{
    Set facts=##class(Demo.Sampling).Facts(request.Scenario)
    Do facts.%Set("scenario",request.Scenario), facts.%Set("stage","before_send")
    Set gate = ##class(Demo.Gate).Inspect(facts)
    Set ^DemoBusiness("gate",request.ExternalId)=gate.%ToJSON()
    If gate.decision="hold_for_review" {
        Set outcome="held_for_review"
        Set ^DemoBusiness("held",request.ExternalId)={"message_id":(request.%Id()),"session_id":(..%SessionId),"bundle_hash":(gate.%Get("bundle_hash")),"scenario":(request.Scenario),"time":(##class(Demo.Protocol).Now())}.%ToJSON()
    } Else {
        Set target = $Select(request.Scenario = "treatment":"TreatmentSink",request.Scenario = "analytics":"AnalyticsSink",1:"FailureSink")
        Set sc = ..SendRequestSync(target,request,.sinkReply,5)
        Set outcome = $Select($System.Status.IsError(sc):"failed",1:"delivered")
    }
    Set response = ##class(Demo.Reply).%New(), response.Outcome = outcome
    Set response.MessageId = request.%Id(), response.SessionId = ..%SessionId
    Set response.ObservationId = ##class(Demo.Runtime).Capture(request,response)
    Quit $$$OK
}
}
