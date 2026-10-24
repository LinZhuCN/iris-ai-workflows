Class User.ContestPlatformProvision
{
ClassMethod Run()
{
    Try {
        For name = "ContestKnowledgeRead","ContestKnowledgeBuild" {
            If '##class(Security.Resources).Exists(name) {
                Set sc = ##class(Security.Resources).Create(name,"Local knowledge platform capability",0) $$$ThrowOnError(sc)
            }
        }
        Set resources = "ContestKnowledgeRead:U,%DB_TRIAGE:RW,%DB_IRISLIB:R,%DB_ENSLIB:R,%DB_IRISTEMP:RW,%Service_WebGateway:U"
        For role = "ContestKnowledgeReader","ContestKnowledgeBuilder" {
            Set r = resources
            If role = "ContestKnowledgeBuilder" Set r = r_",ContestKnowledgeBuild:U"
            If ##class(Security.Resources).Exists("ContestMonitorRead") Set r = r_",ContestMonitorRead:U"
            If (role = "ContestKnowledgeBuilder") && ##class(Security.Resources).Exists("ContestMonitorDeploy") Set r = r_",ContestMonitorDeploy:U"
            If '##class(Security.Roles).Exists(role) {
                Set sc = ##class(Security.Roles).Create(role,"Isolated demo knowledge platform",r)
            } Else {
                Set properties("Resources") = r
                Set sc = ##class(Security.Roles).Modify(role,.properties)
            }
            $$$ThrowOnError(sc)
            Kill properties
        }
        For account = "ContestViewer","ContestKnowledgeAdmin" {
            Set file = "/contest/data/platform/"_account_".password"
            Open file:"R":5
            If '$Test Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError,"Missing platform password file"))
            Use file Read password Close file Use $Principal
            If password = "" Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError,"Empty platform password"))
            Set role = $Select(account = "ContestViewer":"ContestKnowledgeReader",1:"ContestKnowledgeBuilder")
            If '##class(Security.Users).Exists(account) {
                Set sc = ##class(Security.Users).Create(account,role,password,"Local platform demo","TRIAGE",,,0,1)
            } Else {
                Set user("Roles") = role
                Set sc = ##class(Security.Users).Modify(account,.user)
            }
            $$$ThrowOnError(sc)
            Kill password,user
        }
        Set app("NameSpace") = "TRIAGE", app("DispatchClass") = "Contest.KnowledgeAPI"
        Set app("Enabled") = 1, app("AutheEnabled") = 32, app("UseCookies") = 0
        Set app("Resource") = "ContestKnowledgeRead", app("Type") = 2
        Set app("Recurse") = 1, app("ServeFiles") = 0, app("CSPZENEnabled") = 1
        Set app("CSRFToken") = 0, app("CorsCredentialsAllowed") = 0
        If ##class(Security.Applications).Exists("/api/monitor/v1") {
            Set sc = ##class(Security.Applications).Modify("/api/monitor/v1",.app)
        } Else {
            Set sc = ##class(Security.Applications).Create("/api/monitor/v1",.app)
        }
        $$$ThrowOnError(sc)
        Set $Namespace = "TRIAGE"
        Set rs = $System.SQL.Execute("GRANT %CREATE_TABLE TO ContestKnowledgeBuilder")
        If rs.%SQLCODE < 0 Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError,rs.%Message))
        Set tables = $System.SQL.Execute("SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA='Contest'")
        If tables.%SQLCODE < 0 Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError,tables.%Message))
        While tables.%Next() {
            Set name = "Contest."_tables.%Get("TABLE_NAME")
            Set base = $Piece(name,"_Config",1)
            If '##class(Contest.KnowledgeService).ValidTable(base) Continue
            If (name '= base) && (name '= base_"_Config") Continue
            Set sql = "GRANT SELECT ON "_name_" TO ContestKnowledgeReader,ContestKnowledgeBuilder"
            Set rs = $System.SQL.Execute(sql)
            If rs.%SQLCODE < 0 Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError,rs.%Message))
        }
        Open "/contest/data/platform/corpus.sha256":"R":5
        If '$Test Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError,"Missing corpus fingerprint"))
        Use "/contest/data/platform/corpus.sha256" Read fingerprint Close "/contest/data/platform/corpus.sha256" Use $Principal
        Set ^ContestPlatform("corpus") = fingerprint
        Write "PLATFORM_READY",!
    } Catch ex {
        Use $Principal
        Write "PLATFORM_PROVISION_FAILED: ",ex.DisplayString(),!
    }
}
}
