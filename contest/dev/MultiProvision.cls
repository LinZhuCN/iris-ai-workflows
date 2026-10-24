Class Contest.MultiProvision
{
ClassMethod Foundation()
{
    If ($Namespace'="%SYS")||('$System.Security.Check("%Admin_Manage","U")) Throw ##class(%Exception.General).%New("Explicit local administration required")
    Set previous=$Namespace
    Try {
        If '##class(%SYS.Namespace).Exists("DEMODISTRIBUTION") {
            Set $Namespace="HSLIB"
            Do ##class(HS.Util.Installer.Foundation).Install("DEMODISTRIBUTION")
            Set $Namespace="DEMODISTRIBUTION", ^ContestMultiInstall("owner")="iris-ai-workflows"
        }
        Set $Namespace="DEMODISTRIBUTION"
        If $Get(^ContestMultiInstall("owner"))'="iris-ai-workflows" Throw ##class(%Exception.General).%New("Distribution namespace ownership conflict")
    } Catch ex { Set $Namespace=previous Throw ex }
    Set $Namespace=previous
}

ClassMethod Install()
{
    If ($Namespace'="DEMODISTRIBUTION")||($Get(^ContestMultiInstall("owner"))'="iris-ai-workflows") Throw ##class(%Exception.General).%New("Owned distribution namespace required")
    Set running=##class(Ens.Director).IsProductionRunning(.name)
    If running {
        If name'="Contest.Multi.Production" Throw ##class(%Exception.General).%New("Unrelated Production occupies namespace")
        Quit
    }
    For path="/contest/demo/Protocol.cls","/contest/src/ExportEvidence.cls","/contest/multiorg/Request.cls","/contest/multiorg/SendRequest.cls","/contest/multiorg/Reply.cls","/contest/multiorg/Runtime.cls","/contest/multiorg/Service.cls","/contest/multiorg/Process.cls","/contest/multiorg/Operation.cls","/contest/multiorg/AuditRequest.cls","/contest/multiorg/AuditService.cls","/contest/multiorg/AuditProcess.cls","/contest/multiorg/Production.cls" {
        Set sc=$SYSTEM.OBJ.Load(path,"ck") $$$ThrowOnError(sc)
    }
    For key="DemoHospital","DemoQuality","DemoResearch","DemoClinic" {
        If '##class(Ens.Config.BusinessPartner).%ExistsId(key) {
            Set partner=##class(Ens.Config.BusinessPartner).%New(), partner.PartnerName=key, partner.Description="Synthetic multi-organization demonstration"
            Set sc=partner.%Save() $$$ThrowOnError(sc)
        }
    }
    Set sc=##class(Ens.Director).StartProduction("Contest.Multi.Production") $$$ThrowOnError(sc)
}
}
