Class Contest.Multi.Runtime
{
ClassMethod Read(id As %String) As %DynamicObject
{
    If ($Namespace'="DEMODISTRIBUTION")||('$Match(id,"^[A-Za-z0-9-]{1,48}$"))||('$Data(^ContestMulti("run",id))) Do ##class(Demo.Protocol).Fail("Known owned distribution run required")
    Quit {}.%FromJSON(^ContestMulti("run",id))
}

ClassMethod Save(record As %DynamicObject)
{
    If ($Namespace'="DEMODISTRIBUTION")||('$Match(record.id,"^[A-Za-z0-9-]{1,48}$")) Do ##class(Demo.Protocol).Fail("Owned distribution namespace required")
    Set ^ContestMulti("run",record.id)=record.%ToJSON()
    Set ^ContestMulti("order",record.%Get("created_at"),record.id)=1
}

ClassMethod Failed(id As %String, target As %String, error As %String)
{
    Set record=..Read(id)
    For i=0:1:record.branches.%Size()-1 {
        Set branch=record.branches.%Get(i)
        If branch.id=target {
            Set branch.state=$Select(branch.state="attempted":"uncertain",1:"failed"), branch.error=error
        }
    }
    Do ..Save(record)
}

ClassMethod Collect(id As %String)
{
    Set record=..Read(id)
    For i=0:1:record.branches.%Size()-1 {
        Set branch=record.branches.%Get(i)
        If branch.state'="acknowledged" Continue
        If branch.%IsDefined("evidence_hash") Continue
        Set host=$Select(branch.id="quality":"QualitySQL",branch.id="research":"ResearchREST",1:"ClinicHL7")
        Set rs=##class(%SQL.Statement).%ExecDirect(,"SELECT ID,SessionId FROM Ens.MessageHeader WHERE MessageBodyClassName='Contest.Multi.SendRequest' AND MessageBodyId=? AND SourceConfigName='Distribute' AND TargetConfigName=?",branch.%Get("message_id"),host)
        If rs.%SQLCODE<0 Do ##class(Demo.Protocol).Fail("Sidecar header query failed")
        If 'rs.%Next() Do ##class(Demo.Protocol).Fail("Actual outbound message edge missing")
        Do branch.%Set("header_id",rs.%Get("ID"),"string"), branch.%Set("session_id",rs.%Get("SessionId"),"string")
        If rs.%Next() Do ##class(Demo.Protocol).Fail("Ambiguous outbound message edge")
        Set message=##class(Contest.Multi.SendRequest).%OpenId(branch.%Get("message_id"))
        If '$IsObject(message) Do ##class(Demo.Protocol).Fail("Persisted outbound body missing")
        If (message.RunId'=id)||(message.Branch'=branch.id)||(##class(Demo.Protocol).Hash($ZConvert(message.Payload,"O","UTF8"))'=branch.%Get("payload_hash")) Do ##class(Demo.Protocol).Fail("Persisted outbound body changed")
        Set receipt={}.%FromJSON(..ReadReceiver(branch.id,message.DeliveryId))
        If receipt.%Get("payload_hash")'=branch.%Get("payload_hash") Do ##class(Demo.Protocol).Fail("Sidecar receiver readback differs from outbound body")
        Set facts={}.%FromJSON(..Inspect(branch.id,message.Payload)), profile=record.profiles.%Get(branch.id)
        If branch.id="quality" {
            If receipt.%GetTypeOf("column_inventory")'="array" Do ##class(Demo.Protocol).Fail("SQL receiver column readback inventory missing")
            Do facts.%Set("wire_paths",receipt.%Get("column_inventory"))
        }
        Do branch.%Set("facts",facts), branch.%Set("fields",facts.fields)
        Do branch.%Set("policy_mismatches",[].%FromJSON(..Mismatches(facts.%ToJSON(),profile.profile.%ToJSON())))
        Do branch.%Set("evidence_hash",##class(Contest.ExportEvidence).Digest(branch))
    }
    Set record.state=record.%Get("delivery_state")
    Do ..Save(record)
}

ClassMethod Source() As %String [ Language = python ]
{
    import sys, json
    sys.path.insert(0, "/contest")
    import multi_runtime
    return json.dumps(multi_runtime.fhir())
}

ClassMethod Seed() As %String [ Language = python ]
{
    import sys, json
    sys.path.insert(0, "/contest")
    import multi_runtime
    return json.dumps(multi_runtime.seed())
}

ClassMethod Transform(branch As %String, delivery As %String, source As %String, variant As %String) As %String [ Language = python ]
{
    import sys, json
    sys.path.insert(0, "/contest")
    import multi_runtime
    return multi_runtime.transform(branch, delivery, json.loads(source), variant)
}

ClassMethod Inspect(branch As %String, payload As %String) As %String [ Language = python ]
{
    import sys, json
    sys.path.insert(0, "/contest")
    import multi_runtime
    return json.dumps(multi_runtime.inspect_payload(branch, payload))
}

ClassMethod Mismatches(facts As %String, profile As %String) As %String [ Language = python ]
{
    import sys, json
    sys.path.insert(0, "/contest")
    import multi_runtime
    return json.dumps(multi_runtime.policy_mismatches(json.loads(facts), json.loads(profile)))
}

ClassMethod Send(branch As %String, delivery As %String, payload As %String) As %String [ Language = python ]
{
    import sys, json
    sys.path.insert(0, "/contest/multiorg/receiver")
    import transport
    protocol = {"quality": "sql", "research": "rest", "clinic": "hl7"}[branch]
    return json.dumps(transport.send(protocol, delivery, payload))
}

ClassMethod Ready() As %String [ Language = python ]
{
    import sys, json
    sys.path.insert(0, "/contest/multiorg/receiver")
    import transport
    sys.path.insert(0, "/contest")
    import multi_runtime
    items = transport.readiness()
    try:
        items.append(multi_runtime.source_readiness())
    except (OSError, ValueError, KeyError) as error:
        items.append({"name": "FHIR source", "ready": False, "detail": str(error)})
    return json.dumps(items)
}

ClassMethod ReadReceiver(branch As %String, delivery As %String) As %String [ Language = python ]
{
    import sys, json
    sys.path.insert(0, "/contest/multiorg/receiver")
    import transport
    protocol = {"quality": "sql", "research": "rest", "clinic": "hl7"}[branch]
    return json.dumps(transport.read(protocol, delivery))
}
}
