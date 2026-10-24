Class Contest.DeclarationReviewRequest Extends Ens.Request
{
Property RecordId As %String(MAXLEN = 100);
Property TaskId As %String(MAXLEN = 100);
Property DeclarationDigest As %String(MAXLEN = 64);
Property AuthorizationHash As %String(MAXLEN = 64);
Storage Default
{
<Data name="DeclarationReviewRequestDefaultData">
<Subscript>"DeclarationReviewRequest"</Subscript>
<Value name="1"><Value>RecordId</Value></Value>
<Value name="2"><Value>TaskId</Value></Value>
<Value name="3"><Value>DeclarationDigest</Value></Value>
<Value name="4"><Value>AuthorizationHash</Value></Value>
</Data>
<DefaultData>DeclarationReviewRequestDefaultData</DefaultData>
<Type>%Storage.Persistent</Type>
}
}
