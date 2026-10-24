Class Contest.RouteUI
{
ClassMethod Access(write As %Boolean = 0) [ Private ]
{
    If $Namespace'="TRIAGE" Do ##class(Demo.Protocol).Fail("TRIAGE governance UI required")
    If '$System.Security.Check($Select(write:"ContestMonitorDeploy",1:"ContestMonitorRead"),"U") Do ##class(Demo.Protocol).Fail("Route governance capability required")
}

ClassMethod RuntimeBinding() As %DynamicObject [ Private ]
{
    Set previous=$Namespace
    Try {
        Set $Namespace="UTILIZATION", value=##class(Contest.Utilization.Runtime).Binding()
    } Catch ex { Set $Namespace=previous Throw ex }
    Set $Namespace=previous
    Quit value
}

ClassMethod Template() As %DynamicObject
{
    Do ..Access(1)
    Set binding=..RuntimeBinding(), now=##class(Demo.Protocol).Now()\1
    Set declaration={"schema":1,"synthetic":true,"route_id":"demo-quality-improvement","revision":1,"kind":"utilization","purpose_code":"internal-quality-improvement","purpose_text":"The DEMO-HOSPITAL internal quality team compares encounter classes by birth-year cohort to improve hospital services. This is internal quality improvement, not research for generalizable knowledge or external commercial reuse. Approved stable references permit linkage within this project; no de-identification claim.","owner":"demo-quality-office","service_identity":"local-utilization-service","recipient":"local-analysis-receiver","scope":{"resources":["Patient","Encounter"],"fields":["Patient.id","Patient.birthDate","Encounter.id","Encounter.status","Encounter.class.system","Encounter.class.code","Encounter.subject.reference"],"patient_selection":"synthetic-four-resources-v1","max_records":4}}
    Quit {"declaration":(declaration),"binding":(binding),"valid_from":(now),"valid_until":(now+2592000),"runtime_activation":"not_performed"}
}

ClassMethod List(after As %String = "") As %DynamicObject
{
    Do ..Access()
    If (after'="")&&('$Match(after,"^route-[A-Za-z0-9-]{1,80}$")) Do ##class(Demo.Protocol).Fail("Bounded registry cursor required")
    Set records=[], id=after, cursor=""
    For i=1:1:25 {
        Set id=$Order(^ContestRouteGovernance("record",id))
        If id="" Quit
        Do records.%Push(##class(Contest.RouteGovernance).Read(id))
    }
    If id'="" {
        If $Order(^ContestRouteGovernance("record",id))'="" Set cursor=id
    }
    Quit {"records":(records),"next_cursor":(cursor),"user":($Username),"can_write":($System.Security.Check("ContestMonitorDeploy","U")),"runtime_activation":"not_performed","model_calls":0}
}

ClassMethod Recipe(declaration As %DynamicObject, template As %DynamicObject) [ Private ]
{
    Do ##class(Contest.RouteGovernance).Validate(declaration,template.binding)
    For field="schema","synthetic","kind","purpose_code","service_identity","recipient" {
        If declaration.%Get(field)'=template.declaration.%Get(field) Do ##class(Demo.Protocol).Fail("Only the fixed synthetic utilization recipe can be registered here")
    }
    If declaration.scope.%ToJSON()'=template.declaration.scope.%ToJSON() Do ##class(Demo.Protocol).Fail("Scope must match the fixed four-resource seven-field recipe; this UI does not change the exporter")
}

ClassMethod ValidateProposal(body As %DynamicObject)
{
    Do ##class(Contest.RouteGovernance).Shape(body,"declaration,valid_from,valid_until,expected_config_hash")
    Set template=..Template()
    Do ..Recipe(body.declaration,template)
    If body.%Get("expected_config_hash")'=template.binding.%Get("config_hash") Do ##class(Demo.Protocol).Fail("Production configuration changed; reload the proposal template")
    For field="valid_from","valid_until" {
        If body.%GetTypeOf(field)'="number" Do ##class(Demo.Protocol).Fail("Numeric UTC validity bounds required")
    }
    Do ##class(Contest.RouteGovernance).Validity(body.%Get("valid_from"),body.%Get("valid_until"))
    Set now=##class(Demo.Protocol).Now(), span=body.%Get("valid_until")-body.%Get("valid_from")
    If (body.%Get("valid_from")>now)||(body.%Get("valid_from")<(now-86400))||(body.%Get("valid_until")<=now)||(span<86400)||(span>2592000)||((span#86400)'=0) Do ##class(Demo.Protocol).Fail("Proposal validity must start within the last day and last 1 to 30 whole days")
}

ClassMethod Register(body As %DynamicObject) As %DynamicObject
{
    Do ..Access(1), ..ValidateProposal(body)
    Set route=body.declaration.%Get("route_id"), revision=body.declaration.revision
    Lock +^ContestRouteGovernance("uiLock",route):2
    If '$Test Do ##class(Demo.Protocol).Fail("Route registration busy")
    Try {
        Set latest=$Order(^ContestRouteGovernance("revision",route,""),-1)
        If latest'="" {
            Set previous=##class(Contest.RouteGovernance).Read(^ContestRouteGovernance("revision",route,latest))
            If previous.core.declaration.kind'="utilization" Do ##class(Demo.Protocol).Fail("Preset aggregation routes are read-only here")
        }
        If (latest'="")&&(revision'=(latest+1))&&('$Data(^ContestRouteGovernance("revision",route,revision))) Do ##class(Demo.Protocol).Fail("Stale route revision; choose the next immutable revision")
        If (latest="")&&(revision'=1) Do ##class(Demo.Protocol).Fail("A new route must begin at revision 1")
        Set binding=..RuntimeBinding()
        If body.%Get("expected_config_hash")'=binding.%Get("config_hash") Do ##class(Demo.Protocol).Fail("Production configuration changed before registration")
        Set value=##class(Contest.RouteGovernance).Register(body.declaration,binding,body.%Get("valid_from"),body.%Get("valid_until"))
    } Catch ex { Lock -^ContestRouteGovernance("uiLock",route) Throw ex }
    Lock -^ContestRouteGovernance("uiLock",route)
    Quit value
}

ClassMethod Approve(body As %DynamicObject) As %DynamicObject
{
    Do ..Access(1), ##class(Contest.RouteGovernance).Shape(body,"id,digest,confirm_registry_only")
    If (body.%GetTypeOf("confirm_registry_only")'="boolean")||('body.%Get("confirm_registry_only")) Do ##class(Demo.Protocol).Fail("Explicit registry-only approval confirmation required")
    Set value=##class(Contest.RouteGovernance).Read(body.id)
    If value.core.declaration.kind'="utilization" Do ##class(Demo.Protocol).Fail("Preset aggregation approval is read-only here")
    Set template=..Template()
    Do ..Recipe(value.core.declaration,template)
    Set status=##class(Contest.RouteGovernance).Check(body.id,template.binding,body.digest)
    If '((status.state="missing_approval")||(status.state="approved_scope")) Do ##class(Demo.Protocol).Fail("Approval scope or current binding is stale: "_status.state)
    Set now=##class(Demo.Protocol).Now()
    If (now<value.core.%Get("valid_from"))||(now>=value.core.%Get("valid_until")) Do ##class(Demo.Protocol).Fail("Approval proposal is outside its validity interval")
    Quit ##class(Contest.RouteGovernance).Approve(body.id,body.digest)
}

ClassMethod Evidence(body As %DynamicObject) As %DynamicObject
{
    Do ..Access(), ##class(Contest.RouteGovernance).Shape(body,"id,batch_id,receipt_hash")
    Set record=##class(Contest.RouteGovernance).Read(body.id)
    Set value=##class(Contest.RouteEvidence).Read(record.core.declaration.kind,body.%Get("batch_id"),body.%Get("receipt_hash"))
    If (value.evidence.approved.%Get("record_id")'=record.id)||(value.evidence.provenance.%Get("scope_hash")'=record.digest) Do ##class(Demo.Protocol).Fail("This historical batch belongs to a different declaration revision")
    Quit value
}
}
