Class Contest.Multi.AuditService Extends Ens.BusinessService
{
Method OnProcessInput(input As Contest.Multi.AuditRequest, Output output As Contest.Multi.Reply) As %Status
{
    Quit ..SendRequestSync("AdvisoryAudit",input,.output,600)
}
}
