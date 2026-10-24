Class User.ContestMonitorProvision
{
ClassMethod Run()
{
    Try {
        If $Namespace '= "%SYS" Do ##class(Demo.Protocol).Fail("Provisioning requires %SYS")
        Set directory = "/dur/irissys/mgr/demo/"
        If '##class(Config.Databases).Exists("DEMO") {
            If '##class(%File).CreateDirectoryChain(directory) Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError,"Cannot create DEMO directory"))
            Set sc = ##class(SYS.Database).CreateDatabase(directory) $$$ThrowOnError(sc)
            Set p("Directory") = directory
            Set sc = ##class(Config.Databases).Create("DEMO",.p) $$$ThrowOnError(sc)
        }
        If '##class(Config.Namespaces).Exists("DEMO") {
            Kill p
            Set p("Globals") = "DEMO", p("Routines") = "DEMO"
            Set sc = ##class(Config.Namespaces).Create("DEMO",.p) $$$ThrowOnError(sc)
        }
        Set sc = ##class(%EnsembleMgr).EnableNamespace("DEMO") $$$ThrowOnError(sc)
        If '##class(Security.Resources).Exists("%DB_DEMO") {
            Set sc = ##class(Security.Resources).Create("%DB_DEMO","Isolated synthetic DEMO database",0) $$$ThrowOnError(sc)
        }
        Set db = ##class(SYS.Database).%OpenId(directory)
        Set db.ResourceName = "%DB_DEMO"
        Set sc = db.%Save() $$$ThrowOnError(sc)
        For resource = "ContestMonitorRead","ContestMonitorDeploy","ContestConnectorRead","ContestConnectorDeploy","ContestObservationIngest" {
            If '##class(Security.Resources).Exists(resource) {
                Set sc = ##class(Security.Resources).Create(resource,"Local P2 capability",0) $$$ThrowOnError(sc)
            }
        }
        For role = "ContestKnowledgeReader","ContestKnowledgeBuilder" {
            Kill p
            Set sc = ##class(Security.Roles).Get(role,.p) $$$ThrowOnError(sc)
            If p("Resources") '[ "ContestMonitorRead:" Set p("Resources") = p("Resources")_",ContestMonitorRead:U"
            If (role = "ContestKnowledgeBuilder") && (p("Resources") '[ "ContestMonitorDeploy:") Set p("Resources") = p("Resources")_",ContestMonitorDeploy:U"
            Set sc = ##class(Security.Roles).Modify(role,.p) $$$ThrowOnError(sc)
        }
        For account = "ContestConnectorReader","ContestConnectorManager","ContestDemoSource" {
            Set role = account_"Role"
            Set resources = "%DB_IRISLIB:R,%DB_ENSLIB:R,%DB_IRISTEMP:RW,%Service_WebGateway:U"
            If account = "ContestDemoSource" {
                Set resources = resources_",%DB_TRIAGE:RW,ContestObservationIngest:U"
            } Else {
                Set resources = resources_",%DB_DEMO:RW,ContestConnectorRead:U"
                If account = "ContestConnectorManager" Set resources = resources_",ContestConnectorDeploy:U"
            }
            If '##class(Security.Roles).Exists(role) {
                Set sc = ##class(Security.Roles).Create(role,"Fixed local P2 machine identity",resources)
            } Else {
                Kill p
                Set p("Resources") = resources
                Set sc = ##class(Security.Roles).Modify(role,.p)
            }
            $$$ThrowOnError(sc)
            Set file = "/contest/data/platform/"_account_".password"
            Open file:"R":2
            If '$Test Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError,"Missing machine password file"))
            Use file Read password Close file Use $Principal
            If '##class(Security.Users).Exists(account) {
                Set sc = ##class(Security.Users).Create(account,role,password,"P2 machine identity","DEMO",,,0,1) $$$ThrowOnError(sc)
            }
            Kill password
        }
        For path = "/api/monitor/connector","/api/monitor/inbox" {
            Kill app
            Set app("NameSpace") = $Select(path = "/api/monitor/connector":"DEMO",1:"TRIAGE")
            Set app("DispatchClass") = $Select(path = "/api/monitor/connector":"Demo.Connector",1:"Contest.ObservationAPI")
            Set app("Resource") = $Select(path = "/api/monitor/connector":"ContestConnectorRead",1:"ContestObservationIngest")
            Set app("Enabled") = 1, app("AutheEnabled") = 32, app("UseCookies") = 0
            Set app("Type") = 2, app("Recurse") = 1, app("ServeFiles") = 0, app("CSPZENEnabled") = 1
            Set app("CSRFToken") = 0, app("CorsCredentialsAllowed") = 0
            If ##class(Security.Applications).Exists(path) {
                Set sc = ##class(Security.Applications).Modify(path,.app)
            } Else {
                Set sc = ##class(Security.Applications).Create(path,.app)
            }
            $$$ThrowOnError(sc)
        }
        Set $Namespace = "DEMO"
        Set sc = $SYSTEM.OBJ.LoadDir("/contest/demo","ck",,1) $$$ThrowOnError(sc)
        If ##class(Ens.Director).IsProductionRunning(.name) {
            If name '= "Demo.Production" Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError,"Another Production occupies DEMO"))
        } Else {
            Set sc = ##class(Ens.Director).StartProduction("Demo.Production") $$$ThrowOnError(sc)
        }
        Set $Namespace = "TRIAGE"
        Set sc = $SYSTEM.OBJ.Load("/contest/demo/Protocol.cls","ck") $$$ThrowOnError(sc)
        Set sc = $SYSTEM.OBJ.Load("/contest/demo/Sampling.cls","ck") $$$ThrowOnError(sc)
        Set sc = $SYSTEM.OBJ.Load("/contest/demo/RuleEngine.cls","ck") $$$ThrowOnError(sc)
        For file = "PrivacyTools","PrivacyToolSet","BusinessTools","BusinessToolSet","BusinessReview","BusinessReviewV2","BusinessToolsV2","BusinessToolSetV2","BusinessReviewV3","BusinessToolsV3","BusinessToolSetV3","BusinessReviewV4","BusinessToolsV4","BusinessToolSetV4","AgentService","EventService","PrivacyEvaluation","RiskEvidence","RiskReview","RiskReviewV2","RiskReviewV3","ExportEvidence","RouteGovernance","RuleService","PipelineSummary","MonitorService","MonitorInbox","ObservationAPI","KnowledgeAPI" {
            Set sc = $SYSTEM.OBJ.Load("/contest/src/"_file_".cls","ck") $$$ThrowOnError(sc)
        }
        Set production = ##class(Ens.Config.Production).%OpenId("Contest.Production"), found = 0
        For i = 1:1:production.Items.Count() {
            Set item = production.Items.GetAt(i)
            If item.Name = "PlatformMonitorInbox" {
                If item.ClassName '= "Contest.MonitorInbox" Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError,"Owned monitor item name conflict"))
                Set found = 1
            }
        }
        If 'found {
            Set item = ##class(Ens.Config.Item).%New(), item.Name = "PlatformMonitorInbox"
            Set item.ClassName = "Contest.MonitorInbox", item.Enabled = 1, item.PoolSize = 1
            Do production.Items.Insert(item)
            Set sc = production.%Save() $$$ThrowOnError(sc)
            Set sc = ##class(Ens.Director).UpdateProduction() $$$ThrowOnError(sc)
        }
        Use $Principal Write "MONITOR_READY",!
    } Catch ex {
        Use $Principal Write "MONITOR_PROVISION_FAILED: ",ex.DisplayString(),!
    }
}
}
