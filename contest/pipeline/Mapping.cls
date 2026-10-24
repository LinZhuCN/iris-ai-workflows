Class Contest.Aggregation.Mapping
{
ClassMethod Shape(value, keys As %String)
{
    If '$IsObject(value) Do ##class(Demo.Protocol).Fail("Source object required")
    If 'value.%IsA("%DynamicObject") Do ##class(Demo.Protocol).Fail("Source object required")
    If value.%Size()'=$Length(keys,",") Do ##class(Demo.Protocol).Fail("Exact source schema required")
    For i=1:1:$Length(keys,",") {
        If 'value.%IsDefined($Piece(keys,",",i)) Do ##class(Demo.Protocol).Fail("Missing source column")
    }
}
ClassMethod Date(value As %String)
{
    If '$Match(value,"^[0-9]{4}-[0-9]{2}-[0-9]{2}$") Do ##class(Demo.Protocol).Fail("ISO source date required")
    If $ZDATE($ZDATEH(value,3),3)'=value Do ##class(Demo.Protocol).Fail("Invalid source date")
}

ClassMethod Build(source As %DynamicObject) As %DynamicObject
{
    Set bundle={"resourceType":"Bundle","type":"transaction","entry":[]}
    Do ..Shape(source,"patients,encounters,diagnoses,medications")
    Kill patients,encounters,seen
    For kind="patients","encounters","diagnoses","medications" {
        Set rows=source.%Get(kind), columns=##class(Contest.Aggregation.Data).Columns(kind)
        If '$IsObject(rows) Do ##class(Demo.Protocol).Fail("Source row arrays required")
        If 'rows.%IsA("%DynamicArray") Do ##class(Demo.Protocol).Fail("Source row arrays required")
        If (rows.%Size()<1)||(rows.%Size()>20) Do ##class(Demo.Protocol).Fail("Bounded nonempty source required")
        For i=0:1:rows.%Size()-1 {
            Set row=rows.%Get(i)
            Do ..Shape(row,columns)
            For j=1:1:5 {
                Set field=$Piece(columns,",",j)
                If (row.%GetTypeOf(field)'="string")||($Length(row.%Get(field))>128)||($ZStrip(row.%Get(field),"<>W")="") Do ##class(Demo.Protocol).Fail("Nonempty bounded source strings required")
            }
            If '$Match(row.ID,"^agg-[A-Za-z0-9-]{1,50}$") Do ##class(Demo.Protocol).Fail("Only synthetic resource identities supported")
            If $Data(seen(kind,row.ID)) Do ##class(Demo.Protocol).Fail("Duplicate source identity")
            Set seen(kind,row.ID)=1
            If kind="patients" {
                Do ..Date(row.BirthDate)
                Set patients(row.ID)=1, resource={"resourceType":"Patient","id":(row.ID),"identifier":[{"system":"https://synthetic.example.invalid/mrn","value":(row.MRN)}],"name":[{"family":(row.FamilyName),"given":[(row.GivenName)]}],"birthDate":(row.BirthDate)}
            } Else {
                If '$Data(patients(row.PatientID)) Do ##class(Demo.Protocol).Fail("Orphan patient reference")
                Set subject={"reference":("Patient/"_row.PatientID)}
                If kind="encounters" {
                    Do ..Date(row.StartDate)
                    If (row.Status'="finished")||(row.ClassCode'="AMB") Do ##class(Demo.Protocol).Fail("Unsupported synthetic encounter state")
                    Set encounters(row.ID)=row.PatientID, resource={"resourceType":"Encounter","id":(row.ID),"status":(row.Status),"class":{"system":"http://terminology.hl7.org/CodeSystem/v3-ActCode","code":(row.ClassCode)},"subject":(subject),"period":{"start":(row.StartDate)}}
                } Else {
                    If $Get(encounters(row.EncounterID))'=row.PatientID Do ##class(Demo.Protocol).Fail("Orphan or mismatched encounter reference")
                    Set encounter={"reference":("Encounter/"_row.EncounterID)}, code={"coding":[{"system":"https://synthetic.example.invalid/codes","code":(row.Code),"display":(row.Display)}]}
                    If kind="diagnoses" {
                        Set resource={"resourceType":"Condition","id":(row.ID),"clinicalStatus":{"coding":[{"system":"http://terminology.hl7.org/CodeSystem/condition-clinical","code":"active"}]},"code":(code),"subject":(subject),"encounter":(encounter)}
                    } Else {
                        Set resource={"resourceType":"MedicationRequest","id":(row.ID),"status":"active","intent":"order","medicationCodeableConcept":(code),"subject":(subject),"encounter":(encounter)}
                    }
                }
            }
            Set url=resource.resourceType_"/"_resource.id
            Do bundle.entry.%Push({"fullUrl":("https://synthetic.example.invalid/fhir/"_url),"resource":(resource),"request":{"method":"PUT","url":(url)}})
        }
    }
    Quit bundle
}

ClassMethod ValidateResponse(bundle As %DynamicObject, response As %DynamicObject)
{
    If (response.%Get("resourceType")'="Bundle")||(response.%Get("type")'="transaction-response") Do ##class(Demo.Protocol).Fail("FHIR transaction response required")
    If response.entry.%Size()'=bundle.entry.%Size() Do ##class(Demo.Protocol).Fail("Incomplete FHIR transaction response")
    For i=0:1:bundle.entry.%Size()-1 {
        Set entry=response.entry.%Get(i).response, status=$Piece(entry.status," ",1), expected=bundle.entry.%Get(i).request.url
        If '((status="200")||(status="201")) Do ##class(Demo.Protocol).Fail("FHIR transaction entry failed")
        Set location=entry.location, base="http://gateway/csp/healthshare/fhirdemo/fhir/r4/"
        If $Extract(location,1,$Length(base))=base Set location=$Extract(location,$Length(base)+1,*)
        If $Piece(location,"/_history/",1)'=expected Do ##class(Demo.Protocol).Fail("FHIR response resource identity mismatch")
        If location=expected {
            If '$Match(entry.%Get("etag"),"^W/""[A-Za-z0-9.-]+""$") Do ##class(Demo.Protocol).Fail("FHIR response version required")
        } Else {
            If ('$Match($Piece(location,"/_history/",2),"^[A-Za-z0-9.-]+$"))||($Length(location,"/_history/")'=2) Do ##class(Demo.Protocol).Fail("Invalid FHIR response version")
        }
    }
}

ClassMethod EqualValue(expected, actual) As %Boolean
{
    If $IsObject(expected) {
        If '$IsObject(actual) Quit 0
        If expected.%IsA("%DynamicArray") {
            If 'actual.%IsA("%DynamicArray") Quit 0
            If expected.%Size()'=actual.%Size() Quit 0
            For i=0:1:expected.%Size()-1 {
                If '..EqualValue(expected.%Get(i),actual.%Get(i)) Return 0
            }
        } Else {
            If 'actual.%IsA("%DynamicObject") Quit 0
            Set iterator=expected.%GetIterator()
            While iterator.%GetNext(.key,.value) {
                If 'actual.%IsDefined(key) Return 0
                If '..EqualValue(value,actual.%Get(key)) Return 0
            }
        }
        Quit 1
    }
    If $IsObject(actual) Quit 0
    Quit expected=actual
}
}
