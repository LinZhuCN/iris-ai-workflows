Class Contest.RuleService
{
ClassMethod Get(id As %String) As %DynamicObject
{
    If (id="") || '$Data(^ContestRules("draft",id)) Do ##class(Demo.Protocol).Fail("Rule draft not found")
    Quit {}.%FromJSON(^ContestRules("draft",id))
}

ClassMethod PlanGet(id As %String) As %DynamicObject
{
    If (id="") || '$Data(^ContestRules("plan",id)) Do ##class(Demo.Protocol).Fail("Rule plan not found")
    Quit {}.%FromJSON(^ContestRules("plan",id))
}

ClassMethod Create(body As %DynamicObject) As %DynamicObject
{
    If (body.%Size()'=3) || (body.%GetTypeOf("event_id")'="string") || (body.%GetTypeOf("opinion_id")'="string") || (body.%GetTypeOf("bundle")'="object") Do ##class(Demo.Protocol).Fail("Saved event/opinion identities and a bounded bundle are required")
    Set detail=##class(Contest.EventService).Detail(body.%Get("event_id")), found=0
    For i=0:1:detail.event.opinions.%Size()-1 {
        Set opinion=detail.event.opinions.%Get(i)
        If opinion.id=body.%Get("opinion_id") {
            Set found=1, opinionHash=##class(Demo.Protocol).Hash(opinion.text)
        }
    }
    If 'found Do ##class(Demo.Protocol).Fail("Saved opinion not found; saving an opinion never deploys a rule")
    Set bundle=##class(Demo.RuleEngine).Canonical(body.bundle), id="rule-"_$System.Util.CreateGUID()
    Set draft={"id":(id),"revision":1,"state":"draft","bundle":(bundle),"bundle_hash":(##class(Demo.RuleEngine).Hash(bundle)),"event_id":(body.%Get("event_id")),"opinion_id":(body.%Get("opinion_id")),"opinion_hash":(opinionHash),"origin":"manual_template_not_ai","actor":($Username),"created":(##class(Demo.Protocol).Now())}
    Set ^ContestRules("draft",id)=draft.%ToJSON(), ^ContestRules("draftOrder",$Increment(^ContestRules("sequence")))=id
    Do ##class(Contest.KnowledgeService).Audit("rule.draft.created",id,"Manual, linked to immutable saved opinion; no model call")
    Quit draft
}

ClassMethod Test(id As %String, revision As %Integer) As %DynamicObject
{
    Lock +^ContestRules("draftLock",id):2
    If '$Test Do ##class(Demo.Protocol).Fail("Rule draft busy")
    Try {
        Set draft=..Get(id)
        If (draft.revision'=revision) || (draft.state'="draft") Do ##class(Demo.Protocol).Fail("Draft changed or is already tested")
        Set bundle=draft.bundle, tests=[], passed=1
        Set risky={"purpose_known":true,"purpose":"analytics","direct_identifiers":true,"scenario":"analytics","stage":"before_send"}
        Set clean={"purpose_known":true,"purpose":"analytics","direct_identifiers":false,"scenario":"analytics","stage":"before_send"}
        Set treatment={"purpose_known":true,"purpose":"treatment","direct_identifiers":false,"scenario":"treatment","stage":"before_send"}
        Set missing={"purpose_known":true,"purpose":"analytics","scenario":"analytics","stage":"before_send"}
        Set unknown={"purpose_known":false,"scenario":"failure","stage":"before_send"}
        For name="risky","clean","treatment","missing","unknown" {
            Set facts=$Select(name="risky":risky,name="clean":clean,name="treatment":treatment,name="missing":missing,1:unknown)
            Set expected=$Select('bundle.enabled:"continue",(name="clean") || (name="treatment"):"continue",1:"hold_for_review")
            Set actual=##class(Demo.RuleEngine).Decision(bundle,facts)
            Set row={"name":(name),"expected":(expected),"actual":(actual),"passed":false}
            Do row.%Set("passed",expected=actual,"boolean"), tests.%Push(row)
            If expected'=actual Set passed=0
        }
        Set report={"executor":"gate-v1","bundle_hash":(draft.%Get("bundle_hash")),"cases":(tests),"passed":false}
        Do report.%Set("passed",passed,"boolean")
        Set draft.report=report, draft.revision=draft.revision+1
        Set draft.state=$Select(passed:"tested",1:"test_failed")
        Set ^ContestRules("draft",id)=draft.%ToJSON()
        Do ##class(Contest.KnowledgeService).Audit("rule.test",id,draft.state)
    } Catch ex { Lock -^ContestRules("draftLock",id) Throw ex }
    Lock -^ContestRules("draftLock",id)
    Quit draft
}

ClassMethod Plan(id As %String, revision As %Integer) As %DynamicObject
{
    Set draft=..Get(id)
    If (draft.revision'=revision) || (draft.state'="tested") || 'draft.report.passed || (draft.report.%Get("bundle_hash")'=draft.%Get("bundle_hash")) Do ##class(Demo.Protocol).Fail("A passing test for this exact rule hash is required")
    Set source=##class(Contest.MonitorService).Remote("snapshot"), baseline=##class(Contest.MonitorService).Remote("rules/status")
    If 'source.supported Do ##class(Demo.Protocol).Fail("Rule deployment requires the supported DEMO")
    Set id="rule-plan-"_$System.Util.CreateGUID()
    Set desired={"rule_id":(draft.id),"bundle_hash":(draft.%Get("bundle_hash")),"source_hash":(source.%Get("config_hash")),"baseline_revision":(baseline.revision),"opinion_hash":(draft.%Get("opinion_hash")),"executor":"gate-v1"}
    Set digest=##class(Demo.Protocol).Hash(desired.%ToJSON())
    Set plan={"id":(id),"rule_id":(draft.id),"bundle":(draft.bundle),"bundle_hash":(draft.%Get("bundle_hash")),"source_hash":(source.%Get("config_hash")),"expected_revision":(baseline.revision),"previous_bundle":(baseline.bundle),"digest":(digest),"state":"planned","created":(##class(Demo.Protocol).Now()),"actor":($Username),"effect":"Local DEMO before_send only; holds are persistent and never automatically replayed."}
    Set ^ContestRules("plan",id)=plan.%ToJSON(), ^ContestRules("planOrder",$Increment(^ContestRules("sequence")))=id
    Do ##class(Contest.KnowledgeService).Audit("rule.plan",id,digest)
    Quit plan
}

ClassMethod Transition(id As %String, digest As %String, apply As %Boolean) As %DynamicObject
{
    Lock +^ContestRules("planLock",id):2
    If '$Test Do ##class(Demo.Protocol).Fail("Rule deployment busy")
    Set activationStarted=0
    Try {
        Set plan=..PlanGet(id)
        If plan.digest'=digest Do ##class(Demo.Protocol).Fail("Exact rule approval digest required")
        If 'apply {
            If (plan.state'="planned") || ((##class(Demo.Protocol).Now()-plan.created)>900) Do ##class(Demo.Protocol).Fail("Plan is not fresh and planned")
            Set source=##class(Contest.MonitorService).Remote("snapshot"), current=##class(Contest.MonitorService).Remote("rules/status")
            If 'source.supported || (source.%Get("config_hash")'=plan.%Get("source_hash")) || (current.revision'=plan.%Get("expected_revision")) Do ##class(Demo.Protocol).Fail("Source or rule baseline changed; create a fresh plan")
            Set plan.state="approved"
            Do plan.%Set("approved_by",$Username), plan.%Set("approved_at",##class(Demo.Protocol).Now())
        } Else {
            If '((plan.state="approved") || (plan.state="unknown") || (plan.state="loaded") || (plan.state="effect_verified")) Do ##class(Demo.Protocol).Fail("Rule plan is not approved")
            If (##class(Demo.Protocol).Now()-plan.%Get("approved_at"))>900 {
                Set current=##class(Contest.MonitorService).Remote("rules/status")
                If current.%Get("deployment_id")'=id Do ##class(Demo.Protocol).Fail("Approval expired; only an already loaded deployment may be reconciled")
            }
            Set activationStarted=1
            Set prepared=##class(Contest.MonitorService).Remote("rules/prepare",{"deployment_id":(id),"bundle_hash":(plan.%Get("bundle_hash")),"source_hash":(plan.%Get("source_hash")),"expected_revision":(plan.%Get("expected_revision")),"bundle":(plan.bundle)})
            Set loaded=##class(Contest.MonitorService).Remote("rules/activate",{"deployment_id":(id),"bundle_hash":(plan.%Get("bundle_hash"))})
            Set current=##class(Contest.MonitorService).Remote("rules/status")
            If (current.%Get("deployment_id")'=id) || (current.%Get("bundle_hash")'=plan.%Get("bundle_hash")) Do ##class(Demo.Protocol).Fail("Target has a different active deployment; do not silently reapply")
            Set plan.loaded=loaded, plan.state="loaded", probes=[]
            For scenario="analytics","treatment" {
                Set probe=##class(Contest.MonitorService).Remote("messages",{"scenario":(scenario),"key":("rule-probe-"_id_"-"_scenario)})
                Do probes.%Push(probe)
            }
            Set plan.probes=probes
            Do plan.%Remove("error")
        }
        Set ^ContestRules("plan",id)=plan.%ToJSON()
        Do ##class(Contest.KnowledgeService).Audit($Select(apply:"rule.loaded",1:"rule.approved"),id,digest)
    } Catch ex {
        If activationStarted {
            Set plan.state="unknown", plan.error="Activation and/or effect probes not fully confirmed. Reconcile this same deployment; no automatic rollback or business replay."
            Set ^ContestRules("plan",id)=plan.%ToJSON()
        }
        Lock -^ContestRules("planLock",id)
        Throw ex
    }
    Lock -^ContestRules("planLock",id)
    Quit plan
}

ClassMethod Verify(plan As %DynamicObject) As %DynamicObject
{
    If (plan.state'="loaded") || 'plan.%IsDefined("probes") Quit plan
    If plan.probes.%Size()'=2 Quit plan
    Set verified=1
    For i=0:1:plan.probes.%Size()-1 {
        Set probe=plan.probes.%Get(i), id=probe.%Get("observation_id")
        If '$Data(^ContestMonitor("observation",id)) {
            Set verified=0
            Continue
        }
        Set observation={}.%FromJSON(^ContestMonitor("observation",id))
        Set expected=$Select((probe.scenario="analytics") && plan.bundle.enabled:"held_for_review",1:"delivered")
        If (observation.schema'=2) || (observation.scenario'=probe.scenario) || (observation.gate.%Get("bundle_hash")'=plan.%Get("bundle_hash")) || (observation.gate.revision'=plan.loaded.revision) || (observation.outcome'=expected) || (observation.gate.decision'=$Select(expected="held_for_review":"hold_for_review",1:"continue")) Set verified=0
    }
    If verified {
        Set plan.state="effect_verified"
        Set ^ContestRules("plan",plan.id)=plan.%ToJSON()
    }
    Quit plan
}

ClassMethod Rollback(id As %String) As %DynamicObject
{
    Set original=..PlanGet(id), draft=..Get(original.%Get("rule_id"))
    If 'original.%IsDefined("loaded") Do ##class(Demo.Protocol).Fail("Only a loaded deployment has a rollback baseline")
    Set rollback=..Create({"event_id":(draft.%Get("event_id")),"opinion_id":(draft.%Get("opinion_id")),"bundle":(original.%Get("previous_bundle"))})
    Do rollback.%Set("rollback_of",id)
    Set ^ContestRules("draft",rollback.id)=rollback.%ToJSON()
    Set tested=..Test(rollback.id,rollback.revision), plan=..Plan(tested.id,tested.revision)
    Do plan.%Set("rollback_of",id)
    Set ^ContestRules("plan",plan.id)=plan.%ToJSON()
    Quit plan
}

ClassMethod List() As %DynamicObject
{
    Set drafts=[], plans=[], sequence="", count=0
    For {
        Set sequence=$Order(^ContestRules("draftOrder",sequence),-1)
        Quit:((sequence="") || (count>=30))
        Do drafts.%Push(..Get(^ContestRules("draftOrder",sequence)))
        Set count=count+1
    }
    Set sequence="", count=0
    For {
        Set sequence=$Order(^ContestRules("planOrder",sequence),-1)
        Quit:((sequence="") || (count>=30))
        Set plan=..Verify(..PlanGet(^ContestRules("planOrder",sequence)))
        Do plans.%Push(plan)
        Set count=count+1
    }
    Quit {"drafts":(drafts),"plans":(plans),"target":(##class(Contest.MonitorService).Remote("rules/status")),"template":(##class(Demo.RuleEngine).Template()),"user":($Username),"can_write":($System.Security.Check("ContestMonitorDeploy","U")),"natural_language_generation":"not_requested_no_model_budget"}
}
}
