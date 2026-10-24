Class Contest.M5.DemoRuntime
{
ClassMethod Send(id As %String, payloadJson As %String) As %DynamicObject
{
    If ($Namespace'="M5OBSERVATION")||($Get(^ContestM5Install("owner"))'="iris-ai-workflows") Do ##class(Demo.Protocol).Fail("Owned M5 namespace required")
    If '$Match(id,"^m5-demo-[A-Za-z0-9-]{1,48}$") Do ##class(Demo.Protocol).Fail("Bounded fixed demo identity required")
    Set payload={}.%FromJSON(payloadJson)
    Set request=##class(Contest.M5.Request).%New(), request.BatchId=id, request.Route="B", request.Format="json-object", request.PayloadJson=payload.%ToJSON()
    Set sc=##class(Ens.Director).CreateBusinessService("M5Source",.service) $$$ThrowOnError(sc)
    Set sc=service.ProcessInput(request,.reply) $$$ThrowOnError(sc)
    If reply.Outcome'="delivered" Do ##class(Demo.Protocol).Fail("M5 receiver did not acknowledge")
    Set rs=##class(%SQL.Statement).%ExecDirect(,"SELECT ID,SessionId FROM Ens.MessageHeader WHERE MessageBodyClassName=? AND MessageBodyId=? AND SourceConfigName='ProcessB' AND TargetConfigName='ReceiverB'","Contest.M5.Request",request.%Id())
    If rs.%SQLCODE<0 Do ##class(Demo.Protocol).Fail("M5 header query failed")
    If 'rs.%Next() Do ##class(Demo.Protocol).Fail("Actual receiver header missing")
    Set header=rs.%Get("ID"), session=rs.%Get("SessionId")
    If rs.%Next() Do ##class(Demo.Protocol).Fail("Ambiguous M5 receiver header")
    Set rs=##class(%SQL.Statement).%ExecDirect(,"SELECT MessageID,Receiver,PayloadHash FROM SQLUser.M5Receipt WHERE BatchID=?",id)
    If rs.%SQLCODE<0 Do ##class(Demo.Protocol).Fail("M5 receipt query failed")
    If 'rs.%Next() Do ##class(Demo.Protocol).Fail("Actual SQL receipt missing")
    Set hash=##class(Demo.Protocol).Hash($ZConvert(payload.%ToJSON(),"O","UTF8"))
    If (rs.%Get("MessageID")'=request.%Id())||(rs.%Get("Receiver")'="ReceiverB")||(rs.%Get("PayloadHash")'=hash) Do ##class(Demo.Protocol).Fail("M5 SQL receipt mismatch")
    Quit {"message_id":(request.%Id()_""),"session_id":(session_""),"header_id":(header_""),"receiver":"ReceiverB","payload_hash":(hash),"readback_match":true}
}
}
