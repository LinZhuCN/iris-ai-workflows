Class Contest.Aggregation.Reply Extends Ens.Response
{
Property BatchId As %String(MAXLEN = 64);
Property Outcome As %String(MAXLEN = 40);
Property Receipt As %String(MAXLEN = 100000);
Storage Default
{
<Data name="ReplyDefaultData">
<Subscript>"Reply"</Subscript>
<Value name="1"><Value>BatchId</Value></Value>
<Value name="2"><Value>Outcome</Value></Value>
<Value name="3"><Value>Receipt</Value></Value>
</Data>
<DefaultData>ReplyDefaultData</DefaultData>
<Type>%Storage.Persistent</Type>
}
}
