Class Contest.DeclarationReviewProcess Extends Ens.BusinessProcess
{
Method OnRequest(request As Contest.DeclarationReviewRequest, Output response As Contest.DeclarationReviewReply) As %Status
{
    Try {
        Set task=##class(Contest.DeclarationQueue).Execute(request,..%SessionId)
        Set response=##class(Contest.DeclarationReviewReply).%New()
        Set response.TaskId=task.id, response.Outcome=task.state, response.ReportId=task.runtime.%Get("report_id")
        Return $$$OK
    } Catch ex {
        Do ##class(Contest.KnowledgeService).Audit("declaration.bp.failed",request.TaskId,ex.DisplayString())
        Return ex.AsStatus()
    }
}
}
