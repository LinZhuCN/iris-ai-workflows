Class Contest.EventTests Extends %UnitTest.TestProduction
{
Parameter PRODUCTION = "Contest.Production";
Method TestControl() As %Status { Quit $$$OK }

Method TestSourceSampling()
{
    Set config={"enabled":true,"daily_minimum":true,"rate":0,"revision":1}, day=999999
    Do $$$AssertTrue(##class(Demo.Sampling).Select("one","analytics",day,config).selected)
    TStart
    Try {
        Set ^DemoMonitor("daily",day,"route.complete","analytics")=1
        Do $$$AssertTrue('##class(Demo.Sampling).Select("two","analytics",day,config).selected)
        Do $$$AssertTrue(##class(Demo.Sampling).Select("three","analytics",day+1,config).selected)
        Set config.rate=100
        Do $$$AssertTrue(##class(Demo.Sampling).Select("four","analytics",day,config).selected)
        Set config.enabled=0
        Do $$$AssertTrue('##class(Demo.Sampling).Select("five","analytics",day,config).selected)
        TRollback 1
    } Catch ex { TRollback 1 Throw ex }
}

Method TestEventTransitions()
{
    Do $$$AssertTrue(##class(Contest.EventService).AllowedTransition("open","in_review"))
    Do $$$AssertTrue(##class(Contest.EventService).AllowedTransition("ignored","open"))
    Do $$$AssertTrue('##class(Contest.EventService).AllowedTransition("open","resolved"))
    Do $$$AssertTrue('##class(Contest.EventService).AllowedTransition("resolved","ignored"))
}

Method TestObservationIdempotency()
{
    Set id="unit-event-"_$System.Util.CreateGUID()
    Set body=..Observation(id)
    TStart
    Try {
        Set baseline=+$Get(^ContestEvents("counts","observed"))
        Do ##class(Contest.EventService).Observe(body)
        Do ##class(Contest.EventService).Observe(body)
        Do $$$AssertEquals($Get(^ContestEvents("counts","observed")),1+baseline)
        Do $$$AssertTrue($Data(^ContestEvents("observation",id)))
        Do $$$AssertEquals({}.%FromJSON(^ContestEvents("review",id)).state,"blocked_budget")
        TRollback 1
    } Catch ex { TRollback 1 Throw ex }
}

ClassMethod Observation(id As %String) As %DynamicObject
{
    Quit {"schema":2,"observation_id":(id),"scenario":"analytics","outcome":"failed","review_selected":true,"source_day":999999,"sampling_revision":1,"review_reason":"daily_first","facts":{"synthetic":true,"purpose_known":true,"purpose":"analytics","direct_identifiers":true,"deidentification_verified":false,"authorization_known":false},"gate":{"decision":"continue","bundle_hash":"","revision":0},"message_id":"unit","session_id":"unit","point":"route.complete","synthetic":true,"instance_id":"local-demo","namespace":"DEMO","production":"Demo.Production","deployment_id":"unit","snapshot_hash":"unit"}
}

Method TestObservationContract()
{
    Set body=..Observation("unit-contract")
    Do $$$AssertTrue(##class(Contest.MonitorService).ValidObservation(body))
    Do body.%Set("review_reason","invented")
    Do $$$AssertTrue('##class(Contest.MonitorService).ValidObservation(body))
    Set body=..Observation("unit-contract"), body.gate.decision="hold_for_review"
    Do $$$AssertTrue('##class(Contest.MonitorService).ValidObservation(body),"A held Gate must not claim failed/delivered")
    Set body=..Observation("unit-contract")
    Do body.gate.%Set("bundle_hash","invalid")
    Do $$$AssertTrue('##class(Contest.MonitorService).ValidObservation(body))
    Set body=..Observation("unit-contract")
    Do body.%Set("source_day",1.5,"number")
    Do $$$AssertTrue('##class(Contest.MonitorService).ValidObservation(body))
}
}
