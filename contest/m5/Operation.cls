Class Contest.M5.Operation Extends Ens.BusinessOperation
{
Method Receive(request As Contest.M5.Request, Output response As Contest.Aggregation.Reply) As %Status
{
    Try {
        If ('$Match(request.BatchId,"^m5-[A-Za-z0-9-]{1,60}$"))||(request.Format'="json-object") Do ##class(Demo.Protocol).Fail("Bounded synthetic M5 intake required")
        Set rs=##class(%SQL.Statement).%ExecDirect(,"INSERT INTO SQLUser.M5Receipt (BatchID,MessageID,Receiver,PayloadHash,ReceivedAt) VALUES (?,?,?,?,?)",request.BatchId,request.%Id(),..%ConfigName,##class(Demo.Protocol).Hash($ZConvert(request.PayloadJson,"O","UTF8")),##class(Demo.Protocol).Now())
        If rs.%SQLCODE<0 Do ##class(Demo.Protocol).Fail("Synthetic intake insert failed; no automatic replay")
        Set response=##class(Contest.Aggregation.Reply).%New(), response.BatchId=request.BatchId, response.Outcome="delivered", response.Receipt="Local synthetic intake only; later conduct is not observed."
        Set sc=$$$OK
    } Catch ex { Set sc=ex.AsStatus() }
    Quit sc
}
XData MessageMap
{
<MapItems><MapItem MessageType="Contest.M5.Request"><Method>Receive</Method></MapItem></MapItems>
}
}
