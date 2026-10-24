Class Contest.BusinessReviewV3Tests Extends %UnitTest.TestProduction
{
Parameter PRODUCTION = "Contest.Production";
Method TestControl() As %Status { Quit $$$OK }

Method Proposal() As %DynamicObject
{
    Quit {"assessment":"insufficient_evidence","recommended_action":"manual_review","reason":"A contradicted premise does not prove that an agreement is absent.","findings":[{"fact_ids":["purpose"],"condition":"The applicable arrangement must be verified.","applicability":"applicable","applicability_fact_ids":["purpose"],"condition_status":"unknown","affirmative_fact_ids":[],"exceptions":{"status":"resolved","explanation":"No unresolved alternative is asserted in this fixture."},"explanation":"The agreement evidence is not supplied.","citations":[{"evidence_id":"evidence-0","passage_id":"p0"}]}],"claims":[{"fact_ids":["purpose"],"status":"contradicted","explanation":"The premise is contradicted, but the underlying condition remains unknown.","citations":[{"evidence_id":"evidence-0","passage_id":"p0"}]}],"missing_information":["Agreement verification"]}
}

Method TestClaimWarningIsSeparate()
{
    Set proposal=..Proposal(), packet=##class(Contest.BusinessReviewTests).%New("").Packet(), evidence=##class(Contest.BusinessReviewV2Tests).%New("").Evidence()
    Set result=##class(Contest.BusinessReviewV3).Resolve(proposal,packet,evidence)
    Do $$$AssertEquals(result.assessment,"insufficient_evidence")
    Do $$$AssertEquals(result.claims.%Get(0).status,"contradicted")
    Do $$$AssertEquals(result.claims.%Get(0).citations.%Get(0).quote,evidence.%Get(0).text)
    Set proposal.assessment="risk", rejected=0
    Try { Set result=##class(Contest.BusinessReviewV3).Resolve(proposal,packet,evidence) }
    Catch ex { Set rejected=1 }
    Do $$$AssertTrue(rejected,"A contradicted claim cannot establish an underlying unmet condition")
}

Method TestAffirmativeChainAndExceptionReview()
{
    Set packet=##class(Contest.BusinessReviewTests).%New("").Packet(), evidence=##class(Contest.BusinessReviewV2Tests).%New("").Evidence()
    Set proposal=..Proposal(), finding=proposal.findings.%Get(0)
    Set proposal.assessment="risk"
    Do finding.%Set("condition_status","not_met")
    Set rejected=0
    Try { Set result=##class(Contest.BusinessReviewV3).Resolve(proposal,packet,evidence) }
    Catch ex { Set rejected=1 }
    Do $$$AssertTrue(rejected,"A not-met label needs affirmative fact references")
    Do finding.%Set("affirmative_fact_ids",["purpose"])
    Set result=##class(Contest.BusinessReviewV3).Resolve(proposal,packet,evidence)
    Do $$$AssertEquals(result.assessment,"risk")
    Set finding.exceptions.status="unresolved", rejected=0
    Try { Set result=##class(Contest.BusinessReviewV3).Resolve(proposal,packet,evidence) }
    Catch ex { Set rejected=1 }
    Do $$$AssertTrue(rejected,"An unresolved exception cannot support this condition-failure classification")
}

Method TestCompactProjectionPreservesAudit()
{
    Set evidence=##class(Contest.BusinessReviewV2Tests).%New("").Evidence(), response={"availability":"available","evidence":(evidence),"truncated":true}
    Set original=response.%ToJSON(), view=##class(Contest.BusinessReviewV3).ModelView(response)
    Do $$$AssertEquals(response.%ToJSON(),original)
    Do $$$AssertTrue('view.evidence.%Get(0).%IsDefined("text"))
    Do $$$AssertEquals(view.evidence.%Get(0).passages.%Get(0).text,evidence.%Get(0).text)
    Do $$$AssertTrue(view.evidence.%Get(0).%Get("partial_context"))
    Do $$$AssertTrue(view.truncated)
}

Method TestVersionedSdkWithoutChat()
{
    Set agent=##class(Contest.AgentService).NewAgent("unit-no-chat",1,"hipaa-business-runtime-v3")
    Do $$$AssertEquals(agent.SystemPrompt,##class(Contest.BusinessReviewV3).Prompt())
    Set catalog=##class(Contest.BusinessToolSetV3).%New().%Discover()
    Do $$$AssertEquals(catalog.tools.%Size(),3)
    For i=0:1:catalog.tools.%Size()-1 Do $$$AssertTrue($Length(catalog.tools.%Get(i).description)>0)
    Do $$$AssertEquals(##class(Demo.Protocol).Hash(##class(Contest.BusinessReviewV2).Prompt()),"dbddec601f1dd814cdb02189155164189ca5f295aa39d1fee4633f07ab547891")
    TStart
    Try {
        Set ^ContestBusinessContext($Job)="unit-sdk-v3", ^ContestBusinessContext($Job,"facts")=##class(Contest.BusinessReviewTests).%New("").Packet().%ToJSON(), ^ContestBusinessContext($Job,"simulateUnavailable")=1
        Set facts=agent.ToolManager.ExecuteTool("ReadBusinessFacts",{"runId":"unit-sdk-v3"})
        Set lookup=agent.ToolManager.ExecuteTool("LookupBusinessClause",{"runId":"unit-sdk-v3","section":"45 CFR 164.506","anchor":""})
        Do $$$AssertEquals(lookup.value.availability,"unavailable")
        Set trace={}.%FromJSON(^ContestBusinessContext($Job,"trace",1))
        Set recorded=trace.%Get("model_response")
        For key="availability","section","anchor","truncated","anchor_matched","error" {
            Do $$$AssertEquals(recorded.%Get(key),lookup.value.%Get(key))
            Do $$$AssertEquals(recorded.%GetTypeOf(key),lookup.value.%GetTypeOf(key))
        }
        Do $$$AssertEquals(lookup.value.evidence.%Size(),0)
        Do $$$AssertEquals($Get(^ContestBusinessContext($Job,"queries")),1)
        TRollback 1
    } Catch ex { TRollback 1 Throw ex }
}

Method TestMissingAbsentValidAndStageDevelopmentPairs()
{
    Set packet=##class(Contest.BusinessReviewTests).%New("").Packet(), evidence=##class(Contest.BusinessReviewV2Tests).%New("").Evidence()
    For status="unknown","not_met","met" {
        Set proposal=..Proposal(), finding=proposal.findings.%Get(0)
        Do proposal.%Set("claims",[])
        Do finding.%Set("condition_status",status)
        Do packet.facts.%Get(0).%Set("text",$Select(status="unknown":"Agreement not supplied; existence unknown.",status="not_met":"Reviewer verified no required agreement exists and no alternative applies.",1:"Reviewer verified the agreement and applicable conditions."))
        Do finding.%Set("affirmative_fact_ids",$Select(status="unknown":[],1:["purpose"]))
        Do proposal.%Set("missing_information",$Select(status="unknown":["Agreement verification"],1:[]))
        Set proposal.assessment=$Select(status="unknown":"insufficient_evidence",status="not_met":"risk",1:"no_finding")
        For stage="before_send","after_send" {
            Set packet.stage=stage
            Do proposal.%Set("recommended_action",$Select(status="met":"continue_under_existing_controls",stage="before_send":"hold_for_review",1:"manual_review"))
            Set result=##class(Contest.BusinessReviewV3).Resolve(proposal,packet,evidence)
            Do $$$AssertEquals(result.assessment,proposal.assessment)
        }
    }
}

Method TestUnverifiedClaimNoEvidenceAndMalformedFields()
{
    Set packet=##class(Contest.BusinessReviewTests).%New("").Packet(), evidence=##class(Contest.BusinessReviewV2Tests).%New("").Evidence(), proposal=..Proposal()
    Set finding=proposal.findings.%Get(0)
    Do finding.%Set("condition_status","met"), finding.%Set("affirmative_fact_ids",["purpose"])
    Set proposal.claims.%Get(0).status="unverified"
    Set result=##class(Contest.BusinessReviewV3).Resolve(proposal,packet,evidence)
    Do $$$AssertEquals(result.assessment,"insufficient_evidence")
    Do proposal.%Set("extra",1)
    Set rejected=0
    Try { Set result=##class(Contest.BusinessReviewV3).Resolve(proposal,packet,evidence) }
    Catch ex { Set rejected=1 }
    Do $$$AssertTrue(rejected)
    Set proposal=..Proposal()
    Do proposal.%Set("findings",[]), proposal.%Set("claims",[])
    Set result=##class(Contest.BusinessReviewV3).Resolve(proposal,packet,[])
    Do $$$AssertEquals(result.assessment,"insufficient_evidence")
}

Method TestV3AuthorizationCannotUpgradeV2Key()
{
    Set body={"agent_id":"source","request_key":("unit-v3-"_$System.Util.CreateGUID()),"input_hash":($Translate($Justify("",64)," ","a")),"acknowledge_cost":true,"max_model_requests":48,"runtime_version":"hipaa-business-runtime-v3"}
    Do $$$AssertTrue(##class(Contest.BusinessReview).ValidStart(body))
    TStart
    Try {
        Set id="unit-v3-"_$System.Util.CreateGUID()
        Set ^ContestBusinessReview("request",body.%Get("request_key"))=id
        Set ^ContestBusinessReview("report",id)={"id":(id),"state":"completed","prompt_version":"hipaa-business-runtime-v2","config":{"id":"source"},"input_hash":(body.%Get("input_hash"))}.%ToJSON()
        Set rejected=0
        Try { Set result=##class(Contest.BusinessReview).Start(body) }
        Catch ex { Set rejected=1 }
        Do $$$AssertTrue(rejected,"Old cost consent cannot authorize a new runtime version")
        TRollback 1
    } Catch ex { TRollback 1 Throw ex }
}

Method TestSeparateClaimCoverageAndActionPolicy()
{
    Set packet=##class(Contest.BusinessReviewTests).%New("").Packet(), evidence=##class(Contest.BusinessReviewV2Tests).%New("").Evidence(), proposal=..Proposal()
    Set other="operator_claim"
    Do packet.facts.%Push({"id":(other),"text":"Operator supplied a disputed rationale."})
    Do proposal.claims.%Get(0).%Set("fact_ids",[(other)])
    Set resolved=##class(Contest.BusinessReviewV3).Resolve(proposal,packet,evidence)
    Set item={"case_id":"business-01","state":"completed","packet":(packet),"result":(resolved),"evidence":(evidence)}
    Set spec={"required_sections":[],"oracle":{"assessment":"insufficient_evidence","recommended_action":"manual_review","critical_fact_ids":["purpose",(other)]}}
    Set checked=##class(Contest.BusinessReview).CheckCase(item,spec,"hipaa-business-runtime-v3")
    Do $$$AssertTrue(checked.checks.%Get("critical_facts_referenced"),"Coverage includes explicit claims without making them condition failures")
    Do $$$AssertTrue(checked.%Get("action_policy").conforms)
    Do item.result.%Set("recommended_action","hold_for_review")
    Set checked=##class(Contest.BusinessReview).CheckCase(item,spec,"hipaa-business-runtime-v3")
    Do $$$AssertTrue(checked.%Get("action_policy").conforms)
    Do $$$AssertTrue('checked.%Get("action_policy").%Get("expected_action_exact_match"))
    Set item.packet.stage="after_send"
    Set checked=##class(Contest.BusinessReview).CheckCase(item,spec,"hipaa-business-runtime-v3")
    Do $$$AssertTrue('checked.%Get("action_policy").conforms)
}
}
