Class Contest.BusinessToolsV3 Extends %AI.Tool
{
/// Read bound synthetic facts first. No oracle or inferred legal conclusion is supplied.
ClassMethod ReadBusinessFacts(runId As %String) As %DynamicObject
{
    Quit ##class(Contest.BusinessTools).ReadBusinessFacts(runId)
}

/// Discover normative sources in the pinned vector index. Passage text is supplied once; verify relevant clauses/exceptions with LookupBusinessClause.
ClassMethod SearchBusinessEvidence(runId As %String, query As %String) As %DynamicObject
{
    Quit ..Project(##class(Contest.BusinessTools).SearchBusinessEvidence(runId,query))
}

/// Inspect a dated CFR section and optional literal anchor; empty anchor returns the beginning, not necessarily the relevant condition. Honor truncation and neighboring passage hints.
ClassMethod LookupBusinessClause(runId As %String, section As %String, anchor As %String) As %DynamicObject
{
    Quit ..Project(##class(Contest.BusinessToolsV2).LookupBusinessClause(runId,section,anchor))
}

ClassMethod Project(response As %DynamicObject) As %DynamicObject [ Private ]
{
    Set view=##class(Contest.BusinessReviewV3).ModelView(response)
    Set n=$Get(^ContestBusinessContext($Job,"traceCount"),0)-1
    If n<0 Do ##class(Demo.Protocol).Fail("Missing canonical retrieval trace")
    Set trace={}.%FromJSON(^ContestBusinessContext($Job,"trace",n))
    Do trace.%Set("model_response",view)
    Set ^ContestBusinessContext($Job,"trace",n)=trace.%ToJSON()
    Quit view
}
}
