Class Contest.M5Demo
{
ClassMethod ProductionId() As %String
{
    Quit ##class(Contest.ProductionMonitor).Key("M5OBSERVATION","Contest.M5.Production")
}

ClassMethod Snapshot(hash As %String = "") As %DynamicObject
{
    Do ##class(Contest.OrganizationCatalog).Access()
    Set current=##class(Contest.ProductionMonitor).Snapshot("M5OBSERVATION")
    If ('current.running)||(current.id'=..ProductionId()) Do ##class(Demo.Protocol).Fail("Fixed running M5 Production required")
    If (hash'="")&&(hash'=current.%Get("config_hash")) Do ##class(Demo.Protocol).Fail("M5 configuration changed; refresh first")
    Quit current
}

ClassMethod Payload() As %DynamicObject
{
    Quit {"export_context":{"schema":1,"synthetic":true,"purpose":"external_statistics","recipient":"external_analytics","method":"safe_harbor","processing_status":"deidentified"},"name":"SYNTHETIC-DEMO-NAME","mrn":"SYNTHETIC-DEMO-MRN","birthDate":"2001-02-03","status":"finished"}
}

ClassMethod Presets() As %DynamicArray
{
    Set all=##class(Contest.OrganizationCatalog).Presets(), result=[]
    For i=0:1:all.%Size()-1 {
        Set p=all.%Get(i)
        If (p.id="hospital")||(p.id="research") Do result.%Push(p)
    }
    Quit result
}

ClassMethod ProfileSave(body As %DynamicObject) As %DynamicObject
{
    Do ##class(Contest.OrganizationCatalog).Access(1), ##class(Contest.RouteGovernance).Shape(body,"profile,expected_revision,confirmed")
    Do ##class(Contest.OrganizationCatalog).Validate(body.profile), ##class(Contest.ProductionFlow).Integer(body,"expected_revision",0,100000)
    If (body.%GetTypeOf("confirmed")'="boolean")||('body.confirmed) Do ##class(Demo.Protocol).Fail("Explicit profile save required")
    Set p=body.profile
    If (p.id'="hospital")&&(p.id'="research") Do ##class(Demo.Protocol).Fail("Only fixed M5 source and research profiles supported")
    Do ..ValidateProfile({"id":(p.id),"profile":(p),"hash":(##class(Contest.ExportEvidence).Digest(p))})
    Lock +^ContestM5Demo("lock"):3
    If '$Test Do ##class(Demo.Protocol).Fail("M5 demo busy")
    Try {
        Set old=$Get(^ContestM5Demo("profile",p.id)), revision=0
        If old'="" Set revision={}.%FromJSON(old).revision
        If body.%Get("expected_revision")'=revision Do ##class(Demo.Protocol).Fail("Profile revision changed")
        Set other=$Select(p.id="hospital":"research",1:"hospital")
        If $Data(^ContestM5Demo("profile",other)) {
            If {}.%FromJSON(^ContestM5Demo("profile",other)).profile.partner=p.partner Do ##class(Demo.Protocol).Fail("Source and recipient require distinct partner keys")
        }
        Set result={"id":(p.id),"revision":(revision+1),"profile":(p),"hash":(##class(Contest.ExportEvidence).Digest(p)),"confirmed_by":($Username),"confirmed_at":(##class(Demo.Protocol).Now())}
        Set ^ContestM5Demo("profile",p.id)=result.%ToJSON()
    } Catch ex { Lock -^ContestM5Demo("lock") Throw ex }
    Lock -^ContestM5Demo("lock")
    Do ##class(Contest.KnowledgeService).Audit("m5.demo.profile",p.id,result.hash)
    Quit result
}

ClassMethod Profiles() As %DynamicObject
{
    Set profiles={}
    For id="hospital","research" {
        If '$Data(^ContestM5Demo("profile",id)) Do ##class(Demo.Protocol).Fail("Save both M5 organization profiles first")
        Set p={}.%FromJSON(^ContestM5Demo("profile",id))
        Do ..ValidateProfile(p), profiles.%Set(id,p)
    }
    Quit profiles
}

ClassMethod ValidateProfile(p As %DynamicObject)
{
    Do ##class(Contest.OrganizationCatalog).Validate(p.profile)
    If (p.id'=p.profile.id)||(p.hash'=##class(Contest.ExportEvidence).Digest(p.profile)) Do ##class(Demo.Protocol).Fail("Frozen M5 profile integrity mismatch")
    If ($Length(p.profile.%ToJSON())>1700)||($Length(p.profile.purpose)>600) Do ##class(Demo.Protocol).Fail("M5 demo profile exceeds model-fact bounds: 1700 characters total, 600 for purpose")
}

ClassMethod Send(body As %DynamicObject) As %DynamicObject
{
    Do ##class(Contest.OrganizationCatalog).Access(1), ##class(Contest.RouteGovernance).Shape(body,"run_id,config_hash,confirmed")
    If (body.%GetTypeOf("run_id")'="string")||('$Match(body.%Get("run_id"),"^m5-demo-[A-Za-z0-9-]{1,48}$")) Do ##class(Demo.Protocol).Fail("Stable bounded M5 demo run ID required")
    If (body.%GetTypeOf("confirmed")'="boolean")||('body.confirmed) Do ##class(Demo.Protocol).Fail("Explicit synthetic send required")
    Set current=..Snapshot(body.%Get("config_hash")), pid=current.id
    Lock +^ContestM5Demo("lock"):3
    If '$Test Do ##class(Demo.Protocol).Fail("M5 demo busy")
    Try {
        Set id=body.%Get("run_id")
        If $Data(^ContestM5Demo("run",id)) {
            Set result={}.%FromJSON(^ContestM5Demo("run",id))
            If result.%Get("config_hash")'=body.%Get("config_hash") Do ##class(Demo.Protocol).Fail("Run identity conflict")
        } Else {
            Set managed=##class(Contest.ProductionMonitor).Record(pid)
            If 'managed.enabled Do ##class(Demo.Protocol).Fail("Enable M5 monitoring before sending")
            Set auth=$Get(^ContestProductionReview("active",pid))
            If auth'="" {
                Set active={}.%FromJSON(^ContestProductionReview("grant",pid,auth))
                If active.enabled&&(active.definition.%Get("expires_at")>##class(Demo.Protocol).Now())&&(active.%Get("used_reviews")<active.definition.%Get("max_reviews")) Do ##class(Demo.Protocol).Fail("Revoke outstanding M5 model authorization before a new synthetic send")
            }
            If '$Data(^ContestProductionEvidence("allow",pid)) Do ##class(Demo.Protocol).Fail("Authorize M5 local inspection before sending")
            Set allow={}.%FromJSON(^ContestProductionEvidence("allow",pid))
            If ('allow.enabled)||(allow.%Get("config_hash")'=current.%Get("config_hash")) Do ##class(Demo.Protocol).Fail("Fresh exact M5 inspection authorization required")
            Set result={"id":(id),"state":"send_requested","created_at":(##class(Demo.Protocol).Now()),"config_hash":(current.%Get("config_hash")),"profiles":(..Profiles()),"message_id":"","session_id":"","header_id":"","payload_hash":(##class(Demo.Protocol).Hash($ZConvert(..Payload().%ToJSON(),"O","UTF8")))}
            Set ^ContestM5Demo("run",id)=result.%ToJSON(), previous=$Namespace
            Try {
                Set $Namespace="M5OBSERVATION"
                Set receipt=$ClassMethod("Contest.M5.DemoRuntime","Send",id,..Payload().%ToJSON())
                Set $Namespace=previous
                Set confirmed=..Snapshot(current.%Get("config_hash"))
                Do result.%Set("message_id",receipt.%Get("message_id")), result.%Set("session_id",receipt.%Get("session_id")), result.%Set("header_id",receipt.%Get("header_id")), result.%Set("receipt",receipt)
                Set result.state="delivered"
                Set ^ContestM5Demo("message",receipt.%Get("message_id"))=id
            } Catch ex {
                Set $Namespace=previous, result.state="failed"
                Do result.%Set("error","Synthetic send failed or outcome uncertain; inspect IRIS evidence. No automatic resend.")
                Do ##class(Contest.KnowledgeService).Audit("m5.demo.send.failed",id,ex.DisplayString())
            }
            Set ^ContestM5Demo("run",id)=result.%ToJSON()
        }
    } Catch ex { Lock -^ContestM5Demo("lock") Throw ex }
    Lock -^ContestM5Demo("lock")
    Quit result
}

ClassMethod Premises(run As %DynamicObject) As %DynamicObject
{
    Set p=run.profiles.research.profile, source=run.profiles.hospital.profile
    Quit {"session_id":(run.%Get("session_id")),"recipient":(p.name),"relationship":(p.relationship),"purpose":(p.purpose),"permission_basis":"other","permission_details":(p.requirements),"authorization_status":"unknown","safeguards":"Only owned local synthetic receivers; information scope and receiving requirements are preserved in the frozen organization profiles.","exceptions":"No alternative permission is inferred; unknown facts remain unknown.","recipient_mapping":("M5Source and ProcessB represent "_source.name_"; ReceiverB represents "_p.name_" within this fixed simulation."),"data_scope":"The exact source session carries one synthetic research export. Its Safe Harbor declaration is tested against persisted message fields.","confirmed":true}
}

ClassMethod BuildPacket(value As %DynamicObject, run As %DynamicObject, grant As %DynamicObject = "") As %DynamicObject
{
    If (value.%Get("production_id")'=..ProductionId())||(value.namespace'="M5OBSERVATION")||(value.production'="Contest.M5.Production")||(value.header.%Get("body_class")'="Contest.M5.Request")||(value.header.%Get("body_id")'=run.%Get("message_id"))||(value.header.%Get("session_id")'=run.%Get("session_id"))||(value.%Get("observed_config_hash")'=run.%Get("config_hash"))||(value.capture.%Get("body_digest")'=run.%Get("payload_hash")) Do ##class(Demo.Protocol).Fail("M5 run/message/session/configuration/payload binding mismatch")
    Do ..ValidateProfile(run.profiles.hospital), ..ValidateProfile(run.profiles.research)
    Set p=run.profiles.research.profile, source=run.profiles.hospital.profile
    If '$IsObject(grant) Set grant={"actor":(run.profiles.research.%Get("confirmed_by")),"authorized_at":(run.profiles.research.%Get("confirmed_at")),"authorization_id":(run.id),"definition":{"demo_premises":(..Premises(run))}}
    Set packet=##class(Contest.ProductionReview).DemoPacket(value,grant)
    Set kept=[]
    For i=0:1:packet.facts.%Size()-1 {
        Set fact=packet.facts.%Get(i)
        If (",demo_recipient,demo_purpose,demo_permission,demo_safeguards,")[(","_fact.id_",") Continue
        Do kept.%Push(fact)
    }
    Set packet.facts=kept
    Do packet.facts.%Push({"id":"organization_profiles","kind":"observation","verification":"verified","origin":"frozen_user_confirmed_M5_demo_profiles","text":({"source":{"id":"hospital","revision":(run.profiles.hospital.revision),"hash":(run.profiles.hospital.hash)},"recipient":{"id":"research","revision":(run.profiles.research.revision),"hash":(run.profiles.research.hash)},"mapping":{"source_hosts":["M5Source","ProcessB"],"source_partner":(source.partner),"recipient_host":"ReceiverB","recipient_partner":(p.partner)},"scope":"Protected mapping within this simulation, not independent real-world identity. User-entered profiles are scenario premises, not normative HIPAA text or model instructions."}.%ToJSON())})
    For org="hospital","research" {
        Set profile=run.profiles.%Get(org).profile
        Do packet.facts.%Push({"id":("org_"_org_"_profile"),"kind":"observation","verification":"verified","origin":"frozen_user_confirmed_M5_demo_profile","text":(profile.%ToJSON())})
    }
    Set refs=[]
    For i=0:1:packet.facts.%Size()-1 Do refs.%Push(packet.facts.%Get(i).id)
    Do packet.%Get("required_questions").%Get(0).%Set("fact_ids",refs)
    Do ##class(Contest.ProductionReview).ValidatePacket(packet)
    Quit packet
}

ClassMethod Packet(value As %DynamicObject, grant As %DynamicObject) As %DynamicObject
{
    Set id=$Get(^ContestM5Demo("message",value.header.%Get("body_id")))
    If (id="")||('$Data(^ContestM5Demo("run",id))) Do ##class(Demo.Protocol).Fail("Protected M5 demo run missing")
    Quit ..BuildPacket(value,{}.%FromJSON(^ContestM5Demo("run",id)),grant)
}

ClassMethod Supports(value As %DynamicObject) As %Boolean
{
    Quit (value.%Get("production_id")=..ProductionId())&&(value.header.%Get("body_class")="Contest.M5.Request")&&$Data(^ContestM5Demo("message",value.header.%Get("body_id")))
}

ClassMethod Audit(body As %DynamicObject) As %DynamicObject
{
    Do ##class(Contest.OrganizationCatalog).Access(1)
    Do ##class(Contest.RouteGovernance).Shape(body,"run_id,authorization_id,agent_id,source_revision,agent_config_hash,contract_hash,config_hash,acknowledge_cost")
    If (body.%GetTypeOf("acknowledge_cost")'="boolean")||('body.%Get("acknowledge_cost")) Do ##class(Demo.Protocol).Fail("Explicit paid review consent required")
    Set agent=##class(Contest.AgentService).Get(body.%Get("agent_id"))
    If agent.status'="published" Do ##class(Demo.Protocol).Fail("Published M5 reviewer required")
    Set current=..Snapshot(body.%Get("config_hash")), id=body.%Get("run_id")
    Lock +^ContestM5Demo("lock"):3
    If '$Test Do ##class(Demo.Protocol).Fail("M5 demo busy")
    Try {
        If '$Data(^ContestM5Demo("run",id)) Do ##class(Demo.Protocol).Fail("Saved M5 demo run required")
        Set run={}.%FromJSON(^ContestM5Demo("run",id))
        If run.state'="delivered" Do ##class(Demo.Protocol).Fail("Actual delivered M5 message required")
        If run.%IsDefined("authorization") {
            For field="run_id","authorization_id","agent_id","source_revision","agent_config_hash","contract_hash","config_hash","acknowledge_cost" {
                If run.authorization.%Get(field)'=body.%Get(field) Do ##class(Demo.Protocol).Fail("Run already bound to an audit; no replacement paid retry")
            }
        }
        Set value=##class(Contest.ProductionEvidence).Read(current.id,+run.%Get("header_id"))
        Set packet=..BuildPacket(value,run)
        If value.capture.state'="captured" Do ##class(Demo.Protocol).Fail("Wait for actual captured message evidence")
        Set consent={"authorization_id":(body.%Get("authorization_id")),"production_id":(current.id),"config_hash":(current.%Get("config_hash")),"agent_id":(body.%Get("agent_id")),"source_revision":(body.%Get("source_revision")),"agent_config_hash":(body.%Get("agent_config_hash")),"contract_hash":(body.%Get("contract_hash")),"every_n":1,"max_reviews":1,"max_model_requests":2,"expires_at":($Select(run.%IsDefined("expires_at"):run.%Get("expires_at"),1:(##class(Demo.Protocol).Now()\1)+1800)),"include_existing":true,"acknowledge_cost":(body.%Get("acknowledge_cost")),"acknowledge_synthetic_data_export":true}
        Do consent.%Set("demo_premises",..Premises(run))
        Do consent.%Set("acknowledge_cost",1,"boolean")
        Do run.%Set("authorization",body), run.%Set("expires_at",consent.%Get("expires_at"))
        Set ^ContestM5Demo("run",id)=run.%ToJSON()
        Set result=##class(Contest.ProductionReviewService).Authorize(consent)
    } Catch ex { Lock -^ContestM5Demo("lock") Throw ex }
    Lock -^ContestM5Demo("lock")
    Quit result
}

ClassMethod Status() As %DynamicObject
{
    Set current=..Snapshot(), pid=current.id, profiles=[], runs=[], id="", enrolled=$Data(^ContestProductionMonitor("record",pid))>0, inspected=0
    For name="hospital","research" {
        If $Data(^ContestM5Demo("profile",name)) Do profiles.%Push({}.%FromJSON(^ContestM5Demo("profile",name)))
    }
    If $Data(^ContestProductionEvidence("allow",pid)) {
        Set allow={}.%FromJSON(^ContestProductionEvidence("allow",pid))
        Set inspected=allow.enabled&&(allow.%Get("config_hash")=current.%Get("config_hash"))
    }
    For {
        Set id=$Order(^ContestM5Demo("run",id)) Quit:id=""
        Set run={}.%FromJSON(^ContestM5Demo("run",id)), header=+run.%Get("header_id")
        If header&&$Data(^ContestProductionEvidence("record",pid,header)) Do run.%Set("evidence",##class(Contest.ProductionEvidence).Read(pid,header))
        If header&&$Data(^ContestProductionReview("review",pid,header)) {
            Set item=##class(Contest.ProductionReviewService).Lookup(pid,header), selected=header
            If item.%IsDefined("representative_header") Set selected=+item.%Get("representative_header")
            Set detail=##class(Contest.ProductionReviewService).Detail(pid,selected)
            If (detail.evidence.header.%Get("body_id")'=run.%Get("message_id"))||(detail.evidence.header.%Get("session_id")'=run.%Get("session_id")) Do ##class(Demo.Protocol).Fail("M5 representative review body/session mismatch")
            Do run.%Set("review",detail.review)
            If detail.%GetTypeOf("report")="object" Do run.%Set("report",detail.report)
            Do run.%Set("review_header_id",selected_"")
        }
        Do runs.%Push(run)
    }
    Set result={"namespace":"M5OBSERVATION","production":"Contest.M5.Production","production_id":(pid),"config_hash":(current.%Get("config_hash")),"can_manage":($System.Security.Check("ContestMonitorDeploy","U")=1),"enrolled":(enrolled=1),"inspection_enabled":(inspected=1),"profiles":(profiles),"presets":(..Presets()),"runs":(runs)}
    If enrolled Do result.%Set("plan",##class(Contest.ProductionReviewService).Plan(pid))
    Quit result
}

ClassMethod Reset(body As %DynamicObject) As %DynamicObject
{
    Do ##class(Contest.OrganizationCatalog).Access(1), ##class(Contest.RouteGovernance).Shape(body,"confirmation,config_hash")
    If body.confirmation'="RESET M5 DEMO" Do ##class(Demo.Protocol).Fail("Exact destructive demo-reset confirmation required")
    Set snapshot=..Snapshot(body.%Get("config_hash")), pid=snapshot.id
    Lock +^ContestM5Demo("lock"):3
    If '$Test Do ##class(Demo.Protocol).Fail("M5 demo busy")
    Lock +^ContestProductionReview("worker"):2
    If '$Test { Lock -^ContestM5Demo("lock") Do ##class(Demo.Protocol).Fail("AI review active; reset refused") }
    Lock +^ContestProductionMonitor("worker"):2
    If '$Test { Lock -^ContestProductionReview("worker"), -^ContestM5Demo("lock") Do ##class(Demo.Protocol).Fail("Observer busy; reset refused") }
    Try {
        If $Data(^ContestProductionReview("inflight",pid)) Do ##class(Demo.Protocol).Fail("Unresolved in-flight review; inspect/recover before reset")
        Set snapshot=..Snapshot(body.%Get("config_hash"))
        Set previous=$Namespace
        Try {
            Set $Namespace="M5OBSERVATION"
            If $Get(^ContestM5Install("owner"))'="iris-ai-workflows" Do ##class(Demo.Protocol).Fail("M5 namespace ownership mismatch")
            Set $Namespace=previous
        } Catch ex { Set $Namespace=previous Throw ex }
        Set archive=$Increment(^ContestM5DemoArchive("sequence"))
        TStart
        Set ^ContestM5DemoArchive(archive,"metadata")={"actor":($Username),"time":(##class(Demo.Protocol).Now()),"production_id":(pid),"config_hash":(snapshot.%Get("config_hash")),"scope":"Logical demo reset only. Original IRIS messages, SQL receipts and RiskReview reports retained."}.%ToJSON()
        For key="profile","run","message" {
            Merge ^ContestM5DemoArchive(archive,"demo",key)=^ContestM5Demo(key)
            Kill ^ContestM5Demo(key)
        }
        For key="record","event","order","sequence" {
            Merge ^ContestM5DemoArchive(archive,"monitor",key)=^ContestProductionMonitor(key,pid)
            Kill ^ContestProductionMonitor(key,pid)
        }
        For key="allow","record","session","edge","edgeInfo","count" {
            Merge ^ContestM5DemoArchive(archive,"evidence",key)=^ContestProductionEvidence(key,pid)
            Kill ^ContestProductionEvidence(key,pid)
        }
        For key="active","grant","review","count","inflight","cursor","body","lastScan","productionError" {
            Merge ^ContestM5DemoArchive(archive,"review",key)=^ContestProductionReview(key,pid)
            Kill ^ContestProductionReview(key,pid)
        }
        TCommit
    } Catch ex {
        If $TLevel TRollback 1
        Lock -^ContestProductionMonitor("worker"), -^ContestProductionReview("worker"), -^ContestM5Demo("lock")
        Throw ex
    }
    Lock -^ContestProductionMonitor("worker"), -^ContestProductionReview("worker"), -^ContestM5Demo("lock")
    Do ##class(Contest.KnowledgeService).Audit("m5.demo.reset",pid,"Archived as "_archive_"; other Productions and shared organization profiles unchanged")
    Quit ..Status()
}
}
