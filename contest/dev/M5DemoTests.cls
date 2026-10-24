Class Contest.M5DemoTests Extends %UnitTest.TestProduction
{
Parameter PRODUCTION = "Contest.Production";
Method TestControl() As %Status { Quit $$$OK }

Method TestFixedScopeAndPayload()
{
    Do $$$AssertEquals(##class(Contest.M5Demo).ProductionId(),##class(Contest.ProductionMonitor).Key("M5OBSERVATION","Contest.M5.Production"))
    Set payload=##class(Contest.M5Demo).Payload()
    Set facts=##class(Contest.ProductionEvidence).Inspect(payload,"json-object")
    Do $$$AssertTrue(facts.%Get("identifier_present"))
    Do $$$AssertEquals(facts.dates.%Get("full_date"),1)
    Do $$$AssertEquals(facts.%Get("export_context").method,"safe_harbor")
    Do $$$AssertTrue(facts.%ToJSON()'["SYNTHETIC-DEMO-NAME","Model facts exclude actual identifier values")
}

Method TestFrozenProfilePacket()
{
    Set profiles={}, presets=##class(Contest.OrganizationCatalog).Presets()
    For i=0:1:presets.%Size()-1 {
        Set p=presets.%Get(i)
        If (p.id'="hospital")&&(p.id'="research") Continue
        Do profiles.%Set(p.id,{"id":(p.id),"revision":1,"profile":(p),"hash":(##class(Contest.ExportEvidence).Digest(p)),"confirmed_by":"test","confirmed_at":1})
    }
    Set run={"id":"m5-demo-test","state":"delivered","profiles":(profiles),"config_hash":"test-config","message_id":"123","session_id":"456","payload_hash":"test-payload"}
    Set value={"production_id":(..ProductionId()),"namespace":"M5OBSERVATION","production":"Contest.M5.Production","observed_config_hash":"test-config","header":{"body_class":"Contest.M5.Request","body_id":"123","session_id":"456","source":"ProcessB","target":"ReceiverB"},"capture":{"state":"captured","body_digest":"test-payload","facts":(##class(Contest.ProductionEvidence).Inspect(##class(Contest.M5Demo).Payload(),"json-object"))}}
    Set packet=##class(Contest.M5Demo).BuildPacket(value,run), facts=##class(Contest.RiskReview).Facts(packet)
    Do $$$AssertTrue(facts.%IsDefined("organization_profiles"),"Frozen source and recipient profiles reach the model")
    Do $$$AssertTrue(facts.%Get("org_research_profile").text["Safe Harbor")
    Do $$$AssertEquals(packet.%Get("required_questions").%Get(0).topic,"deidentification")
    Do $$$AssertTrue(packet.%ToJSON()'["SYNTHETIC-DEMO-NAME")
    For mode="message","session","profile","config","payload" {
        Set changed={}.%FromJSON(value.%ToJSON()), saved={}.%FromJSON(run.%ToJSON()), rejected=0
        If mode="message" Do changed.header.%Set("body_id","999")
        If mode="session" Do changed.header.%Set("session_id","999")
        If mode="profile" Do saved.profiles.research.profile.%Set("purpose","tampered")
        If mode="config" Do changed.%Set("observed_config_hash","other")
        If mode="payload" Do changed.capture.%Set("body_digest","other")
        Try { Set ignored=##class(Contest.M5Demo).BuildPacket(changed,saved) } Catch ex { Set rejected=1 }
        Do $$$AssertTrue(rejected,"Reject changed "_mode_" binding")
    }
}

Method ProductionId() As %String { Quit ##class(Contest.M5Demo).ProductionId() }

Method TestInvalidMutationsAreRejectedBeforeStateChanges()
{
    If '$System.Security.Check("ContestMonitorDeploy","U") Quit
    Set before=$Data(^ContestM5Demo("profile")), rejected=0
    Try { Set ignored=##class(Contest.M5Demo).Reset({"confirmation":"RESET EVERYTHING","config_hash":"wrong"}) } Catch ex { Set rejected=1 }
    Do $$$AssertTrue(rejected,"Reset requires exact M5-only confirmation")
    Set rejected=0
    Try { Set ignored=##class(Contest.M5Demo).Reset({"confirmation":"RESET M5 DEMO","config_hash":"wrong"}) } Catch ex { Set rejected=1 }
    Do $$$AssertTrue(rejected,"Reset requires current fixed Production configuration")
    Set p=##class(Contest.OrganizationCatalog).Presets().%Get(1), rejected=0
    Try { Set ignored=##class(Contest.M5Demo).ProfileSave({"profile":(p),"expected_revision":0,"confirmed":true}) } Catch ex { Set rejected=1 }
    Do $$$AssertTrue(rejected,"Unrelated organization cannot enter the fixed demo catalog")
    Do $$$AssertEquals($Data(^ContestM5Demo("profile")),before,"Rejected operations do not clear profiles")
}
}
