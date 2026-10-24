Class Contest.FlowEvidence
{
ClassMethod Validate(value As %DynamicObject, flow As %DynamicObject)
{
    Do ##class(Contest.RouteGovernance).Shape(value,"schema,synthetic,binding,observation,references,packet,limits")
    Do ##class(Contest.ProductionFlow).Integer(value,"schema",1,1)
    If (value.%GetTypeOf("synthetic")'="boolean")||('value.synthetic) Do ##class(Demo.Protocol).Fail("Synthetic evidence contract required")
    Set binding=value.binding, observation=value.observation
    Do ##class(Contest.RouteGovernance).Shape(binding,"flow_id,revision,flow_digest,production_id,config_hash")
    For field="flow_id","production_id" Do ##class(Contest.RouteGovernance).Text(binding,field,128)
    Do ##class(Contest.ProductionFlow).Integer(binding,"revision",1), ##class(Contest.ProductionFlow).Hash(binding,"flow_digest"), ##class(Contest.ProductionFlow).Hash(binding,"config_hash")
    If (binding.%Get("flow_id")'=flow.id)||(binding.revision'=flow.revision)||(binding.%Get("flow_digest")'=flow.digest)||(binding.%Get("production_id")'=flow.%Get("production_id"))||(binding.%Get("config_hash")'=flow.binding.%Get("config_hash")) Do ##class(Demo.Protocol).Fail("Evidence belongs to a different flow, revision or Production")
    Do ##class(Contest.RouteGovernance).Shape(observation,"source_key,observed_at,session_id,message_id,batch_id,outcome,delivery_evidence")
    For field="source_key","session_id","message_id" Do ##class(Contest.RouteGovernance).Text(observation,field,128)
    If (observation.%GetTypeOf("batch_id")'="string")||($Length(observation.%Get("batch_id"))>128) Do ##class(Demo.Protocol).Fail("Bounded optional batch identity required")
    If (observation.%GetTypeOf("observed_at")'="number")||(observation.%Get("observed_at")<1)||(observation.%Get("observed_at")>100000000000) Do ##class(Demo.Protocol).Fail("Evidence timestamp required")
    Do ##class(Contest.DeclarationCatalog).Choice(observation,"outcome",["attempted","failed","received","held","unknown"])
    Do ##class(Contest.DeclarationCatalog).Choice(observation,"delivery_evidence",["message_header","sender_result","receiver_ack","receiver_readback"])
    If (observation.outcome="received")&&('((observation.%Get("delivery_evidence")="receiver_ack")||(observation.%Get("delivery_evidence")="receiver_readback"))) Do ##class(Demo.Protocol).Fail("Message headers or sender results cannot prove receiver acceptance")
    If value.%GetTypeOf("references")'="array" Do ##class(Demo.Protocol).Fail("Evidence references array required")
    If (value.references.%Size()<1)||(value.references.%Size()>32) Do ##class(Demo.Protocol).Fail("Bounded nonempty local evidence references required")
    Set seen={}, received=0, readback=0, header=0, sender=0
    For i=0:1:value.references.%Size()-1 {
        Set ref=value.references.%Get(i)
        Do ##class(Contest.RouteGovernance).Shape(ref,"kind,id,digest"), ##class(Contest.ProductionFlow).Hash(ref,"digest")
        Do ##class(Contest.DeclarationCatalog).Choice(ref,"kind",["message_header","message_body","sender_result","receiver_receipt","receiver_readback","config_snapshot"])
        If (ref.%GetTypeOf("id")'="string")||('$Match(ref.id,"^[A-Za-z0-9][A-Za-z0-9_.-]{0,127}$")) Do ##class(Demo.Protocol).Fail("Bounded local evidence reference required; no URLs or expressions")
        Set key=ref.kind_"|"_ref.id
        If seen.%IsDefined(key) Do ##class(Demo.Protocol).Fail("Duplicate evidence reference")
        Do seen.%Set(key,1)
        If ref.kind="message_header" {
            If ref.id'=observation.%Get("message_id") Do ##class(Demo.Protocol).Fail("Message-header reference differs from observation identity")
            Set header=1
        }
        If ref.kind="sender_result" Set sender=1
        If ref.kind="receiver_receipt" Set received=1
        If ref.kind="receiver_readback" Set readback=1
    }
    If ((observation.%Get("delivery_evidence")="message_header")&&('header))||((observation.%Get("delivery_evidence")="sender_result")&&('sender))||((observation.%Get("delivery_evidence")="receiver_ack")&&('received))||((observation.%Get("delivery_evidence")="receiver_readback")&&('readback)) Do ##class(Demo.Protocol).Fail("Delivery evidence level requires its matching local reference")
    Do ##class(Contest.RiskReviewV4).ValidatePacket(value.packet)
    If value.packet.stage'="after_send" Do ##class(Demo.Protocol).Fail("Observed-use review packet required; outcome separately records delivery status")
    If value.%GetTypeOf("limits")'="array" Do ##class(Demo.Protocol).Fail("Explicit coverage limits required")
    If (value.limits.%Size()<1)||(value.limits.%Size()>16) Do ##class(Demo.Protocol).Fail("Bounded nonempty coverage limits required")
    For i=0:1:value.limits.%Size()-1 {
        If (value.limits.%GetTypeOf(i)'="string")||($ZStrip(value.limits.%Get(i),"<>W")="")||($Length(value.limits.%Get(i))>1000) Do ##class(Demo.Protocol).Fail("Bounded coverage-limit text required")
    }
}
}
