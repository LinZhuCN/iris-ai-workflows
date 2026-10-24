Class Contest.BusinessReviewV2Tests Extends %UnitTest.TestProduction
{
Parameter PRODUCTION = "Contest.Production";
Method TestControl() As %Status { Quit $$$OK }

Method Evidence() As %DynamicArray
{
    Set hit=##class(Contest.BusinessReviewTests).%New("").Evidence().%Get(0)
    Do ##class(Contest.BusinessReviewV2).Decorate(hit)
    Quit [(hit)]
}

Method Proposal() As %DynamicObject
{
    Quit {"assessment":"no_finding","recommended_action":"continue_under_existing_controls","reason":"Only this treatment disclosure issue was assessed.","findings":[{"fact_ids":["purpose"],"condition":"Treatment permission, subject to applicable controls and exceptions.","evidence_status":"supported_no_finding","explanation":"The supplied fact supports a treating-provider disclosure.","citations":[{"evidence_id":"evidence-0","passage_id":"p0"}]}],"missing_information":[]}
}

Method TestMaterializedCitations()
{
    Set evidence=..Evidence(), proposal=..Proposal(), original=proposal.%ToJSON()
    Set result=##class(Contest.BusinessReviewV2).Resolve(proposal,##class(Contest.BusinessReviewTests).%New("").Packet(),evidence)
    Set citation=result.findings.%Get(0).citations.%Get(0)
    Do $$$AssertEquals(citation.quote,evidence.%Get(0).text)
    Do $$$AssertEquals(citation.start,0)
    Do $$$AssertEquals(citation.end,$Length(citation.quote))
    Do $$$AssertEquals(proposal.%ToJSON(),original,"Submitted proposal must not be rewritten")
    Do proposal.findings.%Get(0).citations.%Get(0).%Set("quote","A model-authored replacement")
    Set rejected=0
    Try { Set result=##class(Contest.BusinessReviewV2).Resolve(proposal,##class(Contest.BusinessReviewTests).%New("").Packet(),evidence) }
    Catch ex { Set rejected=1 }
    Do $$$AssertTrue(rejected,"Do not silently strip extra citation fields")
}

Method TestMissingProofIsNotConfirmedRisk()
{
    Set proposal=..Proposal(), finding=proposal.findings.%Get(0)
    Do finding.%Set("evidence_status","unresolved")
    Do proposal.%Set("assessment","risk"), proposal.%Set("recommended_action","hold_for_review")
    Do proposal.%Set("missing_information",["Whether the claimed disclosure basis is verified"])
    Set rejected=0
    Try { Set result=##class(Contest.BusinessReviewV2).Resolve(proposal,##class(Contest.BusinessReviewTests).%New("").Packet(),..Evidence()) }
    Catch ex { Set rejected=1 }
    Do $$$AssertTrue(rejected,"Only unresolved findings cannot aggregate to risk")
    Do proposal.%Set("assessment","insufficient_evidence")
    Set result=##class(Contest.BusinessReviewV2).Resolve(proposal,##class(Contest.BusinessReviewTests).%New("").Packet(),..Evidence())
    Do $$$AssertEquals(result.assessment,"insufficient_evidence")
    Do $$$AssertEquals(result.%Get("recommended_action"),"hold_for_review","Conservative action does not require a risk label")
    Do proposal.%Set("assessment","no_finding"), proposal.%Set("recommended_action","continue_under_existing_controls")
    Set rejected=0
    Try { Set result=##class(Contest.BusinessReviewV2).Resolve(proposal,##class(Contest.BusinessReviewTests).%New("").Packet(),..Evidence()) }
    Catch ex { Set rejected=1 }
    Do $$$AssertTrue(rejected)
}

Method TestUnknownPassageAndStageRejected()
{
    Set proposal=..Proposal()
    Do proposal.findings.%Get(0).citations.%Get(0).%Set("passage_id","p999")
    Set rejected=0
    Try { Set result=##class(Contest.BusinessReviewV2).Resolve(proposal,##class(Contest.BusinessReviewTests).%New("").Packet(),..Evidence()) }
    Catch ex { Set rejected=1 }
    Do $$$AssertTrue(rejected)
    Set proposal=..Proposal(), packet=##class(Contest.BusinessReviewTests).%New("").Packet()
    Set packet.stage="after_send"
    Do proposal.%Set("recommended_action","hold_for_review")
    Set rejected=0
    Try { Set result=##class(Contest.BusinessReviewV2).Resolve(proposal,packet,..Evidence()) }
    Catch ex { Set rejected=1 }
    Do $$$AssertTrue(rejected)
}

Method TestFreeSdkDiscoveryAndImmutableV1()
{
    Set agent=##class(Contest.AgentService).NewAgent("unit-no-chat",1,"hipaa-business-runtime-v2")
    Do $$$AssertEquals(agent.SystemPrompt,##class(Contest.BusinessReviewV2).Prompt())
    Do $$$AssertEquals(agent.MaxIterations,4)
    Set discovery=##class(Contest.BusinessToolSetV2).%New().%Discover()
    Do $$$AssertEquals(discovery.tools.%Size(),3,"Facts, semantic discovery and exact section lookup only")
    For i=0:1:discovery.tools.%Size()-1 Do $$$AssertTrue($Length(discovery.tools.%Get(i).description)>0,"SDK must expose tool-specific evidence instructions")
    Do $$$AssertEquals(##class(Demo.Protocol).Hash(##class(Contest.BusinessReview).Prompt()),"80a8231d7aaeb69b3b54ee1f3ef1631887b46c6c08264103226e4596305c689f")
    TStart
    Try {
        Set ^ContestBusinessContext($Job)="unit-sdk-v2", ^ContestBusinessContext($Job,"facts")=##class(Contest.BusinessReviewTests).%New("").Packet().%ToJSON()
        Set ^ContestBusinessContext($Job,"simulateUnavailable")=1
        Set facts=agent.ToolManager.ExecuteTool("ReadBusinessFacts",{"runId":"unit-sdk-v2"})
        Set lookup=agent.ToolManager.ExecuteTool("LookupBusinessClause",{"runId":"unit-sdk-v2","section":"45 CFR 164.506","anchor":""})
        Do $$$AssertEquals(facts.value.%Get("case_id"),"business-01")
        Do $$$AssertEquals(lookup.value.availability,"unavailable")
        Do $$$AssertEquals($Get(^ContestBusinessContext($Job,"traceCount")),2,"SDK dispatch actually invokes the bound tools without Chat")
        TRollback 1
    } Catch ex { TRollback 1 Throw ex }
}

Method TestLookupIsolationAndSharedBudget()
{
    TStart
    Try {
        Set ^ContestBusinessContext($Job)="unit-v2"
        Set rejected=0
        Try { Set result=##class(Contest.BusinessToolsV2).LookupBusinessClause("unit-v2","45 CFR 164.506","") }
        Catch ex { Set rejected=1 }
        Do $$$AssertTrue(rejected,"Facts must precede clause lookup")
        Set ^ContestBusinessContext($Job,"factsRead")=1, ^ContestBusinessContext($Job,"queries")=3
        Set rejected=0
        Try { Set result=##class(Contest.BusinessToolsV2).LookupBusinessClause("unit-v2","45 CFR 164.506","") }
        Catch ex { Set rejected=1 }
        Do $$$AssertTrue(rejected,"Semantic and clause retrieval share a three-call cap")
        Set ^ContestBusinessContext($Job,"queries")=0, ^ContestBusinessContext($Job,"simulateUnavailable")=1
        Set result=##class(Contest.BusinessToolsV2).LookupBusinessClause("unit-v2","45 CFR 164.506","")
        Do $$$AssertEquals(result.availability,"unavailable")
        Do $$$AssertEquals(result.evidence.%Size(),0)
        TRollback 1
    } Catch ex { TRollback 1 Throw ex }
}

Method TestPassageBoundaries()
{
    Set source=$Translate($Justify("",799)," ","A")_$Char(55357,56832)_$Translate($Justify("",820)," ","B")_$Char(10)_"Nineteen characters"
    Set hit={"text":(source)}
    Do ##class(Contest.BusinessReviewV2).Decorate(hit)
    Do $$$AssertEquals(hit.passages.%Get(0).end,799,"Do not split UTF-16 surrogate pairs")
    Set restored="", previous=0
    For i=0:1:hit.passages.%Size()-1 {
        Set span=hit.passages.%Get(i)
        Do $$$AssertEquals(span.start,previous)
        Do $$$AssertTrue(($Length(span.text)>=16) && ($Length(span.text)<=815))
        Set restored=restored_span.text, previous=span.end
    }
    Do $$$AssertEquals(restored,source)
    Do $$$AssertEquals(previous,$Length(source))
}

Method TestVersionAuthorizationCannotReuseOldKey()
{
    Set body={"agent_id":"source","request_key":("free-v2-"_$System.Util.CreateGUID()),"input_hash":($Translate($Justify("",64)," ","a")),"acknowledge_cost":true,"max_model_requests":48,"runtime_version":"hipaa-business-runtime-v2"}
    Do $$$AssertTrue(##class(Contest.BusinessReview).ValidStart(body))
    Do body.%Set("runtime_version","arbitrary-version")
    Do $$$AssertTrue('##class(Contest.BusinessReview).ValidStart(body))
    Do body.%Set("runtime_version","hipaa-business-runtime-v2")
    Set id="free-v2-"_$System.Util.CreateGUID()
    TStart
    Try {
        Set ^ContestBusinessReview("request",body.%Get("request_key"))=id
        Set ^ContestBusinessReview("report",id)={"id":(id),"state":"completed","prompt_version":"hipaa-business-runtime-v1","config":{"id":"source"},"input_hash":(body.%Get("input_hash"))}.%ToJSON()
        Set rejected=0
        Try { Set result=##class(Contest.BusinessReview).Start(body) }
        Catch ex { Set rejected=1 }
        Do $$$AssertTrue(rejected,"An approved v1 key cannot authorize v2")
        TRollback 1
    } Catch ex { TRollback 1 Throw ex }
}
}
