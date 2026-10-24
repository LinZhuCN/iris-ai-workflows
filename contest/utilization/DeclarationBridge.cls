Class Contest.Utilization.DeclarationBridge
{
ClassMethod Approval(id As %String, digest As %String, batch As %String, Output key As %String, hold As %Boolean = 0) As %DynamicObject
{
    Set previous=$Namespace, key="", locked=0
    Try {
        Set $Namespace="TRIAGE", run=##class(Contest.DeclarationExecution).Load(id)
        If hold {
            Set key=run.grant.record.%Get("declaration_id")
            Lock +^ContestDeclaration("lock",key):2
            If '$Test Do ##class(Demo.Protocol).Fail("Declaration changed or is busy at receiver admission")
            Set locked=1
        }
        Set $Namespace="UTILIZATION", binding=##class(Contest.Utilization.Runtime).Binding(), $Namespace="TRIAGE"
        Set dossier=##class(Contest.DeclarationExecution).Admit(id,digest,binding,batch)
    } Catch ex {
        If locked {
            Set $Namespace="TRIAGE"
            Lock -^ContestDeclaration("lock",key)
        }
        Set $Namespace=previous, key=""
        Throw ex
    }
    Set $Namespace=previous
    Quit dossier
}

ClassMethod Release(key As %String)
{
    If key="" Quit
    Set previous=$Namespace, $Namespace="TRIAGE"
    Lock -^ContestDeclaration("lock",key)
    Set $Namespace=previous
}

ClassMethod Verify(run As %DynamicObject, stored As %DynamicObject)
{
    Set receipt=stored.receipt, grant=run.grant, binding=grant.binding, p=grant.record.proposal
    If (receipt.synthetic'=1)||(receipt.outcome'="delivered")||(receipt.%Get("model_calls")'=0)||(receipt.%Get("receiver_readback_match")'=1)||(receipt.transport'="same-instance-BO-to-SQL")||(receipt.%Get("batch_id")'=grant.%Get("batch_id")) Do ##class(Demo.Protocol).Fail("Verified synthetic execution receipt required")
    For field="source","config" {
        If stored.%Get(field_"_hash")'=##class(Contest.Aggregation.Runtime).Digest(stored.%Get(field)) Do ##class(Demo.Protocol).Fail("Frozen declaration batch integrity mismatch: "_field)
    }
    If (stored.%Get("config_hash")'=binding.%Get("config_hash"))||(stored.%Get("output_hash")'=##class(Contest.Aggregation.Runtime).Digest(stored.bundle)) Do ##class(Demo.Protocol).Fail("Frozen execution configuration or output changed")
    Set expected=##class(Contest.Utilization.Runtime).Project(stored.source)
    If expected.%ToJSON()'=stored.bundle.%ToJSON() Do ##class(Demo.Protocol).Fail("Output no longer matches the frozen source projection")
    Set scope={"resources":(p.data.resources),"fields":(p.data.fields),"max_records":(p.data.%Get("max_records"))}
    Set inspection=##class(Contest.Aggregation.Runtime).Inspect(stored.bundle,{"core":{"declaration":{"scope":(scope)}}})
    If (inspection.%ToJSON()'=stored.inspection.%ToJSON())||(inspection.%ToJSON()'=receipt.inspection.%ToJSON()) Do ##class(Demo.Protocol).Fail("Execution scope inspection changed")
    For field="source_hash","output_hash","config_hash","scope_hash","approval_id","session_id","message_id" {
        If stored.%Get(field)'=receipt.%Get(field) Do ##class(Demo.Protocol).Fail("Execution receipt provenance mismatch: "_field)
    }
    Set link=receipt.%Get("declaration_binding")
    If (stored.%Get("declaration_binding").%ToJSON()'=link.%ToJSON())||(link.%Get("execution_id")'=run.id)||(link.%Get("execution_hash")'=run.%Get("grant_hash"))||(link.%Get("record_id")'=grant.record.id)||(link.%Get("declaration_digest")'=grant.record.digest)||(link.revision'=grant.record.revision)||(link.%Get("decision_hash")'=grant.record.decision.%Get("record_hash"))||(link.%Get("task_hash")'=grant.record.review.task.%Get("record_hash")) Do ##class(Demo.Protocol).Fail("Execution receipt declaration/review/decision binding changed")
    If (stored.approval.%ToJSON()'=grant.record.decision.%ToJSON())||(stored.%Get("prepared_at")<grant.%Get("created_at"))||(stored.%Get("prepared_at")<p.validity.from)||(stored.%Get("prepared_at")<grant.record.decision.%Get("decided_at"))||(receipt.%Get("received_at")<stored.%Get("prepared_at"))||(receipt.%Get("received_at")>=p.validity.until) Do ##class(Demo.Protocol).Fail("Execution approval snapshot or historical validity changed")
    Set source=##class(Contest.Aggregation.Request).%OpenId(receipt.%Get("message_id")), send=##class(Contest.Aggregation.SendRequest).%OpenId(receipt.%Get("receiver_message_id"))
    If ('$IsObject(source))||('$IsObject(send)) Do ##class(Demo.Protocol).Fail("Persisted execution messages missing")
    For field="BatchId","ApprovalId","ScopeHash" {
        Set value=stored.%Get($Select(field="BatchId":"batch_id",field="ApprovalId":"approval_id",1:"scope_hash"))
        If ($Property(source,field)'=value)||($Property(send,field)'=value) Do ##class(Demo.Protocol).Fail("Execution message grant differs from receipt")
    }
    If send.Bundle'=stored.bundle.%ToJSON() Do ##class(Demo.Protocol).Fail("Execution sender payload changed")
    For phase="source","receiver" {
        Set class=$Select(phase="source":"Contest.Aggregation.Request",1:"Contest.Aggregation.SendRequest"), body=$Select(phase="source":source.%Id(),1:send.%Id()), from=$Select(phase="source":"FHIRSource",1:"UtilizationProcess"), to=$Select(phase="source":"UtilizationProcess",1:"AnalysisReceiver")
        Set rs=##class(%SQL.Statement).%ExecDirect(,"SELECT COUNT(*) AS N FROM Ens.MessageHeader WHERE MessageBodyClassName=? AND MessageBodyId=? AND SessionId=? AND SourceConfigName=? AND TargetConfigName=?",class,body,receipt.%Get("session_id"),from,to)
        Do ##class(Contest.Aggregation.Data).Check(rs)
        Set next=rs.%Next()
        If rs.%Get("N")'=1 Do ##class(Demo.Protocol).Fail("Execution message/session linkage mismatch")
    }
}
}
