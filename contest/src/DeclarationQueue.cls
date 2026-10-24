Class Contest.DeclarationQueue
{
ClassMethod Access() [ Private ]
{
    If ($Namespace'="TRIAGE")||('$System.Security.Check("ContestMonitorDeploy","U")) Do ##class(Demo.Protocol).Fail("TRIAGE declaration execution capability required")
}

ClassMethod Store(task As %DynamicObject) [ Private ]
{
    Do task.%Remove("record_hash")
    Do task.%Set("record_hash",##class(Contest.ExportEvidence).Digest(task))
    Set ^ContestDeclaration("task",task.id)=task.%ToJSON()
}

ClassMethod Current(record As %DynamicObject) [ Private ]
{
    Set key=record.%Get("declaration_id")
    If (record.revision'=+$Get(^ContestDeclaration("latest",key)))||($Get(^ContestDeclaration("submitted",key))'=record.id) Do ##class(Demo.Protocol).Fail("Only the current submitted declaration can be reviewed")
    If record.%GetTypeOf("decision")'="null" Do ##class(Demo.Protocol).Fail("Decision is final; revise before a new review")
    Set catalog=##class(Contest.DeclarationCatalog).Get()
    If record.context.%Get("catalog_hash")'=##class(Contest.ExportEvidence).Digest(catalog) Do ##class(Demo.Protocol).Fail("Catalog changed; revise the declaration")
    If record.proposal.validity.until<=##class(Demo.Protocol).Now() Do ##class(Demo.Protocol).Fail("Expired declaration cannot be reviewed")
}

ClassMethod Prepare(id As %String) As %DynamicObject
{
    Do ..Access()
    Set record=##class(Contest.DeclarationService).Read(id)
    Do ..Current(record)
    If record.review.%GetTypeOf("task")'="object" Do ##class(Demo.Protocol).Fail("Submit the declaration before preparing cost consent")
    If '$Data(^ContestRouteReview("config")) Do ##class(Demo.Protocol).Fail("An eligible review source must be configured")
    Set config={}.%FromJSON(^ContestRouteReview("config")), source=##class(Contest.AgentService).Get(config.%Get("agent_id"))
    If ('##class(Contest.PrivacyEvaluation).Eligible(source))||(source.model'="deepseek-flash") Do ##class(Demo.Protocol).Fail("Eligible deepseek-flash source Agent required")
    Set packet=##class(Contest.DeclarationReview).Packet(record), task=record.review.task
    Set consent={"record_id":(record.id),"digest":(record.digest),"task_id":(task.id),"agent_id":(source.id),"source_revision":(source.revision),"config_hash":(source.%Get("config_hash")),"input_hash":(##class(Demo.Protocol).Hash(packet.%ToJSON())),"contract_hash":(##class(Contest.DeclarationReview).ContractHash()),"max_model_requests":2,"acknowledge_cost":false}
    Quit {"consent":(consent),"packet":(packet),"source":(source),"model_calls":0}
}

ClassMethod Reserve(body As %DynamicObject) As %DynamicObject
{
    Do ..Access(), ##class(Contest.RouteGovernance).Shape(body,"record_id,digest,task_id,agent_id,source_revision,config_hash,input_hash,contract_hash,max_model_requests,acknowledge_cost")
    If (body.%GetTypeOf("acknowledge_cost")'="boolean")||('body.%Get("acknowledge_cost"))||(body.%GetTypeOf("max_model_requests")'="number")||(body.%Get("max_model_requests")'=2) Do ##class(Demo.Protocol).Fail("Explicit maximum two-request cost consent required")
    Set record=##class(Contest.DeclarationService).Read(body.%Get("record_id")), key=record.%Get("declaration_id")
    Lock +^ContestDeclaration("lock",key):2
    If '$Test Do ##class(Demo.Protocol).Fail("Declaration reservation busy")
    Try {
        Set record=##class(Contest.DeclarationService).Read(record.id)
        Set task=record.review.task
        If '$IsObject(task) Do ##class(Demo.Protocol).Fail("Submitted review task required")
        If task.%IsDefined("runtime") {
            Set expected=task.runtime.authorization
        } Else {
            Set prepared=..Prepare(record.id), expected=prepared.consent
        }
        Do expected.%Set("acknowledge_cost",1,"boolean")
        For field="record_id","digest","task_id","agent_id","source_revision","config_hash","input_hash","contract_hash","max_model_requests","acknowledge_cost" {
            If (body.%GetTypeOf(field)'=expected.%GetTypeOf(field))||(body.%Get(field)'=expected.%Get(field)) Do ##class(Demo.Protocol).Fail("Declaration review consent changed: "_field)
        }
        Set body=expected
        If task.%IsDefined("runtime") {
            If task.runtime.authorization.%ToJSON()'=body.%ToJSON() Do ##class(Demo.Protocol).Fail("Immutable review cost authorization conflict")
        } Else {
            If task.state'="blocked_budget" Do ##class(Demo.Protocol).Fail("Only an unreserved task can receive an allowance")
            Set runtime={"authorization":(body),"source":(prepared.source),"report_id":"","message_id":"","session_id":"","error":"","dispatched":false}
            Do task.%Set("runtime",runtime), task.%Set("reserved_requests",2)
            Set task.state="queued"
            Do task.%Set("blocked_reason","")
            TStart
            Try {
                Do ..Store(task), ##class(Contest.KnowledgeService).Audit("declaration.review.reserved",task.id,"At most two provider requests; no retries")
                TCommit
            } Catch ex { TRollback 1 Throw ex }
        }
    } Catch ex {
        Lock -^ContestDeclaration("lock",key)
        Do ##class(Contest.KnowledgeService).Audit("declaration.reserve.rejected",record.id,ex.DisplayString())
        Throw ex
    }
    Lock -^ContestDeclaration("lock",key)
    Quit ##class(Contest.DeclarationService).Read(record.id)
}

ClassMethod Start(body As %DynamicObject) As %DynamicObject
{
    Set record=..Reserve(body), task=record.review.task
    If (task.state="queued")&&('task.runtime.dispatched) {
        Job ##class(Contest.DeclarationQueue).Dispatch(record.id)::2
        If '$Test Do ##class(Demo.Protocol).Fail("Could not launch declaration review dispatcher; reservation retained")
    }
    Quit record
}

ClassMethod Dispatch(id As %String)
{
    Do ..Access()
    Lock +^ContestDeclaration("dispatch",id):0
    If '$Test Quit
    Try {
        Set record=##class(Contest.DeclarationService).Read(id), key=record.%Get("declaration_id")
        Lock +^ContestDeclaration("lock",key):2
        If '$Test Do ##class(Demo.Protocol).Fail("Declaration dispatch busy")
        Try {
            Set record=##class(Contest.DeclarationService).Read(id), task=record.review.task
            If (task.state'="queued")||(task.runtime.dispatched) {
                Lock -^ContestDeclaration("lock",key), -^ContestDeclaration("dispatch",id)
                Return
            }
            Do ..Current(record)
            Do task.runtime.%Set("dispatched",1,"boolean"), ..Store(task)
        } Catch ex { Lock -^ContestDeclaration("lock",key) Throw ex }
        Lock -^ContestDeclaration("lock",key)
        Set request=##class(Contest.DeclarationReviewRequest).%New(), request.RecordId=id, request.TaskId=task.id, request.DeclarationDigest=record.digest
        Set request.AuthorizationHash=##class(Contest.ExportEvidence).Digest(task.runtime.authorization)
        Set sc=##class(Ens.Director).CreateBusinessService("DeclarationReviewService",.service) $$$ThrowOnError(sc)
        Set sc=service.ProcessInput(request,.response) $$$ThrowOnError(sc)
    } Catch ex {
        Do ##class(Contest.KnowledgeService).Audit("declaration.dispatch.failed",id,ex.DisplayString())
        If $IsObject(task) Do ..Fail(task,ex.DisplayString())
    }
    Lock -^ContestDeclaration("dispatch",id)
}

ClassMethod SyncReport(task As %DynamicObject) [ Private ]
{
    Set reportid=$Get(^ContestRiskReview("request","declaration-"_task.id))
    If reportid="" Quit
    Set report=##class(Contest.DeclarationReview).Status(reportid)
    Do task.runtime.%Set("report_id",report.id)
    Do task.%Set("attempted_requests",report.%Get("reserved_model_requests"))
}

ClassMethod Fail(task As %DynamicObject, reason As %String) [ Private ]
{
    Set current=##class(Contest.DeclarationService).Read(task.%Get("record_id")).review.task
    If (current.state="completed")||(current.state="failed") Quit
    Set task=current
    Do ..SyncReport(task)
    Set task.state="failed"
    Do task.%Set("assessment","","null"), task.%Set("result","","null"), task.runtime.%Set("error",reason)
    Do ..Store(task)
}

ClassMethod Execute(request As Contest.DeclarationReviewRequest, session As %String) As %DynamicObject
{
    Do ..Access()
    Lock +^ContestDeclaration("execute",request.TaskId):0
    If '$Test Do ##class(Demo.Protocol).Fail("Declaration review is already executing")
    Try {
        Set record=##class(Contest.DeclarationService).Read(request.RecordId), task=record.review.task
        If (task.id'=request.TaskId)||(record.digest'=request.DeclarationDigest)||(task.%GetTypeOf("runtime")'="object") Do ##class(Demo.Protocol).Fail("Review request does not match the declaration task")
        If request.AuthorizationHash'=##class(Contest.ExportEvidence).Digest(task.runtime.authorization) Do ##class(Demo.Protocol).Fail("Review authorization hash differs")
        If (task.state="completed")||(task.state="failed") {
            Lock -^ContestDeclaration("execute",request.TaskId)
            Return task
        }
        If task.state'="queued" Do ##class(Demo.Protocol).Fail("Interrupted or running task cannot be replayed")
        Do ..Current(record)
        Set task.state="running"
        Do task.runtime.%Set("message_id",request.%Id()), task.runtime.%Set("session_id",session), ..Store(task)
        Try {
            Set authorization=task.runtime.authorization, source=task.runtime.source, packet=##class(Contest.DeclarationReview).Packet(record)
            Set consent={"request_key":("declaration-"_task.id),"agent_id":(source.id),"source_revision":(source.revision),"config_hash":(source.%Get("config_hash")),"input_hash":(authorization.%Get("input_hash")),"contract_hash":(authorization.%Get("contract_hash")),"max_model_requests":2,"acknowledge_cost":true}
            Set report=##class(Contest.DeclarationReview).Run(packet,consent)
            Do task.runtime.%Set("report_id",report.id), task.%Set("attempted_requests",report.%Get("reserved_model_requests"))
            If report.state="completed" {
                Set task.state="completed", task.assessment=report.result.assessment, task.result=report.result
                Do ..Store(task)
            } Else {
                Do ..Fail(task,"AI Hub review failed; inspect phase evidence. No substitute result or automatic retry.")
            }
        } Catch ex {
            Do ..Fail(task,ex.DisplayString())
            Do ##class(Contest.KnowledgeService).Audit("declaration.review.failed",task.id,ex.DisplayString())
        }
    } Catch ex {
        Lock -^ContestDeclaration("execute",request.TaskId)
        Throw ex
    }
    Lock -^ContestDeclaration("execute",request.TaskId)
    Quit ##class(Contest.DeclarationService).Read(request.RecordId).review.task
}

ClassMethod Report(id As %String) As %DynamicObject
{
    Set record=##class(Contest.DeclarationService).Read(id), task=record.review.task
    If '$IsObject(task) Do ##class(Demo.Protocol).Fail("No review task for this declaration")
    If task.%GetTypeOf("runtime")'="object" Do ##class(Demo.Protocol).Fail("No funded review for this declaration")
    Set reportid=task.runtime.%Get("report_id")
    If reportid="" Set reportid=$Get(^ContestRiskReview("request","declaration-"_task.id))
    If reportid="" Do ##class(Demo.Protocol).Fail("No Agent report exists yet")
    Quit ##class(Contest.DeclarationReview).Status(reportid)
}

ClassMethod Recover(body As %DynamicObject) As %DynamicObject
{
    Do ..Access(), ##class(Contest.RouteGovernance).Shape(body,"record_id,task_id,task_hash")
    Set record=##class(Contest.DeclarationService).Read(body.%Get("record_id")), task=record.review.task
    If '$IsObject(task) Do ##class(Demo.Protocol).Fail("Review task required")
    If (task.id'=body.%Get("task_id"))||(task.%Get("record_hash")'=body.%Get("task_hash")) Do ##class(Demo.Protocol).Fail("Exact interrupted task snapshot required")
    Lock +^ContestDeclaration("dispatch",record.id):0
    If '$Test Do ##class(Demo.Protocol).Fail("Dispatcher is still active")
    Lock +^ContestDeclaration("execute",task.id):0
    If '$Test {
        Lock -^ContestDeclaration("dispatch",record.id)
        Do ##class(Demo.Protocol).Fail("Review worker is still active")
    }
    Try {
        Set latest=##class(Contest.DeclarationService).Read(record.id).review.task
        If latest.%Get("record_hash")'=task.%Get("record_hash") Do ##class(Demo.Protocol).Fail("Task changed while recovering")
        If '((task.state="queued")||(task.state="running")) Do ##class(Demo.Protocol).Fail("Only an interrupted funded task can be recovered")
        Do ..Fail(task,"Review worker ended without a terminal result. Reserved requests are retained; no replay.")
        Do ##class(Contest.KnowledgeService).Audit("declaration.review.interrupted",task.id,"Explicit recovery; no replay")
    } Catch ex {
        Lock -^ContestDeclaration("execute",task.id), -^ContestDeclaration("dispatch",record.id)
        Throw ex
    }
    Lock -^ContestDeclaration("execute",task.id), -^ContestDeclaration("dispatch",record.id)
    Quit ##class(Contest.DeclarationService).Read(record.id)
}
}
