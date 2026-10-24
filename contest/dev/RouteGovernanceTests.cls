Class Contest.RouteGovernanceTests Extends %UnitTest.TestProduction
{
Parameter PRODUCTION = "Contest.Production";
Method TestControl() As %Status { Quit $$$OK }

Method Declaration(kind As %String = "aggregation") As %DynamicObject
{
    Quit {"schema":1,"synthetic":true,"route_id":"unit-route","revision":1,"kind":(kind),"purpose_code":"unit-purpose","purpose_text":($Select(kind="aggregation":"Synthetic internal clinical data consolidation",1:"Synthetic bounded analysis export")),"owner":"demo-owner","service_identity":"demo-export-service","recipient":($Select(kind="aggregation":"local-fhir-center",1:"local-analysis-receiver")),"scope":{"resources":["Patient","Encounter"],"fields":["Patient.identifier","Patient.birthDate","Encounter.subject"],"patient_selection":"synthetic-cohort-a-v1","max_records":20}}
}

Method Binding() As %DynamicObject
{
    Quit {"instance_id":"local-test","namespace":"TRIAGE","production":"Contest.Export.Production","source":"SQLSource","sender":"FHIRSender","point":"before_send","config_hash":("a"_$Translate($Justify("",63)," ","a")),"collector_version":"export-observer-v1","policy_version":"export-policy-v1"}
}

Method TestStrictContract()
{
    Do ##class(Contest.RouteGovernance).Validate(..Declaration(),..Binding())
    For variant="approval","synthetic","purpose","scope","revision","binding","duplicate","wildcard","resource","selection","empty","unknown" {
        Set declaration=..Declaration(), binding=..Binding(), rejected=0
        If variant="approval" Do declaration.%Set("approved",1,"boolean")
        If variant="synthetic" Do declaration.%Set("synthetic",0,"boolean")
        If variant="purpose" Do declaration.%Set("purpose_text","")
        If variant="scope" Do declaration.scope.%Set("max_records",0)
        If variant="revision" Set declaration.revision=1.5
        If variant="binding" Do binding.%Set("config_hash","not-a-hash")
        If variant="duplicate" Do declaration.scope.resources.%Push("Patient")
        If variant="wildcard" Do declaration.scope.fields.%Push("Patient.*")
        If variant="resource" Do declaration.scope.fields.%Push("Observation.value")
        If variant="selection" Do declaration.scope.%Set("patient_selection","SELECT * FROM Patient")
        If variant="empty" Set declaration.scope.fields=[]
        If variant="unknown" Set declaration.kind="auto-approved"
        Try { Do ##class(Contest.RouteGovernance).Validate(declaration,binding) } Catch ex { Set rejected=1 }
        Do $$$AssertTrue(rejected,variant)
    }
}

Method TestPermission()
{
    If $System.Security.Check("ContestMonitorDeploy","U") {
        Do $$$AssertTrue(1,"Authorized persistence assertions run in separate methods")
    } Else {
        For operation="register","approve" {
            Set rejected=0
            Try {
                If operation="register" Set value=##class(Contest.RouteGovernance).Register(..Declaration(),..Binding(),1,2)
                If operation="approve" Set value=##class(Contest.RouteGovernance).Approve("route-missing","wrong")
            } Catch ex { Set rejected=(ex.DisplayString()["Route governance capability required") }
            Do $$$AssertTrue(rejected,operation_": explicit write denial")
        }
    }
}

Method TestApprovalIsExactAndDoesNotActivate()
{
    If '$System.Security.Check("ContestMonitorDeploy","U") Quit
    TStart
    Try {
        Set declaration=..Declaration() Do declaration.%Set("route_id","unit-"_$System.Util.CreateGUID())
        Set binding=..Binding(), now=##class(Demo.Protocol).Now()\1
        Set value=##class(Contest.RouteGovernance).Register(declaration,binding,now-10,now+3600)
        Set status=##class(Contest.RouteGovernance).Check(value.id,binding,value.digest)
        Do $$$AssertEquals(status.state,"missing_approval")
        Set rejected=0
        Try { Set ignored=##class(Contest.RouteGovernance).Approve(value.id,"wrong") } Catch ex { Set rejected=1 }
        Do $$$AssertTrue(rejected)
        Set approved=##class(Contest.RouteGovernance).Approve(value.id,value.digest)
        Set repeat=##class(Contest.RouteGovernance).Approve(value.id,value.digest)
        Do $$$AssertEquals(approved.%ToJSON(),repeat.%ToJSON())
        Do $$$AssertEquals(approved.approval.%Get("approved_by"),$Username)
        Do $$$AssertEquals(approved.approval.%Get("scope_hash"),value.digest)
        Set status=##class(Contest.RouteGovernance).Check(value.id,binding,value.digest)
        Do $$$AssertEquals(status.state,"approved_scope")
        Do $$$AssertEquals(status.%Get("runtime_activation"),"not_performed")
        Set replay=##class(Contest.RouteGovernance).Register(declaration,binding,now-10,now+3600)
        Do $$$AssertEquals(replay.id,value.id)
        For field="instance_id","namespace","production","source","sender","config_hash","collector_version","policy_version" {
            Set changed=..Binding()
            Do changed.%Set(field,$Select(field="config_hash":$Translate(binding.%Get("config_hash"),"a","b"),1:"OtherIdentity"))
            Do $$$AssertEquals(##class(Contest.RouteGovernance).Check(value.id,changed,value.digest).state,"binding_mismatch",field)
        }
        Set rejected=0 Do declaration.%Set("purpose_text","Changed purpose")
        Try { Set ignored=##class(Contest.RouteGovernance).Register(declaration,binding,now-10,now+3600) } Catch ex { Set rejected=1 }
        Do $$$AssertTrue(rejected,"A revision cannot silently change")
        Set declaration.revision=2
        Set newer=##class(Contest.RouteGovernance).Register(declaration,binding,now-10,now+3600)
        Do $$$AssertEquals(##class(Contest.RouteGovernance).Check(newer.id,binding,newer.digest).state,"missing_approval")
        Do $$$AssertEquals(##class(Contest.RouteGovernance).Check(value.id,binding,newer.digest).state,"scope_mismatch","Old approval does not cover the new purpose/revision")
        Set rejected=0
        Try { Set ignored=##class(Contest.RouteGovernance).Check(value.id,binding,"") } Catch ex { Set rejected=1 }
        Do $$$AssertTrue(rejected,"The consuming task must independently pin its intended scope")
        Set saved=^ContestRouteGovernance("approval",value.id), tampered={}.%FromJSON(saved)
        Do tampered.%Set("approved_by","modified")
        Set ^ContestRouteGovernance("approval",value.id)=tampered.%ToJSON(), rejected=0
        Try { Set ignored=##class(Contest.RouteGovernance).Read(value.id) } Catch ex { Set rejected=1 }
        Do $$$AssertTrue(rejected,"Corrupt approval is not a missing or valid approval")
    } Catch ex { TRollback 1 Throw ex }
    TRollback 1
}

Method TestTimeAndMissingStates()
{
    If '$System.Security.Check("ContestMonitorDeploy","U") Quit
    TStart
    Try {
        Set binding=..Binding(), now=##class(Demo.Protocol).Now()\1
        Do $$$AssertEquals(##class(Contest.RouteGovernance).Check("route-missing",binding,binding.%Get("config_hash")).state,"missing_route")
        For variant="expired","not_yet_valid" {
            Set declaration=..Declaration("utilization") Do declaration.%Set("route_id","unit-"_$System.Util.CreateGUID())
            Set start=$Select(variant="expired":now-3600,1:now+3600), end=start+600
            Set value=##class(Contest.RouteGovernance).Register(declaration,binding,start,end)
            Set approved=##class(Contest.RouteGovernance).Approve(value.id,value.digest)
            Do $$$AssertEquals(##class(Contest.RouteGovernance).Check(value.id,binding,value.digest).state,variant)
        }
        Set rejected=0
        Try { Set value=##class(Contest.RouteGovernance).Register(..Declaration(),binding,now,now) } Catch ex { Set rejected=1 }
        Do $$$AssertTrue(rejected,"An empty validity interval is invalid")
    } Catch ex { TRollback 1 Throw ex }
    TRollback 1
}

Method TestStoredDeclarationCannotBeReinterpreted()
{
    If '$System.Security.Check("ContestMonitorDeploy","U") Quit
    TStart
    Try {
        Set declaration=..Declaration() Do declaration.%Set("route_id","unit-"_$System.Util.CreateGUID())
        Set now=##class(Demo.Protocol).Now()\1, value=##class(Contest.RouteGovernance).Register(declaration,..Binding(),now-1,now+3600)
        Set stored={}.%FromJSON(^ContestRouteGovernance("record",value.id))
        Do stored.core.declaration.%Set("purpose_text","Different use")
        Set ^ContestRouteGovernance("record",value.id)=stored.%ToJSON(), rejected=0
        Try { Set ignored=##class(Contest.RouteGovernance).Read(value.id) } Catch ex { Set rejected=1 }
        Do $$$AssertTrue(rejected,"Changed declaration cannot be silently read as approved")
    } Catch ex { TRollback 1 Throw ex }
    TRollback 1
}
}
