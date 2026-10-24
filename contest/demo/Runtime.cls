Class Demo.Runtime
{
ClassMethod Snapshot() As %DynamicObject
{
    If $Namespace '= "DEMO" Do ##class(Demo.Protocol).Fail("DEMO namespace required")
    Set running = ##class(Ens.Director).IsProductionRunning(.name)
    Set nodes = [], edges = [], unknown = [], config = [], compatible = 1
    Set expected("EnsLib.Testing.Service") = "EnsLib.Testing.Service", expected("EnsLib.Testing.Process") = "EnsLib.Testing.Process"
    Set expected("DemoRouter") = "Demo.Router", expected("ObservationDispatcher") = "Demo.Dispatcher", expected("ObservationSender") = "Demo.Sender"
    For sink = "TreatmentSink","AnalyticsSink","FailureSink" Set expected(sink) = "Demo.Sink"
    If name '= "" {
        Set production = ##class(Ens.Config.Production).%OpenId(name)
        If '$IsObject(production) Do ##class(Demo.Protocol).Fail("Production configuration unavailable")
        For i = 1:1:production.Items.Count() {
            Set item = production.Items.GetAt(i), settings = []
            For j = 1:1:item.Settings.Count() {
                Set setting = item.Settings.GetAt(j)
                Do settings.%Push({"target":(setting.Target),"name":(setting.Name),"value":(setting.Value)})
            }
            Do config.%Push({"name":(item.Name),"class":(item.ClassName),"enabled":(item.Enabled),"pool_size":(item.PoolSize),"settings":(settings)})
            Do nodes.%Push({"name":(item.Name),"class":(item.ClassName),"enabled":(item.Enabled),"pool_size":(item.PoolSize)})
            If $Get(expected(item.Name)) '= item.ClassName {
                Do unknown.%Push(item.Name)
                Set compatible = 0
            } Else {
                Set found(item.Name) = 1
                If 'item.Enabled || (item.PoolSize < 1) Set compatible = 0
            }
        }
    }
    Set required = ""
    For { Set required = $Order(expected(required)) Quit:required=""  If '$Data(found(required)) Set compatible = 0 }
    If (name = "Demo.Production") && compatible {
        For target = "TreatmentSink","AnalyticsSink","FailureSink" Do edges.%Push({"source":"DemoRouter","target":(target),"basis":"Pinned Demo.Router implementation; conditional synthetic scenario"})
        Do edges.%Push({"source":"ObservationDispatcher","target":"ObservationSender","basis":"Pinned Demo.Dispatcher implementation"})
    }
    Set hash = ##class(Demo.Protocol).Hash(config.%ToJSON())
    Set summary = $Select(compatible:"Three synthetic routes: treatment, analytics export and destination failure. Observation capture is local; delivery is asynchronous. This implementation description is deterministic, not an AI assessment.",1:"Configuration differs from the supported demo contract. Routing is not inferred; manual integration is required.")
    Quit {"instance_id":"local-demo","namespace":"DEMO","production":(name),"running":(running),"config_hash":(hash),"observer_revision":(+$Get(^DemoMonitor("revision"))),"nodes":(nodes),"edges":(edges),"unknown_routing":(unknown),"observed_at":($ZDATETIME($ZTIMESTAMP,3,1,3)),"capability_version":1,"supported":((name="Demo.Production")&&running&&compatible),"gate":"reviewed-bundle-capable; GET /rules/status for active revision","summary_kind":"deterministic","summary":(summary)}
}

ClassMethod Load(body As %DynamicObject) As %DynamicObject
{
    Lock +^DemoMonitor("deploymentLock"):2
    If '$Test Do ##class(Demo.Protocol).Fail("Deployment is busy")
    Try {
        Set snapshot = ..Snapshot()
        If 'snapshot.supported Do ##class(Demo.Protocol).Fail("Production requires manual integration")
        If snapshot.%Get("config_hash") '= body.%Get("expected_hash") Do ##class(Demo.Protocol).Fail("Stale Production configuration")
        Set previous = $Get(^DemoMonitor("loaded"))
        If previous '= "" {
            Set loaded = {}.%FromJSON(previous)
            If loaded.%Get("deployment_id") = body.%Get("deployment_id") {
                If loaded.digest '= body.digest Do ##class(Demo.Protocol).Fail("Deployment identity conflict")
                Lock -^DemoMonitor("deploymentLock")
                Return loaded
            }
            If snapshot.%Get("observer_revision") '= body.%Get("expected_revision") Do ##class(Demo.Protocol).Fail("Observer baseline changed; replan")
        }
        Set loaded = {"deployment_id":(body.%Get("deployment_id")),"digest":(body.digest),"snapshot_hash":(body.%Get("expected_hash")),"point":"route.complete","sample_rate":100,"loaded_at":($ZDATETIME($ZTIMESTAMP,3,1,3))}
        TSTART
        Set ^DemoMonitor("loaded") = loaded.%ToJSON()
        Set ^DemoMonitor("deployment",body.%Get("deployment_id")) = loaded.%ToJSON()
        Set ^DemoMonitor("revision") = $Increment(^DemoMonitor("revision"))
        TCOMMIT
    } Catch ex {
        Lock -^DemoMonitor("deploymentLock")
        Throw ex
    }
    Lock -^DemoMonitor("deploymentLock")
    Quit loaded
}

ClassMethod Submit(scenario As %String, key As %String) As %DynamicObject
{
    If (scenario '= "treatment") && (scenario '= "analytics") && (scenario '= "failure") Do ##class(Demo.Protocol).Fail("Unsupported synthetic scenario")
    Lock +^DemoBusiness("submit",key):2
    If '$Test Do ##class(Demo.Protocol).Fail("Submission is busy")
    Try {
        If $Data(^DemoBusiness("submitted",key)) {
            Set result = {}.%FromJSON(^DemoBusiness("submitted",key))
            If result.scenario '= scenario Do ##class(Demo.Protocol).Fail("Submission identity conflict")
        } Else {
            If $Data(^DemoBusiness("submissionState",key)) Do ##class(Demo.Protocol).Fail("Earlier submission is incomplete; automatic business replay is disabled")
            If '##class(Ens.Director).IsProductionRunning(.name) || (name '= "Demo.Production") Do ##class(Demo.Protocol).Fail("Demo Production is not running")
            Set ^DemoBusiness("submissionState",key) = "dispatching"
            Set request = ##class(Demo.Message).%New(), request.ExternalId = key, request.Scenario = scenario
            Set sc = ##class(EnsLib.Testing.Service).SendTestRequest("DemoRouter",request,.reply,.session,1) $$$ThrowOnError(sc)
            Set result = {"scenario":(scenario),"message_id":(reply.MessageId),"session_id":(reply.SessionId),"observation_id":(reply.ObservationId),"outcome":(reply.Outcome),"capture_state":($Select(reply.ObservationId="":"not_captured",1:"queued")),"synthetic":true}
            TSTART
            Set ^DemoBusiness("submitted",key) = result.%ToJSON(), ^DemoBusiness("submissionState",key) = "completed"
            TCOMMIT
        }
    } Catch ex {
        Lock -^DemoBusiness("submit",key)
        Throw ex
    }
    Lock -^DemoBusiness("submit",key)
    Quit result
}

ClassMethod Capture(request As Demo.Message, response As Demo.Reply) As %String
{
    Set id = "demo-"_##class(Demo.Protocol).Hash("local-demo|DEMO|route.complete|"_request.ExternalId)
    If $Data(^DemoMonitor("outbox",id,"body")) Quit id
    Set count = $Increment(^DemoMonitor("counters","seen"))
    If '$Data(^DemoMonitor("loaded")) {
        Set count = $Increment(^DemoMonitor("counters","not_monitored"))
        Quit ""
    }
    Lock +^DemoMonitor("capture"):2
    If '$Test {
        Set count = $Increment(^DemoMonitor("counters","dropped"))
        Quit ""
    }
    If $Data(^DemoMonitor("outbox",id,"body")) {
        Lock -^DemoMonitor("capture")
        Quit id
    }
    Set pending = 0, cursor = ""
    For { Set cursor = $Order(^DemoMonitor("pending",cursor)) Quit:cursor=""  Set pending = pending+1 }
    If '##class(Demo.Protocol).CanQueue(pending) {
        Set count = $Increment(^DemoMonitor("counters","dropped"))
        Lock -^DemoMonitor("capture")
        Quit ""
    }
    Try {
        Set loaded = {}.%FromJSON(^DemoMonitor("loaded"))
        Set day=+$Piece($ZTIMESTAMP,",",1), sampling=##class(Demo.Sampling).Config()
        Set selection=##class(Demo.Sampling).Select(id,request.Scenario,day,sampling)
        Set gate={"decision":"continue","bundle_hash":"","revision":0}
        If $Data(^DemoBusiness("gate",request.ExternalId)) Set gate={}.%FromJSON(^DemoBusiness("gate",request.ExternalId))
        Set body = {"schema":2,"instance_id":"local-demo","namespace":"DEMO","production":"Demo.Production","observation_id":(id),"message_id":(response.MessageId),"session_id":(response.SessionId),"scenario":(request.Scenario),"outcome":(response.Outcome),"deployment_id":(loaded.%Get("deployment_id")),"snapshot_hash":(loaded.%Get("snapshot_hash")),"point":"route.complete","synthetic":true,"source_day":(day),"sampling_revision":(sampling.revision),"review_selected":(selection.selected),"review_reason":(selection.reason),"facts":(##class(Demo.Sampling).Facts(request.Scenario)),"gate":(gate)}
        Do body.%Set("review_selected",selection.selected,"boolean")
        TSTART
        If selection.selected Set ^DemoMonitor("daily",day,"route.complete","analytics")=id
        Set ^DemoMonitor("outbox",id,"body") = body.%ToJSON(), ^DemoMonitor("outbox",id,"state") = "pending"
        Set ^DemoMonitor("pending",id) = 1
        TCOMMIT
    } Catch ex {
        Lock -^DemoMonitor("capture")
        Throw ex
    }
    Lock -^DemoMonitor("capture")
    Quit id
}

ClassMethod Transport() As %DynamicObject
{
    Set pending = 0, retrying = 0, id = "", lastError = ""
    For {
        Set id = $Order(^DemoMonitor("pending",id)) Quit:id=""
        Set pending = pending+1
        If $Get(^DemoMonitor("outbox",id,"state")) = "retrying" Set retrying = retrying+1, lastError = $Get(^DemoMonitor("outbox",id,"error"))
    }
    Set loaded = ""
    If $Data(^DemoMonitor("loaded")) Set loaded = {}.%FromJSON(^DemoMonitor("loaded"))
    Set age = ##class(Demo.Protocol).Now()-$Get(^DemoMonitor("heartbeatSeconds"))
    Quit {"pending":(pending),"retrying":(retrying),"last_error":(lastError),"seen":($Get(^DemoMonitor("counters","seen"),0)),"not_monitored":($Get(^DemoMonitor("counters","not_monitored"),0)),"dropped":($Get(^DemoMonitor("counters","dropped"),0)),"heartbeat":($Get(^DemoMonitor("heartbeat"))),"heartbeat_age_seconds":(age),"source_state":($Select(age<15:"live",1:"stale")),"loaded":(loaded)}
}
}
