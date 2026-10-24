Class Contest.DeclarationMonitor
{
ClassMethod Access(write As %Boolean = 0) [ Private ]
{
    If ($Namespace'="TRIAGE")||('$System.Security.Check($Select(write:"ContestMonitorDeploy",1:"ContestMonitorRead"),"U")) Do ##class(Demo.Protocol).Fail("Declaration monitoring permission required")
}

ClassMethod Packet(facts As %DynamicArray) As %DynamicObject
{
    Set refs=[]
    For i=0:1:facts.%Size()-1 Do refs.%Push(facts.%Get(i).id)
    Set question="Compare actual recipient, fields, year-only transformation, configuration and delivery to the exact approved declaration and simulated registered relationship. Assess purpose consistency and minimum necessary. Approval is not proof of later purpose or conduct. Stable IDs do not imply a de-identification claim. Report actual deviations or material gaps, not generic patient authorization/BAA demands for internal use. Later conduct is a coverage boundary."
    Quit {"synthetic":true,"stage":"after_send","facts":(facts),"required_questions":[{"topic":"recipient_purpose","fact_ids":(refs),"question":(question)}]}
}

ClassMethod Evidence(id As %String) As %DynamicObject
{
    Do ..Access()
    Set run=##class(Contest.DeclarationExecution).Read(id)
    If run.state'="delivered" Do ##class(Demo.Protocol).Fail("Only verified delivered declaration batches can be monitored")
    Set r=run.grant.record, p=r.proposal, receipt=run.receipt
    Set limits="The approved proposal and registered synthetic relationship are frozen premises. Actual configuration, source-derived output, persisted messages and SQL readback were verified. Later recipient activities, retention disposal and purpose in practice are not observed; scope match alone does not prove those activities. No overall legal certification or replay."
    Set facts=[
        {"id":"declared_purpose","kind":"claim","verification":"unverified","origin":"immutable_submitted_proposal","text":(p.purpose.text)},
        {"id":"declared_activities","kind":"claim","verification":"unverified","origin":"immutable_submitted_proposal","text":(p.purpose.activities)},
        {"id":"declared_output","kind":"claim","verification":"unverified","origin":"immutable_submitted_proposal","text":(p.purpose.%Get("expected_output"))},
        {"id":"declared_access","kind":"claim","verification":"unverified","origin":"immutable_submitted_proposal","text":(p.handling.access)},
        {"id":"declared_retention","kind":"claim","verification":"unverified","origin":"immutable_submitted_proposal","text":(p.handling.retention)},
        {"id":"declared_sharing","kind":"claim","verification":"unverified","origin":"immutable_submitted_proposal","text":(p.handling.%Get("onward_sharing"))},
        {"id":"declared_necessity","kind":"claim","verification":"unverified","origin":"immutable_submitted_proposal","text":(p.data.necessity)},
        {"id":"approved_scope","kind":"observation","verification":"verified","origin":"hash_bound_review_and_human_decision","text":({"declaration":(r.id),"revision":(r.revision),"digest":(r.digest),"decision_hash":(r.decision.%Get("record_hash")),"approved_by":(r.decision.%Get("decided_by")),"approved_at":(r.decision.%Get("decided_at")),"resources":(p.data.resources),"fields":(p.data.fields),"limit":(p.data.%Get("max_records")),"recipe":(p.handling.%Get("recipe_id"))}.%ToJSON())},
        {"id":"observed_output","kind":"observation","verification":"verified","origin":"source_projection_and_SQL_readback","text":({"inspection":(receipt.inspection),"recipe":(p.handling.%Get("recipe_id")),"output_hash":(receipt.%Get("output_hash")),"source_hash":(receipt.%Get("source_hash")),"birthDate_transform":"year only; stable resource IDs remain linkable"}.%ToJSON())},
        {"id":"delivery_evidence","kind":"observation","verification":"verified","origin":"persisted_BS_BP_BO_and_SQL","text":({"binding":(run.grant.binding),"batch":(receipt.%Get("batch_id")),"session":(receipt.%Get("session_id")),"source_message":(receipt.%Get("message_id")),"receiver_message":(receipt.%Get("receiver_message_id")),"recipient":(receipt.recipient),"received_at":(receipt.%Get("received_at")),"readback":(receipt.%Get("receiver_readback_match")),"receipt_hash":(receipt.%Get("receipt_hash"))}.%ToJSON())},
        {"id":"approved_scenario","kind":"observation","verification":"verified","origin":"immutable_registered_catalog_and_project_approval","text":({"organization":(r.context.organization),"recipient":(r.context.recipient),"purpose_category":(p.purpose.category),"review_task":(r.review.task.id),"review_assessment":(r.review.task.assessment),"premise":"The stated purpose and safeguards are approved proposed conditions, not observations of later recipient conduct. The registered same-covered-entity relationship is established within this synthetic catalog."}.%ToJSON())},
        {"id":"evidence_limits","kind":"missing_information","verification":"unknown","origin":"explicit_coverage_boundary","text":(limits)}
    ]
    Set packet=..Packet(facts)
    Do ##class(Contest.RiskReviewV4).ValidatePacket(packet)
    Set value={"execution_id":(id),"record_id":(r.id),"revision":(r.revision),"digest":(r.digest),"decision_hash":(r.decision.%Get("record_hash")),"task_id":(r.review.task.id),"task_hash":(r.review.task.%Get("record_hash")),"grant_hash":(run.%Get("grant_hash")),"receipt_hash":(receipt.%Get("receipt_hash")),"batch_id":(run.grant.%Get("batch_id")),"packet":(packet),"limits":(limits)}
    Do value.%Set("evidence_hash",##class(Contest.ExportEvidence).Digest(value))
    Quit value
}

ClassMethod Recapture(id As %String) As %DynamicObject
{
    Do ..Access(1)
    Lock +^ContestDeclarationMonitor("worker"):2
    If '$Test Do ##class(Demo.Protocol).Fail("Observer busy")
    Try {
        Set item=..Detail(id)
        If (item.state'="evidence_failed")||$Data(^ContestDeclarationMonitor("allow",id)) Do ##class(Demo.Protocol).Fail("Only an unfunded evidence failure can be explicitly recaptured")
        Set evidence=..Evidence(id)
        If 'item.%IsDefined("capture_failures") Do item.%Set("capture_failures",[])
        Do item.%Get("capture_failures").%Push({"error":(item.error),"time":(##class(Demo.Protocol).Now())})
        Set item.state="blocked_budget", item.error=""
        Do item.%Set("evidence",evidence), item.%Set("evidence_hash",evidence.%Get("evidence_hash")), item.%Set("receipt_hash",evidence.%Get("receipt_hash"))
        Do item.%Remove("heartbeat"), item.%Remove("observer_error"), item.%Remove("authorized_requests")
        Set ^ContestDeclarationMonitor("review",id)=item.%ToJSON()
        Do ##class(Contest.KnowledgeService).Audit("declaration.monitor.recaptured",id,"Previous capture error retained; no inference or delivery")
    } Catch ex { Lock -^ContestDeclarationMonitor("worker") Throw ex }
    Lock -^ContestDeclarationMonitor("worker")
    Quit ..Detail(id)
}

ClassMethod Scan()
{
    Do ..Access(1)
    Set id=""
    For {
        Set id=$Order(^ContestDeclarationExecution("run",id))
        If id="" Quit
        If $Data(^ContestDeclarationMonitor("review",id)) Continue
        Set raw=##class(Contest.DeclarationExecution).Load(id)
        If raw.state'="delivered" Continue
        Set item={"id":(id),"state":"blocked_budget","created":(##class(Demo.Protocol).Now()),"reserved_requests":0,"attempted_requests":0,"result":null,"report_id":"","error":"","event":{"state":"open","revision":1,"actions":[]},"origin":"automatic_after_send","model_calls":0}
        Try {
            Set evidence=..Evidence(id)
            Do item.%Set("evidence",evidence), item.%Set("evidence_hash",evidence.%Get("evidence_hash")), item.%Set("receipt_hash",evidence.%Get("receipt_hash"))
        } Catch ex {
            Set item.state="evidence_failed", item.error="Delivered-batch evidence verification failed; no model called."
            Do ##class(Contest.KnowledgeService).Audit("declaration.monitor.capture.failed",id,ex.DisplayString())
        }
        Set ^ContestDeclarationMonitor("review",id)=item.%ToJSON()
        Do ##class(Contest.KnowledgeService).Audit("declaration.monitor.captured",id,item.state)
    }
    Set ^ContestDeclarationMonitor("heartbeat")=##class(Demo.Protocol).Now()
}

ClassMethod Detail(id As %String) As %DynamicObject
{
    Do ..Access()
    If ('$Match(id,"^declaration-run-[A-Za-z0-9-]{1,80}$"))||('$Data(^ContestDeclarationMonitor("review",id))) Do ##class(Demo.Protocol).Fail("Automatic declaration monitoring record not found")
    Set item={}.%FromJSON(^ContestDeclarationMonitor("review",id))
    If item.%IsDefined("evidence") {
        Set copy={}.%FromJSON(item.evidence.%ToJSON()), digest=copy.%Get("evidence_hash")
        Do copy.%Remove("evidence_hash")
        If (digest'=item.%Get("evidence_hash"))||(digest'=##class(Contest.ExportEvidence).Digest(copy)) Do ##class(Demo.Protocol).Fail("Captured monitor evidence integrity mismatch")
        Set fresh=..Evidence(id)
        If fresh.%Get("evidence_hash")'=digest Do ##class(Demo.Protocol).Fail("Observed batch no longer matches its captured evidence")
    }
    If item.%Get("report_id")'="" {
        Set report=##class(Contest.RiskReviewV4).Status(item.%Get("report_id")), grant={}.%FromJSON(^ContestDeclarationMonitor("allow",id)), auth=report.authorization
        If (auth.%Get("request_key")'=("monitor-"_id))||(auth.%Get("input_hash")'=##class(Demo.Protocol).Hash(item.evidence.packet.%ToJSON()))||(auth.%Get("contract_hash")'=grant.%Get("contract_hash"))||(auth.%Get("config_hash")'=grant.%Get("config_hash"))||(auth.%Get("agent_id")'=grant.%Get("agent_id"))||(auth.%Get("source_revision")'=grant.%Get("source_revision")) Do ##class(Demo.Protocol).Fail("Monitor report does not match its frozen evidence and source")
        If (item.state="completed")&&((report.state'="completed")||(item.result.%ToJSON()'=report.result.%ToJSON())) Do ##class(Demo.Protocol).Fail("Accepted monitor result differs from its actual report")
        Do item.%Set("report",report)
    }
    Do item.%Set("heartbeat",+$Get(^ContestDeclarationMonitor("heartbeat"))), item.%Set("observer_error",$Get(^ContestDeclarationMonitor("error")))
    Do item.%Set("authorized_requests",$Select($Data(^ContestDeclarationMonitor("allow",id)):2,1:0))
    Quit item
}

ClassMethod Plan(id As %String) As %DynamicObject
{
    Do ..Access(1)
    Set item=..Detail(id)
    If (item.state'="blocked_budget")||$Data(^ContestDeclarationMonitor("allow",id)) Do ##class(Demo.Protocol).Fail("Only an unfunded automatically captured review can receive a new grant")
    Set evidence=..Evidence(id)
    If evidence.%Get("evidence_hash")'=item.%Get("evidence_hash") Do ##class(Demo.Protocol).Fail("Captured evidence changed")
    Set config={}.%FromJSON(^ContestRouteReview("config")), source=##class(Contest.AgentService).Get(config.%Get("agent_id"))
    If ('##class(Contest.PrivacyEvaluation).Eligible(source))||(source.model'="deepseek-flash") Do ##class(Demo.Protocol).Fail("Eligible source Agent required")
    Set consent={"id":(id),"evidence_hash":(item.%Get("evidence_hash")),"receipt_hash":(item.%Get("receipt_hash")),"agent_id":(source.id),"source_revision":(source.revision),"config_hash":(source.%Get("config_hash")),"contract_hash":(##class(Contest.RiskReviewV4).ContractHash()),"max_model_requests":2,"acknowledge_cost":false}
    Quit {"consent":(consent),"model":(source.model),"model_calls":0}
}

ClassMethod ValidateConsent(body As %DynamicObject, expected As %DynamicObject)
{
    Do ##class(Contest.RouteGovernance).Shape(body,"id,evidence_hash,receipt_hash,agent_id,source_revision,config_hash,contract_hash,max_model_requests,acknowledge_cost")
    If (body.%GetTypeOf("acknowledge_cost")'="boolean")||('body.%Get("acknowledge_cost"))||(body.%Get("max_model_requests")'=2) Do ##class(Demo.Protocol).Fail("Explicit two-request monitoring cost consent required")
    For field="id","evidence_hash","receipt_hash","agent_id","source_revision","config_hash","contract_hash","max_model_requests" {
        If (body.%GetTypeOf(field)'=expected.%GetTypeOf(field))||(body.%Get(field)'=expected.%Get(field)) Do ##class(Demo.Protocol).Fail("Monitoring consent changed: "_field)
    }
}

ClassMethod Authorize(body As %DynamicObject) As %DynamicObject
{
    Do ..Access(1)
    Lock +^ContestDeclarationMonitor("worker"):2
    If '$Test Do ##class(Demo.Protocol).Fail("Monitoring worker busy")
    Try {
        Set id=body.id
        If $Data(^ContestDeclarationMonitor("allow",id)) {
            Set expected={}.%FromJSON(^ContestDeclarationMonitor("allow",id))
        } Else { Set expected=..Plan(id).consent }
        Do ..ValidateConsent(body,expected), expected.%Set("acknowledge_cost",1,"boolean")
        If '$Data(^ContestDeclarationMonitor("allow",id)) {
            Set ^ContestDeclarationMonitor("allow",id)=expected.%ToJSON()
            Do ##class(Contest.KnowledgeService).Audit("declaration.monitor.authorized",id,"At most two requests; no retries or delivery")
        }
        Set item=..Detail(id)
    } Catch ex { Lock -^ContestDeclarationMonitor("worker") Throw ex }
    Lock -^ContestDeclarationMonitor("worker")
    Quit item
}

ClassMethod Review(id As %String) [ Private ]
{
    Set item={}.%FromJSON(^ContestDeclarationMonitor("review",id)), grant={}.%FromJSON(^ContestDeclarationMonitor("allow",id))
    Set item.state="running"
    Do item.%Set("reserved_requests",2)
    Set ^ContestDeclarationMonitor("review",id)=item.%ToJSON()
    Try {
        Set evidence=..Evidence(id)
        If evidence.%Get("evidence_hash")'=grant.%Get("evidence_hash") Do ##class(Demo.Protocol).Fail("Evidence changed before review")
        Set source=##class(Contest.AgentService).Get(grant.%Get("agent_id"))
        If (source.revision'=grant.%Get("source_revision"))||(source.%Get("config_hash")'=grant.%Get("config_hash"))||(##class(Contest.RiskReviewV4).ContractHash()'=grant.%Get("contract_hash")) Do ##class(Demo.Protocol).Fail("Pinned model or contract changed")
        Set consent={"request_key":("monitor-"_id),"agent_id":(source.id),"source_revision":(source.revision),"config_hash":(source.%Get("config_hash")),"input_hash":(##class(Demo.Protocol).Hash(evidence.packet.%ToJSON())),"contract_hash":(grant.%Get("contract_hash")),"max_model_requests":2,"acknowledge_cost":true}
        Set report=##class(Contest.RiskReviewV4).Run(evidence.packet,consent), item.state=report.state
        Do item.%Set("report_id",report.id), item.%Set("attempted_requests",report.%Get("reserved_model_requests")), item.%Set("model_calls",report.%Get("reserved_model_requests"))
        If report.state="completed" { Set item.result=report.result }
        Else { Set item.error="AI monitoring did not complete. No replacement result or automatic retry." }
    } Catch ex {
        Set item.state="failed", item.error="Automatic comparison failed. Inspect protected audit; no automatic retry."
        Do ##class(Contest.KnowledgeService).Audit("declaration.monitor.failed",id,ex.DisplayString())
    }
    Set ^ContestDeclarationMonitor("review",id)=item.%ToJSON()
    Do ##class(Contest.KnowledgeService).Audit("declaration.monitor.finished",id,item.state)
}

ClassMethod Pump()
{
    Do ..Access(1)
    Lock +^ContestDeclarationMonitor("worker"):0
    If '$Test Quit
    Try {
        Do ..Scan()
        Set id=""
        For {
            Set id=$Order(^ContestDeclarationMonitor("review",id))
            If id="" Quit
            Set item={}.%FromJSON(^ContestDeclarationMonitor("review",id))
            If item.state="running" {
                Set item.state="interrupted", item.error="Previous worker ended without a terminal result; allowance retained, no replay."
                Set ^ContestDeclarationMonitor("review",id)=item.%ToJSON()
            } ElseIf (item.state="blocked_budget")&&$Data(^ContestDeclarationMonitor("allow",id)) { Do ..Review(id) }
        }
        Kill ^ContestDeclarationMonitor("error")
    } Catch ex {
        Set ^ContestDeclarationMonitor("error")="Declaration observer failed; inspect protected audit."
        Do ##class(Contest.KnowledgeService).Audit("declaration.monitor.observer.failed","",ex.DisplayString())
    }
    Lock -^ContestDeclarationMonitor("worker")
}

ClassMethod Action(body As %DynamicObject) As %DynamicObject
{
    Do ..Access(1), ##class(Contest.RouteGovernance).Shape(body,"id,revision,action,text"), ##class(Contest.RouteGovernance).Text(body,"text",2000)
    If (body.%GetTypeOf("revision")'="number")||((body.revision\1)'=body.revision) Do ##class(Demo.Protocol).Fail("Exact event revision required")
    Lock +^ContestDeclarationMonitor("worker"):2
    If '$Test Do ##class(Demo.Protocol).Fail("Monitoring event busy")
    Try {
        Set item=..Detail(body.id)
        If (item.state="running")||(item.event.revision'=body.revision)||('##class(Contest.EventService).AllowedTransition(item.event.state,body.action)) Do ##class(Demo.Protocol).Fail("Event revision or transition conflict")
        Do item.event.actions.%Push({"actor":($Username),"time":(##class(Demo.Protocol).Now()),"before":(item.event.state),"after":(body.action),"text":(body.text)})
        Set item.event.state=body.action, item.event.revision=item.event.revision+1
        Do item.%Remove("report"), item.%Remove("heartbeat"), item.%Remove("observer_error"), item.%Remove("authorized_requests")
        Set ^ContestDeclarationMonitor("review",body.id)=item.%ToJSON()
        Do ##class(Contest.KnowledgeService).Audit("declaration.monitor.human_action",body.id,body.action)
    } Catch ex { Lock -^ContestDeclarationMonitor("worker") Throw ex }
    Lock -^ContestDeclarationMonitor("worker")
    Quit ..Detail(body.id)
}
}
