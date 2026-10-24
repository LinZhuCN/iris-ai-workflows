Class Contest.RouteEvidence
{
ClassMethod Receipt(receipt As %DynamicObject, expected As %String)
{
    If '$Match(expected,"^[a-f0-9]{64}$") Do ##class(Demo.Protocol).Fail("Independent receipt digest required")
    Set copy={}.%FromJSON(receipt.%ToJSON()), digest=copy.%Get("receipt_hash")
    Do copy.%Remove("receipt_hash")
    If (digest'=expected)||(digest'=##class(Contest.ExportEvidence).Digest(copy)) Do ##class(Demo.Protocol).Fail("Receipt integrity or independent pin mismatch")
}

ClassMethod Binding(kind As %String, configHash As %String) As %DynamicObject [ Private ]
{
    If kind="aggregation" Quit {"instance_id":"local-triage-real","namespace":"PIPELINE","production":"Contest.Aggregation.Production","source":"SQLSource","sender":"FHIRSender","point":"before_send","config_hash":(configHash),"collector_version":"aggregation-receipt-v1","policy_version":"aggregation-exact-scope-v1"}
    Quit {"instance_id":"local-triage-real","namespace":"UTILIZATION","production":"Contest.Utilization.Production","source":"FHIRSource","sender":"AnalysisReceiver","point":"before_send","config_hash":(configHash),"collector_version":"utilization-receipt-v1","policy_version":"utilization-exact-scope-v1"}
}

ClassMethod Messages(record As %DynamicObject, kind As %String) [ Private ]
{
    Set previous=$Namespace
    Try {
        Set $Namespace=$Select(kind="aggregation":"PIPELINE",1:"UTILIZATION")
        Set receipt=record.receipt, source=##class(Contest.Aggregation.Request).%OpenId(receipt.%Get("message_id"))
        Set send=##class(Contest.Aggregation.SendRequest).%OpenId(receipt.%Get($Select(kind="aggregation":"send_message_id",1:"receiver_message_id")))
        If ('$IsObject(source))||('$IsObject(send)) Do ##class(Demo.Protocol).Fail("Persisted route messages missing")
        For field="BatchId","ApprovalId","ScopeHash" {
            Set expected=record.%Get($Select(field="BatchId":"batch_id",field="ApprovalId":"approval_id",1:"scope_hash"))
            If ($Property(source,field)'=expected)||($Property(send,field)'=expected) Do ##class(Demo.Protocol).Fail("Persisted route message scope mismatch")
        }
        If send.Bundle'=record.bundle.%ToJSON() Do ##class(Demo.Protocol).Fail("Persisted sender payload mismatch")
        Set target=$Select(kind="aggregation":"AggregationProcess",1:"UtilizationProcess"), sender=$Select(kind="aggregation":"SQLSource",1:"FHIRSource")
        Set result=##class(%SQL.Statement).%ExecDirect(,"SELECT COUNT(*) AS N FROM Ens.MessageHeader WHERE MessageBodyClassName=? AND MessageBodyId=? AND SessionId=? AND SourceConfigName=? AND TargetConfigName=?","Contest.Aggregation.Request",source.%Id(),receipt.%Get("session_id"),sender,target)
        Do ##class(Contest.Aggregation.Data).Check(result)
        Set next=result.%Next()
        If result.%Get("N")'=1 Do ##class(Demo.Protocol).Fail("Source message/session header linkage mismatch")
        Set destination=$Select(kind="aggregation":"FHIRSender",1:"AnalysisReceiver")
        Set result=##class(%SQL.Statement).%ExecDirect(,"SELECT COUNT(*) AS N FROM Ens.MessageHeader WHERE MessageBodyClassName=? AND MessageBodyId=? AND SessionId=? AND SourceConfigName=? AND TargetConfigName=?","Contest.Aggregation.SendRequest",send.%Id(),receipt.%Get("session_id"),target,destination)
        Do ##class(Contest.Aggregation.Data).Check(result)
        Set next=result.%Next()
        If result.%Get("N")'=1 Do ##class(Demo.Protocol).Fail("Sender message/session header linkage mismatch")
    } Catch ex { Set $Namespace=previous Throw ex }
    Set $Namespace=previous
}

ClassMethod Validate(kind As %String, record As %DynamicObject, dossier As %DynamicObject, pin As %String)
{
    For field="source","config","bundle","inspection","approval","receipt" {
        If '$IsObject(record.%Get(field)) Do ##class(Demo.Protocol).Fail("Incomplete historical evidence snapshot: "_field)
    }
    Do ..Receipt(record.receipt,pin)
    Set receipt=record.receipt
    If (record.state'="delivered")||(receipt.outcome'="delivered")||(receipt.%Get("batch_id")'=record.%Get("batch_id"))||(receipt.synthetic'=1)||(receipt.%Get("model_calls")'=0) Do ##class(Demo.Protocol).Fail("Completed synthetic route evidence required")
    For field="source_hash","output_hash","config_hash","approval_id","scope_hash","session_id" {
        If record.%Get(field)'=receipt.%Get(field) Do ##class(Demo.Protocol).Fail("Batch/receipt provenance mismatch: "_field)
    }
    Set messageField=$Select(kind="aggregation":"request_id",1:"message_id")
    If record.%Get(messageField)'=receipt.%Get("message_id") Do ##class(Demo.Protocol).Fail("Batch source message mismatch")
    For field="source","config" {
        If ##class(Contest.ExportEvidence).Digest(record.%Get(field))'=record.%Get(field_"_hash") Do ##class(Demo.Protocol).Fail("Frozen source/config integrity mismatch")
    }
    If ##class(Contest.ExportEvidence).Digest(record.bundle)'=record.%Get("output_hash") Do ##class(Demo.Protocol).Fail("Frozen output integrity mismatch")
    Set binding=..Binding(kind,record.%Get("config_hash"))
    For field="instance_id","namespace","production","source","sender","point","config_hash","collector_version","policy_version" {
        If dossier.core.binding.%Get(field)'=binding.%Get(field) Do ##class(Demo.Protocol).Fail("Historical approval binding mismatch")
    }
    If (dossier.id'=record.%Get("approval_id"))||(dossier.digest'=record.%Get("scope_hash"))||(dossier.core.declaration.kind'=kind) Do ##class(Demo.Protocol).Fail("Historical approval scope mismatch")
    If '$IsObject(dossier.approval) Do ##class(Demo.Protocol).Fail("Historical approval missing")
    If record.approval.%ToJSON()'=dossier.approval.%ToJSON() Do ##class(Demo.Protocol).Fail("Stored approval differs from registry")
    Set observed=receipt.%Get($Select(kind="aggregation":"verified_at",1:"received_at")), prepared=record.%Get("prepared_at")
    If (prepared<dossier.approval.%Get("approved_at"))||(observed<prepared)||(prepared<dossier.core.%Get("valid_from"))||(observed>=dossier.core.%Get("valid_until")) Do ##class(Demo.Protocol).Fail("Approval did not cover historical delivery interval")
    Set expected=$Select(kind="aggregation":##class(Contest.Aggregation.Mapping).Build(record.source),1:##class(Contest.Utilization.Runtime).Project(record.source))
    If expected.%ToJSON()'=record.bundle.%ToJSON() Do ##class(Demo.Protocol).Fail("Frozen output does not match versioned source transform")
    Set inspection=##class(Contest.Aggregation.Runtime).Inspect(record.bundle,dossier)
    If (inspection.%ToJSON()'=record.inspection.%ToJSON())||(inspection.%ToJSON()'=receipt.inspection.%ToJSON()) Do ##class(Demo.Protocol).Fail("Inspection differs from recomputed actual output")
    If kind="aggregation" {
        If record.binding.%ToJSON()'=binding.%ToJSON() Do ##class(Demo.Protocol).Fail("Frozen aggregation binding mismatch")
        Set wire=##class(Demo.Protocol).Hash($ZConvert(record.bundle.%ToJSON(),"O","UTF8"))
        If (wire'=record.%Get("wire_hash"))||(wire'=receipt.%Get("wire_hash")) Do ##class(Demo.Protocol).Fail("Serialized FHIR wire integrity mismatch")
        Do ##class(Contest.Aggregation.Mapping).ValidateResponse(record.bundle,record.%Get("transaction_response"))
        Set resources=record.%Get("readback_resources"), pins=receipt.readbacks
        If (resources.%Size()'=record.bundle.entry.%Size())||(pins.%Size()'=resources.%Size()) Do ##class(Demo.Protocol).Fail("Historical FHIR readback count mismatch")
        For i=0:1:resources.%Size()-1 {
            Set actual=resources.%Get(i), entry=record.bundle.entry.%Get(i), link=pins.%Get(i), response=record.%Get("transaction_response").entry.%Get(i).response
            If ('##class(Contest.Aggregation.Mapping).EqualValue(entry.resource,actual))||(link.resource'=entry.request.url)||(actual.resourceType_"/"_actual.id'=link.resource)||(link.version'=actual.meta.versionId)||(link.%Get("readback_hash")'=##class(Contest.ExportEvidence).Digest(actual))||(link.%Get("mapped_values_match")'=1) Do ##class(Demo.Protocol).Fail("Historical FHIR readback values or version pins mismatch")
            Set version=$Select(response.%IsDefined("etag"):$Piece(response.etag,"""",2),1:$Piece(response.location,"/_history/",2))
            If version'=actual.meta.versionId Do ##class(Demo.Protocol).Fail("Historical FHIR response/readback version mismatch")
        }
    } Else {
        Set pins=record.%Get("source_pins")
        If (pins.%Size()'=record.source.%Size())||(pins.%ToJSON()'=receipt.%Get("source_pins").%ToJSON()) Do ##class(Demo.Protocol).Fail("Source resource pin count mismatch")
        For i=0:1:pins.%Size()-1 {
            Set row=record.source.%Get(i), link=pins.%Get(i)
            If (link.resource'=(row.resourceType_"/"_row.id))||(link.version'=row.meta.versionId)||(link.hash'=##class(Contest.ExportEvidence).Digest(row)) Do ##class(Demo.Protocol).Fail("Frozen FHIR source version/hash mismatch")
        }
        If (receipt.transport'="same-instance-BO-to-SQL")||(receipt.recipient'="local-analysis-receiver")||(receipt.%Get("receiver_readback_match")'=1)||(receipt.deidentification'="not_established") Do ##class(Demo.Protocol).Fail("Unexpected utilization receipt contract")
    }
    If receipt.%Get("legal_authorization")'="not_established" Do ##class(Demo.Protocol).Fail("Receipt cannot establish legal authorization")
}

ClassMethod Identifiers(bundle As %DynamicObject) As %DynamicObject
{
    Set counts={"patient_name_values":0,"patient_identifier_values":0,"full_birth_dates":0,"year_only_birth_dates":0,"stable_resource_ids":0,"patient_references":0}
    For i=0:1:bundle.entry.%Size()-1 {
        Set row=bundle.entry.%Get(i).resource
        If row.%Get("id")'="" Do counts.%Set("stable_resource_ids",counts.%Get("stable_resource_ids")+1)
        If row.resourceType="Patient" {
            If $Match(row.%Get("birthDate"),"^[0-9]{4}-[0-9]{2}-[0-9]{2}$") Do counts.%Set("full_birth_dates",counts.%Get("full_birth_dates")+1)
            If $Match(row.%Get("birthDate"),"^[0-9]{4}$") Do counts.%Set("year_only_birth_dates",counts.%Get("year_only_birth_dates")+1)
            If row.%IsDefined("identifier") {
                For j=0:1:row.identifier.%Size()-1 {
                    If row.identifier.%Get(j).%Get("value")'="" Do counts.%Set("patient_identifier_values",counts.%Get("patient_identifier_values")+1)
                }
            }
            If row.%IsDefined("name") {
                For j=0:1:row.name.%Size()-1 {
                    Set name=row.name.%Get(j)
                    If name.%Get("family")'="" Do counts.%Set("patient_name_values",counts.%Get("patient_name_values")+1)
                    If name.%IsDefined("given") {
                        For k=0:1:name.given.%Size()-1 {
                            If name.given.%Get(k)'="" Do counts.%Set("patient_name_values",counts.%Get("patient_name_values")+1)
                        }
                    }
                }
            }
        } Else {
            If row.%IsDefined("subject") {
                If row.subject.%Get("reference")'="" Do counts.%Set("patient_references",counts.%Get("patient_references")+1)
            }
        }
    }
    Quit counts
}

ClassMethod Project(kind As %String, record As %DynamicObject, dossier As %DynamicObject) As %DynamicObject [ Private ]
{
    Set declaration=dossier.core.declaration, receipt=record.receipt, counts=..Identifiers(record.bundle)
    If '$IsObject(dossier.approval.%Get("scenario")) Do ##class(Demo.Protocol).Fail("Explicit organization-scenario approval required; reset the route demo before review")
    Set scenario=dossier.approval.scenario
    Do ##class(Contest.RouteScenario).Validate(declaration,scenario)
    Set context={"kind":(kind),"purpose_code":(declaration.%Get("purpose_code")),"owner":(declaration.owner),"service_identity":(declaration.%Get("service_identity")),"recipient":(declaration.recipient),"patient_selection":(declaration.scope.%Get("patient_selection"))}
    Set approved={"record_id":(dossier.id),"scope_hash":(dossier.digest),"declared_context":(context),"scope":(declaration.scope),"approved_by":(dossier.approval.%Get("approved_by")),"approved_at":(dossier.approval.%Get("approved_at")),"valid_from":(dossier.core.%Get("valid_from")),"valid_until":(dossier.core.%Get("valid_until")),"source":"synthetic-demo-manual-approval-v1","historical_scope_match":true,"legal_authorization":"not_established"}
    Set observation={"inspection":(record.inspection),"identifier_counts":(counts),"delivery":"delivered","transport":($Select(kind="aggregation":"authenticated-local-FHIR-HTTP",1:"same-instance-BO-to-SQL")),"message_id":(receipt.%Get("message_id")),"session_id":(receipt.%Get("session_id")),"observed_at":(receipt.%Get($Select(kind="aggregation":"verified_at",1:"received_at"))),"readback_basis":($Select(kind="aggregation":"frozen-original-FHIR-response-and-readback",1:"frozen-receipt-and-current-SQL-readback"))}
    Set destination=$Select(kind="aggregation":{"http_server":(record.config.%Get("http_server")),"http_port":(record.config.%Get("http_port")),"endpoint":(record.config.endpoint),"configured_identity":(record.config.identity)},1:{"receiver_table":(record.config.%Get("receiver_table")),"source_endpoint":(record.config.%Get("source_endpoint")),"configured_read_identity":(record.config.%Get("read_identity"))})
    Do observation.%Set("configured_recipient",record.config.recipient), observation.%Set("destination",destination), observation.%Set("runtime_binding",..Binding(kind,record.%Get("config_hash")))
    Set delivery={}.%FromJSON(observation.%ToJSON())
    Do delivery.%Remove("inspection"), delivery.%Remove("identifier_counts")
    Set approvedText=approved.%ToJSON()
    Do approved.%Set("scenario",scenario)
    Set limits="Coverage boundaries, not a checklist of missing release prerequisites: organization relationships and the internal-use path are explicit SYNTHETIC scenario premises bound to project approval, not evidence about a real hospital. The submitted purpose remains a claim to compare with policy. Observations verify configuration, scoped output and delivery, not all downstream conduct or a general PHI scan. Stable IDs remain linkable; this path does not rely on de-identification. Historical snapshots do not establish current-source freshness or atomic reads. Real legal compliance and later onward use are outside this scoped review. After-send review cannot block completed delivery."
    Set facts=[
        {"id":"declared_purpose","kind":"claim","origin":"synthetic_route_declaration","verification":"unverified","text":(declaration.%Get("purpose_text"))},
        {"id":"declared_context","kind":"claim","origin":"synthetic_route_declaration","verification":"unverified","text":(context.%ToJSON())},
        {"id":"approved_scope","kind":"observation","origin":"verified_synthetic_registry_record","verification":"verified","text":(approvedText)},
        {"id":"observed_output","kind":"observation","origin":"recomputed_frozen_output","verification":"verified","text":({"inspection":(record.inspection),"known_field_counts":(counts)}.%ToJSON())},
        {"id":"delivery_evidence","kind":"observation","origin":"persisted_messages_and_receiver","verification":"verified","text":(delivery.%ToJSON())},
        {"id":"evidence_limits","kind":"missing_information","origin":"explicit_monitoring_coverage_boundary","verification":"unknown","text":(limits)},
        {"id":"organization_policy","kind":"local_policy","origin":"synthetic_organization_policy_v1","verification":"verified","text":(scenario.conditions_" Permitted use: "_scenario.%Get("permitted_use")_" Patient authorization and de-identification are not prerequisites of this simulated internal-use path. A new external or research purpose requires separate review.")},
        {"id":"approved_scenario","kind":"observation","origin":"verified_synthetic_policy_approval_binding","verification":"verified","text":(scenario.%ToJSON())}
    ]
    Set packet={"synthetic":true,"stage":"after_send","facts":(facts),"required_questions":[{"topic":"recipient_purpose","fact_ids":["declared_purpose","declared_context","approved_scope","observed_output","delivery_evidence","evidence_limits","organization_policy","approved_scenario"],"question":"Within the approved SYNTHETIC internal-use scenario, compare submitted purpose, recipient, service configuration and actual data scope with organization policy and exact project approval. Explain any purpose contradiction, excess data or destination mismatch. Evaluate minimum-necessary concerns for the stated use, without certifying optimality. This path does not rely on de-identification or individual authorization. Report only material gaps preventing these comparisons; keep unmonitored future conduct and overall legal certification as coverage boundaries."}]}
    Do ##class(Contest.RiskReview).ValidatePacket(packet)
    Set refs=[], provenance={"source_hash":(record.%Get("source_hash")),"output_hash":(record.%Get("output_hash")),"config_hash":(record.%Get("config_hash")),"scope_hash":(record.%Get("scope_hash")),"receipt_hash":(receipt.%Get("receipt_hash"))}
    For i=0:1:facts.%Size()-1 {
        Do refs.%Push({"fact_id":(facts.%Get(i).id),"route_kind":(kind),"batch_id":(record.%Get("batch_id")),"approval_id":(dossier.id),"receipt_hash":(receipt.%Get("receipt_hash")),"method":"route-evidence-revalidation-v1","basis":(facts.%Get(i).origin)})
    }
    Set value={"schema":1,"adapter":"route-evidence-v2","synthetic":true,"route_kind":(kind),"batch_id":(record.%Get("batch_id")),"declaration":(context),"declared_purpose":(declaration.%Get("purpose_text")),"approved":(approved),"observed":(observation),"provenance":(provenance),"fact_evidence":(refs),"packet":(packet),"limitations":(limits),"execution":"not_executed","model_calls":0}
    Do value.%Set("evidence_hash",##class(Contest.ExportEvidence).Digest(value))
    Quit value
}

ClassMethod Read(kind As %String, batch As %String, receiptHash As %String) As %DynamicObject
{
    If $Namespace'="TRIAGE" Do ##class(Demo.Protocol).Fail("TRIAGE evidence reader required")
    If '$System.Security.Check("ContestMonitorRead","U") Do ##class(Demo.Protocol).Fail("Route evidence read capability required")
    Try {
        If '((kind="aggregation")||(kind="utilization")) Do ##class(Demo.Protocol).Fail("Known route kind required")
        If ('$Match(batch,"^[A-Za-z0-9-]{1,64}$"))||('$Match(receiptHash,"^[a-f0-9]{64}$")) Do ##class(Demo.Protocol).Fail("Bounded batch and independent receipt pin required")
        Set previous=$Namespace
        Try {
            Set $Namespace=$Select(kind="aggregation":"PIPELINE",1:"UTILIZATION")
            If kind="aggregation" {
                If '$Data(^ContestAggregation("batch",batch)) Do ##class(Demo.Protocol).Fail("Aggregation evidence missing")
                Set record={}.%FromJSON(^ContestAggregation("batch",batch)), current=##class(Contest.Aggregation.Runtime).Binding()
            } Else {
                If '$Data(^ContestUtilization("batch",batch)) Do ##class(Demo.Protocol).Fail("Utilization evidence missing")
                Set record={}.%FromJSON(^ContestUtilization("batch",batch)), current=##class(Contest.Utilization.Runtime).Binding()
            }
            If record.%Get("batch_id")'=batch Do ##class(Demo.Protocol).Fail("Requested batch identity mismatch")
            If kind="utilization" {
                Set downstream=##class(Contest.Utilization.Runtime).ReadReceiver(batch)
                If (downstream.payload.%ToJSON()'=record.bundle.%ToJSON())||(downstream.%Get("scope_hash")'=record.%Get("scope_hash"))||(downstream.%Get("received_at")'=record.receipt.%Get("received_at")) Do ##class(Demo.Protocol).Fail("Downstream SQL evidence changed")
            }
        } Catch ex { Set $Namespace=previous Throw ex }
        Set $Namespace=previous, dossier=##class(Contest.RouteGovernance).Read(record.%Get("approval_id"))
        Do ..Validate(kind,record,dossier,receiptHash)
        Do ..Messages(record,kind)
        Set value=..Project(kind,record,dossier), admission=##class(Contest.RouteGovernance).Check(dossier.id,current,dossier.digest)
    } Catch ex {
        Do ##class(Contest.KnowledgeService).Audit("route.evidence.read.failed",kind,ex.DisplayString())
        Throw ex
    }
    Quit {"evidence":(value),"current_admission":(admission)}
}
}
