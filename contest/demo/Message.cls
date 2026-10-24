Class Demo.Message Extends Ens.Request
{
Property ExternalId As %String(MAXLEN = 128);
Property Scenario As %String(VALUELIST = ",treatment,analytics,failure");
}
