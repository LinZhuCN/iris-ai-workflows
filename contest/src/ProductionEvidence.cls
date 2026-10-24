Class Contest.ProductionEvidence
{
ClassMethod Access(write As %Boolean = 0) [ Private ]
{
    If ($Namespace'="TRIAGE")||('$System.Security.Check($Select(write:"ContestMonitorDeploy",1:"ContestMonitorRead"),"U")) Do ##class(Demo.Protocol).Fail("Production evidence capability required")
}

ClassMethod Identity(production As %String, header As %Numeric) As %String
{
    If ('$Match(production,"^production-[a-f0-9]{64}$"))||(header<1)||((header\1)'=header) Do ##class(Demo.Protocol).Fail("Exact Production and integer header identity required")
    Quit "observation-"_##class(Demo.Protocol).Hash(production_"|"_header)
}

ClassMethod Walk(value, prefix As %String, result As %DynamicObject, ByRef count As %Integer, depth As %Integer = 0) [ Private ]
{
    If depth>16 Do ##class(Demo.Protocol).Fail("Structured inspection depth exceeded")
    If '$IsObject(value) Quit
    Set iterator=value.%GetIterator()
    While iterator.%GetNext(.key,.child) {
        Set count=count+1
        If count>2000 Do ##class(Demo.Protocol).Fail("Structured inspection node limit exceeded")
        If (prefix="")&&(key="export_context")&&result.%IsDefined("export_context") Continue
        If value.%IsA("%DynamicArray") {
            If $IsObject(child) Do ..Walk(child,prefix,result,.count,depth+1)
            Continue
        }
        Set allowed=",id,identifier,name,family,given,birthDate,telecom,address,line,city,state,postalCode,country,gender,status,class,system,code,subject,reference,period,start,end,patient_id,mrn,email,phone,encounter,resourceType,extension,url,valueString,"
        If allowed'[(","_key_",") {
            Do result.%Set("unknown_fields",result.%Get("unknown_fields")+1)
            Continue
        }
        Set path=$Select(prefix="":key,1:prefix_"."_key)
        If $IsObject(child)&&(child.%Size()>0)&&((",identifier,name,given,telecom,address,")[(","_key_",")) Do result.%Set("identifier_present",1,"boolean")
        If '$IsObject(child) {
            If (child'="")&&((",id,identifier,name,family,given,telecom,address,reference,patient_id,mrn,email,phone,")[(","_key_",")) Do result.%Set("identifier_present",1,"boolean")
            If ((key="birthDate")||(key="start")||(key="end"))&&(child'="") {
                Do result.%Set("date_present",1,"boolean")
                Set category=$Select($Match(child,"^[0-9]{4}$"):"year_only",$Match(child,"^[0-9]{4}-[0-9]{2}-[0-9]{2}.*$"):"full_date",1:"other")
                Do result.dates.%Set(category,result.dates.%Get(category)+1)
            }
        }
        If 'result.fields.%IsDefined(path) {
            If result.fields.%Size()>=64 Do ##class(Demo.Protocol).Fail("Structured inspection field limit exceeded")
            Do result.fields.%Set(path,1)
        }
        If $IsObject(child) Do ..Walk(child,path,result,.count,depth+1)
    }
}

ClassMethod Inspect(value, format As %String) As %DynamicObject
{
    Do ##class(Contest.RiskReview).Object(value)
    If value.%Size()=0 Do ##class(Demo.Protocol).Fail("Empty structured payload is not a clean observation")
    Set result={"format":(format),"record_count":0,"fields":{},"identifier_present":false,"date_present":false,"dates":{"year_only":0,"full_date":0,"other":0},"unknown_fields":0,"classification":"bounded_allowlist_unknown_subtrees_not_inspected","deidentification":"not_established"}, count=0
    If format="json-object" {
        If value.%IsDefined("export_context") {
            Set context=value.%Get("export_context")
            Do ##class(Contest.RouteGovernance).Shape(context,"schema,synthetic,purpose,recipient,method,processing_status")
            If (context.%GetTypeOf("schema")'="number")||(context.schema'=1)||(context.%GetTypeOf("synthetic")'="boolean")||('context.synthetic) Do ##class(Demo.Protocol).Fail("Synthetic export context schema 1 required")
            Do ##class(Contest.DeclarationCatalog).Choice(context,"purpose",["external_statistics"])
            Do ##class(Contest.DeclarationCatalog).Choice(context,"recipient",["external_analytics"])
            Do ##class(Contest.DeclarationCatalog).Choice(context,"method",["safe_harbor"])
            Do ##class(Contest.DeclarationCatalog).Choice(context,"processing_status",["deidentified"])
            Do result.%Set("export_context",context)
        }
        Do result.%Set("record_count",1)
        Do ..Walk(value,"",result,.count)
    } ElseIf format="fhir-r4" {
        If (value.resourceType'="Bundle")||(value.%GetTypeOf("entry")'="array") Do ##class(Demo.Protocol).Fail("FHIR Bundle entry array required")
        If (value.entry.%Size()<1)||(value.entry.%Size()>100) Do ##class(Demo.Protocol).Fail("FHIR record limit exceeded or empty Bundle")
        For i=0:1:value.entry.%Size()-1 {
            Set entry=value.entry.%Get(i)
            Do ##class(Contest.RiskReview).Object(entry)
            Set resource=entry.resource
            Do ##class(Contest.RiskReview).Object(resource)
            If '((resource.resourceType="Patient")||(resource.resourceType="Encounter")||(resource.resourceType="Condition")||(resource.resourceType="MedicationRequest")) Do ##class(Demo.Protocol).Fail("FHIR resource requires a registered classifier")
            Do ..Walk(resource,resource.resourceType,result,.count)
        }
        Do result.%Set("record_count",value.entry.%Size())
    } Else { Do ##class(Demo.Protocol).Fail("Unsupported structured format") }
    Quit result
}

ClassMethod Authorize(body As %DynamicObject) As %DynamicObject
{
    Do ..Access(1), ##class(Contest.RouteGovernance).Shape(body,"production_id,config_hash,acknowledge_local_synthetic_inspection")
    If (body.%GetTypeOf("acknowledge_local_synthetic_inspection")'="boolean")||('body.%Get("acknowledge_local_synthetic_inspection")) Do ##class(Demo.Protocol).Fail("Explicit local synthetic payload-inspection consent required")
    Set item=##class(Contest.ProductionMonitor).Record(body.%Get("production_id")), current=##class(Contest.ProductionMonitor).Snapshot(item.namespace)
    If (current.id'=item.id)||('current.running)||(current.%Get("config_hash")'=body.%Get("config_hash")) Do ##class(Demo.Protocol).Fail("Exact active Production configuration required")
    Lock +^ContestProductionMonitor("worker"):2
    If '$Test Do ##class(Demo.Protocol).Fail("Production observer busy")
    Try {
        Set grant={"production_id":(item.id),"config_hash":(current.%Get("config_hash")),"enabled":true,"actor":($Username),"authorized_at":(##class(Demo.Protocol).Now()),"scope":"local registered structured message properties only; no external calls"}
        Set ^ContestProductionEvidence("allow",item.id)=grant.%ToJSON()
    } Catch ex { Lock -^ContestProductionMonitor("worker") Throw ex }
    Lock -^ContestProductionMonitor("worker")
    Do ##class(Contest.KnowledgeService).Audit("production.evidence.authorized",item.id,current.%Get("config_hash"))
    Quit grant
}

ClassMethod Revoke(body As %DynamicObject) As %DynamicObject
{
    Do ..Access(1), ##class(Contest.RouteGovernance).Shape(body,"production_id")
    Set item=##class(Contest.ProductionMonitor).Record(body.%Get("production_id"))
    Lock +^ContestProductionMonitor("worker"):2
    If '$Test Do ##class(Demo.Protocol).Fail("Production observer busy")
    Try {
        Set grant={"production_id":(item.id),"enabled":false,"actor":($Username),"revoked_at":(##class(Demo.Protocol).Now())}
        Set ^ContestProductionEvidence("allow",item.id)=grant.%ToJSON()
    } Catch ex { Lock -^ContestProductionMonitor("worker") Throw ex }
    Lock -^ContestProductionMonitor("worker")
    Do ##class(Contest.KnowledgeService).Audit("production.evidence.revoked",item.id,"Retained observations unchanged; future body reads disabled.")
    Quit grant
}

ClassMethod Payload(item As %DynamicObject, row As %DynamicObject, snapshot As %DynamicObject) As %DynamicObject [ Private ]
{
    Set result={"state":"unsupported","reason":"No registered structured-property adapter for this message class.","facts":null,"body_digest":""}
    Set class=row.%Get("body_class")
    If (class'="Contest.Aggregation.SendRequest")&&(class'="Contest.StructuredRequest")&&(class'="Contest.M5.Request")&&(class'="Contest.Multi.SendRequest") Quit result
    If '$Data(^ContestProductionEvidence("allow",item.id)) {
        Set result.state="not_authorized", result.reason="Local payload inspection has not been explicitly authorized."
        Quit result
    }
    Set grant={}.%FromJSON(^ContestProductionEvidence("allow",item.id))
    If 'grant.%Get("enabled",1) {
        Set result.state="not_authorized", result.reason="Local payload inspection consent was revoked."
        Quit result
    }
    If grant.%Get("config_hash")'=snapshot.%Get("config_hash") {
        Set result.state="not_authorized", result.reason="Production configuration changed; renew local inspection consent."
        Quit result
    }
    Set previous=$Namespace
    Try {
        Set $Namespace=item.namespace
        Set body=$ClassMethod(class,"%OpenId",row.%Get("body_id"))
        If '$IsObject(body) Do $System.Status.ThrowStatus($$$ERROR($$$GeneralError,"Persisted structured message missing"))
        If class="Contest.Aggregation.SendRequest" {
            Set text=body.Bundle, format="fhir-r4"
        } ElseIf class="Contest.Multi.SendRequest" {
            Set text=body.Payload, branch=body.Branch
            Set wirefacts={}.%FromJSON(##class(Contest.Multi.Runtime).Inspect(branch,text))
        } Else { Set text=body.PayloadJson, format=body.Format }
        Set $Namespace=previous
        If ($Length(text)>100000)||(text="") Do ##class(Demo.Protocol).Fail("Structured payload size invalid")
        If class="Contest.Multi.SendRequest" {
            Set result.facts=##class(Contest.MultiObservation).Normalize(wirefacts,branch)
        } Else {
            Set result.facts=..Inspect({}.%FromJSON(text),format)
        }
        Do result.%Set("body_digest",##class(Demo.Protocol).Hash($ZConvert(text,"O","UTF8")))
        Do result.%Set("authorization",grant)
        Set result.state="captured", result.reason="Minimized local inspection; values are not stored in this observation."
    } Catch ex {
        Set $Namespace=previous, result.state="evidence_failed", result.reason="Local structured inspection failed; no assessment or automatic retry.", result.facts=""
        Do result.%Set("facts","","null")
        Do ##class(Contest.KnowledgeService).Audit("production.evidence.capture.failed",item.id_"|"_row.%Get("header_id"),ex.DisplayString())
    }
    Set confirmed=##class(Contest.ProductionMonitor).Snapshot(item.namespace)
    If (confirmed.id'=item.id)||('confirmed.running)||(confirmed.%Get("config_hash")'=snapshot.%Get("config_hash")) Do ##class(Demo.Protocol).Fail("Production changed during payload inspection; retain cursor")
    Quit result
}

ClassMethod Capture(item As %DynamicObject, row As %DynamicObject, snapshot As %DynamicObject)
{
    Do ..Access(1)
    If (snapshot.id'=item.id)||(snapshot.namespace'=item.namespace)||(snapshot.production'=item.production) Do ##class(Demo.Protocol).Fail("Capture snapshot belongs to a different Production")
    Set header=row.%Get("header_id"), id=..Identity(item.id,header)
    If $Data(^ContestProductionEvidence("record",item.id,header)) Quit
    Set payload=..Payload(item,row,snapshot)
    Set edge=##class(Demo.Protocol).Hash(row.source_"|"_row.target)
    Set value={"id":(id),"collector_version":"production-evidence-v1","production_id":(item.id),"namespace":(item.namespace),"production":(item.production),"header":(row),"observed_config_hash":(snapshot.%Get("config_hash")),"attribution":"sampled_active_production_and_component_names_not_historical_proof","capture":(payload),"review_state":"not_enabled_m3","context_state":"business_purpose_and_recipient_not_established","outcome":($Select(row.%Get("is_error"):"failed",1:"attempted")),"delivery_evidence":"message_header_only","edge_id":(edge),"captured_at":(##class(Demo.Protocol).Now()),"limits":["Session membership and observed edges do not prove a complete ordered business path.","Successful message status is not receiver acceptance or downstream purpose.","Configuration is pinned at inspection time, not proven at original send time.","Field presence and date representation do not prove a source-to-output transformation or comprehensive identifier detection."],"model_calls":0}
    Do value.%Set("record_hash",##class(Contest.ExportEvidence).Digest(value))
    Set ^ContestProductionEvidence("record",item.id,header)=value.%ToJSON()
    Set ^ContestProductionEvidence("session",item.id,row.%Get("session_id"),header)=1
    Set ^ContestProductionEvidence("edge",item.id,edge,header)=1
    Set ^ContestProductionEvidence("edgeInfo",item.id,edge)={"id":(edge),"source":(row.source),"target":(row.target),"basis":"actual_message_header"}.%ToJSON()
    Set ^ContestProductionEvidence("count",item.id,payload.state)=$Get(^ContestProductionEvidence("count",item.id,payload.state))+1
    If payload.state'="captured" Do ##class(Contest.ProductionMonitor).Emit(item.id,"evidence-"_header,"coverage_gap","warning",payload.reason,{"observation_id":(id),"header_id":(header),"capture_state":(payload.state)})
}

ClassMethod Read(id As %String, header As %Numeric) As %DynamicObject
{
    Do ..Access()
    Set identity=..Identity(id,header)
    If '$Data(^ContestProductionEvidence("record",id,header)) Do ##class(Demo.Protocol).Fail("Production observation not found")
    Set value={}.%FromJSON(^ContestProductionEvidence("record",id,header)), copy={}.%FromJSON(value.%ToJSON())
    Do copy.%Remove("record_hash")
    If (value.id'=identity)||(value.%Get("production_id")'=id)||(value.%Get("record_hash")'=##class(Contest.ExportEvidence).Digest(copy)) Do ##class(Demo.Protocol).Fail("Observation integrity mismatch")
    Quit value
}

ClassMethod Page(id As %String, before As %Numeric = 0, session As %String = "") As %DynamicObject
{
    Do ..Access()
    Set item=##class(Contest.ProductionMonitor).Record(id)
    If (before<0)||((before\1)'=before)||(before>1000000000000000) Do ##class(Demo.Protocol).Fail("Bounded evidence page cursor required")
    If (session'="")&&('$Match(session,"^[0-9]{1,15}$")) Do ##class(Demo.Protocol).Fail("Numeric source session required")
    Set items=[], header=$Select(before>0:before,1:""), cursor=0
    For i=1:1:25 {
        Set header=$Select(session="":$Order(^ContestProductionEvidence("record",id,header),-1),1:$Order(^ContestProductionEvidence("session",id,session,header),-1))
        If header="" Quit
        Set value=..Read(id,header)
        Do value.%Set("current_review",##class(Contest.ProductionReviewService).Lookup(id,header))
        Do items.%Push(value)
        Set cursor=+header
    }
    Set older=$Select(session="":$Order(^ContestProductionEvidence("record",id,cursor),-1),1:$Order(^ContestProductionEvidence("session",id,session,cursor),-1))
    Set counts={}, state=""
    For { Set state=$Order(^ContestProductionEvidence("count",id,state)) Quit:state=""  Do counts.%Set(state,^ContestProductionEvidence("count",id,state)) }
    Quit {"production_id":(id),"items":(items),"next_before":($Select((cursor>0)&&(older'=""):cursor,1:0)),"capture_counts":(counts),"observer":{"last_scan":(item.%Get("last_scan")),"error":(item.error),"batch_full":(item.%Get("header_batch_full",0)),"unattributed_headers":(item.%Get("unattributed_header_count",0)),"retention_loss_detection":"not_available","retention":"no_automatic_purge"},"model_calls":0,"model_calls_scope":"local capture only; current_review reports separately authorized inference","review_overlay":"current_review is live and excluded from the immutable observation record_hash; review_state is capture-time history.","history":"Evidence starts with new observer collection after M2 installation; no automatic body backfill."}
}

ClassMethod Paths(id As %String, after As %String = "") As %DynamicObject
{
    Do ..Access()
    Set item=##class(Contest.ProductionMonitor).Record(id)
    If (after'="")&&('$Match(after,"^[a-f0-9]{64}$")) Do ##class(Demo.Protocol).Fail("Exact observed-edge cursor required")
    Set items=[], key=after, cursor=""
    For i=1:1:25 {
        Set key=$Order(^ContestProductionEvidence("edgeInfo",id,key))
        If key="" Quit
        Do items.%Push({}.%FromJSON(^ContestProductionEvidence("edgeInfo",id,key)))
        Set cursor=key
    }
    Quit {"production_id":(id),"items":(items),"next_after":($Select((cursor'="")&&($Order(^ContestProductionEvidence("edgeInfo",id,cursor))'=""):cursor,1:"")),"scope":"Observed edges; query evidence by source session for correlation. Not inferred end-to-end paths.","model_calls":0}
}
}
