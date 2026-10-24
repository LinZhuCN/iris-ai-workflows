Class Contest.Multi.SendRequest Extends Ens.Request
{
Property RunId As %String(MAXLEN = 64);
Property Branch As %String;
Property DeliveryId As %String(MAXLEN = 64);
Property Payload As %String(MAXLEN = 16000);
}
