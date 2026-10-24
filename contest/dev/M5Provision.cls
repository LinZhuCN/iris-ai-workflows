Class Contest.M5Provision
{
ClassMethod Foundation()
{
    If ($Namespace'="%SYS")||('$System.Security.Check("%Admin_Manage","U")) Throw ##class(%Exception.General).%New("Explicit local administration required")
    Set previous=$Namespace
    Try {
        If '##class(%SYS.Namespace).Exists("M5OBSERVATION") {
            Set $Namespace="HSLIB"
            Do ##class(HS.Util.Installer.Foundation).Install("M5OBSERVATION")
            Set $Namespace="M5OBSERVATION", ^ContestM5Install("owner")="iris-ai-workflows"
        }
        Set $Namespace="M5OBSERVATION"
        If $Get(^ContestM5Install("owner"))'="iris-ai-workflows" Throw ##class(%Exception.General).%New("M5 namespace ownership conflict")
    } Catch ex { Set $Namespace=previous Throw ex }
    Set $Namespace=previous
}
ClassMethod Install()
{
    If ($Namespace'="M5OBSERVATION")||($Get(^ContestM5Install("owner"))'="iris-ai-workflows") Throw ##class(%Exception.General).%New("Owned isolated M5 namespace required")
    If ##class(Ens.Director).IsProductionRunning(.name) {
        If name'="Contest.M5.Production" Throw ##class(%Exception.General).%New("Different active Production; no changes")
        Quit
    }
    For path="/contest/demo/Protocol.cls","/contest/pipeline/Reply.cls","/contest/m5/Request.cls","/contest/m5/Service.cls","/contest/m5/Process.cls","/contest/m5/Operation.cls","/contest/m5/Production.cls" {
        Set sc=$SYSTEM.OBJ.Load(path,"ck") $$$ThrowOnError(sc)
    }
    Set rs=##class(%SQL.Statement).%ExecDirect(,"SELECT COUNT(*) AS N FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA='SQLUser' AND TABLE_NAME='M5Receipt'")
    If rs.%SQLCODE<0 Throw ##class(%Exception.General).%New("M5 schema lookup failed: "_rs.%Message)
    Set next=rs.%Next()
    If rs.%Get("N")=0 {
        Set rs=##class(%SQL.Statement).%ExecDirect(,"CREATE TABLE SQLUser.M5Receipt (BatchID VARCHAR(64) PRIMARY KEY, MessageID BIGINT NOT NULL, Receiver VARCHAR(64) NOT NULL, PayloadHash VARCHAR(64) NOT NULL, ReceivedAt NUMERIC(20,6) NOT NULL)")
        If rs.%SQLCODE<0 Throw ##class(%Exception.General).%New("M5 receiver schema creation failed: "_rs.%Message)
    }
    Set sc=##class(Ens.Director).StartProduction("Contest.M5.Production") $$$ThrowOnError(sc)
}
}
