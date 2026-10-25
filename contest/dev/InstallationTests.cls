Class Contest.InstallationTests Extends %UnitTest.TestProduction
{
Parameter PRODUCTION = "Contest.Production";

Method TestControl() As %Status
{
    Quit $$$OK
}

Method TestDedicatedDatabaseResource()
{
    Set previous=$Namespace
    Try {
        Set $Namespace="%SYS"
        Set exists=##class(Security.Resources).Exists("%DB_TRIAGE")
        Set db=##class(SYS.Database).%OpenId("/dur/irissys/mgr/triage/")
        Set resource=db.ResourceName
        Set $Namespace=previous
    } Catch ex {
        Set $Namespace=previous
        Throw ex
    }
    Do $$$AssertTrue(exists,"Runtime installation must provision its database resource without development tools")
    Do $$$AssertEquals(resource,"%DB_TRIAGE","Platform roles must refer to the actual TRIAGE database resource")
}
}
