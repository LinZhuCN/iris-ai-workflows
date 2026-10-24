Class Contest.MonitorService
{
ClassMethod ValidScenario(value As %String) As %Boolean
{
    Quit (value = "treatment") || (value = "analytics") || (value = "failure")
}

ClassMethod ValidObservation(body As %DynamicObject) As %Boolean
{
    If '$IsObject(body) Quit 0
    If 'body.%IsA("%DynamicObject") Quit 0
    If (body.%GetTypeOf("schema")'="number") || '((body.schema=1) || (body.schema=2)) Quit 0
    If body.%Size()'=$Select(body.schema=1:13,1:19) Quit 0
    If (body.%Get("instance_id") '= "local-demo") || (body.%Get("namespace") '= "DEMO") || (body.%Get("production") '= "Demo.Production") || (body.%Get("point") '= "route.complete") Quit 0
    If (body.%GetTypeOf("synthetic") '= "boolean") || 'body.%Get("synthetic") Quit 0
    If '..ValidScenario(body.%Get("scenario")) Quit 0
    If (body.%Get("outcome") '= "delivered") && (body.%Get("outcome") '= "failed") && (body.%Get("outcome")'="held_for_review") Quit 0
    If (body.schema=1) && (body.%Get("outcome")="held_for_review") Quit 0
    For field = "observation_id","message_id","session_id","deployment_id","snapshot_hash" {
        If (body.%GetTypeOf(field) '= "string") && '((field = "session_id") && (body.%GetTypeOf(field) = "number")) Return 0
        If '$Match(body.%Get(field),"^[A-Za-z0-9-]{1,128}$") Return 0
    }
    If body.schema=2 {
        If (body.%GetTypeOf("source_day")'="number") || (body.%Get("source_day")<1) || (body.%GetTypeOf("sampling_revision")'="number") || (body.%GetTypeOf("review_selected")'="boolean") || (body.%GetTypeOf("review_reason")'="string") Return 0
        If (body.%Get("source_day")\1'=body.%Get("source_day")) || (body.%Get("sampling_revision")<1) || (body.%Get("sampling_revision")\1'=body.%Get("sampling_revision")) Return 0
        Set reason=body.%Get("review_reason"), selected=body.%Get("review_selected")
        If selected {
            If (body.scenario'="analytics") || '((reason="daily_first") || (reason="rate")) Return 0
        } Else {
            If '((reason="not_sampled") || (reason="paused") || (reason="not_eligible")) Return 0
            If ((body.scenario="analytics") && (reason="not_eligible")) || ((body.scenario'="analytics") && (reason'="not_eligible")) Return 0
        }
        If (body.%GetTypeOf("facts")'="object") || (body.%GetTypeOf("gate")'="object") Return 0
        Set facts=body.facts
        If (facts.%Size()'=6) || (facts.%GetTypeOf("purpose")'="string") Return 0
        For field="synthetic","purpose_known","direct_identifiers","deidentification_verified","authorization_known" {
            If facts.%GetTypeOf(field)'="boolean" Return 0
        }
        If 'facts.synthetic || (body.gate.%Size()'=3) || (body.gate.%GetTypeOf("decision")'="string") || (body.gate.%GetTypeOf("bundle_hash")'="string") || (body.gate.%GetTypeOf("revision")'="number") Return 0
        If (body.gate.revision<0) || (body.gate.revision\1'=body.gate.revision) Return 0
        If '((body.gate.decision="continue") || (body.gate.decision="hold_for_review")) Return 0
        If (body.gate.decision="hold_for_review")'=(body.outcome="held_for_review") Return 0
        If body.gate.revision=0 {
            If body.gate.%Get("bundle_hash")'="" Return 0
        } Else {
            If '$Match(body.gate.%Get("bundle_hash"),"^[a-f0-9]{64}$") Return 0
        }
    }
    Quit 1
}

ClassMethod Remote(path As %String, body As %DynamicObject = "") As %DynamicObject
{
    Set account = $Select($IsObject(body):"ContestConnectorManager",1:"ContestConnectorReader")
    Quit ##class(Demo.Protocol).Call("/api/monitor/connector/"_path,account,body)
}

ClassMethod Instances() As %DynamicObject
{
    Set health = ..Remote("health")
    Quit {"instance":(health),"user":($Username),"can_deploy":($System.Security.Check("ContestMonitorDeploy","U")),"endpoint":"pre-registered local Connector; namespace allowlist DEMO"}
}

ClassMethod Discover() As %DynamicObject
{
    Set snapshot = ..Remote("snapshot"), id = "snapshot-"_$System.Util.CreateGUID()
    Do snapshot.%Set("id",id)
    Set ^ContestMonitor("snapshot",id) = snapshot.%ToJSON(), ^ContestMonitor("latestSnapshot") = id
    Do ##class(Contest.KnowledgeService).Audit("monitor.discovered",id,snapshot.%Get("config_hash"))
    Quit snapshot
}

ClassMethod Plan(snapshotId As %String) As %DynamicObject
{
    If '$Data(^ContestMonitor("snapshot",snapshotId)) Do ##class(Demo.Protocol).Fail("Snapshot not found")
    Set snapshot = {}.%FromJSON(^ContestMonitor("snapshot",snapshotId))
    If 'snapshot.supported Do ##class(Demo.Protocol).Fail("Production requires manual integration")
    Set current = ..Remote("snapshot")
    If (current.%Get("config_hash") '= snapshot.%Get("config_hash")) || (current.%Get("observer_revision") '= snapshot.%Get("observer_revision")) || (current.production '= snapshot.production) || 'current.running Do ##class(Demo.Protocol).Fail("Snapshot is stale; rediscover")
    Set id = "plan-"_$System.Util.CreateGUID()
    Set desired = {"point":"route.complete","sample_rate":100,"enforcement":false,"namespace":"DEMO","production":"Demo.Production","snapshot_id":(snapshotId),"expected_hash":(snapshot.%Get("config_hash")),"expected_revision":(snapshot.%Get("observer_revision")),"capability_version":1}
    Set digest = ##class(Demo.Protocol).Hash(desired.%ToJSON())
    Set plan = {"id":(id),"snapshot_id":(snapshotId),"expected_hash":(snapshot.%Get("config_hash")),"digest":(digest),"state":"planned","desired":(desired),"diff":"Enable the preinstalled route.complete observer at 100%; no business component edits or Production restart.","impact":"Local bounded outbox only; no remote calls on the business path; Gate remains non-enforcing.","compensation":"Restore the previous observer configuration through a separately approved deployment; never replay business messages.","created_by":($Username),"created_at":($ZDATETIME($ZTIMESTAMP,3,1,3))}
    Set ^ContestMonitor("plan",id) = plan.%ToJSON(), ^ContestMonitor("latestPlan") = id
    Do ##class(Contest.KnowledgeService).Audit("monitor.planned",id,digest)
    Quit plan
}

ClassMethod Transition(id As %String, digest As %String, apply As %Boolean = 0) As %DynamicObject
{
    Lock +^ContestMonitor("planLock",id):2
    If '$Test Do ##class(Demo.Protocol).Fail("Deployment is busy")
    Try {
        If '$Data(^ContestMonitor("plan",id)) Do ##class(Demo.Protocol).Fail("Plan not found")
        Set plan = {}.%FromJSON(^ContestMonitor("plan",id))
        If plan.digest '= digest Do ##class(Demo.Protocol).Fail("Approved digest mismatch")
        If (plan.state = "stale") || (plan.state = "failed") Do ##class(Demo.Protocol).Fail("Create a new deployment plan")
        Set current = ..Remote("snapshot")
        Set baselineChanged = 0
        If ((plan.state = "planned") || (plan.state = "approved")) && (current.%Get("observer_revision") '= plan.desired.%Get("expected_revision")) Set baselineChanged = 1
        If (current.%Get("config_hash") '= plan.%Get("expected_hash")) || 'current.running || (current.production '= "Demo.Production") || baselineChanged {
            Set plan.state = "stale", ^ContestMonitor("plan",id) = plan.%ToJSON()
            Do ##class(Demo.Protocol).Fail("Production changed; plan is stale")
        }
        If 'apply {
            If plan.state = "planned" {
                Set plan.state = "approved"
                Do plan.%Set("approved_by",$Username)
            }
        } Else {
            If (plan.state '= "approved") && (plan.state '= "unknown") && (plan.state '= "verifying") && (plan.state '= "active") Do ##class(Demo.Protocol).Fail("Exact plan must be approved before applying")
            If plan.state '= "active" {
                Set plan.state = "applying", ^ContestMonitor("plan",id) = plan.%ToJSON()
                Try {
                    Set loaded = ..Remote("deploy",{"deployment_id":(id),"digest":(digest),"expected_hash":(plan.%Get("expected_hash")),"expected_revision":(plan.desired.%Get("expected_revision"))})
                    If (loaded.digest '= digest) || (loaded.%Get("deployment_id") '= id) Do ##class(Demo.Protocol).Fail("Loaded acknowledgment mismatch")
                    Set plan.loaded = loaded, plan.state = "verifying"
                    Set ^ContestMonitor("plan",id) = plan.%ToJSON()
                    Set probe = ..Remote("messages",{"scenario":"treatment","key":("probe-"_id)})
                    Set plan.probe = probe
                } Catch ex {
                    Set plan.state = "unknown", plan.error = "Target result uncertain; retry this deployment to reconcile, do not create a blind rollback"
                    Do ##class(Contest.KnowledgeService).Audit("monitor.apply.unknown",id,ex.DisplayString())
                }
            }
        }
        Set ^ContestMonitor("plan",id) = plan.%ToJSON()
        Do ##class(Contest.KnowledgeService).Audit("monitor."_plan.state,id,digest)
    } Catch ex {
        Lock -^ContestMonitor("planLock",id)
        Throw ex
    }
    Lock -^ContestMonitor("planLock",id)
    Quit plan
}

ClassMethod Accept(body As %DynamicObject, Output duplicate As %Boolean) As %Boolean
{
    Set duplicate = 0
    If '..ValidObservation(body) Do ##class(Demo.Protocol).Fail("Invalid observation contract")
    Set canonical = {}
    For field = "schema","instance_id","namespace","production","observation_id","message_id","session_id","scenario","outcome","deployment_id","snapshot_hash","point","synthetic" Do canonical.%Set(field,body.%Get(field),body.%GetTypeOf(field))
    If body.schema=2 {
        For field="source_day","sampling_revision","review_selected","review_reason" Do canonical.%Set(field,body.%Get(field),body.%GetTypeOf(field))
        Set facts={}, gate={}
        For field="synthetic","purpose_known","purpose","direct_identifiers","deidentification_verified","authorization_known" Do facts.%Set(field,body.facts.%Get(field),body.facts.%GetTypeOf(field))
        For field="decision","bundle_hash","revision" Do gate.%Set(field,body.gate.%Get(field),body.gate.%GetTypeOf(field))
        Do canonical.%Set("facts",facts), canonical.%Set("gate",gate)
    }
    Set id = body.%Get("observation_id"), digest = ##class(Demo.Protocol).Hash(canonical.%ToJSON())
    Lock +^ContestMonitor("inboxLock",id):2
    If '$Test Do ##class(Demo.Protocol).Fail("Inbox is busy")
    Try {
        If $Data(^ContestMonitor("inbox",id,"digest")) {
            If ^ContestMonitor("inbox",id,"digest") '= digest Do ##class(Demo.Protocol).Fail("Observation key conflict")
            Set duplicate = 1
        } Else {
            If '$Data(^ContestMonitor("plan",body.%Get("deployment_id"))) Do ##class(Demo.Protocol).Fail("Unknown deployment")
            Set plan = {}.%FromJSON(^ContestMonitor("plan",body.%Get("deployment_id")))
            If (plan.%Get("expected_hash") '= body.%Get("snapshot_hash")) || '$IsObject(plan.%Get("loaded")) Do ##class(Demo.Protocol).Fail("Observation target mismatch")
            TSTART
            Set ^ContestMonitor("inbox",id,"digest") = digest, ^ContestMonitor("inbox",id,"body") = body.%ToJSON()
            Set ^ContestMonitor("pending",id) = 1
            TCOMMIT
        }
    } Catch ex {
        Lock -^ContestMonitor("inboxLock",id)
        Throw ex
    }
    Lock -^ContestMonitor("inboxLock",id)
    Quit 1
}

ClassMethod Consume()
{
    Set id = "", count = 0
    For {
        Set id = $Order(^ContestMonitor("pending",id)) Quit:id=""  Quit:count>=100
        Lock +^ContestMonitor("consume",id):1
        If '$Test Continue
        Try {
            TSTART
            If '$Data(^ContestMonitor("observation",id)) {
                Set ^ContestMonitor("observation",id) = ^ContestMonitor("inbox",id,"body")
                Set sequence = $Increment(^ContestMonitor("sequence"))
                Set ^ContestMonitor("order",sequence) = id
                Set ^ContestMonitor("receipt",id) = {"observation_id":(id),"state":"received","received_at":($ZDATETIME($ZTIMESTAMP,3,1,3))}.%ToJSON()
            }
            Set ^ContestEvents("pending",id)=1
            Kill ^ContestMonitor("pending",id)
            TCOMMIT
        } Catch ex {
            TROLLBACK
            Lock -^ContestMonitor("consume",id)
            Throw ex
        }
        Lock -^ContestMonitor("consume",id)
        Set count = count+1
    }
    Set ^ContestMonitor("consumerHeartbeat") = ##class(Demo.Protocol).Now()
    Do ##class(Contest.EventService).Drain()
}

ClassMethod Pipelines() As %DynamicObject
{
    Set snapshot = "", plan = "", observations = [], snapshotId = $Get(^ContestMonitor("latestSnapshot")), planId = $Get(^ContestMonitor("latestPlan"))
    If snapshotId '= "" Set snapshot = {}.%FromJSON(^ContestMonitor("snapshot",snapshotId))
    If planId '= "" {
        Set plan = {}.%FromJSON(^ContestMonitor("plan",planId))
        If (plan.state = "verifying") && $IsObject(plan.%Get("probe")) {
            Set probeId = plan.probe.%Get("observation_id")
            If (probeId '= "") && $Data(^ContestMonitor("observation",probeId)) {
                Set plan.state = "active"
                Do plan.%Set("verified_at",$ZDATETIME($ZTIMESTAMP,3,1,3))
                Set ^ContestMonitor("plan",planId) = plan.%ToJSON()
            }
        }
    }
    Set sequence = "", count = 0
    For {
        Set sequence = $Order(^ContestMonitor("order",sequence),-1) Quit:sequence=""
        Set id = ^ContestMonitor("order",sequence)
        If count < 50 Do observations.%Push({}.%FromJSON(^ContestMonitor("observation",id)))
        Set count = count+1
    }
    Set transport = ..Remote("transport"), summary = ""
    If snapshotId '= "" Set summary = ##class(Contest.PipelineSummary).Status($Get(^ContestMonitor("summaryFor",snapshotId)))
    Quit {"snapshot":(snapshot),"deployment":(plan),"summary":(summary),"observations":(observations),"transport":(transport),"consumer_age_seconds":(##class(Demo.Protocol).Now()-$Get(^ContestMonitor("consumerHeartbeat"))),"receiver_paused":(+$Get(^ContestMonitor("receiverPaused"))),"received":(count),"can_deploy":($System.Security.Check("ContestMonitorDeploy","U"))}
}
}
