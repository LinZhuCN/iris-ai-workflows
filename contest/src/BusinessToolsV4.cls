Class Contest.BusinessToolsV4 Extends %AI.Tool
{
/// Call ONCE before the final answer. Choose a public-knowledge query and one or two relevant 45 CFR sections from the bound facts. Discovery and exact lookups run together (max three retrievals). Use literal anchors or empty anchors for section beginnings; optional secondSection and secondAnchor must both be empty if unused. Review steps[].error/truncated and cite only returned passage IDs.
ClassMethod GatherBusinessEvidence(runId As %String, query As %String, section As %String, anchor As %String, secondSection As %String, secondAnchor As %String) As %DynamicObject
{
    If (runId="") || (runId'=$Get(^ContestBusinessContext($Job))) || '$Get(^ContestBusinessContext($Job,"factsRead")) Do ##class(Demo.Protocol).Fail("Bound server-prefilled facts are required")
    If $Get(^ContestBusinessContext($Job,"bundleStarted")) || ($Get(^ContestBusinessContext($Job,"queries"),0)'=0) Do ##class(Demo.Protocol).Fail("Only one evidence bundle per case, no additional retrievals")
    If ($ZStrip(query,"<>W")="") || ($Length(query)>600) Do ##class(Demo.Protocol).Fail("A bounded public-knowledge query is required")
    If '$Match(section,"^45 CFR 16[04][.][0-9]{3}$") || ($Length(anchor)>160) Do ##class(Demo.Protocol).Fail("Use a bounded CFR section and literal anchor")
    If secondSection="" {
        If secondAnchor'="" Do ##class(Demo.Protocol).Fail("Second anchor requires a second section")
    } Else {
        If '$Match(secondSection,"^45 CFR 16[04][.][0-9]{3}$") || (secondSection=section) || ($Length(secondAnchor)>160) Do ##class(Demo.Protocol).Fail("Second lookup requires a distinct bounded CFR section and anchor")
    }
    Set ^ContestBusinessContext($Job,"bundleStarted")=1
    Set first=$Get(^ContestBusinessContext($Job,"traceCount"),0)
    Set discovery=##class(Contest.BusinessTools).SearchBusinessEvidence(runId,query)
    Set clause=##class(Contest.BusinessToolsV2).LookupBusinessClause(runId,section,anchor)
    If secondSection'="" Set second=##class(Contest.BusinessToolsV2).LookupBusinessClause(runId,secondSection,secondAnchor)
    Set steps=[], evidence=[], last=$Get(^ContestBusinessContext($Job,"traceCount"),0)-1
    For i=first:1:last {
        Set trace={}.%FromJSON(^ContestBusinessContext($Job,"trace",i))
        Do trace.%Set("parent_tool","GatherBusinessEvidence")
        Set ^ContestBusinessContext($Job,"trace",i)=trace.%ToJSON()
        Set step={}.%FromJSON(trace.response.%ToJSON())
        Do step.%Remove("evidence"), step.%Set("tool",trace.tool)
        If trace.tool="SearchBusinessEvidence" Do step.%Set("query",trace.query)
        Do steps.%Push(step)
        For j=0:1:trace.response.evidence.%Size()-1 Do evidence.%Push(trace.response.evidence.%Get(j))
    }
    Set response={"availability":($Select(evidence.%Size()>0:"available",1:"unavailable")),"evidence":(evidence),"steps":(steps)}
    Set view=##class(Contest.BusinessReviewV3).ModelView(response), n=last+1
    Set ^ContestBusinessContext($Job,"trace",n)={"tool":"GatherBusinessEvidence","runId":(runId),"query":(query),"section":(section),"anchor":(anchor),"secondSection":(secondSection),"secondAnchor":(secondAnchor),"time":(##class(Demo.Protocol).Now()),"response":(response),"model_response":(view)}.%ToJSON()
    Set ^ContestBusinessContext($Job,"traceCount")=n+1, ^ContestBusinessContext($Job,"bundleComplete")=1
    Quit view
}
}
