Class Contest.Destination Extends %Persistent
{
Property CaseId As %Integer [ Required ];
Property Queue As %String;
Property Payload As %String(MAXLEN = 10000);
Property At As %TimeStamp [ InitialExpression = {$ZDATETIME($HOROLOG,3)} ];
Index OneDestination On CaseId [ Unique ];
}
