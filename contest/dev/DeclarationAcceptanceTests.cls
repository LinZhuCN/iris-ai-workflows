Class Contest.DeclarationAcceptanceTests Extends Contest.DeclarationExecutionTests
{
Method TestControlledHistoricalDrift()
{
    If '$System.Security.Check("ContestMonitorDeploy","U") Quit
    Set id="", selected=""
    For {
        Set id=$Order(^ContestDeclarationExecution("run",id))
        If id="" Quit
        Set value=##class(Contest.DeclarationExecution).Load(id)
        If value.state="delivered" { Set selected=id Quit }
    }
    Do $$$AssertTrue(selected'="","D6 requires a genuinely delivered declaration batch")
    If selected="" Quit
    Set run=##class(Contest.DeclarationExecution).Read(selected), previous=$Namespace
    Try {
        Set $Namespace="UTILIZATION", batch=run.grant.%Get("batch_id"), raw=^ContestUtilization("declarationBatch",batch), baseline={}.%FromJSON(raw)
        Do ##class(Contest.Utilization.DeclarationBridge).Verify(run,baseline)
        For variant="recipient","field","source","config","decision","task","revision","message","time" {
            Set changed={}.%FromJSON(raw), rejected=0
            If variant="recipient" {
                Set changed.config.recipient="external-marketing-demo"
                Do changed.%Set("config_hash",##class(Contest.Aggregation.Runtime).Digest(changed.config)), changed.receipt.%Set("config_hash",changed.%Get("config_hash"))
            }
            If variant="field" {
                Set changed.bundle.entry.%Get(0).resource.name=[{"family":"SYNTHETIC-EXCESS"}]
                Do changed.%Set("output_hash",##class(Contest.Aggregation.Runtime).Digest(changed.bundle)), changed.receipt.%Set("output_hash",changed.%Get("output_hash"))
            }
            If variant="source" Set changed.source.%Get(0).birthDate="1970-01-01"
            If variant="config" Do changed.%Set("config_hash","wrong")
            If variant="decision" Do changed.receipt.%Get("declaration_binding").%Set("decision_hash","wrong")
            If variant="task" Do changed.receipt.%Get("declaration_binding").%Set("task_hash","wrong")
            If variant="revision" Set changed.receipt.%Get("declaration_binding").revision=99
            If variant="message" Do changed.%Set("message_id","missing"), changed.receipt.%Set("message_id","missing")
            If variant="time" Do changed.receipt.%Set("received_at",run.grant.record.proposal.validity.until)
            Try { Do ##class(Contest.Utilization.DeclarationBridge).Verify(run,changed) } Catch ex { Set rejected=1 }
            Do $$$AssertTrue(rejected,"Reject controlled "_variant_" drift without sending or persisting it")
        }
        Do $$$AssertEquals(^ContestUtilization("declarationBatch",batch),raw,"Original delivered evidence was never edited")
        Set receiver=##class(Contest.Utilization.Runtime).ReadReceiver(batch)
        Do $$$AssertEquals(receiver.%Get("output_hash"),baseline.%Get("output_hash"),"Original SQL output remains intact")
    } Catch ex { Set $Namespace=previous Throw ex }
    Set $Namespace=previous
}
}
