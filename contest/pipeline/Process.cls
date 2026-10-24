Class Contest.Aggregation.Process Extends Ens.BusinessProcess
{
Method OnRequest(request As Contest.Aggregation.Request, Output response As Contest.Aggregation.Reply) As %Status
{
    Set locked=0, started=0
    Try {
        If '$Match(request.BatchId,"^[A-Za-z0-9-]{1,64}$") Do ##class(Demo.Protocol).Fail("Bounded batch identity required")
        Lock +^ContestAggregation("batchLock",request.BatchId):2
        If '$Test Do ##class(Demo.Protocol).Fail("Aggregation batch busy")
        Set locked=1, dossier=##class(Contest.Aggregation.Runtime).Approval(request.ApprovalId,request.ScopeHash)
        Set source=##class(Contest.Aggregation.Data).Snapshot(), bundle=##class(Contest.Aggregation.Mapping).Build(source)
        Set inspection=##class(Contest.Aggregation.Runtime).Inspect(bundle,dossier), binding=##class(Contest.Aggregation.Runtime).Binding()
        Set sourceHash=##class(Contest.Aggregation.Runtime).Digest(source), outputHash=##class(Contest.Aggregation.Runtime).Digest(bundle)
        If $Data(^ContestAggregation("batch",request.BatchId)) {
            Set record={}.%FromJSON(^ContestAggregation("batch",request.BatchId))
            If (record.%Get("source_hash")'=sourceHash)||(record.%Get("output_hash")'=outputHash)||(record.%Get("scope_hash")'=request.ScopeHash)||(record.%Get("approval_id")'=request.ApprovalId)||(record.%Get("config_hash")'=binding.%Get("config_hash")) Do ##class(Demo.Protocol).Fail("Immutable batch scope conflict")
            If record.state'="delivered" Do ##class(Demo.Protocol).Fail("Batch incomplete or failed; automatic replay disabled")
            Set response=##class(Contest.Aggregation.Reply).%New(), response.BatchId=request.BatchId, response.Outcome="delivered", response.Receipt=record.receipt.%ToJSON()
        } Else {
            Set record={"batch_id":(request.BatchId),"state":"prepared","source":(source),"bundle":(bundle),"source_hash":(sourceHash),"output_hash":(outputHash),"config_hash":(binding.%Get("config_hash")),"config":(##class(Contest.Aggregation.Runtime).Config()),"binding":(binding),"approval_id":(request.ApprovalId),"scope_hash":(request.ScopeHash),"approval":(dossier.approval),"inspection":(inspection),"request_id":(request.%Id()),"session_id":(..%SessionId),"prepared_at":(##class(Demo.Protocol).Now())}
            Set ^ContestAggregation("batch",request.BatchId)=record.%ToJSON(), started=1
            Set send=##class(Contest.Aggregation.SendRequest).%New(), send.BatchId=request.BatchId, send.ApprovalId=request.ApprovalId, send.ScopeHash=request.ScopeHash, send.Bundle=bundle.%ToJSON()
            Set sc=..SendRequestSync("FHIRSender",send,.response,180) $$$ThrowOnError(sc)
            If response.Outcome'="delivered" Do ##class(Demo.Protocol).Fail("FHIR operation did not verify delivery")
        }
        Set sc=$$$OK
    } Catch ex {
        Set sc=ex.AsStatus()
        If started {
            Set record={}.%FromJSON(^ContestAggregation("batch",request.BatchId))
            If record.state'="delivered" {
                Set record.state="reconciliation_required"
                Do record.%Set("error",ex.DisplayString())
                Set ^ContestAggregation("batch",request.BatchId)=record.%ToJSON()
            }
        }
        $$$LOGERROR($SYSTEM.Status.GetErrorText(sc))
    }
    If locked Lock -^ContestAggregation("batchLock",request.BatchId)
    Quit sc
}
Storage Default
{
<Type>%Storage.Persistent</Type>
}
}
