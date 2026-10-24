Class Contest.BusinessReviewV4Tests Extends %UnitTest.TestProduction
{
Parameter PRODUCTION = "Contest.Production";
Method TestControl() As %Status { Quit $$$OK }

Method TestBoundFactsAndSingleUseSdkBundle()
{
    TStart
    Try {
        Set run="unit-v4", packet=##class(Contest.BusinessReviewTests).%New("").Packet()
        Set ^ContestBusinessContext($Job)=run, ^ContestBusinessContext($Job,"facts")=packet.%ToJSON(), ^ContestBusinessContext($Job,"simulateUnavailable")=1
        Set input=##class(Contest.BusinessReviewV4).Input(run)
        Do $$$AssertEquals(input.facts.%ToJSON(),packet.%ToJSON())
        Set agent=##class(Contest.AgentService).NewAgent("unit-no-chat",1,"hipaa-business-runtime-v4")
        Do $$$AssertEquals(agent.MaxIterations,4)
        Do $$$AssertEquals(agent.SystemPrompt,##class(Contest.BusinessReviewV4).Prompt())
        Set catalog=##class(Contest.BusinessToolSetV4).%New().%Discover()
        Do $$$AssertEquals(catalog.tools.%Size(),1)
        Do $$$AssertTrue($Length(catalog.tools.%Get(0).description)>0)
        Set args={"runId":(run),"query":"Treatment disclosure","section":"45 CFR 164.506","anchor":"","secondSection":"45 CFR 164.502","secondAnchor":""}
        Set result=agent.ToolManager.ExecuteTool("GatherBusinessEvidence",args), view=result.value
        Do $$$AssertEquals(view.steps.%Size(),3)
        Do $$$AssertEquals(view.evidence.%Size(),0)
        Do $$$AssertEquals($Get(^ContestBusinessContext($Job,"queries")),3)
        Do $$$AssertTrue($Get(^ContestBusinessContext($Job,"clauseRead")))
        Do $$$AssertTrue($Get(^ContestBusinessContext($Job,"bundleComplete")))
        Set trace={}.%FromJSON(^ContestBusinessContext($Job,"trace",4))
        Do $$$AssertEquals(trace.tool,"GatherBusinessEvidence")
        Set recorded=trace.%Get("model_response")
        Do $$$AssertEquals(recorded.availability,view.availability)
        Do $$$AssertEquals(recorded.steps.%Size(),view.steps.%Size())
        For i=0:1:view.steps.%Size()-1 {
            Set expected=recorded.steps.%Get(i), actual=view.steps.%Get(i), it=expected.%GetIterator()
            Do $$$AssertEquals(actual.%Size(),expected.%Size())
            While it.%GetNext(.key,.value) {
                Do $$$AssertEquals(actual.%Get(key),value)
                Do $$$AssertEquals(actual.%GetTypeOf(key),expected.%GetTypeOf(key))
            }
        }
        Set rejected=0
        Try { Set again=##class(Contest.BusinessToolsV4).GatherBusinessEvidence(run,"Treatment disclosure","45 CFR 164.506","","","") }
        Catch ex { Set rejected=1 }
        Do $$$AssertTrue(rejected,"A second bundle cannot spend more retrievals")
        TRollback 1
    } Catch ex { TRollback 1 Throw ex }
}

Method TestInvalidPlanIsRejectedBeforeRetrieval()
{
    TStart
    Try {
        Set run="unit-v4-invalid", ^ContestBusinessContext($Job)=run, ^ContestBusinessContext($Job,"facts")=##class(Contest.BusinessReviewTests).%New("").Packet().%ToJSON(), ^ContestBusinessContext($Job,"simulateUnavailable")=1
        Set input=##class(Contest.BusinessReviewV4).Input(run)
        For mode="query","section","anchor","second","duplicate","run" {
            Set query="Treatment", section="45 CFR 164.506", anchor="", second="", secondAnchor="", bound=run
            If mode="query" Set query=""
            If mode="section" Set section="arbitrary SQL"
            If mode="anchor" Set anchor=$Justify("",161)
            If mode="second" Set secondAnchor="orphan anchor"
            If mode="duplicate" Set second=section
            If mode="run" Set bound="another-run"
            Set rejected=0
            Try { Set result=##class(Contest.BusinessToolsV4).GatherBusinessEvidence(bound,query,section,anchor,second,secondAnchor) }
            Catch ex { Set rejected=1 }
            Do $$$AssertTrue(rejected)
            Do $$$AssertEquals($Get(^ContestBusinessContext($Job,"queries"),0),0)
            Do $$$AssertTrue('$Get(^ContestBusinessContext($Job,"bundleStarted")))
        }
        TRollback 1
    } Catch ex { TRollback 1 Throw ex }
}

Method TestVersionPinAndUnchangedContract()
{
    Set body={"agent_id":"source","request_key":"unit-v4","input_hash":($Translate($Justify("",64)," ","a")),"acknowledge_cost":true,"max_model_requests":48,"runtime_version":"hipaa-business-runtime-v4"}
    Do $$$AssertTrue(##class(Contest.BusinessReview).ValidStart(body))
    Do $$$AssertEquals(##class(Demo.Protocol).Hash(##class(Contest.BusinessReviewV3).Prompt()),"47879a4322b7ea63964d9b7f7c0e47064fb3b011c261676cbb110169aac43cdd")
    Do $$$AssertTrue($Length(##class(Contest.BusinessReviewV4).Prompt())<($Length(##class(Contest.BusinessReviewV3).Prompt())*0.8))
    Set p=##class(Contest.BusinessReviewV3Tests).%New("").Proposal(), packet=##class(Contest.BusinessReviewTests).%New("").Packet(), evidence=##class(Contest.BusinessReviewV2Tests).%New("").Evidence()
    Set result=##class(Contest.BusinessReviewV3).Resolve(p,packet,evidence)
    Do $$$AssertEquals(result.assessment,"insufficient_evidence")
}

Method TestSingleClauseAndMissingPrefill()
{
    TStart
    Try {
        Set run="unit-v4-single", ^ContestBusinessContext($Job)=run, ^ContestBusinessContext($Job,"facts")=##class(Contest.BusinessReviewTests).%New("").Packet().%ToJSON(), ^ContestBusinessContext($Job,"simulateUnavailable")=1
        Set rejected=0
        Try { Set output=##class(Contest.BusinessToolsV4).GatherBusinessEvidence(run,"Treatment","45 CFR 164.506","","","") }
        Catch ex { Set rejected=1 }
        Do $$$AssertTrue(rejected,"No retrieval before server-prefilled facts")
        Set input=##class(Contest.BusinessReviewV4).Input(run)
        Set output=##class(Contest.BusinessToolsV4).GatherBusinessEvidence(run,"Treatment","45 CFR 164.506","","","")
        Do $$$AssertEquals(output.steps.%Size(),2)
        Do $$$AssertEquals($Get(^ContestBusinessContext($Job,"queries")),2)
        Do $$$AssertEquals(output.availability,"unavailable")
        Do $$$AssertTrue(output.steps.%Get(1).%IsDefined("error"))
        Set rejected=0
        Try { Set input=##class(Contest.BusinessReviewV4).Input(run) }
        Catch ex { Set rejected=1 }
        Do $$$AssertTrue(rejected,"Facts cannot be re-prefilled after retrieval")
        TRollback 1
    } Catch ex { TRollback 1 Throw ex }
}

Method TestOldCostConsentCannotUpgrade()
{
    Set key="unit-v4-"_$System.Util.CreateGUID()
    Set body={"agent_id":"source","request_key":(key),"input_hash":($Translate($Justify("",64)," ","a")),"acknowledge_cost":true,"max_model_requests":48,"runtime_version":"hipaa-business-runtime-v4"}
    TStart
    Try {
        Set id="unit-v4-"_$System.Util.CreateGUID()
        Set ^ContestBusinessReview("request",key)=id
        Set ^ContestBusinessReview("report",id)={"id":(id),"state":"completed","prompt_version":"hipaa-business-runtime-v3","config":{"id":"source"},"input_hash":(body.%Get("input_hash"))}.%ToJSON()
        Set rejected=0
        Try { Set result=##class(Contest.BusinessReview).Start(body) }
        Catch ex { Set rejected=1 }
        Do $$$AssertTrue(rejected,"V3 cost consent never authorizes V4")
        TRollback 1
    } Catch ex { TRollback 1 Throw ex }
}
}
