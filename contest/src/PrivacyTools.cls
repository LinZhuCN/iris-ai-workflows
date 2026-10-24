Class Contest.PrivacyTools Extends %AI.Tool
{
ClassMethod CheckRun(runId As %String) [ Private ]
{
    If (runId = "") || (runId '= $Get(^ContestAgentContext($Job))) Do ##class(Demo.Protocol).Fail("Tool access requires the currently bound test run")
}

ClassMethod ReadPrivacyFacts(runId As %String) As %DynamicObject
{
    Do ..CheckRun(runId)
    Set ^ContestAgentContext($Job,"factsRead") = 1
    Do ..Trace("ReadPrivacyFacts")
    Quit {}.%FromJSON(^ContestAgentContext($Job,"facts"))
}

ClassMethod SearchPrivacyEvidence(runId As %String) As %DynamicObject
{
    Do ..CheckRun(runId)
    Set config = {}.%FromJSON(^ContestAgentContext($Job,"config"))
    If '$Data(^ContestAgentContext($Job,"evidence")) {
        Set hits = ##class(Contest.KnowledgeService).SearchVersion(config.%Get("retrieval_query"),config.table,config.%Get("index_version"))
        Set evidence = [], allowed = {}
        For i = 0:1:hits.value.%Size()-1 {
            Set hit = hits.value.%Get(i), key = "evidence-"_i
            Set entry = {"id":(key),"chunk_id":(hit.id),"text":($Extract(hit.text,1,2000)),"metadata":(hit.metadata),"score":(hit.score)}
            Do evidence.%Push(entry), allowed.%Set(key,1,"boolean")
        }
        If evidence.%Size() = 0 Do ##class(Demo.Protocol).Fail("Pinned retrieval returned no evidence")
        Set ^ContestAgentContext($Job,"evidence") = evidence.%ToJSON(), ^ContestAgentContext($Job,"allowed") = allowed.%ToJSON()
    }
    Set ^ContestAgentContext($Job,"evidenceRead") = 1
    Do ..Trace("SearchPrivacyEvidence")
    Quit {"index_version":(config.%Get("index_version")),"evidence":([].%FromJSON(^ContestAgentContext($Job,"evidence")))}
}

ClassMethod Trace(tool As %String) [ Private ]
{
    Set sequence = $Increment(^ContestAgentContext($Job,"sequence"))
    Set ^ContestAgentContext($Job,"trace",sequence) = {"tool":(tool),"time":(##class(Demo.Protocol).Now())}.%ToJSON()
}
}
