Class Contest.Utilization.Receiver Extends Ens.BusinessOperation
{
Parameter INVOCATION = "Queue";

Method OnMessage(request As Contest.Aggregation.SendRequest, Output response As Contest.Aggregation.Reply) As %Status
{
    Set locked=0, declarationKey=""
    Try {
        If '$Match(request.BatchId,"^[A-Za-z0-9-]{1,64}$") Do ##class(Demo.Protocol).Fail("Bounded utilization batch required")
        Lock +^ContestUtilization("receiverLock",request.BatchId):2
        If '$Test Do ##class(Demo.Protocol).Fail("Utilization receiver busy")
        Set locked=1
        Set bucket=##class(Contest.Utilization.Runtime).Bucket(request.ApprovalId)
        If '$Data(^ContestUtilization(bucket,request.BatchId)) Do ##class(Demo.Protocol).Fail("Prepared utilization batch required")
        Set record={}.%FromJSON(^ContestUtilization(bucket,request.BatchId))
        Do ##class(Contest.Utilization.Runtime).Prepared(record,request)
        If bucket="declarationBatch" {
            Set dossier=##class(Contest.Utilization.DeclarationBridge).Approval(request.ApprovalId,request.ScopeHash,request.BatchId,.declarationKey,1)
            If record.%Get("declaration_binding").%ToJSON()'=dossier.%Get("declaration_binding").%ToJSON() Do ##class(Demo.Protocol).Fail("Prepared declaration binding changed")
        } Else { Set dossier=##class(Contest.Utilization.Runtime).Approval(request.ApprovalId,request.ScopeHash,request.BatchId) }
        Set binding=##class(Contest.Utilization.Runtime).Binding()
        Set bundle={}.%FromJSON(request.Bundle), outputHash=##class(Contest.Aggregation.Runtime).Digest(bundle)
        If (outputHash'=record.%Get("output_hash"))||(binding.%Get("config_hash")'=record.%Get("config_hash")) Do ##class(Demo.Protocol).Fail("Utilization output or config changed")
        Set inspection=##class(Contest.Aggregation.Runtime).Inspect(bundle,dossier), now=##class(Demo.Protocol).Now()
        TStart
        Try {
            Set result=##class(%SQL.Statement).%ExecDirect(,"INSERT INTO SQLUser.UtilizationReceipt (BatchID,ScopeHash,OutputHash,Payload,ReceivedAt) VALUES (?,?,?,?,?)",request.BatchId,request.ScopeHash,outputHash,request.Bundle,now)
            Do ##class(Contest.Aggregation.Data).Check(result)
            Set read=##class(Contest.Utilization.Runtime).ReadReceiver(request.BatchId)
            If (read.payload.%ToJSON()'=request.Bundle)||(read.%Get("scope_hash")'=request.ScopeHash) Do ##class(Demo.Protocol).Fail("Downstream SQL readback mismatch")
            Set receipt={"schema":1,"synthetic":true,"batch_id":(request.BatchId),"outcome":"delivered","recipient":"local-analysis-receiver","transport":"same-instance-BO-to-SQL","source_pins":(record.%Get("source_pins")),"source_hash":(record.%Get("source_hash")),"output_hash":(outputHash),"config_hash":(record.%Get("config_hash")),"scope_hash":(request.ScopeHash),"approval_id":(request.ApprovalId),"message_id":(record.%Get("message_id")),"session_id":(record.%Get("session_id")),"receiver_message_id":(request.%Id()),"inspection":(inspection),"received_at":(now),"receiver_readback_match":true,"model_calls":0,"deidentification":"not_established","legal_authorization":"not_established"}
            If bucket="declarationBatch" Do receipt.%Set("declaration_binding",dossier.%Get("declaration_binding"))
            Do receipt.%Set("receipt_hash",##class(Contest.Aggregation.Runtime).Digest(receipt))
            Set record.state="delivered"
            Do record.%Set("receipt",receipt)
            Set ^ContestUtilization(bucket,request.BatchId)=record.%ToJSON()
            TCommit
        } Catch ex { TRollback 1 Throw ex }
        Set response=##class(Contest.Aggregation.Reply).%New(), response.BatchId=request.BatchId, response.Outcome="delivered", response.Receipt=receipt.%ToJSON(), sc=$$$OK
    } Catch ex {
        Set sc=ex.AsStatus()
        $$$LOGERROR($SYSTEM.Status.GetErrorText(sc))
    }
    Do ##class(Contest.Utilization.DeclarationBridge).Release(declarationKey)
    If locked Lock -^ContestUtilization("receiverLock",request.BatchId)
    Quit sc
}
}
