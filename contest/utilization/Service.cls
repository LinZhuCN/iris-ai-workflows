Class Contest.Utilization.Service Extends Ens.BusinessService
{
Method OnProcessInput(input As Contest.Aggregation.Request, Output output As Contest.Aggregation.Reply) As %Status
{
    Quit ..SendRequestSync("UtilizationProcess",input,.output,120)
}
}
