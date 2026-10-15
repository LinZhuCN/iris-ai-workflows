Class Contest.Case Extends %Persistent
{
Property ExternalId As %String(MAXLEN = 128) [ Required ];
Property Payload As %String(MAXLEN = 10000);
Property Facts As %String(MAXLEN = 10000);
Property Decision As %String;
Property Reason As %String(MAXLEN = 2000);
Property Policy As %String;
Property Outcome As %String;
Property Error As %String(MAXLEN = 10000);
Property RequestId As %String;
Property SessionId As %String;
Property AgentSession As %String;
Property Usage As %String(MAXLEN = 10000);
Property ProviderMode As %String;
Property Model As %String;
Property ElapsedMs As %Integer;
Property CreatedAt As %TimeStamp [ InitialExpression = {$ZDATETIME($HOROLOG,3)} ];
Index ExternalKey On ExternalId [ Unique ];

ClassMethod OpenByExternalId(externalId As %String) As Contest.Case
{
    Quit ..ExternalKeyOpen(externalId)
}
}
