Class Contest.DevTests Extends %UnitTest.TestProduction
{
Parameter PRODUCTION = "Contest.Production";

Method TestControl() As %Status
{
    Quit $$$OK
}

/// Complete known-code synthetic messages expose only safe boolean facts.
Method TestCompleteFacts()
{
    Set facts = ##class(Contest.Facts).Inspect("{""reference"":""synthetic"",""code"":""OBS"",""value"":""42""}")
    Do $$$AssertEquals(facts.%Get("has_required_fields"),1)
    Do $$$AssertEquals(facts.%Get("known_code"),1)
    Do $$$AssertEquals(facts.%IsDefined("reference"),0)
    Do $$$AssertEquals(facts.%IsDefined("value"),0)
}

/// Missing fields and unknown codes must not be reported as delivery-ready.
Method TestIncompleteAndUnknownFacts()
{
    Set facts = ##class(Contest.Facts).Inspect("{""reference"":""synthetic"",""code"":""OTHER""}")
    Do $$$AssertEquals(facts.%Get("has_required_fields"),0)
    Do $$$AssertEquals(facts.%Get("known_code"),0)
}

/// A developer or Agent without a bound BP request cannot read arbitrary cases.
Method TestUnboundToolDenied()
{
    Set denied = 0
    Try {
        Set facts = ##class(Contest.Facts).GetTriageFacts("999999999")
    } Catch ex {
        Set denied = ex.DisplayString() [ "outside the current request"
    }
    Do $$$AssertTrue(denied)
}
}
