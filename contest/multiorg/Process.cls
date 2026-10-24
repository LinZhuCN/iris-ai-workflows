Class Contest.Multi.Process Extends Ens.BusinessProcess
{
Method OnRequest(request As Contest.Multi.Request, Output response As Contest.Multi.Reply) As %Status
{
    Try {
        Set record=##class(Contest.Multi.Runtime).Read(request.RunId)
        If (record.state'="queued")||(record.profiles.%ToJSON()'=request.Profiles)||(record.variant'=request.Variant) Do ##class(Demo.Protocol).Fail("Frozen run conflict or replay")
        Set record.state="reading_fhir"
        Do ##class(Contest.Multi.Runtime).Save(record)
        Set source={}.%FromJSON(##class(Contest.Multi.Runtime).Source()), pins=[{"resource":("Patient/"_source.id),"version":(source.meta.versionId),"hash":(##class(Contest.ExportEvidence).Digest(source))}]
        Do record.%Set("source_pins",pins), record.%Set("request_id",request.%Id())
        Set record.state="sending"
        Do ##class(Contest.Multi.Runtime).Save(record)
        For i=0:1:record.branches.%Size()-1 {
            Set branch=record.branches.%Get(i), send=##class(Contest.Multi.SendRequest).%New()
            Set send.RunId=request.RunId, send.Branch=branch.id, send.DeliveryId=request.RunId_"-"_branch.id
            Set send.Payload=##class(Contest.Multi.Runtime).Transform(branch.id,send.DeliveryId,source.%ToJSON(),request.Variant)
            Set sc=..SendRequestSync($Select(branch.id="quality":"QualitySQL",branch.id="research":"ResearchREST",1:"ClinicHL7"),send,.reply,50)
            If $System.Status.IsError(sc) {
                Do ##class(Contest.Multi.Runtime).Failed(request.RunId,branch.id,$System.Status.GetErrorText(sc))
                $$$LOGERROR($System.Status.GetErrorText(sc))
            }
        }
        Set record=##class(Contest.Multi.Runtime).Read(request.RunId), completed=0
        For i=0:1:record.branches.%Size()-1 If record.branches.%Get(i).state="acknowledged" Set completed=completed+1
        Do record.%Set("delivery_state",$Select(completed=3:"completed",completed>0:"partial",1:"failed"))
        Set record.state="collecting_evidence"
        Do ##class(Contest.Multi.Runtime).Save(record)
        Set response=##class(Contest.Multi.Reply).%New(), response.Outcome=record.state
        Set sc=$$$OK
    } Catch ex {
        $$$LOGERROR(ex.DisplayString())
        Set sc=ex.AsStatus()
    }
    Quit sc
}
}
