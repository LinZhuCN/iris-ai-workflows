Class Contest.PipelineSummary
{
ClassMethod ValidResult(value As %DynamicObject) As %Boolean
{
    If '$IsObject(value) Quit 0
    If 'value.%IsA("%DynamicObject") Quit 0
    If (value.%Size() '= 2) || (value.%GetTypeOf("summary") '= "string") || (value.%GetTypeOf("limitations") '= "array") Quit 0
    If ($ZStrip(value.summary,"<>W") = "") || ($Length(value.summary) > 1200) Quit 0
    If value.limitations.%Size() > 5 Quit 0
    For i = 0:1:value.limitations.%Size()-1 {
        If value.limitations.%GetTypeOf(i) '= "string" Return 0
        If ($Length(value.limitations.%Get(i)) > 240) || ($ZStrip(value.limitations.%Get(i),"<>W") = "") Return 0
    }
    Quit 1
}

ClassMethod Facts(snapshot As %DynamicObject) As %DynamicObject
{
    Set routes = []
    For i = 0:1:snapshot.edges.%Size()-1 {
        Set edge = snapshot.edges.%Get(i)
        Do routes.%Push({"source":(edge.source),"target":(edge.target)})
    }
    Quit {"snapshot_id":(snapshot.id),"config_hash":(snapshot.%Get("config_hash")),"namespace":"DEMO","production":"Demo.Production","running":(snapshot.running),"component_count":(snapshot.nodes.%Size()),"confirmed_routes":(routes),"unknown_route_count":(snapshot.%Get("unknown_routing").%Size()),"business_data":"synthetic only","destinations":"local sinks, no external delivery","observer":"route.complete, local durable outbox, asynchronous HTTP to durable inbox","gate":"observe-only; no policy enforcement","evidence_basis":"actual configuration and pinned demo implementation; not runtime throughput or legal compliance evidence"}
}

ClassMethod Start(snapshotId As %String) As %String
{
    If snapshotId = "" Do ##class(Demo.Protocol).Fail("Snapshot identity is required")
    If '$Data(^ContestMonitor("snapshot",snapshotId)) Do ##class(Demo.Protocol).Fail("Snapshot not found")
    Set snapshot = {}.%FromJSON(^ContestMonitor("snapshot",snapshotId))
    If 'snapshot.supported Do ##class(Demo.Protocol).Fail("Only the supported synthetic demo may be summarized")
    If ($System.Util.GetEnviron("TRIAGE_MODE") '= "real") || ($System.Util.GetEnviron("TRIAGE_API_KEY") = "") Do ##class(Demo.Protocol).Fail("Real AI Hub provider is not configured")
    Lock +^ContestMonitor("summaryLock",snapshotId):2
    If '$Test Do ##class(Demo.Protocol).Fail("Summary scheduling is busy")
    Try {
        Set previous = $Get(^ContestMonitor("summaryFor",snapshotId))
        If previous '= "" {
            Set status = ..Status(previous)
            If (status.state = "queued") || (status.state = "running") Do ##class(Demo.Protocol).Fail("This snapshot already has a running summary")
        }
        Set id = "summary-"_$System.Util.CreateGUID()
        Set state = {"id":(id),"snapshot_id":(snapshotId),"config_hash":(snapshot.%Get("config_hash")),"state":"queued","model":($System.Util.GetEnviron("TRIAGE_MODEL")),"actor":($Username),"started":(##class(Demo.Protocol).Now()),"kind":"ai-hub-agent","max_agent_iterations":1}
        Set ^ContestMonitor("summary",id) = state.%ToJSON(), ^ContestMonitor("summaryFor",snapshotId) = id
        Job ##class(Contest.PipelineSummary).Run(id)::5
        If '$Test {
            Set state.state = "failed", state.error = "Unable to launch summary worker"
            Set ^ContestMonitor("summary",id) = state.%ToJSON()
            Do ##class(Demo.Protocol).Fail("Unable to launch summary worker")
        }
        Do ##class(Contest.KnowledgeService).Audit("pipeline.summary.queued",id,snapshotId)
    } Catch ex {
        Lock -^ContestMonitor("summaryLock",snapshotId)
        Throw ex
    }
    Lock -^ContestMonitor("summaryLock",snapshotId)
    Quit id
}

ClassMethod Run(id As %String)
{
    Set state = {}.%FromJSON(^ContestMonitor("summary",id))
    Try {
        Set state.state = "running", ^ContestMonitor("summary",id) = state.%ToJSON()
        Set snapshot = {}.%FromJSON(^ContestMonitor("snapshot",state.%Get("snapshot_id")))
        Set settings = {"api_key":($System.Util.GetEnviron("TRIAGE_API_KEY")),"base_url":($System.Util.GetEnviron("TRIAGE_PROVIDER_URL"))}
        Set provider = ##class(%AI.Provider).Create("openai",settings)
        Set settings = ""
        Set agent = ##class(%AI.Agent).%New(provider)
        Set agent.Model = state.model, agent.MaxIterations = 1, agent.ToolSets = ""
        Set agent.SystemPrompt = "You are a read-only pipeline explainer. Use only the supplied synthetic discovery facts. Never invent routes, throughput, privacy findings or legal conclusions. No tools or configuration changes are allowed. Return ONLY a JSON object with exactly summary (a nonempty string, at most 1200 characters, about 80 words) and limitations (an array of at most 5 nonempty strings, each at most 240 characters). Explain business routing and separate asynchronous observation transport. A destination-failure route is intentional. Mention that the snapshot does not prove current health and the Gate does not enforce rules."
        Set sc = agent.%Init() $$$ThrowOnError(sc)
        Set session = agent.CreateSession()
        Set sc = session.%Save() $$$ThrowOnError(sc)
        Do state.%Set("agent_session",session.%Id())
        Set ^ContestMonitor("summary",id) = state.%ToJSON()
        Set result = agent.Chat(session,..Facts(snapshot).%ToJSON())
        If $IsObject(result.Usage) Do state.%Set("usage",result.Usage)
        Set value = {}.%FromJSON(result.Content)
        If '..ValidResult(value) Do ##class(Demo.Protocol).Fail("AI Hub summary did not match the bounded output contract")
        Set state.result = value, state.state = "completed"
        Do state.%Set("completed",##class(Demo.Protocol).Now())
        Set ^ContestMonitor("summary",id) = state.%ToJSON()
        Do ##class(Contest.KnowledgeService).Audit("pipeline.summary.completed",id,state.%Get("snapshot_id"))
    } Catch ex {
        Set state.state = "failed", state.error = "AI Hub summary failed; no deterministic text was substituted"
        Set ^ContestMonitor("summary",id) = state.%ToJSON()
        Do ##class(Contest.KnowledgeService).Audit("pipeline.summary.failed",id,ex.DisplayString())
    }
}

ClassMethod Status(id As %String) As %DynamicObject
{
    If id = "" Quit ""
    If '$Data(^ContestMonitor("summary",id)) Quit ""
    Set state = {}.%FromJSON(^ContestMonitor("summary",id))
    If ((state.state = "queued") || (state.state = "running")) && ((##class(Demo.Protocol).Now()-state.started) > 180) {
        Set state.state = "interrupted", state.error = "No completion within 180 seconds. Inspect the job; do not assume a provider call was cancelled."
    }
    Quit state
}
}
