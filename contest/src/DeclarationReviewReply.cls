Class Contest.DeclarationReviewReply Extends Ens.Response
{
Property TaskId As %String(MAXLEN = 100);
Property Outcome As %String(MAXLEN = 40);
Property ReportId As %String(MAXLEN = 100);
Storage Default
{
<Data name="DeclarationReviewReplyDefaultData">
<Subscript>"DeclarationReviewReply"</Subscript>
<Value name="1"><Value>TaskId</Value></Value>
<Value name="2"><Value>Outcome</Value></Value>
<Value name="3"><Value>ReportId</Value></Value>
</Data>
<DefaultData>DeclarationReviewReplyDefaultData</DefaultData>
<Type>%Storage.Persistent</Type>
}
}
