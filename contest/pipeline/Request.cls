Class Contest.Aggregation.Request Extends Ens.Request
{
Property BatchId As %String(MAXLEN = 64);
Property ApprovalId As %String(MAXLEN = 100);
Property ScopeHash As %String(MAXLEN = 64);
Storage Default
{
<Data name="RequestDefaultData">
<Subscript>"Request"</Subscript>
<Value name="1"><Value>BatchId</Value></Value>
<Value name="2"><Value>ApprovalId</Value></Value>
<Value name="3"><Value>ScopeHash</Value></Value>
</Data>
<DefaultData>RequestDefaultData</DefaultData>
<Type>%Storage.Persistent</Type>
}
}
