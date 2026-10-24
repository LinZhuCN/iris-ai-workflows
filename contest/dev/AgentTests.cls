Class Contest.AgentTests Extends %UnitTest.TestProduction
{
Parameter PRODUCTION = "Contest.Production";

Method TestControl() As %Status
{
    Quit $$$OK
}

Method TestDraftContract()
{
    Set value = {"name":"Privacy reviewer","purpose":"Review synthetic analytics exports","retrieval_query":"HIPAA de-identification identifiers permitted uses"}
    Do $$$AssertTrue(##class(Contest.AgentService).ValidDraft(value))
    Set value.endpoint = "http://arbitrary"
    Do $$$AssertTrue('##class(Contest.AgentService).ValidDraft(value))
    Do value.%Remove("endpoint")
    Set value.purpose = ""
    Do $$$AssertTrue('##class(Contest.AgentService).ValidDraft(value))
}

Method TestResultContract()
{
    Set citations = {"evidence-1":true}
    Set value = {"assessment":"risk","reason":"Direct identifiers in an analytics export need review.","citations":["evidence-1"]}
    Do $$$AssertTrue(##class(Contest.AgentService).ValidResult(value,citations))
    Set value.assessment = "deliver"
    Do $$$AssertTrue('##class(Contest.AgentService).ValidResult(value,citations))
    Set value.assessment = "risk", value.citations = ["invented"]
    Do $$$AssertTrue('##class(Contest.AgentService).ValidResult(value,citations))
    Set value.citations = []
    Do $$$AssertTrue('##class(Contest.AgentService).ValidResult(value,citations))
}

Method TestFixturesAndIsolation()
{
    Do $$$AssertEquals(##class(Contest.AgentService).Fixture("risk").%Get("direct_identifiers"),1)
    Do $$$AssertEquals(##class(Contest.AgentService).Fixture("no_finding").%Get("deidentification_verified"),1)
    Do $$$AssertEquals(##class(Contest.AgentService).Fixture("insufficient_evidence").%Get("purpose_known"),0)
    Set rejected = 0
    Try { Set facts = ##class(Contest.PrivacyTools).ReadPrivacyFacts("unbound") }
    Catch ex { Set rejected = 1 }
    Do $$$AssertTrue(rejected,"Tools must reject calls outside a bound job")
}

Method TestPublishingGate()
{
    Set config = {"id":"test-version","config_hash":"abc","status":"draft"}
    Set report = {"kind":"test","config":{"id":"test-version"},"state":"completed","config_hash":"abc","passed":true}
    Do $$$AssertTrue(##class(Contest.AgentService).CanPublish(config,report))
    Do report.%Set("config_hash","old")
    Do $$$AssertTrue('##class(Contest.AgentService).CanPublish(config,report))
    Do report.%Set("config_hash","abc"), report.%Set("passed",0,"boolean")
    Do $$$AssertTrue('##class(Contest.AgentService).CanPublish(config,report))
    Do report.%Set("passed",1,"boolean")
    Set report.config.id="other-version"
    Do $$$AssertTrue('##class(Contest.AgentService).CanPublish(config,report))
}

Method TestVersionLifecycle()
{
    Set id="unit-"_$System.Util.CreateGUID(), reportId=id_"-report", level=$TLevel
    TStart
    Try {
        Set config={"id":(id),"revision":1,"status":"draft","name":"Synthetic unit version","purpose":"Review synthetic analytics","retrieval_query":"HIPAA de-identification","template":"privacy_review","table":"Contest.HIPAAIndex7","index_version":"7","corpus":"unit","model":"unit","max_iterations":4,"executor_version":"privacy-v1"}
        Do config.%Set("config_hash",##class(Contest.AgentService).ConfigHash(config))
        Set ^ContestAgents("config",id)=config.%ToJSON()
        Set rejected=0
        Try { Set result=##class(Contest.AgentService).Mutate("publish",{"id":(id),"revision":1}) }
        Catch ex { Set rejected=1 }
        Do $$$AssertTrue(rejected,"Untested draft cannot be published")
        Set report={"kind":"test","config":{"id":(id)},"state":"completed","config_hash":(config.%Get("config_hash")),"passed":true}
        Set ^ContestAgents("job",reportId)=report.%ToJSON(), ^ContestAgents("tested",id)=reportId
        Set edited=##class(Contest.AgentService).Mutate("edit",{"id":(id),"revision":1,"draft":{"name":"Changed","purpose":"Review synthetic analytics","retrieval_query":"HIPAA de-identification"}})
        Do $$$AssertTrue(edited.%Get("config_hash")'=config.%Get("config_hash"))
        Set rejected=0
        Try { Set result=##class(Contest.AgentService).Mutate("publish",{"id":(id),"revision":2}) }
        Catch ex { Set rejected=1 }
        Do $$$AssertTrue(rejected,"Changed draft cannot reuse old tests")
        Do report.%Set("config_hash",edited.%Get("config_hash"))
        Set ^ContestAgents("job",reportId)=report.%ToJSON(), ^ContestAgents("tested",id)=reportId
        Set published=##class(Contest.AgentService).Mutate("publish",{"id":(id),"revision":2})
        Do $$$AssertEquals(published.status,"published")
        Set rejected=0
        Try { Set result=##class(Contest.AgentService).Mutate("edit",{"id":(id),"revision":3,"draft":{"name":"Changed again","purpose":"Review","retrieval_query":"HIPAA"}}) }
        Catch ex { Set rejected=1 }
        Do $$$AssertTrue(rejected,"Published versions are immutable")
        Set ^ContestMonitor("snapshot",id)={"id":(id),"namespace":"DEMO","production":"Demo.Production","supported":true,"config_hash":"stale-unit-hash"}.%ToJSON()
        Set rejected=0
        Try { Set result=##class(Contest.AgentService).Mutate("bind",{"id":(id),"revision":3,"snapshot_id":(id)}) }
        Catch ex { Set rejected=1 }
        Do $$$AssertTrue(rejected,"Binding cannot accept a stale source configuration")
        Set ^ContestAgents("binding")={"agent_id":(id),"enabled":true}.%ToJSON()
        Set disabled=##class(Contest.AgentService).Mutate("disable",{"id":(id),"revision":3})
        Do $$$AssertEquals(disabled.status,"disabled")
        Set binding={}.%FromJSON(^ContestAgents("binding"))
        Do $$$AssertEquals(binding.enabled,0)
        TRollback 1
    } Catch ex {
        If $TLevel>level TRollback 1
        Throw ex
    }
}

Method TestPinnedIndexGuard()
{
    Set rejected=0
    Try { Set hits=##class(Contest.KnowledgeService).SearchVersion("HIPAA","Other.Table","7") }
    Catch ex { Set rejected=1 }
    Do $$$AssertTrue(rejected)
    Set rejected=0
    Try { Set hits=##class(Contest.KnowledgeService).SearchVersion("HIPAA","Contest.HIPAAIndex7","baseline-v1") }
    Catch ex { Set rejected=1 }
    Do $$$AssertTrue(rejected)
}

Method TestStartupScopeGuard()
{
    Set sc=##class(Contest.Startup).EnsureProduction("Not.TheManagedProduction")
    Do $$$AssertTrue($SYSTEM.Status.IsError(sc),"Startup cannot recover or replace an unrelated Production")
    Do $$$AssertTrue(##class(Ens.Director).IsProductionRunning(.name))
    Do $$$AssertEquals(name,"Contest.Production")
}

Method TestInterruptedJob()
{
    Set id="unit-job-"_$System.Util.CreateGUID()
    TStart
    Try {
        Set ^ContestAgents("job",id)={"id":(id),"state":"running","boot":"previous-server-run"}.%ToJSON()
        Set result=##class(Contest.AgentService).JobStatus(id)
        Do $$$AssertEquals(result.state,"interrupted")
        Set stored={}.%FromJSON(^ContestAgents("job",id))
        Do $$$AssertEquals(stored.state,"running","Status lookup does not launch or fake-complete a worker")
        TRollback 1
    } Catch ex {
        TRollback 1
        Throw ex
    }
}

Method TestConnectorPreservesDevice()
{
    Set device=$IO
    Set health=##class(Contest.MonitorService).Remote("health")
    Do $$$AssertEquals($IO,device,"Connector restores the caller's output device, including MCP test capture")
    Do $$$AssertEquals(health.%Get("instance_id"),"local-demo")
}
}
