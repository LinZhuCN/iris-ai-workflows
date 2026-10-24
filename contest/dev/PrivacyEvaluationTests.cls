Class Contest.PrivacyEvaluationTests Extends %UnitTest.TestProduction
{
Parameter PRODUCTION = "Contest.Production";
Method TestControl() As %Status { Quit $$$OK }

Method TestFixedManifest()
{
    Set cases=##class(Contest.PrivacyEvaluation).Cases(), ids={}, counts={}
    Do $$$AssertEquals(cases.%Size(),12)
    For i=0:1:cases.%Size()-1 {
        Set item=cases.%Get(i)
        Do $$$AssertTrue('ids.%IsDefined(item.id))
        Do ids.%Set(item.id,1)
        Do $$$AssertTrue(item.facts.synthetic)
        Do $$$AssertTrue('item.facts.%IsDefined("expected"),"Expected labels must not be supplied as facts")
        Do counts.%Set(item.expected,1+counts.%Get(item.expected))
    }
    Do $$$AssertEquals(counts.risk,3)
    Do $$$AssertEquals(counts.%Get("no_finding"),3)
    Do $$$AssertEquals(counts.%Get("insufficient_evidence"),6)
}

Method TestConsentAndBudget()
{
    Do $$$AssertTrue(##class(Contest.PrivacyEvaluation).ValidStart({"agent_id":"published","request_key":"unit-evaluation","acknowledge_cost":true,"max_model_requests":48}))
    Do $$$AssertTrue('##class(Contest.PrivacyEvaluation).ValidStart({"agent_id":"published","request_key":"unit-evaluation","acknowledge_cost":false,"max_model_requests":48}))
    Do $$$AssertTrue('##class(Contest.PrivacyEvaluation).ValidStart({"agent_id":"published","request_key":"unit-evaluation","acknowledge_cost":true,"max_model_requests":52}))
}

Method TestInterruptedAndNoReplay()
{
    Set id="evaluation-unit-"_$System.Util.CreateGUID()
    TStart
    Try {
        Set ^ContestEvaluations("report",id)={"id":(id),"state":"running","boot":"old-boot","cases":[]}.%ToJSON()
        Do $$$AssertEquals(##class(Contest.PrivacyEvaluation).Status(id).state,"interrupted")
        Set rejected=0
        Try { Do ##class(Contest.PrivacyEvaluation).Run(id) }
        Catch ex { Set rejected=1 }
        Do $$$AssertTrue(rejected,"Worker must refuse an old boot before any model call")
        TRollback 1
    } Catch ex { TRollback 1 Throw ex }
}

Method TestRequestIdentity()
{
    Set id="evaluation-unit-"_$System.Util.CreateGUID(), key="unit-"_$System.Util.CreateGUID()
    TStart
    Try {
        Set ^ContestEvaluations("report",id)={"id":(id),"state":"completed","config":{"id":"published"},"cases":[]}.%ToJSON()
        Set ^ContestEvaluations("request",key)=id
        Set body={"agent_id":"published","request_key":(key),"acknowledge_cost":true,"max_model_requests":48}
        Do $$$AssertEquals(##class(Contest.PrivacyEvaluation).Start(body).id,id,"Repeated request returns original report without launching a worker")
        Do body.%Set("agent_id","other")
        Set rejected=0
        Try { Set result=##class(Contest.PrivacyEvaluation).Start(body) }
        Catch ex { Set rejected=1 }
        Do $$$AssertTrue(rejected)
        TRollback 1
    } Catch ex { TRollback 1 Throw ex }
}

Method TestNoFindingRequiresCompleteFacts()
{
    Set facts=##class(Contest.AgentService).Fixture("no_finding"), result={"assessment":"no_finding"}
    Do facts.%Remove("expected")
    Do $$$AssertTrue(##class(Contest.AgentService).SafeAssessment(result,facts))
    For field="purpose_known","purpose","direct_identifiers","deidentification_verified" {
        Set missing={}.%FromJSON(facts.%ToJSON())
        Do missing.%Remove(field)
        Do $$$AssertTrue('##class(Contest.AgentService).SafeAssessment(result,missing),"Missing "_field_" must not accept no_finding")
    }
    Do facts.%Set("direct_identifiers",1,"boolean")
    Do $$$AssertTrue('##class(Contest.AgentService).SafeAssessment(result,facts))
    Do facts.%Set("direct_identifiers",0,"boolean"), facts.%Set("deidentification_verified","true")
    Do $$$AssertTrue('##class(Contest.AgentService).SafeAssessment(result,facts))
    Set result.assessment="risk"
    Do $$$AssertTrue(##class(Contest.AgentService).SafeAssessment(result,facts),"Conservative risk is not silently rewritten as a clean finding")
}

Method TestVersionedPromptClone()
{
    Set id="unit-privacy-source-"_$System.Util.CreateGUID()
    TStart
    Try {
        Set source={"id":(id),"revision":3,"status":"published","name":"Privacy reviewer","purpose":"Synthetic review","retrieval_query":"HIPAA","template":"privacy_review","table":"Contest.HIPAAIndex7","index_version":7,"corpus":"unit","model":"unit","max_iterations":4,"executor_version":"privacy-v1"}
        Do source.%Set("config_hash",##class(Contest.AgentService).ConfigHash(source))
        Set original=source.%ToJSON(), ^ContestAgents("config",id)=original
        Set revised=##class(Contest.AgentService).Revise({"id":(id),"revision":3})
        Do $$$AssertEquals(^ContestAgents("config",id),original,"Published source must be unchanged")
        Do $$$AssertEquals(revised.status,"draft")
        Do $$$AssertEquals(revised.%Get("parent_id"),id)
        Do $$$AssertEquals(revised.%Get("prompt_version"),"privacy-review-v2")
        Do $$$AssertTrue(revised.%Get("config_hash")'=source.%Get("config_hash"))
        Do $$$AssertTrue(##class(Contest.AgentService).ValidPrompt(revised))
        Do revised.%Set("prompt_hash","tampered")
        Do $$$AssertTrue('##class(Contest.AgentService).ValidPrompt(revised))
        TRollback 1
    } Catch ex { TRollback 1 Throw ex }
}

Method TestV2EvaluationPublishing()
{
    Set config={"id":"unit-candidate","revision":1,"status":"draft","prompt_version":"privacy-review-v2","prompt_hash":"unit-prompt","config_hash":"unit-hash"}
    Set manifest=##class(Contest.PrivacyEvaluation).Cases()
    Set report={"id":"evaluation-unit","suite":"privacy-synthetic-v1","config":{"id":"unit-candidate","revision":1},"state":"completed","config_hash":"unit-hash","passed":true,"acceptance_policy":"privacy-safety-v1","prompt_version":"privacy-review-v2","prompt_hash":"unit-prompt","manifest_hash":(##class(Demo.Protocol).Hash(manifest.%ToJSON())),"cases":[]}
    For i=0:1:11 {
        Set item=manifest.%Get(i)
        Do report.cases.%Push({"scenario":(item.id),"expected":(item.expected),"result":{"assessment":(item.expected)},"state":"completed","passed":true,"prompt_version":"privacy-review-v2","prompt_hash":"unit-prompt"})
    }
    Do $$$AssertTrue(##class(Contest.AgentService).CanPublishEvaluation(config,report))
    Set config.revision=2
    Do $$$AssertTrue('##class(Contest.AgentService).CanPublishEvaluation(config,report),"Even a same-content edit must invalidate evaluation eligibility")
    Set config.revision=1
    Set altered={}.%FromJSON(report.%ToJSON())
    Do altered.%Set("prompt_hash","wrong-prompt")
    Do $$$AssertTrue('##class(Contest.AgentService).CanPublishEvaluation(config,altered),"A passing label cannot override mismatched prompt provenance")
    Set altered={}.%FromJSON(report.%ToJSON())
    Do altered.%Set("manifest_hash","wrong-manifest")
    Do $$$AssertTrue('##class(Contest.AgentService).CanPublishEvaluation(config,altered))
    Set altered={}.%FromJSON(report.%ToJSON())
    Do altered.cases.%Get(8).result.%Set("assessment","no_finding")
    Do $$$AssertTrue('##class(Contest.AgentService).CanPublishEvaluation(config,altered),"Actual labels must match fixed expectations, not just a passed flag")
    Do report.cases.%Get(8).%Set("passed",0,"boolean")
    Do $$$AssertTrue('##class(Contest.AgentService).CanPublishEvaluation(config,report))
    Set legacy={"kind":"test","state":"completed","config":{"id":"unit-candidate"},"config_hash":"unit-hash","passed":true}
    Do $$$AssertTrue('##class(Contest.AgentService).CanPublish(config,legacy),"V2 must not bypass twelve-case evaluation with a legacy three-case report")
}
}
