Class Contest.ProductionBusinessTests Extends %UnitTest.TestProduction
{
Parameter PRODUCTION = "Contest.Production";
Method TestControl() As %Status { Quit $$$OK }

Method TestHeaderBoundaryPreserved()
{
    Set value=##class(Contest.ProductionReviewTests).%New("").Observation()
    Set packet=##class(Contest.ProductionReview).Packet(value,[])
    Do $$$AssertEquals(##class(Contest.RiskReview).Facts(packet).%Get("business_context").kind,"missing_information")
    Do $$$AssertTrue('##class(Contest.ProductionBusinessEvidence).Supports(value),"Unregistered Production has no business adapter")
}

Method TestBusinessPacketRequiresBoundEvidence()
{
    Set value=##class(Contest.ProductionReviewTests).%New("").Observation(), rejected=0
    Set value.namespace="M5OBSERVATION", value.production="Contest.M5.Production"
    Do value.header.%Set("body_class","Contest.M5.Request")
    Try { Set packet=##class(Contest.ProductionReview).BusinessPacket(value) } Catch ex { Set rejected=1 }
    Do $$$AssertTrue(rejected,"Fabricated adapter identity cannot bypass persisted evidence binding")
}

Method TestPolicyIsNotModelVerdict()
{
    Set rule=##class(Contest.ProductionBusinessEvidence).Policy()
    Do $$$AssertEquals(rule.version,"synthetic-quality-intake-v1")
    Do $$$AssertTrue(rule.%ToJSON()["year-only","Explicit local minimization rule")
    Do $$$AssertTrue(rule.%ToJSON()["not legal certification","Scope boundary explicit")
    Do $$$AssertTrue('rule.%IsDefined("assessment"),"Policy never stores expected AI answer")
}

Method TestScenarioCannotBypassJobGuard()
{
    Set fixture=##class(Contest.RiskReviewTests).%New(""), packet=fixture.Packet(), packet.stage="after_send"
    Do packet.facts.%Push({"id":"approved_scenario","kind":"observation","verification":"verified","origin":"untrusted_fixture","text":"A caller cannot grant itself established business review."})
    Set questions=##class(Contest.RiskReviewV4).Questions(packet,fixture.Plan()), packages=fixture.Packages(questions)
    Set answer=##class(Contest.RiskReviewV4Tests).%New("").Answer(), issue=answer.issues.%Get(0), issue.status="no_signal_on_checked_issue"
    Do issue.%Set("condition_status","met")
    Set rejected=0
    Try { Set result=##class(Contest.ProductionReview).Resolve(packet,questions,packages,answer) } Catch ex { Set rejected=(ex.DisplayString()["job-bound collector authorization") }
    Do $$$AssertTrue(rejected,"Even a well-formed fabricated scenario cannot bypass collector job authorization")
}

Method TestPersistedBindingAndMinimization()
{
    If '$System.Security.Check("ContestMonitorDeploy","U") Quit
    Set pid=##class(Contest.ProductionMonitor).Key("M5OBSERVATION","Contest.M5.Production"), header="", count=0
    For {
        Set header=$Order(^ContestProductionEvidence("record",pid,header))
        If header="" Quit
        Set value=##class(Contest.ProductionEvidence).Read(pid,header)
        If value.capture.state'="captured" Continue
        Set evidence=##class(Contest.ProductionBusinessEvidence).Read(value)
        If '$Match(evidence.receipt.%Get("batch_id"),"^m5-[ABCD]-[0-9]+$") Continue
        Do $$$AssertEquals(evidence.%Get("production_id"),pid)
        Do $$$AssertEquals(evidence.%Get("observation_hash"),value.%Get("record_hash"))
        Do $$$AssertTrue(evidence.receipt.%Get("readback_match"),"Independent SQL readback matches persisted body")
        Do $$$AssertTrue(evidence.%ToJSON()'["SYNTHETIC-M5-","No raw synthetic identifier export")
        Do ##class(Contest.ProductionBusinessEvidence).Validate(evidence,value)
        Set corrupt={}.%FromJSON(evidence.%ToJSON()), corrupt.receipt.receiver="ForgedReceiver", rejected=0
        Try { Do ##class(Contest.ProductionBusinessEvidence).Validate(corrupt,value) } Catch ex { Set rejected=1 }
        Do $$$AssertTrue(rejected,"Frozen receiver evidence cannot be silently replaced")
        Set other={}.%FromJSON(value.%ToJSON())
        Do other.%Set("production_id",##class(Contest.ProductionMonitor).Key("DEMO","Demo.Production"))
        Set rejected=0
        Try { Do ##class(Contest.ProductionBusinessEvidence).Validate(evidence,other) } Catch ex { Set rejected=1 }
        Do $$$AssertTrue(rejected,"Business evidence cannot cross Production boundaries")
        Set packet=##class(Contest.ProductionReview).Packet(value,[]), facts=##class(Contest.RiskReview).Facts(packet)
        Do $$$AssertEquals(facts.%Get("observed_output").verification,"verified")
        If evidence.receipt.receiver="ReceiverC" {
            Do $$$AssertTrue('facts.%IsDefined("approved_scenario"),"Unclassified receiver never becomes established")
            Do $$$AssertEquals(facts.%Get("business_context").kind,"missing_information")
        } Else {
            Do $$$AssertEquals(facts.%Get("approved_scenario").kind,"observation")
            Do $$$AssertEquals(facts.%Get("local_minimization_rule").kind,"local_policy")
        }
        Set changed={}.%FromJSON(value.%ToJSON()), changed.header.target="ForgedReceiver", rejected=0
        Try { Set ignored=##class(Contest.ProductionBusinessEvidence).Read(changed) } Catch ex { Set rejected=1 }
        Do $$$AssertTrue(rejected,"Changed message target cannot borrow an observation hash")
        Set changed={}.%FromJSON(value.%ToJSON()), rejected=0
        Do changed.capture.%Set("body_digest","forged")
        Try { Set ignored=##class(Contest.ProductionBusinessEvidence).Read(changed) } Catch ex { Set rejected=1 }
        Do $$$AssertTrue(rejected,"Changed body digest cannot borrow persisted evidence")
        Set count=count+1
    }
    Do $$$AssertEquals(count,8,"Four real intakes, two request edges each; no per-flow records")
}
}
