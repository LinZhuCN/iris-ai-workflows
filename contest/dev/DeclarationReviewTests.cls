Class Contest.DeclarationReviewTests Extends Contest.DeclarationTests
{
Method Packages(questions As %DynamicArray) As %DynamicArray
{
    Set packages=[]
    For i=0:1:questions.%Size()-1 {
        Set hit={"id":("e"_i),"text":"A synthetic normative excerpt for contract tests only.","metadata":{"kind":"regulation_snapshot","retrieval_scope":"normative"}}
        Do ##class(Contest.BusinessReviewV2).Decorate(hit)
        Do packages.%Push({"question_id":(questions.%Get(i).id),"availability":"available","evidence":[(hit)]})
    }
    Quit packages
}

Method TestProposedUseGrounding()
{
    Set record={"id":"declaration-unit","revision":1,"digest":"unit","proposal":(..Proposal()),"context":{"organization":{"organization_id":"DEMO-HOSPITAL","role":"simulated-covered-entity"},"recipient":{"id":"local-analysis-receiver","relationship":"same-covered-entity"}}}
    Do record.context.%Set("catalog_hash",##class(Contest.ExportEvidence).Digest(##class(Contest.DeclarationCatalog).Get()))
    Set packet=##class(Contest.DeclarationReview).Packet(record)
    Do $$$AssertEquals(record.proposal.data.necessity,"Birth year defines cohorts; encounter classes and references support the comparison.","Packet construction must not remove source fields")
    Do $$$AssertEquals(packet.stage,"config_review")
    Do $$$AssertEquals(packet.facts.%Size(),11)
    Do $$$AssertEquals(packet.facts.%Get(0).kind,"claim","Proposed purpose is not an observed delivery")
    Do $$$AssertTrue(packet.facts.%Get(9).text["Birth-year and encounter projection","Processing recipe is visible, not an opaque code")
    Set questions=##class(Contest.DeclarationReview).Questions(packet,{"questions":[]})
    Do $$$AssertEquals(questions.%Size(),1,"Required proposal review cannot be omitted")
    Set packages=..Packages(questions)
    For status="no_signal_on_checked_issue","risk_signal","unresolved" {
        Set answer={"issues":[{"question_id":"q1","status":(status),"fact_ids":["purpose_text"],"citations":[{"evidence_id":"e0","passage_id":"p0"}],"explanation":"Assessment of the proposed use as declared, not observed behavior."}],"missing_information":[]}
        If status="unresolved" Do answer.%Set("missing_information",["Specify the recipient relationship."])
        Set result=##class(Contest.DeclarationReview).Resolve(packet,questions,packages,answer)
        Do $$$AssertEquals(result.assessment,$Select(status="risk_signal":"risk_identified",status="unresolved":"information_required",1:"no_risk_identified"))
        Do $$$AssertEquals(result.issues.%Get(0).citations.%Get(0).quote,packages.%Get(0).evidence.%Get(0).text)
        Do $$$AssertTrue('result.%IsDefined("human_review_required"),"No blanket manual-review result marker")
    }
    Set answer.issues.%Get(0).status="risk_signal"
    Set result=##class(Contest.DeclarationReview).Resolve(packet,questions,packages,answer)
    Do $$$AssertEquals(result.assessment,"risk_identified","Risk may coexist with material unanswered questions")
    Do $$$AssertTrue(result.unresolved)
    For variant="citation","unavailable","observation","missing","extra","unsupported" {
        Set packet=##class(Contest.DeclarationReview).Packet(record), questions=##class(Contest.DeclarationReview).Questions(packet,{"questions":[]}), packages=..Packages(questions), rejected=0
        Set answer={"issues":[{"question_id":"q1","status":"no_signal_on_checked_issue","fact_ids":["purpose_text"],"citations":[{"evidence_id":"e0","passage_id":"p0"}],"explanation":"Proposed purpose is within the stated internal scenario."}],"missing_information":[]}
        If variant="citation" Do answer.issues.%Get(0).citations.%Get(0).%Set("passage_id","invented")
        If variant="unavailable" Set packages.%Get(0).availability="unavailable"
        If variant="observation" Set packet.facts.%Get(0).kind="observation", packet.facts.%Get(0).verification="verified"
        If variant="missing" Set answer.issues.%Get(0).status="unresolved"
        If variant="extra" Set answer.approved=1
        If variant="unsupported" Set questions.%Get(0).topic="unclassified"
        Try { Set ignored=##class(Contest.DeclarationReview).Resolve(packet,questions,packages,answer) } Catch ex { Set rejected=1 }
        Do $$$AssertTrue(rejected,variant)
    }
}

Method TestDeclarationReviewBudget()
{
    If '$System.Security.Check("ContestMonitorDeploy","U") Quit
    TStart
    Try {
        Set record=..Save(), submitted=##class(Contest.DeclarationService).Submit(..Command(record))
        Set prepared=##class(Contest.DeclarationQueue).Prepare(record.id)
        Do $$$AssertEquals(prepared.consent.%Get("max_model_requests"),2)
        Do $$$AssertEquals(prepared.consent.%Get("acknowledge_cost"),0)
        Set rejected=0
        Try { Set ignored=##class(Contest.DeclarationQueue).Reserve(prepared.consent) } Catch ex { Set rejected=1 }
        Do $$$AssertTrue(rejected,"Preparation does not authorize provider requests")
        Do prepared.consent.%Set("acknowledge_cost",1,"boolean")
        Set queued=##class(Contest.DeclarationQueue).Reserve(prepared.consent)
        Do $$$AssertEquals(queued.review.task.state,"queued")
        Do $$$AssertEquals(queued.review.task.%Get("reserved_requests"),2)
        Do $$$AssertEquals(queued.review.task.%Get("attempted_requests"),0)
        Set repeat=##class(Contest.DeclarationQueue).Reserve(prepared.consent)
        Do $$$AssertEquals(repeat.review.task.%Get("record_hash"),queued.review.task.%Get("record_hash"),"Reserve once; no duplicate calls")
        Set bad={}.%FromJSON(prepared.consent.%ToJSON()), rejected=0
        Do bad.%Set("input_hash","changed")
        Try { Set ignored=##class(Contest.DeclarationQueue).Reserve(bad) } Catch ex { Set rejected=1 }
        Do $$$AssertTrue(rejected,"Immutable input grant")
        Set newer=..Save(record.%Get("declaration_id"),1,record.digest,..Proposal()), rejected=0
        Try { Set ignored=##class(Contest.DeclarationQueue).Prepare(record.id) } Catch ex { Set rejected=1 }
        Do $$$AssertTrue(rejected,"Cannot fund an old revision")
    } Catch ex { TRollback 1 Throw ex }
    TRollback 1
}

Method TestJudgeOutputContract()
{
    Set prompt=##class(Contest.DeclarationReview).Prompt("judge")
    Do $$$AssertTrue(prompt["Example output shape:","Concrete output shape reduces unsupported placeholder fields")
    Do $$$AssertTrue(prompt["Never add issue-level citation or passage_id, even as empty strings.","Citation handles belong only inside citations")
    Set record={"id":"declaration-output-unit","revision":1,"digest":"unit","proposal":(..Proposal()),"context":{"catalog_hash":(##class(Contest.ExportEvidence).Digest(##class(Contest.DeclarationCatalog).Get()))}}
    Set packet=##class(Contest.DeclarationReview).Packet(record), questions=##class(Contest.DeclarationReview).Questions(packet,{"questions":[]}), packages=..Packages(questions)
    Set answer={"issues":[{"question_id":"q1","status":"no_signal_on_checked_issue","fact_ids":["purpose_text"],"citations":[{"evidence_id":"e0","passage_id":"p0"}],"explanation":"Synthetic output-contract fixture.","citation":"","passage_id":""}],"missing_information":[]}, rejected=0
    Try { Set ignored=##class(Contest.DeclarationReview).Resolve(packet,questions,packages,answer) } Catch ex { Set rejected=1 }
    Do $$$AssertTrue(rejected,"Preserved real failure shape must not be silently accepted")
    Do answer.issues.%Get(0).%Remove("citation"), answer.issues.%Get(0).%Remove("passage_id")
    Set result=##class(Contest.DeclarationReview).Resolve(packet,questions,packages,answer)
    Do $$$AssertEquals(result.assessment,"no_risk_identified","Exact fixture shape remains valid; no application task is rewritten")
}

Method TestQueuedExecutionAndFailureNeverRetry()
{
    If '$System.Security.Check("ContestMonitorDeploy","U") Quit
    TStart
    Try {
        For outcome="completed","failed" {
            Set record=..Save(), submitted=##class(Contest.DeclarationService).Submit(..Command(record)), prepared=##class(Contest.DeclarationQueue).Prepare(record.id)
            Do prepared.consent.%Set("acknowledge_cost",1,"boolean")
            Set queued=##class(Contest.DeclarationQueue).Reserve(prepared.consent), task=queued.review.task
            Set packet=##class(Contest.DeclarationReview).Packet(queued), questions=##class(Contest.DeclarationReview).Questions(packet,{"questions":[]}), packages=..Packages(questions)
            Set answer={"issues":[{"question_id":"q1","status":"no_signal_on_checked_issue","fact_ids":["purpose_text"],"citations":[{"evidence_id":"e0","passage_id":"p0"}],"explanation":"Synthetic prospective-use framework fixture."}],"missing_information":[]}
            Set result=##class(Contest.DeclarationReview).Resolve(packet,questions,packages,answer), consent=prepared.consent, source=prepared.source
            Set authorization={"request_key":("declaration-"_task.id),"agent_id":(source.id),"source_revision":(source.revision),"config_hash":(source.%Get("config_hash")),"input_hash":(consent.%Get("input_hash")),"contract_hash":(consent.%Get("contract_hash")),"max_model_requests":2,"acknowledge_cost":true}
            Set reportid="risk-evaluation-"_$System.Util.CreateGUID()
            Set report={"id":(reportid),"state":(outcome),"authorization":(authorization),"reserved_model_requests":($Select(outcome="completed":2,1:1)),"result":(result),"fixture":true}
            Set ^ContestRiskReview("request","declaration-"_task.id)=reportid, ^ContestRiskReview("report",reportid)=report.%ToJSON()
            Set request=##class(Contest.DeclarationReviewRequest).%New(), request.RecordId=record.id, request.TaskId=task.id, request.DeclarationDigest=record.digest, request.AuthorizationHash="wrong", rejected=0
            Try { Set ignored=##class(Contest.DeclarationQueue).Execute(request,"fixture-session") } Catch ex { Set rejected=1 }
            Do $$$AssertTrue(rejected,"Invalid message authorization cannot call the Agent")
            Set request.AuthorizationHash=##class(Contest.ExportEvidence).Digest(consent)
            Set terminal=##class(Contest.DeclarationQueue).Execute(request,"fixture-session")
            Do $$$AssertEquals(terminal.state,outcome)
            Do $$$AssertEquals(terminal.%Get("attempted_requests"),$Select(outcome="completed":2,1:1))
            If outcome="completed" {
                Do $$$AssertEquals(terminal.assessment,"no_risk_identified")
            } Else {
                Do $$$AssertEquals(terminal.%GetTypeOf("assessment"),"null")
                Do $$$AssertEquals(terminal.%GetTypeOf("result"),"null","Technical failure has no success-shaped fallback")
            }
            Set repeated=##class(Contest.DeclarationQueue).Execute(request,"fixture-session")
            Do $$$AssertEquals(repeated.%Get("record_hash"),terminal.%Get("record_hash"),"Duplicate message never retries a terminal task")
        }
    } Catch ex { TRollback 1 Throw ex }
    TRollback 1
}

Method TestRecoveryDoesNotReplay()
{
    If '$System.Security.Check("ContestMonitorDeploy","U") Quit
    TStart
    Try {
        Set record=..Save(), submitted=##class(Contest.DeclarationService).Submit(..Command(record)), prepared=##class(Contest.DeclarationQueue).Prepare(record.id)
        Do prepared.consent.%Set("acknowledge_cost",1,"boolean")
        Set queued=##class(Contest.DeclarationQueue).Reserve(prepared.consent), task=queued.review.task
        Set recovered=##class(Contest.DeclarationQueue).Recover({"record_id":(record.id),"task_id":(task.id),"task_hash":(task.%Get("record_hash"))})
        Do $$$AssertEquals(recovered.review.task.state,"failed")
        Do $$$AssertEquals(recovered.review.task.%Get("attempted_requests"),0)
        Do $$$AssertEquals(recovered.review.task.%Get("reserved_requests"),2,"Recovery does not replenish an allowance")
        Do $$$AssertEquals(recovered.review.task.%GetTypeOf("assessment"),"null")
        Set same=##class(Contest.DeclarationQueue).Reserve(prepared.consent)
        Do $$$AssertEquals(same.review.task.state,"failed","Repeating the original authorization cannot retry")
    } Catch ex { TRollback 1 Throw ex }
    TRollback 1
}

Method TestActualAgentHasNoToolsOrHiddenIterations()
{
    For phase="locate","judge" {
        Set agent=##class(Contest.DeclarationReview).NewAgent("unit-no-chat",phase)
        Do $$$AssertEquals(agent.MaxIterations,1)
        Do $$$AssertEquals(agent.ToolSets,"")
        Do $$$AssertEquals(agent.ToolManager.%Discover().%Size(),0)
        Do $$$AssertEquals(agent.SystemPrompt,##class(Contest.DeclarationReview).Prompt(phase))
    }
    Do $$$AssertEquals(##class(Contest.DeclarationReview).InputLimit(),160000)
}
}
