Class User.ContestUtilizationProvision
{
ClassMethod Foundation()
{
    If $Namespace'="%SYS" Throw ##class(%Exception.General).%New("Provision in %SYS")
    Set ns="UTILIZATION", original=$Namespace
    Try {
        If '##class(%SYS.Namespace).Exists(ns) {
            Set $Namespace="HSLIB"
            Do ##class(HS.Util.Installer.Foundation).Install(ns)
            Set $Namespace=ns, ^ContestUtilizationInstall("owner")="iris-ai-workflows"
        }
        Set $Namespace=ns
        If $Get(^ContestUtilizationInstall("owner"))'="iris-ai-workflows" Throw ##class(%Exception.General).%New("UTILIZATION namespace ownership conflict")
    } Catch ex { Set $Namespace=original Throw ex }
    Set $Namespace=original
}

ClassMethod Pipeline()
{
    If $Namespace'="UTILIZATION" Throw ##class(%Exception.General).%New("UTILIZATION installation required")
    If ##class(Ens.Director).IsProductionRunning(.current) {
        If current'="Contest.Utilization.Production" Throw ##class(%Exception.General).%New("Another Production occupies UTILIZATION")
        Quit
    }
    Set sc=$SYSTEM.OBJ.Load("/contest/demo/Protocol.cls","ck") $$$ThrowOnError(sc)
    For name="Request","SendRequest","Reply","Data","Mapping","Runtime" {
        Set sc=$SYSTEM.OBJ.Load("/contest/pipeline/"_name_".cls","ck") $$$ThrowOnError(sc)
    }
    For name="Runtime","DeclarationBridge","Service","Receiver","Process","Production" {
        Set sc=$SYSTEM.OBJ.Load("/contest/utilization/"_name_".cls","ck") $$$ThrowOnError(sc)
    }
    Do ##class(Contest.Utilization.Runtime).EnsureReceiver()
    Set sc=##class(Ens.Director).StartProduction("Contest.Utilization.Production") $$$ThrowOnError(sc)
}

ClassMethod Register() As %DynamicObject
{
    If $Namespace'="UTILIZATION" Throw ##class(%Exception.General).%New("UTILIZATION registration required")
    If $Data(^ContestUtilization("registration")) {
        Set ref={}.%FromJSON(^ContestUtilization("registration")), binding=##class(Contest.Utilization.Runtime).Binding(), previous=$Namespace
        Try {
            Set $Namespace="TRIAGE"
            Set status=##class(Contest.RouteGovernance).Check(ref.id,binding,ref.digest)
            If (status.state'="missing_approval")&&(status.state'="approved_scope") Throw ##class(%Exception.General).%New("Existing utilization registration is not current: "_status.state)
        } Catch ex { Set $Namespace=previous Throw ex }
        Set $Namespace=previous
        Quit ref
    }
    Set declaration={"schema":1,"synthetic":true,"route_id":"synthetic-fhir-analysis","revision":1,"kind":"utilization","purpose_code":"internal-quality-improvement","purpose_text":"The DEMO-HOSPITAL internal quality team compares encounter classes by birth-year cohort to improve hospital services. This is internal quality improvement, not research for generalizable knowledge or external commercial reuse. Approved stable references permit linkage within this project; no de-identification claim.","owner":"demo-quality-office","service_identity":"local-utilization-service","recipient":"local-analysis-receiver","scope":{"resources":["Patient","Encounter"],"fields":["Patient.id","Patient.birthDate","Encounter.id","Encounter.status","Encounter.class.system","Encounter.class.code","Encounter.subject.reference"],"patient_selection":"synthetic-four-resources-v1","max_records":4}}
    Set binding=##class(Contest.Utilization.Runtime).Binding(), now=##class(Demo.Protocol).Now()\1, previous=$Namespace
    Try {
        Set $Namespace="TRIAGE"
        Set dossier=##class(Contest.RouteGovernance).Register(declaration,binding,now,now+2592000)
    } Catch ex { Set $Namespace=previous Throw ex }
    Set $Namespace=previous, ref={"id":(dossier.id),"digest":(dossier.digest)}
    Set ^ContestUtilization("registration")=ref.%ToJSON()
    Quit ref
}

ClassMethod Approve(id As %String, digest As %String)
{
    If $Namespace'="UTILIZATION" Throw ##class(%Exception.General).%New("UTILIZATION approval required")
    Set ref={}.%FromJSON(^ContestUtilization("registration"))
    If (ref.id'=id)||(ref.digest'=digest) Throw ##class(%Exception.General).%New("Exact registered utilization proposal required")
    Set previous=$Namespace
    Try {
        Set $Namespace="TRIAGE"
        Set dossier=##class(Contest.RouteGovernance).Approve(id,digest)
    } Catch ex { Set $Namespace=previous Throw ex }
    Set $Namespace=previous
}
}
