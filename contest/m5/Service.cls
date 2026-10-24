Class Contest.M5.Service Extends Ens.BusinessService
{
Method OnProcessInput(input As Contest.M5.Request, Output output As Contest.Aggregation.Reply) As %Status
{
    If '$Match(input.Route,"^[ABCD]$") Quit $$$ERROR($$$GeneralError,"Unknown synthetic route")
    Quit ..SendRequestSync("Process"_input.Route,input,.output,30)
}
}
