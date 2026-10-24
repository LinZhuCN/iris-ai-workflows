Class Contest.ProductionReviewService
{
ClassMethod Access(write As %Boolean = 0) [ Private ]
{
    If ($Namespace'="TRIAGE")||('$System.Security.Check($Select(write:"ContestMonitorDeploy",1:"ContestMonitorRead"),"U")) Do ##class(Demo.Protocol).Fail("Production review capability required")
}

ClassMethod Selected(ordinal As %Integer, every As %Integer) As %Boolean
{
    If (ordinal<1)||(every<1)||(every>1000)||((ordinal\1)'=ordinal)||((every\1)'=every) Do ##class(Demo.Protocol).Fail("Positive bounded sampling interval required")
    Quit ((ordinal-1)#every)=0
}

ClassMethod Authorize(body As %DynamicObject) As %DynamicObject
{
    Do ..Access(1)
    Set shape={}.%FromJSON(body.%ToJSON())
    If body.%IsDefined("demo_premises") {
        Do ##class(Contest.ProductionReview).ValidatePremises(body.%Get("demo_premises"))
        Do shape.%Remove("demo_premises")
    }
    Do ##class(Contest.RouteGovernance).Shape(shape,"authorization_id,production_id,config_hash,agent_id,source_revision,agent_config_hash,contract_hash,every_n,max_reviews,max_model_requests,expires_at,include_existing,acknowledge_cost,acknowledge_synthetic_data_export")
    For field="include_existing","acknowledge_cost","acknowledge_synthetic_data_export" {
        If body.%GetTypeOf(field)'="boolean" Do ##class(Demo.Protocol).Fail("Explicit boolean required: "_field)
    }
    If ('body.%Get("acknowledge_cost"))||('body.%Get("acknowledge_synthetic_data_export")) Do ##class(Demo.Protocol).Fail("Separate cost and synthetic minimized-data export consent required")
    If '$Match(body.%Get("authorization_id"),"^[A-Za-z0-9-]{1,40}$") Do ##class(Demo.Protocol).Fail("Immutable bounded authorization identity required")
    Do ##class(Contest.ProductionFlow).Integer(body,"every_n",1,1000), ##class(Contest.ProductionFlow).Integer(body,"max_reviews",1,20), ##class(Contest.ProductionFlow).Integer(body,"max_model_requests",2,40)
    Do ##class(Contest.ProductionFlow).Integer(body,"source_revision",1), ##class(Contest.ProductionFlow).Integer(body,"expires_at",1,1000000000000)
    If body.%Get("max_model_requests")'=(2*body.%Get("max_reviews")) Do ##class(Demo.Protocol).Fail("Exactly two requests reserved per selected review")
    Set pid=body.%Get("production_id"), item=##class(Contest.ProductionMonitor).Record(pid), snapshot=##class(Contest.ProductionMonitor).Snapshot(item.namespace)
    If ('item.enabled)||('snapshot.running)||(snapshot.id'=pid)||(snapshot.%Get("config_hash")'=body.%Get("config_hash")) Do ##class(Demo.Protocol).Fail("Enabled exact active Production configuration required")
    Set source=##class(Contest.AgentService).Get(body.%Get("agent_id"))
    If ('##class(Contest.PrivacyEvaluation).Eligible(source))||(source.revision'=body.%Get("source_revision"))||(source.%Get("config_hash")'=body.%Get("agent_config_hash"))||(body.%Get("contract_hash")'=##class(Contest.ProductionReview).ContractHash()) Do ##class(Demo.Protocol).Fail("Exact eligible Agent and reviewer contract required")
    Lock +^ContestProductionReview("worker"):2
    If '$Test Do ##class(Demo.Protocol).Fail("Production reviewer busy; authorization unchanged")
    Try {
        Set auth=body.%Get("authorization_id")
        If $Data(^ContestProductionReview("grant",pid,auth)) {
            Set grant={}.%FromJSON(^ContestProductionReview("grant",pid,auth))
            If ##class(Contest.ExportEvidence).Digest(grant.definition)'=##class(Contest.ExportEvidence).Digest(body) Do ##class(Demo.Protocol).Fail("Immutable authorization conflict")
        } Else {
            If (body.%Get("expires_at")<=##class(Demo.Protocol).Now())||(body.%Get("expires_at")>(##class(Demo.Protocol).Now()+86400)) Do ##class(Demo.Protocol).Fail("Authorization expiry must be within the next 24 hours")
            Set active=$Get(^ContestProductionReview("active",pid))
            If active'="" {
                Set previous={}.%FromJSON(^ContestProductionReview("grant",pid,active))
                If previous.enabled&&(previous.definition.%Get("expires_at")>##class(Demo.Protocol).Now()) Do ##class(Demo.Protocol).Fail("Revoke previous active authorization first")
            }
            Set cursor=$Select(body.%Get("include_existing"):0,1:+$Order(^ContestProductionEvidence("record",pid,""),-1))
            Set grant={"authorization_id":(auth),"production_id":(pid),"definition":(body),"actor":($Username),"authorized_at":(##class(Demo.Protocol).Now()),"enabled":true,"used_reviews":0,"eligible_bodies":0,"cursor":(cursor)}
            TStart
            Try {
                Set ^ContestProductionReview("grant",pid,auth)=grant.%ToJSON(), ^ContestProductionReview("active",pid)=auth, ^ContestProductionReview("cursor",pid)=cursor
                TCommit
            } Catch ex { TRollback 1 Throw ex }
        }
    } Catch ex { Lock -^ContestProductionReview("worker") Throw ex }
    Lock -^ContestProductionReview("worker")
    Do ##class(Contest.KnowledgeService).Audit("production.review.authorized",pid,auth)
    Quit grant
}

ClassMethod Revoke(body As %DynamicObject) As %DynamicObject
{
    Do ..Access(1), ##class(Contest.RouteGovernance).Shape(body,"production_id,authorization_id")
    Set managed=##class(Contest.ProductionMonitor).Record(body.%Get("production_id")), pid=managed.id, auth=body.%Get("authorization_id")
    Lock +^ContestProductionReview("worker"):2
    If '$Test Do ##class(Demo.Protocol).Fail("Review in flight; revocation not applied, retry explicitly")
    Try {
        If '$Data(^ContestProductionReview("grant",pid,auth)) Do ##class(Demo.Protocol).Fail("Production authorization not found")
        Set grant={}.%FromJSON(^ContestProductionReview("grant",pid,auth))
        Do grant.%Set("enabled",0,"boolean"), grant.%Set("revoked_at",##class(Demo.Protocol).Now()), grant.%Set("revoked_by",$Username)
        Set ^ContestProductionReview("grant",pid,auth)=grant.%ToJSON()
    } Catch ex { Lock -^ContestProductionReview("worker") Throw ex }
    Lock -^ContestProductionReview("worker")
    Do ##class(Contest.KnowledgeService).Audit("production.review.revoked",pid,auth)
    Quit grant
}

ClassMethod Save(item As %DynamicObject)
{
    Do ..Access(1)
    Set pid=item.%Get("production_id"), header=item.%Get("header_id")
    If item.id'=##class(Contest.ProductionEvidence).Identity(pid,header) Do ##class(Demo.Protocol).Fail("Review identity does not match Production/header")
    TStart
    Try {
        If $Data(^ContestProductionReview("review",pid,header)) {
            Set previous={}.%FromJSON(^ContestProductionReview("review",pid,header))
            Set ^ContestProductionReview("count",pid,previous.state)=$Get(^ContestProductionReview("count",pid,previous.state))-1
        }
        Set ^ContestProductionReview("review",pid,header)=item.%ToJSON()
        Set ^ContestProductionReview("count",pid,item.state)=$Get(^ContestProductionReview("count",pid,item.state))+1
        If (item.state="pending")||(item.state="running") { Set ^ContestProductionReview("inflight",pid,header)=1 }
        Else { Kill ^ContestProductionReview("inflight",pid,header) }
        TCommit
    } Catch ex { TRollback 1 Throw ex }
}

ClassMethod Reserve(item As %DynamicObject) As %Boolean
{
    Do ..Access(1)
    Set pid=item.%Get("production_id"), auth=item.%Get("authorization_id"), reserved=0
    Lock +^ContestProductionReview("budget",pid):2
    If '$Test Do ##class(Demo.Protocol).Fail("Production review budget busy")
    Try {
        Set previous=$Get(^ContestProductionReview("review",pid,item.%Get("header_id"))), spent=0
        If previous'="" Set spent={}.%FromJSON(previous).%Get("reserved_model_requests")
        If (item.state="pending")&&('spent) {
            Set grant={}.%FromJSON(^ContestProductionReview("grant",pid,auth))
            If ('grant.enabled)||(grant.definition.%Get("expires_at")<=##class(Demo.Protocol).Now()) {
                Set item.state="not_authorized"
            } ElseIf grant.%Get("used_reviews")>=grant.definition.%Get("max_reviews") {
                Set item.state="blocked_budget"
            } Else {
                Do grant.%Set("used_reviews",grant.%Get("used_reviews")+1)
                Set item.state="running", reserved=1
                Do item.%Set("reserved_model_requests",2)
                TStart
                Try {
                    Set ^ContestProductionReview("grant",pid,auth)=grant.%ToJSON()
                    Do ..Save(item)
                    TCommit
                } Catch ex { TRollback 1 Throw ex }
            }
        }
    } Catch ex { Lock -^ContestProductionReview("budget",pid) Throw ex }
    Lock -^ContestProductionReview("budget",pid)
    Quit reserved
}

ClassMethod Contexts(value As %DynamicObject) As %DynamicArray
{
    Do ..Access()
    Set matches=[], key="", count=0
    For {
        Set key=$Order(^ContestProductionFlow("production",value.%Get("production_id"),key))
        If key="" Quit
        Set count=count+1
        If count>100 Do ##class(Demo.Protocol).Fail("Optional context lookup bound exceeded")
        Set context=##class(Contest.ProductionFlow).Read(key)
        If context.binding.%Get("config_hash")'=value.%Get("observed_config_hash") Continue
        Set hosts={}, config=context.config
        Do hosts.%Set(config.source,1), hosts.%Set(config.sender,1)
        For i=0:1:config.processors.%Size()-1 Do hosts.%Set(config.processors.%Get(i),1)
        If hosts.%IsDefined(value.header.source)&&hosts.%IsDefined(value.header.target) Do matches.%Push(context)
    }
    Quit matches
}

ClassMethod Review(item As %DynamicObject, value As %DynamicObject, grant As %DynamicObject) [ Private ]
{
    Set pid=item.%Get("production_id")
    Try {
        Set contexts=..Contexts(value), packet=##class(Contest.ProductionReview).Packet(value,contexts,.business,grant)
        Do item.%Set("context_state",$Select(contexts.%Size()=1:"unique_optional_context",contexts.%Size()>1:"ambiguous_optional_context",1:"no_optional_context"))
        Do item.%Set("contexts",contexts), item.%Set("packet",packet)
        If $IsObject(business) Do item.%Set("business_evidence",business)
        If grant.definition.%IsDefined("demo_premises") Do item.%Set("demo_approval",##class(Contest.ProductionReview).Approval(grant))
        Set definition=grant.definition, source=##class(Contest.AgentService).Get(definition.%Get("agent_id"))
        If (source.revision'=definition.%Get("source_revision"))||(source.%Get("config_hash")'=definition.%Get("agent_config_hash"))||(definition.%Get("contract_hash")'=##class(Contest.ProductionReview).ContractHash()) Do ##class(Demo.Protocol).Fail("Pinned Agent/reviewer changed")
        If ..Reserve(item) {
            Set consent={"request_key":("production-"_##class(Demo.Protocol).Hash(item.id_"|"_item.%Get("authorization_id"))),"agent_id":(source.id),"source_revision":(source.revision),"config_hash":(source.%Get("config_hash")),"input_hash":(##class(Demo.Protocol).Hash(packet.%ToJSON())),"contract_hash":(definition.%Get("contract_hash")),"max_model_requests":2,"acknowledge_cost":true}
            Do item.%Set("request_key",consent.%Get("request_key")), ..Save(item)
            If $Data(^ContestProductionReview("context",$Job)) Do ##class(Demo.Protocol).Fail("Cannot overwrite bound Production review context")
            Set ^ContestProductionReview("context",$Job)={"production_id":(pid),"authorization_id":(item.%Get("authorization_id")),"input_hash":(consent.%Get("input_hash")),"request_key":(consent.%Get("request_key"))}.%ToJSON()
            Try { Set report=##class(Contest.ProductionReview).Run(packet,consent) }
            Catch ex { Kill ^ContestProductionReview("context",$Job) Throw ex }
            Kill ^ContestProductionReview("context",$Job)
            Set item.state=report.state
            Do item.%Set("report_id",report.id), item.%Set("attempted_model_requests",report.%Get("reserved_model_requests"))
            If report.state="completed" {
                Do item.%Set("result",report.result)
                Do ##class(Contest.ProductionMonitor).Emit(pid,"review-"_item.%Get("header_id"),$Select(report.result.summary.%Get("risk_detected"):"risk",report.result.summary.unresolved:"information_required",1:"review_completed"),"warning","Production AI review completed; scoped advisory result, no execution.",{"observation_id":(item.id),"report_id":(report.id),"assessment":(report.result.assessment)})
            } Else { Do item.%Set("error","AI Hub/provider/retrieval/output review failed; no substitute verdict or automatic retry.") }
        }
    } Catch ex {
        Set item.state="failed"
        Do item.%Set("error","Production evidence or AI review failed; inspect protected audit. No automatic retry.")
        Do ##class(Contest.KnowledgeService).Audit("production.review.failed",item.id,ex.DisplayString())
    }
    Do ..AttachReport(item)
    Do item.%Set("finished_at",##class(Demo.Protocol).Now())
    Do ..Save(item)
    If (item.state="failed")||(item.state="interrupted") Do ##class(Contest.ProductionMonitor).Emit(pid,"review-"_item.%Get("header_id"),"technical_failure","warning",item.error,{"observation_id":(item.id)})
}

ClassMethod BoundReport(item As %DynamicObject) As %DynamicObject [ Private ]
{
    Set key="production-"_##class(Demo.Protocol).Hash(item.id_"|"_item.%Get("authorization_id")), report=##class(Contest.RiskReview).Status(item.%Get("report_id"))
    If (item.%Get("request_key")'=key)||(report.authorization.%Get("request_key")'=key)||(report.version'="production-review-v1")||(report.authorization.%Get("input_hash")'=##class(Demo.Protocol).Hash(item.packet.%ToJSON()))||(report.packet.%ToJSON()'=item.packet.%ToJSON()) Do ##class(Demo.Protocol).Fail("Production review report/packet binding mismatch")
    If item.%IsDefined("demo_approval") {
        Set grant={}.%FromJSON(^ContestProductionReview("grant",item.%Get("production_id"),item.%Get("authorization_id")))
        Set expected=##class(Contest.ProductionReview).Approval(grant), facts=##class(Contest.RiskReview).Facts(item.packet)
        Set binding={}.%FromJSON(facts.%Get("demo_approval").text)
        If (expected.%ToJSON()'=item.%Get("demo_approval").%ToJSON())||(binding.%Get("approval_hash")'=##class(Contest.ExportEvidence).Digest(expected)) Do ##class(Demo.Protocol).Fail("Demo approval differs from frozen consent/model packet")
    }
    If item.%IsDefined("business_evidence") {
        Set observation=##class(Contest.ProductionEvidence).Read(item.%Get("production_id"),item.%Get("header_id"))
        Do ##class(Contest.ProductionBusinessEvidence).Validate(item.%Get("business_evidence"),observation)
        Set facts=##class(Contest.RiskReview).Facts(item.packet), binding={}.%FromJSON(facts.%Get("evidence_binding").text)
        If binding.%Get("evidence_hash")'=item.%Get("business_evidence").%Get("evidence_hash") Do ##class(Demo.Protocol).Fail("Business evidence differs from model-reviewed packet")
    }
    Quit report
}

ClassMethod AttachReport(item As %DynamicObject, interrupted As %Boolean = 0) [ Private ]
{
    Set key=item.%Get("request_key")
    If key="" Quit
    Set id=$Get(^ContestRiskReview("request",key))
    If id="" Quit
    Do item.%Set("report_id",id)
    Set report=..BoundReport(item), phases=[]
    If interrupted&&(report.state="running") {
        Set report.state="interrupted", report.error="Production worker ended without completion; reserved requests are never replayed."
        Set ^ContestRiskReview("report",id)=report.%ToJSON()
    }
    Do item.%Set("attempted_model_requests",report.%Get("reserved_model_requests"))
    For i=0:1:report.phases.%Size()-1 {
        Set phase=report.phases.%Get(i), view={}
        For field="phase","state","agent_session","usage","sdk_stats" {
            If phase.%IsDefined(field) Do view.%Set(field,phase.%Get(field))
        }
        Do phases.%Push(view)
    }
    Do item.%Set("phases",phases)
}

ClassMethod Scan(pid As %String)
{
    Do ..Access(1)
    Set managed=##class(Contest.ProductionMonitor).Record(pid)
    If 'managed.enabled Quit
    Set auth=$Get(^ContestProductionReview("active",pid)), grant="", permitted=0, reason="No separate AI review authorization."
    If auth'="" {
        Set grant={}.%FromJSON(^ContestProductionReview("grant",pid,auth))
        Set reason=$Select('grant.enabled:"AI review authorization revoked.",grant.definition.%Get("expires_at")<=##class(Demo.Protocol).Now():"AI review authorization expired.",1:"Production is inactive, replaced or its configuration changed.")
        If grant.enabled&&(grant.definition.%Get("expires_at")>##class(Demo.Protocol).Now()) {
            Set current=##class(Contest.ProductionMonitor).Snapshot(managed.namespace)
            Set permitted=current.running&&(current.id=pid)&&(current.%Get("config_hash")=grant.definition.%Get("config_hash"))
        }
    }
    Set cursor=+$Get(^ContestProductionReview("cursor",pid))
    For n=1:1:200 {
        Set header=$Order(^ContestProductionEvidence("record",pid,cursor))
        If header="" Quit
        Set value=##class(Contest.ProductionEvidence).Read(pid,header)
        Set item={"id":(value.id),"production_id":(pid),"header_id":(header),"observation_hash":(value.%Get("record_hash")),"authorization_id":(auth),"state":"not_authorized","reason":(reason),"reserved_model_requests":0,"attempted_model_requests":0,"execution":"not_executed","created_at":(##class(Demo.Protocol).Now())}
        Set previous=$Get(^ContestProductionReview("review",pid,header))
        If previous'="" {
            Set old={}.%FromJSON(previous)
            If old.state'="not_authorized" { Set cursor=header Continue }
        }
        If value.capture.state'="captured" {
            Set item.state=value.capture.state
            Set item.reason=value.capture.%Get("reason")
        } ElseIf permitted&&('##class(Contest.ProductionReview).MatchesPremises(value,grant)) {
            Set item.reason="User-confirmed demo premises apply only to another source session; no model request reserved."
        } ElseIf permitted&&(value.%Get("observed_config_hash")=grant.definition.%Get("config_hash")) {
            Set item.reason=""
            Set bodyKey=##class(Demo.Protocol).Hash(value.header.%Get("session_id")_"|"_value.header.%Get("body_class")_"|"_value.header.%Get("body_id"))
            If $Data(^ContestProductionReview("body",pid,bodyKey)) {
                Set item.state="not_sampled_duplicate"
                Do item.%Set("representative_header",^ContestProductionReview("body",pid,bodyKey))
            } Else {
                TStart
                Try {
                    Set ^ContestProductionReview("body",pid,bodyKey)=header
                    Set fresh={}.%FromJSON(^ContestProductionReview("grant",pid,auth))
                    Do fresh.%Set("eligible_bodies",fresh.%Get("eligible_bodies")+1)
                    Set ^ContestProductionReview("grant",pid,auth)=fresh.%ToJSON(), grant=fresh
                    Set item.state=$Select(..Selected(grant.%Get("eligible_bodies"),grant.definition.%Get("every_n")):"pending",1:"not_sampled")
                    Do ..Save(item)
                    TCommit
                } Catch ex { TRollback 1 Throw ex }
                If item.state="pending" Do ..Review(item,value,grant)
            }
        } ElseIf permitted {
            Set item.reason="Observation configuration differs from this authorization; no external call."
        }
        If item.state'="running" Do ..Save(item)
        Set cursor=header, ^ContestProductionReview("cursor",pid)=cursor
    }
    Set ^ContestProductionReview("cursor",pid)=cursor
}

ClassMethod Pump()
{
    Lock +^ContestProductionReview("worker"):0
    If '$Test Quit
    Try {
        Do ..Access(1)
        Kill ^ContestProductionReview("context",$Job)
        Set pid=""
        For {
            Set pid=$Order(^ContestProductionMonitor("record",pid))
            If pid="" Quit
            Try {
                Do ..RecoverLocked(pid), ..Scan(pid)
                Set ^ContestProductionReview("lastScan",pid)=##class(Demo.Protocol).Now()
                Kill ^ContestProductionReview("productionError",pid)
            } Catch ex {
                Set ^ContestProductionReview("productionError",pid)="Production review scan failed; retained cursor and evidence available, inspect protected audit."
                Do ##class(Contest.KnowledgeService).Audit("production.review.scan.failed",pid,ex.DisplayString())
            }
        }
        Set ^ContestProductionReview("heartbeat")=##class(Demo.Protocol).Now()
        Kill ^ContestProductionReview("error")
    } Catch ex {
        Set ^ContestProductionReview("error")="Production review worker failed; retained evidence/cursor available, inspect protected audit."
        Do ##class(Contest.KnowledgeService).Audit("production.review.worker.failed","",ex.DisplayString())
    }
    Lock -^ContestProductionReview("worker")
}

ClassMethod Recover(pid As %String)
{
    Do ..Access(1)
    Set managed=##class(Contest.ProductionMonitor).Record(pid)
    Lock +^ContestProductionReview("worker"):2
    If '$Test Do ##class(Demo.Protocol).Fail("Review worker still active; recovery refused")
    Try { Do ..RecoverLocked(pid) }
    Catch ex { Lock -^ContestProductionReview("worker") Throw ex }
    Lock -^ContestProductionReview("worker")
}

ClassMethod RecoverLocked(pid As %String) [ Private ]
{
    Set header=""
    For {
        Set header=$Order(^ContestProductionReview("inflight",pid,header))
        If header="" Quit
        Set item={}.%FromJSON(^ContestProductionReview("review",pid,header))
        If (item.state'="running")&&(item.state'="pending") Continue
        Set item.state="interrupted"
        Do item.%Set("error","Previous worker ended without completion; reserved budget is never replayed."), ..AttachReport(item,1), ..Save(item)
        Do ##class(Contest.KnowledgeService).Audit("production.review.interrupted",item.id,item.error)
        Do ##class(Contest.ProductionMonitor).Emit(pid,"review-"_header,"technical_failure","warning",item.error,{"observation_id":(item.id)})
    }
}

ClassMethod Lookup(pid As %String, header As %Integer) As %DynamicObject
{
    Do ..Access()
    If $Data(^ContestProductionReview("review",pid,header)) {
        Set item={}.%FromJSON(^ContestProductionReview("review",pid,header))
        If (item.%Get("production_id")'=pid)||(item.%Get("header_id")'=header)||(item.id'=##class(Contest.ProductionEvidence).Identity(pid,header)) Do ##class(Demo.Protocol).Fail("Stored review Production/header mismatch")
        Quit item
    }
    Quit {"state":"pending_observer","reserved_model_requests":0,"attempted_model_requests":0,"execution":"not_executed"}
}

ClassMethod Plan(pid As %String) As %DynamicObject
{
    Do ..Access()
    Set managed=##class(Contest.ProductionMonitor).Record(pid), snapshot=##class(Contest.ProductionMonitor).Snapshot(managed.namespace), sources=[], id=""
    For {
        Set id=$Order(^ContestAgents("config",id))
        If id="" Quit
        Set source=##class(Contest.AgentService).Get(id)
        If '##class(Contest.PrivacyEvaluation).Eligible(source) Continue
        Do sources.%Push({"id":(source.id),"revision":(source.revision),"config_hash":(source.%Get("config_hash")),"model":(source.model),"status":(source.status)})
    }
    Quit {"production_id":(pid),"config_hash":(snapshot.%Get("config_hash")),"runtime":"production-review-v1","contract_hash":(##class(Contest.ProductionReview).ContractHash()),"eligible_agents":(sources),"now":(##class(Demo.Protocol).Now()),"bounds":{"max_reviews":20,"requests_per_review":2,"max_model_requests":40,"expiry_seconds":86400,"input_characters":160000,"output_characters":18000},"sampling":"First eligible session/body then every Nth; optional demo premises restrict eligibility to the approved source session. All edge evidence remains visible.","scope":"Synthetic minimized observations, optional user-approved demo premises/context and dated normative sources; no real-system connection required for demo premises. Advisory, no delivery or replay.","model_calls":0}
}

ClassMethod Detail(pid As %String, header As %Integer) As %DynamicObject
{
    Do ..Access()
    Set evidence=##class(Contest.ProductionEvidence).Read(pid,header), item=..Lookup(pid,header)
    If item.%Get("observation_hash")'=evidence.%Get("record_hash") Do ##class(Demo.Protocol).Fail("Review observation binding mismatch")
    Set result={"review":(item),"evidence":(evidence),"report":null}
    If item.%Get("report_id")'="" Do result.%Set("report",..BoundReport(item))
    Quit result
}

ClassMethod Page(pid As %String, before As %Numeric = 0) As %DynamicObject
{
    Do ..Access()
    Set managed=##class(Contest.ProductionMonitor).Record(pid)
    If (before<0)||(before>1000000000000000)||((before\1)'=before) Do ##class(Demo.Protocol).Fail("Bounded review cursor required")
    Set items=[], header=$Select(before>0:before,1:""), cursor=0
    For i=1:1:25 {
        Set header=$Order(^ContestProductionReview("review",pid,header),-1)
        If header="" Quit
        Do items.%Push(..Lookup(pid,header))
        Set cursor=+header
    }
    Set counts={}, state="", authorizations=[], auth=""
    For { Set state=$Order(^ContestProductionReview("count",pid,state)) Quit:state=""  Do counts.%Set(state,^ContestProductionReview("count",pid,state)) }
    For { Set auth=$Order(^ContestProductionReview("grant",pid,auth)) Quit:auth=""  Do authorizations.%Push({}.%FromJSON(^ContestProductionReview("grant",pid,auth))) }
    Set reviewCursor=+$Get(^ContestProductionReview("cursor",pid))
    Quit {"production_id":(pid),"items":(items),"next_before":($Select((cursor>0)&&($Order(^ContestProductionReview("review",pid,cursor),-1)'=""):cursor,1:0)),"counts":(counts),"authorizations":(authorizations),"heartbeat":($Get(^ContestProductionReview("heartbeat"))),"last_scan":($Get(^ContestProductionReview("lastScan",pid))),"error":($Get(^ContestProductionReview("productionError",pid))),"worker_error":($Get(^ContestProductionReview("error"))),"cursor":(reviewCursor),"batch_full":($Order(^ContestProductionEvidence("record",pid,reviewCursor))'=""),"paused":('managed.enabled),"sampling_unit":"first captured session/body reference, not every message edge","execution":"advisory_only_no_replay"}
}
}
