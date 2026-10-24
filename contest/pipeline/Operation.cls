Class Contest.Aggregation.Operation Extends Ens.BusinessOperation
{
Parameter INVOCATION = "Queue";

Method OnMessage(request As Contest.Aggregation.SendRequest, Output response As Contest.Aggregation.Reply) As %Status
{
    Set locked=0, sending=0
    Try {
        If '$Match(request.BatchId,"^[A-Za-z0-9-]{1,64}$") Do ##class(Demo.Protocol).Fail("Bounded batch identity required")
        Lock +^ContestAggregation("sendLock",request.BatchId):2
        If '$Test Do ##class(Demo.Protocol).Fail("FHIR batch busy")
        Set locked=1
        If '$Data(^ContestAggregation("batch",request.BatchId)) Do ##class(Demo.Protocol).Fail("FHIR operation requires a prepared batch")
        Set record={}.%FromJSON(^ContestAggregation("batch",request.BatchId)), bundle={}.%FromJSON(request.Bundle)
        If (record.state'="prepared")||(record.bundle.%ToJSON()'=request.Bundle)||(record.%Get("approval_id")'=request.ApprovalId)||(record.%Get("scope_hash")'=request.ScopeHash) Do ##class(Demo.Protocol).Fail("Prepared batch mismatch or replay; no send")
        Set dossier=##class(Contest.Aggregation.Runtime).Approval(request.ApprovalId,request.ScopeHash), binding=##class(Contest.Aggregation.Runtime).Binding()
        If (record.%Get("config_hash")'=binding.%Get("config_hash"))||(record.%Get("output_hash")'=##class(Contest.Aggregation.Runtime).Digest(bundle)) Do ##class(Demo.Protocol).Fail("Configuration or prepared output changed before send")
        Set inspection=##class(Contest.Aggregation.Runtime).Inspect(bundle,dossier), record.state="sending"
        Do record.%Set("wire_hash",##class(Demo.Protocol).Hash($ZConvert(request.Bundle,"O","UTF8")))
        Do record.%Set("sending_at",##class(Demo.Protocol).Now())
        Set ^ContestAggregation("batch",request.BatchId)=record.%ToJSON(), sending=1
        Set result=##class(Contest.Aggregation.Runtime).Http("",request.Bundle)
        Do record.%Set("transaction_response",result)
        Set record.state="response_received", ^ContestAggregation("batch",request.BatchId)=record.%ToJSON()
        Do ##class(Contest.Aggregation.Mapping).ValidateResponse(bundle,result)
        Set readbacks=[], resources=[]
        For i=0:1:bundle.entry.%Size()-1 {
            Set expected=bundle.entry.%Get(i), actual=##class(Contest.Aggregation.Runtime).Http(expected.request.url)
            If '##class(Contest.Aggregation.Mapping).EqualValue(expected.resource,actual) Do ##class(Demo.Protocol).Fail("FHIR readback differs from mapped source values or references")
            Set transactionEntry=result.entry.%Get(i).response
            If transactionEntry.%IsDefined("etag") {
                If transactionEntry.etag'=("W/"""_actual.meta.versionId_"""") Do ##class(Demo.Protocol).Fail("FHIR resource version changed before readback")
            } Else {
                If actual.meta.versionId'=$Piece(transactionEntry.location,"/_history/",2) Do ##class(Demo.Protocol).Fail("FHIR history version changed before readback")
            }
            Do resources.%Push(actual)
            Do readbacks.%Push({"resource":(expected.request.url),"version":(actual.meta.versionId),"readback_hash":(##class(Contest.Aggregation.Runtime).Digest(actual)),"mapped_values_match":true})
        }
        Set receipt={"schema":1,"synthetic":true,"batch_id":(request.BatchId),"outcome":"delivered","message_id":(record.%Get("request_id")),"session_id":(record.%Get("session_id")),"send_message_id":(request.%Id()),"source_hash":(record.%Get("source_hash")),"output_hash":(record.%Get("output_hash")),"wire_hash":(record.%Get("wire_hash")),"config_hash":(record.%Get("config_hash")),"approval_id":(request.ApprovalId),"scope_hash":(request.ScopeHash),"inspection":(inspection),"readbacks":(readbacks),"verified_at":(##class(Demo.Protocol).Now()),"model_calls":0,"legal_authorization":"not_established"}
        Do receipt.%Set("receipt_hash",##class(Contest.Aggregation.Runtime).Digest(receipt))
        Set record.state="delivered"
        Do record.%Set("receipt",receipt), record.%Set("readback_resources",resources)
        Set ^ContestAggregation("batch",request.BatchId)=record.%ToJSON()
        Set response=##class(Contest.Aggregation.Reply).%New(), response.BatchId=request.BatchId, response.Outcome="delivered", response.Receipt=receipt.%ToJSON(), sc=$$$OK
    } Catch ex {
        Set sc=ex.AsStatus()
        If sending {
            Set record.state="reconciliation_required"
            Do record.%Set("error",ex.DisplayString())
            Set ^ContestAggregation("batch",request.BatchId)=record.%ToJSON()
        }
        $$$LOGERROR($SYSTEM.Status.GetErrorText(sc))
    }
    If locked Lock -^ContestAggregation("sendLock",request.BatchId)
    Quit sc
}
}
