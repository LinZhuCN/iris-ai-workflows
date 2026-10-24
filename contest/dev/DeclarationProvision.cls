Class Contest.DeclarationProvision
{
ClassMethod Activate()
{
    If ($Namespace'="TRIAGE")||('$System.Security.Check("%Admin_Manage","U")) Do ##class(Demo.Protocol).Fail("Local TRIAGE administration required")
    Set production=##class(Ens.Config.Production).%OpenId("Contest.Production")
    If '$IsObject(production) Do ##class(Demo.Protocol).Fail("Existing Contest Production required")
    Set sc=##class(Ens.Director).GetProductionStatus(.name,.state) $$$ThrowOnError(sc)
    If (name'="Contest.Production")||(state'=1) Do ##class(Demo.Protocol).Fail("Existing Contest Production must already be running")
    If ##class(Ens.Director).ProductionNeedsUpdate(.reason) Do ##class(Demo.Protocol).Fail("Unrelated pending Production changes must be resolved before adding declaration hosts: "_reason)
    For host="DeclarationReviewService","DeclarationReviewProcess" {
        Set item=""
        For i=1:1:production.Items.Count() {
            If production.Items.GetAt(i).Name=host Set item=production.Items.GetAt(i)
        }
        If $IsObject(item) {
            If (item.ClassName'=("Contest."_host))||('item.Enabled)||(item.PoolSize'=1) Do ##class(Demo.Protocol).Fail("Unexpected existing declaration host configuration")
        } Else {
            Set item=##class(Ens.Config.Item).%New()
            Set item.Name=host, item.ClassName="Contest."_host, item.Enabled=1, item.PoolSize=1
            Do production.Items.Insert(item)
        }
    }
    Set sc=production.%Save() $$$ThrowOnError(sc)
    Set sc=production.SaveToClass() $$$ThrowOnError(sc)
    Set sc=##class(Ens.Director).UpdateProduction(30,0) $$$ThrowOnError(sc)
    Do ##class(Contest.KnowledgeService).Audit("declaration.hosts.enabled","Contest.Production","Two new declaration hosts only; no Production restart")
}
}
