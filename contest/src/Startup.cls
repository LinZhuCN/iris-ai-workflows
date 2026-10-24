Include Ensemble

Class Contest.Startup
{
ClassMethod EnsureProduction(expected As %String) As %Status
{
    Set sc=##class(Ens.Director).GetProductionStatus(.name,.state)
    If $$$ISERR(sc) Quit sc
    If (state'=$$$eProductionStateStopped) && (name'=expected) Quit $$$ERROR($$$GeneralError,"Another Production occupies the demo namespace; refusing recovery")
    If state=$$$eProductionStateRunning Quit $$$OK
    If state=$$$eProductionStateSuspended Quit $$$ERROR($$$GeneralError,"Production is intentionally suspended; manual resume required")
    If state=$$$eProductionStateTroubled {
        Write "Recovering unclean Production state for ",expected,!
        Set sc=##class(Ens.Director).RecoverProduction()
        If $$$ISERR(sc) Quit sc
    }
    Quit ##class(Ens.Director).StartProduction(expected)
}
}
