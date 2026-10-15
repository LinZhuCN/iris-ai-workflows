Class Contest.Event Extends %Persistent
{
Property CaseId As %Integer [ Required ];
Property Stage As %String;
Property Detail As %String(MAXLEN = 10000);
Property At As %TimeStamp [ InitialExpression = {$ZDATETIME($HOROLOG,3)} ];

ClassMethod Add(caseId As %Integer, stage As %String, detail As %String = "") As %Status
{
    Set event = ..%New()
    Set event.CaseId = caseId, event.Stage = stage, event.Detail = detail
    Quit event.%Save()
}
}
