Class Contest.ProductionBusinessEvidence
{
ClassMethod Supports(value As %DynamicObject) As %Boolean
{
    Quit (value.namespace="M5OBSERVATION")&&(value.production="Contest.M5.Production")&&(value.header.%Get("body_class")="Contest.M5.Request")
}

ClassMethod Policy() As %DynamicObject
{
    Quit {"version":"synthetic-quality-intake-v1","synthetic":true,"recipients":["ReceiverA","ReceiverB","ReceiverD"],"relationship":"Established fictional same-covered-entity internal quality intake; not marketing, external disclosure or a de-identification release.","purpose":"Internal quality intake using stable synthetic patient IDs and year-only birth dates. No full dates, contact details or unknown fields are permitted by this local minimization rule.","allowed_fields":["patient_id","birthDate","status"],"scope":"Observed local intake versus this explicit synthetic policy only; not legal certification, later actual use, retention/disposal or comprehensive safeguards."}
}

ClassMethod Read(value As %DynamicObject) As %DynamicObject
{
    If ($Namespace'="TRIAGE")||('$System.Security.Check("ContestMonitorDeploy","U")) Do ##class(Demo.Protocol).Fail("Protected local evidence collector required")
    If '..Supports(value) Do ##class(Demo.Protocol).Fail("No registered business evidence adapter")
    Set stored=##class(Contest.ProductionEvidence).Read(value.%Get("production_id"),value.header.%Get("header_id"))
    If (stored.%Get("record_hash")'=value.%Get("record_hash"))||(stored.%ToJSON()'=value.%ToJSON()) Do ##class(Demo.Protocol).Fail("Business evidence requires the exact immutable observation")
    Set pid=value.%Get("production_id"), current=##class(Contest.ProductionMonitor).Snapshot(value.namespace)
    If (current.id'=pid)||('current.running)||(current.%Get("config_hash")'=value.%Get("observed_config_hash")) Do ##class(Demo.Protocol).Fail("Business adapter active configuration changed")
    If '$Data(^ContestProductionEvidence("allow",pid)) Do ##class(Demo.Protocol).Fail("Fresh local inspection consent required")
    Set grant={}.%FromJSON(^ContestProductionEvidence("allow",pid))
    If ('grant.enabled)||(grant.%Get("config_hash")'=current.%Get("config_hash")) Do ##class(Demo.Protocol).Fail("Local inspection consent revoked or changed")
    Set previous=$Namespace
    Try {
        Set $Namespace=value.namespace
        Set body=##class(Contest.M5.Request).%OpenId(value.header.%Get("body_id"))
        If '$IsObject(body) Do ##class(Demo.Protocol).Fail("Persisted business request missing")
        Set digest=##class(Demo.Protocol).Hash($ZConvert(body.PayloadJson,"O","UTF8"))
        If digest'=value.capture.%Get("body_digest") Do ##class(Demo.Protocol).Fail("Business request changed after capture")
        Set rs=##class(%SQL.Statement).%ExecDirect(,"SELECT TargetConfigName FROM Ens.MessageHeader WHERE MessageBodyClassName=? AND MessageBodyId=? AND SessionId=? AND SourceConfigName LIKE 'Process%' AND TargetConfigName LIKE 'Receiver%'","Contest.M5.Request",body.%Id(),value.header.%Get("session_id")), target="", n=0
        If rs.%SQLCODE<0 Do ##class(Demo.Protocol).Fail("Business header query failed")
        While rs.%Next() { Set target=rs.%Get("TargetConfigName"), n=n+1 }
        If (rs.%SQLCODE<0)||(n'=1) Do ##class(Demo.Protocol).Fail("Exactly one actual receiver edge required")
        Set rs=##class(%SQL.Statement).%ExecDirect(,"SELECT MessageID,Receiver,PayloadHash,ReceivedAt FROM SQLUser.M5Receipt WHERE BatchID=?",body.BatchId)
        If rs.%SQLCODE<0 Do ##class(Demo.Protocol).Fail("Receiver readback query failed")
        If 'rs.%Next() Do ##class(Demo.Protocol).Fail("Receiver readback not available; no invented acceptance")
        If (rs.%Get("MessageID")'=body.%Id())||(rs.%Get("Receiver")'=target)||(rs.%Get("PayloadHash")'=digest) Do ##class(Demo.Protocol).Fail("Receiver readback differs from persisted message/session")
        Set receipt={"batch_id":(body.BatchId),"message_id":(body.%Id()),"session_id":(value.header.%Get("session_id")),"receiver":(target),"payload_hash":(digest),"received_at":(rs.%Get("ReceivedAt")),"readback_match":true}
    } Catch ex { Set $Namespace=previous Throw ex }
    Set $Namespace=previous
    Set confirmed=##class(Contest.ProductionMonitor).Snapshot(value.namespace)
    If (confirmed.id'=pid)||(confirmed.%Get("config_hash")'=current.%Get("config_hash"))||('confirmed.running) Do ##class(Demo.Protocol).Fail("Production changed during business readback")
    Set policy=..Policy(), known=0
    For i=0:1:policy.recipients.%Size()-1 If policy.recipients.%Get(i)=target Set known=1
    Set evidence={"adapter":"synthetic-quality-intake-v1","production_id":(pid),"observation_hash":(value.%Get("record_hash")),"config_hash":(current.%Get("config_hash")),"receipt":(receipt),"policy":(policy),"recipient_established":(known=1),"scope":"Synthetic local SQL intake and configured internal relationship only. No assertion of later use or actual legal compliance."}
    Do evidence.%Set("evidence_hash",##class(Contest.ExportEvidence).Digest(evidence))
    Quit evidence
}

ClassMethod Validate(evidence As %DynamicObject, value As %DynamicObject)
{
    Set copy={}.%FromJSON(evidence.%ToJSON())
    Do copy.%Remove("evidence_hash")
    If (evidence.%Get("evidence_hash")'=##class(Contest.ExportEvidence).Digest(copy))||(evidence.%Get("production_id")'=value.%Get("production_id"))||(evidence.%Get("observation_hash")'=value.%Get("record_hash"))||(evidence.%Get("config_hash")'=value.%Get("observed_config_hash")) Do ##class(Demo.Protocol).Fail("Frozen business evidence integrity/binding mismatch")
    If (evidence.receipt.%Get("payload_hash")'=value.capture.%Get("body_digest"))||(evidence.receipt.%Get("message_id")'=value.header.%Get("body_id"))||(evidence.receipt.%Get("session_id")'=value.header.%Get("session_id"))||('evidence.receipt.%Get("readback_match")) Do ##class(Demo.Protocol).Fail("Frozen business receipt differs from observation")
}
}
