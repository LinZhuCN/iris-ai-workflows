Class Contest.DeclarationService
{
ClassMethod Access(write As %Boolean = 0) [ Private ]
{
    If $Namespace'="TRIAGE" Do ##class(Demo.Protocol).Fail("TRIAGE declarations required")
    If '$System.Security.Check($Select(write:"ContestMonitorDeploy",1:"ContestMonitorRead"),"U") Do ##class(Demo.Protocol).Fail($Select(write:"Declaration write capability required",1:"Declaration read capability required"))
}

ClassMethod Identity(id As %String) [ Private ]
{
    If '$Match(id,"^[A-Za-z][A-Za-z0-9_.-]{0,127}$") Do ##class(Demo.Protocol).Fail("Bounded declaration identity required")
}

ClassMethod Hash(value, field As %String) [ Private ]
{
    If (value.%GetTypeOf(field)'="string")||('$Match(value.%Get(field),"^[a-f0-9]{64}$")) Do ##class(Demo.Protocol).Fail("Exact declaration digest required: "_field)
}

ClassMethod Seal(value As %DynamicObject) [ Private ]
{
    Do value.%Set("record_hash",##class(Contest.ExportEvidence).Digest(value))
}

ClassMethod Verify(value As %DynamicObject) [ Private ]
{
    Do ..Hash(value,"record_hash")
    Set copy={}.%FromJSON(value.%ToJSON()), digest=copy.%Get("record_hash")
    Do copy.%Remove("record_hash")
    If digest'=##class(Contest.ExportEvidence).Digest(copy) Do ##class(Demo.Protocol).Fail("Declaration record integrity mismatch")
}

ClassMethod Load(id As %String) As %DynamicObject [ Private ]
{
    If '$Match(id,"^declaration-[A-Za-z0-9-]{1,80}$") Do ##class(Demo.Protocol).Fail("Bounded declaration record identity required")
    If '$Data(^ContestDeclaration("record",id)) Do ##class(Demo.Protocol).Fail("Declaration record not found")
    Set value={}.%FromJSON(^ContestDeclaration("record",id))
    Do ##class(Contest.RouteGovernance).Shape(value,"id,declaration_id,revision,parent_digest,proposal,digest,context,created_by,created_at,record_hash")
    Do ..Verify(value), ##class(Contest.DeclarationCatalog).Validate(value.proposal)
    Do ..Identity(value.%Get("declaration_id")), ..Hash(value,"digest")
    If (value.%GetTypeOf("revision")'="number")||(value.revision<1)||(value.revision>100000)||((value.revision\1)'=value.revision) Do ##class(Demo.Protocol).Fail("Stored declaration revision invalid")
    Do ##class(Contest.RouteGovernance).Shape(value.context,"catalog_version,catalog_hash,organization,recipient")
    Do ..Hash(value.context,"catalog_hash")
    If value.context.recipient.id'=value.proposal.%Get("recipient_id") Do ##class(Demo.Protocol).Fail("Registered recipient snapshot differs from proposal selection")
    If (value.id'=id)||(value.digest'=##class(Contest.ExportEvidence).Digest(value.proposal)) Do ##class(Demo.Protocol).Fail("Declaration identity or proposal digest mismatch")
    If $Get(^ContestDeclaration("revision",value.%Get("declaration_id"),value.revision))'=id Do ##class(Demo.Protocol).Fail("Declaration revision index mismatch")
    Quit value
}

ClassMethod Save(body As %DynamicObject) As %DynamicObject
{
    Do ..Access(1)
    Try {
        Do ##class(Contest.RouteGovernance).Shape(body,"declaration_id,expected_revision,expected_digest,proposal")
        Do ..Identity(body.%Get("declaration_id")), ##class(Contest.DeclarationCatalog).Validate(body.proposal)
        If (body.%GetTypeOf("expected_revision")'="number")||(body.%Get("expected_revision")<0)||(body.%Get("expected_revision")>=100000)||((body.%Get("expected_revision")\1)'=body.%Get("expected_revision")) Do ##class(Demo.Protocol).Fail("Bounded expected declaration revision required")
        If body.%Get("expected_revision")=0 {
            If (body.%GetTypeOf("expected_digest")'="string")||(body.%Get("expected_digest")'="") Do ##class(Demo.Protocol).Fail("First declaration revision requires empty parent digest")
        } Else { Do ..Hash(body,"expected_digest") }
        Set key=body.%Get("declaration_id"), parent=body.%Get("expected_revision"), digest=##class(Contest.ExportEvidence).Digest(body.proposal)
        Lock +^ContestDeclaration("lock",key):2
        If '$Test Do ##class(Demo.Protocol).Fail("Declaration busy")
        Try {
            Set latest=+$Get(^ContestDeclaration("latest",key)), revision=parent+1, existing=$Get(^ContestDeclaration("revision",key,revision))
            If existing'="" {
                Set stored=..Load(existing)
                If (latest'=revision)||(stored.digest'=digest)||(stored.%Get("parent_digest")'=body.%Get("expected_digest")) Do ##class(Demo.Protocol).Fail("Stale or conflicting declaration revision")
            } Else {
                If latest'=parent Do ##class(Demo.Protocol).Fail("Stale expected declaration revision")
                If parent>0 {
                    Set previous=..Load(^ContestDeclaration("revision",key,parent))
                    If previous.digest'=body.%Get("expected_digest") Do ##class(Demo.Protocol).Fail("Expected parent digest differs")
                }
                Set id="declaration-"_$System.Util.CreateGUID(), catalog=##class(Contest.DeclarationCatalog).Get()
                Set context={"catalog_version":(catalog.version),"catalog_hash":(##class(Contest.ExportEvidence).Digest(catalog)),"organization":(catalog.organization),"recipient":(##class(Contest.DeclarationCatalog).Recipient(body.proposal.%Get("recipient_id")))}
                Set stored={"id":(id),"declaration_id":(key),"revision":(revision),"parent_digest":(body.%Get("expected_digest")),"proposal":(body.proposal),"digest":(digest),"context":(context),"created_by":($Username),"created_at":(##class(Demo.Protocol).Now())}
                Do ..Seal(stored)
                TStart
                Try {
                    Set ^ContestDeclaration("record",id)=stored.%ToJSON(), ^ContestDeclaration("revision",key,revision)=id, ^ContestDeclaration("latest",key)=revision
                    Do ##class(Contest.KnowledgeService).Audit("declaration.saved",id,digest)
                    TCommit
                } Catch ex { TRollback 1 Throw ex }
            }
        } Catch ex { Lock -^ContestDeclaration("lock",key) Throw ex }
        Lock -^ContestDeclaration("lock",key)
    } Catch ex {
        Do ##class(Contest.KnowledgeService).Audit("declaration.save.rejected","",ex.DisplayString())
        Throw ex
    }
    Quit ..Read(stored.id)
}

ClassMethod Task(record As %DynamicObject) [ Private ]
{
    Set id=$Get(^ContestDeclaration("review",record.id))
    If id="" Quit ""
    If '$Data(^ContestDeclaration("task",id)) Do ##class(Demo.Protocol).Fail("Declaration review task missing")
    Set task={}.%FromJSON(^ContestDeclaration("task",id))
    Set keys="id,mode,record_id,declaration_id,revision,declaration_digest,catalog_version,catalog_hash,state,assessment,result,reserved_requests,attempted_requests,created_by,created_at,blocked_reason,record_hash"
    If task.%IsDefined("runtime") Set keys=keys_",runtime"
    Do ##class(Contest.RouteGovernance).Shape(task,keys)
    Do ..Verify(task)
    If (task.id'=id)||(task.%Get("record_id")'=record.id)||(task.%Get("declaration_digest")'=record.digest)||(task.revision'=record.revision)||(task.%Get("declaration_id")'=record.%Get("declaration_id")) Do ##class(Demo.Protocol).Fail("Review belongs to a different declaration revision")
    If (task.mode'="declaration")||(task.%Get("catalog_version")'=record.context.%Get("catalog_version"))||(task.%Get("catalog_hash")'=record.context.%Get("catalog_hash")) Do ##class(Demo.Protocol).Fail("Review catalog binding differs from declaration")
    For field="reserved_requests","attempted_requests" {
        If (task.%GetTypeOf(field)'="number")||(task.%Get(field)<0)||((task.%Get(field)\1)'=task.%Get(field)) Do ##class(Demo.Protocol).Fail("Nonnegative integer review accounting required")
    }
    If task.%Get("attempted_requests")>task.%Get("reserved_requests") Do ##class(Demo.Protocol).Fail("Review attempts exceed reservation")
    If '((task.state="blocked_budget")||(task.state="queued")||(task.state="running")||(task.state="completed")||(task.state="failed")) Do ##class(Demo.Protocol).Fail("Unknown declaration review state")
    If task.state="completed" {
        If '((task.assessment="no_risk_identified")||(task.assessment="risk_identified")||(task.assessment="information_required")) Do ##class(Demo.Protocol).Fail("Completed declaration assessment required")
        If task.%GetTypeOf("result")'="object" Do ##class(Demo.Protocol).Fail("Completed review result required")
        If task.%IsDefined("runtime") {
            If task.assessment'=task.result.assessment Do ##class(Demo.Protocol).Fail("Task assessment differs from reviewed result")
        }
    } Else {
        If (task.%GetTypeOf("assessment")'="null")||(task.%GetTypeOf("result")'="null") Do ##class(Demo.Protocol).Fail("Incomplete review cannot contain an assessment")
    }
    If task.%IsDefined("runtime") {
        Set runtime=task.runtime
        Do ##class(Contest.RouteGovernance).Shape(runtime,"authorization,source,report_id,message_id,session_id,error,dispatched")
        If (runtime.authorization.%Get("task_id")'=task.id)||(runtime.authorization.%Get("record_id")'=record.id)||(runtime.authorization.digest'=record.digest)||(runtime.source.id'=runtime.authorization.%Get("agent_id")) Do ##class(Demo.Protocol).Fail("Runtime authorization belongs to another task")
        If task.%Get("reserved_requests")'=2 Do ##class(Demo.Protocol).Fail("Funded task requires exactly two reserved requests")
    }
    Quit task
}

ClassMethod Read(id As %String) As %DynamicObject
{
    Do ..Access()
    Set record=..Load(id), task=..Task(record), taskView={"task":null}, decision=""
    If $IsObject(task) Do taskView.%Set("task",task)
    If $Data(^ContestDeclaration("decision",id)) {
        Set decision={}.%FromJSON(^ContestDeclaration("decision",id))
        Do ##class(Contest.RouteGovernance).Shape(decision,"record_id,digest,task_id,task_hash,action,reason,decided_by,decided_at,record_hash")
        Do ..Verify(decision)
        If (decision.%Get("record_id")'=id)||(decision.digest'=record.digest)||('$IsObject(task)) Do ##class(Demo.Protocol).Fail("Decision declaration binding mismatch")
        If (decision.%Get("task_id")'=task.id)||(decision.%Get("task_hash")'=task.%Get("record_hash")) Do ##class(Demo.Protocol).Fail("Decision review binding mismatch")
        If '((decision.action="approved")||(decision.action="returned")||(decision.action="rejected")) Do ##class(Demo.Protocol).Fail("Unknown stored declaration decision")
        If decision.action="approved" {
            If (task.state'="completed")||(task.assessment'="no_risk_identified") Do ##class(Demo.Protocol).Fail("Stored approval lacks a completed no-risk review")
        }
    }
    Set key=record.%Get("declaration_id"), current=$Get(^ContestDeclaration("submitted",key)), capability=##class(Contest.DeclarationCatalog).Capability(record.proposal)
    Set execution="not_approved"
    If $IsObject(decision) {
        If decision.action="approved" Set execution=$Select(capability.state="supported":"ready",1:"unsupported")
    }
    Set now=##class(Demo.Protocol).Now()
    If now<record.proposal.validity.from Set execution="not_yet_valid"
    If now>=record.proposal.validity.until Set execution="expired"
    If (current'="")&&(current'=id) {
        Set active=..Load(current)
        If active.revision>record.revision Set execution="superseded"
    }
    If (execution="ready")&&(record.revision'=+$Get(^ContestDeclaration("latest",key))) Set execution="superseded"
    Set result={}.%FromJSON(record.%ToJSON())
    Do result.%Set("state",$Select($IsObject(task):"submitted",1:"draft")), result.%Set("review",taskView)
    If $IsObject(decision) { Do result.%Set("decision",decision) } Else { Do result.%Set("decision","","null") }
    Set attempted=0
    If $IsObject(task) Set attempted=task.%Get("attempted_requests")
    Do result.%Set("capability",capability), result.%Set("execution_state",execution), result.%Set("model_calls",attempted)
    Do result.%Set("latest_revision",+$Get(^ContestDeclaration("latest",key))), result.%Set("is_current_submission",current=id,"boolean")
    Quit result
}

ClassMethod Submit(body As %DynamicObject) As %DynamicObject
{
    Do ..Access(1), ##class(Contest.RouteGovernance).Shape(body,"record_id,digest"), ..Hash(body,"digest")
    Set record=..Load(body.%Get("record_id")), key=record.%Get("declaration_id")
    Lock +^ContestDeclaration("lock",key):2
    If '$Test Do ##class(Demo.Protocol).Fail("Declaration busy")
    Try {
        If (record.digest'=body.digest)||(record.revision'=+$Get(^ContestDeclaration("latest",key))) Do ##class(Demo.Protocol).Fail("Submit requires the exact latest declaration revision")
        Set catalog=##class(Contest.DeclarationCatalog).Get()
        If (record.context.%Get("catalog_version")'=catalog.version)||(record.context.%Get("catalog_hash")'=##class(Contest.ExportEvidence).Digest(catalog)) Do ##class(Demo.Protocol).Fail("Catalog changed; save a new declaration revision")
        Set task=..Task(record)
        If '$IsObject(task) {
            If record.proposal.validity.until<=##class(Demo.Protocol).Now() Do ##class(Demo.Protocol).Fail("Expired declaration cannot be submitted")
            Set id="declaration-review-"_$System.Util.CreateGUID()
            Set task={"id":(id),"mode":"declaration","record_id":(record.id),"declaration_id":(key),"revision":(record.revision),"declaration_digest":(record.digest),"catalog_version":(catalog.version),"catalog_hash":(record.context.%Get("catalog_hash")),"state":"blocked_budget","assessment":null,"result":null,"reserved_requests":0,"attempted_requests":0,"created_by":($Username),"created_at":(##class(Demo.Protocol).Now()),"blocked_reason":"D1 persists review intent only; D2 must authorize and execute this task."}
            Do ..Seal(task)
            TStart
            Try {
                Set ^ContestDeclaration("task",id)=task.%ToJSON(), ^ContestDeclaration("review",record.id)=id, ^ContestDeclaration("submitted",key)=record.id
                Do ##class(Contest.KnowledgeService).Audit("declaration.submitted",record.id,id)
                TCommit
            } Catch ex { TRollback 1 Throw ex }
        }
    } Catch ex {
        Lock -^ContestDeclaration("lock",key)
        Do ##class(Contest.KnowledgeService).Audit("declaration.submit.rejected",record.id,ex.DisplayString())
        Throw ex
    }
    Lock -^ContestDeclaration("lock",key)
    Quit ..Read(record.id)
}

ClassMethod Decide(body As %DynamicObject) As %DynamicObject
{
    Do ..Access(1), ##class(Contest.RouteGovernance).Shape(body,"record_id,digest,task_id,task_hash,action,reason")
    Do ..Hash(body,"digest"), ..Hash(body,"task_hash"), ##class(Contest.RouteGovernance).Text(body,"reason",1000)
    If '((body.action="approved")||(body.action="returned")||(body.action="rejected")) Do ##class(Demo.Protocol).Fail("Explicit declaration decision required")
    Set record=..Load(body.%Get("record_id")), key=record.%Get("declaration_id")
    Lock +^ContestDeclaration("lock",key):2
    If '$Test Do ##class(Demo.Protocol).Fail("Declaration busy")
    Try {
        Set task=..Task(record), catalog=##class(Contest.DeclarationCatalog).Get()
        If (record.digest'=body.digest)||(record.revision'=+$Get(^ContestDeclaration("latest",key)))||($Get(^ContestDeclaration("submitted",key))'=record.id) Do ##class(Demo.Protocol).Fail("Decision requires the current submitted revision")
        If '$IsObject(task) Do ##class(Demo.Protocol).Fail("Declaration review required")
        If (task.id'=body.%Get("task_id"))||(task.%Get("record_hash")'=body.%Get("task_hash")) Do ##class(Demo.Protocol).Fail("Decision requires the exact review result")
        If '((task.state="completed")||(task.state="failed")) Do ##class(Demo.Protocol).Fail("A terminal review task is required for a decision")
        If body.action="approved" {
            If (task.state'="completed")||(task.assessment'="no_risk_identified") Do ##class(Demo.Protocol).Fail("Approval requires a completed no-risk declaration review")
            If (record.context.%Get("catalog_version")'=catalog.version)||(record.context.%Get("catalog_hash")'=##class(Contest.ExportEvidence).Digest(catalog))||(record.proposal.validity.from>##class(Demo.Protocol).Now())||(record.proposal.validity.until<=##class(Demo.Protocol).Now()) Do ##class(Demo.Protocol).Fail("Current catalog and valid declaration interval required")
        }
        If $Data(^ContestDeclaration("decision",record.id)) {
            Set existing=..Read(record.id).decision
            If (existing.action'=body.action)||(existing.reason'=body.reason)||(existing.%Get("decided_by")'=$Username) Do ##class(Demo.Protocol).Fail("Immutable declaration decision conflict")
        } Else {
            Set decision={"record_id":(record.id),"digest":(record.digest),"task_id":(task.id),"task_hash":(task.%Get("record_hash")),"action":(body.action),"reason":(body.reason),"decided_by":($Username),"decided_at":(##class(Demo.Protocol).Now())}
            Do ..Seal(decision)
            TStart
            Try {
                Set ^ContestDeclaration("decision",record.id)=decision.%ToJSON()
                Do ##class(Contest.KnowledgeService).Audit("declaration.decided",record.id,body.action)
                TCommit
            } Catch ex { TRollback 1 Throw ex }
        }
    } Catch ex {
        Lock -^ContestDeclaration("lock",key)
        Do ##class(Contest.KnowledgeService).Audit("declaration.decision.rejected",record.id,ex.DisplayString())
        Throw ex
    }
    Lock -^ContestDeclaration("lock",key)
    Quit ..Read(record.id)
}

ClassMethod List(after As %String = "") As %DynamicObject
{
    Do ..Access()
    If after'="" Do ..Identity(after)
    Set items=[], key=after, cursor="", next=""
    For i=1:1:25 {
        Set key=$Order(^ContestDeclaration("latest",key))
        If key="" Quit
        Set revision=^ContestDeclaration("latest",key), record=..Read(^ContestDeclaration("revision",key,revision))
        Do items.%Push(record)
        Set cursor=key
    }
    If cursor'="" Set next=$Order(^ContestDeclaration("latest",cursor))
    Quit {"items":(items),"next_cursor":($Select(next'="":cursor,1:"")),"can_write":($System.Security.Check("ContestMonitorDeploy","U")),"model_calls":0}
}

ClassMethod History(key As %String, before As %String = "") As %DynamicObject
{
    Do ..Access(), ..Identity(key)
    If '$Data(^ContestDeclaration("latest",key)) Do ##class(Demo.Protocol).Fail("Declaration not found")
    Set items=[], revision=^ContestDeclaration("latest",key)
    If before'="" {
        If ('$Match(before,"^[1-9][0-9]{0,5}$"))||(before>100001) Do ##class(Demo.Protocol).Fail("Bounded history revision cursor required")
        Set revision=$Select((before-1)<revision:before-1,1:revision)
    }
    For i=1:1:25 {
        If revision<1 Quit
        Do items.%Push(..Read(^ContestDeclaration("revision",key,revision)))
        Set revision=revision-1
    }
    Quit {"declaration_id":(key),"items":(items),"older_before_revision":(revision+1),"has_older":(revision>0)}
}

}
