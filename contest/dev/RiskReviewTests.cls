Class Contest.RiskReviewTests Extends %UnitTest.TestProduction
{
Parameter PRODUCTION = "Contest.Production";
Method TestControl() As %Status { Quit $$$OK }

Method Packet() As %DynamicObject
{
    Quit {"synthetic":true,"stage":"before_send","facts":[{"id":"destination","kind":"observation","origin":"destination_check","verification":"verified","text":"The observed destination differs from the approved destination."},{"id":"approval","kind":"claim","origin":"operator","verification":"unverified","text":"Operator says the export was approved."}],"required_questions":[{"topic":"recipient_purpose","fact_ids":["destination"],"question":"Does the recorded recipient/purpose raise a scoped risk?"}]}
}

Method Plan() As %DynamicObject
{
    Quit {"questions":[{"topic":"recipient_purpose","fact_ids":["approval"],"question":"Is the claimed permission established?"}]}
}

Method Packages(questions As %DynamicArray) As %DynamicArray
{
    Set packages=[]
    For i=0:1:questions.%Size()-1 {
        Set hit={"id":("e"_i),"text":"A dated authority excerpt used only for development contract tests.","metadata":{"kind":"regulation_snapshot","retrieval_scope":"normative","source_locator":"45 CFR 164.502"}}
        Do ##class(Contest.BusinessReviewV2).Decorate(hit)
        Do packages.%Push({"question_id":(questions.%Get(i).id),"coverage":"unreviewed_partial","availability":"available","evidence":[(hit)],"retrievals":[]})
    }
    Quit packages
}

Method TestMandatoryQuestionCannotBeDropped()
{
    Set packet=..Packet(), plan=..Plan()
    Set questions=##class(Contest.RiskReview).Questions(packet,plan)
    Do $$$AssertEquals(questions.%Size(),1)
    Do $$$AssertEquals(questions.%Get(0).%Get("fact_ids").%Size(),2)
    Do $$$AssertEquals(questions.%Get(0).origin,"mandatory_and_model")
    Set empty=##class(Contest.RiskReview).Questions(packet,{"questions":[]})
    Do $$$AssertEquals(empty.%Size(),1)
    Do $$$AssertEquals(empty.%Get(0).origin,"mandatory")
    Do packet.%Get("required_questions").%Push({"topic":"deidentification","fact_ids":["destination"],"question":"Check the claimed release path."})
    Set questions=##class(Contest.RiskReview).Questions(packet,{"questions":[{"topic":"unclassified","fact_ids":["approval"],"question":"An unsupported issue needs human review."}]})
    Do $$$AssertEquals(questions.%Size(),3)
}

Method TestLocatorCannotSeeMandatoryTopicLabels()
{
    Set packet=..Packet(), input=##class(Contest.RiskReview).LocateInput(packet)
    Do $$$AssertEquals(input.%Size(),3)
    Do $$$AssertTrue('input.%IsDefined("required_questions"))
    Do $$$AssertEquals(input.facts.%ToJSON(),packet.facts.%ToJSON())
    Do $$$AssertEquals(input.stage,packet.stage)
}

Method TestPacketAndUnknownReferencesFail()
{
    Set packet=..Packet()
    Do ##class(Contest.RiskReview).ValidatePacket(packet)
    Set packet.facts.%Get(0).verification="assumed", rejected=0
    Try { Do ##class(Contest.RiskReview).ValidatePacket(packet) }
    Catch ex { Set rejected=1 }
    Do $$$AssertTrue(rejected)
    Set packet=..Packet(), plan=..Plan()
    Do plan.questions.%Get(0).%Set("fact_ids",["invented"])
    Set rejected=0
    Try { Set questions=##class(Contest.RiskReview).Questions(packet,plan) }
    Catch ex { Set rejected=1 }
    Do $$$AssertTrue(rejected)
}

Method TestRiskAndUnknownCoexistWithoutModelAggregate()
{
    Set packet=..Packet()
    Do packet.%Get("required_questions").%Push({"topic":"unclassified","fact_ids":["approval"],"question":"A separate unverified basis."})
    Set questions=##class(Contest.RiskReview).Questions(packet,..Plan()), packages=..Packages(questions)
    Set result={"issues":[{"question_id":"q1","status":"risk_signal","fact_ids":["destination"],"citations":[{"evidence_id":"e0","passage_id":"p0"}],"explanation":"Observed destination mismatch; not a definitive legal verdict."},{"question_id":"q2","status":"unresolved","fact_ids":["approval"],"citations":[],"explanation":"The separate claim needs verification."}],"missing_information":["Verify the separate approval."]}
    Set resolved=##class(Contest.RiskReview).Resolve(packet,questions,packages,result)
    Do $$$AssertTrue(resolved.summary.%Get("risk_detected"))
    Do $$$AssertTrue(resolved.summary.%Get("unresolved"))
    Do $$$AssertEquals(resolved.summary.%Get("recommended_action"),"hold_for_review")
    Do $$$AssertEquals(resolved.issues.%Get(0).citations.%Get(0).quote,packages.%Get(0).evidence.%Get(0).text)
    Set packet.stage="after_send"
    Set resolved=##class(Contest.RiskReview).Resolve(packet,questions,packages,result)
    Do $$$AssertEquals(resolved.summary.%Get("recommended_action"),"manual_review")
    Set result.assessment="no_finding", rejected=0
    Try { Set resolved=##class(Contest.RiskReview).Resolve(packet,questions,packages,result) }
    Catch ex { Set rejected=1 }
    Do $$$AssertTrue(rejected,"Model aggregate/action fields are not accepted")
}

Method TestIncompleteEvidenceNeverAuthorizesRelease()
{
    Set packet=..Packet(), questions=##class(Contest.RiskReview).Questions(packet,..Plan()), packages=..Packages(questions)
    Set answer={"issues":[{"question_id":"q1","status":"no_signal_on_checked_issue","fact_ids":["destination"],"citations":[{"evidence_id":"e0","passage_id":"p0"}],"explanation":"A limited development finding, not overall compliance."}],"missing_information":[]}
    Set resolved=##class(Contest.RiskReview).Resolve(packet,questions,packages,answer)
    Do $$$AssertTrue('resolved.summary.%Get("risk_detected"))
    Do $$$AssertTrue(resolved.summary.%Get("coverage_limited"))
    Do $$$AssertEquals(resolved.summary.%Get("recommended_action"),"manual_review")
    Do packages.%Get(0).%Set("evidence",[])
    Set packages.%Get(0).availability="unavailable", rejected=0
    Try { Set resolved=##class(Contest.RiskReview).Resolve(packet,questions,packages,answer) }
    Catch ex { Set rejected=1 }
    Do $$$AssertTrue(rejected,"No evidence cannot support no-signal")
    Set answer.issues.%Get(0).status="unresolved"
    Do answer.issues.%Get(0).%Set("citations",[]), answer.%Set("missing_information",["Required evidence."])
    Set resolved=##class(Contest.RiskReview).Resolve(packet,questions,packages,answer)
    Do $$$AssertTrue(resolved.summary.%Get("unresolved"))
}

Method TestConsentAndNoChatAgentConfiguration()
{
    Set packet=..Packet(), config={"id":"source","revision":3,"config_hash":"pinned"}
    Set body={"request_key":"unit-risk","agent_id":"source","source_revision":3,"config_hash":"pinned","input_hash":(##class(Demo.Protocol).Hash(packet.%ToJSON())),"contract_hash":(##class(Contest.RiskReview).ContractHash()),"acknowledge_cost":true,"max_model_requests":2}
    Do ##class(Contest.RiskReview).ValidateConsent(body,packet,config)
    Do body.%Set("max_model_requests",4)
    Set rejected=0
    Try { Do ##class(Contest.RiskReview).ValidateConsent(body,packet,config) }
    Catch ex { Set rejected=1 }
    Do $$$AssertTrue(rejected)
    Do body.%Set("max_model_requests",2)
    For field="input_hash","config_hash","contract_hash","source_revision","acknowledge_cost" {
        Set bad={}.%FromJSON(body.%ToJSON()), rejected=0
        If field="source_revision" {
            Do bad.%Set(field,4)
        } ElseIf field="acknowledge_cost" {
            Do bad.%Set(field,0,"boolean")
        } Else {
            Do bad.%Set(field,"changed")
        }
        Try { Do ##class(Contest.RiskReview).ValidateConsent(bad,packet,config) } Catch ex { Set rejected=1 }
        Do $$$AssertTrue(rejected,field)
    }
    For phase="locate","judge" {
        Set agent=##class(Contest.RiskReview).NewAgent("unit-no-chat",phase)
        Do $$$AssertEquals(agent.MaxIterations,1)
        Do $$$AssertEquals(agent.ToolSets,"")
        Do $$$AssertEquals(agent.ToolManager.%Discover().%Size(),0,"Actual SDK tool catalog must be empty")
        Do $$$AssertEquals(agent.SystemPrompt,##class(Contest.RiskReview).Prompt(phase))
    }
}

    Method TestPacketLimitsAndProvenance()
    {
        For variant="real","extra","large","claim","missing","empty" {
            Set packet=..Packet(), rejected=0
            If variant="real" Set packet.synthetic=0
            If variant="extra" Set packet.oracle="risk"
            If variant="large" Set packet.facts.%Get(0).text=$Justify("x",2001)
            If variant="claim" Set packet.facts.%Get(1).verification="verified"
            If variant="missing" Do packet.%Remove("required_questions")
            If variant="empty" Do packet.%Set("required_questions",[])
            Try { Do ##class(Contest.RiskReview).ValidatePacket(packet) } Catch ex { Set rejected=1 }
            Do $$$AssertTrue(rejected,variant)
        }
        Set packet=..Packet(), packet.facts.%Get(0).text=$Justify("x",2000)
        Do ##class(Contest.RiskReview).ValidatePacket(packet)
    }

    Method TestJudgeRejectsFabricatedAndCrossQuestionEvidence()
    {
        For variant="missing","order","quote","passage","evidence","non-normative","changed","unverified","unsupported","partial","extra","bounds" {
            Set packet=..Packet(), questions=##class(Contest.RiskReview).Questions(packet,..Plan()), packages=..Packages(questions)
            Set answer={"issues":[{"question_id":"q1","status":"risk_signal","fact_ids":["destination"],"citations":[{"evidence_id":"e0","passage_id":"p0"}],"explanation":"A scoped finding."}],"missing_information":[]}
            If variant="missing" Do answer.%Set("issues",[])
            If variant="order" Do answer.issues.%Get(0).%Set("question_id","q2")
            If variant="quote" Set answer.issues.%Get(0).citations.%Get(0).quote="Authored quote is forbidden"
            If variant="passage" Do answer.issues.%Get(0).citations.%Get(0).%Set("passage_id","p99")
            If variant="evidence" Do answer.issues.%Get(0).citations.%Get(0).%Set("evidence_id","other-question")
            If variant="non-normative" Set packages.%Get(0).evidence.%Get(0).metadata.kind="llm_brief"
            If variant="changed" Set packages.%Get(0).evidence.%Get(0).passages.%Get(0).text="Altered canonical text"
            If variant="unverified" Do answer.issues.%Get(0).%Set("fact_ids",["approval"])
            If variant="unsupported" Set questions.%Get(0).topic="unclassified"
            If variant="partial" Set packages.%Get(0).availability="partial"
            If variant="extra" Set answer.action="execute"
            If variant="bounds" Set answer.issues.%Get(0).explanation=$Justify("x",1001)
            Set rejected=0
            Try { Set resolved=##class(Contest.RiskReview).Resolve(packet,questions,packages,answer) } Catch ex { Set rejected=1 }
            Do $$$AssertTrue(rejected,variant)
        }
        Set packet=..Packet(), questions=##class(Contest.RiskReview).Questions(packet,..Plan()), packages=..Packages(questions)
        Set answer={"issues":[{"question_id":"q1","status":"unresolved","fact_ids":["approval"],"citations":[],"explanation":"No verified basis."}],"missing_information":[]}, rejected=0
        Try { Set resolved=##class(Contest.RiskReview).Resolve(packet,questions,packages,answer) } Catch ex { Set rejected=1 }
        Do $$$AssertTrue(rejected,"Unknown requires explicit missing information")
        Do packet.%Get("required_questions").%Push({"topic":"deidentification","fact_ids":["destination"],"question":"Check a separate release path."})
        Set questions=##class(Contest.RiskReview).Questions(packet,..Plan()), packages=..Packages(questions)
        Set answer={"issues":[{"question_id":"q1","status":"risk_signal","fact_ids":["destination"],"citations":[{"evidence_id":"e1","passage_id":"p0"}],"explanation":"Cross-question evidence is not supplied to q1."},{"question_id":"q2","status":"unresolved","fact_ids":["destination"],"citations":[],"explanation":"Separate unresolved path."}],"missing_information":["Verify the release path."]}, rejected=0
        Do $$$AssertEquals(packages.%Get(1).evidence.%Get(0).id,"e1")
        Try { Set resolved=##class(Contest.RiskReview).Resolve(packet,questions,packages,answer) } Catch ex { Set rejected=1 }
        Do $$$AssertTrue(rejected,"An existing source handle from a different question must be rejected")
    }

    Method TestQuestionBoundsAndNoLawSelection()
    {
        Set packet=..Packet()
        For variant="array","unsupported","duplicate","law","question-limit","refs","wrong-type" {
            Set plan=..Plan(), rejected=0
            If variant="array" Set plan.questions="not an array"
            If variant="unsupported" Set plan.questions.%Get(0).topic="breach_notification"
            If variant="duplicate" Do plan.questions.%Push(plan.questions.%Get(0))
            If variant="law" Set plan.questions.%Get(0).section="164.506"
            If variant="question-limit" Set plan.questions.%Get(0).question=$Justify("x",601)
            If variant="refs" Do plan.questions.%Get(0).%Set("fact_ids",[])
            If variant="wrong-type" Set plan.questions.%Get(0).topic=4
            Try { Set questions=##class(Contest.RiskReview).Questions(packet,plan) } Catch ex { Set rejected=1 }
            Do $$$AssertTrue(rejected,variant)
        }
    }

    Method TestEvidenceFailureAndContextIsolation()
    {
        TStart
        Try {
            Set packet=..Packet(), questions=##class(Contest.RiskReview).Questions(packet,..Plan())
            Set rejected=0
            Try { Set packages=##class(Contest.RiskReview).PrepareEvidence("unit-staged-outage",{"table":"NotAllowed.Table","index_version":"7"},questions) } Catch ex { Set rejected=1 }
            Do $$$AssertTrue(rejected,"Invalid index is a technical failure, not semantic uncertainty")
            Do $$$AssertTrue('$Data(^ContestBusinessContext($Job)))
            Set ^ContestBusinessContext($Job)="existing", rejected=0
            Try { Set packages=##class(Contest.RiskReview).PrepareEvidence("cannot-overwrite",{},questions) } Catch ex { Set rejected=1 }
            Do $$$AssertTrue(rejected)
            Do $$$AssertEquals(^ContestBusinessContext($Job),"existing")
            TRollback 1
        } Catch ex { TRollback 1 Throw ex }
    }

    Method TestFixturePipelineAndImmutableReplay()
    {
        If '$System.Security.Check("ContestMonitorDeploy","U") {
            Set rejected=0
            Try { Set ignored=##class(Contest.RiskReviewFixture).Run(..Packet(),{}) } Catch ex { Set rejected=1 }
            Do $$$AssertTrue(rejected,"Read-only MCP identity must be denied; run fixture pipeline with the existing authorized terminal identity")
            Quit
        }
        TStart
        Try {
            Set packet=..Packet(), id="unit-staged-"_$System.Util.CreateGUID()
            Set config={"id":(id),"revision":1,"status":"published","template":"privacy_review","model":"fixture-never-network","table":"Contest.HIPAAKnowledgeV1","index_version":"baseline-v1","max_iterations":4,"executor_version":"privacy-v1"}
            Do config.%Set("config_hash",##class(Contest.AgentService).ConfigHash(config))
            Set ^ContestAgents("config",id)=config.%ToJSON()
            Set body={"request_key":(id),"agent_id":(id),"source_revision":1,"config_hash":(config.%Get("config_hash")),"input_hash":(##class(Demo.Protocol).Hash(packet.%ToJSON())),"contract_hash":(##class(Contest.RiskReview).ContractHash()),"acknowledge_cost":true,"max_model_requests":2}
            Set report=##class(Contest.RiskReviewFixture).Run(packet,body)
            Do $$$AssertEquals(report.state,"completed")
            Do $$$AssertEquals(report.%Get("reserved_model_requests"),2)
            Do $$$AssertEquals(report.phases.%Size(),2)
            Do $$$AssertTrue(report.result.summary.%Get("unresolved"))
            Do $$$AssertTrue('report.result.summary.%Get("risk_detected"))
            Set replay=##class(Contest.RiskReviewFixture).Run(packet,body)
            Do $$$AssertEquals(replay.id,report.id)
            Do $$$AssertEquals(replay.phases.%Size(),2,"Same key never invokes another phase")
            Do $$$AssertEquals(##class(Contest.RiskReview).Status(report.id).state,"completed")
            Set packet.facts.%Get(0).text="Changed synthetic input"
            Do body.%Set("input_hash",##class(Demo.Protocol).Hash(packet.%ToJSON()))
            Set rejected=0
            Try { Set ignored=##class(Contest.RiskReviewFixture).Run(packet,body) } Catch ex { Set rejected=1 }
            Do $$$AssertTrue(rejected,"Same key cannot be reused with changed input")
            TRollback 1
        } Catch ex { TRollback 1 Throw ex }
    }

    Method TestFixtureFailureDoesNotCallSecondModel()
    {
        If '$System.Security.Check("ContestMonitorDeploy","U") {
            Set rejected=0
            Try { Set ignored=##class(Contest.RiskReviewFixture).Run(..Packet(),{}) } Catch ex { Set rejected=1 }
            Do $$$AssertTrue(rejected,"Evaluation write permission is not granted for tests")
            Quit
        }
        TStart
        Try {
            Set packet=..Packet(), id="unit-staged-"_$System.Util.CreateGUID()
            Set config={"id":(id),"revision":1,"status":"published","template":"privacy_review","model":"fixture-fail-locate","table":"Contest.HIPAAKnowledgeV1","index_version":"baseline-v1","max_iterations":4,"executor_version":"privacy-v1"}
            Do config.%Set("config_hash",##class(Contest.AgentService).ConfigHash(config))
            Set ^ContestAgents("config",id)=config.%ToJSON()
            Set body={"request_key":(id),"agent_id":(id),"source_revision":1,"config_hash":(config.%Get("config_hash")),"input_hash":(##class(Demo.Protocol).Hash(packet.%ToJSON())),"contract_hash":(##class(Contest.RiskReview).ContractHash()),"acknowledge_cost":true,"max_model_requests":2}
            Set report=##class(Contest.RiskReviewFixture).Run(packet,body)
            Do $$$AssertEquals(report.state,"failed")
            Do $$$AssertEquals(report.phases.%Size(),1)
            Do $$$AssertEquals(report.%Get("reserved_model_requests"),1)
            Do $$$AssertTrue('report.%IsDefined("result"),"Technical failure is not an unresolved semantic result")
            Set replay=##class(Contest.RiskReviewFixture).Run(packet,body)
            Do $$$AssertEquals(replay.phases.%Size(),1,"Failed attempts are never retried")
            Set report.state="running", ^ContestRiskReview("report",report.id)=report.%ToJSON()
            Set interrupted=##class(Contest.RiskReviewFixture).Run(packet,body)
            Do $$$AssertEquals(interrupted.state,"interrupted")
            Do $$$AssertEquals(interrupted.phases.%Size(),1)
            Set id="unit-staged-"_$System.Util.CreateGUID(), config.id=id, config.model="fixture-fail-evidence"
            Do config.%Set("config_hash",##class(Contest.AgentService).ConfigHash(config))
            Set ^ContestAgents("config",id)=config.%ToJSON()
            Do body.%Set("request_key",id), body.%Set("agent_id",id), body.%Set("config_hash",config.%Get("config_hash"))
            Set sourceFailure=##class(Contest.RiskReviewFixture).Run(packet,body)
            Do $$$AssertEquals(sourceFailure.state,"failed")
            Do $$$AssertEquals(sourceFailure.phases.%Size(),1,"Evidence-integrity failure must prevent judgment Chat")
            Do $$$AssertTrue('sourceFailure.%IsDefined("result"))
            TRollback 1
        } Catch ex { TRollback 1 Throw ex }
    }
}
