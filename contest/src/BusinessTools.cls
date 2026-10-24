Class Contest.BusinessTools Extends %AI.Tool
{
ClassMethod CheckRun(runId As %String) [ Private ]
{
    If (runId="") || (runId'=$Get(^ContestBusinessContext($Job))) Do ##class(Demo.Protocol).Fail("Business tools require the currently bound run")
}

ClassMethod ReadBusinessFacts(runId As %String) As %DynamicObject
{
    Do ..CheckRun(runId)
    Set ^ContestBusinessContext($Job,"factsRead")=1
    Do ..Trace({"tool":"ReadBusinessFacts","time":(##class(Demo.Protocol).Now())})
    Quit {}.%FromJSON(^ContestBusinessContext($Job,"facts"))
}

ClassMethod SearchBusinessEvidence(runId As %String, query As %String) As %DynamicObject
{
    Do ..CheckRun(runId)
    If '$Get(^ContestBusinessContext($Job,"factsRead")) Do ##class(Demo.Protocol).Fail("Read business facts before selecting a contextual search")
    If ($ZStrip(query,"<>W")="") || ($Length(query)>600) Do ##class(Demo.Protocol).Fail("A bounded public-knowledge query is required")
    If $Get(^ContestBusinessContext($Job,"queries"))>=3 Do ##class(Demo.Protocol).Fail("At most three evidence searches per case")
    Set ^ContestBusinessContext($Job,"queries")=$Get(^ContestBusinessContext($Job,"queries"))+1
    Set response={"availability":"unavailable","evidence":[]}, count=^ContestBusinessContext($Job,"queries")
    If $Get(^ContestBusinessContext($Job,"simulateUnavailable")) {
        Do response.%Set("error","Explicit synthetic retrieval-outage control; no sources available")
    } Else {
        Try {
            Set config={}.%FromJSON(^ContestBusinessContext($Job,"config"))
            Set hits=##class(Contest.KnowledgeService).SearchVersion(query,config.table,config.%Get("index_version"))
            For i=0:1:hits.value.%Size()-1 {
                Set hit=hits.value.%Get(i), meta=hit.metadata
                If (meta.%Get("retrieval_scope")'="normative") || '((meta.kind="regulation_snapshot") || (meta.kind="official_guidance")) Continue
                If meta.id="" Do ##class(Demo.Protocol).Fail("Evidence lacks source record identity")
                Set entry={"id":("evidence-"_count_"-"_i),"record_id":(meta.id),"chunk_id":(hit.id),"text":($Extract(hit.text,1,2000)),"metadata":(meta),"score":(hit.score)}
                If ($Get(^ContestBusinessContext($Job,"runtimeVersion"))="hipaa-business-runtime-v2") || ($Get(^ContestBusinessContext($Job,"runtimeVersion"))="hipaa-business-runtime-v3") || ($Get(^ContestBusinessContext($Job,"runtimeVersion"))="hipaa-business-runtime-v4") Do ##class(Contest.BusinessReviewV2).Decorate(entry)
                Do response.evidence.%Push(entry)
            }
            If response.evidence.%Size()>0 {
                Set response.availability="available"
                For i=0:1:response.evidence.%Size()-1 {
                    Set n=$Get(^ContestBusinessContext($Job,"evidenceCount"),0)
                    Set ^ContestBusinessContext($Job,"evidence",n)=response.evidence.%Get(i).%ToJSON(), ^ContestBusinessContext($Job,"evidenceCount")=n+1
                }
            } Else {
                Do response.%Set("error","No normative evidence in the retrieved results; refine the query or request human review")
            }
        } Catch ex {
            Do ##class(Contest.KnowledgeService).Audit("business.retrieval.failed",runId,ex.DisplayString())
            Set response={"availability":"unavailable","evidence":[]}
            Do response.%Set("error","Pinned evidence retrieval failed; no substitute sources or clean conclusion are supplied")
        }
    }
    Set ^ContestBusinessContext($Job,"evidenceRead")=1
    Do ..Trace({"tool":"SearchBusinessEvidence","query":(query),"time":(##class(Demo.Protocol).Now()),"response":(response)})
    Quit response
}

ClassMethod Trace(value As %DynamicObject) [ Private ]
{
    Set n=$Get(^ContestBusinessContext($Job,"traceCount"),0)
    Set ^ContestBusinessContext($Job,"trace",n)=value.%ToJSON(), ^ContestBusinessContext($Job,"traceCount")=n+1
}
}
