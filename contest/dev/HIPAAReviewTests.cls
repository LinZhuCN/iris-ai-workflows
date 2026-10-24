Class Contest.HIPAAReviewTests Extends %UnitTest.TestProduction
{
Parameter PRODUCTION = "Contest.Production";
Method TestControl() As %Status { Quit $$$OK }

Method TestPermissionExceptionsHaveSources()
{
    Set plan=##class(Contest.HIPAAReview).Template("recipient_purpose"), found=0
    For i=0:1:plan.%Size()-1 If plan.%Get(i).section="45 CFR 164.508" Set found=1
    Do $$$AssertTrue(found,"Notes and marketing authorization exceptions cannot be omitted")
    Do $$$AssertEquals(plan.%Size(),4)
    Do $$$AssertEquals(##class(Contest.HIPAAReview).Template("deidentification").%Get(0).section,"45 CFR 164.514")
    Do $$$AssertTrue(##class(Contest.HIPAAReview).ContractHash()'=##class(Contest.ProductionReview).ContractHash(),"Benchmark must not silently reuse local-rule consent")
    Do $$$AssertEquals(##class(Contest.HIPAAReview).InputLimit(),160000)
}

Method TestProductionUsesLegalCoreWithoutLosingUnknownGuard()
{
    Do $$$AssertTrue(##class(Contest.ProductionReview).Prompt("judge")["Assess the HIPAA condition actually raised","Production shares the tested legal-condition core")
    Set packet=##class(Contest.ProductionReviewTests).%New("").Observation()
    Set result=##class(Contest.ProductionReview).Packet(packet,[])
    Do $$$AssertEquals(##class(Contest.RiskReview).Facts(result).%Get("business_context").kind,"missing_information","Changing legal core must not manufacture business evidence")
}
}
