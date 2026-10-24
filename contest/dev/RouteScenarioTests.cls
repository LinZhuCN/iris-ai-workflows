Class Contest.RouteScenarioTests Extends %UnitTest.TestProduction
{
Parameter PRODUCTION = "Contest.Production";
Method TestControl() As %Status { Quit $$$OK }

Method TestInternalPathsDoNotRequireDeidentification()
{
    For kind="aggregation","utilization" {
        Set declaration={"kind":(kind),"purpose_code":($Select(kind="aggregation":"internal-consolidation",1:"internal-quality-improvement")),"recipient":($Select(kind="aggregation":"local-fhir-center",1:"local-analysis-receiver")),"service_identity":($Select(kind="aggregation":"ContestAggregationFHIR",1:"local-utilization-service"))}
        Set scenario=##class(Contest.RouteScenario).ForDeclaration(declaration)
        Do $$$AssertTrue(scenario.synthetic)
        Do $$$AssertEquals(scenario.%Get("organization_id"),"DEMO-HOSPITAL")
        Do $$$AssertEquals(scenario.%Get("deidentification_required"),0)
        Do $$$AssertEquals(scenario.%Get("individual_authorization_required"),0)
        Do $$$AssertEquals(scenario.%Get("recipient_relationship"),"same-covered-entity")
        Do ##class(Contest.RouteScenario).Validate(declaration,scenario)
        Set changed={}.%FromJSON(scenario.%ToJSON()), rejected=0
        Do changed.%Set("organization_id","different")
        Try { Do ##class(Contest.RouteScenario).Validate(declaration,changed) } Catch ex { Set rejected=1 }
        Do $$$AssertTrue(rejected,"A rehashed arbitrary scenario is not organization policy")
    }
}

Method TestUnregisteredPurposeCannotSelectPolicy()
{
    Set declaration={"kind":"utilization","purpose_code":"commercial-export","recipient":"local-analysis-receiver","service_identity":"local-utilization-service"}
    Do $$$AssertEquals(##class(Contest.RouteScenario).ForDeclaration(declaration),"")
    Do declaration.%Set("purpose_code","internal-quality-improvement")
    Set declaration.recipient="external-buyer", rejected=0
    Try { Set scenario=##class(Contest.RouteScenario).ForDeclaration(declaration) } Catch ex { Set rejected=1 }
    Do $$$AssertTrue(rejected,"A purpose code cannot authorize an unregistered recipient")
}

Method TestApprovalBindsPolicyAndPurposeRemainsClaim()
{
    If '$System.Security.Check("ContestMonitorDeploy","U") Quit
    Set template=##class(Contest.RouteUI).Template(), now=##class(Demo.Protocol).Now()\1
    Do template.declaration.%Set("route_id","unit-scenario")
    TStart
    Try {
        Kill ^ContestRouteGovernance("revision","unit-scenario")
        Set dossier=##class(Contest.RouteGovernance).Register(template.declaration,template.binding,now-10,now+86400)
        Do $$$AssertEquals(dossier.approval,"","Registration alone is not policy approval")
        Set approved=##class(Contest.RouteGovernance).Approve(dossier.id,dossier.digest)
        Do $$$AssertTrue($IsObject(approved.approval.%Get("scenario")))
        Do $$$AssertEquals(approved.approval.scenario.%Get("policy_id"),"DEMO-INTERNAL-USE-1")
        Do $$$AssertEquals(approved.approval.%Get("scope_hash"),dossier.digest)
    } Catch ex { TRollback 1 Throw ex }
    TRollback 1
}

Method TestDeliveredEvidenceUsesScopedQuestions()
{
    If '$System.Security.Check("ContestMonitorDeploy","U") Quit
    For kind="aggregation","utilization" {
        Set batch=$Select(kind="aggregation":"aggregation-internal-demo",1:"utilization-quality-demo")
        Set raw=$Select(kind="aggregation":^|"PIPELINE"|ContestAggregation("batch",batch),1:^|"UTILIZATION"|ContestUtilization("batch",batch))
        Set record={}.%FromJSON(raw), evidence=##class(Contest.RouteEvidence).Read(kind,batch,record.receipt.%Get("receipt_hash")).evidence
        Do $$$AssertEquals(evidence.adapter,"route-evidence-v2")
        Do $$$AssertEquals(evidence.packet.facts.%Size(),8)
        Do $$$AssertEquals(evidence.packet.facts.%Get(0).kind,"claim","Submitted purpose is not silently upgraded")
        Do $$$AssertEquals(evidence.packet.facts.%Get(7).id,"approved_scenario")
        Do $$$AssertEquals(evidence.packet.facts.%Get(7).kind,"observation")
        Do $$$AssertEquals(evidence.packet.%Get("required_questions").%Size(),1,"No mandatory de-identification investigation")
        Do $$$AssertEquals(evidence.packet.%Get("required_questions").%Get(0).topic,"recipient_purpose")
        Do $$$AssertEquals(evidence.approved.scenario.%Get("deidentification_required"),0)
    }

}

Method TestResetRejectsStalePlanWithoutDeletingData()
{
    If '$System.Security.Check("%Admin_Manage","U") Quit
    Set before=##class(Contest.RouteDemo).Plan(), rejected=0
    Try { Do ##class(Contest.RouteDemo).Reset("stale") } Catch ex { Set rejected=(ex.DisplayString()["Reset plan changed") }
    Do $$$AssertTrue(rejected)
    Do $$$AssertEquals(##class(Contest.RouteDemo).Plan().%ToJSON(),before.%ToJSON())
}

Method TestOutputRetestCannotReplenishBudget()
{
    If '$System.Security.Check("%Admin_Manage","U") Quit
    Lock +^ContestRouteReview("worker"):10
    If '$Test Do ##class(Demo.Protocol).Fail("Worker busy; free fixture not run")
    TStart
    Try {
        Set key="utilization-utilization-quality-demo-consumed", original=$Get(^ContestRouteReview("allow","utilization-utilization-quality-demo"))
        Set ^ContestRouteReview("allow",key)={"reserved":true}.%ToJSON(), rejected=0
        Try { Do ##class(Contest.RouteDemo).ReplaceFailedUtilization() } Catch ex { Set rejected=(ex.DisplayString()["One explicitly authorized output retest only") }
        Do $$$AssertTrue(rejected)
        Do $$$AssertEquals($Get(^ContestRouteReview("allow","utilization-utilization-quality-demo")),original,"No replenished allowance")
    } Catch ex {
        TRollback 1
        Lock -^ContestRouteReview("worker")
        Throw ex
    }
    TRollback 1
    Lock -^ContestRouteReview("worker")
}
}
