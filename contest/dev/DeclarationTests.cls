Class Contest.DeclarationTests Extends %UnitTest.TestProduction
{
Parameter PRODUCTION = "Contest.Production";
Method TestControl() As %Status { Quit $$$OK }

Method Proposal() As %DynamicObject
{
    Set now=##class(Demo.Protocol).Now()\1
    Quit {"schema":1,"synthetic":true,"title":"Hospital encounter quality study","owner":"Quality office","purpose":{"category":"quality_improvement","text":"Compare encounter classes by birth-year cohort to improve hospital services.","activities":"Calculate internal quality indicators.","expected_output":"Internal service improvement report."},"recipient_id":"local-analysis-receiver","data":{"resources":["Patient","Encounter"],"fields":["Patient.id","Patient.birthDate","Encounter.id","Encounter.status","Encounter.class.system","Encounter.class.code","Encounter.subject.reference"],"cohort":"synthetic-four-resources-v1","max_records":4,"necessity":"Birth year defines cohorts; encounter classes and references support the comparison."},"handling":{"recipe_id":"year-and-encounter-v1","identifiability":"linkable","access":"Internal quality team only.","retention":"30 days","onward_sharing":"None"},"arrangements":{"status":"not_specified","details":""},"validity":{"from":(now-10),"until":(now+86400)}}
}

Method Save(id As %String = "", revision As %Integer = 0, digest As %String = "", proposal = "") As %DynamicObject
{
    If id="" Set id="unit-"_$System.Util.CreateGUID()
    If '$IsObject(proposal) Set proposal=..Proposal()
    Quit ##class(Contest.DeclarationService).Save({"declaration_id":(id),"expected_revision":(revision),"expected_digest":(digest),"proposal":(proposal)})
}

Method Command(record As %DynamicObject) As %DynamicObject
{
    Quit {"record_id":(record.id),"digest":(record.digest)}
}

Method TestContractAndCatalog()
{
    Set catalog=##class(Contest.DeclarationCatalog).Get()
    Do $$$AssertEquals(catalog.recipients.%Size(),3)
    Do $$$AssertEquals(catalog.organization.%Get("organization_id"),"DEMO-HOSPITAL")
    Do ##class(Contest.DeclarationCatalog).Validate(..Proposal())
    Set proposal=..Proposal(), proposal.purpose.category="marketing", proposal.purpose.text="Provide identifiable patient details to an external marketing team."
    Do proposal.%Set("recipient_id","external-marketing-demo")
    Set proposal.data.fields=["Patient.id","Patient.name"], proposal.data.resources=["Patient"], proposal.handling.identifiability="identifiable"
    Do proposal.handling.%Set("recipe_id","retain-requested-fields")
    Do ##class(Contest.DeclarationCatalog).Validate(proposal)
    Set capability=##class(Contest.DeclarationCatalog).Capability(proposal)
    Do $$$AssertEquals(capability.state,"unsupported","Assessable is not executable")
    Do $$$AssertEquals(capability.%Get("model_calls"),0)
    For variant="unknown-field","resource","duplicate","empty","url","injection","boolean","fraction","validity","extra","category" {
        Set proposal=..Proposal(), rejected=0
        If variant="unknown-field" Do proposal.data.fields.%Push("Patient.secret")
        If variant="resource" Set proposal.data.resources=["Patient"]
        If variant="duplicate" Do proposal.data.fields.%Push("Patient.id")
        If variant="empty" Set proposal.purpose.text=" "
        If variant="url" Do proposal.%Set("recipient_id","https://example.invalid")
        If variant="injection" Set proposal.data.cohort="SELECT * FROM Patient"
        If variant="boolean" Set proposal.synthetic="true"
        If variant="fraction" Do proposal.data.%Set("max_records",2.5)
        If variant="validity" Set proposal.validity.until=proposal.validity.from
        If variant="extra" Set proposal.approved=1
        If variant="category" Set proposal.purpose.category="automatically-approved"
        Try { Do ##class(Contest.DeclarationCatalog).Validate(proposal) } Catch ex { Set rejected=1 }
        Do $$$AssertTrue(rejected,variant)
    }
}

Method TestRevisionsAndSubmission()
{
    If '$System.Security.Check("ContestMonitorDeploy","U") Quit
    TStart
    Try {
        Set one=..Save(), repeat=..Save(one.%Get("declaration_id"),0,"",one.proposal)
        Do $$$AssertEquals(one.id,repeat.id,"Lost-response retry is idempotent")
        Do $$$AssertEquals(one.state,"draft")
        Do $$$AssertEquals(one.review.%GetTypeOf("task"),"null")
        Set submitted=##class(Contest.DeclarationService).Submit(..Command(one))
        Do $$$AssertEquals(submitted.state,"submitted")
        Do $$$AssertEquals(submitted.review.task.state,"blocked_budget")
        Do $$$AssertEquals(submitted.review.task.%Get("reserved_requests"),0)
        Set again=##class(Contest.DeclarationService).Submit(..Command(one))
        Do $$$AssertEquals(again.review.task.id,submitted.review.task.id)
        Set proposal=..Proposal() Set proposal.purpose.text="Study a different proposed purpose."
        Set two=..Save(one.%Get("declaration_id"),1,one.digest,proposal)
        Do $$$AssertEquals(two.revision,2)
        Do $$$AssertEquals(two.review.%GetTypeOf("task"),"null","No inherited review")
        Do $$$AssertEquals(two.%GetTypeOf("decision"),"null","No inherited decision")
        Do $$$AssertEquals(two.%Get("parent_digest"),one.digest)
        For operation="stale-save","stale-submit","wrong-digest" {
            Set rejected=0
            Try {
                If operation="stale-save" Set ignored=..Save(one.%Get("declaration_id"),1,one.digest,..Proposal())
                If operation="stale-submit" Set ignored=##class(Contest.DeclarationService).Submit(..Command(one))
                If operation="wrong-digest" Set ignored=##class(Contest.DeclarationService).Submit({"record_id":(two.id),"digest":("a"_$Translate($Justify("",63)," ","a"))})
            } Catch ex { Set rejected=1 }
            Do $$$AssertTrue(rejected,operation)
        }
        Set submitted=##class(Contest.DeclarationService).Submit(..Command(two))
        Set old=##class(Contest.DeclarationService).Read(one.id)
        Do $$$AssertEquals(old.%Get("execution_state"),"superseded")
        Do $$$AssertEquals(old.review.task.id,again.review.task.id,"Historical review stays with old revision")
        Set detail=##class(Contest.DeclarationService).Read(two.id)
        Do $$$AssertEquals(detail.%Get("model_calls"),0)
        Do $$$AssertEquals(detail.%Get("execution_state"),"not_approved")
    } Catch ex { TRollback 1 Throw ex }
    TRollback 1
}

Method CompleteFixture(record As %DynamicObject, assessment As %String = "no_risk_identified") As %DynamicObject
{
    Set stored={}.%FromJSON(^ContestDeclaration("task",record.review.task.id))
    Set stored.state="completed", stored.assessment=assessment, stored.result={"fixture":true}
    Do stored.%Remove("record_hash")
    Do stored.%Set("record_hash",##class(Contest.ExportEvidence).Digest(stored))
    Set ^ContestDeclaration("task",stored.id)=stored.%ToJSON()
    Quit ##class(Contest.DeclarationService).Read(record.id)
}

Method Decision(record As %DynamicObject, action As %String = "approved") As %DynamicObject
{
    Quit ##class(Contest.DeclarationService).Decide({"record_id":(record.id),"digest":(record.digest),"task_id":(record.review.task.id),"task_hash":(record.review.task.%Get("record_hash")),"action":(action),"reason":"Synthetic framework decision fixture"})
}

Method TestDecisionsAreReviewBound()
{
    If '$System.Security.Check("ContestMonitorDeploy","U") Quit
    TStart
    Try {
        Set one=..Save(), submitted=##class(Contest.DeclarationService).Submit(..Command(one)), rejected=0
        Try { Set ignored=..Decision(submitted) } Catch ex { Set rejected=1 }
        Do $$$AssertTrue(rejected,"Blocked review cannot authorize approval")
        Set completed=..CompleteFixture(submitted), approved=..Decision(completed)
        Do $$$AssertEquals(approved.decision.action,"approved")
        Do $$$AssertEquals(approved.decision.%Get("task_hash"),completed.review.task.%Get("record_hash"))
        Do $$$AssertEquals(approved.%Get("execution_state"),"ready","Approval makes the bounded recipe eligible; no data is sent")
        Set repeat=..Decision(completed)
        Do $$$AssertEquals(repeat.decision.%ToJSON(),approved.decision.%ToJSON())
        Set rejected=0
        Try { Set ignored=..Decision(completed,"rejected") } Catch ex { Set rejected=1 }
        Do $$$AssertTrue(rejected,"Decision cannot be overwritten")
        Set proposal=..Proposal() Set proposal.purpose.text="Revised activities require another review."
        Set two=..Save(one.%Get("declaration_id"),1,one.digest,proposal)
        Set two=##class(Contest.DeclarationService).Submit(..Command(two)), rejected=0
        Try { Set ignored=..Decision(completed) } Catch ex { Set rejected=1 }
        Do $$$AssertTrue(rejected,"Even an idempotent old decision is stale after new submission")
        Do $$$AssertEquals(two.%GetTypeOf("decision"),"null")
        Set old=##class(Contest.DeclarationService).Read(one.id)
        Do $$$AssertEquals(old.%Get("execution_state"),"superseded")
        Set risky=..CompleteFixture(two,"risk_identified"), rejected=0
        Try { Set ignored=..Decision(risky) } Catch ex { Set rejected=1 }
        Do $$$AssertTrue(rejected,"No risk override in the first workflow")
        Set returned=..Decision(risky,"returned")
        Do $$$AssertEquals(returned.decision.action,"returned")
    } Catch ex { TRollback 1 Throw ex }
    TRollback 1
}

Method TestTamperingAndReadBoundaries()
{
    If '$System.Security.Check("ContestMonitorDeploy","U") Quit
    TStart
    Try {
        Set one=..Save(), submitted=##class(Contest.DeclarationService).Submit(..Command(one))
        Set taskid=submitted.review.task.id, saved=^ContestDeclaration("task",taskid), bad={}.%FromJSON(saved)
        Set bad.state="completed", bad.assessment="no_risk_identified"
        Set ^ContestDeclaration("task",taskid)=bad.%ToJSON(), rejected=0
        Try { Set ignored=##class(Contest.DeclarationService).Read(one.id) } Catch ex { Set rejected=1 }
        Do $$$AssertTrue(rejected,"Task integrity is checked, not just revision integrity")
        Set ^ContestDeclaration("task",taskid)=saved
        Set bad={}.%FromJSON(^ContestDeclaration("record",one.id)), bad.proposal.title="Tampered"
        Set ^ContestDeclaration("record",one.id)=bad.%ToJSON(), rejected=0
        Try { Set ignored=##class(Contest.DeclarationService).Read(one.id) } Catch ex { Set rejected=1 }
        Do $$$AssertTrue(rejected,"Stored proposal integrity checked")
        Set rejected=0
        Try { Set ignored=##class(Contest.DeclarationService).Read("../unknown") } Catch ex { Set rejected=1 }
        Do $$$AssertTrue(rejected,"Bounded identities")
    } Catch ex { TRollback 1 Throw ex }
    TRollback 1
}

Method TestCatalogPinsAndPagination()
{
    If '$System.Security.Check("ContestMonitorDeploy","U") Quit
    TStart
    Try {
        Set one=..Save(), id=one.%Get("declaration_id"), previous=one
        Do $$$AssertEquals(one.context.recipient.relationship,"same-covered-entity")
        Do $$$AssertEquals(one.context.%Get("catalog_hash"),##class(Contest.ExportEvidence).Digest(##class(Contest.DeclarationCatalog).Get()))
        For i=2:1:27 {
            Set proposal=..Proposal(), proposal.title="Draft "_i
            Set previous=..Save(id,previous.revision,previous.digest,proposal)
        }
        Set history=##class(Contest.DeclarationService).History(id)
        Do $$$AssertEquals(history.items.%Size(),25)
        Do $$$AssertTrue(history.%Get("has_older"))
        Do $$$AssertEquals(history.items.%Get(0).revision,27)
        Set older=##class(Contest.DeclarationService).History(id,history.%Get("older_before_revision"))
        Do $$$AssertEquals(older.items.%Size(),2)
        Do $$$AssertEquals(older.items.%Get(1).id,one.id)
        Do $$$AssertTrue('older.%Get("has_older"))
        Set value={}.%FromJSON(^ContestDeclaration("record",previous.id))
        Do value.context.%Set("catalog_hash",$Translate(value.context.%Get("catalog_hash"),"abcdef0123456789","bcdefa1234567890"))
        Do value.%Remove("record_hash")
        Do value.%Set("record_hash",##class(Contest.ExportEvidence).Digest(value))
        Set ^ContestDeclaration("record",previous.id)=value.%ToJSON(), rejected=0
        Try { Set ignored=##class(Contest.DeclarationService).Submit(..Command(previous)) } Catch ex { Set rejected=1 }
        Do $$$AssertTrue(rejected,"Changed catalog requires a new snapshot, not silent rebinding")
    } Catch ex { TRollback 1 Throw ex }
    TRollback 1
}

Method TestTaskAndDecisionValidation()
{
    If '$System.Security.Check("ContestMonitorDeploy","U") Quit
    TStart
    Try {
        Set one=..Save(), submitted=##class(Contest.DeclarationService).Submit(..Command(one))
        Set taskid=submitted.review.task.id, saved=^ContestDeclaration("task",taskid)
        For variant="other-record","other-revision","other-catalog","wrong-mode","nonterminal-assessment","attempts","unknown-state" {
            Set task={}.%FromJSON(saved), rejected=0
            If variant="other-record" Do task.%Set("record_id","declaration-another-record")
            If variant="other-revision" Set task.revision=2
            If variant="other-catalog" Do task.%Set("catalog_hash",$Translate(task.%Get("catalog_hash"),"abcdef0123456789","bcdefa1234567890"))
            If variant="wrong-mode" Set task.mode="after_send"
            If variant="nonterminal-assessment" Set task.assessment="no_risk_identified"
            If variant="attempts" Do task.%Set("attempted_requests",1)
            If variant="unknown-state" Set task.state="auto-approved"
            Do task.%Remove("record_hash")
            Do task.%Set("record_hash",##class(Contest.ExportEvidence).Digest(task))
            Set ^ContestDeclaration("task",taskid)=task.%ToJSON()
            Try { Set ignored=##class(Contest.DeclarationService).Read(one.id) } Catch ex { Set rejected=1 }
            Do $$$AssertTrue(rejected,variant)
        }
        Set ^ContestDeclaration("task",taskid)=saved, task={}.%FromJSON(saved), task.state="failed"
        Do task.%Remove("record_hash")
        Do task.%Set("record_hash",##class(Contest.ExportEvidence).Digest(task))
        Set ^ContestDeclaration("task",taskid)=task.%ToJSON(), failed=##class(Contest.DeclarationService).Read(one.id), rejected=0
        Try { Set ignored=..Decision(failed) } Catch ex { Set rejected=1 }
        Do $$$AssertTrue(rejected,"Technical failure is never no-risk")
        Set returned=..Decision(failed,"returned")
        Do $$$AssertEquals(returned.decision.action,"returned")
        Set another=..Save(), another=##class(Contest.DeclarationService).Submit(..Command(another))
        Set incomplete=..CompleteFixture(another,"information_required"), rejected=0
        Try { Set ignored=..Decision(incomplete) } Catch ex { Set rejected=1 }
        Do $$$AssertTrue(rejected,"Material unanswered questions cannot be approved")
        Set completed=..CompleteFixture(another), command={"record_id":(completed.id),"digest":(completed.digest),"task_id":(completed.review.task.id),"task_hash":($Translate(completed.review.task.%Get("record_hash"),"abcdef0123456789","bcdefa1234567890")),"action":"approved","reason":"Exact review hash required"}, rejected=0
        Try { Set ignored=##class(Contest.DeclarationService).Decide(command) } Catch ex { Set rejected=1 }
        Do $$$AssertTrue(rejected,"Approval cannot cite a different review snapshot")
    } Catch ex { TRollback 1 Throw ex }
    TRollback 1
}

Method TestDifferentUsesAreStoredAsProposals()
{
    If '$System.Security.Check("ContestMonitorDeploy","U") Quit
    TStart
    Try {
        For category="marketing","research","unspecified" {
            Set proposal=..Proposal(), proposal.purpose.category=category, proposal.purpose.text="Proposed "_category_" activity described by the applicant."
            Do proposal.%Set("recipient_id",$Select(category="unspecified":"unspecified-recipient",1:"external-marketing-demo"))
            Do proposal.handling.%Set("recipe_id","retain-requested-fields")
            Set proposal.data.fields=["Patient.id","Patient.name"], proposal.data.resources=["Patient"]
            Set record=..Save("",0,"",proposal), read=##class(Contest.DeclarationService).Read(record.id)
            Do $$$AssertEquals(read.proposal.purpose.category,category)
            Do $$$AssertEquals(read.proposal.purpose.text,proposal.purpose.text)
            Do $$$AssertEquals(read.context.recipient.relationship,$Select(category="unspecified":"unknown",1:"external"))
            Do $$$AssertEquals(read.capability.state,"unsupported")
            Do $$$AssertEquals(read.%GetTypeOf("decision"),"null","Catalog selection is not approval")
            Do $$$AssertEquals(read.review.%GetTypeOf("task"),"null","Saving is not inference")
        }
    } Catch ex { TRollback 1 Throw ex }
    TRollback 1
}

Method TestPermission()
{
    If $System.Security.Check("ContestMonitorDeploy","U") {
        Do $$$AssertTrue(1,"Authorized persistence tests execute in this session")
    } Else {
        Set rejected=0
        Try { Set ignored=..Save() } Catch ex { Set rejected=(ex.DisplayString()["Declaration write capability required") }
        Do $$$AssertTrue(rejected,"No write capability escalation")
    }
}
}
