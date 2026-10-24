Class Contest.RouteGovernance
{
ClassMethod Access(write As %Boolean = 0) [ Private ]
{
    If $Namespace'="TRIAGE" Do ##class(Demo.Protocol).Fail("TRIAGE route registry required")
    If '$System.Security.Check($Select(write:"ContestMonitorDeploy",1:"ContestMonitorRead"),"U") Do ##class(Demo.Protocol).Fail("Route governance capability required")
}

ClassMethod Shape(value, keys As %String)
{
    Do ##class(Contest.RiskReview).Object(value)
    If value.%Size()'=$Length(keys,",") Do ##class(Demo.Protocol).Fail("Exact route contract required")
    For i=1:1:$Length(keys,",") {
        If 'value.%IsDefined($Piece(keys,",",i)) Do ##class(Demo.Protocol).Fail("Missing route contract field")
    }
}

ClassMethod Text(value, field As %String, maximum As %Integer = 128)
{
    If (value.%GetTypeOf(field)'="string")||($Length(value.%Get(field))>maximum)||($ZStrip(value.%Get(field),"<>W")="") Do ##class(Demo.Protocol).Fail("Bounded nonempty route text required: "_field)
}

ClassMethod Names(values)
{
    If '$IsObject(values) Do ##class(Demo.Protocol).Fail("Route scope array required")
    If 'values.%IsA("%DynamicArray") Do ##class(Demo.Protocol).Fail("Route scope array required")
    If (values.%Size()<1)||(values.%Size()>64) Do ##class(Demo.Protocol).Fail("Bounded nonempty route scope required")
    Kill seen
    For i=0:1:values.%Size()-1 {
        Set name=values.%Get(i)
        If (values.%GetTypeOf(i)'="string")||('$Match(name,"^[A-Za-z][A-Za-z0-9_.-]{0,127}$")) Do ##class(Demo.Protocol).Fail("Explicit scope names required; no wildcards or expressions")
        If $Data(seen(name)) Do ##class(Demo.Protocol).Fail("Duplicate route scope name")
        Set seen(name)=1
    }
}

ClassMethod ValidateBinding(binding As %DynamicObject)
{
    Do ..Shape(binding,"instance_id,namespace,production,source,sender,point,config_hash,collector_version,policy_version")
    For field="instance_id","namespace","production","source","sender","collector_version","policy_version" {
        Do ..Text(binding,field)
        If '$Match(binding.%Get(field),"^[A-Za-z][A-Za-z0-9_.-]{0,127}$") Do ##class(Demo.Protocol).Fail("Explicit route binding identity required")
    }
    If (binding.point'="before_send")||(binding.%GetTypeOf("config_hash")'="string")||('$Match(binding.%Get("config_hash"),"^[a-f0-9]{64}$")) Do ##class(Demo.Protocol).Fail("Exact configuration digest and before_send boundary required")
}

ClassMethod Validate(declaration As %DynamicObject, binding As %DynamicObject)
{
    Do ..Shape(declaration,"schema,synthetic,route_id,revision,kind,purpose_code,purpose_text,owner,service_identity,recipient,scope")
    If (declaration.%GetTypeOf("schema")'="number")||(declaration.schema'=1)||(declaration.%GetTypeOf("synthetic")'="boolean")||('declaration.synthetic) Do ##class(Demo.Protocol).Fail("Synthetic route schema 1 required")
    If (declaration.%GetTypeOf("revision")'="number")||(declaration.revision<1)||(declaration.revision>100000)||((declaration.revision\1)'=declaration.revision) Do ##class(Demo.Protocol).Fail("Bounded integer route revision required")
    For field="route_id","purpose_code","owner","service_identity","recipient" {
        Do ..Text(declaration,field)
        If '$Match(declaration.%Get(field),"^[A-Za-z][A-Za-z0-9_.-]{0,127}$") Do ##class(Demo.Protocol).Fail("Explicit route identity required")
    }
    Do ..Text(declaration,"purpose_text",2000)
    If '((declaration.kind="aggregation")||(declaration.kind="utilization")) Do ##class(Demo.Protocol).Fail("Unknown route kind")
    Set scope=declaration.scope
    Do ..Shape(scope,"resources,fields,patient_selection,max_records"), ..Names(scope.resources), ..Names(scope.fields), ..Text(scope,"patient_selection")
    If '$Match(scope.%Get("patient_selection"),"^[A-Za-z][A-Za-z0-9_.-]{0,127}$") Do ##class(Demo.Protocol).Fail("Named patient selection required; no executable query")
    If (scope.%GetTypeOf("max_records")'="number")||(scope.%Get("max_records")<1)||(scope.%Get("max_records")>10000)||((scope.%Get("max_records")\1)'=scope.%Get("max_records")) Do ##class(Demo.Protocol).Fail("Bounded record limit required")
    For i=0:1:scope.fields.%Size()-1 {
        Set path=scope.fields.%Get(i), found=0
        If $Length(path,".")<2 Do ##class(Demo.Protocol).Fail("Resource-qualified field path required")
        For j=0:1:scope.resources.%Size()-1 {
            If $Piece(path,".",1)=scope.resources.%Get(j) Set found=1
        }
        If 'found Do ##class(Demo.Protocol).Fail("Field resource outside declared scope")
    }
    Do ..ValidateBinding(binding)
}

ClassMethod Validity(start As %Numeric, end As %Numeric)
{
    If (start<1)||(end'>start)||((start\1)'=start)||((end\1)'=end)||(end>100000000000) Do ##class(Demo.Protocol).Fail("Explicit nonempty integer UTC validity interval required")
}

ClassMethod Register(declaration As %DynamicObject, binding As %DynamicObject, validFrom As %Numeric, validUntil As %Numeric) As %DynamicObject
{
    Do ..Access(1)
    Try {
        Do ..Validate(declaration,binding), ..Validity(validFrom,validUntil)
        Set core={"declaration":(declaration),"binding":(binding),"valid_from":(validFrom),"valid_until":(validUntil)}
        Set digest=##class(Contest.ExportEvidence).Digest(core), route=declaration.%Get("route_id"), revision=declaration.revision
        Lock +^ContestRouteGovernance("lock",route,revision):2
        If '$Test Do ##class(Demo.Protocol).Fail("Route revision busy")
        Try {
            Set id=$Get(^ContestRouteGovernance("revision",route,revision))
            If id'="" {
                Set value=..Load(id)
                If value.digest'=digest Do ##class(Demo.Protocol).Fail("Immutable route revision conflict; register a new revision")
            } Else {
                Set id="route-"_$System.Util.CreateGUID()
                Set value={"id":(id),"core":(core),"digest":(digest),"submitted_by":($Username),"submitted_at":(##class(Demo.Protocol).Now()),"record_source":"synthetic-demo-registry-v1"}
                Do value.%Set("record_hash",##class(Contest.ExportEvidence).Digest(value))
                TStart
                Try {
                    Set ^ContestRouteGovernance("record",id)=value.%ToJSON(), ^ContestRouteGovernance("revision",route,revision)=id
                    Do ##class(Contest.KnowledgeService).Audit("route.registered",id,digest)
                    TCommit
                } Catch ex { TRollback 1 Throw ex }
            }
        } Catch ex { Lock -^ContestRouteGovernance("lock",route,revision) Throw ex }
        Lock -^ContestRouteGovernance("lock",route,revision)
    } Catch ex {
        Do ##class(Contest.KnowledgeService).Audit("route.register.failed","synthetic-registry",ex.DisplayString())
        Throw ex
    }
    Quit ..Read(id)
}

ClassMethod Integrity(value As %DynamicObject, field As %String) [ Private ]
{
    Set copy={}.%FromJSON(value.%ToJSON()), digest=copy.%Get(field)
    Do copy.%Remove(field)
    If digest'=##class(Contest.ExportEvidence).Digest(copy) Do ##class(Demo.Protocol).Fail("Route registry integrity mismatch")
}

ClassMethod Load(id As %String) As %DynamicObject [ Private ]
{
    If '$Match(id,"^route-[A-Za-z0-9-]{1,80}$") Do ##class(Demo.Protocol).Fail("Bounded route record identity required")
    If '$Data(^ContestRouteGovernance("record",id)) Do ##class(Demo.Protocol).Fail("Route record not found")
    Set value={}.%FromJSON(^ContestRouteGovernance("record",id))
    Do ..Shape(value,"id,core,digest,submitted_by,submitted_at,record_source,record_hash"), ..Integrity(value,"record_hash")
    Do ..Shape(value.core,"declaration,binding,valid_from,valid_until"), ..Validate(value.core.declaration,value.core.binding)
    Do ..Validity(value.core.%Get("valid_from"),value.core.%Get("valid_until"))
    If (value.id'=id)||(value.%Get("record_source")'="synthetic-demo-registry-v1")||(value.digest'=##class(Contest.ExportEvidence).Digest(value.core)) Do ##class(Demo.Protocol).Fail("Route identity or scope digest mismatch")
    Quit value
}

ClassMethod Read(id As %String) As %DynamicObject
{
    Do ..Access()
    Try {
        Set value=..Load(id), approval=""
        If $Data(^ContestRouteGovernance("approval",id)) {
            Set approval={}.%FromJSON(^ContestRouteGovernance("approval",id))
            Do ..Shape(approval,"route_record_id,scope_hash,approved_by,approved_at,record_source,record_hash"_$Select(approval.%IsDefined("scenario"):",scenario",1:"")), ..Integrity(approval,"record_hash")
            If approval.%IsDefined("scenario") Do ##class(Contest.RouteScenario).Validate(value.core.declaration,approval.scenario)
            If (approval.%Get("route_record_id")'=id)||(approval.%Get("scope_hash")'=value.digest)||(approval.%Get("record_source")'="synthetic-demo-manual-approval-v1") Do ##class(Demo.Protocol).Fail("Approval scope mismatch")
        }
        Do value.%Set("approval",approval)
    } Catch ex {
        Do ##class(Contest.KnowledgeService).Audit("route.read.failed","synthetic-registry",ex.DisplayString())
        Throw ex
    }
    Quit value
}

ClassMethod Approve(id As %String, digest As %String) As %DynamicObject
{
    Do ..Access(1)
    Try {
        Set value=..Load(id)
        If value.digest'=digest Do ##class(Demo.Protocol).Fail("Exact declaration/binding/validity approval digest required")
        Lock +^ContestRouteGovernance("approveLock",id):2
        If '$Test Do ##class(Demo.Protocol).Fail("Route approval busy")
        Try {
            If '$Data(^ContestRouteGovernance("approval",id)) {
                Set approval={"route_record_id":(id),"scope_hash":(digest),"approved_by":($Username),"approved_at":(##class(Demo.Protocol).Now()),"record_source":"synthetic-demo-manual-approval-v1"}
                Set scenario=##class(Contest.RouteScenario).ForDeclaration(value.core.declaration)
                If $IsObject(scenario) Do approval.%Set("scenario",scenario)
                Do approval.%Set("record_hash",##class(Contest.ExportEvidence).Digest(approval))
                TStart
                Try {
                    Set ^ContestRouteGovernance("approval",id)=approval.%ToJSON()
                    Do ##class(Contest.KnowledgeService).Audit("route.approved",id,digest)
                    TCommit
                } Catch ex { TRollback 1 Throw ex }
            }
            Set result=..Read(id)
        } Catch ex { Lock -^ContestRouteGovernance("approveLock",id) Throw ex }
        Lock -^ContestRouteGovernance("approveLock",id)
    } Catch ex {
        Do ##class(Contest.KnowledgeService).Audit("route.approve.failed","synthetic-registry",ex.DisplayString())
        Throw ex
    }
    Quit result
}

ClassMethod Check(id As %String, expectedBinding As %DynamicObject, expectedScopeHash As %String) As %DynamicObject
{
    Do ..Access()
    Try {
        Do ..ValidateBinding(expectedBinding)
        If '$Match(expectedScopeHash,"^[a-f0-9]{64}$") Do ##class(Demo.Protocol).Fail("Independently pinned route scope digest required")
        If '$Match(id,"^route-[A-Za-z0-9-]{1,80}$") Do ##class(Demo.Protocol).Fail("Bounded route record identity required")
        Set state="missing_route", digest="", now=##class(Demo.Protocol).Now()
        If $Data(^ContestRouteGovernance("record",id)) {
            Set value=..Read(id), digest=value.digest, state="missing_approval"
            Set mismatch=0
            For field="instance_id","namespace","production","source","sender","point","config_hash","collector_version","policy_version" {
                If value.core.binding.%Get(field)'=expectedBinding.%Get(field) Set mismatch=1
            }
            If value.digest'=expectedScopeHash {
                Set state="scope_mismatch"
            } ElseIf mismatch {
                Set state="binding_mismatch"
            } ElseIf $IsObject(value.approval) {
                Set state=$Select(now<value.core.%Get("valid_from"):"not_yet_valid",now>=value.core.%Get("valid_until"):"expired",1:"approved_scope")
            }
        }
    } Catch ex {
        Do ##class(Contest.KnowledgeService).Audit("route.check.failed","synthetic-registry",ex.DisplayString())
        Throw ex
    }
    Quit {"route_record_id":(id),"state":(state),"scope_hash":(digest),"checked_at":(now),"binding_verification":"caller_supplied_not_discovered","runtime_activation":"not_performed","legal_authorization":"not_established","actual_output_verification":"not_performed"}
}
}
