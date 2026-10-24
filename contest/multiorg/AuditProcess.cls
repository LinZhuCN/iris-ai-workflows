Class Contest.Multi.AuditProcess Extends Ens.BusinessProcess
{
Method OnRequest(request As Contest.Multi.AuditRequest, Output response As Contest.Multi.Reply) As %Status
{
    Set previous=$Namespace
    Try {
        Set session=..%SessionId, message=request.%Id(), $Namespace="TRIAGE"
        If request.InspectOnly {
            Do ##class(Contest.MultiAudit).Preflight(request.RunId)
            Set outcome="preflight_passed"
        } Else {
            Do ##class(Contest.MultiAudit).Worker(request.RunId,session,message)
            Set record=##class(Contest.MultiOrganization).Read(request.RunId), outcome=record.%Get("audit_state")
        }
        Set $Namespace=previous
        Set response=##class(Contest.Multi.Reply).%New(), response.Outcome=outcome
        Return $$$OK
    } Catch ex {
        Set $Namespace=previous
        $$$LOGERROR(ex.DisplayString())
        Return ex.AsStatus()
    }
}
}
