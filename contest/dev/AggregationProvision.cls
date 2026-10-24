Class User.ContestAggregationProvision
{
ClassMethod Foundation()
{
    If $Namespace'="%SYS" Throw ##class(%Exception.General).%New("Run provisioning in %SYS")
    For ns="PIPELINE","FHIRDEMO" {
        If '##class(%SYS.Namespace).Exists(ns) {
            Set original=$Namespace
            Try {
                Set $Namespace="HSLIB"
                Do ##class(HS.Util.Installer.Foundation).Install(ns)
            } Catch ex { Set $Namespace=original Throw ex }
            Set $Namespace=original
            Set $Namespace=ns, ^ContestAggregationInstall("owner")="iris-ai-workflows"
            Set $Namespace=original
        }
        Set original=$Namespace
        Try {
            Set $Namespace=ns
            If $Get(^ContestAggregationInstall("owner"))'="iris-ai-workflows" Throw ##class(%Exception.General).%New("Existing namespace is not owned by this demo")
        } Catch ex { Set $Namespace=original Throw ex }
        Set $Namespace=original
    }
}

ClassMethod Repository()
{
    If $Namespace'="FHIRDEMO" Throw ##class(%Exception.General).%New("FHIRDEMO repository required")
    Set path="/csp/healthshare/fhirdemo/fhir/r4"
    Set previous=$Namespace
    Try {
        Set $Namespace="%SYS", exists=##class(Security.Applications).Exists(path)
        If exists {
            Set sc=##class(Security.Applications).Get(path,.p) $$$ThrowOnError(sc)
            If p("NameSpace")'="FHIRDEMO" Throw ##class(%Exception.General).%New("FHIR endpoint ownership conflict")
        }
    } Catch ex { Set $Namespace=previous Throw ex }
    Set $Namespace=previous
    If 'exists {
        Do ##class(HS.FHIRServer.Installer).InstallNamespace()
        Do ##class(HS.FHIRServer.Installer).InstallInstance(path,"HS.FHIRServer.Storage.Json.InteractionsStrategy",$ListBuild("hl7.fhir.r4.core@4.0.1"),,"Synthetic aggregation data center")
    }
}

ClassMethod Access()
{
    If $Namespace'="%SYS" Throw ##class(%Exception.General).%New("Run access provisioning in %SYS")
    Set resource="ContestAggregationFHIR", role="ContestAggregationFHIRRole", account="ContestAggregationFHIR"
    If '##class(Security.Resources).Exists(resource) {
        Set sc=##class(Security.Resources).Create(resource,"Synthetic aggregation FHIR endpoint access",0) $$$ThrowOnError(sc)
    }
    If '##class(Security.Roles).Exists(role) {
        Set sc=##class(Security.Roles).Create(role,"Synthetic aggregation FHIR client",resource_":U,%Service_WebGateway:U") $$$ThrowOnError(sc)
    } Else {
        Set sc=##class(Security.Roles).Get(role,.roleProps) $$$ThrowOnError(sc)
        Set grants=roleProps("Resources")
        If ($Length(grants,",")'=2)||((","_grants_",")'[(","_resource_":U,"))||((","_grants_",")'[(",%Service_WebGateway:U,")) Throw ##class(%Exception.General).%New("FHIR service role differs; explicit access review required")
    }
    If '##class(Security.Users).Exists(account) {
        Open "/contest/data/platform/AggregationFHIR.password":"R":2
        If '$Test Throw ##class(%Exception.General).%New("Missing local FHIR credential")
        Use "/contest/data/platform/AggregationFHIR.password" Read password Close "/contest/data/platform/AggregationFHIR.password" Use $Principal
        Set sc=##class(Security.Users).Create(account,role,password,"Synthetic FHIR aggregation client","FHIRDEMO",,,0,1) $$$ThrowOnError(sc)
        Kill password
    } Else {
        Set sc=##class(Security.Users).Get(account,.userProps) $$$ThrowOnError(sc)
        If userProps("Roles")'=role Throw ##class(%Exception.General).%New("FHIR service identity role conflict")
    }
    Set path="/csp/healthshare/fhirdemo/fhir/r4"
    Set sc=##class(Security.Applications).Get(path,.p) $$$ThrowOnError(sc)
    If p("NameSpace")'="FHIRDEMO" Throw ##class(%Exception.General).%New("FHIR application ownership conflict")
    Set p("Resource")=resource, p("AutheEnabled")=32
    Set sc=##class(Security.Applications).Modify(path,.p) $$$ThrowOnError(sc)
}

ClassMethod Pipeline()
{
    If $Namespace'="PIPELINE" Throw ##class(%Exception.General).%New("PIPELINE installation required")
    If ##class(Ens.Director).IsProductionRunning(.current) {
        If current'="Contest.Aggregation.Production" Throw ##class(%Exception.General).%New("Another Production occupies PIPELINE")
        Quit
    }
    Set sc=$SYSTEM.OBJ.Load("/contest/demo/Protocol.cls","ck") $$$ThrowOnError(sc)
    For name="Request","SendRequest","Reply","Data","Mapping","Runtime","Service","Operation","Process","Production" {
        Set sc=$SYSTEM.OBJ.Load("/contest/pipeline/"_name_".cls","ck") $$$ThrowOnError(sc)
    }
    Do ##class(Contest.Aggregation.Data).EnsureAndSeed()
    Set sc=##class(Ens.Director).StartProduction("Contest.Aggregation.Production") $$$ThrowOnError(sc)
}

ClassMethod PresetApproval() As %DynamicObject
{
    If $Namespace'="PIPELINE" Throw ##class(%Exception.General).%New("PIPELINE preset required")
    If $Data(^ContestAggregation("approvalRef")) {
        Set ref={}.%FromJSON(^ContestAggregation("approvalRef"))
        Set dossier=##class(Contest.Aggregation.Runtime).Approval(ref.id,ref.digest)
        Quit ref
    }
    Set fields=["Patient.id","Patient.identifier.system","Patient.identifier.value","Patient.name.family","Patient.name.given","Patient.birthDate","Encounter.id","Encounter.status","Encounter.class.system","Encounter.class.code","Encounter.subject.reference","Encounter.period.start","Condition.id","Condition.clinicalStatus.coding.system","Condition.clinicalStatus.coding.code","Condition.code.coding.system","Condition.code.coding.code","Condition.code.coding.display","Condition.subject.reference","Condition.encounter.reference","MedicationRequest.id","MedicationRequest.status","MedicationRequest.intent","MedicationRequest.medicationCodeableConcept.coding.system","MedicationRequest.medicationCodeableConcept.coding.code","MedicationRequest.medicationCodeableConcept.coding.display","MedicationRequest.subject.reference","MedicationRequest.encounter.reference"]
    Set declaration={"schema":1,"synthetic":true,"route_id":"synthetic-sql-fhir-aggregation","revision":1,"kind":"aggregation","purpose_code":"internal-consolidation","purpose_text":"Consolidate the fixed synthetic clinic cohort into DEMO-HOSPITAL's internal FHIR center to support approved hospital care and operations. Both systems belong to the same simulated covered entity. No external export or de-identification claim.","owner":"demo-clinical-data-office","service_identity":"ContestAggregationFHIR","recipient":"local-fhir-center","scope":{"resources":["Patient","Encounter","Condition","MedicationRequest"],"fields":(fields),"patient_selection":"synthetic-cohort-v1","max_records":8}}
    Set binding=##class(Contest.Aggregation.Runtime).Binding(), now=##class(Demo.Protocol).Now()\1, previous=$Namespace
    Try {
        Set $Namespace="TRIAGE"
        Set dossier=##class(Contest.RouteGovernance).Register(declaration,binding,now,now+2592000)
        Set approved=##class(Contest.RouteGovernance).Approve(dossier.id,dossier.digest)
    } Catch ex { Set $Namespace=previous Throw ex }
    Set $Namespace=previous, ref={"id":(dossier.id),"digest":(dossier.digest)}
    Set ^ContestAggregation("approvalRef")=ref.%ToJSON()
    Quit ref
}
}
