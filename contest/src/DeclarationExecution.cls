Class Contest.DeclarationExecution
{
ClassMethod Access(write As %Boolean = 0) [ Private ]
{
    If ($Namespace'="TRIAGE")||('$System.Security.Check($Select(write:"ContestMonitorDeploy",1:"ContestMonitorRead"),"U")) Do ##class(Demo.Protocol).Fail("Declaration execution permission required")
}

ClassMethod Batch(batch As %String)
{
    If '$Match(batch,"^[A-Za-z0-9-]{1,64}$") Do ##class(Demo.Protocol).Fail("Batch ID must contain 1-64 ASCII letters, digits or hyphens")
}

ClassMethod Binding() As %DynamicObject
{
    Set previous=$Namespace
    Try {
        Set $Namespace="UTILIZATION", binding=##class(Contest.Utilization.Runtime).Binding()
        Set sc=##class(Ens.Director).GetProductionStatus(.name,.state) $$$ThrowOnError(sc)
        If (name'="Contest.Utilization.Production")||(state'=1) Do ##class(Demo.Protocol).Fail("The utilization Production must already be running")
    } Catch ex { Set $Namespace=previous Throw ex }
    Set $Namespace=previous
    Quit binding
}

ClassMethod Eligible(record As %DynamicObject)
{
    Set now=##class(Demo.Protocol).Now(), task=record.review.task
    If (record.%GetTypeOf("decision")'="object")||('$IsObject(task)) Do ##class(Demo.Protocol).Fail("A reviewed and approved declaration is required")
    If (record.decision.action'="approved")||(task.state'="completed")||(task.assessment'="no_risk_identified") Do ##class(Demo.Protocol).Fail("Only a completed no-risk, human-approved declaration can run")
    If (record.revision'=record.%Get("latest_revision"))||('record.%Get("is_current_submission")) Do ##class(Demo.Protocol).Fail("Only the latest current submitted declaration can run")
    If (record.proposal.validity.from>now)||(record.proposal.validity.until<=now) Do ##class(Demo.Protocol).Fail("Declaration is outside its approved validity")
    Set catalog=##class(Contest.DeclarationCatalog).Get()
    If (record.context.%Get("catalog_hash")'=##class(Contest.ExportEvidence).Digest(catalog))||(record.context.%Get("catalog_version")'=catalog.version) Do ##class(Demo.Protocol).Fail("Catalog changed; revise and review before running")
    If (record.capability.state'="supported")||(##class(Contest.DeclarationCatalog).Capability(record.proposal).state'="supported") Do ##class(Demo.Protocol).Fail("This recipient or processing recipe has no supported execution")
}

ClassMethod Prepare(id As %String, batch As %String) As %DynamicObject
{
    Do ..Access(1), ..Batch(batch)
    Set record=##class(Contest.DeclarationService).Read(id)
    Do ..Eligible(record)
    Set binding=..Binding(), task=record.review.task
    Set consent={"record_id":(id),"digest":(record.digest),"decision_hash":(record.decision.%Get("record_hash")),"task_id":(task.id),"task_hash":(task.%Get("record_hash")),"config_hash":(binding.%Get("config_hash")),"batch_id":(batch),"acknowledge_delivery":false}
    Quit {"consent":(consent),"binding":(binding),"recipe_id":(record.proposal.handling.%Get("recipe_id")),"max_records":(record.proposal.data.%Get("max_records")),"recipient":(record.context.recipient.id),"model_calls":0}
}

ClassMethod Load(id As %String) As %DynamicObject
{
    Do ..Access()
    If ('$Match(id,"^declaration-run-[A-Za-z0-9-]{1,80}$"))||('$Data(^ContestDeclarationExecution("run",id))) Do ##class(Demo.Protocol).Fail("Declaration execution not found")
    Set run={}.%FromJSON(^ContestDeclarationExecution("run",id))
    If (run.id'=id)||(run.%Get("grant_hash")'=##class(Contest.ExportEvidence).Digest(run.grant)) Do ##class(Demo.Protocol).Fail("Immutable execution grant integrity mismatch")
    If $Get(^ContestDeclarationExecution("batch",run.grant.%Get("batch_id")))'=id Do ##class(Demo.Protocol).Fail("Execution batch index mismatch")
    Quit run
}

ClassMethod Reserve(body As %DynamicObject) As %DynamicObject
{
    Do ..Access(1), ##class(Contest.RouteGovernance).Shape(body,"record_id,digest,decision_hash,task_id,task_hash,config_hash,batch_id,acknowledge_delivery")
    If (body.%GetTypeOf("acknowledge_delivery")'="boolean")||('body.%Get("acknowledge_delivery")) Do ##class(Demo.Protocol).Fail("Explicit synthetic delivery confirmation required")
    Do ..Batch(body.%Get("batch_id"))
    Set record=##class(Contest.DeclarationService).Read(body.%Get("record_id")), key=record.%Get("declaration_id"), batch=body.%Get("batch_id")
    Lock +^ContestDeclarationExecution("batchLock",batch):2
    If '$Test Do ##class(Demo.Protocol).Fail("Execution batch is busy")
    Try {
        If $Data(^ContestDeclarationExecution("batch",batch)) {
            Set run=..Load(^ContestDeclarationExecution("batch",batch)), expected=run.grant.consent
        } Else {
            Lock +^ContestDeclaration("lock",key):2
            If '$Test Do ##class(Demo.Protocol).Fail("Declaration is busy")
            Try {
                Set plan=..Prepare(record.id,batch), record=##class(Contest.DeclarationService).Read(record.id), expected=plan.consent
                Do expected.%Set("acknowledge_delivery",1,"boolean")
                Do ..Consent(body,expected), ..Unused(batch)
                Set id="declaration-run-"_$System.Util.CreateGUID(), grant={"consent":(expected),"record":(record),"binding":(plan.binding),"batch_id":(batch),"created_by":($Username),"created_at":(##class(Demo.Protocol).Now())}
                Set run={"id":(id),"grant":(grant),"grant_hash":(##class(Contest.ExportEvidence).Digest(grant)),"state":"reserved","receipt":null,"error":"","model_calls":0,"monitoring_state":"pending_d5"}
                TStart
                Try {
                    Set ^ContestDeclarationExecution("run",id)=run.%ToJSON(), ^ContestDeclarationExecution("batch",batch)=id, ^ContestDeclarationExecution("record",record.id,id)=1
                    Do ##class(Contest.KnowledgeService).Audit("declaration.execution.reserved",id,record.id)
                    TCommit
                } Catch ex { TRollback 1 Throw ex }
            } Catch ex { Lock -^ContestDeclaration("lock",key) Throw ex }
            Lock -^ContestDeclaration("lock",key)
        }
        Do ..Consent(body,expected)
    } Catch ex { Lock -^ContestDeclarationExecution("batchLock",batch) Throw ex }
    Lock -^ContestDeclarationExecution("batchLock",batch)
    Quit run
}

ClassMethod Consent(body As %DynamicObject, expected As %DynamicObject) [ Private ]
{
    For field="record_id","digest","decision_hash","task_id","task_hash","config_hash","batch_id","acknowledge_delivery" {
        If (body.%GetTypeOf(field)'=expected.%GetTypeOf(field))||(body.%Get(field)'=expected.%Get(field)) Do ##class(Demo.Protocol).Fail("Exact execution consent mismatch: "_field)
    }
}

ClassMethod Unused(batch As %String) [ Private ]
{
    Set previous=$Namespace
    Try {
        Set $Namespace="UTILIZATION"
        If $Data(^ContestUtilization("batch",batch))||$Data(^ContestUtilization("declarationBatch",batch)) Do ##class(Demo.Protocol).Fail("Batch ID already belongs to a utilization task")
        Set rs=##class(%SQL.Statement).%ExecDirect(,"SELECT COUNT(*) AS N FROM SQLUser.UtilizationReceipt WHERE BatchID=?",batch)
        Do ##class(Contest.Aggregation.Data).Check(rs)
        Set next=rs.%Next()
        If rs.%Get("N") Do ##class(Demo.Protocol).Fail("Batch ID already has a downstream receipt")
    } Catch ex { Set $Namespace=previous Throw ex }
    Set $Namespace=previous
}

ClassMethod Admit(id As %String, digest As %String, binding As %DynamicObject, batch As %String) As %DynamicObject
{
    Do ..Access()
    Set run=..Load(id), record=##class(Contest.DeclarationService).Read(run.grant.record.id)
    Do ..Eligible(record)
    If (run.state'="running")||(run.%Get("grant_hash")'=digest)||(run.grant.%Get("batch_id")'=batch) Do ##class(Demo.Protocol).Fail("Only the exact active execution grant can be consumed")
    If (run.grant.binding.%ToJSON()'=binding.%ToJSON())||(record.digest'=run.grant.record.digest)||(record.decision.%Get("record_hash")'=run.grant.record.decision.%Get("record_hash"))||(record.review.task.%Get("record_hash")'=run.grant.record.review.task.%Get("record_hash")) Do ##class(Demo.Protocol).Fail("Execution approval, review or configuration changed")
    Set p=record.proposal, scope={"resources":(p.data.resources),"fields":(p.data.fields),"patient_selection":(p.data.cohort),"max_records":(p.data.%Get("max_records"))}
    Set link={"execution_id":(id),"execution_hash":(digest),"record_id":(record.id),"declaration_id":(record.%Get("declaration_id")),"revision":(record.revision),"declaration_digest":(record.digest),"decision_hash":(record.decision.%Get("record_hash")),"task_id":(record.review.task.id),"task_hash":(record.review.task.%Get("record_hash")),"recipe_id":(p.handling.%Get("recipe_id"))}
    Quit {"id":(id),"digest":(digest),"core":{"declaration":{"kind":"utilization","scope":(scope)},"binding":(binding),"valid_from":(p.validity.from),"valid_until":(p.validity.until)},"approval":(record.decision),"declaration_binding":(link)}
}

ClassMethod Start(body As %DynamicObject) As %DynamicObject
{
    Set run=..Reserve(body), id=run.id
    Lock +^ContestDeclarationExecution("dispatch",id):0
    If '$Test Quit ..Read(id)
    Try {
        Set run=..Load(id)
        If run.state="reserved" {
            Set run.state="running", ^ContestDeclarationExecution("run",id)=run.%ToJSON(), previous=$Namespace
            Try {
                Set $Namespace="UTILIZATION", request=##class(Contest.Aggregation.Request).%New()
                Set request.BatchId=run.grant.%Get("batch_id"), request.ApprovalId=id, request.ScopeHash=run.%Get("grant_hash")
                Set sc=##class(Ens.Director).CreateBusinessService("FHIRSource",.service) $$$ThrowOnError(sc)
                Set sc=service.ProcessInput(request,.reply) $$$ThrowOnError(sc)
                If reply.Outcome'="delivered" Do ##class(Demo.Protocol).Fail("Utilization did not confirm delivery")
            } Catch ex {
                Set $Namespace=previous, run.state="reconciliation_required", run.error="Execution did not return a verified reply. Inspect the batch and receiver; automatic replay is disabled."
                Set ^ContestDeclarationExecution("run",id)=run.%ToJSON()
                Do ##class(Contest.KnowledgeService).Audit("declaration.execution.failed",id,ex.DisplayString())
            }
            Set $Namespace=previous
        }
        Set result=..Read(id)
    } Catch ex { Lock -^ContestDeclarationExecution("dispatch",id) Throw ex }
    Lock -^ContestDeclarationExecution("dispatch",id)
    Quit result
}

ClassMethod Read(id As %String) As %DynamicObject
{
    Set run=..Load(id), previous=$Namespace, batch=run.grant.%Get("batch_id"), receipt=""
    Try {
        Set $Namespace="UTILIZATION"
        If $Data(^ContestUtilization("declarationBatch",batch)) {
            Set stored={}.%FromJSON(^ContestUtilization("declarationBatch",batch))
            If stored.state="delivered" {
                Set receipt=stored.receipt, downstream=##class(Contest.Utilization.Runtime).ReadReceiver(batch)
                Do ##class(Contest.Utilization.DeclarationBridge).Verify(run,stored)
                If (stored.%Get("approval_id")'=id)||(stored.%Get("scope_hash")'=run.%Get("grant_hash"))||(receipt.%Get("approval_id")'=id)||(receipt.%Get("scope_hash")'=run.%Get("grant_hash"))||(downstream.%Get("scope_hash")'=run.%Get("grant_hash"))||(downstream.%Get("output_hash")'=receipt.%Get("output_hash"))||(stored.bundle.%ToJSON()'=downstream.payload.%ToJSON()) Do ##class(Demo.Protocol).Fail("Execution receiver readback or batch binding changed")
            }
        }
    } Catch ex { Set $Namespace=previous Throw ex }
    Set $Namespace=previous
    If $IsObject(receipt) {
        Set copy={}.%FromJSON(receipt.%ToJSON()), pin=copy.%Get("receipt_hash")
        Do copy.%Remove("receipt_hash")
        If pin'=##class(Contest.ExportEvidence).Digest(copy) Do ##class(Demo.Protocol).Fail("Declaration receipt integrity mismatch")
        If receipt.%Get("declaration_binding").%Get("record_id")'=run.grant.record.id Do ##class(Demo.Protocol).Fail("Receipt belongs to another declaration")
        If (run.state="delivered")&&(run.receipt.%ToJSON()'=receipt.%ToJSON()) Do ##class(Demo.Protocol).Fail("Previously pinned receipt changed")
        If run.state'="delivered" {
            Set run.state="delivered", run.receipt=receipt, run.error="", ^ContestDeclarationExecution("run",id)=run.%ToJSON()
            Do ##class(Contest.KnowledgeService).Audit("declaration.execution.delivered",id,pin)
        }
    } ElseIf run.state="delivered" { Do ##class(Demo.Protocol).Fail("Previously delivered execution evidence is missing") }
    Do run.%Set("monitoring_state","automatic_observer")
    Quit run
}

ClassMethod List(recordId As %String, before As %String = "") As %DynamicObject
{
    Do ..Access()
    If (before'="")&&('$Match(before,"^declaration-run-[A-Za-z0-9-]{1,80}$")) Do ##class(Demo.Protocol).Fail("Bounded execution cursor required")
    Set record=##class(Contest.DeclarationService).Read(recordId), items=[], id=before, cursor=""
    For i=1:1:25 {
        Set id=$Order(^ContestDeclarationExecution("record",recordId,id),-1)
        If id="" Quit
        Do items.%Push(..Read(id))
        Set cursor=id
    }
    Set next=$Select(cursor'="":$Order(^ContestDeclarationExecution("record",recordId,cursor),-1),1:"")
    Quit {"record_id":(record.id),"items":(items),"next_cursor":($Select(next'="":cursor,1:"")),"model_calls":0}
}
}
