Class Contest.RouteUITests Extends %UnitTest.TestProduction
{
Parameter PRODUCTION = "Contest.Production";
Method TestControl() As %Status { Quit $$$OK }

Method TestTemplateIsBoundedAndNotActivation()
{
    If '$System.Security.Check("ContestMonitorDeploy","U") Quit
    Set value=##class(Contest.RouteUI).Template(), declaration=value.declaration
    Do $$$AssertEquals(declaration.kind,"utilization")
    Do $$$AssertEquals(declaration.scope.%Get("max_records"),4)
    Do $$$AssertEquals(declaration.scope.fields.%Size(),7)
    Do $$$AssertEquals(value.%Get("runtime_activation"),"not_performed")
    Do $$$AssertTrue(value.binding.%Get("config_hash")'="")
}

Method TestRegistryViewDoesNotInventRuntimeObservation()
{
    If '$System.Security.Check("ContestMonitorRead","U") {
        Set rejected=0
        Try { Set value=##class(Contest.RouteUI).List() } Catch ex { Set rejected=(ex.DisplayString()["Route governance capability required") }
        Do $$$AssertTrue(rejected,"Unprivileged development caller cannot read the registry")
        Quit
    }
    Set value=##class(Contest.RouteUI).List()
    Do $$$AssertEquals(value.%Get("model_calls"),0)
    Do $$$AssertEquals(value.%Get("runtime_activation"),"not_performed")
    Do $$$AssertTrue($IsObject(value.records))
    For i=0:1:value.records.%Size()-1 {
        Set record=value.records.%Get(i)
        Do $$$AssertTrue(record.%IsDefined("core"))
        Do $$$AssertTrue('record.%IsDefined("observed"))
    }
}
    Method Proposal() As %DynamicObject
    {
        Set template=##class(Contest.RouteUI).Template()
        Do template.declaration.%Set("route_id","unit-route-ui-"_$System.Util.CreateGUID())
        Quit {"declaration":(template.declaration),"valid_from":(template.%Get("valid_from")),"valid_until":(template.%Get("valid_until")),"expected_config_hash":(template.binding.%Get("config_hash"))}
    }

    Method TestDurableRevisionApprovalAndNoActivation()
    {
        If '$System.Security.Check("ContestMonitorDeploy","U") Quit
        Set active=$Get(^|"UTILIZATION"|ContestUtilization("registration"))
        TStart
        Try {
            Set body=..Proposal(), first=##class(Contest.RouteUI).Register(body)
            Do $$$AssertTrue('$IsObject(first.approval))
            Set repeated=##class(Contest.RouteUI).Register(body)
            Do $$$AssertEquals(first.%ToJSON(),repeated.%ToJSON())
            Set approved=##class(Contest.RouteUI).Approve({"id":(first.id),"digest":(first.digest),"confirm_registry_only":true})
            Do $$$AssertEquals(approved.approval.%Get("approved_by"),$Username)
            Set body.declaration.revision=2
            Do body.declaration.%Set("purpose_text","Synthetic revised analysis purpose")
            Set second=##class(Contest.RouteUI).Register(body)
            Do $$$AssertTrue('$IsObject(second.approval))
            Do $$$AssertTrue(first.id'=second.id)
            Do $$$AssertTrue(first.digest'=second.digest)
            Do $$$AssertEquals($Get(^|"UTILIZATION"|ContestUtilization("registration")),active)
            Set check=##class(Contest.RouteGovernance).Check(second.id,second.core.binding,second.digest)
            Do $$$AssertEquals(check.state,"missing_approval")
        } Catch ex { TRollback 1 Throw ex }
        TRollback 1
    }

    Method TestUntrustedScopeConfigIdentityAndRevisionFail()
    {
        If '$System.Security.Check("ContestMonitorDeploy","U") Quit
        TStart
        Try {
            Set original=..Proposal()
            For variant="scope","endpoint","identity","config","validity","short","unknown","revision" {
                Set body={}.%FromJSON(original.%ToJSON()), rejected=0
                If variant="scope" Do body.declaration.scope.fields.%Push("Patient.name.family")
                If variant="endpoint" Set body.declaration.recipient="remote"
                If variant="identity" Do body.declaration.%Set("service_identity","unregistered-user")
                If variant="config" Do body.%Set("expected_config_hash",$Translate($Justify("",64)," ","0"))
                If variant="validity" Do body.%Set("valid_until",body.%Get("valid_from")+2592001)
                If variant="short" Do body.%Set("valid_until",body.%Get("valid_from")+1)
                If variant="unknown" Do body.%Set("activate",1,"boolean")
                If variant="revision" Set body.declaration.revision=3
                Try { Set result=##class(Contest.RouteUI).Register(body) } Catch ex { Set rejected=(ex.DisplayString()["ERROR #5001:") }
                Do $$$AssertTrue(rejected,variant)
            }
            Set first=##class(Contest.RouteUI).Register(original)
            Set conflict={}.%FromJSON(original.%ToJSON()), rejected=0
            Do conflict.declaration.%Set("purpose_text","Changed purpose on an immutable existing revision")
            Try { Set ignored=##class(Contest.RouteUI).Register(conflict) } Catch ex { Set rejected=(ex.DisplayString()["Immutable route revision conflict") }
            Do $$$AssertTrue(rejected,"Changed same-revision declaration cannot overwrite its record")
            For variant="digest","confirmation","stale" {
                Set body={"id":(first.id),"digest":(first.digest),"confirm_registry_only":true}, rejected=0
                If variant="digest" Set body.digest=$Translate($Justify("",64)," ","0")
                If variant="confirmation" Do body.%Set("confirm_registry_only",0,"boolean")
                If variant="stale" {
                    Set proposal={}.%FromJSON(original.%ToJSON()), proposal.declaration.revision=3
                }
                Try {
                    If variant="stale" {
                        Set ignored=##class(Contest.RouteUI).Register(proposal)
                    } Else {
                        Set ignored=##class(Contest.RouteUI).Approve(body)
                    }
                } Catch ex { Set rejected=(ex.DisplayString()["ERROR #5001:") }
                Do $$$AssertTrue(rejected,variant)
            }
            Do $$$AssertTrue('$IsObject(##class(Contest.RouteGovernance).Read(first.id).approval))
            Set broader=..Proposal(), binding=##class(Contest.RouteUI).Template().binding
            Do broader.declaration.scope.fields.%Push("Patient.name.family")
            Set record=##class(Contest.RouteGovernance).Register(broader.declaration,binding,broader.%Get("valid_from"),broader.%Get("valid_until")), rejected=0
            Try { Set ignored=##class(Contest.RouteUI).Approve({"id":(record.id),"digest":(record.digest),"confirm_registry_only":true}) } Catch ex { Set rejected=(ex.DisplayString()["Scope must match the fixed") }
            Do $$$AssertTrue(rejected,"UI cannot approve a wider recipe registered by another entry point")
        } Catch ex { TRollback 1 Throw ex }
        TRollback 1
    }

    Method TestEvidenceCannotMoveBetweenRevisions()
    {
        If '$System.Security.Check("ContestMonitorDeploy","U") Quit
        Set batch="", record=""
        For {
            Set batch=$Order(^|"UTILIZATION"|ContestUtilization("batch",batch))
            If batch="" Quit
            Set candidate={}.%FromJSON(^|"UTILIZATION"|ContestUtilization("batch",batch))
            If candidate.state="delivered" { Set record=candidate Quit }
        }
        If '$IsObject(record) Do ##class(Demo.Protocol).Fail("Actual delivered utilization fixture required")
        Set body={"id":(record.%Get("approval_id")),"batch_id":(batch),"receipt_hash":(record.receipt.%Get("receipt_hash"))}
        Set value=##class(Contest.RouteUI).Evidence(body)
        Do $$$AssertEquals(value.evidence.approved.%Get("record_id"),body.id)
        TStart
        Try {
            Set other=##class(Contest.RouteUI).Register(..Proposal()), body.id=other.id, rejected=0
            Try { Set value=##class(Contest.RouteUI).Evidence(body) } Catch ex { Set rejected=(ex.DisplayString()["different declaration revision") }
            Do $$$AssertTrue(rejected)
        } Catch ex { TRollback 1 Throw ex }
        TRollback 1
    }
}
