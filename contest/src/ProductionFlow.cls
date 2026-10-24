Class Contest.ProductionFlow
{
ClassMethod Access(write As %Boolean = 0) [ Private ]
{
    If ($Namespace'="TRIAGE")||('$System.Security.Check($Select(write:"ContestMonitorDeploy",1:"ContestMonitorRead"),"U")) Do ##class(Demo.Protocol).Fail("Production flow capability required")
}

ClassMethod Integer(value, field As %String, minimum As %Integer = 0, maximum As %Integer = 100000)
{
    If (value.%GetTypeOf(field)'="number")||(value.%Get(field)<minimum)||(value.%Get(field)>maximum)||((value.%Get(field)\1)'=value.%Get(field)) Do ##class(Demo.Protocol).Fail("Bounded integer required: "_field)
}

ClassMethod Hash(value, field As %String)
{
    If (value.%GetTypeOf(field)'="string")||('$Match(value.%Get(field),"^[a-f0-9]{64}$")) Do ##class(Demo.Protocol).Fail("Exact SHA-256 digest required: "_field)
}

ClassMethod Key(productionId As %String, flowKey As %String) As %String
{
    If '$Match(productionId,"^production-[a-f0-9]{64}$") Do ##class(Demo.Protocol).Fail("Managed Production identity required")
    If '$Match(flowKey,"^[A-Za-z][A-Za-z0-9_.-]{0,127}$") Do ##class(Demo.Protocol).Fail("Bounded literal flow key required")
    Quit "flow-"_##class(Demo.Protocol).Hash(productionId_"|"_flowKey)
}

ClassMethod ValidateConfig(config As %DynamicObject)
{
    Do ##class(Contest.RouteGovernance).Shape(config,"schema,synthetic,title,owner,source,processors,sender,purpose,recipient_id,declaration,collector,review_policy")
    Do ..Integer(config,"schema",1,1)
    If (config.%GetTypeOf("synthetic")'="boolean")||('config.synthetic) Do ##class(Demo.Protocol).Fail("Only synthetic business-flow enrollment is supported")
    For field="title","owner" Do ##class(Contest.RouteGovernance).Text(config,field,200)
    For field="source","sender" Do ##class(Contest.RouteGovernance).Text(config,field,128)
    Do ##class(Contest.RouteGovernance).Text(config,"purpose",2000)
    If config.source=config.sender Do ##class(Demo.Protocol).Fail("Distinct source and sender hosts required")
    If config.%GetTypeOf("processors")'="array" Do ##class(Demo.Protocol).Fail("Processor host array required")
    If config.processors.%Size()>16 Do ##class(Demo.Protocol).Fail("At most 16 processor hosts supported")
    Set seen={}
    Do seen.%Set(config.source,1), seen.%Set(config.sender,1)
    For i=0:1:config.processors.%Size()-1 {
        Set name=config.processors.%Get(i)
        If (config.processors.%GetTypeOf(i)'="string")||($Length(name)>128)||($ZStrip(name,"<>W")="") Do ##class(Demo.Protocol).Fail("Bounded literal processor host required")
        If seen.%IsDefined(name) Do ##class(Demo.Protocol).Fail("Duplicate flow host")
        Do seen.%Set(name,1)
    }
    Do ##class(Contest.RouteGovernance).Text(config,"recipient_id")
    Set recipient=##class(Contest.DeclarationCatalog).Recipient(config.%Get("recipient_id"))
    If config.%GetTypeOf("declaration")'="null" {
        Do ##class(Contest.RouteGovernance).Shape(config.declaration,"record_id,digest"), ..Hash(config.declaration,"digest")
        If (config.declaration.%GetTypeOf("record_id")'="string")||('$Match(config.declaration.%Get("record_id"),"^declaration-[A-Za-z0-9-]{1,80}$")) Do ##class(Demo.Protocol).Fail("Exact declaration revision record required")
    }
    Do ##class(Contest.RouteGovernance).Shape(config.collector,"id,format,fields")
    If (config.collector.id'="structured-message-v1")||('((config.collector.format="fhir-r4")||(config.collector.format="json-object"))) Do ##class(Demo.Protocol).Fail("Registered structured collector contract required")
    Do ##class(Contest.RouteGovernance).Names(config.collector.fields)
    For i=0:1:config.collector.fields.%Size()-1 {
        Set path=config.collector.fields.%Get(i)
        If '$Match(path,"^[A-Za-z][A-Za-z0-9_]*([.][A-Za-z][A-Za-z0-9_]*){0,15}$") Do ##class(Demo.Protocol).Fail("Literal field paths required; no executable selectors")
        If (config.collector.format="fhir-r4")&&($Length(path,".")<2) Do ##class(Demo.Protocol).Fail("FHIR field paths must be resource-qualified")
    }
    If (config.%GetTypeOf("review_policy")'="string")||(config.%Get("review_policy")'="observed-use-v1") Do ##class(Demo.Protocol).Fail("Registered observed-use review policy required")
}

ClassMethod Hosts(config As %DynamicObject, snapshot As %DynamicObject) [ Private ]
{
    Set selected=[(config.source),(config.sender)]
    For i=0:1:config.processors.%Size()-1 Do selected.%Push(config.processors.%Get(i))
    For i=0:1:selected.%Size()-1 {
        Set found=0
        For j=0:1:snapshot.nodes.%Size()-1 {
            Set node=snapshot.nodes.%Get(j)
            If (node.name=selected.%Get(i))&&node.enabled Set found=1
        }
        If 'found Do ##class(Demo.Protocol).Fail("Selected flow host is absent or disabled in the exact active Production")
    }
}

ClassMethod Load(id As %String, revision As %Integer = 0) As %DynamicObject [ Private ]
{
    If '$Match(id,"^flow-[a-f0-9]{64}$") Do ##class(Demo.Protocol).Fail("Exact flow identity required")
    If (revision<0)||(revision>100000)||((revision\1)'=revision) Do ##class(Demo.Protocol).Fail("Bounded flow revision required")
    If revision=0 Set revision=+$Get(^ContestProductionFlow("latest",id))
    If '$Data(^ContestProductionFlow("record",id,revision)) Do ##class(Demo.Protocol).Fail("Flow revision not found")
    Set value={}.%FromJSON(^ContestProductionFlow("record",id,revision))
    Do ##class(Contest.RouteGovernance).Shape(value,"id,production_id,flow_key,revision,parent_digest,binding,config,declaration_snapshot,recipient_snapshot,digest,created_by,created_at,record_hash")
    Do ..Integer(value,"revision",1), ..Hash(value,"digest"), ..Hash(value,"record_hash"), ..ValidateConfig(value.config)
    Set copy={}.%FromJSON(value.%ToJSON())
    Do copy.%Remove("record_hash")
    If value.%Get("record_hash")'=##class(Contest.ExportEvidence).Digest(copy) Do ##class(Demo.Protocol).Fail("Flow record integrity mismatch")
    Do ##class(Contest.RouteGovernance).Shape(value.binding,"instance_id,namespace,production,config_hash"), ..Hash(value.binding,"config_hash")
    If (value.id'=id)||(value.revision'=revision)||(id'=..Key(value.%Get("production_id"),value.%Get("flow_key"))) Do ##class(Demo.Protocol).Fail("Flow identity or revision mismatch")
    If value.%Get("production_id")'=##class(Contest.ProductionMonitor).Key(value.binding.namespace,value.binding.production) Do ##class(Demo.Protocol).Fail("Flow Production binding mismatch")
    If value.binding.%Get("instance_id")'="local-iris" Do ##class(Demo.Protocol).Fail("Local IRIS flow binding required")
    Set core={"binding":(value.binding),"config":(value.config),"declaration_snapshot":null,"recipient_snapshot":(value.%Get("recipient_snapshot"))}
    If value.%GetTypeOf("declaration_snapshot")="object" Do core.%Set("declaration_snapshot",value.%Get("declaration_snapshot"))
    If value.digest'=##class(Contest.ExportEvidence).Digest(core) Do ##class(Demo.Protocol).Fail("Flow configuration digest mismatch")
    Set managed=##class(Contest.ProductionMonitor).Record(value.%Get("production_id"))
    Quit value
}

ClassMethod Save(body As %DynamicObject) As %DynamicObject
{
    Do ..Access(1)
    Try {
        Do ##class(Contest.RouteGovernance).Shape(body,"production_id,flow_key,expected_revision,expected_digest,production_config_hash,config")
        Do ##class(Contest.RouteGovernance).Text(body,"production_id"), ##class(Contest.RouteGovernance).Text(body,"flow_key")
        Set id=..Key(body.%Get("production_id"),body.%Get("flow_key"))
        Do ..ValidateConfig(body.config), ..Integer(body,"expected_revision",0,99999), ..Hash(body,"production_config_hash")
        Set parent=body.%Get("expected_revision"), revision=parent+1
        If parent=0 {
            If (body.%GetTypeOf("expected_digest")'="string")||(body.%Get("expected_digest")'="") Do ##class(Demo.Protocol).Fail("First flow revision requires empty parent digest")
        } Else { Do ..Hash(body,"expected_digest") }
        Set managed=##class(Contest.ProductionMonitor).Record(body.%Get("production_id"))
        Lock +^ContestProductionFlow("lock",id):2
        If '$Test Do ##class(Demo.Protocol).Fail("Flow revision busy")
        Try {
            Set latest=+$Get(^ContestProductionFlow("latest",id))
            If $Data(^ContestProductionFlow("record",id,revision)) {
                Set stored=..Load(id,revision)
                If (latest'=revision)||(stored.%Get("parent_digest")'=body.%Get("expected_digest"))||(stored.binding.%Get("config_hash")'=body.%Get("production_config_hash"))||(##class(Contest.ExportEvidence).Digest(stored.config)'=##class(Contest.ExportEvidence).Digest(body.config)) Do ##class(Demo.Protocol).Fail("Stale or conflicting flow revision")
            } Else {
                If latest'=parent Do ##class(Demo.Protocol).Fail("Stale expected flow revision")
                If parent>0 {
                    Set previous=..Load(id,parent)
                    If previous.digest'=body.%Get("expected_digest") Do ##class(Demo.Protocol).Fail("Flow parent digest mismatch")
                }
                Set snapshot=##class(Contest.ProductionMonitor).Snapshot(managed.namespace)
                If ('snapshot.running)||(snapshot.id'=managed.id)||(snapshot.%Get("config_hash")'=body.%Get("production_config_hash")) Do ##class(Demo.Protocol).Fail("Active Production or configuration changed; refresh before saving")
                Do ..Hosts(body.config,snapshot)
                Set declaration=""
                If body.config.%GetTypeOf("declaration")'="null" {
                    Set source=##class(Contest.DeclarationService).Read(body.config.declaration.%Get("record_id"))
                    If source.digest'=body.config.declaration.digest Do ##class(Demo.Protocol).Fail("Declaration revision digest mismatch")
                    Set declaration={"record_id":(source.id),"declaration_id":(source.%Get("declaration_id")),"revision":(source.revision),"digest":(source.digest),"proposal":(source.proposal),"context":(source.context),"decision":null}
                    If source.%GetTypeOf("decision")="object" Do declaration.%Set("decision",source.decision)
                }
                Set binding={"instance_id":(snapshot.%Get("instance_id")),"namespace":(snapshot.namespace),"production":(snapshot.production),"config_hash":(snapshot.%Get("config_hash"))}
                Set core={"binding":(binding),"config":(body.config),"declaration_snapshot":null,"recipient_snapshot":(##class(Contest.DeclarationCatalog).Recipient(body.config.%Get("recipient_id")))}
                If $IsObject(declaration) Do core.%Set("declaration_snapshot",declaration)
                Set stored={"id":(id),"production_id":(managed.id),"flow_key":(body.%Get("flow_key")),"revision":(revision),"parent_digest":(body.%Get("expected_digest")),"binding":(binding),"config":(body.config),"declaration_snapshot":null,"recipient_snapshot":(core.%Get("recipient_snapshot")),"digest":(##class(Contest.ExportEvidence).Digest(core)),"created_by":($Username),"created_at":(##class(Demo.Protocol).Now())}
                If $IsObject(declaration) Do stored.%Set("declaration_snapshot",declaration)
                Do stored.%Set("record_hash",##class(Contest.ExportEvidence).Digest(stored))
                TStart
                Try {
                    Set ^ContestProductionFlow("record",id,revision)=stored.%ToJSON(), ^ContestProductionFlow("latest",id)=revision
                    Set ^ContestProductionFlow("production",managed.id,id)=1
                    Do ##class(Contest.KnowledgeService).Audit("production.flow.saved",id,revision_"|"_stored.digest)
                    TCommit
                } Catch ex { TRollback 1 Throw ex }
            }
        } Catch ex { Lock -^ContestProductionFlow("lock",id) Throw ex }
        Lock -^ContestProductionFlow("lock",id)
    } Catch ex {
        Do ##class(Contest.KnowledgeService).Audit("production.flow.save.rejected","",ex.DisplayString())
        Throw ex
    }
    Quit ..Read(id,revision)
}

ClassMethod Read(id As %String, revision As %Integer = 0) As %DynamicObject
{
    Do ..Access()
    Set value=..Load(id,revision)
    Do value.%Set("monitoring_prerequisite",0,"boolean")
    Do value.%Set("coverage",{"state":"optional_context_only","automatic_review":false,"topology":"configured_hosts_not_observed_edges","purpose":"declared_not_observed","recipient":"registered_selection_not_delivery_proof","reason":"Optional versioned review context, not a discovered flow or collection filter. Production enrollment covers all its component activity without these records. Sampled AI review requires separate Production-level authorization; this record grants none."}), value.%Set("model_calls",0)
    Quit value
}

ClassMethod List(productionId As %String, after As %String = "") As %DynamicObject
{
    Do ..Access()
    Set managed=##class(Contest.ProductionMonitor).Record(productionId)
    If (after'="")&&('$Match(after,"^flow-[a-f0-9]{64}$")) Do ##class(Demo.Protocol).Fail("Exact flow page cursor required")
    Set items=[], id=after
    For {
        Set id=$Order(^ContestProductionFlow("production",productionId,id))
        If id="" Quit
        Do items.%Push(..Read(id))
        If items.%Size()=25 Quit
    }
    Set next=$Select((id'="")&&($Order(^ContestProductionFlow("production",productionId,id))'=""):id,1:"")
    Set result={"production_id":(productionId),"items":(items),"next_after":(next),"model_calls":0,"record_kind":"optional_review_context","discovered_flows":false,"monitoring_prerequisite":false}
    Do result.%Set("can_manage",$System.Security.Check("ContestMonitorDeploy","U"),"boolean")
    Quit result
}
}
