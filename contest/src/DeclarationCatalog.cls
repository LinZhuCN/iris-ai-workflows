Class Contest.DeclarationCatalog
{
ClassMethod Get() As %DynamicObject
{
    Quit {"schema":1,"version":"declaration-catalog-v1","organization":{"organization_id":"DEMO-HOSPITAL","role":"simulated-covered-entity","synthetic":true},"recipients":[{"id":"local-analysis-receiver","name":"Internal quality team","relationship":"same-covered-entity","service_identity":"local-utilization-service","executable":true},{"id":"external-marketing-demo","name":"Simulated external marketing organization","relationship":"external","service_identity":"","executable":false},{"id":"unspecified-recipient","name":"Recipient not yet specified","relationship":"unknown","service_identity":"","executable":false}],"purpose_categories":["quality_improvement","treatment","research","marketing","other","unspecified"],"resources":["Patient","Encounter"],"fields":["Patient.id","Patient.name","Patient.identifier","Patient.birthDate","Encounter.id","Encounter.status","Encounter.class.system","Encounter.class.code","Encounter.subject.reference","Encounter.period.start"],"cohorts":["synthetic-four-resources-v1"],"recipes":[{"id":"year-and-encounter-v1","description":"Birth-year and encounter projection; seven fields, four resources.","executable":true},{"id":"retain-requested-fields","description":"Assess a proposed retained-field dataset; execution is not connected.","executable":false}],"identifiability":["identifiable","linkable","claimed_deidentified","unspecified"],"arrangement_statuses":["not_specified","not_relied_upon","declared_available"],"model_calls":0}
}

ClassMethod Choice(value, field As %String, allowed As %DynamicArray)
{
    Do ##class(Contest.RouteGovernance).Text(value,field)
    Set found=0
    For i=0:1:allowed.%Size()-1 {
        If value.%Get(field)=allowed.%Get(i) Set found=1
    }
    If 'found Do ##class(Demo.Protocol).Fail("Unknown declaration selection: "_field)
}

ClassMethod Recipient(id As %String) As %DynamicObject
{
    Set catalog=..Get()
    For i=0:1:catalog.recipients.%Size()-1 {
        Set recipient=catalog.recipients.%Get(i)
        If recipient.id=id Quit
    }
    If recipient.id'=id Do ##class(Demo.Protocol).Fail("Registered synthetic recipient required")
    Quit recipient
}

ClassMethod Scope(values, allowed As %DynamicArray)
{
    Do ##class(Contest.RouteGovernance).Names(values)
    For i=0:1:values.%Size()-1 {
        Set found=0
        For j=0:1:allowed.%Size()-1 {
            If values.%Get(i)=allowed.%Get(j) Set found=1
        }
        If 'found Do ##class(Demo.Protocol).Fail("Requested data outside declaration catalog: "_values.%Get(i))
    }
}

ClassMethod Validate(proposal As %DynamicObject)
{
    Do ##class(Contest.RouteGovernance).Shape(proposal,"schema,synthetic,title,owner,purpose,recipient_id,data,handling,arrangements,validity")
    If (proposal.%GetTypeOf("schema")'="number")||(proposal.schema'=1)||(proposal.%GetTypeOf("synthetic")'="boolean")||('proposal.synthetic) Do ##class(Demo.Protocol).Fail("Synthetic declaration schema 1 required")
    Do ##class(Contest.RouteGovernance).Text(proposal,"title",200), ##class(Contest.RouteGovernance).Text(proposal,"owner",200)
    Set catalog=..Get(), purpose=proposal.purpose, data=proposal.data, handling=proposal.handling, arrangements=proposal.arrangements
    Do ##class(Contest.RouteGovernance).Shape(purpose,"category,text,activities,expected_output")
    Do ..Choice(purpose,"category",catalog.%Get("purpose_categories"))
    For field="text","activities","expected_output" Do ##class(Contest.RouteGovernance).Text(purpose,field,2000)
    Do ##class(Contest.RouteGovernance).Text(proposal,"recipient_id")
    Set recipient=..Recipient(proposal.%Get("recipient_id"))
    Do ##class(Contest.RouteGovernance).Shape(data,"resources,fields,cohort,max_records,necessity")
    Do ..Scope(data.resources,catalog.resources), ..Scope(data.fields,catalog.fields), ..Choice(data,"cohort",catalog.cohorts)
    Do ##class(Contest.RouteGovernance).Text(data,"necessity",2000)
    If (data.%GetTypeOf("max_records")'="number")||(data.%Get("max_records")<1)||(data.%Get("max_records")>10000)||((data.%Get("max_records")\1)'=data.%Get("max_records")) Do ##class(Demo.Protocol).Fail("Integer declaration record limit from 1 to 10000 required")
    For i=0:1:data.fields.%Size()-1 {
        Set found=0
        For j=0:1:data.resources.%Size()-1 {
            If $Piece(data.fields.%Get(i),".",1)=data.resources.%Get(j) Set found=1
        }
        If 'found Do ##class(Demo.Protocol).Fail("Field resource is outside requested resources")
    }
    Do ##class(Contest.RouteGovernance).Shape(handling,"recipe_id,identifiability,access,retention,onward_sharing")
    Do ..Choice(handling,"recipe_id",["year-and-encounter-v1","retain-requested-fields"]), ..Choice(handling,"identifiability",catalog.identifiability)
    For field="access","retention","onward_sharing" Do ##class(Contest.RouteGovernance).Text(handling,field,1000)
    Do ##class(Contest.RouteGovernance).Shape(arrangements,"status,details"), ..Choice(arrangements,"status",catalog.%Get("arrangement_statuses"))
    If (arrangements.%GetTypeOf("details")'="string")||($Length(arrangements.details)>2000) Do ##class(Demo.Protocol).Fail("Bounded arrangement details required")
    If arrangements.status="declared_available" Do ##class(Contest.RouteGovernance).Text(arrangements,"details",2000)
    Do ##class(Contest.RouteGovernance).Shape(proposal.validity,"from,until")
    If (proposal.validity.%GetTypeOf("from")'="number")||(proposal.validity.%GetTypeOf("until")'="number") Do ##class(Demo.Protocol).Fail("Numeric declaration validity required")
    Do ##class(Contest.RouteGovernance).Validity(proposal.validity.from,proposal.validity.until)
}

ClassMethod Capability(proposal As %DynamicObject) As %DynamicObject
{
    Do ..Validate(proposal)
    Set required=["Patient.id","Patient.birthDate","Encounter.id","Encounter.status","Encounter.class.system","Encounter.class.code","Encounter.subject.reference"]
    Set fields=proposal.data.fields, supported=1
    For i=0:1:required.%Size()-1 {
        Set found=0
        For j=0:1:fields.%Size()-1 {
            If required.%Get(i)=fields.%Get(j) Set found=1
        }
        If 'found Set supported=0
    }
    If (fields.%Size()'=7)||(proposal.data.resources.%Size()'=2)||(proposal.data.%Get("max_records")'=4)||(proposal.%Get("recipient_id")'="local-analysis-receiver")||(proposal.handling.%Get("recipe_id")'="year-and-encounter-v1") Set supported=0
    Quit {"state":($Select(supported:"supported",1:"unsupported")),"reason":($Select(supported:"Four-resource, seven-field year/encounter projection to the registered internal SQL receiver; exact review and human approval required.",1:"This proposed use can be assessed but has no connected execution recipe.")),"model_calls":0}
}

}
