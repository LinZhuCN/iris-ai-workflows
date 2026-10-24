Class Contest.EventService
{
ClassMethod AllowedTransition(before As %String, after As %String) As %Boolean
{
    If (before="resolved") || (before="ignored") Quit after="open"
    If before="open" Quit (after="in_review") || (after="ignored")
    If before="in_review" Quit (after="needs_information") || (after="resolved") || (after="ignored")
    If before="needs_information" Quit (after="in_review") || (after="resolved") || (after="ignored")
    Quit 0
}

ClassMethod Create(observation As %String, category As %String, detector As %String, title As %String, detail As %String) As %String
{
    Set id="event-"_##class(Demo.Protocol).Hash(observation_"|"_category_"|"_detector)
    If '$Data(^ContestEvents("event",id)) {
        Set event={"id":(id),"observation_id":(observation),"category":(category),"detector":(detector),"title":(title),"detail":(detail),"state":"open","revision":1,"created":(##class(Demo.Protocol).Now()),"actions":[],"opinions":[]}
        Set ^ContestEvents("event",id)=event.%ToJSON()
        Set ^ContestEvents("order",$Increment(^ContestEvents("sequence")))=id
    }
    Quit id
}

ClassMethod Observe(body As %DynamicObject)
{
    Set id=body.%Get("observation_id")
    If $Data(^ContestEvents("observation",id)) Quit
    Set ^ContestEvents("observation",id)=body.%ToJSON()
    Set ^ContestEvents("counts","observed")=1+$Get(^ContestEvents("counts","observed"))
    If body.outcome="failed" Set eventId=..Create(id,"business_failure","destination","Synthetic destination failure","A real DEMO route completed with a failed local destination. This is not a privacy finding.")
    If body.outcome="held_for_review" Set eventId=..Create(id,"rule_hold","gate","Demo Gate held the message","No destination delivery was attempted; inspect the actual bundle recorded in the observation.")
    If body.schema=1 {
        Set ^ContestEvents("counts","legacy_without_facts")=1+$Get(^ContestEvents("counts","legacy_without_facts"))
        Quit
    }
    If body.scenario="analytics" Set ^ContestEvents("counts","eligible")=1+$Get(^ContestEvents("counts","eligible"))
    If 'body.%Get("review_selected") Quit
    Set ^ContestEvents("counts","selected_persisted")=1+$Get(^ContestEvents("counts","selected_persisted"))
    Set task={"id":(id),"observation_id":(id),"state":"blocked_budget","reason":"No model budget has been authorized for automatic reviews.","origin":"source_sample","attempts":0}
    Set ^ContestEvents("review",id)=task.%ToJSON()
    Set eventId=..Create(id,"coverage_gap","budget","Selected review awaits model authorization","The source persisted a selected sample, but no automatic model budget is enabled. This is not an AI privacy verdict.")
}

ClassMethod Drain()
{
    Lock +^ContestEvents("intake"):0
    If '$Test Quit
    Try {
        Set id="", count=0
        For {
            Set id=$Order(^ContestEvents("pending",id))
            Quit:((id="") || (count>=100))
            TStart
            Try {
                If $Data(^ContestMonitor("observation",id)) Do ..Observe({}.%FromJSON(^ContestMonitor("observation",id)))
                Kill ^ContestEvents("pending",id)
                TCommit
            } Catch ex { TRollback 1 Throw ex }
            Set count=count+1
        }
    } Catch ex {
        Lock -^ContestEvents("intake")
        Throw ex
    }
    Lock -^ContestEvents("intake")
}

ClassMethod Backfill()
{
    Set id=""
    For {
        Set id=$Order(^ContestMonitor("observation",id))
        Quit:id=""
        If '$Data(^ContestEvents("observation",id)) Set ^ContestEvents("pending",id)=1
    }
    Do ..Drain()
}

ClassMethod List() As %DynamicObject
{
    Set events=[], reviews=[], sequence="", count=0, counts={}
    For {
        Set sequence=$Order(^ContestEvents("order",sequence),-1)
        Quit:((sequence="") || (count>=100))
        Do events.%Push({}.%FromJSON(^ContestEvents("event",^ContestEvents("order",sequence))))
        Set count=count+1
    }
    Set id=""
    For {
        Set id=$Order(^ContestEvents("review",id))
        Quit:id=""
        Set review={}.%FromJSON(^ContestEvents("review",id))
        If (review.state="queued") || (review.state="running") {
            If review.boot'=$Get(^ContestAgents("boot")) {
                Set review.state="interrupted", review.error="Server restarted. This review was not automatically replayed."
            }
        }
        Do reviews.%Push(review)
    }
    For field="observed","eligible","selected_persisted","legacy_without_facts" Do counts.%Set(field,+$Get(^ContestEvents("counts",field)))
    Quit {"events":(events),"reviews":(reviews),"counts":(counts),"can_write":($System.Security.Check("ContestMonitorDeploy","U")),"user":($Username),"automatic_model_budget":0}
}

ClassMethod Detail(id As %String) As %DynamicObject
{
    If (id="") || '$Data(^ContestEvents("event",id)) Do ##class(Demo.Protocol).Fail("Event not found")
    Set event={}.%FromJSON(^ContestEvents("event",id))
    Set observation={}.%FromJSON(^ContestEvents("observation",event.%Get("observation_id")))
    Quit {"event":(event),"observation":(observation)}
}

ClassMethod Action(body As %DynamicObject) As %DynamicObject
{
    If (body.%Size()'=4) || (body.%GetTypeOf("id")'="string") || (body.%GetTypeOf("revision")'="number") || (body.%GetTypeOf("action")'="string") || (body.%GetTypeOf("text")'="string") || ($ZStrip(body.text,"<>W")="") || ($Length(body.text)>2000) Do ##class(Demo.Protocol).Fail("Exact event revision, action and a nonempty reason/opinion of at most 2000 characters are required")
    Lock +^ContestEvents("eventLock",body.id):2
    If '$Test Do ##class(Demo.Protocol).Fail("Event busy")
    Try {
        Set detail=..Detail(body.id), event=detail.event
        If event.revision'=body.revision Do ##class(Demo.Protocol).Fail("Event revision conflict; refresh before editing")
        Set entry={"id":($System.Util.CreateGUID()),"actor":($Username),"text":(body.text),"time":(##class(Demo.Protocol).Now())}
        If body.action="opinion" {
            Do entry.%Set("summary_state","not_requested"), event.opinions.%Push(entry)
        } Else {
            If '..AllowedTransition(event.state,body.action) Do ##class(Demo.Protocol).Fail("Event transition is not allowed")
            Do entry.%Set("before",event.state), entry.%Set("after",body.action), event.actions.%Push(entry)
            Set event.state=body.action
        }
        Set event.revision=event.revision+1, ^ContestEvents("event",body.id)=event.%ToJSON()
        Do ##class(Contest.KnowledgeService).Audit("event."_body.action,body.id,"Reason/opinion retained locally; not sent to a model")
    } Catch ex {
        Lock -^ContestEvents("eventLock",body.id)
        Throw ex
    }
    Lock -^ContestEvents("eventLock",body.id)
    Quit event
}

ClassMethod Investigate(body As %DynamicObject) As %DynamicObject
{
    If (body.%Size()'=4) || (body.%GetTypeOf("id")'="string") || (body.%GetTypeOf("revision")'="number") || (body.%GetTypeOf("agent_id")'="string") || (body.%GetTypeOf("acknowledge_cost")'="boolean") || 'body.%Get("acknowledge_cost") Do ##class(Demo.Protocol).Fail("Confirm a specific event revision, published Agent and up to four real model requests")
    Set detail=..Detail(body.id), observation=detail.observation
    If detail.event.revision'=body.revision Do ##class(Demo.Protocol).Fail("Event revision changed")
    If (observation.schema'=2) || (observation.scenario'="analytics") Do ##class(Demo.Protocol).Fail("Only synthetic analytics observations with source facts support this privacy template")
    Set config=##class(Contest.AgentService).Get(body.%Get("agent_id"))
    If config.status'="published" Do ##class(Demo.Protocol).Fail("Select a published Agent")
    Set id="investigation-"_$System.Util.CreateGUID()
    Set review={"id":(id),"event_id":(body.id),"observation_id":(observation.%Get("observation_id")),"config":(config),"config_hash":(config.%Get("config_hash")),"facts":(observation.facts),"state":"queued","boot":($Get(^ContestAgents("boot"))),"actor":($Username),"started":(##class(Demo.Protocol).Now()),"origin":"manual_investigation","max_model_requests":4}
    Set ^ContestEvents("review",id)=review.%ToJSON()
    Job ##class(Contest.EventService).Run(id)::5
    If '$Test {
        Set review.state="failed", review.error="Could not launch investigation worker", ^ContestEvents("review",id)=review.%ToJSON()
        Do ##class(Demo.Protocol).Fail("Could not launch investigation worker")
    }
    Do ##class(Contest.KnowledgeService).Audit("event.investigate",id,body.id)
    Quit review
}

ClassMethod Run(id As %String)
{
    Set review={}.%FromJSON(^ContestEvents("review",id))
    Try {
        If review.boot'=$Get(^ContestAgents("boot")) Do ##class(Demo.Protocol).Fail("Server boot changed; refusing automatic replay")
        Set config=##class(Contest.AgentService).Get(review.config.id)
        If (config.status'="published") || (config.%Get("config_hash")'=review.%Get("config_hash")) Do ##class(Demo.Protocol).Fail("Agent was disabled or changed before execution")
        Set review.state="running", ^ContestEvents("review",id)=review.%ToJSON()
        Set result=##class(Contest.AgentService).Evaluate(id,review.config,"observation",review.facts)
        Set review.state=result.state, review.analysis=result
        If result.state="completed" {
            Set assessment=result.result.assessment
            If assessment'="no_finding" {
                Set eventId=..Create(review.%Get("observation_id"),assessment,id,"AI Hub scoped "_assessment,result.result.reason)
                Do review.%Set("result_event",eventId)
            }
        } Else {
            Set eventId=..Create(review.%Get("observation_id"),"technical_failure",id,"AI Hub investigation failed","A technical or schema error is not a privacy finding.")
        }
        Do review.%Set("completed",##class(Demo.Protocol).Now())
        Set ^ContestEvents("review",id)=review.%ToJSON()
    } Catch ex {
        Set review.state="failed", review.error="Investigation failed; inspect protected audit", ^ContestEvents("review",id)=review.%ToJSON()
        Do ##class(Contest.KnowledgeService).Audit("event.investigate.failed",id,ex.DisplayString())
    }
}
}
