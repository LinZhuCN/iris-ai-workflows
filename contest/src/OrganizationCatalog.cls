Class Contest.OrganizationCatalog
{
ClassMethod Access(write As %Boolean = 0)
{
    If ($Namespace'="TRIAGE")||('$System.Security.Check($Select(write:"ContestMonitorDeploy",1:"ContestMonitorRead"),"U")) Do ##class(Demo.Protocol).Fail("Organization catalog permission required")
}

ClassMethod Presets() As %DynamicArray
{
    Quit [
      {"id":"hospital","name":"Synthetic source hospital","partner":"DemoHospital","type":"hospital","parent_id":"","responsibilities":"Provide hospital care and coordinate referrals for synthetic patients.","purpose":"Source of the fixed synthetic referral and quality cohort.","relationship":"same_covered_entity","allowed_fields":["patient_id","name","mrn","birthDate","status"],"prohibited_fields":[],"requirements":"A simulated HIPAA covered hospital. Synthetic demo data only: ordinary patient records of the same referred patient and care episode. No psychotherapy notes, specially restricted data or conflicting prohibition is stipulated."},
      {"id":"quality","name":"Hospital quality department","partner":"DemoQuality","type":"quality_department","parent_id":"hospital","responsibilities":"Perform internal quality statistics within the source hospital.","purpose":"Internal quality improvement for the same synthetic care episode.","relationship":"same_covered_entity","allowed_fields":["patient_id","birthYear","status"],"prohibited_fields":["name","mrn","birthDate"],"requirements":"Local minimization rule: use a local patient code and year-only date. Hospital internal operations; not a de-identification claim."},
      {"id":"research","name":"Synthetic external research center","partner":"DemoResearch","type":"research_center","parent_id":"","responsibilities":"Perform external statistical research, not patient treatment.","purpose":"External statistical research using exports declared deidentified under Safe Harbor.","relationship":"external","allowed_fields":["birthYear","status"],"prohibited_fields":["patient_id","name","mrn","birthDate"],"requirements":"The selected release path is Safe Harbor, not Expert Determination. Direct identifiers and full birth dates must not be included. No alternative PHI release basis is stipulated. This is a demo receiving agreement, not itself legal authorization."},
      {"id":"clinic","name":"Synthetic external treating clinic","partner":"DemoClinic","type":"clinic","parent_id":"","responsibilities":"Treat the referred synthetic patient.","purpose":"Actual treatment of the same patient and referral episode represented by the message.","relationship":"another_provider","allowed_fields":["patient_id","name","mrn","birthDate","status"],"prohibited_fields":[],"requirements":"Ordinary provider-treatment disclosure. No individual authorization is relied upon, no special data or conflicting restriction is stipulated. Access is limited to the treating team. No de-identification claim."}
    ]
}

ClassMethod Validate(p As %DynamicObject)
{
    Do ##class(Contest.RouteGovernance).Shape(p,"id,name,partner,type,parent_id,responsibilities,purpose,relationship,allowed_fields,prohibited_fields,requirements")
    Do ##class(Contest.DeclarationCatalog).Choice(p,"id",["hospital","quality","research","clinic"])
    Do ##class(Contest.DeclarationCatalog).Choice(p,"relationship",["same_covered_entity","another_provider","external"])
    For field="name","partner","type" Do ##class(Contest.RouteGovernance).Text(p,field,160)
    For field="responsibilities","purpose","requirements" Do ##class(Contest.RouteGovernance).Text(p,field,1000)
    If (p.%GetTypeOf("parent_id")'="string")||('$Match(p.%Get("parent_id"),"^(hospital|quality|research|clinic)?$")) Do ##class(Demo.Protocol).Fail("Unknown parent organization")
    If p.%Get("parent_id")=p.id Do ##class(Demo.Protocol).Fail("An organization cannot be its own parent")
    If '$Match(p.partner,"^[A-Za-z][A-Za-z0-9_-]{0,79}$") Do ##class(Demo.Protocol).Fail("Stable Business Partner key required")
    For field="allowed_fields","prohibited_fields" {
        If p.%GetTypeOf(field)'="array" Do ##class(Demo.Protocol).Fail("Field list required")
        Set list=p.%Get(field), seen={}
        If list.%Size()>20 Do ##class(Demo.Protocol).Fail("Too many fields")
        For i=0:1:list.%Size()-1 {
            Set key=list.%Get(i)
            If (list.%GetTypeOf(i)'="string")||('$Match(key,"^[A-Za-z][A-Za-z0-9_.]{0,79}$"))||seen.%IsDefined(key) Do ##class(Demo.Protocol).Fail("Unique field names required")
            Do seen.%Set(key,1)
        }
    }
    For i=0:1:p.%Get("allowed_fields").%Size()-1 {
        For j=0:1:p.%Get("prohibited_fields").%Size()-1 {
            If p.%Get("allowed_fields").%Get(i)=p.%Get("prohibited_fields").%Get(j) Do ##class(Demo.Protocol).Fail("A field cannot be allowed and prohibited")
        }
    }
}

ClassMethod Read(id As %String, revision As %Integer = 0) As %DynamicObject
{
    Do ..Access()
    If '$Match(id,"^(hospital|quality|research|clinic)$") Do ##class(Demo.Protocol).Fail("Known organization required")
    If revision=0 Set revision=+$Get(^ContestOrganizations("latest",id))
    If '$Data(^ContestOrganizations("record",id,revision)) Do ##class(Demo.Protocol).Fail("Confirmed organization profile missing: "_id)
    Set record={}.%FromJSON(^ContestOrganizations("record",id,revision))
    If record.hash'=##class(Contest.ExportEvidence).Digest(record.profile) Do ##class(Demo.Protocol).Fail("Organization profile integrity mismatch")
    Quit record
}

ClassMethod List() As %DynamicObject
{
    Do ..Access()
    Set items=[], id=""
    For { Set id=$Order(^ContestOrganizations("latest",id)) Quit:id=""  Do items.%Push(..Read(id)) }
    Set result={"items":(items),"presets":(..Presets()),"can_manage":false}
    Do result.%Set("can_manage",$System.Security.Check("ContestMonitorDeploy","U")=1,"boolean")
    Quit result
}

ClassMethod Save(body As %DynamicObject) As %DynamicObject
{
    Do ..Access(1), ##class(Contest.RouteGovernance).Shape(body,"profile,expected_revision,confirmed")
    If (body.%GetTypeOf("confirmed")'="boolean")||('body.confirmed) Do ##class(Demo.Protocol).Fail("Confirm synthetic scenario profile")
    Do ..Validate(body.profile), ##class(Contest.ProductionFlow).Integer(body,"expected_revision",0,100000)
    Set p=body.profile, id=p.id
    Lock +^ContestOrganizations("lock"):3
    If '$Test Do ##class(Demo.Protocol).Fail("Organization catalog busy")
    Try {
        Set current=+$Get(^ContestOrganizations("latest",id))
        If current'=body.%Get("expected_revision") Do ##class(Demo.Protocol).Fail("Organization revision changed; reload before saving")
        Set other=""
        For {
            Set other=$Order(^ContestOrganizations("latest",other)) Quit:other=""
            If (other'=id)&&(..Read(other).profile.partner=p.partner) Do ##class(Demo.Protocol).Fail("Business Partner already belongs to another organization")
        }
        Set record={"id":(id),"revision":(current+1),"profile":(p),"confirmed_by":($Username),"confirmed_at":(##class(Demo.Protocol).Now()),"hash":(##class(Contest.ExportEvidence).Digest(p))}
        TStart
        Set ^ContestOrganizations("record",id,current+1)=record.%ToJSON(), ^ContestOrganizations("latest",id)=current+1
        TCommit
    } Catch ex { If $TLevel TRollback 1
        Lock -^ContestOrganizations("lock") Throw ex
    }
    Lock -^ContestOrganizations("lock")
    Do ##class(Contest.KnowledgeService).Audit("organization.confirmed",id,"revision "_record.revision)
    Quit record
}
}
