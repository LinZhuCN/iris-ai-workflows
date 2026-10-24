Class Contest.ObservationAPI Extends %CSP.REST
{
Parameter UseSession = 0;
Parameter HandleCorsRequest = 0;
Parameter CHARSET = "utf-8";

XData UrlMap [ XMLNamespace = "http://www.intersystems.com/urlmap" ]
{
<Routes>
<Route Url="/observations" Method="POST" Call="Accept"/>
</Routes>
}

ClassMethod Accept() As %Status
{
    If ($Username '= "ContestDemoSource") || '$System.Security.Check("ContestObservationIngest","U") Quit ##class(Contest.KnowledgeAPI).Failure("source_denied","Registered source identity required","403 Forbidden")
    If $Get(^ContestMonitor("receiverPaused")) Quit ##class(Contest.KnowledgeAPI).Failure("demo_receiver_paused","Demo receiver outage is enabled","503 Service Unavailable")
    If %request.Content.Size > 4096 Quit ##class(Contest.KnowledgeAPI).Failure("body_too_large","Observation exceeds bound","413 Content Too Large")
    If $ZConvert($Piece(%request.GetCgiEnv("CONTENT_TYPE"),";",1),"L") '= "application/json" Quit ##class(Contest.KnowledgeAPI).Failure("invalid_type","JSON required","415 Unsupported Media Type")
    Try { Set body = {}.%FromJSON(%request.Content) }
    Catch ex { Return ##class(Contest.KnowledgeAPI).Failure("invalid_json","Invalid JSON","400 Bad Request") }
    If '##class(Contest.MonitorService).ValidObservation(body) Quit ##class(Contest.KnowledgeAPI).Failure("invalid_observation","Observation contract rejected","400 Bad Request")
    Try {
        Set ok = ##class(Contest.MonitorService).Accept(body,.duplicate)
        Return ##class(Contest.KnowledgeAPI).Reply({"observation_id":(body.%Get("observation_id")),"duplicate":(duplicate),"state":"durable-inbox"})
    } Catch ex {
        Do ##class(Contest.KnowledgeService).Audit("monitor.ingest.rejected",body.%Get("observation_id"),ex.DisplayString())
        Return ##class(Contest.KnowledgeAPI).Failure("observation_conflict","Observation key or deployment rejected","409 Conflict")
    }
}
}
