Class Contest.StructuredProcess Extends Ens.BusinessProcess
{
Property Target As %String;
Parameter SETTINGS = "Target";
Method OnRequest(request As Contest.StructuredRequest, Output response As Contest.Aggregation.Reply) As %Status
{
    Quit ..SendRequestSync(..Target,request,.response,30)
}
Storage Default
{
<Data name="StructuredProcessDefaultData">
<Subscript>"StructuredProcess"</Subscript>
<Value name="1">
<Value>Target</Value>
</Value>
</Data>
<DefaultData>StructuredProcessDefaultData</DefaultData>
<Type>%Storage.Persistent</Type>
}
}
