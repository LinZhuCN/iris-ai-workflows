Class Contest.RouteEvidenceTests Extends %UnitTest.TestProduction
{
Parameter PRODUCTION = "Contest.Production";
Method TestControl() As %Status { Quit $$$OK }

Method TestIndependentReceiptPin()
{
    Set receipt={"schema":1,"outcome":"delivered","batch_id":"unit"}, pin=##class(Contest.ExportEvidence).Digest(receipt)
    Do receipt.%Set("receipt_hash",pin)
    Do ##class(Contest.RouteEvidence).Receipt(receipt,pin)
    Do $$$AssertEquals(receipt.%Get("receipt_hash"),pin)
    For variant="content","pin","rehashed" {
        Set changed={}.%FromJSON(receipt.%ToJSON()), expected=pin, rejected=0
        If variant="pin" Set expected=$Translate($Justify("",64)," ","0")
        If variant'="pin" Set changed.outcome="modified"
        If variant="rehashed" {
            Do changed.%Remove("receipt_hash")
            Do changed.%Set("receipt_hash",##class(Contest.ExportEvidence).Digest(changed))
        }
        Try { Do ##class(Contest.RouteEvidence).Receipt(changed,expected) } Catch ex { Set rejected=(ex.DisplayString()["ERROR #5001:") }
        Do $$$AssertTrue(rejected,variant)
    }
}

Method TestReadRequiresExplicitRouteBatchAndPin()
{
    For variant="route","batch","pin" {
        Set kind="utilization", batch="unit", pin=$Translate($Justify("",64)," ","a"), rejected=0
        If variant="route" Set kind="USER"
        If variant="batch" Set batch="../bad"
        If variant="pin" Set pin=""
        Try { Set value=##class(Contest.RouteEvidence).Read(kind,batch,pin) } Catch ex { Set rejected=(ex.DisplayString()'["CLASS DOES NOT EXIST") }
        Do $$$AssertTrue(rejected,variant)
    }
}
    Method Fixture(kind As %String) As %DynamicObject
    {
        Set batch="", record=""
        If kind="aggregation" {
            For {
                Set batch=$Order(^|"PIPELINE"|ContestAggregation("batch",batch))
                If batch="" Quit
                Set candidate={}.%FromJSON(^|"PIPELINE"|ContestAggregation("batch",batch))
                If (candidate.state="delivered")&&($IsObject(candidate.config)) { Set record=candidate Quit }
            }
        } Else {
            For {
                Set batch=$Order(^|"UTILIZATION"|ContestUtilization("batch",batch))
                If batch="" Quit
                Set candidate={}.%FromJSON(^|"UTILIZATION"|ContestUtilization("batch",batch))
                If (candidate.state="delivered")&&($IsObject(candidate.config)) { Set record=candidate Quit }
            }
        }
        If '$IsObject(record) Do ##class(Demo.Protocol).Fail("Authorized durable evidence tests require an actual delivered route fixture")
        Quit record
    }

    Method Store(kind As %String, record As %DynamicObject)
    {
        If kind="aggregation" {
            Set ^|"PIPELINE"|ContestAggregation("batch",record.%Get("batch_id"))=record.%ToJSON()
        } Else {
            Set ^|"UTILIZATION"|ContestUtilization("batch",record.%Get("batch_id"))=record.%ToJSON()
        }
    }

    Method TestDurableBothRoutesAndMinimizedFacts()
    {
        If '$System.Security.Check("ContestMonitorDeploy","U") Quit
        For kind="aggregation","utilization" {
            Set record=..Fixture(kind), value=##class(Contest.RouteEvidence).Read(kind,record.%Get("batch_id"),record.receipt.%Get("receipt_hash")), evidence=value.evidence
            Do $$$AssertEquals(evidence.%Get("route_kind"),kind)
            Do $$$AssertEquals(evidence.packet.stage,"after_send")
            Do $$$AssertEquals(evidence.packet.facts.%Get(0).verification,"unverified")
            Do $$$AssertEquals(evidence.packet.facts.%Get(2).verification,"verified")
            Do $$$AssertEquals(evidence.observed.%Get("configured_recipient"),record.config.recipient)
            Do $$$AssertEquals(evidence.approved.%Get("declared_context").recipient,evidence.declaration.recipient)
            Do $$$AssertEquals(evidence.observed.%Get("runtime_binding").%Get("config_hash"),record.%Get("config_hash"))
            Do $$$AssertEquals(evidence.%Get("model_calls"),0)
            Do $$$AssertEquals(evidence.%Get("fact_evidence").%Size(),evidence.packet.facts.%Size())
            Set counts=evidence.observed.%Get("identifier_counts")
            Do $$$AssertEquals(counts.%Get("patient_identifier_values"),$Select(kind="aggregation":2,1:0))
            Do $$$AssertEquals(counts.%Get("full_birth_dates"),$Select(kind="aggregation":2,1:0))
            Do $$$AssertEquals(counts.%Get("year_only_birth_dates"),$Select(kind="utilization":2,1:0))
            Set text=evidence.%ToJSON()
            For forbidden="SYNTHETIC-MRN-A","SYNTHETIC-MRN-B","SYNTHETIC-A","SYNTHETIC-B","1980-01-02","1990-03-04","agg-p1","agg-e1" {
                Do $$$AssertTrue(text'[forbidden,forbidden)
            }
            Do $$$AssertTrue('evidence.%IsDefined("source"))
            Do $$$AssertTrue('evidence.%IsDefined("bundle"))
            Do ##class(Contest.RiskReview).ValidatePacket(evidence.packet)
            Set again=##class(Contest.RouteEvidence).Read(kind,record.%Get("batch_id"),record.receipt.%Get("receipt_hash"))
            Do $$$AssertEquals(again.evidence.%ToJSON(),evidence.%ToJSON())
        }
    }

    Method TestDurableMutationsCannotBecomeVerifiedFacts()
    {
        If '$System.Security.Check("ContestMonitorDeploy","U") Quit
        TStart
        Try {
            For kind="aggregation","utilization" {
                Set original=..Fixture(kind), batch=original.%Get("batch_id"), pin=original.receipt.%Get("receipt_hash")
                For variant="source","config","output","inspection","approval","scope","message","readback","receipt","rehashed-output" {
                    Set record={}.%FromJSON(original.%ToJSON())
                    If variant="source" Do record.source.%Set($Select(kind="aggregation":"patients",1:0),[])
                    If variant="config" Set record.config.recipient="different"
                    If variant="output" Set record.bundle.entry.%Get(0).resource.birthDate="1970"
                    If variant="inspection" Set record.inspection.%Get("resource_counts").Patient=0
                    If variant="approval" Do record.approval.%Set("approved_by","different")
                    If variant="scope" Do record.%Set("scope_hash","different")
                    If variant="message" Do record.%Set($Select(kind="aggregation":"request_id",1:"message_id"),"999999999")
                    If variant="readback" {
                        If kind="aggregation" {
                            Set record.%Get("readback_resources").%Get(0).birthDate="1970-01-01"
                        } Else {
                            Do record.%Get("source_pins").%Get(0).%Set("version","999")
                        }
                    }
                    If variant="receipt" Set record.receipt.%Get("inspection").%Get("resource_counts").Patient=0
                    If variant="rehashed-output" {
                        Set record.bundle.entry.%Get(0).resource.birthDate="1970"
                        Do record.%Set("output_hash",##class(Contest.ExportEvidence).Digest(record.bundle))
                        Do record.receipt.%Set("output_hash",record.%Get("output_hash")), record.receipt.%Remove("receipt_hash")
                        Do record.receipt.%Set("receipt_hash",##class(Contest.ExportEvidence).Digest(record.receipt))
                    }
                    Do ..Store(kind,record)
                    Set rejected=0
                    Try { Set ignored=##class(Contest.RouteEvidence).Read(kind,batch,pin) } Catch ex { Set rejected=(ex.DisplayString()["ERROR #5001:") }
                    Do $$$AssertTrue(rejected,kind_":"_variant)
                    Do $$$AssertEquals($Namespace,"TRIAGE")
                    Do ..Store(kind,original)
                }
            }
        } Catch ex { TRollback 1 Throw ex }
        TRollback 1
    }

    Method TestHistoricalEvidenceIsNotLiveConfigAdmission()
    {
        If '$System.Security.Check("ContestMonitorDeploy","U") Quit
        Set record=..Fixture("utilization"), dossier=##class(Contest.RouteGovernance).Read(record.%Get("approval_id"))
        Set changed={}.%FromJSON(dossier.core.binding.%ToJSON())
        Do changed.%Set("config_hash",$Translate($Justify("",64)," ","0"))
        Set status=##class(Contest.RouteGovernance).Check(dossier.id,changed,dossier.digest)
        Do $$$AssertEquals(status.state,"binding_mismatch")
        Do ##class(Contest.RouteEvidence).Validate("utilization",record,dossier,record.receipt.%Get("receipt_hash"))
        Do $$$AssertTrue(1,"Historical validation is independent of admission for a changed current config")
    }

    Method TestDurableSQLAndMessageHeaderTampering()
    {
        If '$System.Security.Check("ContestMonitorDeploy","U") Quit
        Set record=..Fixture("utilization"), batch=record.%Get("batch_id"), pin=record.receipt.%Get("receipt_hash"), previous=$Namespace
        For variant="payload","scope","header" {
            TStart
            Try {
                Set $Namespace="UTILIZATION"
                If variant="payload" {
                    Set payload={}.%FromJSON(record.bundle.%ToJSON()), payload.entry.%Get(0).resource.birthDate="1970"
                    Set result=##class(%SQL.Statement).%ExecDirect(,"UPDATE SQLUser.UtilizationReceipt SET Payload=?,OutputHash=? WHERE BatchID=?",payload.%ToJSON(),##class(Contest.Aggregation.Runtime).Digest(payload),batch)
                } ElseIf variant="scope" {
                    Set result=##class(%SQL.Statement).%ExecDirect(,"UPDATE SQLUser.UtilizationReceipt SET ScopeHash=? WHERE BatchID=?","different",batch)
                } Else {
                    Set result=##class(%SQL.Statement).%ExecDirect(,"UPDATE Ens.MessageHeader SET SessionId=? WHERE MessageBodyClassName=? AND MessageBodyId=?",999999999,"Contest.Aggregation.SendRequest",record.receipt.%Get("receiver_message_id"))
                }
                Do ##class(Contest.Aggregation.Data).Check(result)
                Do $$$AssertEquals(result.%ROWCOUNT,1)
                Set $Namespace=previous, rejected=0
                Try { Set value=##class(Contest.RouteEvidence).Read("utilization",batch,pin) } Catch ex { Set rejected=(ex.DisplayString()["ERROR #5001:") }
                Do $$$AssertTrue(rejected,variant)
                Do $$$AssertEquals($Namespace,"TRIAGE")
            } Catch ex { TRollback 1 Set $Namespace=previous Throw ex }
            TRollback 1
        }
        Set value=##class(Contest.RouteEvidence).Read("utilization",batch,pin)
        Do $$$AssertEquals(value.evidence.%Get("batch_id"),batch)
    }

    Method TestHistoricalValidityCannotBeInvented()
    {
        If '$System.Security.Check("ContestMonitorDeploy","U") Quit
        Set record=..Fixture("utilization"), original=##class(Contest.RouteGovernance).Read(record.%Get("approval_id"))
        For variant="too_early","too_late","approval_after_delivery" {
            Set dossier={}.%FromJSON(original.%ToJSON()), rejected=0, changed={}.%FromJSON(record.%ToJSON())
            If variant="too_early" Do dossier.core.%Set("valid_from",record.receipt.%Get("received_at")+1)
            If variant="too_late" Do dossier.core.%Set("valid_until",record.receipt.%Get("received_at"))
            If variant="approval_after_delivery" {
                Do dossier.approval.%Set("approved_at",record.receipt.%Get("received_at")+1)
                Set changed.approval=dossier.approval
            }
            Try { Do ##class(Contest.RouteEvidence).Validate("utilization",changed,dossier,record.receipt.%Get("receipt_hash")) } Catch ex { Set rejected=(ex.DisplayString()["ERROR #5001:") }
            Do $$$AssertTrue(rejected,variant)
        }
    }

    Method TestLaterSQLSourceChangesDoNotRewriteHistory()
    {
        If '$System.Security.Check("ContestMonitorDeploy","U") Quit
        Set record=..Fixture("aggregation"), batch=record.%Get("batch_id"), pin=record.receipt.%Get("receipt_hash")
        Set before=##class(Contest.RouteEvidence).Read("aggregation",batch,pin), previous=$Namespace
        TStart
        Try {
            Set $Namespace="PIPELINE"
            Set result=##class(%SQL.Statement).%ExecDirect(,"UPDATE SQLUser.AggPatient SET FamilyName=? WHERE ID=?","SYNTHETIC-LATER-VALUE","agg-p1")
            Do ##class(Contest.Aggregation.Data).Check(result)
            Do $$$AssertEquals(result.%ROWCOUNT,1)
            Set $Namespace=previous, after=##class(Contest.RouteEvidence).Read("aggregation",batch,pin)
            Do $$$AssertEquals(after.evidence.%ToJSON(),before.evidence.%ToJSON())
        } Catch ex { TRollback 1 Set $Namespace=previous Throw ex }
        TRollback 1
    }
    }
