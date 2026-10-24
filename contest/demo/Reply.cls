Class Demo.Reply Extends Ens.Response
{
Property Outcome As %String;
Property ObservationId As %String(MAXLEN = 128);
Property MessageId As %String;
Property SessionId As %String;

Storage Default
{
<Type>%Storage.Persistent</Type>
<DefaultData>ReplyDefaultData</DefaultData>
<Data name="ReplyDefaultData">
<Structure>listnode</Structure>
<Subscript>"Reply"</Subscript>
<Value name="1">
<Value>Outcome</Value>
</Value>
<Value name="2">
<Value>ObservationId</Value>
</Value>
<Value name="3">
<Value>MessageId</Value>
</Value>
<Value name="4">
<Value>SessionId</Value>
</Value>
</Data>
}
}
