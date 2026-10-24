Class Contest.ProductionPremiseTests Extends %UnitTest.TestProduction
{
Parameter PRODUCTION = "Contest.Production";
Method TestControl() As %Status { Quit $$$OK }

Method Premises() As %DynamicObject
{
    Quit {"session_id":"900001000","recipient":"Demo clinic","relationship":"another_provider","purpose":"Treating the referred patient.","permission_basis":"treatment","permission_details":"Ordinary patient data for treatment; not psychotherapy notes. No special restriction is stipulated.","authorization_status":"not_relied_upon","safeguards":"Only the treating provider has access.","exceptions":"No special-category restriction applies in this scenario.","confirmed":true}
}

Method TestObservedExportDeclarationAndPayloadAreCompared()
{
    Set context={"schema":1,"synthetic":true,"purpose":"external_statistics","recipient":"external_analytics","method":"safe_harbor","processing_status":"deidentified"}
    Set bad={"export_context":(context),"name":"SYNTHETIC-NEVER-EXPORT","mrn":"SYNTHETIC-MRN","birthDate":"2001-02-03","status":"finished"}
    Set clean={"export_context":(context),"birthDate":"2001","status":"finished"}
    For mode="bad","clean" {
        Set inspection=##class(Contest.ProductionEvidence).Inspect($Select(mode="bad":bad,1:clean),"json-object")
        Do $$$AssertTrue(inspection.%IsDefined("export_context"),"Read declared export context from the actual message, not approval text")
        If 'inspection.%IsDefined("export_context") Continue
        Do $$$AssertEquals(inspection.%Get("export_context").%ToJSON(),context.%ToJSON(),"Retain the same neutral declaration for both cases")
        Do $$$AssertEquals(inspection.%Get("unknown_fields"),0)
        Do $$$AssertEquals(inspection.%Get("identifier_present"),mode="bad")
        Do $$$AssertEquals(inspection.dates.%Get("full_date"),mode="bad")
        Do $$$AssertTrue(inspection.%ToJSON()'["SYNTHETIC-NEVER-EXPORT","No name value sent to model")
        Do $$$AssertTrue(inspection.%ToJSON()'["SYNTHETIC-MRN","No medical-record-number value sent to model")
        Set value=##class(Contest.ProductionReviewTests).%New("").Observation(), value.capture.facts=inspection
        Set grant={"actor":"Demo approver","authorized_at":1,"definition":{"demo_premises":(..Premises())}}
        Set packet=##class(Contest.ProductionReview).Packet(value,[],.business,grant), facts=##class(Contest.RiskReview).Facts(packet)
        Do $$$AssertEquals(packet.%Get("required_questions").%Get(0).topic,"deidentification")
        Do $$$AssertTrue(facts.%IsDefined("observed_export_context"),"Message declaration separately grounded from observed field inventory")
        Do $$$AssertTrue(packet.%ToJSON()'["risk_signal","Input does not contain the expected answer")
    }
    For mode="extra","wrong_method","nonsynthetic" {
        Set payload={}.%FromJSON(clean.%ToJSON()), rejected=0
        If mode="extra" Do payload.%Get("export_context").%Set("verdict","risk")
        If mode="wrong_method" Do payload.%Get("export_context").%Set("method","invented")
        If mode="nonsynthetic" Do payload.%Get("export_context").%Set("synthetic",0,"boolean")
        Try { Set ignored=##class(Contest.ProductionEvidence).Inspect(payload,"json-object") } Catch ex { Set rejected=1 }
        Do $$$AssertTrue(rejected,"Reject invalid or answer-bearing export metadata: "_mode)
    }
}

Method TestApprovedDemoPremisesEnterPacketWithoutRealSystem()
{
    Set value=##class(Contest.ProductionReviewTests).%New("").Observation()
    Set grant={"actor":"Demo approver","authorized_at":1,"definition":{"demo_premises":(..Premises())}}
    Set packet=##class(Contest.ProductionReview).Packet(value,[],.business,grant), facts=##class(Contest.RiskReview).Facts(packet)
    Do $$$AssertTrue(facts.%IsDefined("approved_scenario"),"User approval supplies demo premises without an external system")
    Do $$$AssertTrue(facts.%IsDefined("demo_permission"),"Permission details reach legal reviewer")
    Do $$$AssertTrue(packet.%ToJSON()["Demo approver","Approval provenance is frozen")
    Do $$$AssertTrue(packet.%ToJSON()["not independently verified","Simulation must not claim real-world verification")
    Do $$$AssertTrue('facts.%IsDefined("business_context"),"Known demo premises are not automatically treated as missing")
    Do $$$AssertTrue(packet.%ToJSON()'["NEVER-EXPORT","Raw patient value still excluded")
    Do $$$AssertTrue('$IsObject(business),"Demo premise mode does not pretend to have receiver readback")
}

Method TestScopeAndUnknowns()
{
    Set value=##class(Contest.ProductionReviewTests).%New("").Observation(), p=..Premises()
    Set grant={"actor":"Demo approver","authorized_at":1,"definition":{"demo_premises":(p)}}
    Do $$$AssertTrue(##class(Contest.ProductionReview).MatchesPremises(value,grant))
    Do p.%Set("session_id","900001999")
    Do $$$AssertTrue('##class(Contest.ProductionReview).MatchesPremises(value,grant),"Premises do not leak to another message session")
    Set rejected=0
    Try { Set packet=##class(Contest.ProductionReview).Packet(value,[],.business,grant) } Catch ex { Set rejected=1 }
    Do $$$AssertTrue(rejected,"Mismatched premise scope cannot reach model")
    Do p.%Set("session_id","900001000"), p.%Set("relationship","unknown"), p.%Set("permission_basis","unknown"), p.%Set("authorization_status","unknown")
    Set packet=##class(Contest.ProductionReview).Packet(value,[],.business,grant), facts=##class(Contest.RiskReview).Facts(packet)
    Do $$$AssertEquals(facts.%Get("demo_recipient").kind,"missing_information")
    Do $$$AssertEquals(facts.%Get("demo_permission").kind,"missing_information","Unknown is not affirmative absence")
    Do p.%Set("confirmed",0,"boolean")
    Set rejected=0
    Try { Do ##class(Contest.ProductionReview).ValidatePremises(p) } Catch ex { Set rejected=1 }
    Do $$$AssertTrue(rejected,"Unconfirmed input cannot become approved premises")
    Do p.%Set("confirmed",1,"boolean"), p.%Set("invented_verdict","no_risk")
    Set rejected=0
    Try { Do ##class(Contest.ProductionReview).ValidatePremises(p) } Catch ex { Set rejected=1 }
    Do $$$AssertTrue(rejected,"Client cannot supply expected verdict or verification flags")
}

Method TestExplicitMessageMappingIsNotLost()
{
    Set value=##class(Contest.ProductionReviewTests).%New("").Observation(), p=..Premises()
    Do p.%Set("recipient_mapping","Source and Process are internal transport; Receiver represents the stated clinic.")
    Do p.%Set("data_scope","All data in this source session concern the referred synthetic patient and specified treatment.")
    Set grant={"actor":"Demo approver","authorized_at":1,"definition":{"demo_premises":(p)}}
    Set packet=##class(Contest.ProductionReview).Packet(value,[],.business,grant), facts=##class(Contest.RiskReview).Facts(packet)
    Do $$$AssertTrue(facts.%IsDefined("demo_message_scope"),"Approver's explicit message-to-business mapping reaches the model")
    Do $$$AssertTrue(facts.%Get("demo_message_scope").text["Receiver represents the stated clinic")
    Do $$$AssertTrue(facts.%Get("demo_message_scope").text["referred synthetic patient")
    Do $$$AssertEquals(facts.%Get("demo_message_scope").origin,"user_confirmed_demo_premise","Mapping is stipulated, not independently observed")
    Do p.%Set("data_scope","")
    Set rejected=0
    Try { Do ##class(Contest.ProductionReview).ValidatePremises(p) } Catch ex { Set rejected=1 }
    Do $$$AssertTrue(rejected,"Do not accept partial/empty mapping as established")
}

Method TestDemoPremisesCanSupportScopedLegalOutcomes()
{
    If '$System.Security.Check("ContestMonitorDeploy","U") Quit
    Lock +^ContestProductionReview("worker"):2
    If '$Test Do ##class(Demo.Protocol).Fail("Reviewer busy; isolated premise test refused")
    TStart
    Try {
        Set value=##class(Contest.ProductionReviewTests).%New("").Observation(), pid=value.%Get("production_id")
        Set current=##class(Contest.ProductionMonitor).Snapshot("OBSERVATION"), auth="unit-demo-premises"
        Set grant={"authorization_id":(auth),"actor":"Demo approver","authorized_at":1,"enabled":true,"definition":{"demo_premises":(..Premises()),"config_hash":(current.%Get("config_hash")),"expires_at":(##class(Demo.Protocol).Now()+60)}}
        Set ^ContestProductionReview("grant",pid,auth)=grant.%ToJSON()
        Set packet=##class(Contest.ProductionReview).Packet(value,[],.business,grant)
        Set questions=##class(Contest.ProductionReview).Questions(packet,{"questions":[]})
        Set packages=##class(Contest.RiskReviewTests).%New("").Packages(questions)
        Set ^ContestProductionReview("context",$Job)={"production_id":(pid),"authorization_id":(auth),"input_hash":(##class(Demo.Protocol).Hash(packet.%ToJSON()))}.%ToJSON()
        Set answer=##class(Contest.RiskReviewV4Tests).%New("").Answer(), issue=answer.issues.%Get(0)
        Do issue.%Set("fact_ids",["demo_recipient","demo_purpose","demo_permission"])
        Do issue.%Set("applicability_fact_ids",["demo_recipient","demo_purpose"]), issue.%Set("affirmative_fact_ids",["demo_permission"])
        Set result=##class(Contest.ProductionReview).Resolve(packet,questions,packages,answer)
        Do $$$AssertEquals(result.assessment,"risk_identified","Confirmed substantive demo premises can ground a scoped failed condition")
        Set issue.status="no_signal_on_checked_issue"
        Do issue.%Set("condition_status","met")
        Set result=##class(Contest.ProductionReview).Resolve(packet,questions,packages,answer)
        Do $$$AssertEquals(result.assessment,"no_signal_on_checked_issues","No forced unknown merely because the scenario is user-entered")
        Do $$$AssertEquals(result.summary.execution,"not_executed")
        Do $$$AssertTrue(result.%Get("human_review_required"))
        Set grant.enabled=0, ^ContestProductionReview("grant",pid,auth)=grant.%ToJSON(), rejected=0
        Try { Set ignored=##class(Contest.ProductionReview).Resolve(packet,questions,packages,answer) } Catch ex { Set rejected=1 }
        Do $$$AssertTrue(rejected,"Demo premises do not bypass revoked consent")
    } Catch ex { TRollback 1 Lock -^ContestProductionReview("worker") Throw ex }
    TRollback 1
    Lock -^ContestProductionReview("worker")
}

Method TestConsentFreezesPremisesAndServerProvenance()
{
    If '$System.Security.Check("ContestMonitorDeploy","U") Quit
    Lock +^ContestProductionReview("worker"):2
    If '$Test Do ##class(Demo.Protocol).Fail("Reviewer busy; isolated consent test refused")
    TStart
    Try {
        Set value=##class(Contest.ProductionReviewTests).%New("").Observation(), pid=value.%Get("production_id")
        Set plan=##class(Contest.ProductionReviewService).Plan(pid)
        If plan.%Get("eligible_agents").%Size()=0 Do ##class(Demo.Protocol).Fail("Published test reviewer required")
        Set agent=plan.%Get("eligible_agents").%Get(0)
        Set body={"authorization_id":"unit-demo-consent","production_id":(pid),"config_hash":(plan.%Get("config_hash")),"agent_id":(agent.id),"source_revision":(agent.revision),"agent_config_hash":(agent.%Get("config_hash")),"contract_hash":(plan.%Get("contract_hash")),"every_n":1,"max_reviews":1,"max_model_requests":2,"expires_at":((plan.now\1)+60),"include_existing":false,"acknowledge_cost":true,"acknowledge_synthetic_data_export":true,"demo_premises":(..Premises())}
        Set grant=##class(Contest.ProductionReviewService).Authorize(body)
        Do $$$AssertEquals(grant.actor,$Username,"Actor comes from authenticated server context")
        Do $$$AssertTrue(grant.%Get("authorized_at")>0)
        Do $$$AssertEquals(grant.definition.%Get("demo_premises").%ToJSON(),body.%Get("demo_premises").%ToJSON())
        Set same=##class(Contest.ProductionReviewService).Authorize(body)
        Do $$$AssertEquals(same.%ToJSON(),grant.%ToJSON(),"Same approval retry is idempotent")
        Set changed={}.%FromJSON(body.%ToJSON()), rejected=0
        Do changed.%Get("demo_premises").%Set("recipient","A different recipient")
        Try { Set ignored=##class(Contest.ProductionReviewService).Authorize(changed) } Catch ex { Set rejected=(ex.DisplayString()["Immutable authorization conflict") }
        Do $$$AssertTrue(rejected,"Confirmed premises cannot be edited under the same consent ID")
        Do $$$AssertEquals(grant.%Get("used_reviews"),0,"Saving premises alone does not reserve requests")
    } Catch ex { TRollback 1 Lock -^ContestProductionReview("worker") Throw ex }
    TRollback 1
    Lock -^ContestProductionReview("worker")
}
}
