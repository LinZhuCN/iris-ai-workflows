Class Contest.M5.Request Extends Ens.Request
{
Property BatchId As %String(MAXLEN = 64);
Property Route As %String(VALUELIST = ",A,B,C,D");
Property Format As %String(VALUELIST = ",json-object");
Property PayloadJson As %String(MAXLEN = 100000);
}
