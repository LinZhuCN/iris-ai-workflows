Class Contest.Aggregation.SendRequest Extends Ens.Request
{
Property BatchId As %String(MAXLEN = 64);
Property ApprovalId As %String(MAXLEN = 100);
Property ScopeHash As %String(MAXLEN = 64);
Property Bundle As %String(MAXLEN = 100000);
Storage Default
{
<Data name="SendRequestDefaultData">
<Subscript>"SendRequest"</Subscript>
<Value name="1"><Value>BatchId</Value></Value>
<Value name="2"><Value>ApprovalId</Value></Value>
<Value name="3"><Value>ScopeHash</Value></Value>
<Value name="4"><Value>Bundle</Value></Value>
</Data>
<DefaultData>SendRequestDefaultData</DefaultData>
<Type>%Storage.Persistent</Type>
}
}
