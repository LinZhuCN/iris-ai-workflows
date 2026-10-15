Class Contest.Process Extends Ens.BusinessProcess
{
Method OnRequest(request As Contest.Request, Output response As Contest.Reply) As %Status
{
    Set sc = $$$OK, record = "", locked = 0, caseId = ""
    Set started = $ZTIMESTAMP
    Try {
        If (request.ExternalId = "") || ($Length(request.ExternalId) > 128) Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError,"ExternalId must contain 1-128 characters"))
        Lock +^Contest.Lock(request.ExternalId):5
        If '$Test Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError,"Case is busy"))
        Set locked = 1
        Set record = ##class(Contest.Case).OpenByExternalId(request.ExternalId)
        If $IsObject(record) {
            If record.Payload '= request.Payload Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError,"ExternalId conflicts with existing payload"))
            If (record.Outcome '= "delivered") && (record.Outcome '= "quarantined") && (record.Outcome '= "pending_review") Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError,"Existing case is failed or incomplete; automatic replay is disabled"))
            Set response = ##class(Contest.Reply).%New()
            Set response.CaseId = record.%Id(), response.Outcome = record.Outcome
            Set sc = ##class(Contest.Event).Add(record.%Id(),"duplicate","Returned existing outcome without replay") $$$ThrowOnError(sc)
        } Else {
            Set record = ##class(Contest.Case).%New()
            Set record.ExternalId = request.ExternalId, record.Payload = request.Payload
            Set record.RequestId = request.%Id(), record.SessionId = ..%SessionId
            Set record.Outcome = "received", record.Policy = "not_evaluated"
            Set record.ProviderMode = $System.Util.GetEnviron("TRIAGE_MODE"), record.Model = $System.Util.GetEnviron("TRIAGE_MODEL")
            Set sc = record.%Save() $$$ThrowOnError(sc)
            Set sc = ##class(Contest.Event).Add(record.%Id(),"received") $$$ThrowOnError(sc)
            Set facts = ##class(Contest.Facts).Inspect(request.Payload)
            Set record.Facts = facts.%ToJSON()
            Set sc = record.%Save() $$$ThrowOnError(sc)
            Set ^Contest.Context($Job) = record.%Id()
            Set caseId = record.%Id()
            Set settings = ##class(%DynamicObject).%New()
            If record.ProviderMode = "real" {
                Set key = $System.Util.GetEnviron("TRIAGE_API_KEY")
            } Else {
                Open "/run/secrets/provider-key":"R":5
                If '$Test Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError,"Cannot read provider key file"))
                Use "/run/secrets/provider-key" Read key Close "/run/secrets/provider-key"
            }
            If key = "" Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError,"Provider key file is empty"))
            Do settings.%Set("api_key",key)
            Do settings.%Set("base_url",$System.Util.GetEnviron("TRIAGE_PROVIDER_URL"))
            Set provider = ##class(%AI.Provider).Create("openai",settings)
            Kill key
            Set agent = ##class(%AI.Agent).%New(provider)
            Set agent.Model = record.Model
            Set agent.SystemPrompt = "Call GetTriageFacts for the supplied case_id before deciding. Only use these facts. Missing required fields should be quarantined; unknown codes need human_review; otherwise deliver. Return only a JSON object with decision (deliver, quarantine, human_review) and a nonempty reason. Do not request other cases."
            Set sc = agent.UseToolSet("Contest.ToolSet") $$$ThrowOnError(sc)
            Set sc = agent.%Init() $$$ThrowOnError(sc)
            Set session = agent.CreateSession()
            Set sc = session.%Save() $$$ThrowOnError(sc)
            Set record.AgentSession = session.%Id()
            Set sc = record.%Save() $$$ThrowOnError(sc)
            Set prompt = ##class(%DynamicObject).%New()
            Do prompt.%Set("case_id",caseId)
            Set result = agent.Chat(session,prompt.%ToJSON())
            If $IsObject(result.Usage) Set record.Usage = result.Usage.%ToJSON()
            Set content = result.Content
            If '$Get(^Contest.Context($Job,"factsRead")) Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError,"Agent did not read the bound case facts"))
            Set decision = ##class(%DynamicObject).%FromJSON(content)
            If 'decision.%IsA("%DynamicObject") Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError,"Agent must return a JSON object"))
            If (decision.%GetTypeOf("decision") '= "string") || (decision.%GetTypeOf("reason") '= "string") Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError,"Agent decision and reason must be strings"))
            Set record.Decision = decision.%Get("decision"), record.Reason = decision.%Get("reason")
            Set record.Policy = "denied"
            Set sc = record.%Save() $$$ThrowOnError(sc)
            Set sc = ##class(Contest.Event).Add(caseId,"agent_decision",content) $$$ThrowOnError(sc)
            If (record.Decision '= "deliver") && (record.Decision '= "quarantine") && (record.Decision '= "human_review") Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError,"Policy rejected unknown action"))
            If ($ZStrip(record.Reason,"<>W") = "") || ($Length(record.Reason) > 2000) Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError,"Policy requires a nonempty reason of at most 2000 characters"))
            If (record.Decision = "deliver") && ((facts.%Get("has_required_fields") = 0) || (facts.%Get("known_code") = 0)) Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError,"Policy forbids delivery of incomplete or unknown-code messages"))
            Set record.Policy = "allowed"
            Set sc = record.%Save() $$$ThrowOnError(sc)
            Set sc = ##class(Contest.Event).Add(caseId,"policy","allowed") $$$ThrowOnError(sc)
            Set dispatch = ##class(Contest.Reply).%New()
            Set dispatch.CaseId = caseId
            Set record = ""
            Set sc = ..SendRequestSync("TriageSink",dispatch,.response,30) $$$ThrowOnError(sc)
            Set record = ##class(Contest.Case).%OpenId(caseId)
            Set record.ElapsedMs = (($Piece($ZTIMESTAMP,",",1)-$Piece(started,",",1))*86400+$Piece($ZTIMESTAMP,",",2)-$Piece(started,",",2))*1000
            Set sc = record.%Save() $$$ThrowOnError(sc)
        }
    } Catch ex {
        Set sc = ex.AsStatus()
        If ('$IsObject(record)) && (caseId '= "") Set record = ##class(Contest.Case).%OpenId(caseId)
        If $IsObject(record) {
            If (record.%Id() '= "") && (record.Outcome = "received") {
                Set record.Outcome = "failed", record.Error = $SYSTEM.Status.GetErrorText(sc)
                Set auditSC = record.%Save()
                If $$$ISERR(auditSC) Set sc = $SYSTEM.Status.AppendStatus(sc,auditSC)
                Set auditSC = ##class(Contest.Event).Add(record.%Id(),"failed",record.Error)
                If $$$ISERR(auditSC) Set sc = $SYSTEM.Status.AppendStatus(sc,auditSC)
            }
        }
        $$$LOGERROR($SYSTEM.Status.GetErrorText(sc))
    }
    Kill ^Contest.Context($Job)
    If locked Lock -^Contest.Lock(request.ExternalId)
    Quit sc
}
}
