Class Contest.RouteDemo
{
ClassMethod Access()
{
    If ($Namespace'="TRIAGE")||('$System.Security.Check("ContestMonitorDeploy","U"))||('$System.Security.Check("%Admin_Manage","U")) Do ##class(Demo.Protocol).Fail("Local route demo administration required")
}

ClassMethod Plan() As %DynamicObject
{
    Do ..Access()
    Set records=[], batches=[], id=""
    For {
        Set id=$Order(^ContestRouteGovernance("record",id))
        If id="" Quit
        Set record=##class(Contest.RouteGovernance).Read(id), route=record.core.declaration.%Get("route_id")
        If (route'="synthetic-sql-fhir-aggregation")&&(route'="synthetic-fhir-analysis")&&(route'="demo-analysis-onboarding")&&(route'="demo-quality-improvement") Do ##class(Demo.Protocol).Fail("Unexpected route registration; reset refused")
        If record.core.binding.%Get("instance_id")'="local-triage-real" Do ##class(Demo.Protocol).Fail("Foreign route instance; reset refused")
        Do records.%Push({"id":(id),"route_id":(route),"revision":(record.core.declaration.revision)})
    }
    For kind="aggregation","utilization" {
        Set batch=""
        For {
            Set batch=$Select(kind="aggregation":$Order(^|"PIPELINE"|ContestAggregation("batch",batch)),1:$Order(^|"UTILIZATION"|ContestUtilization("batch",batch)))
            If batch="" Quit
            If '$Match(batch,"^"_kind_"-[A-Za-z0-9-]{1,50}$") Do ##class(Demo.Protocol).Fail("Unexpected route batch; reset refused")
            Set raw=$Select(kind="aggregation":^|"PIPELINE"|ContestAggregation("batch",batch),1:^|"UTILIZATION"|ContestUtilization("batch",batch)), row={}.%FromJSON(raw), found=0
            If (row.state="running")||(row.state="prepared") Do ##class(Demo.Protocol).Fail("In-flight route batch; reset refused")
            For i=0:1:records.%Size()-1 {
                If records.%Get(i).id=row.%Get("approval_id") Set found=1
            }
            If 'found Do ##class(Demo.Protocol).Fail("Batch outside selected demo registrations; reset refused")
            Do batches.%Push({"kind":(kind),"batch":(batch)})
        }
    }
    Quit {"records":(records),"batches":(batches),"model_calls":0}
}

ClassMethod Reset(expected As %String)
{
    Do ..Access()
    Lock +^ContestRouteReview("worker"):10
    If '$Test Do ##class(Demo.Protocol).Fail("Route worker active; reset refused")
    Set previous=$Namespace
    Try {
        Set plan=..Plan()
        If expected'=##class(Contest.ExportEvidence).Digest(plan) Do ##class(Demo.Protocol).Fail("Reset plan changed; inspect again")
        Set keys={}, reportIds=[], key=""
        For i=0:1:plan.batches.%Size()-1 {
            Set row=plan.batches.%Get(i)
            Do keys.%Set(row.kind_"-"_row.batch,1)
        }
        For {
            Set key=$Order(^ContestRouteReview("review",key))
            If key="" Quit
            Set item={}.%FromJSON(^ContestRouteReview("review",key))
            If ('keys.%IsDefined(item.%Get("route_kind")_"-"_item.%Get("batch_id")))||(item.state="running") Do ##class(Demo.Protocol).Fail("Unexpected or running review; reset refused")
            If item.%IsDefined("report_id") Do reportIds.%Push(item.%Get("report_id"))
        }
        TStart
        Try {
            Set ^ContestRouteReview("enabled")=0
            For i=0:1:reportIds.%Size()-1 {
                Set id=reportIds.%Get(i), report=##class(Contest.RiskReviewV4).Status(id)
                Kill ^ContestRiskReview("request",report.authorization.%Get("request_key")), ^ContestRiskReview("report",id)
            }
            For node="review","allow","pin","acceptance","targets","config","heartbeat","observerIdentity","nextTick","lastError" {
                Kill ^ContestRouteReview(node)
            }
            For i=0:1:plan.batches.%Size()-1 {
                Set row=plan.batches.%Get(i)
                If row.kind="aggregation" {
                    Kill ^|"PIPELINE"|ContestAggregation("batch",row.batch)
                } Else {
                    Set $Namespace="UTILIZATION"
                    Set result=##class(%SQL.Statement).%ExecDirect(,"DELETE FROM SQLUser.UtilizationReceipt WHERE BatchID=?",row.batch)
                    Do ##class(Contest.Aggregation.Data).Check(result)
                    Set $Namespace="TRIAGE"
                    Kill ^|"UTILIZATION"|ContestUtilization("batch",row.batch)
                }
            }
            For i=0:1:plan.records.%Size()-1 {
                Set row=plan.records.%Get(i)
                Kill ^ContestRouteGovernance("record",row.id), ^ContestRouteGovernance("approval",row.id), ^ContestRouteGovernance("revision",row.%Get("route_id"),row.revision)
            }
            Kill ^|"PIPELINE"|ContestAggregation("approvalRef"), ^|"UTILIZATION"|ContestUtilization("registration")
            Do ##class(Contest.KnowledgeService).Audit("route.demo.reset","internal-use-demo","User-approved replacement of route demo data; other workflows and engine logs untouched")
            TCommit
        } Catch ex { TRollback 1 Throw ex }
    } Catch ex {
        Set $Namespace=previous
        Lock -^ContestRouteReview("worker")
        Do ##class(Contest.KnowledgeService).Audit("route.demo.reset.failed","internal-use-demo",ex.DisplayString())
        Throw ex
    }
    Set $Namespace=previous
    Lock -^ContestRouteReview("worker")
}

ClassMethod ReplaceFailedUtilization()
{
    Do ..Access()
    Lock +^ContestRouteReview("worker"):10
    If '$Test Do ##class(Demo.Protocol).Fail("Route worker active; replacement refused")
    Try {
        Set key="utilization-utilization-quality-demo", consumed=key_"-consumed"
        If $Data(^ContestRouteReview("allow",consumed)) Do ##class(Demo.Protocol).Fail("One explicitly authorized output retest only; no automatic retries")
        Set item=##class(Contest.RouteReview).Detail(key)
        If (item.state'="failed")||('item.%IsDefined("report_id")) Do ##class(Demo.Protocol).Fail("Only a terminal failed utilization review can be replaced")
        Set old=##class(Contest.RiskReviewV4).Status(item.%Get("report_id")), grant={}.%FromJSON(^ContestRouteReview("allow",key))
        If (old.state'="failed")||(old.%Get("reserved_model_requests")'=2)||('grant.reserved)||(grant.%Get("authorization_id")'="internal-use-demo") Do ##class(Demo.Protocol).Fail("Expected consumed two-phase original review required")
        Set evidence=##class(Contest.RouteEvidence).Read("utilization",item.%Get("batch_id"),item.%Get("receipt_hash")).evidence
        If evidence.%Get("evidence_hash")'=item.evidence.%Get("evidence_hash") Do ##class(Demo.Protocol).Fail("Evidence changed; replacement refused")
        Set config={}.%FromJSON(grant.config.%ToJSON())
        Do config.%Set("contract_hash",##class(Contest.RiskReviewV4).ContractHash())
        Set source=##class(Contest.AgentService).Get(config.%Get("agent_id"))
        If (source.model'="deepseek-flash")||(source.revision'=config.%Get("source_revision"))||(source.%Get("config_hash")'=config.%Get("config_hash"))||('##class(Contest.PrivacyEvaluation).Eligible(source)) Do ##class(Demo.Protocol).Fail("Pinned eligible source Agent required")
        Set replacement={"receipt_hash":(item.%Get("receipt_hash")),"reserved":false,"actor":($Username),"authorized_at":(##class(Demo.Protocol).Now()),"max_model_requests":2,"runtime_version":"staged-risk-v4","config":(config),"authorization_id":"utilization-output-retest"}
        Set usage=[]
        For i=0:1:old.phases.%Size()-1 {
            Set phase=old.phases.%Get(i)
            If phase.%IsDefined("sdk_stats") Do usage.%Push(phase.%Get("sdk_stats"))
        }
        Do grant.%Set("consumed_sdk_stats",usage)
        For field="report_id","actual_model_requests","phases","completed","error","failure","sources" Do item.%Remove(field)
        Set item.state="blocked_budget", item.event={"category":"coverage_gap","state":"open","revision":1,"actions":[]}, item.trigger="explicit_output_retest"
        Do item.%Set("authorization_id","utilization-output-retest"), item.%Set("reserved_model_requests",0), item.%Set("previous_model_requests",2)
        TStart
        Try {
            Set ^ContestRouteReview("allow",consumed)=grant.%ToJSON(), ^ContestRouteReview("allow",key)=replacement.%ToJSON(), ^ContestRouteReview("review",key)=item.%ToJSON()
            Kill ^ContestRiskReview("request",old.authorization.%Get("request_key")), ^ContestRiskReview("report",old.id)
            Do ##class(Contest.KnowledgeService).Audit("route.demo.output_retest",key,"Explicit two-request consent; replace rejected output, retain consumed budget counters; no new delivery")
            TCommit
        } Catch ex { TRollback 1 Throw ex }
    } Catch ex {
        Lock -^ContestRouteReview("worker")
        Do ##class(Contest.KnowledgeService).Audit("route.demo.output_retest.failed","utilization-quality-demo",ex.DisplayString())
        Throw ex
    }
    Lock -^ContestRouteReview("worker")
}
}
