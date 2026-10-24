Class Contest.Multi.Service Extends Ens.BusinessService
{
Method OnProcessInput(input As Contest.Multi.Request, Output output As Contest.Multi.Reply) As %Status
{
    Quit ..SendRequestSync("Distribute",input,.output,180)
}
}
