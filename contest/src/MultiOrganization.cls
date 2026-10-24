Class Contest.MultiOrganization
{
ClassMethod Status() As %DynamicObject
{
    Do ##class(Contest.OrganizationCatalog).Access()
    Set ready=[], runs=[], ns=$Namespace
    Try {
        If '##class(%SYS.Namespace).Exists("DEMODISTRIBUTION") Do ##class(Demo.Protocol).Fail("Distribution environment not installed")
        Set $Namespace="DEMODISTRIBUTION", ready=[].%FromJSON(##class(Contest.Multi.Runtime).Ready()), id=""
        Set running=##class(Ens.Director).IsProductionRunning(.name)
        Set item={"name":"Distribution Production","ready":false,"detail":"DEMODISTRIBUTION / Contest.Multi.Production"}
        Do item.%Set("ready",(running=1)&&(name="Contest.Multi.Production"),"boolean"), ready.%Push(item)
        Set at=""
        For {
            Set at=$Order(^ContestMulti("order",at),-1) Quit:at=""
            Set id=""
            For {
                Set id=$Order(^ContestMulti("order",at,id),-1) Quit:id=""
                Do runs.%Push(##class(Contest.Multi.Runtime).Read(id))
                If runs.%Size()>=20 Quit
            }
            If runs.%Size()>=20 Quit
        }
        Set $Namespace=ns
    } Catch ex {
        Set $Namespace=ns
        Do ready.%Push({"name":"Distribution setup","ready":false,"detail":(ex.DisplayString())})
    }
    For i=0:1:runs.%Size()-1 Do runs.%Set(i,..Read(runs.%Get(i).id))
    Set all=1
    For i=0:1:ready.%Size()-1 If 'ready.%Get(i).ready Set all=0
    For id="hospital","quality","research","clinic" {
        Try { Set profile=##class(Contest.OrganizationCatalog).Read(id) }
        Catch ex { Set all=0 Do ready.%Push({"name":("Profile "_id),"ready":false,"detail":(ex.DisplayString())}) }
    }
    Set result={"ready":false,"readiness":(ready),"runs":(runs),"can_manage":false,"model_request_limit":6}
    Do result.%Set("ready",all=1,"boolean"), result.%Set("can_manage",$System.Security.Check("ContestMonitorDeploy","U")=1,"boolean")
    Quit result
}

ClassMethod Read(id As %String) As %DynamicObject
{
    Do ##class(Contest.OrganizationCatalog).Access()
    Set ns=$Namespace, boot=$Get(^ContestAgents("boot"))
    Try {
        Set $Namespace="DEMODISTRIBUTION", record=##class(Contest.Multi.Runtime).Read(id), changed=0
        If (record.%Get("boot")'=boot)&&((record.state="queued")||(record.state="reading_fhir")||(record.state="sending")||(record.state="collecting_evidence")) {
            Set record.state="interrupted", record.error="Server restarted during delivery. Reconcile receiver receipts; no automatic resend.", changed=1
        }
        If (record.%Get("audit_state")="running")&&(record.%Get("audit_authorization").%Get("boot")'=boot) {
            Do record.%Set("audit_state","interrupted"), record.%Set("audit_error","Server restarted during AI review. Original attempts retained; no automatic paid retry.")
            Set changed=1
        }
        If changed Do ##class(Contest.Multi.Runtime).Save(record)
    }
    Catch ex { Set $Namespace=ns Throw ex }
    Set $Namespace=ns
    Quit record
}

ClassMethod Seed(body As %DynamicObject) As %DynamicObject
{
    Do ##class(Contest.OrganizationCatalog).Access(1), ##class(Contest.RouteGovernance).Shape(body,"confirmed")
    If (body.%GetTypeOf("confirmed")'="boolean")||('body.confirmed) Do ##class(Demo.Protocol).Fail("Confirm loading synthetic FHIR data")
    Set ns=$Namespace
    Try { Set $Namespace="DEMODISTRIBUTION", result={}.%FromJSON(##class(Contest.Multi.Runtime).Seed()) }
    Catch ex { Set $Namespace=ns Throw ex }
    Set $Namespace=ns
    Do ##class(Contest.KnowledgeService).Audit("distribution.seed","synthetic","FHIR seed only; no sends or model calls")
    Quit result
}

ClassMethod Profiles() As %DynamicObject
{
    Set profiles={}
    For id="hospital","quality","research","clinic" Do profiles.%Set(id,##class(Contest.OrganizationCatalog).Read(id))
    Quit profiles
}

ClassMethod Start(body As %DynamicObject) As %DynamicObject
{
    Do ##class(Contest.OrganizationCatalog).Access(1), ##class(Contest.RouteGovernance).Shape(body,"run_id,variant,confirmed")
    If (body.%GetTypeOf("confirmed")'="boolean")||('body.confirmed) Do ##class(Demo.Protocol).Fail("Confirm synthetic local distribution")
    If '$Match(body.%Get("run_id"),"^[A-Za-z0-9-]{1,48}$") Do ##class(Demo.Protocol).Fail("Bounded run ID required")
    Do ##class(Contest.DeclarationCatalog).Choice(body,"variant",["identifier-leak","corrected"])
    Set profiles=..Profiles(), id=body.%Get("run_id"), branches=[], boot=$Get(^ContestAgents("boot"))
    If $Length(profiles.%ToJSON())>16000 Do ##class(Demo.Protocol).Fail("Combined profile snapshot exceeds the bounded message contract")
    For target="quality","research","clinic" {
        Do branches.%Push({"id":(target),"organization":(profiles.%Get(target).profile.name),"protocol":($Select(target="quality":"SQL",target="research":"REST",1:"HL7")),"namespace":($Select(target="quality":"DEMOQUALITY",target="research":"DEMORESEARCH",1:"DEMOCLINIC")),"state":"prepared","message_id":"","session_id":"","fields":[],"payload_hash":"","policy_mismatches":[]})
    }
    Set ns=$Namespace
    Try {
        Set $Namespace="DEMODISTRIBUTION"
        Lock +^ContestMulti("runLock",id):2
        If '$Test Do ##class(Demo.Protocol).Fail("Run busy")
        Try {
            If $Data(^ContestMulti("run",id)) {
                Set record=##class(Contest.Multi.Runtime).Read(id)
                If record.variant'=body.variant Do ##class(Demo.Protocol).Fail("Immutable run ID conflict")
            } Else {
                Set sc=##class(Ens.Director).GetProductionStatus(.name,.state) $$$ThrowOnError(sc)
                If (name'="Contest.Multi.Production")||(state'=1) Do ##class(Demo.Protocol).Fail("Distribution Production is not running")
                Set production=##class(Ens.Config.Production).%OpenId(name), hosts={}
                For i=1:1:production.Items.Count() {
                    Set item=production.Items.GetAt(i), partner=""
                    For j=1:1:item.Settings.Count() {
                        Set setting=item.Settings.GetAt(j)
                        If setting.Name="BusinessPartner" Set partner=setting.Value
                    }
                    Do hosts.%Set(item.Name,partner)
                }
                For target="hospital","quality","research","clinic" {
                    Set host=$Select(target="hospital":"FHIRSource",target="quality":"QualitySQL",target="research":"ResearchREST",1:"ClinicHL7")
                    If hosts.%Get(host)'=profiles.%Get(target).profile.partner Do ##class(Demo.Protocol).Fail("Business Partner mapping changed; explicitly reconcile profile and host configuration")
                }
                Set record={"id":(id),"variant":(body.variant),"state":"queued","created_at":(##class(Demo.Protocol).Now()),"profiles":(profiles),"source_pins":[],"branches":(branches),"host_partners":(hosts),"actor":($Username),"mapping_version":"multi-org-v1","boot":(boot)}
                Do ##class(Contest.Multi.Runtime).Save(record)
                Set $Namespace="TRIAGE"
                Job ##class(Contest.MultiOrganization).Worker(id)::5
                Set $Namespace="DEMODISTRIBUTION"
                If '$Test Do ##class(Demo.Protocol).Fail("Distribution worker could not start; run reserved, no automatic resend")
            }
        } Catch ex { Lock -^ContestMulti("runLock",id) Throw ex }
        Lock -^ContestMulti("runLock",id)
    } Catch ex { Set $Namespace=ns Throw ex }
    Set $Namespace=ns
    Do ##class(Contest.KnowledgeService).Audit("distribution.requested",id,"Synthetic local distribution; no model authorization")
    Quit record
}

ClassMethod Worker(id As %String)
{
    Set previous=$Namespace
    Try {
        Set $Namespace="DEMODISTRIBUTION", record=##class(Contest.Multi.Runtime).Read(id), request=##class(Contest.Multi.Request).%New()
        Set request.RunId=id, request.Variant=record.variant, request.Profiles=record.profiles.%ToJSON()
        Set sc=##class(Ens.Director).CreateBusinessService("FHIRSource",.service) $$$ThrowOnError(sc)
        Set sc=service.ProcessInput(request,.reply) $$$ThrowOnError(sc)
        Do ##class(Contest.Multi.Runtime).Collect(id)
    } Catch ex {
        If $Namespace="DEMODISTRIBUTION" {
            Set record=##class(Contest.Multi.Runtime).Read(id), record.state="failed", record.error=ex.DisplayString()
            Do ##class(Contest.Multi.Runtime).Save(record)
        }
        Set $Namespace=previous
        Do ##class(Contest.KnowledgeService).Audit("distribution.worker.failed",id,ex.DisplayString())
    }
    Set $Namespace=previous
}
}
