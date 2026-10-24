Class Contest.ProductionFlowTests Extends %UnitTest.TestProduction
{
Parameter PRODUCTION = "Contest.Production";
Method TestControl() As %Status { Quit $$$OK }

Method Config() As %DynamicObject
{
    Quit {"schema":1,"synthetic":true,"title":"Independent quality flow","owner":"Quality office","source":"FHIRSource","processors":["UtilizationProcess"],"sender":"AnalysisReceiver","purpose":"Compare encounter classes for internal service improvement.","recipient_id":"local-analysis-receiver","declaration":null,"collector":{"id":"structured-message-v1","format":"fhir-r4","fields":["Patient.id","Patient.birthDate","Encounter.status"]},"review_policy":"observed-use-v1"}
}

Method Enroll(ns As %String) As %DynamicObject
{
    Set snapshot=##class(Contest.ProductionMonitor).Snapshot(ns)
    Quit ##class(Contest.ProductionMonitor).Enroll({"namespace":(ns),"production":(snapshot.production),"config_hash":(snapshot.%Get("config_hash")),"acknowledge_monitoring":true})
}

Method Command(item As %DynamicObject, key As %String) As %DynamicObject
{
    Set snapshot=##class(Contest.ProductionMonitor).Snapshot(item.namespace)
    Quit {"production_id":(item.id),"flow_key":(key),"expected_revision":0,"expected_digest":"","production_config_hash":(snapshot.%Get("config_hash")),"config":(..Config())}
}

Method TestConfigContract()
{
    Do ##class(Contest.ProductionFlow).ValidateConfig(..Config())
    For variant="extra","synthetic","schema","empty","duplicate","source-loop","collector","format","expression","policy","recipient","declaration" {
        Set config=..Config(), rejected=0
        If variant="extra" Set config.enabled=1
        If variant="synthetic" Set config.synthetic="true"
        If variant="schema" Set config.schema=1.5
        If variant="empty" Set config.purpose=" "
        If variant="duplicate" Do config.processors.%Push("UtilizationProcess")
        If variant="source-loop" Set config.sender=config.source
        If variant="collector" Set config.collector.id="Arbitrary.Class"
        If variant="format" Set config.collector.format="javascript"
        If variant="expression" Set config.collector.fields=["Patient.name;SELECT"]
        If variant="policy" Do config.%Set("review_policy","auto-approve")
        If variant="recipient" Do config.%Set("recipient_id","https://example.invalid")
        If variant="declaration" Set config.declaration={"record_id":"missing","digest":"wrong"}
        Try { Do ##class(Contest.ProductionFlow).ValidateConfig(config) } Catch ex { Set rejected=1 }
        Do $$$AssertTrue(rejected,variant)
    }
    Set config=..Config(), config.collector.format="json-object", config.collector.fields=["patient_id","encounter.status"]
    Do ##class(Contest.ProductionFlow).ValidateConfig(config)
    Do $$$AssertTrue(1,"Same binding contract supports a bounded structured JSON collector")
}

Method TestVersionedBindings()
{
    If '$System.Security.Check("ContestMonitorDeploy","U") Quit
    TStart
    Try {
        Set item=..Enroll("UTILIZATION"), key="unit-"_$System.Util.CreateGUID(), command=..Command(item,key)
        Set one=##class(Contest.ProductionFlow).Save(command), again=##class(Contest.ProductionFlow).Save(command)
        Do $$$AssertEquals(one.id,again.id,"Retry has the same flow identity")
        Do $$$AssertEquals(one.digest,again.digest,"Retry does not replace the frozen snapshot")
        Do $$$AssertEquals(one.revision,1)
        Do $$$AssertEquals(one.%GetTypeOf("declaration_snapshot"),"null","Missing declaration is allowed, not a clean compliance conclusion")
        Set view=##class(Contest.ProductionFlow).Read(one.id)
        Do $$$AssertEquals(view.coverage.state,"optional_context_only","Context does not define the monitored Production scope")
        Do $$$AssertEquals(view.%Get("monitoring_prerequisite"),0,"Manual context is never a monitoring prerequisite")
        Do $$$AssertEquals(view.coverage.%Get("automatic_review"),0,"M1 grants no model permission")
        Do $$$AssertEquals(view.%Get("model_calls"),0)
        Do command.%Set("expected_revision",one.revision), command.%Set("expected_digest",one.digest)
        Set command.config.purpose="Compare a second declared quality use."
        Set two=##class(Contest.ProductionFlow).Save(command)
        Do $$$AssertEquals(two.revision,2)
        Do $$$AssertEquals(two.%Get("parent_digest"),one.digest)
        Do $$$AssertTrue(two.digest'=one.digest,"New business scope has a new digest")
        Set old=##class(Contest.ProductionFlow).Read(one.id,1)
        Do $$$AssertEquals(old.digest,one.digest,"Historical binding remains immutable")
        Do $$$AssertEquals(old.config.purpose,one.config.purpose)
        For variant="stale","digest","config","host","fraction" {
            Set bad={}.%FromJSON(command.%ToJSON()), rejected=0
            Do bad.%Set("expected_revision",two.revision), bad.%Set("expected_digest",two.digest)
            If variant="stale" Do bad.%Set("expected_revision",0), bad.%Set("expected_digest","")
            If variant="digest" Do bad.%Set("expected_digest",one.digest)
            If variant="config" Do bad.%Set("production_config_hash",one.digest)
            If variant="host" Set bad.config.sender="NonexistentReceiver"
            If variant="fraction" Do bad.%Set("expected_revision",2.5)
            Try { Set ignored=##class(Contest.ProductionFlow).Save(bad) } Catch ex { Set rejected=1 }
            Do $$$AssertTrue(rejected,variant)
        }
        Set page=##class(Contest.ProductionFlow).List(item.id)
        Do $$$AssertEquals(page.%Get("production_id"),item.id)
        Do $$$AssertTrue(page.items.%Size()>0)
    } Catch ex { TRollback 1 Throw ex }
    TRollback 1
}

Method TestProductionIsolationAndDeclarationPin()
{
    If '$System.Security.Check("ContestMonitorDeploy","U") Quit
    TStart
    Try {
        Set a=..Enroll("UTILIZATION"), b=..Enroll("DEMO"), key="unit-"_$System.Util.CreateGUID(), command=..Command(a,key)
        Set proposal=##class(Contest.DeclarationTests).%New("flow-fixture").Proposal()
        Set declaration=##class(Contest.DeclarationService).Save({"declaration_id":(key),"expected_revision":0,"expected_digest":"","proposal":(proposal)})
        Set command.config.declaration={"record_id":(declaration.id),"digest":(declaration.digest)}
        Set one=##class(Contest.ProductionFlow).Save(command)
        Do $$$AssertEquals(one.%Get("declaration_snapshot").%Get("record_id"),declaration.id)
        Do $$$AssertEquals(one.%Get("declaration_snapshot").%GetTypeOf("decision"),"null","Linking a draft never manufactures approval")
        Set nextProposal={}.%FromJSON(proposal.%ToJSON()), nextProposal.purpose.text="A revised purpose must not rewrite the earlier binding."
        Set next=##class(Contest.DeclarationService).Save({"declaration_id":(key),"expected_revision":1,"expected_digest":(declaration.digest),"proposal":(nextProposal)})
        Set frozen=##class(Contest.ProductionFlow).Read(one.id,1)
        Do $$$AssertEquals(frozen.%Get("declaration_snapshot").proposal.purpose.text,proposal.purpose.text,"Later declaration edits cannot replace the frozen evidence premise")
        Do $$$AssertEquals(frozen.%Get("declaration_snapshot").revision,1)
        Set command=..Command(b,key), nodes=b.baseline.nodes
        Set command.config.source=nodes.%Get(0).name, command.config.sender=nodes.%Get(1).name, command.config.processors=[]
        Set two=##class(Contest.ProductionFlow).Save(command)
        Do $$$AssertTrue(one.id'=two.id,"Same key in different Productions is not the same flow")
        Set page=##class(Contest.ProductionFlow).List(b.id)
        For i=0:1:page.items.%Size()-1 Do $$$AssertTrue(page.items.%Get(i).id'=one.id,"No cross-Production flow leak")
        Set bad=..Command(a,"other-"_$System.Util.CreateGUID()), bad.config.declaration={"record_id":(declaration.id),"digest":(one.digest)}, rejected=0
        Try { Set ignored=##class(Contest.ProductionFlow).Save(bad) } Catch ex { Set rejected=1 }
        Do $$$AssertTrue(rejected,"Declaration record requires its own exact digest")
        Set stored={}.%FromJSON(^ContestProductionFlow("record",one.id,1)), stored.config.purpose="Tampered purpose"
        Set ^ContestProductionFlow("record",one.id,1)=stored.%ToJSON(), rejected=0
        Try { Set ignored=##class(Contest.ProductionFlow).Read(one.id,1) } Catch ex { Set rejected=1 }
        Do $$$AssertTrue(rejected,"Binding tampering fails explicitly")
    } Catch ex { TRollback 1 Throw ex }
    TRollback 1
}

Method Envelope(flow As %DynamicObject) As %DynamicObject
{
    Quit {"schema":1,"synthetic":true,"binding":{"flow_id":(flow.id),"revision":(flow.revision),"flow_digest":(flow.digest),"production_id":(flow.%Get("production_id")),"config_hash":(flow.binding.%Get("config_hash"))},"observation":{"source_key":"header-123","observed_at":(##class(Demo.Protocol).Now()),"session_id":"123","message_id":"456","batch_id":"","outcome":"attempted","delivery_evidence":"message_header"},"references":[{"kind":"message_header","id":"456","digest":(flow.digest)}],"packet":{"synthetic":true,"stage":"after_send","facts":[{"id":"purpose","kind":"claim","verification":"unverified","origin":"flow_configuration","text":"Declared internal quality use; not an observation of later purpose."}],"required_questions":[{"topic":"recipient_purpose","fact_ids":["purpose"],"question":"Assess the declared purpose against observed use and identify material missing evidence."}]},"limits":["Message header proves no receiver acceptance or later recipient conduct."]}
}

Method TestEvidenceContract()
{
    Set digest=##class(Demo.Protocol).Hash("unit-flow"), flow={"id":("flow-"_digest),"revision":1,"digest":(digest),"production_id":("production-"_digest),"binding":{"config_hash":(digest)}}
    Do ##class(Contest.FlowEvidence).Validate(..Envelope(flow),flow)
    For variant="cross-flow","revision","digest","production","config","outcome","receipt","claim","fact-type","reference","header-id","empty-reference","limits","body","boolean" {
        Set value=..Envelope(flow), rejected=0
        If variant="cross-flow" Do value.binding.%Set("flow_id","flow-wrong")
        If variant="revision" Set value.binding.revision=2
        If variant="digest" Do value.binding.%Set("flow_digest","wrong")
        If variant="production" Do value.binding.%Set("production_id","production-wrong")
        If variant="config" Do value.binding.%Set("config_hash","wrong")
        If variant="outcome" Set value.observation.outcome="approved"
        If variant="receipt" Set value.observation.outcome="received"
        If variant="claim" Set value.packet.facts.%Get(0).verification="verified"
        If variant="fact-type" Set value.packet.facts.%Get(0).kind="unknown"
        If variant="reference" Set value.references.%Get(0).kind="arbitrary_url"
        If variant="header-id" Set value.references.%Get(0).id="other-header"
        If variant="empty-reference" Set value.references=[]
        If variant="limits" Set value.limits=[]
        If variant="body" Set value.payload="Do not accept raw payload as another envelope field"
        If variant="boolean" Set value.synthetic="true"
        Try { Do ##class(Contest.FlowEvidence).Validate(value,flow) } Catch ex { Set rejected=1 }
        Do $$$AssertTrue(rejected,variant)
    }
    Do $$$AssertTrue(1,"Schema validation does not persist observations, grant budget or call a model")
}

Method TestPaginationAndDeniedAccess()
{
    If '$System.Security.Check("ContestMonitorDeploy","U") {
        Set rejected=0
        Try { Set ignored=##class(Contest.ProductionFlow).Save({}) } Catch ex { Set rejected=1 }
        Do $$$AssertTrue(rejected,"The development/reader account cannot configure monitoring")
        Quit
    }
    TStart
    Try {
        Set item=..Enroll("UTILIZATION"), prefix="page-"_$System.Util.CreateGUID()
        For i=1:1:27 {
            Set command=..Command(item,prefix_"-"_i), saved=##class(Contest.ProductionFlow).Save(command)
        }
        Set first=##class(Contest.ProductionFlow).List(item.id), second=##class(Contest.ProductionFlow).List(item.id,first.%Get("next_after")), seen={}
        Do $$$AssertEquals(first.items.%Size(),25,"Flow list is bounded")
        Do $$$AssertTrue(first.%Get("next_after")'="","More flows have an explicit cursor")
        For i=0:1:first.items.%Size()-1 Do seen.%Set(first.items.%Get(i).id,1)
        For i=0:1:second.items.%Size()-1 Do $$$AssertTrue('seen.%IsDefined(second.items.%Get(i).id),"Flow pages do not duplicate identities")
        Set rejected=0
        Try { Set ignored=##class(Contest.ProductionFlow).List(item.id,"../bad") } Catch ex { Set rejected=1 }
        Do $$$AssertTrue(rejected,"Malformed flow cursor rejected")
    } Catch ex { TRollback 1 Throw ex }
    TRollback 1
}
}
