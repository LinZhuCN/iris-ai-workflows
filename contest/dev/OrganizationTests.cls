Class Contest.OrganizationTests Extends %UnitTest.TestProduction
{
Parameter PRODUCTION = "Contest.Production";
Method TestControl() As %Status { Quit $$$OK }

Method TestPresetAndVersionContract()
{
    Set presets=##class(Contest.OrganizationCatalog).Presets()
    Do $$$AssertEquals(presets.%Size(),4,"Source hospital and three recipients")
    For i=0:1:3 {
        Set p=presets.%Get(i)
        Do ##class(Contest.OrganizationCatalog).Validate(p)
        Do $$$AssertTrue(p.%Get("allowed_fields").%IsA("%DynamicArray"))
    }
    Set p=presets.%Get(2), bad={}.%FromJSON(p.%ToJSON())
    Do bad.%Set("verdict","risk")
    Set rejected=0
    Try { Do ##class(Contest.OrganizationCatalog).Validate(bad) } Catch ex { Set rejected=1 }
    Do $$$AssertTrue(rejected,"Do not accept expected model verdict in profile")
}

Method TestUnknownFieldsAndInvalidLimits()
{
    Set p=##class(Contest.OrganizationCatalog).Presets().%Get(0)
    Do p.%Set("name","")
    Set rejected=0
    Try { Do ##class(Contest.OrganizationCatalog).Validate(p) } Catch ex { Set rejected=1 }
    Do $$$AssertTrue(rejected,"Empty organization name rejected")
}
}
