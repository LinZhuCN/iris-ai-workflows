Class Contest.RuleTests Extends %UnitTest.TestProduction
{
Parameter PRODUCTION = "Contest.Production";
Method TestControl() As %Status { Quit $$$OK }

Method TestBoundedAST()
{
    Set bundle=##class(Demo.RuleEngine).Template()
    Do $$$AssertTrue(##class(Demo.RuleEngine).Valid(bundle))
    Set bundle.endpoint="http://arbitrary"
    Do $$$AssertTrue('##class(Demo.RuleEngine).Valid(bundle))
    Do bundle.%Remove("endpoint")
    Set bundle.rules.%Get(0).action="execute"
    Do $$$AssertTrue('##class(Demo.RuleEngine).Valid(bundle))
}

Method TestThreeValues()
{
    Set rule=##class(Demo.RuleEngine).Template().rules.%Get(0)
    Do $$$AssertEquals(##class(Demo.RuleEngine).Match(rule,{"purpose":"analytics","direct_identifiers":true}),1)
    Do $$$AssertEquals(##class(Demo.RuleEngine).Match(rule,{"purpose":"treatment","direct_identifiers":true}),0)
    Do $$$AssertEquals(##class(Demo.RuleEngine).Match(rule,{"purpose":"analytics"}),-1)
    Do $$$AssertEquals(##class(Demo.RuleEngine).Match(rule,{"purpose":"analytics","direct_identifiers":"true"}),-1)
}

Method TestGoldenDecisions()
{
    Set bundle=##class(Demo.RuleEngine).Template()
    Do $$$AssertEquals(##class(Demo.RuleEngine).Decision(bundle,{"purpose_known":true,"purpose":"analytics","direct_identifiers":true}),"hold_for_review")
    Do $$$AssertEquals(##class(Demo.RuleEngine).Decision(bundle,{"purpose_known":true,"purpose":"analytics","direct_identifiers":false}),"continue")
    Do $$$AssertEquals(##class(Demo.RuleEngine).Decision(bundle,{"purpose_known":false}),"hold_for_review")
    Do bundle.%Set("enabled",0,"boolean")
    Set bundle.rules=[]
    Do $$$AssertEquals(##class(Demo.RuleEngine).Decision(bundle,{}),"continue")
}

Method TestCanonicalHash()
{
    Set bundle=##class(Demo.RuleEngine).Template()
    Set reordered={}.%FromJSON({"rules":(bundle.rules),"unknown_action":"hold_for_review","default_action":"continue","enabled":true,"target":"local-demo/DEMO/Demo.Production/before_send","executor":"gate-v1","schema":1}.%ToJSON())
    Do $$$AssertEquals(##class(Demo.RuleEngine).Hash(bundle),##class(Demo.RuleEngine).Hash(reordered))
    Set reordered.rules.%Get(0).all.%Get(0).value="treatment"
    Do $$$AssertTrue(##class(Demo.RuleEngine).Hash(bundle)'=##class(Demo.RuleEngine).Hash(reordered))
}

Method TestOperatorsAndBoundaries()
{
    Set rule={"id":"bounded","all":[{"field":"purpose","op":"in","value":["analytics","treatment"]},{"field":"authorization_known","op":"exists","value":true}],"action":"hold_for_review"}
    Set bundle=##class(Demo.RuleEngine).Template(), bundle.rules=[]
    Do bundle.rules.%Push(rule)
    Do $$$AssertTrue(##class(Demo.RuleEngine).Valid(bundle))
    Do $$$AssertEquals(##class(Demo.RuleEngine).Match(rule,{"purpose":"analytics","authorization_known":false}),1)
    Do $$$AssertEquals(##class(Demo.RuleEngine).Match(rule,{"purpose":"analytics"}),0)
    Do $$$AssertEquals(##class(Demo.RuleEngine).Match(rule,{"authorization_known":true}),-1)
    Set bundle=##class(Demo.RuleEngine).Template()
    Do bundle.%Set("enabled",1,"number")
    Do $$$AssertTrue('##class(Demo.RuleEngine).Valid(bundle))
    Set bundle=##class(Demo.RuleEngine).Template()
    For i=1:1:5 Do bundle.rules.%Push({"id":("rule-"_i),"all":[{"field":"purpose","op":"eq","value":"analytics"}],"action":"hold_for_review"})
    Do $$$AssertTrue('##class(Demo.RuleEngine).Valid(bundle))
}

Method TestNoApprovalBypass()
{
    Set id="unit-rule-plan-"_$System.Util.CreateGUID()
    TStart
    Try {
        Set ^ContestRules("plan",id)={"id":(id),"digest":"right","state":"planned"}.%ToJSON(), rejected=0
        Try { Set result=##class(Contest.RuleService).Transition(id,"wrong",1) }
        Catch ex { Set rejected=1 }
        Do $$$AssertTrue(rejected)
        Do $$$AssertEquals({}.%FromJSON(^ContestRules("plan",id)).state,"planned","An unauthorized activation must not become reconcilable")
        TRollback 1
    } Catch ex { TRollback 1 Throw ex }
}
}
