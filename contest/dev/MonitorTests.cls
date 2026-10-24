Class Contest.MonitorTests Extends %UnitTest.TestProduction
{
Parameter PRODUCTION = "Contest.Production";

Method TestControl() As %Status
{
    Quit $$$OK
}

Method TestScenarioBoundary()
{
    Do $$$AssertTrue(##class(Contest.MonitorService).ValidScenario("treatment"))
    Do $$$AssertTrue(##class(Contest.MonitorService).ValidScenario("analytics"))
    Do $$$AssertTrue(##class(Contest.MonitorService).ValidScenario("failure"))
    Do $$$AssertTrue('##class(Contest.MonitorService).ValidScenario("arbitrary"))
}

Method TestObservationBoundary()
{
    Set body = {"schema":1,"instance_id":"local-demo","namespace":"DEMO","production":"Demo.Production","observation_id":"demo-123","message_id":"42","session_id":"41","scenario":"analytics","outcome":"delivered","deployment_id":"plan-1","snapshot_hash":"abc","point":"route.complete","synthetic":true}
    Do $$$AssertTrue(##class(Contest.MonitorService).ValidObservation(body))
    Set body.namespace = "USER"
    Do $$$AssertTrue('##class(Contest.MonitorService).ValidObservation(body))
    Set body.namespace = "DEMO", body.patient = "not permitted"
    Do $$$AssertTrue('##class(Contest.MonitorService).ValidObservation(body))
}

Method TestProtocolBoundaries()
{
    Do $$$AssertTrue(##class(Demo.Protocol).CanQueue(999))
    Do $$$AssertTrue('##class(Demo.Protocol).CanQueue(1000))
    Do $$$AssertTrue('##class(Demo.Protocol).CanQueue(-1))
    Do $$$AssertEquals(##class(Demo.Protocol).Hash("abc"),"ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
}

Method TestSummaryBoundary()
{
    Do $$$AssertEquals(##class(Contest.PipelineSummary).Status(""),"")
    Do $$$AssertTrue(##class(Contest.PipelineSummary).ValidResult({"summary":"Synthetic routes with observation-only transport.","limitations":["No rule enforcement."]}))
    Do $$$AssertTrue('##class(Contest.PipelineSummary).ValidResult({"summary":"","limitations":[]}))
    Do $$$AssertTrue('##class(Contest.PipelineSummary).ValidResult({"summary":"text","limitations":[12]}))
    Do $$$AssertTrue('##class(Contest.PipelineSummary).ValidResult({"summary":"text","limitations":[],"action":"modify"}))
    Do $$$AssertTrue('##class(Contest.PipelineSummary).ValidResult({"summary":"text","limitations":"not an array"}))
}
}
