Class Contest.MultiAudit
{
ClassMethod Packet(record As %DynamicObject, branch As %DynamicObject) As %DynamicObject
{
    If (branch.state'="acknowledged")||('branch.receipt.%Get("readback_match"))||(branch.%Get("payload_hash")'=branch.receipt.%Get("payload_hash")) Do ##class(Demo.Protocol).Fail("Acknowledged actual receiver evidence required")
    Set original={}.%FromJSON(branch.%ToJSON())
    Do original.%Remove("evidence_hash"), original.%Remove("audit")
    If branch.%Get("evidence_hash")'=##class(Contest.ExportEvidence).Digest(original) Do ##class(Demo.Protocol).Fail("Frozen outbound evidence changed")
    Set source=record.profiles.hospital, target=record.profiles.%Get(branch.id)
    If (source.hash'=##class(Contest.ExportEvidence).Digest(source.profile))||(target.hash'=##class(Contest.ExportEvidence).Digest(target.profile)) Do ##class(Demo.Protocol).Fail("Frozen institution profile changed")
    Set context={"source_id":(source.profile.id),"source":(source.profile.name),"recipient_id":(target.profile.id),"recipient":(target.profile.name),"recipient_type":(target.profile.type),"parent_id":(target.profile.%Get("parent_id")),"relationship":(target.profile.relationship),"responsibilities":(target.profile.responsibilities)}
    Set facts=[
      {"id":"approved_scenario","kind":"observation","verification":"verified","origin":"versioned_user_confirmed_synthetic_profiles","text":"The profile's substantive organization relationship, stated purpose and conditions are established within this simulation. They are not independent real-world evidence or legal permission. All message data concern the same synthetic patient and care episode."},
      {"id":"organization_context","kind":"observation","verification":"verified","origin":"frozen_synthetic_profile","text":(context.%ToJSON())},
      {"id":"source_context","kind":"observation","verification":"verified","origin":"frozen_source_profile","text":(source.profile.requirements)},
      {"id":"business_purpose","kind":"observation","verification":"verified","origin":"confirmed_per_branch_demo_purpose","text":(target.profile.purpose)},
      {"id":"release_conditions","kind":"observation","verification":"verified","origin":"confirmed_demo_conditions_not_instructions","text":(target.profile.requirements)},
      {"id":"actual_wire","kind":"observation","verification":"verified","origin":"actual_post_transform_outbound_payload","text":(branch.facts.%ToJSON())},
      {"id":"receiver_evidence","kind":"observation","verification":"verified","origin":"protocol_ack_and_persisted_readback","text":({"protocol":(branch.protocol),"namespace":(branch.namespace),"payload_hash":(branch.%Get("payload_hash")),"message_id":(branch.%Get("message_id")),"session_id":(branch.%Get("session_id")),"readback_match":true,"scope":"Receipt confirms local simulated acceptance only, not later use."}.%ToJSON())},
      {"id":"receiving_policy","kind":"local_policy","verification":"verified","origin":"versioned_demo_receiving_agreement","text":({"allowed":(target.profile.%Get("allowed_fields")),"prohibited":(target.profile.%Get("prohibited_fields")),"actual_mismatches":(branch.%Get("policy_mismatches")),"scope":"Operational agreement, not itself HIPAA law or disclosure authorization."}.%ToJSON())},
      {"id":"source_and_mapping","kind":"observation","verification":"verified","origin":"fhir_read_and_actual_host_association","text":({"source_pins":(record.%Get("source_pins")),"host_partners":(record.%Get("host_partners")),"mapping_version":(record.%Get("mapping_version")),"source_profile_revision":(source.revision),"target_profile_revision":(target.revision)}.%ToJSON())},
      {"id":"coverage","kind":"missing_information","verification":"unknown","origin":"bounded_demo_scope","text":"No comprehensive free-text identifier inspection, downstream-use verification or current-law certification. These coverage limits do not invalidate known synthetic scenario premises."}
    ], refs=[]
    For i=0:1:facts.%Size()-1 Do refs.%Push(facts.%Get(i).id)
    Set topic=$Select(branch.id="research":"deidentification",1:"recipient_purpose")
    Set packet={"synthetic":true,"stage":"after_send","facts":(facts),"required_questions":[{"topic":(topic),"fact_ids":(refs),"question":"Assess the applicable HIPAA conditions and exceptions for this branch using confirmed organization context and actual outbound fields. Distinguish receiving-agreement deviations from legal condition failures. Keep missing material conditions unresolved; no comprehensive compliance certification."}]}
    Do ##class(Contest.MultiReview).ValidatePacket(packet)
    Quit packet
}

ClassMethod Start(body As %DynamicObject) As %DynamicObject
{
    Do ##class(Contest.OrganizationCatalog).Access(1), ##class(Contest.RouteGovernance).Shape(body,"run_id,acknowledge_cost,acknowledge_synthetic")
    For field="acknowledge_cost","acknowledge_synthetic" {
        If (body.%GetTypeOf(field)'="boolean")||('body.%Get(field)) Do ##class(Demo.Protocol).Fail("Explicit cost and minimized synthetic export consent required")
    }
    Set id=body.%Get("run_id"), record=##class(Contest.MultiOrganization).Read(id)
    If (record.state'="completed")&&(record.state'="partial") Do ##class(Demo.Protocol).Fail("Finished distribution required before advisory audit")
    For i=0:1:record.branches.%Size()-1 {
        If record.branches.%Get(i).state="acknowledged" Set packet=..Packet(record,record.branches.%Get(i))
    }
    Set config=..Source()
    Set previous=$Namespace
    Try {
        Set $Namespace="DEMODISTRIBUTION", probe=##class(Contest.Multi.AuditRequest).%New(), probe.RunId=id, probe.InspectOnly=1
        Set sc=##class(Ens.Director).CreateBusinessService("AuditSource",.service) $$$ThrowOnError(sc)
        Set sc=service.ProcessInput(probe,.reply) $$$ThrowOnError(sc)
        If reply.Outcome'="preflight_passed" Do ##class(Demo.Protocol).Fail("Audit Business Process preflight did not pass")
    } Catch ex { Set $Namespace=previous Throw ex }
    Set $Namespace=previous
    Set previous=$Namespace, contract=##class(Contest.MultiReview).ContractHash(), boot=$Get(^ContestAgents("boot"))
    Try {
        Set $Namespace="DEMODISTRIBUTION"
        Lock +^ContestMulti("runLock",id):3
        If '$Test Do ##class(Demo.Protocol).Fail("Run busy")
        Try {
            Set record=##class(Contest.Multi.Runtime).Read(id)
            If 'record.%IsDefined("audit_state") {
                Do record.%Set("audit_state","running"), record.%Set("audit_authorization",{"actor":($Username),"at":(##class(Demo.Protocol).Now()),"max_reviews":3,"max_model_requests":6,"automatic_paid_retries":0,"agent":(config),"contract_hash":(contract),"boot":(boot)})
                Do ##class(Contest.Multi.Runtime).Save(record)
                Set $Namespace="TRIAGE"
                Job ##class(Contest.MultiAudit).Dispatch(id)::5
                Set $Namespace="DEMODISTRIBUTION"
                If '$Test Do ##class(Demo.Protocol).Fail("Audit worker launch failed; authorization reserved, no automatic retry")
            }
        } Catch ex { Lock -^ContestMulti("runLock",id) Throw ex }
        Lock -^ContestMulti("runLock",id)
    } Catch ex { Set $Namespace=previous Throw ex }
    Set $Namespace=previous
    Do ##class(Contest.KnowledgeService).Audit("distribution.audit.authorized",id,"Maximum three reviews/six model requests; no automatic paid retries")
    Quit record
}

ClassMethod Source() As %DynamicObject
{
    Set agents=##class(Contest.AgentService).List(), config=""
    For i=0:1:agents.agents.%Size()-1 {
        Set candidate=agents.agents.%Get(i)
        If (candidate.status="published")&&##class(Contest.PrivacyEvaluation).Eligible(candidate) Set config=candidate
    }
    If '$IsObject(config) Do ##class(Demo.Protocol).Fail("Published eligible AI Hub reviewer required")
    Quit config
}

ClassMethod Preflight(id As %String)
{
    Do ##class(Contest.OrganizationCatalog).Access(1)
    Set record=##class(Contest.MultiOrganization).Read(id), config=..Source()
    For i=0:1:record.branches.%Size()-1 {
        Set branch=record.branches.%Get(i)
        If branch.state'="acknowledged" Continue
        Set packet=..Packet(record,branch), questions=##class(Contest.MultiReview).Questions(packet,{"questions":[]})
        Set packages=##class(Contest.MultiReview).PrepareEvidence("multi-preflight-"_id,config,questions)
        For j=0:1:packages.%Size()-1 If packages.%Get(j).availability'="available" Do ##class(Demo.Protocol).Fail("Complete normative knowledge sections unavailable; no model request authorized")
    }
}

ClassMethod Dispatch(id As %String)
{
    Set previous=$Namespace
    Try {
        Set $Namespace="DEMODISTRIBUTION", request=##class(Contest.Multi.AuditRequest).%New(), request.RunId=id
        Set sc=##class(Ens.Director).CreateBusinessService("AuditSource",.service) $$$ThrowOnError(sc)
        Set sc=service.ProcessInput(request,.reply) $$$ThrowOnError(sc)
    } Catch ex {
        Set $Namespace="TRIAGE"
        Do ##class(Contest.KnowledgeService).Audit("distribution.audit.dispatch.failed",id,ex.DisplayString())
        Set record=##class(Contest.MultiOrganization).Read(id)
        Do record.%Set("audit_state","failed"), record.%Set("audit_error",ex.DisplayString())
        Set $Namespace="DEMODISTRIBUTION"
        Do ##class(Contest.Multi.Runtime).Save(record)
    }
    Set $Namespace=previous
}

ClassMethod Worker(id As %String, session As %String, message As %String)
{
    Set previous=$Namespace
    Try {
        Set record=##class(Contest.MultiOrganization).Read(id), config=record.%Get("audit_authorization").agent, failed=0
        If record.%Get("audit_state")'="running" Do ##class(Demo.Protocol).Fail("Active single-use audit grant required")
        Do record.%Set("audit_interop",{"namespace":"DEMODISTRIBUTION","production":"Contest.Multi.Production","host":"AdvisoryAudit","session_id":(session),"message_id":(message),"execution":"AI Hub phases execute inside this Business Process; TRIAGE holds the control-plane knowledge and reports."})
        Set $Namespace="DEMODISTRIBUTION"
        Do ##class(Contest.Multi.Runtime).Save(record)
        Set $Namespace="TRIAGE"
        For i=0:1:record.branches.%Size()-1 {
            Set branch=record.branches.%Get(i)
            If branch.state'="acknowledged" Continue
            If branch.%IsDefined("audit") Continue
            Set packet=..Packet(record,branch), consent={"request_key":("multi-"_id_"-"_branch.id),"acknowledge_cost":true,"max_model_requests":2,"source_revision":(config.revision),"agent_id":(config.id),"config_hash":(config.%Get("config_hash")),"input_hash":(##class(Demo.Protocol).Hash(packet.%ToJSON())),"contract_hash":(##class(Contest.MultiReview).ContractHash())}
            Set ^ContestMultiAudit("context",$Job)={"id":(id),"input_hash":(consent.%Get("input_hash")),"contract_hash":(consent.%Get("contract_hash"))}.%ToJSON()
            Set report=##class(Contest.MultiReview).Run(packet,consent), assessment="not_assessed", explanation="Audit did not return a validated assessment. Inspect the preserved failure."
            Do report.%Set("interop",record.%Get("audit_interop"))
            Set ^ContestRiskReview("report",report.id)=report.%ToJSON()
            If report.state'="completed" Set failed=1
            If report.state="completed" {
                Set result=report.result
                Set assessment=$Select(result.summary.%Get("risk_detected"):"risk_identified",result.summary.unresolved:"information_required",1:"no_signal_on_checked_issues"), explanation=""
                For j=0:1:result.issues.%Size()-1 Set explanation=explanation_$Select(j>0:" ",1:"")_result.issues.%Get(j).explanation
            }
            Do branch.%Set("audit",{"state":(report.state),"assessment":(assessment),"explanation":(explanation),"next_step":($Select(assessment="risk_identified":"Review the receiving agreement and remove unnecessary identifiers before a separately authorized future export.",assessment="information_required":"Review missing material facts; this is not an all-clear.",assessment="not_assessed":"Inspect the preserved technical failure. No valid AI conclusion was produced; no automatic paid retry.",1:"No signal on checked issues only; retain human review.")),"report_id":(report.id),"model_requests":(report.%Get("reserved_model_requests")),"raw":(report)})
            Set $Namespace="DEMODISTRIBUTION"
            Do ##class(Contest.Multi.Runtime).Save(record)
            Set $Namespace="TRIAGE"
            Set pid=##class(Contest.ProductionMonitor).Key("DEMODISTRIBUTION","Contest.Multi.Production")
            Do ##class(Contest.ProductionMonitor).Emit(pid,"multi-"_id_"-"_branch.id,"risk_review",$Select(assessment="risk_identified":"warning",assessment="not_assessed":"error",1:"info"),"Organization-aware audit: "_branch.organization_" / "_assessment,{"run_id":(id),"branch":(branch.id),"report_id":(report.id),"assessment":(assessment),"scope":"Advisory post-send review; acknowledge or add a human note in Production events. No delivery action.","detail_page":"/demo"})
        }
        Do record.%Set("audit_state",$Select(failed:"completed_with_errors",1:"completed"))
        Set $Namespace="DEMODISTRIBUTION"
        Do ##class(Contest.Multi.Runtime).Save(record)
    } Catch ex {
        Set $Namespace="TRIAGE"
        Do ##class(Contest.KnowledgeService).Audit("distribution.audit.failed",id,ex.DisplayString())
        Set record=##class(Contest.MultiOrganization).Read(id)
        Do record.%Set("audit_state","failed"), record.%Set("audit_error",ex.DisplayString())
        Set $Namespace="DEMODISTRIBUTION"
        Do ##class(Contest.Multi.Runtime).Save(record)
    }
    Set $Namespace="TRIAGE"
    Kill ^ContestMultiAudit("context",$Job)
    Set $Namespace=previous
}
}
