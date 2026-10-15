Class User.ContestDevProvision
{
ClassMethod Run()
{
    Set sc = $$$OK
    Try {
        Open "/contest/data/agentic-dev/password":"R":5
        If '$Test Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError,"Cannot read development password"))
        Use "/contest/data/agentic-dev/password" Read password
        Close "/contest/data/agentic-dev/password"
        Use $Principal
        If password = "" Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError,"Empty development password"))
        Set resources = "%Development:U,%DB_TRIAGE:RW,%DB_IRISLIB:R,%DB_ENSLIB:R,%DB_IRISTEMP:RW"
        If '##class(Security.Resources).Exists("%DB_TRIAGE") {
            Set sc = ##class(Security.Resources).Create("%DB_TRIAGE","Contest development database",0) $$$ThrowOnError(sc)
        }
        Set db = ##class(SYS.Database).%OpenId("/dur/irissys/mgr/triage/")
        Set db.ResourceName = "%DB_TRIAGE"
        Set sc = db.%Save() $$$ThrowOnError(sc)
        If '##class(Security.Roles).Exists("ContestDevelopment") {
            Set sc = ##class(Security.Roles).Create("ContestDevelopment","Development in isolated TRIAGE only",resources)
        } Else {
            Set role("Resources") = resources
            Set sc = ##class(Security.Roles).Modify("ContestDevelopment",.role)
        }
        $$$ThrowOnError(sc)
        If '##class(Security.Users).Exists("ContestDeveloper") {
            Set sc = ##class(Security.Users).Create("ContestDeveloper","ContestDevelopment",password,"Contest development MCP","TRIAGE",,,0,1)
        } Else {
            Set user("Password") = password, user("Roles") = "ContestDevelopment"
            Set sc = ##class(Security.Users).Modify("ContestDeveloper",.user)
        }
        $$$ThrowOnError(sc)
        Kill password,user
        Set $Namespace = "TRIAGE"
        Set ^UnitTestRoot = "/contest/dev"
        Write "DEV_ACCOUNT_READY",!
    } Catch ex {
        Use $Principal
        Write "DEV_PROVISION_FAILED: ",ex.DisplayString(),!
    }
}
}
