Class Contest.DeclarationMonitorTests Extends %UnitTest.TestProduction
{
Parameter PRODUCTION = "Contest.Production";
Method TestControl() As %Status { Quit $$$OK }

Method TestObservationPacketAndGrant()
{
    Set facts=[
        {"id":"declared_purpose","kind":"claim","verification":"unverified","origin":"declaration","text":"Internal quality improvement"},
        {"id":"approved_scope","kind":"observation","verification":"verified","origin":"approval","text":"Exact approved scope"},
        {"id":"observed_output","kind":"observation","verification":"verified","origin":"receiver","text":"Four resources, seven fields"},
        {"id":"delivery_evidence","kind":"observation","verification":"verified","origin":"messages","text":"Delivered"},
        {"id":"approved_scenario","kind":"observation","verification":"verified","origin":"catalog","text":"Same simulated covered entity"},
        {"id":"evidence_limits","kind":"missing_information","verification":"unknown","origin":"coverage","text":"Later conduct not observed"}
    ]
    Set packet=##class(Contest.DeclarationMonitor).Packet(facts)
    Do $$$AssertEquals(packet.stage,"after_send")
    Do $$$AssertEquals(packet.%Get("required_questions").%Size(),1)
    Do ##class(Contest.RiskReviewV4).ValidatePacket(packet)
    Set item={"id":"unit","state":"blocked_budget","evidence_hash":"evidence","receipt_hash":"receipt"}, consent={"id":"unit","evidence_hash":"evidence","receipt_hash":"receipt","agent_id":"agent","source_revision":1,"config_hash":"config","contract_hash":"contract","max_model_requests":2,"acknowledge_cost":false}
    Set rejected=0
    Try { Do ##class(Contest.DeclarationMonitor).ValidateConsent(consent,consent) } Catch ex { Set rejected=1 }
    Do $$$AssertTrue(rejected,"Read-only planning cannot authorize calls")
    Do consent.%Set("acknowledge_cost",1,"boolean")
    Do ##class(Contest.DeclarationMonitor).ValidateConsent(consent,consent)
    Set wrong={}.%FromJSON(consent.%ToJSON())
    Do wrong.%Set("receipt_hash","other")
    Set rejected=0
    Try { Do ##class(Contest.DeclarationMonitor).ValidateConsent(wrong,consent) } Catch ex { Set rejected=1 }
    Do $$$AssertTrue(rejected,"Receipt change cannot use an earlier grant")
}

Method TestEventActionsCannotReplay()
{
    If '$System.Security.Check("ContestMonitorDeploy","U") Quit
    TStart
    Try {
        Set id="declaration-run-unit-"_$System.Util.CreateGUID(), item={"id":(id),"state":"blocked_budget","event":{"state":"open","revision":1,"actions":[]}}
        Set ^ContestDeclarationMonitor("review",id)=item.%ToJSON()
        Set changed=##class(Contest.DeclarationMonitor).Action({"id":(id),"revision":1,"action":"in_review","text":"Inspect synthetic receipt"})
        Do $$$AssertEquals(changed.event.state,"in_review")
        Do $$$AssertEquals(changed.event.revision,2)
        Set rejected=0
        Try { Set ignored=##class(Contest.DeclarationMonitor).Action({"id":(id),"revision":1,"action":"resolved","text":"Stale action"}) } Catch ex { Set rejected=1 }
        Do $$$AssertTrue(rejected,"Optimistic event revision prevents stale actions")
        Set changed=##class(Contest.DeclarationMonitor).Action({"id":(id),"revision":2,"action":"resolved","text":"Reviewed without delivery or inference"})
        Do $$$AssertEquals(changed.event.actions.%Size(),2)
        Do $$$AssertEquals(changed.state,"blocked_budget","Human resolution never invents an AI review")
    } Catch ex { TRollback 1 Throw ex }
    TRollback 1
}

Method TestEvidenceFailureCannotBecomeApproval()
{
    If '$System.Security.Check("ContestMonitorDeploy","U") Quit
    TStart
    Try {
        Set id="declaration-run-unit-"_$System.Util.CreateGUID(), item={"id":(id),"state":"evidence_failed","error":"Synthetic capture failure","evidence":{"evidence_hash":"changed"},"evidence_hash":"original","report_id":"","event":{"state":"open","revision":1,"actions":[]}}
        Set ^ContestDeclarationMonitor("review",id)=item.%ToJSON(), rejected=0
        Try { Set value=##class(Contest.DeclarationMonitor).Detail(id) } Catch ex { Set rejected=1 }
        Do $$$AssertTrue(rejected,"Tampered captured evidence is not silently displayed")
        Do item.%Remove("evidence")
        Set ^ContestDeclarationMonitor("review",id)=item.%ToJSON(), rejected=0
        Try { Set value=##class(Contest.DeclarationMonitor).Plan(id) } Catch ex { Set rejected=1 }
        Do $$$AssertTrue(rejected,"Evidence failure cannot be funded as an AI assessment")
        Set rejected=0
        Try { Set value=##class(Contest.DeclarationMonitor).Action({"id":(id),"revision":1,"action":"delivered","text":"No replay allowed"}) } Catch ex { Set rejected=1 }
        Do $$$AssertTrue(rejected,"Event mutation cannot execute delivery")
    } Catch ex { TRollback 1 Throw ex }
    TRollback 1
}
}
