Class User.ContestInstaller
{
ClassMethod Run()
{
    Try {
        If ##class(%File).Exists("/contest/data/portal-admin-password") {
            Set sc=$SYSTEM.OBJ.Load("/contest/PortalAdmin.cls","ck") $$$ThrowOnError(sc)
            Do ##class(User.ContestPortalAdmin).Apply()
        }
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
        Set ^ContestAgents("boot") = $System.Util.CreateGUID()
        Set sc = ##class(Contest.Setup).Start() $$$ThrowOnError(sc)
        ZN "%SYS"
        If ##class(Config.Namespaces).Exists("DEMO") {
            ZN "DEMO"
            If ##class(%Dictionary.ClassDefinition).%ExistsId("Demo.Production") {
                Set sc = $SYSTEM.OBJ.Load("/contest/src/Startup.cls","ck") $$$ThrowOnError(sc)
                Set sc = ##class(Contest.Startup).EnsureProduction("Demo.Production") $$$ThrowOnError(sc)
            }
        }
        ZN "%SYS"
        If ##class(Config.Namespaces).Exists("PIPELINE") {
            ZN "PIPELINE"
            If ($Get(^ContestAggregationInstall("owner"))="iris-ai-workflows") && ##class(%Dictionary.ClassDefinition).%ExistsId("Contest.Aggregation.Production") {
                Set sc = $SYSTEM.OBJ.Load("/contest/src/Startup.cls","ck") $$$ThrowOnError(sc)
                Set sc = ##class(Contest.Startup).EnsureProduction("Contest.Aggregation.Production") $$$ThrowOnError(sc)
            }
        }
        ZN "%SYS"
        If ##class(Config.Namespaces).Exists("UTILIZATION") {
            ZN "UTILIZATION"
            If ($Get(^ContestUtilizationInstall("owner"))="iris-ai-workflows") && ##class(%Dictionary.ClassDefinition).%ExistsId("Contest.Utilization.Production") {
                Set sc = $SYSTEM.OBJ.Load("/contest/src/Startup.cls","ck") $$$ThrowOnError(sc)
                Set sc = ##class(Contest.Startup).EnsureProduction("Contest.Utilization.Production") $$$ThrowOnError(sc)
            }
        }
        ZN "%SYS"
        If ##class(Config.Namespaces).Exists("M5OBSERVATION") {
            ZN "M5OBSERVATION"
            If ($Get(^ContestM5Install("owner"))="iris-ai-workflows") && ##class(%Dictionary.ClassDefinition).%ExistsId("Contest.M5.Production") {
                Set sc = $SYSTEM.OBJ.Load("/contest/src/Startup.cls","ck") $$$ThrowOnError(sc)
                Set sc = ##class(Contest.Startup).EnsureProduction("Contest.M5.Production") $$$ThrowOnError(sc)
            }
        }
        ZN "%SYS"
        If ##class(Config.Namespaces).Exists("DEMOCLINIC") {
            ZN "DEMOCLINIC"
            If ($Get(^MultiOrgReceiverInstall("owner"))="multi-organization-receivers-v1") && ##class(%Dictionary.ClassDefinition).%ExistsId("MultiOrg.Receiver.API") {
                Do ##class(MultiOrg.Receiver.API).StartIfNeeded()
            }
        }
        ZN "%SYS"
        If ##class(Config.Namespaces).Exists("DEMODISTRIBUTION") {
            ZN "DEMODISTRIBUTION"
            If ($Get(^ContestMultiInstall("owner"))="iris-ai-workflows") && ##class(%Dictionary.ClassDefinition).%ExistsId("Contest.Multi.Production") {
                Set sc = $SYSTEM.OBJ.Load("/contest/src/Startup.cls","ck") $$$ThrowOnError(sc)
                Set sc = ##class(Contest.Startup).EnsureProduction("Contest.Multi.Production") $$$ThrowOnError(sc)
            }
        }
        ZN "TRIAGE"
        Open "/tmp/triage-ready":"WNS"
        Use "/tmp/triage-ready" Write "ready",!
        Close "/tmp/triage-ready"
    } Catch ex {
        Use $Principal
        Write "TRIAGE_SETUP_FAILED: ",ex.DisplayString(),!
    }
}
}
