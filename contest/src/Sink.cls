Class Contest.Sink Extends Ens.BusinessOperation
{
Parameter INVOCATION = "Queue";

Method OnMessage(request As Contest.Reply, Output response As Contest.Reply) As %Status
{
    Set sc = $$$OK
    TSTART
    Try {
        Set record = ##class(Contest.Case).%OpenId(request.CaseId)
        If '$IsObject(record) Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError,"Unknown case at sink"))
        If record.Policy '= "allowed" Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError,"Sink requires policy approval"))
        Set action = record.Decision
        If (action '= "deliver") && (action '= "quarantine") && (action '= "human_review") Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError,"Invalid sink action"))
        Set destination = ##class(Contest.Destination).%New()
        Set destination.CaseId = request.CaseId, destination.Queue = action, destination.Payload = record.Payload
        Set sc = destination.%Save() $$$ThrowOnError(sc)
        Set record.Outcome = $Select(action = "deliver":"delivered",action = "quarantine":"quarantined",1:"pending_review")
        Set sc = record.%Save() $$$ThrowOnError(sc)
        Set sc = ##class(Contest.Event).Add(request.CaseId,"executed",record.Outcome) $$$ThrowOnError(sc)
        TCOMMIT
        Set response = ##class(Contest.Reply).%New()
        Set response.CaseId = request.CaseId, response.Outcome = record.Outcome
    } Catch ex {
        TROLLBACK
        Set sc = ex.AsStatus()
    }
    Quit sc
}
}
