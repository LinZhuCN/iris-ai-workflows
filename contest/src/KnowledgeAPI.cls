Class Contest.KnowledgeAPI Extends %CSP.REST
{
Parameter UseSession = 0;
Parameter HandleCorsRequest = 0;
Parameter CHARSET = "utf-8";

XData UrlMap [ XMLNamespace = "http://www.intersystems.com/urlmap" ]
{
<Routes>
<Route Url="/m5-demo" Method="GET" Call="M5DemoStatus"/>
<Route Url="/m5-demo/profiles" Method="POST" Call="M5DemoProfiles"/>
<Route Url="/m5-demo/send" Method="POST" Call="M5DemoSend"/>
<Route Url="/m5-demo/audit" Method="POST" Call="M5DemoAudit"/>
<Route Url="/m5-demo/reset" Method="POST" Call="M5DemoReset"/>
<Route Url="/organizations" Method="GET" Call="Organizations"/>
<Route Url="/organizations" Method="POST" Call="OrganizationSave"/>
<Route Url="/distribution" Method="GET" Call="DistributionStatus"/>
<Route Url="/distribution/seed" Method="POST" Call="DistributionSeed"/>
<Route Url="/distribution/run" Method="POST" Call="DistributionRun"/>
<Route Url="/distribution/audit" Method="POST" Call="DistributionAudit"/>
<Route Url="/distribution/runs/:id" Method="GET" Call="DistributionDetail"/>
<Route Url="/knowledge" Method="GET" Call="Status"/>
<Route Url="/knowledge/search" Method="POST" Call="Search"/>
<Route Url="/knowledge/builds" Method="POST" Call="Build"/>
<Route Url="/knowledge/builds/:id" Method="GET" Call="JobStatus"/>
<Route Url="/instances" Method="GET" Call="Instances"/>
<Route Url="/instances/local-demo/discover" Method="POST" Call="Discover"/>
<Route Url="/pipelines" Method="GET" Call="Pipelines"/>
<Route Url="/productions" Method="GET" Call="ManagedProductions"/>
<Route Url="/productions/discover" Method="GET" Call="DiscoverProductions"/>
<Route Url="/productions/enroll" Method="POST" Call="EnrollProduction"/>
<Route Url="/productions/manage" Method="POST" Call="ManageProduction"/>
<Route Url="/productions/action" Method="POST" Call="ProductionEventAction"/>
<Route Url="/productions/:id/events" Method="GET" Call="ProductionEvents"/>
<Route Url="/productions/:id/risks" Method="GET" Call="ProductionRisks"/>
<Route Url="/productions/:id/flows" Method="GET" Call="ProductionFlows"/>
<Route Url="/productions/:id/evidence" Method="GET" Call="ProductionEvidence"/>
<Route Url="/productions/:id/paths" Method="GET" Call="ProductionPaths"/>
<Route Url="/productions/authorize-inspection" Method="POST" Call="AuthorizeProductionInspection"/>
<Route Url="/productions/revoke-inspection" Method="POST" Call="RevokeProductionInspection"/>
<Route Url="/productions/authorize-review" Method="POST" Call="AuthorizeProductionReview"/>
<Route Url="/productions/revoke-review" Method="POST" Call="RevokeProductionReview"/>
<Route Url="/productions/:id/reviews" Method="GET" Call="ProductionReviews"/>
<Route Url="/productions/:id/reviews/:header" Method="GET" Call="ProductionReviewDetail"/>
<Route Url="/productions/:id/review-plan" Method="GET" Call="ProductionReviewPlan"/>
<Route Url="/productions/:id" Method="GET" Call="ManagedProduction"/>
<Route Url="/production-flows/save" Method="POST" Call="SaveProductionFlow"/>
<Route Url="/production-flows/:id" Method="GET" Call="ProductionFlow"/>
<Route Url="/deployments/plan" Method="POST" Call="Plan"/>
<Route Url="/deployments/:id/approve" Method="POST" Call="Approve"/>
<Route Url="/deployments/:id/apply" Method="POST" Call="Apply"/>
<Route Url="/demo/messages" Method="POST" Call="DemoMessage"/>
<Route Url="/demo/transport" Method="POST" Call="DemoTransport"/>
<Route Url="/pipelines/summary" Method="POST" Call="PipelineSummary"/>
<Route Url="/agents" Method="GET" Call="Agents"/>
<Route Url="/agents/generate" Method="POST" Call="AgentGenerate"/>
<Route Url="/agents/edit" Method="POST" Call="AgentEdit"/>
<Route Url="/agents/revise" Method="POST" Call="AgentRevise"/>
<Route Url="/agents/test" Method="POST" Call="AgentTest"/>
<Route Url="/agents/retest" Method="POST" Call="AgentRetest"/>
<Route Url="/agents/publish" Method="POST" Call="AgentPublish"/>
<Route Url="/agents/bind" Method="POST" Call="AgentBind"/>
<Route Url="/agents/disable" Method="POST" Call="AgentDisable"/>
<Route Url="/events" Method="GET" Call="Events"/>
<Route Url="/events/:id" Method="GET" Call="EventDetail"/>
<Route Url="/events/action" Method="POST" Call="EventAction"/>
<Route Url="/events/investigate" Method="POST" Call="EventInvestigate"/>
<Route Url="/evaluations" Method="GET" Call="Evaluations"/>
<Route Url="/evaluations" Method="POST" Call="StartEvaluation"/>
<Route Url="/business-evaluations" Method="GET" Call="BusinessEvaluations"/>
<Route Url="/business-evaluations" Method="POST" Call="StartBusinessEvaluation"/>
<Route Url="/rules" Method="GET" Call="Rules"/>
<Route Url="/rules/create" Method="POST" Call="RuleCreate"/>
<Route Url="/rules/test" Method="POST" Call="RuleTest"/>
<Route Url="/rules/plan" Method="POST" Call="RulePlan"/>
<Route Url="/rules/approve" Method="POST" Call="RuleApprove"/>
<Route Url="/rules/apply" Method="POST" Call="RuleApply"/>
<Route Url="/rules/rollback" Method="POST" Call="RuleRollback"/>
<Route Url="/governance" Method="GET" Call="Governance"/>
<Route Url="/governance/template" Method="GET" Call="GovernanceTemplate"/>
<Route Url="/governance/register" Method="POST" Call="GovernanceRegister"/>
<Route Url="/governance/approve" Method="POST" Call="GovernanceApprove"/>
<Route Url="/governance/evidence" Method="POST" Call="GovernanceEvidence"/>
<Route Url="/route-reviews" Method="GET" Call="RouteReviews"/>
<Route Url="/route-reviews/:id" Method="GET" Call="RouteReviewDetail"/>
<Route Url="/route-reviews" Method="POST" Call="RouteReviewAction"/>
<Route Url="/declarations/catalog" Method="GET" Call="DeclarationCatalog"/>
<Route Url="/declarations" Method="GET" Call="Declarations"/>
<Route Url="/declarations" Method="POST" Call="DeclarationSave"/>
<Route Url="/declarations/submit" Method="POST" Call="DeclarationSubmit"/>
<Route Url="/declarations/decide" Method="POST" Call="DeclarationDecide"/>
<Route Url="/declarations/review" Method="POST" Call="DeclarationReviewStart"/>
<Route Url="/declarations/recover" Method="POST" Call="DeclarationReviewRecover"/>
<Route Url="/declarations/execute" Method="POST" Call="DeclarationExecute"/>
<Route Url="/declarations/executions/:run" Method="GET" Call="DeclarationExecutionDetail"/>
<Route Url="/declarations/monitor/authorize" Method="POST" Call="DeclarationMonitorAuthorize"/>
<Route Url="/declarations/monitor/action" Method="POST" Call="DeclarationMonitorAction"/>
<Route Url="/declarations/monitor/:run/plan" Method="GET" Call="DeclarationMonitorPlan"/>
<Route Url="/declarations/monitor/:run" Method="GET" Call="DeclarationMonitorDetail"/>
<Route Url="/declarations/:id/execution-plan" Method="GET" Call="DeclarationExecutionPlan"/>
<Route Url="/declarations/:id/executions" Method="GET" Call="DeclarationExecutions"/>
<Route Url="/declarations/:id/review-plan" Method="GET" Call="DeclarationReviewPlan"/>
<Route Url="/declarations/:id/review-report" Method="GET" Call="DeclarationReviewReport"/>
<Route Url="/declarations/:key/history" Method="GET" Call="DeclarationHistory"/>
<Route Url="/declarations/:id" Method="GET" Call="DeclarationDetail"/>
</Routes>
}

ClassMethod Reply(body As %DynamicObject, status As %String = "200 OK") As %Status
{
    Set %response.Status = status, %response.ContentType = "application/json"
    Do %response.SetHeader("Cache-Control","no-store")
    Do %response.SetHeader("X-Content-Type-Options","nosniff")
    Write body.%ToJSON()
    Quit $$$OK
}

ClassMethod M5DemoCall(action As %String) As %Status
{
    Try {
        Do ##class(Contest.OrganizationCatalog).Access(action'="status")
        If action="status" { Set result=##class(Contest.M5Demo).Status() }
        Else {
            Set body={}.%FromJSON(%request.Content)
            If action="profiles" { Set result=##class(Contest.M5Demo).ProfileSave(body) }
            ElseIf action="send" { Set result=##class(Contest.M5Demo).Send(body) }
            ElseIf action="audit" { Set result=##class(Contest.M5Demo).Audit(body) }
            ElseIf action="reset" { Set result=##class(Contest.M5Demo).Reset(body) }
            Else { Do ##class(Demo.Protocol).Fail("Unknown M5 demo action") }
        }
    } Catch ex {
        Do ##class(Contest.KnowledgeService).Audit("m5.demo.rejected",action,ex.DisplayString())
        Return ..Failure("m5_demo_rejected",ex.DisplayString(),"409 Conflict")
    }
    Quit ..Reply(result)
}
ClassMethod M5DemoStatus() As %Status { Quit ..M5DemoCall("status") }
ClassMethod M5DemoProfiles() As %Status { Quit ..M5DemoCall("profiles") }
ClassMethod M5DemoSend() As %Status { Quit ..M5DemoCall("send") }
ClassMethod M5DemoAudit() As %Status { Quit ..M5DemoCall("audit") }
ClassMethod M5DemoReset() As %Status { Quit ..M5DemoCall("reset") }

ClassMethod Organizations() As %Status
{
    Try { Set result=##class(Contest.OrganizationCatalog).List() }
    Catch ex { Return ..Failure("organization_rejected",ex.DisplayString(),"409 Conflict") }
    Quit ..Reply(result)
}

ClassMethod OrganizationSave() As %Status
{
    Try { Set body={}.%FromJSON(%request.Content), result=##class(Contest.OrganizationCatalog).Save(body) }
    Catch ex {
        Do ##class(Contest.KnowledgeService).Audit("organization.rejected","save",ex.DisplayString())
        Return ..Failure("organization_rejected",ex.DisplayString(),"409 Conflict")
    }
    Quit ..Reply(result)
}

ClassMethod DistributionCall(action As %String, id As %String = "") As %Status
{
    Try {
        Do ##class(Contest.OrganizationCatalog).Access(action'="status"&&action'="detail")
        If action="status" { Set result=##class(Contest.MultiOrganization).Status() }
        ElseIf action="detail" { Set result=##class(Contest.MultiOrganization).Read(id) }
        Else {
            Set body={}.%FromJSON(%request.Content)
            If action="seed" { Set result=##class(Contest.MultiOrganization).Seed(body) }
            ElseIf action="run" { Set result=##class(Contest.MultiOrganization).Start(body) }
            ElseIf action="audit" { Set result=##class(Contest.MultiAudit).Start(body) }
            Else { Do ##class(Demo.Protocol).Fail("Unknown distribution action") }
        }
    } Catch ex {
        Do ##class(Contest.KnowledgeService).Audit("distribution.api.rejected",action,ex.DisplayString())
        Return ..Failure("distribution_rejected",ex.DisplayString(),"409 Conflict")
    }
    Quit ..Reply(result)
}

ClassMethod DistributionStatus() As %Status { Quit ..DistributionCall("status") }
ClassMethod DistributionSeed() As %Status { Quit ..DistributionCall("seed") }
ClassMethod DistributionRun() As %Status { Quit ..DistributionCall("run") }
ClassMethod DistributionAudit() As %Status { Quit ..DistributionCall("audit") }
ClassMethod DistributionDetail(id As %String) As %Status { Quit ..DistributionCall("detail",id) }

ClassMethod Failure(code As %String, message As %String, status As %String) As %Status
{
    Quit ..Reply({"code":(code),"message":(message),"request_id":($Job_"-"_$Increment(^ContestPlatform("requestSequence")))},status)
}

ClassMethod ProductionCall(action As %String, id As %String = "") As %Status
{
    If '$System.Security.Check("ContestMonitorRead","U") Quit ..Failure("forbidden","Production read permission required","403 Forbidden")
    If ((action="discover")||(action="enroll")||(action="manage")||(action="action")||(action="authorize-inspection")||(action="revoke-inspection")||(action="authorize-review")||(action="revoke-review"))&&('$System.Security.Check("ContestMonitorDeploy","U")) Quit ..Failure("forbidden","Production management permission required","403 Forbidden")
    Try {
        If action="list" { Set result=##class(Contest.ProductionMonitor).List() }
        ElseIf action="discover" { Set result=##class(Contest.ProductionMonitor).Discover() }
        ElseIf action="detail" { Set result=##class(Contest.ProductionMonitor).Detail(id) }
        ElseIf action="evidence" {
            Set cursor=$Get(%request.Data("before",1),"0")
            If '$Match(cursor,"^[0-9]{1,15}$") Do ##class(Demo.Protocol).Fail("Numeric evidence cursor required")
            Set result=##class(Contest.ProductionEvidence).Page(id,+cursor,$Get(%request.Data("session",1)))
        }
        ElseIf action="paths" { Set result=##class(Contest.ProductionEvidence).Paths(id,$Get(%request.Data("after",1))) }
        ElseIf action="reviews" {
            Set cursor=$Get(%request.Data("before",1),"0")
            If '$Match(cursor,"^[0-9]{1,15}$") Do ##class(Demo.Protocol).Fail("Numeric review cursor required")
            Set result=##class(Contest.ProductionReviewService).Page(id,+cursor)
        }
        ElseIf action="review-plan" { Set result=##class(Contest.ProductionReviewService).Plan(id) }
        ElseIf (action="events")||(action="risks") {
            Set cursor=$Get(%request.Data("before",1),"0")
            If '$Match(cursor,"^[0-9]{1,15}$") Do ##class(Demo.Protocol).Fail("Bounded numeric event cursor required")
            If action="events" { Set result=##class(Contest.ProductionMonitor).Events(id,+cursor) }
            Else { Set result=##class(Contest.ProductionMonitor).Risks(id,+cursor) }
        } Else {
            Try { Set body={}.%FromJSON(%request.Content) }
            Catch ex { Return ..Failure("invalid_json","Invalid JSON body","400 Bad Request") }
            If '$IsObject(body) Return ..Failure("invalid_body","JSON object required","400 Bad Request")
            If 'body.%IsA("%DynamicObject") Return ..Failure("invalid_body","JSON object required","400 Bad Request")
            If action="enroll" { Set result=##class(Contest.ProductionMonitor).Enroll(body) }
            ElseIf action="manage" { Set result=##class(Contest.ProductionMonitor).Manage(body) }
            ElseIf action="action" { Set result=##class(Contest.ProductionMonitor).Action(body) }
            ElseIf action="authorize-inspection" { Set result=##class(Contest.ProductionEvidence).Authorize(body) }
            ElseIf action="revoke-inspection" { Set result=##class(Contest.ProductionEvidence).Revoke(body) }
            ElseIf action="authorize-review" { Set result=##class(Contest.ProductionReviewService).Authorize(body) }
            ElseIf action="revoke-review" { Set result=##class(Contest.ProductionReviewService).Revoke(body) }
            Else { Do ##class(Demo.Protocol).Fail("Unknown Production action") }
        }
    } Catch ex {
        Do ##class(Contest.KnowledgeService).Audit("production.api.rejected",id,ex.DisplayString())
        Return ..Failure("production_rejected",ex.DisplayString(),"409 Conflict")
    }
    Quit ..Reply(result)
}

ClassMethod ManagedProductions() As %Status { Quit ..ProductionCall("list") }
ClassMethod DiscoverProductions() As %Status { Quit ..ProductionCall("discover") }
ClassMethod EnrollProduction() As %Status { Quit ..ProductionCall("enroll") }
ClassMethod ManageProduction() As %Status { Quit ..ProductionCall("manage") }
ClassMethod ProductionEventAction() As %Status { Quit ..ProductionCall("action") }
ClassMethod ManagedProduction(id As %String) As %Status { Quit ..ProductionCall("detail",id) }
ClassMethod ProductionEvents(id As %String) As %Status { Quit ..ProductionCall("events",id) }
ClassMethod ProductionRisks(id As %String) As %Status { Quit ..ProductionCall("risks",id) }
ClassMethod ProductionEvidence(id As %String) As %Status { Quit ..ProductionCall("evidence",id) }
ClassMethod ProductionPaths(id As %String) As %Status { Quit ..ProductionCall("paths",id) }
ClassMethod AuthorizeProductionInspection() As %Status { Quit ..ProductionCall("authorize-inspection") }
ClassMethod RevokeProductionInspection() As %Status { Quit ..ProductionCall("revoke-inspection") }
ClassMethod AuthorizeProductionReview() As %Status { Quit ..ProductionCall("authorize-review") }
ClassMethod RevokeProductionReview() As %Status { Quit ..ProductionCall("revoke-review") }
ClassMethod ProductionReviews(id As %String) As %Status { Quit ..ProductionCall("reviews",id) }
ClassMethod ProductionReviewPlan(id As %String) As %Status { Quit ..ProductionCall("review-plan",id) }
ClassMethod ProductionReviewDetail(id As %String, header As %String) As %Status
{
    If '$System.Security.Check("ContestMonitorRead","U") Quit ..Failure("forbidden","Production read permission required","403 Forbidden")
    Try {
        If '$Match(header,"^[0-9]{1,15}$") Do ##class(Demo.Protocol).Fail("Exact numeric observation header required")
        Set result=##class(Contest.ProductionReviewService).Detail(id,+header)
    } Catch ex {
        Do ##class(Contest.KnowledgeService).Audit("production.review.detail.rejected",id,ex.DisplayString())
        Return ..Failure("production_rejected",ex.DisplayString(),"409 Conflict")
    }
    Quit ..Reply(result)
}

ClassMethod ProductionFlowCall(action As %String, id As %String = "") As %Status
{
    If '$System.Security.Check("ContestMonitorRead","U") Quit ..Failure("forbidden","Production flow read permission required","403 Forbidden")
    If (action="save")&&('$System.Security.Check("ContestMonitorDeploy","U")) Quit ..Failure("forbidden","Production flow management permission required","403 Forbidden")
    Try {
        If action="list" { Set result=##class(Contest.ProductionFlow).List(id,$Get(%request.Data("after",1))) }
        ElseIf action="detail" {
            Set revision=$Get(%request.Data("revision",1),"0")
            If '$Match(revision,"^[0-9]{1,6}$") Do ##class(Demo.Protocol).Fail("Bounded numeric flow revision required")
            Set result=##class(Contest.ProductionFlow).Read(id,+revision)
        } ElseIf action="save" {
            Try { Set body={}.%FromJSON(%request.Content) }
            Catch ex { Return ..Failure("invalid_json","Invalid JSON body","400 Bad Request") }
            If '$IsObject(body) Return ..Failure("invalid_body","JSON object required","400 Bad Request")
            If 'body.%IsA("%DynamicObject") Return ..Failure("invalid_body","JSON object required","400 Bad Request")
            Set result=##class(Contest.ProductionFlow).Save(body)
        } Else { Do ##class(Demo.Protocol).Fail("Unknown Production flow action") }
    } Catch ex {
        Do ##class(Contest.KnowledgeService).Audit("production.flow.api.rejected",id,ex.DisplayString())
        Return ..Failure("production_flow_rejected",ex.DisplayString(),"409 Conflict")
    }
    Quit ..Reply(result)
}

ClassMethod ProductionFlows(id As %String) As %Status { Quit ..ProductionFlowCall("list",id) }
ClassMethod ProductionFlow(id As %String) As %Status { Quit ..ProductionFlowCall("detail",id) }
ClassMethod SaveProductionFlow() As %Status { Quit ..ProductionFlowCall("save") }

ClassMethod OnPreDispatch(url As %String, method As %String, ByRef continue As %Boolean) As %Status
{
    Set continue = 0
    If '$System.Security.Check("ContestKnowledgeRead","U") Quit ..Failure("forbidden","Knowledge read permission required","403 Forbidden")
    If method = "POST" {
        If %request.GetCgiEnv("HTTP_X_REQUESTED_WITH") '= "IRIS-Workflows" Quit ..Failure("csrf_rejected","Explicit application request header required","403 Forbidden")
        If $ZConvert($ZStrip($Piece(%request.GetCgiEnv("CONTENT_TYPE"),";",1),"<>W"),"L") '= "application/json" Quit ..Failure("content_type","JSON required","415 Unsupported Media Type")
        Set maximum=$Select(url="/declarations":65536,url="/production-flows/save":32768,url="/organizations":16384,1:4096)
        If %request.Content.Size > maximum Quit ..Failure("body_too_large","Request body exceeds "_maximum_" bytes","413 Content Too Large")
    }
    Set continue = 1
    Quit $$$OK
}

ClassMethod ValidQuery(body As %DynamicObject) As %Boolean
{
    If '$IsObject(body) Quit 0
    If 'body.%IsA("%DynamicObject") Quit 0
    If body.%GetTypeOf("query") '= "string" Quit 0
    If body.%Size() '= 1 Quit 0
    Quit ($Length(body.query) <= 1000) && ($ZStrip(body.query,"<>W") '= "")
}

ClassMethod Status() As %Status
{
    Try { Set body = ##class(Contest.KnowledgeService).Status() }
    Catch ex {
        Do ##class(Contest.KnowledgeService).Audit("knowledge.status.failed","",ex.DisplayString())
        Return ..Failure("knowledge_unavailable","Unable to read index status","503 Service Unavailable")
    }
    Quit ..Reply(body)
}

ClassMethod Search() As %Status
{
    Try { Set body = {}.%FromJSON(%request.Content) }
    Catch ex { Return ..Failure("invalid_json","Invalid JSON body","400 Bad Request") }
    If '..ValidQuery(body) Quit ..Failure("invalid_query","Provide only a nonempty query of at most 1000 characters","400 Bad Request")
    Try { Set result = ##class(Contest.KnowledgeService).Search(body.query) }
    Catch ex {
        Do ##class(Contest.KnowledgeService).Audit("knowledge.search.failed","",ex.DisplayString())
        Return ..Failure("retrieval_failed","Local knowledge retrieval failed; no answer was substituted","503 Service Unavailable")
    }
    Quit ..Reply(result)
}

ClassMethod Build() As %Status
{
    If '$System.Security.Check("ContestKnowledgeBuild","U") Quit ..Failure("forbidden","Knowledge build permission required","403 Forbidden")
    Try { Set body = {}.%FromJSON(%request.Content) }
    Catch ex { Return ..Failure("invalid_json","Invalid JSON body","400 Bad Request") }
    If 'body.%IsA("%DynamicObject") Quit ..Failure("invalid_body","An empty JSON object is required","400 Bad Request")
    If body.%Size() '= 0 Quit ..Failure("invalid_body","No paths or build parameters are accepted","400 Bad Request")
    Try { Set id = ##class(Contest.KnowledgeService).StartBuild() }
    Catch ex {
        Do ##class(Contest.KnowledgeService).Audit("knowledge.build.rejected","",ex.DisplayString())
        Return ..Failure("build_conflict","Build could not start; inspect current job status","409 Conflict")
    }
    Quit ..Reply({"job_id":(id)},"202 Accepted")
}

ClassMethod JobStatus(id As %String) As %Status
{
    Set body = ##class(Contest.KnowledgeService).JobStatus(id)
    If '$IsObject(body) Quit ..Failure("not_found","Job not found","404 Not Found")
    Quit ..Reply(body)
}

ClassMethod AgentCall(action As %String) As %Status
{
    If '$System.Security.Check("ContestMonitorRead","U") Quit ..Failure("forbidden","Agent read permission required","403 Forbidden")
    Try {
        If action="list" {
            Set result=##class(Contest.AgentService).List()
        } Else {
            If '$System.Security.Check("ContestMonitorDeploy","U") Return ..Failure("forbidden","Agent builder permission required","403 Forbidden")
            Try { Set body={}.%FromJSON(%request.Content) }
            Catch ex { Return ..Failure("invalid_json","Invalid JSON body","400 Bad Request") }
            If '$IsObject(body) Return ..Failure("invalid_body","JSON object required","400 Bad Request")
            If 'body.%IsA("%DynamicObject") Return ..Failure("invalid_body","JSON object required","400 Bad Request")
            If (action="generate") || (action="test") || (action="retest") {
                If (body.%GetTypeOf("acknowledge_cost")'="boolean") || 'body.%Get("acknowledge_cost") Return ..Failure("cost_confirmation","Explicit confirmation of bounded real model requests is required","400 Bad Request")
                Set result=##class(Contest.AgentService).Schedule(action,body)
            } ElseIf action="revise" {
                Set result=##class(Contest.AgentService).Revise(body)
            } Else {
                Set result=##class(Contest.AgentService).Mutate(action,body)
            }
        }
    } Catch ex {
        Do ##class(Contest.KnowledgeService).Audit("agent."_action_".rejected","",ex.DisplayString())
        Return ..Failure("agent_rejected",ex.DisplayString(),"409 Conflict")
    }
    Quit ..Reply(result,$Select((action="generate") || (action="test") || (action="retest"):"202 Accepted",1:"200 OK"))
}

ClassMethod Agents() As %Status { Quit ..AgentCall("list") }
ClassMethod AgentGenerate() As %Status { Quit ..AgentCall("generate") }
ClassMethod AgentEdit() As %Status { Quit ..AgentCall("edit") }
ClassMethod AgentRevise() As %Status { Quit ..AgentCall("revise") }
ClassMethod AgentTest() As %Status { Quit ..AgentCall("test") }
ClassMethod AgentRetest() As %Status { Quit ..AgentCall("retest") }
ClassMethod AgentPublish() As %Status { Quit ..AgentCall("publish") }
ClassMethod AgentBind() As %Status { Quit ..AgentCall("bind") }
ClassMethod AgentDisable() As %Status { Quit ..AgentCall("disable") }

ClassMethod EventCall(action As %String, id As %String = "") As %Status
{
    If '$System.Security.Check("ContestMonitorRead","U") Quit ..Failure("forbidden","Event read permission required","403 Forbidden")
    Try {
        If action="list" {
            Set result=##class(Contest.EventService).List()
        } ElseIf action="detail" {
            Set result=##class(Contest.EventService).Detail(id)
        } Else {
            If '$System.Security.Check("ContestMonitorDeploy","U") Return ..Failure("forbidden","Event write permission required","403 Forbidden")
            Try { Set body={}.%FromJSON(%request.Content) }
            Catch ex { Return ..Failure("invalid_json","Invalid JSON body","400 Bad Request") }
            If '$IsObject(body) Return ..Failure("invalid_body","JSON object required","400 Bad Request")
            If 'body.%IsA("%DynamicObject") Return ..Failure("invalid_body","JSON object required","400 Bad Request")
            If action="investigate" {
                If (body.%GetTypeOf("acknowledge_cost")'="boolean") || 'body.%Get("acknowledge_cost") Return ..Failure("cost_confirmation","Explicit confirmation of up to four model requests is required","400 Bad Request")
                Set result=##class(Contest.EventService).Investigate(body)
            } Else {
                Set result=##class(Contest.EventService).Action(body)
            }
        }
    } Catch ex {
        Do ##class(Contest.KnowledgeService).Audit("event."_action_".rejected",id,ex.DisplayString())
        Return ..Failure("event_rejected",ex.DisplayString(),"409 Conflict")
    }
    Quit ..Reply(result,$Select(action="investigate":"202 Accepted",1:"200 OK"))
}

ClassMethod Events() As %Status { Quit ..EventCall("list") }
ClassMethod EventDetail(id As %String) As %Status { Quit ..EventCall("detail",id) }
ClassMethod EventAction() As %Status { Quit ..EventCall("action") }
ClassMethod EventInvestigate() As %Status { Quit ..EventCall("investigate") }

ClassMethod Evaluations() As %Status
{
    If '$System.Security.Check("ContestMonitorRead","U") Quit ..Failure("forbidden","Evaluation read permission required","403 Forbidden")
    Try { Return ..Reply(##class(Contest.PrivacyEvaluation).List()) }
    Catch ex {
        Do ##class(Contest.KnowledgeService).Audit("privacy.evaluation.read.failed","",ex.DisplayString())
        Return ..Failure("evaluation_unavailable","Unable to read evaluations; inspect protected audit","503 Service Unavailable")
    }
}

ClassMethod StartEvaluation() As %Status
{
    If '$System.Security.Check("ContestMonitorDeploy","U") Quit ..Failure("forbidden","Evaluation execution permission required","403 Forbidden")
    Try { Set body={}.%FromJSON(%request.Content) }
    Catch ex { Return ..Failure("invalid_json","Invalid JSON body","400 Bad Request") }
    If '##class(Contest.PrivacyEvaluation).ValidStart(body) Quit ..Failure("cost_confirmation","Confirm a fixed twelve-case evaluation with request_key, agent_id and max_model_requests=48","400 Bad Request")
    Try { Return ..Reply(##class(Contest.PrivacyEvaluation).Start(body)) }
    Catch ex {
        Do ##class(Contest.KnowledgeService).Audit("privacy.evaluation.start.rejected","",ex.DisplayString())
        Return ..Failure("evaluation_rejected",ex.DisplayString(),"409 Conflict")
    }
}

ClassMethod BusinessEvaluations() As %Status
{
    If '$System.Security.Check("ContestMonitorRead","U") Quit ..Failure("forbidden","Evaluation read permission required","403 Forbidden")
    Try { Return ..Reply(##class(Contest.BusinessReview).List()) }
    Catch ex {
        Do ##class(Contest.KnowledgeService).Audit("business.evaluation.read.failed","",ex.DisplayString())
        Return ..Failure("business_evaluation_unavailable","Unable to read business evaluations","503 Service Unavailable")
    }
}

ClassMethod StartBusinessEvaluation() As %Status
{
    If '$System.Security.Check("ContestMonitorDeploy","U") Quit ..Failure("forbidden","Evaluation execution permission required","403 Forbidden")
    Try { Set body={}.%FromJSON(%request.Content) }
    Catch ex { Return ..Failure("invalid_json","Invalid JSON body","400 Bad Request") }
    If '##class(Contest.BusinessReview).ValidStart(body) Quit ..Failure("cost_confirmation","Confirm pinned agent_id/input_hash, request_key and max_model_requests=48; versioned reviewers also require the explicit supported runtime_version","400 Bad Request")
    Try { Return ..Reply(##class(Contest.BusinessReview).Start(body),"202 Accepted") }
    Catch ex {
        Do ##class(Contest.KnowledgeService).Audit("business.evaluation.start.rejected","",ex.DisplayString())
        Return ..Failure("business_evaluation_rejected",ex.DisplayString(),"409 Conflict")
    }
}

ClassMethod RuleCall(action As %String) As %Status
{
    If '$System.Security.Check("ContestMonitorRead","U") Quit ..Failure("forbidden","Rule read permission required","403 Forbidden")
    Try {
        If action="list" {
            Set result=##class(Contest.RuleService).List()
        } Else {
            If '$System.Security.Check("ContestMonitorDeploy","U") Return ..Failure("forbidden","Rule deployment permission required","403 Forbidden")
            Try { Set body={}.%FromJSON(%request.Content) }
            Catch ex { Return ..Failure("invalid_json","Invalid JSON body","400 Bad Request") }
            If '$IsObject(body) Return ..Failure("invalid_body","JSON object required","400 Bad Request")
            If 'body.%IsA("%DynamicObject") Return ..Failure("invalid_body","JSON object required","400 Bad Request")
            If action="create" {
                Set result=##class(Contest.RuleService).Create(body)
            } Else {
                If (body.%GetTypeOf("id")'="string") || (body.id="") Return ..Failure("invalid_body","Object identity required","400 Bad Request")
                If (action="test") || (action="plan") {
                    If (body.%Size()'=2) || (body.%GetTypeOf("revision")'="number") Return ..Failure("invalid_body","Exact draft revision required","400 Bad Request")
                    Set result=$Select(action="test":##class(Contest.RuleService).Test(body.id,body.revision),1:##class(Contest.RuleService).Plan(body.id,body.revision))
                } ElseIf action="rollback" {
                    If body.%Size()'=1 Return ..Failure("invalid_body","Only the original deployment identity is accepted","400 Bad Request")
                    Set result=##class(Contest.RuleService).Rollback(body.id)
                } Else {
                    If (body.%Size()'=2) || (body.%GetTypeOf("digest")'="string") Return ..Failure("invalid_body","Exact plan digest required","400 Bad Request")
                    Set result=##class(Contest.RuleService).Transition(body.id,body.digest,action="apply")
                }
            }
        }
    } Catch ex {
        Do ##class(Contest.KnowledgeService).Audit("rule."_action_".rejected","",ex.DisplayString())
        Return ..Failure("rule_rejected",ex.DisplayString(),"409 Conflict")
    }
    Quit ..Reply(result)
}

ClassMethod Rules() As %Status { Quit ..RuleCall("list") }
ClassMethod RuleCreate() As %Status { Quit ..RuleCall("create") }
ClassMethod RuleTest() As %Status { Quit ..RuleCall("test") }
ClassMethod RulePlan() As %Status { Quit ..RuleCall("plan") }
ClassMethod RuleApprove() As %Status { Quit ..RuleCall("approve") }
ClassMethod RuleApply() As %Status { Quit ..RuleCall("apply") }
ClassMethod RuleRollback() As %Status { Quit ..RuleCall("rollback") }

ClassMethod GovernanceCall(action As %String) As %Status
{
    If '$System.Security.Check("ContestMonitorRead","U") Quit ..Failure("forbidden","Route read permission required","403 Forbidden")
    If (action="template")||(action="register")||(action="approve") {
        If '$System.Security.Check("ContestMonitorDeploy","U") Quit ..Failure("forbidden","Route proposal permission required","403 Forbidden")
    }
    Try {
        If action="list" {
            Set result=##class(Contest.RouteUI).List($Get(%request.Data("after",1)))
        } ElseIf action="template" {
            Set result=##class(Contest.RouteUI).Template()
        } Else {
            Try { Set body={}.%FromJSON(%request.Content) }
            Catch ex { Return ..Failure("invalid_json","Invalid JSON body","400 Bad Request") }
            If '$IsObject(body) Return ..Failure("invalid_body","JSON object required","400 Bad Request")
            If 'body.%IsA("%DynamicObject") Return ..Failure("invalid_body","JSON object required","400 Bad Request")
            If action="register" {
                Set result=##class(Contest.RouteUI).Register(body)
            } ElseIf action="approve" {
                Set result=##class(Contest.RouteUI).Approve(body)
            } Else {
                Set result=##class(Contest.RouteUI).Evidence(body)
            }
        }
    } Catch ex {
        Do ##class(Contest.KnowledgeService).Audit("governance."_action_".rejected","",ex.DisplayString())
        Return ..Failure("governance_rejected",ex.DisplayString(),"409 Conflict")
    }
    Quit ..Reply(result)
}

ClassMethod Governance() As %Status { Quit ..GovernanceCall("list") }
ClassMethod GovernanceTemplate() As %Status { Quit ..GovernanceCall("template") }
ClassMethod GovernanceRegister() As %Status { Quit ..GovernanceCall("register") }
ClassMethod GovernanceApprove() As %Status { Quit ..GovernanceCall("approve") }
ClassMethod GovernanceEvidence() As %Status { Quit ..GovernanceCall("evidence") }

ClassMethod DeclarationCall(action As %String, id As %String = "") As %Status
{
    If '$System.Security.Check("ContestMonitorRead","U") Quit ..Failure("forbidden","Declaration read permission required","403 Forbidden")
    Set write=(action="save")||(action="submit")||(action="decide")||(action="review")||(action="recover")||(action="execute")||(action="monitor-authorize")||(action="monitor-action")
    If ((action="review-plan")||(action="execution-plan")||(action="monitor-plan"))&&('$System.Security.Check("ContestMonitorDeploy","U")) Quit ..Failure("forbidden","Declaration write permission required","403 Forbidden")
    If write&&('$System.Security.Check("ContestMonitorDeploy","U")) Quit ..Failure("forbidden","Declaration write permission required","403 Forbidden")
    If write {
        Try { Set body={}.%FromJSON(%request.Content) }
        Catch ex { Return ..Failure("invalid_json","Invalid JSON body","400 Bad Request") }
        If '$IsObject(body) Quit ..Failure("invalid_body","JSON object required","400 Bad Request")
        If 'body.%IsA("%DynamicObject") Quit ..Failure("invalid_body","JSON object required","400 Bad Request")
    }
    Try {
        If action="catalog" { Set result=##class(Contest.DeclarationCatalog).Get() }
        ElseIf action="list" { Set result=##class(Contest.DeclarationService).List($Get(%request.Data("after",1))) }
        ElseIf action="detail" { Set result=##class(Contest.DeclarationService).Read(id) }
        ElseIf action="history" { Set result=##class(Contest.DeclarationService).History(id,$Get(%request.Data("before",1))) }
        ElseIf action="save" { Set result=##class(Contest.DeclarationService).Save(body) }
        ElseIf action="submit" { Set result=##class(Contest.DeclarationService).Submit(body) }
        ElseIf action="review-plan" { Set result=##class(Contest.DeclarationQueue).Prepare(id) }
        ElseIf action="review-report" { Set result=##class(Contest.DeclarationQueue).Report(id) }
        ElseIf action="review" { Set result=##class(Contest.DeclarationQueue).Start(body) }
        ElseIf action="recover" { Set result=##class(Contest.DeclarationQueue).Recover(body) }
        ElseIf action="execution-plan" { Set result=##class(Contest.DeclarationExecution).Prepare(id,$Get(%request.Data("batch_id",1))) }
        ElseIf action="execute" { Set result=##class(Contest.DeclarationExecution).Start(body) }
        ElseIf action="executions" { Set result=##class(Contest.DeclarationExecution).List(id,$Get(%request.Data("before",1))) }
        ElseIf action="execution-detail" { Set result=##class(Contest.DeclarationExecution).Read(id) }
        ElseIf action="monitor-plan" { Set result=##class(Contest.DeclarationMonitor).Plan(id) }
        ElseIf action="monitor-detail" { Set result=##class(Contest.DeclarationMonitor).Detail(id) }
        ElseIf action="monitor-authorize" { Set result=##class(Contest.DeclarationMonitor).Authorize(body) }
        ElseIf action="monitor-action" { Set result=##class(Contest.DeclarationMonitor).Action(body) }
        Else { Set result=##class(Contest.DeclarationService).Decide(body) }
    } Catch ex {
        Do ##class(Contest.KnowledgeService).Audit("declaration.api."_action_".rejected",id,ex.DisplayString())
        Return ..Failure("declaration_rejected",ex.DisplayString(),"409 Conflict")
    }
    Quit ..Reply(result)
}

ClassMethod DeclarationCatalog() As %Status { Quit ..DeclarationCall("catalog") }
ClassMethod Declarations() As %Status { Quit ..DeclarationCall("list") }
ClassMethod DeclarationDetail(id As %String) As %Status { Quit ..DeclarationCall("detail",id) }
ClassMethod DeclarationHistory(key As %String) As %Status { Quit ..DeclarationCall("history",key) }
ClassMethod DeclarationSave() As %Status { Quit ..DeclarationCall("save") }
ClassMethod DeclarationSubmit() As %Status { Quit ..DeclarationCall("submit") }
ClassMethod DeclarationDecide() As %Status { Quit ..DeclarationCall("decide") }
ClassMethod DeclarationReviewStart() As %Status { Quit ..DeclarationCall("review") }
ClassMethod DeclarationReviewRecover() As %Status { Quit ..DeclarationCall("recover") }
ClassMethod DeclarationReviewPlan(id As %String) As %Status { Quit ..DeclarationCall("review-plan",id) }
ClassMethod DeclarationReviewReport(id As %String) As %Status { Quit ..DeclarationCall("review-report",id) }
ClassMethod DeclarationExecutionPlan(id As %String) As %Status { Quit ..DeclarationCall("execution-plan",id) }
ClassMethod DeclarationExecute() As %Status { Quit ..DeclarationCall("execute") }
ClassMethod DeclarationExecutions(id As %String) As %Status { Quit ..DeclarationCall("executions",id) }
ClassMethod DeclarationExecutionDetail(run As %String) As %Status { Quit ..DeclarationCall("execution-detail",run) }
ClassMethod DeclarationMonitorDetail(run As %String) As %Status { Quit ..DeclarationCall("monitor-detail",run) }
ClassMethod DeclarationMonitorPlan(run As %String) As %Status { Quit ..DeclarationCall("monitor-plan",run) }
ClassMethod DeclarationMonitorAuthorize() As %Status { Quit ..DeclarationCall("monitor-authorize") }
ClassMethod DeclarationMonitorAction() As %Status { Quit ..DeclarationCall("monitor-action") }

ClassMethod RouteReviews() As %Status
{
    Try { Set result=##class(Contest.RouteReview).List($Get(%request.Data("after",1))) }
    Catch ex {
        Do ##class(Contest.KnowledgeService).Audit("route.review.list.failed","",ex.DisplayString())
        Return ..Failure("route_review_failed","Unable to list route reviews","403 Forbidden")
    }
    Quit ..Reply(result)
}

ClassMethod RouteReviewDetail(id As %String) As %Status
{
    Try { Set result=##class(Contest.RouteReview).Detail(id) }
    Catch ex {
        Do ##class(Contest.KnowledgeService).Audit("route.review.read.failed",id,ex.DisplayString())
        Return ..Failure("route_review_failed","Unable to read route review","403 Forbidden")
    }
    Quit ..Reply(result)
}

ClassMethod RouteReviewAction() As %Status
{
    If '$System.Security.Check("ContestMonitorDeploy","U") Quit ..Failure("forbidden","Route action permission required","403 Forbidden")
    Try { Set body={}.%FromJSON(%request.Content) }
    Catch ex { Return ..Failure("invalid_json","Invalid JSON body","400 Bad Request") }
    Try { Set result=##class(Contest.RouteReview).Action(body) }
    Catch ex {
        Do ##class(Contest.KnowledgeService).Audit("route.review.action.rejected","",ex.DisplayString())
        Return ..Failure("route_review_rejected","Action rejected; refresh and check the exact event revision/transition","409 Conflict")
    }
    Quit ..Reply(result)
}

ClassMethod MonitorCall(action As %String, id As %String = "") As %Status
{
    If '$System.Security.Check("ContestMonitorRead","U") Quit ..Failure("forbidden","Monitor read permission required","403 Forbidden")
    Try {
        If (action = "instances") || (action = "pipelines") {
            Set result = $Select(action = "instances":##class(Contest.MonitorService).Instances(),1:##class(Contest.MonitorService).Pipelines())
        } Else {
            If '$System.Security.Check("ContestMonitorDeploy","U") Return ..Failure("forbidden","Demo deployment permission required","403 Forbidden")
            Try { Set body = {}.%FromJSON(%request.Content) }
            Catch ex { Return ..Failure("invalid_json","Invalid JSON body","400 Bad Request") }
            If 'body.%IsA("%DynamicObject") Return ..Failure("invalid_body","JSON object required","400 Bad Request")
            If action = "discover" {
                If body.%Size() '= 0 Return ..Failure("invalid_body","No namespace or endpoint parameters accepted","400 Bad Request")
                Set result = ##class(Contest.MonitorService).Discover()
            } ElseIf action = "plan" {
                If (body.%Size() '= 1) || (body.%GetTypeOf("snapshot_id") '= "string") Return ..Failure("invalid_body","Only snapshot_id is accepted","400 Bad Request")
                Set result = ##class(Contest.MonitorService).Plan(body.%Get("snapshot_id"))
            } ElseIf action = "summary" {
                If (body.%Size() '= 2) || (body.%GetTypeOf("snapshot_id") '= "string") || (body.%GetTypeOf("acknowledge_cost") '= "boolean") || 'body.%Get("acknowledge_cost") Return ..Failure("cost_confirmation","Confirm one real model invocation for a specific snapshot","400 Bad Request")
                Set summaryId = ##class(Contest.PipelineSummary).Start(body.%Get("snapshot_id"))
                Set result = ##class(Contest.PipelineSummary).Status(summaryId)
            } ElseIf (action = "approve") || (action = "apply") {
                If (body.%Size() '= 1) || (body.%GetTypeOf("digest") '= "string") Return ..Failure("invalid_body","Only the exact plan digest is accepted","400 Bad Request")
                Set result = ##class(Contest.MonitorService).Transition(id,body.digest,action="apply")
            } ElseIf action = "message" {
                If (body.%Size() '= 1) || (body.%GetTypeOf("scenario") '= "string") Return ..Failure("invalid_body","Only a synthetic scenario is accepted","400 Bad Request")
                If '##class(Contest.MonitorService).ValidScenario(body.scenario) Return ..Failure("invalid_scenario","Choose treatment, analytics or failure","400 Bad Request")
                Set result = ##class(Contest.MonitorService).Remote("messages",{"scenario":(body.scenario),"key":("manual-"_$System.Util.CreateGUID())})
                Do ##class(Contest.KnowledgeService).Audit("demo.message",result.%Get("message_id"),body.scenario)
            } ElseIf action = "transport" {
                If (body.%Size() '= 1) || (body.%GetTypeOf("paused") '= "boolean") Return ..Failure("invalid_body","Only paused boolean is accepted","400 Bad Request")
                Set ^ContestMonitor("receiverPaused") = body.paused, result = {"paused":(body.paused)}
                Do ##class(Contest.KnowledgeService).Audit("demo.receiver",body.paused)
            } Else {
                Return ..Failure("not_found","Unknown monitor operation","404 Not Found")
            }
        }
        Return ..Reply(result)
    } Catch ex {
        Do ##class(Contest.KnowledgeService).Audit("monitor."_action_".failed",id,ex.DisplayString())
        If (ex.DisplayString() [ "Snapshot is stale") || (ex.DisplayString() [ "plan is stale") Return ..Failure("stale_plan","Production or observer baseline changed. Refresh discovery and create a new plan.","409 Conflict")
        Return ..Failure("monitor_operation_failed","Monitor operation failed; check Connector health, rediscover stale plans, or inspect protected audit","409 Conflict")
    }
}

ClassMethod Instances() As %Status { Quit ..MonitorCall("instances") }
ClassMethod Pipelines() As %Status { Quit ..MonitorCall("pipelines") }
ClassMethod Discover() As %Status { Quit ..MonitorCall("discover") }
ClassMethod Plan() As %Status { Quit ..MonitorCall("plan") }
ClassMethod Approve(id As %String) As %Status { Quit ..MonitorCall("approve",id) }
ClassMethod Apply(id As %String) As %Status { Quit ..MonitorCall("apply",id) }
ClassMethod DemoMessage() As %Status { Quit ..MonitorCall("message") }
ClassMethod DemoTransport() As %Status { Quit ..MonitorCall("transport") }
ClassMethod PipelineSummary() As %Status { Quit ..MonitorCall("summary") }
}
