Class Demo.Sampling
{
ClassMethod Config() As %DynamicObject
{
    If $Data(^DemoMonitor("sampling")) Quit {}.%FromJSON(^DemoMonitor("sampling"))
    Quit {"enabled":true,"daily_minimum":true,"rate":0,"revision":1}
}

ClassMethod Facts(scenario As %String) As %DynamicObject
{
    Set facts={"synthetic":true,"purpose_known":false,"purpose":($Select(scenario="analytics":"analytics",scenario="treatment":"treatment",1:"unknown")),"direct_identifiers":false,"deidentification_verified":false,"authorization_known":false}
    Do facts.%Set("purpose_known",scenario'="failure","boolean"), facts.%Set("direct_identifiers",scenario="analytics","boolean")
    Quit facts
}

ClassMethod Bucket(id As %String) As %Integer
{
    Set digest=$System.Encryption.SHAHash(256,id)
    Quit (($Ascii(digest,1)*16777216)+($Ascii(digest,2)*65536)+($Ascii(digest,3)*256)+$Ascii(digest,4))#100
}

ClassMethod Select(id As %String, scenario As %String, day As %Integer, config As %DynamicObject) As %DynamicObject
{
    Set selected=0, reason="not_eligible"
    If scenario="analytics" {
        Set reason="paused"
        If config.enabled {
            Set reason="not_sampled"
            If config.%Get("daily_minimum") && '$Data(^DemoMonitor("daily",day,"route.complete","analytics")) {
                Set selected=1, reason="daily_first"
            } ElseIf ..Bucket(id)<config.rate {
                Set selected=1, reason="rate"
            }
        }
    }
    Set result={"selected":false,"reason":(reason)}
    Do result.%Set("selected",selected,"boolean")
    Quit result
}
}
