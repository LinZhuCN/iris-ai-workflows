Class Contest.AggregationTests Extends %UnitTest.TestProduction
{
Parameter PRODUCTION = "Contest.Production";
Method TestControl() As %Status { Quit $$$OK }

Method TestActualMappingAndReferences()
{
    Set source=##class(Contest.Aggregation.Data).Fixture()
    Set bundle=##class(Contest.Aggregation.Mapping).Build(source)
    Do $$$AssertEquals(bundle.type,"transaction")
    Do $$$AssertEquals(bundle.entry.%Size(),8)
    Set patient=bundle.entry.%Get(0).resource, encounter=bundle.entry.%Get(2).resource
    Do $$$AssertEquals(patient.name.%Get(0).family,"SYNTHETIC-A")
    Do $$$AssertEquals(patient.birthDate,"1980-01-02")
    Do $$$AssertEquals(encounter.subject.reference,"Patient/agg-p1")
    Do $$$AssertEquals(bundle.entry.%Get(4).resource.encounter.reference,"Encounter/agg-e1")
    Do $$$AssertEquals(bundle.entry.%Get(6).resource.intent,"order")
    Do source.patients.%Get(0).%Set("FamilyName","SYNTHETIC-CHANGED")
    Set changed=##class(Contest.Aggregation.Mapping).Build(source)
    Do $$$AssertEquals(changed.entry.%Get(0).resource.name.%Get(0).family,"SYNTHETIC-CHANGED")
    Do $$$AssertTrue(##class(Contest.ExportEvidence).Digest(changed)'=##class(Contest.ExportEvidence).Digest(bundle))
}

Method TestInvalidSourcesFail()
{
    For variant="orphan","duplicate","date","empty" {
        Set source=##class(Contest.Aggregation.Data).Fixture(), rejected=0
        If variant="orphan" Do source.encounters.%Get(0).%Set("PatientID","absent")
        If variant="duplicate" Do source.patients.%Push(source.patients.%Get(0))
        If variant="date" Do source.patients.%Get(0).%Set("BirthDate","1980-02-31")
        If variant="empty" Set source.patients=[]
        Try { Set bundle=##class(Contest.Aggregation.Mapping).Build(source) } Catch ex { Set rejected=1 }
        Do $$$AssertTrue(rejected,variant)
    }
}

Method TestResponseIsNotJustHTTP200()
{
    Set bundle=##class(Contest.Aggregation.Mapping).Build(##class(Contest.Aggregation.Data).Fixture()), response={"resourceType":"Bundle","type":"transaction-response","entry":[]}
    For i=0:1:7 {
        Set request=bundle.entry.%Get(i).request
        Do response.entry.%Push({"response":{"status":"201 Created","location":(request.url_"/_history/1")}})
    }
    Do ##class(Contest.Aggregation.Mapping).ValidateResponse(bundle,response)
    Set absolute={}.%FromJSON(response.%ToJSON())
    For i=0:1:7 {
        Set expected=bundle.entry.%Get(i).request.url, item=absolute.entry.%Get(i).response
        Set item.location="http://gateway/csp/healthshare/fhirdemo/fhir/r4/"_expected, item.etag="W/""1"""
    }
    Do ##class(Contest.Aggregation.Mapping).ValidateResponse(bundle,absolute)
    For variant="partial","error","location" {
        Set changed={}.%FromJSON(response.%ToJSON()), rejected=0
        If variant="partial" Set changed.entry=[]
        If variant="error" Set changed.entry.%Get(0).response.status="400 Bad Request"
        If variant="location" Set changed.entry.%Get(0).response.location="Patient/other/_history/1"
        Try { Do ##class(Contest.Aggregation.Mapping).ValidateResponse(bundle,changed) } Catch ex { Set rejected=1 }
        Do $$$AssertTrue(rejected,variant)
    }

}

Method TestActualOutputScopeAndReadback()
{
    Set bundle=##class(Contest.Aggregation.Mapping).Build(##class(Contest.Aggregation.Data).Fixture()), fields=[]
    For i=0:1:bundle.entry.%Size()-1 {
        Set resource=bundle.entry.%Get(i).resource
        Do ##class(Contest.Aggregation.Runtime).Paths(resource,resource.resourceType,.fields)
    }
    Set dossier={"core":{"declaration":{"scope":{"resources":["Patient","Encounter","Condition","MedicationRequest"],"fields":(fields),"max_records":8}}}}
    Set check=##class(Contest.Aggregation.Runtime).Inspect(bundle,dossier)
    Do $$$AssertEquals(check.%Get("resource_counts").Patient,2)
    For variant="field","limit","resource" {
        Set changed={}.%FromJSON(bundle.%ToJSON()), limit={}.%FromJSON(dossier.%ToJSON()), rejected=0
        If variant="field" Set changed.entry.%Get(0).resource.telecom=[{"system":"phone","value":"SYNTHETIC"}]
        If variant="limit" Do limit.core.declaration.scope.%Set("max_records",7)
        If variant="resource" Do limit.core.declaration.scope.%Set("resources",["Patient"])
        Try { Set check=##class(Contest.Aggregation.Runtime).Inspect(changed,limit) } Catch ex { Set rejected=1 }
        Do $$$AssertTrue(rejected,variant)
    }
    Set expected=bundle.entry.%Get(0).resource, actual={}.%FromJSON(expected.%ToJSON())
    Set actual.meta={"versionId":"1"}
    Do $$$AssertTrue(##class(Contest.Aggregation.Mapping).EqualValue(expected,actual),"Server metadata is permitted")
    Set actual.birthDate="2000-01-01"
    Do $$$AssertTrue('##class(Contest.Aggregation.Mapping).EqualValue(expected,actual),"Changed mapped values are rejected")
}
}
