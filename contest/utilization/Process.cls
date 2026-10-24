Class Contest.Utilization.Process Extends Ens.BusinessProcess
{
Method OnRequest(request As Contest.Aggregation.Request, Output response As Contest.Aggregation.Reply) As %Status
{
    Set locked=0, started=0
    Try {
        If '$Match(request.BatchId,"^[A-Za-z0-9-]{1,64}$") Do ##class(Demo.Protocol).Fail("Bounded utilization batch required")
        Lock +^ContestUtilization("batchLock",request.BatchId):2
        If '$Test Do ##class(Demo.Protocol).Fail("Utilization batch busy")
        Set locked=1, dossier=##class(Contest.Utilization.Runtime).Approval(request.ApprovalId,request.ScopeHash,request.BatchId)
        Set bucket=##class(Contest.Utilization.Runtime).Bucket(request.ApprovalId), other=$Select(bucket="batch":"declarationBatch",1:"batch")
        If $Data(^ContestUtilization(other,request.BatchId)) Do ##class(Demo.Protocol).Fail("Batch ID belongs to another utilization workflow")
        Set binding=##class(Contest.Utilization.Runtime).Binding()
        If $Data(^ContestUtilization(bucket,request.BatchId)) {
            Set record={}.%FromJSON(^ContestUtilization(bucket,request.BatchId))
            If (record.%Get("scope_hash")'=request.ScopeHash)||(record.%Get("approval_id")'=request.ApprovalId)||(record.%Get("config_hash")'=binding.%Get("config_hash")) Do ##class(Demo.Protocol).Fail("Immutable utilization task conflict")
            If record.state'="delivered" Do ##class(Demo.Protocol).Fail("Incomplete utilization batch; automatic replay disabled")
            Set downstream=##class(Contest.Utilization.Runtime).ReadReceiver(request.BatchId)
            If (downstream.%Get("output_hash")'=record.receipt.%Get("output_hash"))||(downstream.%Get("scope_hash")'=request.ScopeHash) Do ##class(Demo.Protocol).Fail("Historical receiver evidence changed")
            Set response=##class(Contest.Aggregation.Reply).%New(), response.BatchId=request.BatchId, response.Outcome="delivered", response.Receipt=record.receipt.%ToJSON()
        } Else {
            Set rows=##class(Contest.Utilization.Runtime).Source(.pins), bundle=##class(Contest.Utilization.Runtime).Project(rows)
            Set inspection=##class(Contest.Aggregation.Runtime).Inspect(bundle,dossier)
            Set record={"batch_id":(request.BatchId),"state":"prepared","config":(##class(Contest.Utilization.Runtime).Config()),"config_hash":(binding.%Get("config_hash")),"source_pins":(pins),"source":(rows),"source_hash":(##class(Contest.Aggregation.Runtime).Digest(rows)),"bundle":(bundle),"output_hash":(##class(Contest.Aggregation.Runtime).Digest(bundle)),"inspection":(inspection),"approval_id":(request.ApprovalId),"scope_hash":(request.ScopeHash),"approval":(dossier.approval),"message_id":(request.%Id()),"session_id":(..%SessionId),"prepared_at":(##class(Demo.Protocol).Now())}
            If dossier.%IsDefined("declaration_binding") Do record.%Set("declaration_binding",dossier.%Get("declaration_binding"))
            Set ^ContestUtilization(bucket,request.BatchId)=record.%ToJSON(), started=1
            Set send=##class(Contest.Aggregation.SendRequest).%New(), send.BatchId=request.BatchId, send.ApprovalId=request.ApprovalId, send.ScopeHash=request.ScopeHash, send.Bundle=bundle.%ToJSON()
            Set sc=..SendRequestSync("AnalysisReceiver",send,.response,30) $$$ThrowOnError(sc)
            If response.Outcome'="delivered" Do ##class(Demo.Protocol).Fail("Utilization receiver did not verify persistence")
        }
        Set sc=$$$OK
    } Catch ex {
        Set sc=ex.AsStatus()
        If started {
            Set record={}.%FromJSON(^ContestUtilization(bucket,request.BatchId))
            If record.state'="delivered" {
                Set record.state="reconciliation_required"
                Do record.%Set("error",ex.DisplayString())
                Set ^ContestUtilization(bucket,request.BatchId)=record.%ToJSON()
            }
        }
        $$$LOGERROR($SYSTEM.Status.GetErrorText(sc))
    }
    If locked Lock -^ContestUtilization("batchLock",request.BatchId)
    Quit sc
}
Storage Default
{
<Type>%Storage.Persistent</Type>
}
}
