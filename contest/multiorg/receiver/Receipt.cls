Class MultiOrg.Receiver.Receipt Extends %Persistent
{
Property DeliveryId As %String(MAXLEN = 64) [ Required ];
Property PayloadHash As %String(MAXLEN = 64) [ Required ];
Property RawPayload As %String(MAXLEN = 32000) [ Required ];
Property PatientId As %String(MAXLEN = 64) [ SqlFieldName = patient_id ];
Property birthYear As %Integer;
Property status As %String(MAXLEN = 64);
Index DeliveryKey On DeliveryId [ PrimaryKey, Unique ];
}
