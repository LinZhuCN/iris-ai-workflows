Class Contest.StructuredService Extends Ens.BusinessService
{
Method OnProcessInput(input As Contest.StructuredRequest, Output output As Contest.Aggregation.Reply) As %Status
{
    If '((input.Route="A")||(input.Route="B")||(input.Route="C")) Quit $$$ERROR($$$GeneralError,"Unknown local route")
    Quit ..SendRequestSync("Process"_input.Route,input,.output,30)
}
}
