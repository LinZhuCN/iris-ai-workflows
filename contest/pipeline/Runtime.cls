Class Contest.Aggregation.Runtime
{
ClassMethod Digest(value) As %String
{
    Quit ##class(Demo.Protocol).Hash($ZConvert(value.%ToJSON(),"O","UTF8"))
}

ClassMethod Config() As %DynamicObject
{
    If $Namespace'="PIPELINE" Do ##class(Demo.Protocol).Fail("PIPELINE runtime required")
    Set production=##class(Ens.Config.Production).%OpenId("Contest.Aggregation.Production")
    If '$IsObject(production) Do ##class(Demo.Protocol).Fail("Aggregation Production not installed")
    Set items=[]
    For i=1:1:production.Items.Count() {
        Set item=production.Items.GetAt(i), settings=[]
        For j=1:1:item.Settings.Count() {
            Set setting=item.Settings.GetAt(j)
            Do settings.%Push({"target":(setting.Target),"name":(setting.Name),"value":(setting.Value)})
        }
        Do items.%Push({"name":(item.Name),"class":(item.ClassName),"enabled":(item.Enabled),"pool_size":(item.PoolSize),"settings":(settings)})
    }
    Quit {"namespace":"PIPELINE","production":"Contest.Aggregation.Production","items":(items),"source":"four-sql-tables-cohort-v1","mapping":"sql-fhir-r4-v1","recipient":"local-fhir-center","http_server":"gateway","http_port":80,"endpoint":"/csp/healthshare/fhirdemo/fhir/r4","identity":"ContestAggregationFHIR","collector":"aggregation-receipt-v1"}
}

ClassMethod Binding() As %DynamicObject
{
    Quit {"instance_id":"local-triage-real","namespace":"PIPELINE","production":"Contest.Aggregation.Production","source":"SQLSource","sender":"FHIRSender","point":"before_send","config_hash":(..Digest(..Config())),"collector_version":"aggregation-receipt-v1","policy_version":"aggregation-exact-scope-v1"}
}

ClassMethod Approval(id As %String, digest As %String) As %DynamicObject
{
    Set binding=..Binding(), previous=$Namespace
    Try {
        Set $Namespace="TRIAGE"
        Set status=##class(Contest.RouteGovernance).Check(id,binding,digest)
        If status.state'="approved_scope" Do ##class(Demo.Protocol).Fail("Aggregation approval is not applicable: "_status.state)
        Set dossier=##class(Contest.RouteGovernance).Read(id)
        If '$IsObject(dossier.approval.%Get("scenario")) Do ##class(Demo.Protocol).Fail("Approved internal organization scenario required")
    } Catch ex { Set $Namespace=previous Throw ex }
    Set $Namespace=previous
    Set declaration=dossier.core.declaration, scope=declaration.scope
    If (declaration.kind'="aggregation")||(declaration.%Get("purpose_code")'="internal-consolidation")||(declaration.recipient'="local-fhir-center")||(declaration.%Get("service_identity")'="ContestAggregationFHIR")||(scope.%Get("patient_selection")'="synthetic-cohort-v1") Do ##class(Demo.Protocol).Fail("Approval does not cover this aggregation task")
    Quit dossier
}

ClassMethod Paths(value, prefix As %String, Output paths As %DynamicArray)
{
    If '$IsObject(paths) Set paths=[]
    If $IsObject(value) {
        If value.%IsA("%DynamicArray") {
            For i=0:1:value.%Size()-1 Do ..Paths(value.%Get(i),prefix,.paths)
        } Else {
            Set iterator=value.%GetIterator()
            While iterator.%GetNext(.key,.child) {
                If key="resourceType" Continue
                Do ..Paths(child,prefix_"."_key,.paths)
            }
        }
    } Else {
        Set found=0
        For i=0:1:paths.%Size()-1 { If paths.%Get(i)=prefix Set found=1 }
        If 'found Do paths.%Push(prefix)
    }
}

ClassMethod Inspect(bundle As %DynamicObject, dossier As %DynamicObject) As %DynamicObject
{
    Set scope=dossier.core.declaration.scope, allowed={}, paths=[], counts={"Patient":0,"Encounter":0,"Condition":0,"MedicationRequest":0}
    For i=0:1:scope.resources.%Size()-1 Do allowed.%Set(scope.resources.%Get(i),1)
    If bundle.entry.%Size()>scope.%Get("max_records") Do ##class(Demo.Protocol).Fail("Resource count exceeds approved batch scope")
    For i=0:1:bundle.entry.%Size()-1 {
        Set resource=bundle.entry.%Get(i).resource, type=resource.resourceType
        If 'allowed.%IsDefined(type) Do ##class(Demo.Protocol).Fail("Resource outside approved scope")
        Do counts.%Set(type,counts.%Get(type)+1), ..Paths(resource,type,.paths)
    }
    For i=0:1:paths.%Size()-1 {
        Set found=0
        For j=0:1:scope.fields.%Size()-1 { If paths.%Get(i)=scope.fields.%Get(j) Set found=1 }
        If 'found Do ##class(Demo.Protocol).Fail("Output field outside approved scope")
    }
    Quit {"method":"actual-fhir-leaf-paths-v1","resource_counts":(counts),"field_paths":(paths),"scope_match":true,"complete_hipaa_check":false,"unclassified_content":"semantic/free-text PHI detection not performed"}
}

ClassMethod Http(path As %String, body As %String = "") As %DynamicObject
{
    If (path'="")&&('$Match(path,"^(Patient|Encounter|Condition|MedicationRequest)/agg-[A-Za-z0-9-]{1,50}$")) Do ##class(Demo.Protocol).Fail("Unapproved FHIR path")
    Set previous=$IO, file="/contest/data/platform/AggregationFHIR.password"
    Open file:"R":2
    If '$Test Do ##class(Demo.Protocol).Fail("FHIR credential unavailable")
    Try { Use file Read password } Catch ex { Close file Use previous Throw ex }
    Close file Use previous
    Set http=##class(%Net.HttpRequest).%New(), http.Server="gateway", http.Port=80, http.Timeout=15
    Set encoded=$Translate($System.Encryption.Base64Encode("ContestAggregationFHIR:"_password),$Char(13,10))
    Set sc=http.SetHeader("Authorization","Basic "_encoded) $$$ThrowOnError(sc)
    Set sc=http.SetHeader("Accept","application/fhir+json") $$$ThrowOnError(sc)
    Kill password,encoded
    Set url="/csp/healthshare/fhirdemo/fhir/r4/"_path
    If body'="" {
        Set http.ContentType="application/fhir+json"
        Do http.EntityBody.Write(body)
        Set sc=http.Post(url)
    } Else {
        Set sc=http.Get(url)
    }
    $$$ThrowOnError(sc)
    If '$IsObject(http.HttpResponse) Do ##class(Demo.Protocol).Fail("FHIR response unavailable; reconcile before replay")
    If (http.HttpResponse.StatusCode<200)||(http.HttpResponse.StatusCode>299) Do ##class(Demo.Protocol).Fail("FHIR HTTP "_http.HttpResponse.StatusCode_"; inspect protected FHIR logs")
    Quit {}.%FromJSON(http.HttpResponse.Data)
}
}
