Class Contest.DeclarationReviewService Extends Ens.BusinessService
{
Method OnProcessInput(input As Contest.DeclarationReviewRequest, Output output As Contest.DeclarationReviewReply) As %Status
{
    Quit ..SendRequestSync("DeclarationReviewProcess",input,.output,600)
}
}
