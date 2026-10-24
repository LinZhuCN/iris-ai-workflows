Class Contest.M5.Process Extends Ens.BusinessProcess
{
Property Target As %String;
Parameter SETTINGS = "Target";
Method OnRequest(request As Contest.M5.Request, Output response As Contest.Aggregation.Reply) As %Status
{
    Quit ..SendRequestSync(..Target,request,.response,30)
}
}
