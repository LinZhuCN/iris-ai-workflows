Class Contest.Multi.Operation Extends Ens.BusinessOperation
{
Parameter INVOCATION = "Queue";

Method OnMessage(request As Contest.Multi.SendRequest, Output response As Contest.Multi.Reply) As %Status
{
    Try {
        Set record=##class(Contest.Multi.Runtime).Read(request.RunId), branch=""
        For i=0:1:record.branches.%Size()-1 If record.branches.%Get(i).id=request.Branch Set branch=record.branches.%Get(i)
        If '$IsObject(branch) Do ##class(Demo.Protocol).Fail("Unknown branch")
        If branch.state'="prepared" Do ##class(Demo.Protocol).Fail("Branch has already been attempted; no automatic replay")
        Set branch.state="attempted"
        Do branch.%Set("message_id",request.%Id(),"string"), branch.%Set("session_id",..%SessionId,"string")
        Do branch.%Set("payload_hash",##class(Demo.Protocol).Hash($ZConvert(request.Payload,"O","UTF8")))
        Do ##class(Contest.Multi.Runtime).Save(record)
        Set receipt={}.%FromJSON(##class(Contest.Multi.Runtime).Send(request.Branch,request.DeliveryId,request.Payload))
        If (receipt.%Get("payload_hash")'=branch.%Get("payload_hash"))||('receipt.%Get("readback_match")) Do ##class(Demo.Protocol).Fail("Actual receiver differs from transmitted payload")
        Do branch.%Set("receipt",receipt)
        Set branch.state="acknowledged"
        Do ##class(Contest.Multi.Runtime).Save(record)
        Set response=##class(Contest.Multi.Reply).%New(), response.Outcome="acknowledged"
        Set sc=$$$OK
    } Catch ex {
        $$$LOGERROR(ex.DisplayString())
        Set sc=ex.AsStatus()
    }
    Quit sc
}
}
