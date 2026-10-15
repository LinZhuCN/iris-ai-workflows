Class User.ContestInstaller
{
ClassMethod Run()
{
    Try {
        Open "/run/secrets/gateway-password":"R":5
        If '$Test Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError,"Cannot read Gateway credential file"))
        Use "/run/secrets/gateway-password" Read password
        Close "/run/secrets/gateway-password"
        Use $Principal
        If password = "" Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError,"Gateway credential file is empty"))
        If '##class(Security.Users).Exists("ContestGateway") {
            Set sc = ##class(Security.Users).Create("ContestGateway","",password,"Local demo Gateway service","%SYS",,,0,1)
        } Else {
            Set user("Password") = password
            Set sc = ##class(Security.Users).Modify("ContestGateway",.user)
        }
        $$$ThrowOnError(sc)
        Kill password,user
        Set directory = "/dur/irissys/mgr/triage/"
        If '##class(Config.Databases).Exists("TRIAGE") {
            If '##class(%File).CreateDirectoryChain(directory) Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError,"Cannot create TRIAGE database directory"))
            Set sc = ##class(SYS.Database).CreateDatabase(directory) $$$ThrowOnError(sc)
            Set p("Directory") = directory
            Set sc = ##class(Config.Databases).Create("TRIAGE",.p) $$$ThrowOnError(sc)
        }
        If '##class(Config.Namespaces).Exists("TRIAGE") {
            Kill p
            Set p("Globals") = "TRIAGE", p("Routines") = "TRIAGE"
            Set sc = ##class(Config.Namespaces).Create("TRIAGE",.p) $$$ThrowOnError(sc)
        }
        Set sc = ##class(%EnsembleMgr).EnableNamespace("TRIAGE") $$$ThrowOnError(sc)
        ZN "TRIAGE"
        Set sc = $SYSTEM.OBJ.LoadDir("/contest/src","ck",,1) $$$ThrowOnError(sc)
        Set sc = ##class(Contest.Setup).Start() $$$ThrowOnError(sc)
        Open "/tmp/triage-ready":"WNS"
        Use "/tmp/triage-ready" Write "ready",!
        Close "/tmp/triage-ready"
    } Catch ex {
        Use $Principal
        Write "TRIAGE_SETUP_FAILED: ",ex.DisplayString(),!
    }
}
}
