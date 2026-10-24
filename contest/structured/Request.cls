Class Contest.StructuredRequest Extends Ens.Request
{
Property BatchId As %String(MAXLEN = 64);
Property Route As %String(VALUELIST = ",A,B,C");
Property Format As %String(VALUELIST = ",fhir-r4,json-object");
Property PayloadJson As %String(MAXLEN = 100000);
Storage Default
{
<Data name="StructuredRequestDefaultData">
<Subscript>"StructuredRequest"</Subscript>
<Value name="1">
<Value>BatchId</Value>
</Value>
<Value name="2">
<Value>Route</Value>
</Value>
<Value name="3">
<Value>Format</Value>
</Value>
<Value name="4">
<Value>PayloadJson</Value>
</Value>
</Data>
<DefaultData>StructuredRequestDefaultData</DefaultData>
<Type>%Storage.Persistent</Type>
}
}
