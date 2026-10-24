Class Contest.RouteReview
{
ClassMethod Access(write As %Boolean = 0) [ Private ]
{
    If ($Namespace'="TRIAGE")||('$System.Security.Check($Select(write:"ContestMonitorDeploy",1:"ContestMonitorRead"),"U")) Do ##class(Demo.Protocol).Fail("Route review capability required")
}

ClassMethod Key(kind As %String, batch As %String) As %String [ Private ]
{
    If '((kind="aggregation")||(kind="utilization")) Do ##class(Demo.Protocol).Fail("Known route required")
    If '$Match(batch,"^[A-Za-z0-9-]{1,64}$") Do ##class(Demo.Protocol).Fail("Bounded batch required")
    Quit kind_"-"_batch
}

ClassMethod Event(category As %String) As %DynamicObject [ Private ]
{
    Quit {"category":(category),"state":"open","revision":1,"actions":[]}
}

ClassMethod Configure(config As %DynamicObject, grants As %DynamicArray, authorize As %Boolean = 0)
{
    Do ..Access(1)
    Lock +^ContestRouteReview("worker"):2
    If '$Test Do ##class(Demo.Protocol).Fail("Automatic worker busy; configuration was not changed")
    Try { Do ..ConfigureLocked(config,grants,authorize) }
    Catch ex { Lock -^ContestRouteReview("worker") Throw ex }
    Lock -^ContestRouteReview("worker")
}

ClassMethod ConfigureLocked(config As %DynamicObject, grants As %DynamicArray, authorize As %Boolean) [ Private ]
{
    Do ..Access(1), ##class(Contest.RouteGovernance).Shape(config,"agent_id,source_revision,config_hash,contract_hash")
    If grants.%Size()'=2 Do ##class(Demo.Protocol).Fail("Exactly two pinned original batches required")
    Set source=##class(Contest.AgentService).Get(config.%Get("agent_id"))
    If (source.model'="deepseek-flash")||(source.revision'=config.%Get("source_revision"))||(source.%Get("config_hash")'=config.%Get("config_hash"))||(##class(Contest.RiskReviewV4).ContractHash()'=config.%Get("contract_hash"))||('##class(Contest.PrivacyEvaluation).Eligible(source)) Do ##class(Demo.Protocol).Fail("Eligible exact deepseek-flash Agent and current scenario-review contract required")
    If $Data(^ContestRouteReview("config")) {
        If ^ContestRouteReview("config")'=config.%ToJSON() Do ##class(Demo.Protocol).Fail("Observer configuration is immutable")
    }
    If $Data(^ContestRouteReview("targets")) {
        If ^ContestRouteReview("targets")'=grants.%ToJSON() Do ##class(Demo.Protocol).Fail("Observer budget targets are immutable")
    }
    Set seen={}
    For i=0:1:grants.%Size()-1 {
        Set grant=grants.%Get(i)
        Do ##class(Contest.RouteGovernance).Shape(grant,"kind,batch,receipt_hash")
        Set key=..Key(grant.kind,grant.batch)
        If seen.%IsDefined(key) Do ##class(Demo.Protocol).Fail("Duplicate budget target")
        Do seen.%Set(key,1)
        Set evidence=##class(Contest.RouteEvidence).Read(grant.kind,grant.batch,grant.%Get("receipt_hash"))
        If $Data(^ContestRouteReview("pin",key)) {
            If ^ContestRouteReview("pin",key)'=grant.%Get("receipt_hash") Do ##class(Demo.Protocol).Fail("Original receipt pin is immutable")
        }
    }
    TStart
    Try {
        Set ^ContestRouteReview("config")=config.%ToJSON()
        Set ^ContestRouteReview("targets")=grants.%ToJSON()
        For i=0:1:grants.%Size()-1 {
            Set grant=grants.%Get(i), key=..Key(grant.kind,grant.batch)
            Set ^ContestRouteReview("pin",key)=grant.%Get("receipt_hash")
            If authorize&&('$Data(^ContestRouteReview("allow",key))) {
                Set ^ContestRouteReview("allow",key)={"receipt_hash":(grant.%Get("receipt_hash")),"reserved":false,"actor":($Username),"authorized_at":(##class(Demo.Protocol).Now()),"max_model_requests":2,"runtime_version":"staged-risk-v4","config":(config),"authorization_id":"internal-use-demo"}.%ToJSON()
            }
        }
        Set ^ContestRouteReview("enabled")=1
        TCommit
    } Catch ex { TRollback 1 Throw ex }
    Do ##class(Contest.KnowledgeService).Audit("route.observer.configured","two-original-batches",$Select(authorize:"At most four model requests; no replay",1:"Observation only; model budget zero"))
}

ClassMethod Tick()
{
    If '$Get(^ContestRouteReview("enabled")) Quit
    If $Get(^ContestRouteReview("nextTick"))>##class(Demo.Protocol).Now() Quit
    Set ^ContestRouteReview("nextTick")=##class(Demo.Protocol).Now()+5
    Job ##class(Contest.RouteReview).Pump()::2
    If '$Test Do ##class(Demo.Protocol).Fail("Could not launch automatic route observer")
}

ClassMethod AuthorizeAcceptance(id As %String, targets As %DynamicArray)
{
    Do ..Access(1)
    If '$Match(id,"^[A-Za-z0-9-]{1,20}$") Do ##class(Demo.Protocol).Fail("Bounded acceptance authorization required")
    Lock +^ContestRouteReview("worker"):2
    If '$Test Do ##class(Demo.Protocol).Fail("Observer busy; acceptance authorization not changed")
    Try { Do ..AuthorizeAcceptanceLocked(id,targets) }
    Catch ex {
        Lock -^ContestRouteReview("worker")
        Do ##class(Contest.KnowledgeService).Audit("route.review.acceptance.rejected",id,ex.DisplayString())
        Throw ex
    }
    Lock -^ContestRouteReview("worker")
}

ClassMethod AuthorizeAcceptanceLocked(id As %String, targets As %DynamicArray) [ Private ]
{
    If targets.%Size()'=3 Do ##class(Demo.Protocol).Fail("Acceptance requires two historical targets and one new utilization batch; six requests maximum")
    Set config={}.%FromJSON(^ContestRouteReview("config"))
    Do config.%Set("contract_hash",##class(Contest.RiskReviewV4).ContractHash())
    Set source=##class(Contest.AgentService).Get(config.%Get("agent_id"))
    If (source.model'="deepseek-flash")||(source.revision'=config.%Get("source_revision"))||(source.%Get("config_hash")'=config.%Get("config_hash"))||('##class(Contest.PrivacyEvaluation).Eligible(source)) Do ##class(Demo.Protocol).Fail("Pinned source Agent unavailable")
    Set definition={"targets":(targets),"config":(config),"runtime_version":"staged-risk-v4","max_model_requests":6}
    If $Data(^ContestRouteReview("acceptance",id)) {
        If ^ContestRouteReview("acceptance",id)'=definition.%ToJSON() Do ##class(Demo.Protocol).Fail("Immutable acceptance authorization conflict")
        Quit
    }
    Set plans=[], seen={}
    For i=0:1:2 {
        Set target=targets.%Get(i)
        Do ##class(Contest.RouteGovernance).Shape(target,"kind,batch,receipt_hash")
        Set base=..Key(target.kind,target.batch), mode=$Select(i=2:"new_batch",1:"reassessment")
        If target.kind'=$Select(i=0:"aggregation",1:"utilization") Do ##class(Demo.Protocol).Fail("Expected aggregation retest, utilization retest and new utilization batch")
        If seen.%IsDefined(base) Do ##class(Demo.Protocol).Fail("Duplicate acceptance target")
        Do seen.%Set(base,1)
        Set key=base_$Select(i=2:"",1:"-"_id)
        If ($Length(key)>94)||($Data(^ContestRouteReview("allow",key)))||($Data(^ContestRouteReview("review",key))) Do ##class(Demo.Protocol).Fail("New bounded task identity required; old tasks cannot be reset")
        Set grant={"receipt_hash":(target.%Get("receipt_hash")),"reserved":false,"actor":($Username),"authorized_at":(##class(Demo.Protocol).Now()),"max_model_requests":2,"runtime_version":"staged-risk-v4","config":(config),"authorization_id":(id),"mode":(mode)}, item=""
        If i<2 {
            Set evidence=##class(Contest.RouteEvidence).Read(target.kind,target.batch,target.%Get("receipt_hash")).evidence
            If '$Data(^ContestRouteReview("review",base)) Do ##class(Demo.Protocol).Fail("Historical automatic capture required for reassessment")
            Set item={"id":(key),"route_kind":(target.kind),"batch_id":(target.batch),"origin":"automatic_after_send","trigger":"explicit_reassessment","parent_review_id":(base),"authorization_id":(id),"runtime_version":"staged-risk-v4","state":"blocked_budget","created":(##class(Demo.Protocol).Now()),"worker_identity":($Username),"receipt_hash":(target.%Get("receipt_hash")),"pin_basis":"independent_original_receipt","evidence":(evidence),"record_id":(evidence.approved.%Get("record_id")),"reserved_model_requests":0,"event":(..Event("coverage_gap")),"execution":"not_executed"}
        } Else {
            If target.%Get("receipt_hash")'="" Do ##class(Demo.Protocol).Fail("New batch authorization must precede delivery; no invented future receipt")
            Set previous=$Namespace
            Try {
                Set $Namespace="UTILIZATION"
                If $Data(^ContestUtilization("batch",target.batch)) Do ##class(Demo.Protocol).Fail("Acceptance batch already exists; use the authorized new identity")
                Set registration={}.%FromJSON(^ContestUtilization("registration")), binding=##class(Contest.Utilization.Runtime).Binding()
                Set dossier=##class(Contest.Utilization.Runtime).Approval(registration.id,registration.digest)
            } Catch ex { Set $Namespace=previous Throw ex }
            Set $Namespace=previous
            Do grant.%Set("expected_approval",registration.id), grant.%Set("expected_scope",registration.digest), grant.%Set("expected_config",binding.%Get("config_hash"))
        }
        Do plans.%Push({"key":(key),"grant":(grant),"item":(item)})
    }
    TStart
    Try {
        Set ^ContestRouteReview("acceptance",id)=definition.%ToJSON()
        For i=0:1:2 {
            Set plan=plans.%Get(i), key=plan.key
            Set ^ContestRouteReview("allow",key)=plan.grant.%ToJSON()
            If $IsObject(plan.item) Set ^ContestRouteReview("review",key)=plan.item.%ToJSON()
        }
        Do ##class(Contest.KnowledgeService).Audit("route.review.acceptance.authorized",id,"Three exact targets, six requests maximum; no automatic retries")
        TCommit
    } Catch ex { TRollback 1 Throw ex }
}

ClassMethod Capture(kind As %String, batch As %String)
{
    Do ..Access(1)
    Set key=..Key(kind,batch)
    If $Data(^ContestRouteReview("review",key)) Quit
    Set item={"id":(key),"route_kind":(kind),"batch_id":(batch),"origin":"automatic_after_send","runtime_version":"staged-risk-v4","state":"blocked_budget","created":(##class(Demo.Protocol).Now()),"worker_identity":($Username),"reserved_model_requests":0,"event":(..Event("coverage_gap")),"execution":"not_executed"}
    Try {
        Set previous=$Namespace
        Try {
            Set $Namespace=$Select(kind="aggregation":"PIPELINE",1:"UTILIZATION")
            Set raw=$Select(kind="aggregation":$Get(^ContestAggregation("batch",batch)),1:$Get(^ContestUtilization("batch",batch)))
            If raw="" Do ##class(Demo.Protocol).Fail("Completed batch evidence missing")
            Set source={}.%FromJSON(raw), pin=source.receipt.%Get("receipt_hash")
        } Catch ex { Set $Namespace=previous Throw ex }
        Set $Namespace=previous, basis="first_observer_capture"
        If $Data(^ContestRouteReview("pin",key)) {
            Set pin=^ContestRouteReview("pin",key), basis="independent_original_receipt"
        }
        Set value=##class(Contest.RouteEvidence).Read(kind,batch,pin)
        Do item.%Set("receipt_hash",pin), item.%Set("pin_basis",basis), item.%Set("evidence",value.evidence)
        Do item.%Set("record_id",value.evidence.approved.%Get("record_id"))
        Do item.%Set("current_admission",value.%Get("current_admission"))
        If $Data(^ContestRouteReview("allow",key)) {
            Set grant={}.%FromJSON(^ContestRouteReview("allow",key))
            If grant.%IsDefined("authorization_id") {
                Do item.%Set("authorization_id",grant.%Get("authorization_id")), item.%Set("runtime_version",grant.%Get("runtime_version"))
                Set item.trigger="new_completed_batch"
            }
        }
    } Catch ex {
        Set $Namespace="TRIAGE", item.state="evidence_failed", item.event=..Event("technical_failure")
        Do item.%Set("error","Historical evidence could not be verified. No model called and no privacy verdict substituted.")
        Do ##class(Contest.KnowledgeService).Audit("route.review.evidence.failed",key,ex.DisplayString())
    }
    Set ^ContestRouteReview("review",key)=item.%ToJSON()
    Do ##class(Contest.KnowledgeService).Audit("route.review.captured",key,item.state)
}

ClassMethod Scan()
{
    Do ..Access(1)
    For kind="aggregation","utilization" {
        Set previous=$Namespace, batches=[]
        Try {
            Set $Namespace=$Select(kind="aggregation":"PIPELINE",1:"UTILIZATION"), batch=""
            For {
                Set batch=$Select(kind="aggregation":$Order(^ContestAggregation("batch",batch)),1:$Order(^ContestUtilization("batch",batch)))
                If batch="" Quit
                Set raw=$Select(kind="aggregation":^ContestAggregation("batch",batch),1:^ContestUtilization("batch",batch))
                Set row={}.%FromJSON(raw)
                If row.state="delivered" Do batches.%Push(batch)
            }
        } Catch ex { Set $Namespace=previous Throw ex }
        Set $Namespace=previous
        For i=0:1:batches.%Size()-1 Do ..Capture(kind,batches.%Get(i))
    }
    Set ^ContestRouteReview("heartbeat")=##class(Demo.Protocol).Now(), ^ContestRouteReview("observerIdentity")=$Username
}

ClassMethod Reserve(key As %String, item As %DynamicObject) As %Boolean
{
    Do ..Access(1)
    Lock +^ContestRouteReview("budgetLock",key):2
    If '$Test Do ##class(Demo.Protocol).Fail("Budget reservation busy")
    Try { Set reserved=..ReserveLocked(key,item) }
    Catch ex { Lock -^ContestRouteReview("budgetLock",key) Throw ex }
    Lock -^ContestRouteReview("budgetLock",key)
    Quit reserved
}

ClassMethod ReserveLocked(key As %String, item As %DynamicObject) As %Boolean [ Private ]
{
    Do ..Access(1)
    If (item.state'="blocked_budget")||('$Data(^ContestRouteReview("allow",key))) Quit 0
    Set grant={}.%FromJSON(^ContestRouteReview("allow",key))
    If grant.reserved Quit 0
    If (grant.%Get("mode")="new_batch")&&(grant.%Get("receipt_hash")="") {
        Set evidence=item.evidence
        If (evidence.approved.%Get("record_id")'=grant.%Get("expected_approval"))||(evidence.approved.%Get("scope_hash")'=grant.%Get("expected_scope"))||(evidence.provenance.%Get("config_hash")'=grant.%Get("expected_config")) Do ##class(Demo.Protocol).Fail("New batch does not match authorized approval/configuration")
        Do grant.%Set("receipt_hash",item.%Get("receipt_hash"))
    }
    If grant.%Get("receipt_hash")'=item.%Get("receipt_hash") Do ##class(Demo.Protocol).Fail("Authorized receipt changed")
    Set grant.reserved=1
    Do grant.%Set("reserved_at",##class(Demo.Protocol).Now())
    Set item.state="running"
    Do item.%Set("reserved_model_requests",2)
    TStart
    Try {
        Set ^ContestRouteReview("allow",key)=grant.%ToJSON(), ^ContestRouteReview("review",key)=item.%ToJSON()
        TCommit
    } Catch ex { TRollback 1 Throw ex }
    Quit 1
}

ClassMethod Review(key As %String)
{
    Set item={}.%FromJSON(^ContestRouteReview("review",key))
    Try {
        Set reserved=..Reserve(key,item)
        If 'reserved Quit
        Set grant={}.%FromJSON(^ContestRouteReview("allow",key)), version=grant.%Get("runtime_version","staged-risk-v3")
        Do item.%Set("runtime_version",version)
        If grant.%IsDefined("authorization_id") Do item.%Set("authorization_id",grant.%Get("authorization_id"))
        If '((version="staged-risk-v3")||(version="staged-risk-v4")) Do ##class(Demo.Protocol).Fail("Unsupported authorized review runtime")
        Set runtime=$Select(version="staged-risk-v4":"Contest.RiskReviewV4",1:"Contest.RiskReviewV3")
        Set config=$Select(grant.%IsDefined("config"):grant.config,1:{}.%FromJSON(^ContestRouteReview("config")))
        Set fresh=##class(Contest.RouteEvidence).Read(item.%Get("route_kind"),item.%Get("batch_id"),item.%Get("receipt_hash"))
        If fresh.evidence.%Get("evidence_hash")'=item.evidence.%Get("evidence_hash") Do ##class(Demo.Protocol).Fail("Captured evidence changed before review")
        Set packet=item.evidence.packet, source=##class(Contest.AgentService).Get(config.%Get("agent_id"))
        If (source.model'="deepseek-flash")||(source.revision'=config.%Get("source_revision"))||(source.%Get("config_hash")'=config.%Get("config_hash"))||($ClassMethod(runtime,"ContractHash")'=config.%Get("contract_hash")) Do ##class(Demo.Protocol).Fail("Pinned Agent or reviewer changed")
        Set consent={"request_key":("route-"_key),"agent_id":(source.id),"source_revision":(source.revision),"config_hash":(source.%Get("config_hash")),"input_hash":(##class(Demo.Protocol).Hash(packet.%ToJSON())),"contract_hash":(config.%Get("contract_hash")),"max_model_requests":2,"acknowledge_cost":true}
        Set report=$ClassMethod(runtime,"Run",packet,consent), item.state=report.state
        Do item.%Set("report_id",report.id), item.%Set("actual_model_requests",report.%Get("reserved_model_requests"))
        Set phases=[]
        For i=0:1:report.phases.%Size()-1 {
            Set phase=report.phases.%Get(i), view={"phase":(phase.phase),"agent_session":(phase.%Get("agent_session")),"state":(phase.state)}
            If phase.%IsDefined("sdk_stats") Do view.%Set("sdk_stats",phase.%Get("sdk_stats"))
            Do phases.%Push(view)
        }
        Do item.%Set("phases",phases)
        If report.state="completed" {
            Do item.%Set("result",report.result), item.%Set("questions",report.questions)
            Set summary=report.result.summary, category=$Select(summary.%Get("risk_detected"):"risk_signal",summary.unresolved:"unresolved",1:"no_signal_on_checked_issues")
            Set item.event=..Event(category)
        } Else {
            Set item.event=..Event("technical_failure")
            Do item.%Set("error","AI Hub review did not complete: provider, retrieval or output failure. No replacement verdict or automatic retry.")
        }
    } Catch ex {
        Set item.state="failed", item.event=..Event("technical_failure")
        Do item.%Set("error","Automatic review failed; inspect protected audit. Reserved requests are not replayed.")
        Do ##class(Contest.KnowledgeService).Audit("route.review.failed",key,ex.DisplayString())
    }
    Do item.%Set("completed",##class(Demo.Protocol).Now())
    Set ^ContestRouteReview("review",key)=item.%ToJSON()
    Do ##class(Contest.KnowledgeService).Audit("route.review.finished",key,item.state)
}

ClassMethod Pump()
{
    Job ##class(Contest.ProductionReviewService).Pump()::2
    If '$Test Do ##class(Demo.Protocol).Fail("Could not launch Production review worker")
    Job ##class(Contest.ProductionMonitor).Pump()::2
    If '$Test Do ##class(Demo.Protocol).Fail("Could not launch Production observer")
    Job ##class(Contest.DeclarationMonitor).Pump()::2
    If '$Test Do ##class(Demo.Protocol).Fail("Could not launch declaration observer")
    If '$Get(^ContestRouteReview("enabled")) Quit
    Lock +^ContestRouteReview("worker"):0
    If '$Test Quit
    Try {
        Do ..Scan()
        Set key=""
        For {
            Set key=$Order(^ContestRouteReview("review",key))
            If key="" Quit
            Set item={}.%FromJSON(^ContestRouteReview("review",key))
            If item.state="running" {
                Set item.state="interrupted", item.event=..Event("technical_failure")
                Do item.%Set("error","Previous worker ended without completion. No automatic replay.")
                Set ^ContestRouteReview("review",key)=item.%ToJSON()
                Do ##class(Contest.KnowledgeService).Audit("route.review.interrupted",key,item.error)
            } ElseIf (item.state="blocked_budget")&&($Data(^ContestRouteReview("allow",key))) {
                Do ..Review(key)
            }
        }
        Kill ^ContestRouteReview("lastError")
    } Catch ex {
        Set ^ContestRouteReview("lastError")="Automatic observer failed; inspect protected audit."
        Do ##class(Contest.KnowledgeService).Audit("route.observer.failed","",ex.DisplayString())
    }
    Lock -^ContestRouteReview("worker")
}

ClassMethod List(after As %String = "") As %DynamicObject
{
    Do ..Access()
    If (after'="")&&('$Match(after,"^[A-Za-z0-9-]{1,100}$")) Do ##class(Demo.Protocol).Fail("Bounded review cursor required")
    Set items=[], key=after, cursor=""
    For i=1:1:25 {
        Set key=$Order(^ContestRouteReview("review",key))
        If key="" Quit
        Set item={}.%FromJSON(^ContestRouteReview("review",key)), view={}
        If item.%IsDefined("report_id") {
            Set report=##class(Contest.RiskReviewV4).Status(item.%Get("report_id"))
            Do item.%Set("runtime_version",report.version)
        }
        For field="id","route_kind","batch_id","record_id","state","created","event","reserved_model_requests","actual_model_requests","error","authorization_id","runtime_version","trigger","parent_review_id" {
            If item.%IsDefined(field) Do view.%Set(field,item.%Get(field))
        }
        Do items.%Push(view)
    }
    If key'="" {
        If $Order(^ContestRouteReview("review",key))'="" Set cursor=key
    }
    Set authorizations={}, grantKey=""
    For {
        Set grantKey=$Order(^ContestRouteReview("allow",grantKey))
        If grantKey="" Quit
        Set grant={}.%FromJSON(^ContestRouteReview("allow",grantKey)), group=grant.%Get("authorization_id","original-p6")
        If 'authorizations.%IsDefined(group) Do authorizations.%Set(group,{"authorized_requests":0,"reserved_requests":0})
        Set summary=authorizations.%Get(group)
        Do summary.%Set("authorized_requests",summary.%Get("authorized_requests")+grant.%Get("max_model_requests"))
        If grant.reserved Do summary.%Set("reserved_requests",summary.%Get("reserved_requests")+grant.%Get("max_model_requests"))
    }
    Quit {"items":(items),"next_cursor":(cursor),"authorizations":(authorizations),"enabled":(+$Get(^ContestRouteReview("enabled"))),"heartbeat":(+$Get(^ContestRouteReview("heartbeat"))),"observer_identity":($Get(^ContestRouteReview("observerIdentity"))),"error":($Get(^ContestRouteReview("lastError"))),"execution":"not_executed","automatic_new_batch_budget":0}
}

ClassMethod Detail(id As %String) As %DynamicObject
{
    Do ..Access()
    If ('$Match(id,"^[A-Za-z0-9-]{1,100}$"))||('$Data(^ContestRouteReview("review",id))) Do ##class(Demo.Protocol).Fail("Route review not found")
    Set item={}.%FromJSON(^ContestRouteReview("review",id))
    If item.%IsDefined("report_id") {
        Set report=##class(Contest.RiskReviewV3).Status(item.%Get("report_id"))
        Do item.%Set("runtime_version",report.version)
        Set sources=[], seen={}
        If report.%IsDefined("packages") {
            For i=0:1:report.packages.%Size()-1 {
                Set package=report.packages.%Get(i)
                For j=0:1:package.evidence.%Size()-1 {
                    Set hit=package.evidence.%Get(j)
                    If 'seen.%IsDefined(hit.id) {
                        Set source={"id":(hit.id)}
                        For field="source_url","source_locator","source_version","kind","retrieved_on","content_sha256" {
                            If hit.metadata.%IsDefined(field) Do source.%Set(field,hit.metadata.%Get(field))
                        }
                        Do sources.%Push(source), seen.%Set(hit.id,1)
                    }
                }
            }
        }
        Do item.%Set("sources",sources)
    }
    If (item.state="failed")&&(item.%IsDefined("report_id")) {
        For i=0:1:report.phases.%Size()-1 {
            Set phase=report.phases.%Get(i)
            If phase.state="failed" {
                Set error=phase.%Get("error"), kind=$Select((error["timed out")||(error["timeout"):"provider_timeout",1:"provider_or_output_failure")
                Do item.%Set("failure",{"stage":(phase.phase),"kind":(kind),"retry":"disabled"})
            }
        }
    }
    Quit item
}

ClassMethod Action(body As %DynamicObject) As %DynamicObject
{
    Do ..Access(1), ##class(Contest.RouteGovernance).Shape(body,"id,revision,action,text")
    Do ##class(Contest.RouteGovernance).Text(body,"text",2000)
    If (body.%GetTypeOf("revision")'="number")||((body.revision\1)'=body.revision) Do ##class(Demo.Protocol).Fail("Exact integer event revision required")
    Set item=..Detail(body.id)
    Lock +^ContestRouteReview("worker"):2
    If '$Test Do ##class(Demo.Protocol).Fail("Event busy")
    Try {
        Set item=..Detail(body.id)
        If item.state="running" Do ##class(Demo.Protocol).Fail("Review still running")
        If item.event.revision'=body.revision Do ##class(Demo.Protocol).Fail("Event revision conflict")
        If '##class(Contest.EventService).AllowedTransition(item.event.state,body.action) Do ##class(Demo.Protocol).Fail("Event transition not allowed")
        Do item.event.actions.%Push({"actor":($Username),"time":(##class(Demo.Protocol).Now()),"before":(item.event.state),"after":(body.action),"text":(body.text)})
        Set item.event.state=body.action, item.event.revision=item.event.revision+1
        Set ^ContestRouteReview("review",body.id)=item.%ToJSON()
        Do ##class(Contest.KnowledgeService).Audit("route.review.human_action",body.id,body.action)
    } Catch ex { Lock -^ContestRouteReview("worker") Throw ex }
    Lock -^ContestRouteReview("worker")
    Quit item
}
}
