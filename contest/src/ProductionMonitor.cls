Class Contest.ProductionMonitor
{
ClassMethod Scope() As %DynamicObject
{
    Quit {"unit":"production","flow_registration_required":false,"component_scope":"all_current_components","semantic_context":"optional_not_a_collection_filter","path_discovery":"observed_edges_and_session_correlation","payload_review":"separately_authorized_sampled_ai_review","review_results":"production_scoped_advisory_with_explicit_information_gaps"}
}

ClassMethod Access(write As %Boolean = 0) [ Private ]
{
    If ($Namespace'="TRIAGE")||('$System.Security.Check($Select(write:"ContestMonitorDeploy",1:"ContestMonitorRead"),"U")) Do ##class(Demo.Protocol).Fail("Production monitoring permission required")
}

ClassMethod Key(ns As %String, production As %String) As %String
{
    Quit "production-"_##class(Demo.Protocol).Hash("local-iris|"_$ZConvert(ns,"U")_"|"_production)
}

ClassMethod Snapshot(ns As %String) As %DynamicObject
{
    Do ..Access()
    If '$Match(ns,"^[A-Za-z][A-Za-z0-9_-]{0,63}$") Do ##class(Demo.Protocol).Fail("Explicit local namespace required")
    Set previous=$Namespace
    Try {
        Set $Namespace=ns, ns=$Namespace
        If '##class(%Dictionary.CompiledClass).%ExistsId("Ens.Director") Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError,"Namespace is not Interoperability-enabled"))
        Set sc=##class(Ens.Director).GetProductionStatus(.name,.state) $$$ThrowOnError(sc)
        If name="" Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError,"Namespace has no selected Production"))
        Set production=##class(Ens.Config.Production).%OpenId(name)
        If '$IsObject(production) Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError,"Production configuration unavailable"))
        Set nodes=[], config=[]
        For i=1:1:production.Items.Count() {
            Set item=production.Items.GetAt(i), settings=[]
            For j=1:1:item.Settings.Count() {
                Set setting=item.Settings.GetAt(j)
                Do settings.%Push({"target":(setting.Target),"name":(setting.Name),"value":(setting.Value)})
            }
            Set node={"name":(item.Name),"class":(item.ClassName),"enabled":(item.Enabled),"pool_size":(item.PoolSize)}
            Do config.%Push({"node":(node),"settings":(settings)})
            Set display={}.%FromJSON(node.%ToJSON()), partner=""
            For j=0:1:settings.%Size()-1 {
                Set setting=settings.%Get(j)
                If setting.name="BusinessPartner" Set partner=setting.value
            }
            Do display.%Set("business_partner",partner), nodes.%Push(display)
        }
    } Catch ex { Set $Namespace=previous Throw ex }
    Set $Namespace=previous
    Set fingerprint=##class(Demo.Protocol).Hash(config.%ToJSON())
    Quit {"id":(..Key(ns,name)),"instance_id":"local-iris","namespace":(ns),"production":(name),"state":(state),"running":(state=1),"nodes":(nodes),"config_hash":(fingerprint),"observed_at":(##class(Demo.Protocol).Now())}
}

ClassMethod Discover() As %DynamicObject
{
    Do ..Access(1)
    Set sc=##class(%SYS.Namespace).ListAll(.names) $$$ThrowOnError(sc)
    Set items=[], errors=[], ns=""
    For {
        Set ns=$Order(names(ns))
        If ns="" Quit
        If '$Match(ns,"^[A-Za-z][A-Za-z0-9_-]{0,63}$") Continue
        Set previous=$Namespace
        Try {
            Set $Namespace=ns, ensemble=##class(%Dictionary.CompiledClass).%ExistsId("Ens.Director")
            If ensemble {
                Set sc=##class(Ens.Director).GetProductionStatus(.name,.state) $$$ThrowOnError(sc)
            }
            Set $Namespace=previous
            If ensemble&&(state=1) {
                Set item=..Snapshot(ns)
                Do item.%Set("managed",$Data(^ContestProductionMonitor("record",item.id))>0,"boolean"), items.%Push(item)
            }
        } Catch ex {
            Set $Namespace=previous
            Do errors.%Push({"namespace":(ns),"error":"Cannot inspect namespace; check existing Interoperability/database permissions."})
            Do ##class(Contest.KnowledgeService).Audit("production.discovery.failed",ns,ex.DisplayString())
        }
    }
    Quit {"items":(items),"errors":(errors),"instance_id":"local-iris","model_calls":0}
}

ClassMethod Record(id As %String) As %DynamicObject
{
    Do ..Access()
    If ('$Match(id,"^production-[a-f0-9]{64}$"))||('$Data(^ContestProductionMonitor("record",id))) Do ##class(Demo.Protocol).Fail("Managed Production not found")
    Set item={}.%FromJSON(^ContestProductionMonitor("record",id))
    If item.id'=..Key(item.namespace,item.production) Do ##class(Demo.Protocol).Fail("Production identity mismatch")
    Quit item
}

ClassMethod Cursors(ns As %String) As %DynamicObject [ Private ]
{
    Set previous=$Namespace
    Try {
        Set $Namespace=ns, rs=##class(%SQL.Statement).%ExecDirect(,"SELECT COALESCE(MAX(ID),0) AS N FROM Ens.MessageHeader")
        If rs.%SQLCODE<0 Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError,rs.%Message))
        Set next=rs.%Next(), header=rs.%Get("N"), rs=##class(%SQL.Statement).%ExecDirect(,"SELECT COALESCE(MAX(ID),0) AS N FROM Ens_Util.Log")
        If rs.%SQLCODE<0 Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError,rs.%Message))
        Set next=rs.%Next(), log=rs.%Get("N")
    } Catch ex { Set $Namespace=previous Throw ex }
    Set $Namespace=previous
    Quit {"header":(header),"log":(log)}
}

ClassMethod Enroll(body As %DynamicObject) As %DynamicObject
{
    Do ..Access(1), ##class(Contest.RouteGovernance).Shape(body,"namespace,production,config_hash,acknowledge_monitoring")
    If (body.%GetTypeOf("acknowledge_monitoring")'="boolean")||('body.%Get("acknowledge_monitoring")) Do ##class(Demo.Protocol).Fail("Explicit monitoring enrollment confirmation required")
    For field="namespace","production","config_hash" Do ##class(Contest.RouteGovernance).Text(body,field,128)
    Lock +^ContestProductionMonitor("worker"):2
    If '$Test Do ##class(Demo.Protocol).Fail("Production observer busy")
    Try {
        Set snapshot=..Snapshot(body.namespace), id=snapshot.id
        If ('snapshot.running)||(snapshot.production'=body.production)||(snapshot.%Get("config_hash")'=body.%Get("config_hash")) Do ##class(Demo.Protocol).Fail("Active Production or configuration changed; discover again")
        If $Data(^ContestProductionMonitor("record",id)) { Set result=..Record(id) }
        Else {
            Set result={"id":(id),"instance_id":"local-iris","namespace":(snapshot.namespace),"production":(snapshot.production),"enabled":true,"revision":1,"enrolled_by":($Username),"enrolled_at":(##class(Demo.Protocol).Now()),"enrolled_time":($ZDATETIME($ZTIMESTAMP,3,1,3)),"baseline":(snapshot),"current":(snapshot),"cursor":(..Cursors(snapshot.namespace)),"last_scan":0,"error":"","model_calls":0,"header_count":0,"log_count":0}
            Set ^ContestProductionMonitor("record",id)=result.%ToJSON()
            Do ..Emit(id,"enrolled","monitoring_started","info","Production enrolled for read-only observation",{"history":"Header/log collection begins at enrollment, not a historical backfill."})
            Do ..Emit(id,"coverage","coverage_gap","warning","Enrollment alone does not authorize message inspection or AI risk review",{"observed":"Production state, configuration fingerprints, new message headers and warning/error event-log metadata. Body inspection and bounded sampled AI review need separate explicit grants.","ai":"No model allowance is granted by enrollment; missing business context remains unresolved, not an all-clear."})
            Do ##class(Contest.KnowledgeService).Audit("production.enrolled",id,snapshot.namespace_"|"_snapshot.production)
        }
    } Catch ex { Lock -^ContestProductionMonitor("worker") Throw ex }
    Lock -^ContestProductionMonitor("worker")
    Quit result
}

ClassMethod Manage(body As %DynamicObject) As %DynamicObject
{
    Do ..Access(1), ##class(Contest.RouteGovernance).Shape(body,"id,revision,enabled")
    If (body.%GetTypeOf("enabled")'="boolean")||(body.%GetTypeOf("revision")'="number") Do ##class(Demo.Protocol).Fail("Exact management revision and enabled boolean required")
    Lock +^ContestProductionMonitor("worker"):2
    If '$Test Do ##class(Demo.Protocol).Fail("Production observer busy")
    Try {
        Set item=..Record(body.id)
        If item.revision'=body.revision Do ##class(Demo.Protocol).Fail("Managed Production changed; refresh")
        If item.enabled'=body.enabled {
            Do item.%Set("enabled",body.enabled,"boolean")
            Set item.revision=item.revision+1
            If item.enabled {
                Set current=..Snapshot(item.namespace)
                If (current.production'=item.production)||('current.running) Do ##class(Demo.Protocol).Fail("Selected Production must be active before resuming")
            }
            Set ^ContestProductionMonitor("record",item.id)=item.%ToJSON()
            Do ..Emit(item.id,"management-"_item.revision,"monitoring_state","info",$Select(item.enabled:"Observer resumed; retained cursor will catch up",1:"Observer paused; business Production was not stopped"),{})
            Do ##class(Contest.KnowledgeService).Audit("production.monitoring.changed",item.id,item.enabled)
        }
    } Catch ex { Lock -^ContestProductionMonitor("worker") Throw ex }
    Lock -^ContestProductionMonitor("worker")
    Quit item
}

ClassMethod Emit(id As %String, sourceKey As %String, category As %String, severity As %String, title As %String, evidence As %DynamicObject)
{
    Do ..Access(1)
    If $Data(^ContestProductionMonitor("event",id,sourceKey)) Quit
    Set sequence=$Increment(^ContestProductionMonitor("sequence",id)), event={"production_id":(id),"source_key":(sourceKey),"sequence":(sequence),"category":(category),"severity":(severity),"title":(title),"evidence":(evidence),"created_at":(##class(Demo.Protocol).Now()),"state":"open","revision":1,"actions":[]}
    Set ^ContestProductionMonitor("event",id,sourceKey)=event.%ToJSON(), ^ContestProductionMonitor("order",id,sequence)=sourceKey
}

ClassMethod Event(id As %String, sourceKey As %String) As %DynamicObject
{
    Set item=..Record(id)
    If ('$Match(sourceKey,"^[A-Za-z0-9-]{1,160}$"))||('$Data(^ContestProductionMonitor("event",id,sourceKey))) Do ##class(Demo.Protocol).Fail("Production event not found")
    Quit {}.%FromJSON(^ContestProductionMonitor("event",id,sourceKey))
}

ClassMethod Events(id As %String, before As %Integer = 0) As %DynamicObject
{
    Set item=..Record(id), items=[], seq=$Select(before>0:before,1:""), cursor=0
    For i=1:1:25 {
        Set seq=$Order(^ContestProductionMonitor("order",id,seq),-1)
        If seq="" Quit
        Do items.%Push(..Event(id,^ContestProductionMonitor("order",id,seq)))
        Set cursor=+seq
    }
    Set older=$Select(cursor>0:$Order(^ContestProductionMonitor("order",id,cursor),-1),1:"")
    Quit {"production_id":(id),"items":(items),"next_before":($Select(older'="":cursor,1:0))}
}

ClassMethod Action(body As %DynamicObject) As %DynamicObject
{
    Do ..Access(1), ##class(Contest.RouteGovernance).Shape(body,"production_id,source_key,revision,action,text"), ##class(Contest.RouteGovernance).Text(body,"text",2000)
    If body.%GetTypeOf("revision")'="number" Do ##class(Demo.Protocol).Fail("Exact event revision required")
    Lock +^ContestProductionMonitor("worker"):2
    If '$Test Do ##class(Demo.Protocol).Fail("Production event busy")
    Try {
        Set event=..Event(body.%Get("production_id"),body.%Get("source_key"))
        If (event.revision'=body.revision)||('##class(Contest.EventService).AllowedTransition(event.state,body.action)) Do ##class(Demo.Protocol).Fail("Event revision or transition conflict")
        Do event.actions.%Push({"actor":($Username),"time":(##class(Demo.Protocol).Now()),"before":(event.state),"after":(body.action),"text":(body.text)})
        Set event.state=body.action, event.revision=event.revision+1, ^ContestProductionMonitor("event",body.%Get("production_id"),body.%Get("source_key"))=event.%ToJSON()
        Do ##class(Contest.KnowledgeService).Audit("production.event.action",body.%Get("production_id"),body.action)
    } Catch ex { Lock -^ContestProductionMonitor("worker") Throw ex }
    Lock -^ContestProductionMonitor("worker")
    Quit event
}

ClassMethod Collect(item As %DynamicObject) [ Private ]
{
    Set previous=$Namespace
    Try {
        Set current=..Snapshot(item.namespace)
        If (current.production'=item.production)||('current.running) {
            If (current.production'=item.current.production)||(current.state'=item.current.state) Do ..Emit(item.id,"inactive-"_$Increment(^ContestProductionMonitor("transition",item.id)),"production_inactive","warning","Managed Production is not currently running",{"selected":(item.production),"current":(current.production),"state":(current.state)})
        } Else {
            If (item.current.production'=item.production)||('item.current.running) Do ..Emit(item.id,"active-"_$Increment(^ContestProductionMonitor("transition",item.id)),"production_active","info","Managed Production is active again",{})
            If current.%Get("config_hash")'=item.current.%Get("config_hash") Do ..Emit(item.id,"config-"_$Increment(^ContestProductionMonitor("transition",item.id)),"configuration_change","warning","Production configuration changed",{"previous_hash":(item.current.%Get("config_hash")),"current_hash":(current.%Get("config_hash"))})
            Set components={}
            For i=0:1:current.nodes.%Size()-1 Do components.%Set(current.nodes.%Get(i).name,1)
            Set $Namespace=item.namespace, headers=[], logs=[]
            Set rs=##class(%SQL.Statement).%ExecDirect(,"SELECT TOP 200 ID,SourceConfigName,TargetConfigName,SessionId,IsError,Status,TimeCreated,MessageBodyClassName,MessageBodyId,Type,CorrespondingMessageId FROM Ens.MessageHeader WHERE ID>? AND TimeCreated>=? ORDER BY ID",item.cursor.header,item.%Get("enrolled_time"))
            If rs.%SQLCODE<0 Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError,rs.%Message))
            While rs.%Next() {
                Set row={"header_id":(rs.%Get("ID")),"source":(rs.%Get("SourceConfigName")),"target":(rs.%Get("TargetConfigName")),"session_id":(rs.%Get("SessionId")),"is_error":(rs.%Get("IsError")),"status":(rs.%Get("Status")),"time":(rs.%Get("TimeCreated"))}
                Do row.%Set("body_class",rs.%Get("MessageBodyClassName")), row.%Set("body_id",rs.%Get("MessageBodyId")), row.%Set("message_type",rs.%Get("Type")), row.%Set("corresponding_header",rs.%Get("CorrespondingMessageId"))
                Do headers.%Push(row)
            }
            If rs.%SQLCODE<0 Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError,rs.%Message))
            Set rs=##class(%SQL.Statement).%ExecDirect(,"SELECT TOP 200 ID,ConfigName,Type,SessionId,TimeLogged FROM Ens_Util.Log WHERE ID>? AND TimeLogged>=? ORDER BY ID",item.cursor.log,item.%Get("enrolled_time"))
            If rs.%SQLCODE<0 Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError,rs.%Message))
            While rs.%Next() {
                Do logs.%Push({"log_id":(rs.%Get("ID")),"component":(rs.%Get("ConfigName")),"type":(rs.%Get("Type")),"session_id":(rs.%Get("SessionId")),"time":(rs.%Get("TimeLogged"))})
            }
            If rs.%SQLCODE<0 Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError,rs.%Message))
            Set sc=##class(Ens.Director).GetProductionStatus(.afterName,.afterState) $$$ThrowOnError(sc)
            Set $Namespace=previous
            If (afterName'=item.production)||(afterState'=1) Do ##class(Demo.Protocol).Fail("Production changed during collection; cursor retained")
            Set confirmed=..Snapshot(item.namespace)
            If (confirmed.production'=item.production)||('confirmed.running)||(confirmed.%Get("config_hash")'=current.%Get("config_hash")) Do ##class(Demo.Protocol).Fail("Production configuration changed during collection; cursor retained")
            For i=0:1:headers.%Size()-1 {
                Set row=headers.%Get(i)
                If components.%IsDefined(row.source)||components.%IsDefined(row.target) {
                    Do ##class(Contest.ProductionEvidence).Capture(item,row,current)
                    Do ..Emit(item.id,"header-"_row.%Get("header_id"),$Select(row.%Get("is_error"):"message_error",1:"message_observed"),$Select(row.%Get("is_error"):"warning",1:"info"),"IRIS message header observed",row)
                    Do item.%Set("header_count",item.%Get("header_count")+1)
                } Else { Do item.%Set("unattributed_header_count",item.%Get("unattributed_header_count",0)+1) }
                Set item.cursor.header=row.%Get("header_id")
            }
            Do item.%Set("header_batch_full",headers.%Size()=200,"boolean")
            For i=0:1:logs.%Size()-1 {
                Set row=logs.%Get(i)
                If components.%IsDefined(row.component)&&((row.type=1)||(row.type=2)||(row.type="Error")||(row.type="Warning")||(row.type="Alert")) {
                    Do ..Emit(item.id,"log-"_row.%Get("log_id"),"runtime_log","warning","IRIS component warning/error (metadata only)",row)
                    Do item.%Set("log_count",item.%Get("log_count")+1)
                }
                Set item.cursor.log=row.%Get("log_id")
            }
        }
        Set item.current=current, item.error=""
    } Catch ex { Set $Namespace=previous Throw ex }
}

ClassMethod Pump()
{
    Do ..Access(1)
    Lock +^ContestProductionMonitor("worker"):0
    If '$Test Quit
    Try {
        Set id=""
        For {
            Set id=$Order(^ContestProductionMonitor("record",id))
            If id="" Quit
            Set item=..Record(id)
            If 'item.enabled Continue
            TStart
            Try {
                Do ..Collect(item), item.%Set("last_scan",##class(Demo.Protocol).Now())
                Set ^ContestProductionMonitor("record",id)=item.%ToJSON()
                TCommit
            }
            Catch ex {
                TRollback 1
                Set item=..Record(id)
                Set item.error="Production read-only collection failed; check source access and runtime status. Existing cursor retained."
                Do item.%Set("last_scan",##class(Demo.Protocol).Now())
                Set ^ContestProductionMonitor("record",id)=item.%ToJSON()
                Do ##class(Contest.KnowledgeService).Audit("production.collection.failed",id,ex.DisplayString())
            }
        }
        Set ^ContestProductionMonitor("heartbeat")=##class(Demo.Protocol).Now()
        Kill ^ContestProductionMonitor("error")
    } Catch ex {
        Set ^ContestProductionMonitor("error")="Production observer failed; inspect protected audit."
        Do ##class(Contest.KnowledgeService).Audit("production.observer.failed","",ex.DisplayString())
    }
    Lock -^ContestProductionMonitor("worker")
}

ClassMethod Risks(id As %String, offset As %Integer = 0) As %DynamicObject
{
    If (offset<0)||(offset>1000000)||((offset\1)'=offset) Do ##class(Demo.Protocol).Fail("Bounded risk page offset required")
    Set item=..Record(id), results=[]
    Set header=""
    For {
        Set header=$Order(^ContestProductionReview("review",id,header),-1)
        If header="" Quit
        Set review=##class(Contest.ProductionReviewService).Lookup(id,header)
        If (review.state'="completed")&&(review.state'="failed")&&(review.state'="interrupted") Continue
        Set result=$Select(review.%IsDefined("result"):review.result,1:""), eventState="open", eventBefore=0
        If $Data(^ContestProductionMonitor("event",id,"review-"_header)) {
            Set event=..Event(id,"review-"_header), eventState=event.state, eventBefore=event.sequence+1
        }
        Set category=$Select(review.state'="completed":"technical_failure",result.summary.%Get("risk_detected"):"risk_identified",result.summary.unresolved:"information_required",1:"no_deviation_on_checked_use")
        Do results.%Push({"id":(review.id),"source":"production_observation","state":(review.state),"category":(category),"batch_id":"","record_id":"","event_state":(eventState),"event_before":(eventBefore),"result":(result),"link":("#production-event-"_id_"-review-"_header),"title":("Observed message "_header_" - bounded AI review")})
    }
    If (item.namespace="UTILIZATION")&&(item.production="Contest.Utilization.Production") {
        Set run=""
        For {
            Set run=$Order(^ContestDeclarationMonitor("review",run))
            If run="" Quit
            Set execution=##class(Contest.DeclarationExecution).Load(run)
            If (execution.grant.binding.namespace'=item.namespace)||(execution.grant.binding.production'=item.production) Continue
            Set review=##class(Contest.DeclarationMonitor).Detail(run), category=$Select((review.state="failed")||(review.state="interrupted")||(review.state="evidence_failed"):"technical_failure",review.state'="completed":"coverage_gap",review.result.summary.%Get("risk_detected"):"risk_identified",review.result.summary.unresolved:"information_required",1:"no_deviation_on_checked_use")
            Do results.%Push({"id":(run),"source":"declaration_after_send","state":(review.state),"category":(category),"batch_id":(execution.grant.%Get("batch_id")),"record_id":(execution.grant.record.id),"event_state":(review.event.state),"result":(review.result),"link":"/declarations","receipt_hash":(execution.receipt.%Get("receipt_hash"))})
        }
    }
    If ((item.namespace="PIPELINE")&&(item.production="Contest.Aggregation.Production"))||((item.namespace="UTILIZATION")&&(item.production="Contest.Utilization.Production")) {
        Set key="", kind=$Select(item.namespace="PIPELINE":"aggregation",1:"utilization")
        For {
            Set key=$Order(^ContestRouteReview("review",key))
            If key="" Quit
            Set review={}.%FromJSON(^ContestRouteReview("review",key))
            If review.%Get("route_kind")'=kind Continue
            Set result=$Select(review.%IsDefined("result"):review.result,1:"")
            Set category=$Select((review.state="failed")||(review.state="interrupted")||(review.state="evidence_failed"):"technical_failure",review.state'="completed":"coverage_gap",result.summary.%Get("risk_detected"):"risk_identified",result.summary.unresolved:"information_required",1:"no_deviation_on_checked_use")
            Do results.%Push({"id":(key),"source":"legacy_route_after_send","state":(review.state),"category":(category),"batch_id":(review.%Get("batch_id")),"record_id":(review.%Get("record_id")),"event_state":(review.event.state),"result":(result),"link":"/governance"})
        }
    }
    If (item.namespace="DEMO")&&(item.production="Demo.Production") {
        Set key=""
        For {
            Set key=$Order(^ContestEvents("event",key))
            If key="" Quit
            Set event={}.%FromJSON(^ContestEvents("event",key)), raw=$Get(^ContestMonitor("observation",event.%Get("observation_id")))
            If raw="" Continue
            Set observation={}.%FromJSON(raw)
            If (observation.namespace'=item.namespace)||(observation.production'=item.production) Continue
            Set category=$Select((event.category="risk")||(event.category="risk_signal"):"risk_identified",event.category="insufficient_evidence":"information_required",event.category="technical_failure":"technical_failure",event.category="coverage_gap":"coverage_gap",1:"event")
            Do results.%Push({"id":(key),"source":"demo_observation","state":(event.state),"category":(category),"batch_id":"","record_id":"","event_state":(event.state),"result":null,"link":("/events/"_key),"title":(event.title)})
        }
    }
    Set page=[]
    For i=offset:1:offset+24 {
        If i>=results.%Size() Quit
        Do page.%Push(results.%Get(i))
    }
    Quit {"production_id":(id),"items":(page),"next_offset":($Select(offset+25<results.%Size():offset+25,1:0)),"general_payload_assessment":false,"model_calls":0,"coverage":"Saved source-bound findings and separately funded sampled Production reviews. Reading this page calls no model. Enrollment alone grants no inspection/model budget; header-only evidence cannot establish actual business purpose, recipient or HIPAA compliance."}
}

ClassMethod List() As %DynamicObject
{
    Do ..Access()
    Set items=[], id=""
    For {
        Set id=$Order(^ContestProductionMonitor("record",id))
        If id="" Quit
        Do items.%Push(..Record(id))
    }
    Quit {"items":(items),"can_manage":($System.Security.Check("ContestMonitorDeploy","U")),"heartbeat":(+$Get(^ContestProductionMonitor("heartbeat"))),"error":($Get(^ContestProductionMonitor("error"))),"instance_id":"local-iris"}
}

ClassMethod Detail(id As %String) As %DynamicObject
{
    Set record=..Record(id)
    Quit {"record":(record),"risks":(..Risks(id)),"events":(..Events(id)),"monitoring_scope":(..Scope())}
}
}
