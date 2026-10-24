Class Contest.BusinessToolsV2 Extends %AI.Tool
{
/// Read the bound synthetic fact packet FIRST; no expected answers or legal conclusions are supplied.
ClassMethod ReadBusinessFacts(runId As %String) As %DynamicObject
{
    Quit ##class(Contest.BusinessTools).ReadBusinessFacts(runId)
}

/// Discover dated normative regulations and HHS guidance in the pinned vector index; then verify relevant conditions/exceptions with LookupBusinessClause.
ClassMethod SearchBusinessEvidence(runId As %String, query As %String) As %DynamicObject
{
    Quit ##class(Contest.BusinessTools).SearchBusinessEvidence(runId,query)
}

/// Fetch a dated regulation section such as 45 CFR 164.506, optionally focused by a literal source phrase or paragraph marker. Empty anchor inspects the beginning. Check truncated; cite returned passage IDs, never invent quotations.
ClassMethod LookupBusinessClause(runId As %String, section As %String, anchor As %String) As %DynamicObject
{
    If (runId="") || (runId'=$Get(^ContestBusinessContext($Job))) || '$Get(^ContestBusinessContext($Job,"factsRead")) Do ##class(Demo.Protocol).Fail("Read bound facts before clause lookup")
    If '$Match(section,"^45 CFR 16[04][.][0-9]{3}$") || ($Length(anchor)>160) Do ##class(Demo.Protocol).Fail("Use a bounded CFR section and literal source anchor")
    If $Get(^ContestBusinessContext($Job,"queries"),0)>=3 Do ##class(Demo.Protocol).Fail("At most three combined evidence retrieval calls")
    Set count=$Get(^ContestBusinessContext($Job,"queries"),0)+1, ^ContestBusinessContext($Job,"queries")=count
    Set response={"availability":"unavailable","evidence":[],"section":(section),"anchor":(anchor),"truncated":false,"anchor_matched":false}
    If $Get(^ContestBusinessContext($Job,"simulateUnavailable")) {
        Do response.%Set("error","Explicit synthetic retrieval-outage control; no sources available")
    } Else {
        Try {
            Set config={}.%FromJSON(^ContestBusinessContext($Job,"config"))
            Do ##class(Contest.KnowledgeService).ValidateVersion(config.table,config.%Get("index_version"))
            // Metadata is canonical JSON from the indexer; bind the exact locator, never caller SQL.
            Set filter="%""source_locator"":"""_section_"""%"
            Set rs=##class(%SQL.Statement).%ExecDirect(,"SELECT id,text,metadata FROM "_config.table_" WHERE metadata LIKE ?",filter)
            If rs.%SQLCODE<0 Do ##class(Demo.Protocol).Fail(rs.%Message)
            Set rows=0, matches=0, sectionChunks=0, cropped=0
            While rs.%Next() {
                Set rows=rows+1
                If rows>100 Do ##class(Demo.Protocol).Fail("Section exceeds bounded lookup; no partial success")
                Set meta={}.%FromJSON(rs.%Get("metadata")), text=rs.%Get("text")
                If (meta.%Get("source_locator")'=section) || (meta.kind'="regulation_snapshot") || (meta.%Get("retrieval_scope")'="normative") Continue
                Set offset=meta.%Get("character_offset")
                If $Data(chunks(offset)) Do ##class(Demo.Protocol).Fail("Ambiguous section source offsets")
                Set sectionChunks=sectionChunks+1
                Set chunks(offset)={"id":(rs.%Get("id")),"text":(text),"metadata":(meta)}
            }
            Set offset=""
            For {
                Set offset=$Order(chunks(offset)) Quit:offset=""
                Set hit=chunks(offset), position=$Find($ZConvert(hit.text,"L"),$ZConvert(anchor,"L"))
                If (anchor'="") && 'position Continue
                Set matches=matches+1
                If response.evidence.%Size()>=5 Continue
                Set start=$Select(anchor="":1,1:position-$Length(anchor)-400)
                If start<1 Set start=1
                If (start>1) || ($Length(hit.text)>2000) Set cropped=1
                Set entry={"id":("evidence-"_count_"-"_response.evidence.%Size()),"record_id":(hit.metadata.id),"chunk_id":(hit.id),"text":($Extract(hit.text,start,start+1999)),"metadata":(hit.metadata),"excerpt_start":(start-1),"retrieval_method":"exact_section"}
                Do ##class(Contest.BusinessReviewV2).Decorate(entry)
                Do response.evidence.%Push(entry)
            }
            Do response.%Set("truncated",(sectionChunks>response.evidence.%Size())||cropped,"boolean"), response.%Set("anchor_matched",(anchor'="")&&(matches>0),"boolean"), response.%Set("matching_chunks",matches), response.%Set("section_chunks",sectionChunks)
            If response.evidence.%Size()>0 {
                Set response.availability="available"
                For i=0:1:response.evidence.%Size()-1 {
                    Set n=$Get(^ContestBusinessContext($Job,"evidenceCount"),0)
                    Set ^ContestBusinessContext($Job,"evidence",n)=response.evidence.%Get(i).%ToJSON(), ^ContestBusinessContext($Job,"evidenceCount")=n+1
                }
            } Else {
                Do response.%Set("error","No exact normative section/anchor match in the pinned index; refine or report insufficient evidence")
            }
        } Catch ex {
            Do ##class(Contest.KnowledgeService).Audit("business.clause.failed",runId,ex.DisplayString())
            Set response={"availability":"unavailable","evidence":[],"section":(section),"anchor":(anchor),"truncated":false,"anchor_matched":false,"error":"Pinned clause lookup failed; no substitute evidence"}
        }
    }
    Set ^ContestBusinessContext($Job,"evidenceRead")=1, ^ContestBusinessContext($Job,"clauseRead")=1
    Set n=$Get(^ContestBusinessContext($Job,"traceCount"),0)
    Set ^ContestBusinessContext($Job,"trace",n)={"tool":"LookupBusinessClause","section":(section),"anchor":(anchor),"time":(##class(Demo.Protocol).Now()),"response":(response)}.%ToJSON(), ^ContestBusinessContext($Job,"traceCount")=n+1
    Quit response
}
}
