Class Contest.DeclarationExecutionTests Extends Contest.DeclarationTests
{
Method Approved() As %DynamicObject
{
    Set record=..Save(), submitted=##class(Contest.DeclarationService).Submit(..Command(record))
    Quit ..Decision(..CompleteFixture(submitted))
}

Method TestExecutionRequiresExactApproval()
{
    If '$System.Security.Check("ContestMonitorDeploy","U") Quit
    TStart
    Try {
        Set record=..Save(), rejected=0
        Try { Set plan=##class(Contest.DeclarationExecution).Prepare(record.id,"unit-draft") } Catch ex { Set rejected=1 }
        Do $$$AssertTrue(rejected,"Unreviewed draft cannot plan delivery")
        Set approved=..Approved(), batch="unit-"_$System.Util.CreateGUID()
        Set plan=##class(Contest.DeclarationExecution).Prepare(approved.id,batch)
        Do $$$AssertEquals(plan.consent.%Get("acknowledge_delivery"),0)
        Do $$$AssertEquals(plan.%Get("model_calls"),0)
        Set rejected=0
        Try { Set run=##class(Contest.DeclarationExecution).Reserve(plan.consent) } Catch ex { Set rejected=1 }
        Do $$$AssertTrue(rejected,"A plan does not authorize delivery")
        Do plan.consent.%Set("acknowledge_delivery",1,"boolean")
        Set run=##class(Contest.DeclarationExecution).Reserve(plan.consent), again=##class(Contest.DeclarationExecution).Reserve(plan.consent)
        Do $$$AssertEquals(run.id,again.id,"Same exact batch reserves once without sending")
        Do $$$AssertEquals(run.state,"reserved")
        Do $$$AssertEquals(run.grant.record.id,approved.id)
        Do $$$AssertEquals(run.grant.record.decision.%Get("record_hash"),approved.decision.%Get("record_hash"))
        Set bad={}.%FromJSON(plan.consent.%ToJSON()), rejected=0
        Do bad.%Set("config_hash","wrong")
        Try { Set ignored=##class(Contest.DeclarationExecution).Reserve(bad) } Catch ex { Set rejected=1 }
        Do $$$AssertTrue(rejected,"Exact immutable delivery consent required")
        Set other=..Approved(), otherplan=##class(Contest.DeclarationExecution).Prepare(other.id,batch), rejected=0
        Do otherplan.consent.%Set("acknowledge_delivery",1,"boolean")
        Try { Set ignored=##class(Contest.DeclarationExecution).Reserve(otherplan.consent) } Catch ex { Set rejected=1 }
        Do $$$AssertTrue(rejected,"Batch identity cannot be reused for another declaration")
        Set next=..Save(approved.%Get("declaration_id"),approved.revision,approved.digest,..Proposal())
        Set next=##class(Contest.DeclarationService).Submit(..Command(next)), rejected=0
        Try { Set ignored=##class(Contest.DeclarationExecution).Prepare(approved.id,"unit-stale") } Catch ex { Set rejected=1 }
        Do $$$AssertTrue(rejected,"Replacement submission invalidates old execution")
        Set rejected=0
        Try { Set ignored=##class(Contest.DeclarationExecution).Admit(run.id,run.%Get("grant_hash"),run.grant.binding,batch) } Catch ex { Set rejected=1 }
        Do $$$AssertTrue(rejected,"Receiver must revalidate rather than trust the earlier grant")
    } Catch ex { TRollback 1 Throw ex }
    TRollback 1
}

Method TestExecutionScopeAndValidity()
{
    If '$System.Security.Check("ContestMonitorDeploy","U") Quit
    TStart
    Try {
        Set approved=..Approved(), binding=##class(Contest.DeclarationExecution).Binding()
        Do ##class(Contest.DeclarationExecution).Eligible(approved)
        For variant="unsupported","expired","future","catalog","risk","decision","latest","submission" {
            Set changed={}.%FromJSON(approved.%ToJSON()), rejected=0
            If variant="unsupported" Set changed.capability.state="unsupported"
            If variant="expired" Set changed.proposal.validity.until=1
            If variant="future" Set changed.proposal.validity.from=##class(Demo.Protocol).Now()+86400
            If variant="catalog" Do changed.context.%Set("catalog_hash","changed")
            If variant="risk" Set changed.review.task.assessment="risk_identified"
            If variant="decision" Set changed.decision.action="returned"
            If variant="latest" Do changed.%Set("latest_revision",2)
            If variant="submission" Do changed.%Set("is_current_submission",0,"boolean")
            Try { Do ##class(Contest.DeclarationExecution).Eligible(changed) } Catch ex { Set rejected=1 }
            Do $$$AssertTrue(rejected,variant)
        }
        Set plan=##class(Contest.DeclarationExecution).Prepare(approved.id,"unit-"_$System.Util.CreateGUID())
        Do plan.consent.%Set("acknowledge_delivery",1,"boolean")
        Set run=##class(Contest.DeclarationExecution).Reserve(plan.consent), rejected=0
        Try { Set dossier=##class(Contest.DeclarationExecution).Admit(run.id,run.%Get("grant_hash"),binding,run.grant.%Get("batch_id")) } Catch ex { Set rejected=1 }
        Do $$$AssertTrue(rejected,"Reservation alone cannot be consumed as an active runtime request")
        Set run.state="running", runraw=run.%ToJSON()
        Set ^ContestDeclarationExecution("run",run.id)=runraw
        Set dossier=##class(Contest.DeclarationExecution).Admit(run.id,run.%Get("grant_hash"),binding,run.grant.%Get("batch_id"))
        Do $$$AssertEquals(dossier.%Get("declaration_binding").%Get("record_id"),approved.id)
        Do $$$AssertEquals(dossier.core.declaration.scope.fields.%Size(),7)
        Do binding.%Set("config_hash","changed")
        Set rejected=0
        Try { Set ignored=##class(Contest.DeclarationExecution).Admit(run.id,run.%Get("grant_hash"),binding,run.grant.%Get("batch_id")) } Catch ex { Set rejected=1 }
        Do $$$AssertTrue(rejected,"Production configuration drift fails closed")
    } Catch ex { TRollback 1 Throw ex }
    TRollback 1
}

Method TestReceiverUsesDeclarationBucket()
{
    If '$System.Security.Check("ContestMonitorDeploy","U") Quit
    Set previous=$Namespace, key=""
    TStart
    Try {
        Set approved=..Approved(), batch="unit-"_$System.Util.CreateGUID(), plan=##class(Contest.DeclarationExecution).Prepare(approved.id,batch)
        Do plan.consent.%Set("acknowledge_delivery",1,"boolean")
        Set run=##class(Contest.DeclarationExecution).Reserve(plan.consent), run.state="running", ^ContestDeclarationExecution("run",run.id)=run.%ToJSON()
        Set dossier=##class(Contest.DeclarationExecution).Admit(run.id,run.%Get("grant_hash"),run.grant.binding,batch)
        Set $Namespace="UTILIZATION", full=##class(Contest.Aggregation.Mapping).Build(##class(Contest.Aggregation.Data).Fixture()), rows=[]
        For i=0:1:3 Do rows.%Push(full.entry.%Get(i).resource)
        Set bundle=##class(Contest.Utilization.Runtime).Project(rows), inspection=##class(Contest.Aggregation.Runtime).Inspect(bundle,dossier)
        Set request=##class(Contest.Aggregation.SendRequest).%New(), request.BatchId=batch, request.ApprovalId=run.id, request.ScopeHash=run.%Get("grant_hash"), request.Bundle=bundle.%ToJSON()
        Set config=##class(Contest.Utilization.Runtime).Config()
        Set record={"state":"prepared","batch_id":(batch),"source":(rows),"source_pins":[],"source_hash":(##class(Contest.Aggregation.Runtime).Digest(rows)),"bundle":(bundle),"output_hash":(##class(Contest.Aggregation.Runtime).Digest(bundle)),"config":(config),"config_hash":(run.grant.binding.%Get("config_hash")),"approval_id":(run.id),"scope_hash":(run.%Get("grant_hash")),"approval":(approved.decision),"declaration_binding":(dossier.%Get("declaration_binding")),"message_id":"fixture-only","session_id":0,"prepared_at":(##class(Demo.Protocol).Now())}
        Set ^ContestUtilization("declarationBatch",batch)=record.%ToJSON()
        Do $$$AssertEquals(##class(Contest.Utilization.Runtime).Bucket(run.id),"declarationBatch")
        Do $$$AssertEquals(##class(Contest.Utilization.Runtime).Bucket("route-legacy"),"batch")
        Set receiver=##class(Contest.Utilization.Receiver).%New("AnalysisReceiver"), sc=receiver.OnMessage(request,.reply)
        Do $$$AssertStatusOK(sc,"Compiled receiver reads the new bucket and revalidates the active grant")
        Do $$$AssertEquals(reply.Outcome,"delivered")
        Set read=##class(Contest.Utilization.Runtime).ReadReceiver(batch), stored={}.%FromJSON(^ContestUtilization("declarationBatch",batch))
        Do $$$AssertEquals(read.payload.%ToJSON(),bundle.%ToJSON())
        Do $$$AssertEquals(stored.receipt.%Get("declaration_binding").%Get("record_id"),approved.id)
        Do $$$AssertTrue('$Data(^ContestUtilization("batch",batch)),"No legacy batch written")
        Set $Namespace="TRIAGE"
    } Catch ex { TRollback 1 Set $Namespace=previous Throw ex }
    TRollback 1
    Set $Namespace=previous
}
}
