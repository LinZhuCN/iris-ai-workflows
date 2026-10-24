Class Contest.MultiOrganizationTests Extends %UnitTest.TestProduction
{
Parameter PRODUCTION = "Contest.Production";
Method TestControl() As %Status { Quit $$$OK }

Method TestProfileSnapshotIntegrity()
{
    Set presets=##class(Contest.OrganizationCatalog).Presets(), records={}
    For i=0:1:presets.%Size()-1 {
        Set p=presets.%Get(i)
        Do records.%Set(p.id,{"profile":(p),"revision":1,"hash":(##class(Contest.ExportEvidence).Digest(p))})
    }
    For id="hospital","quality","research","clinic" {
        Set r=records.%Get(id)
        Do $$$AssertTrue(r.revision>0)
        Do $$$AssertEquals(r.hash,##class(Contest.ExportEvidence).Digest(r.profile))
    }
    Set record={"profiles":(records),"source_pins":[],"host_partners":{"ResearchREST":"DemoResearch"},"mapping_version":"multi-org-v1"}
    Set branch={"id":"research","state":"acknowledged","protocol":"REST","namespace":"DEMORESEARCH","payload_hash":"test-hash","message_id":"101","session_id":"100","facts":{"fields":["name","mrn","birthDate"],"full_date":true},"receipt":{"readback_match":true,"payload_hash":"test-hash"},"policy_mismatches":["name","mrn","birthDate"]}
    Do branch.%Set("evidence_hash",##class(Contest.ExportEvidence).Digest(branch))
    Set packet=##class(Contest.MultiAudit).Packet(record,branch)
    Do $$$AssertEquals(packet.%Get("required_questions").%Get(0).topic,"deidentification")
    Do $$$AssertTrue(##class(Contest.RiskReview).Facts(packet).%IsDefined("actual_wire"))
    Do branch.facts.%Set("fields",[])
    Set rejected=0
    Try { Set changed=##class(Contest.MultiAudit).Packet(record,branch) } Catch ex { Set rejected=1 }
    Do $$$AssertTrue(rejected,"Changed wire facts cannot reuse frozen evidence hash")
}

Method TestAuditNeedsActualReceiverEvidence()
{
    Set rejected=0
    Try { Set packet=##class(Contest.MultiAudit).Packet({"profiles":{}},{"id":"research","state":"prepared"}) }
    Catch ex { Set rejected=1 }
    Do $$$AssertTrue(rejected,"Prepared output cannot become an actual-receiver audit")
}

Method TestWireAdapterRetainsDatePrecisionWithoutValues()
{
    Set full=##class(Contest.MultiObservation).Normalize({"fields":["mrn","name","birthDate"],"identifier_present":true,"full_date":true},"clinic")
    Set year=##class(Contest.MultiObservation).Normalize({"fields":["birthYear","status"],"identifier_present":false,"full_date":false},"research")
    Do $$$AssertEquals(full.format,"hl7-v2")
    Do $$$AssertEquals(full.dates.%Get("full_date"),1)
    Do $$$AssertTrue(full.%Get("identifier_present"))
    Do $$$AssertEquals(year.dates.%Get("year_only"),1)
    Do $$$AssertTrue('year.%Get("identifier_present"))
}

Method TestAuditConsentRequiresExplicitBoundedApproval()
{
    Do $$$AssertTrue($Length(##class(Contest.MultiReview).ContractHash())=64,"Versioned multi-organization reviewer contract")
    Set rejected=0
    Try { Set result=##class(Contest.MultiAudit).Start({"run_id":"nonexistent","acknowledge_cost":false,"acknowledge_synthetic":true}) }
    Catch ex { Set rejected=1 }
    Do $$$AssertTrue(rejected,"No model requests from unconfirmed consent")
}
}
