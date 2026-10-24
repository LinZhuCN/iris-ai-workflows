Class Contest.StructuredProvision
{
ClassMethod Foundation()
{
    If ($Namespace'="%SYS")||('$System.Security.Check("%Admin_Manage","U")) Throw ##class(%Exception.General).%New("Explicit local administration required")
    Set previous=$Namespace
    Try {
        If '##class(%SYS.Namespace).Exists("OBSERVATION") {
            Set $Namespace="HSLIB"
            Do ##class(HS.Util.Installer.Foundation).Install("OBSERVATION")
            Set $Namespace="OBSERVATION", ^ContestStructuredInstall("owner")="iris-ai-workflows"
        }
        Set $Namespace="OBSERVATION"
        If $Get(^ContestStructuredInstall("owner"))'="iris-ai-workflows" Throw ##class(%Exception.General).%New("OBSERVATION namespace ownership conflict")
    } Catch ex { Set $Namespace=previous Throw ex }
    Set $Namespace=previous
}

ClassMethod Install()
{
    If $Namespace'="OBSERVATION" Throw ##class(%Exception.General).%New("Isolated OBSERVATION installation required")
    If $Get(^ContestStructuredInstall("owner"))'="iris-ai-workflows" Throw ##class(%Exception.General).%New("Namespace ownership conflict")
    If ##class(Ens.Director).IsProductionRunning(.name) {
        If name'="Contest.StructuredProduction" Throw ##class(%Exception.General).%New("Different active Production; no changes made")
        Quit
    }
    For path="/contest/demo/Protocol.cls","/contest/pipeline/Reply.cls","/contest/structured/Request.cls","/contest/structured/Service.cls","/contest/structured/Process.cls","/contest/structured/Operation.cls","/contest/structured/Production.cls" {
        Set sc=$SYSTEM.OBJ.Load(path,"ck") $$$ThrowOnError(sc)
    }
    Set rs=##class(%SQL.Statement).%ExecDirect(,"SELECT COUNT(*) AS N FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA='SQLUser' AND TABLE_NAME='StructuredReceipt'")
    If rs.%SQLCODE<0 Throw ##class(%Exception.General).%New("Receiver schema lookup failed: "_rs.%Message)
    Set next=rs.%Next()
    If rs.%Get("N")=0 {
        Set rs=##class(%SQL.Statement).%ExecDirect(,"CREATE TABLE SQLUser.StructuredReceipt (BatchID VARCHAR(64) PRIMARY KEY, PayloadHash VARCHAR(64) NOT NULL)")
        If rs.%SQLCODE<0 Throw ##class(%Exception.General).%New("Receiver schema creation failed: "_rs.%Message)
    }
    Set sc=##class(Ens.Director).StartProduction("Contest.StructuredProduction") $$$ThrowOnError(sc)
}
}
