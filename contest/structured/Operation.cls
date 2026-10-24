Class Contest.StructuredOperation Extends Ens.BusinessOperation
{
Method Receive(request As Contest.StructuredRequest, Output response As Contest.Aggregation.Reply) As %Status
{
    Try {
        If '$Match(request.BatchId,"^[A-Za-z0-9-]{1,64}$") Do ##class(Demo.Protocol).Fail("Bounded synthetic batch required")
        Set rs=##class(%SQL.Statement).%ExecDirect(,"INSERT INTO SQLUser.StructuredReceipt (BatchID,PayloadHash) VALUES (?,?)",request.BatchId,##class(Demo.Protocol).Hash(request.PayloadJson))
        If rs.%SQLCODE<0 Do ##class(Demo.Protocol).Fail("Synthetic receiver insert failed; no replay")
        Set response=##class(Contest.Aggregation.Reply).%New(), response.BatchId=request.BatchId, response.Outcome="delivered", response.Receipt="Local SQL write; observer must independently establish any delivery claims."
        Set sc=$$$OK
    } Catch ex { Set sc=ex.AsStatus() }
    Quit sc
}
XData MessageMap
{
<MapItems><MapItem MessageType="Contest.StructuredRequest"><Method>Receive</Method></MapItem></MapItems>
}
}
