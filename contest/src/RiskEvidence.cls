Class Contest.RiskEvidence
{
ClassMethod Assemble(chunks As %DynamicArray, section As %String) As %DynamicObject
{
    If (chunks.%Size()<1)||(chunks.%Size()>32) Do ##class(Demo.Protocol).Fail("Complete section requires 1-32 chunks")
    Set first=chunks.%Get(0).metadata, text="", ids=[], coordinates=[], seen={}
    For i=0:1:chunks.%Size()-1 {
        Set hit=chunks.%Get(i), meta=hit.metadata, offset=meta.%Get("character_offset")
        If (meta.kind'="regulation_snapshot") || (meta.%Get("retrieval_scope")'="normative") || (meta.%Get("source_locator")'=section) Do ##class(Demo.Protocol).Fail("Section requires exact normative snapshot provenance")
        For key="id","source_version","content_sha256","source_sha256","source_url" {
            If (meta.%Get(key)="") || (meta.%Get(key)'=first.%Get(key)) Do ##class(Demo.Protocol).Fail("Mixed or missing section provenance")
        }
        If (meta.%GetTypeOf("character_offset")'="number") || (offset<0) || (offset\1'=offset) || (offset>32000) || seen.%IsDefined(offset) Do ##class(Demo.Protocol).Fail("Invalid or duplicate section offset")
        If (hit.%GetTypeOf("text")'="string") || ($Length(hit.text)=0) || ($Length(hit.text)>4000) Do ##class(Demo.Protocol).Fail("Invalid source chunk size")
        // The current index stores Python character offsets; reject unsupported surrogate coordinates rather than shifting source text.
        For j=1:1:$Length(hit.text) If ($Ascii(hit.text,j)>=55296)&&($Ascii(hit.text,j)<=57343) Do ##class(Demo.Protocol).Fail("Non-BMP section coordinates require an explicit index migration")
        Do seen.%Set(offset,1)
        Set ordered(offset)=hit
    }
    Set offset=""
    For {
        Set offset=$Order(ordered(offset)) Quit:offset=""
        Set hit=ordered(offset), start=offset
        // Index chunks were stripped after assigning their offsets; only already reconstructed whitespace can be skipped.
        While ($ZStrip($Extract(hit.text,1),"<>W")'="") && (start<$Length(text)) && (($Extract(text,start+1)=" ")||($Extract(text,start+1)=$Char(9))||($Extract(text,start+1)=$Char(10))||($Extract(text,start+1)=$Char(13))) {
            Set start=start+1
        }
        Do coordinates.%Push({"chunk_id":(hit.id),"index_offset":(offset),"resolved_offset":(start)})
        If (start>$Length(text)) || ((start+$Length(hit.text))>32000) Do ##class(Demo.Protocol).Fail("Section has a source gap or exceeds 32000 characters")
        Set overlap=$Length(text)-start
        If overlap>$Length(hit.text) Set overlap=$Length(hit.text)
        If $Extract(text,start+1,start+overlap)'=$Extract(hit.text,1,overlap) Do ##class(Demo.Protocol).Fail("Section overlap differs from canonical text")
        Set text=text_$Extract(hit.text,overlap+1,*)
        Do ids.%Push(hit.id)
    }
    If ##class(Demo.Protocol).Hash($ZConvert(text,"O","UTF8"))'=first.%Get("content_sha256") Do ##class(Demo.Protocol).Fail("Complete section does not match prepared-source UTF-8 hash")
    Set metadata={}.%FromJSON(first.%ToJSON())
    Do metadata.%Remove("character_offset"), metadata.%Remove("chunk_index"), metadata.%Remove("source")
    Set entry={"id":("section-"_$Piece(section," ",3)),"record_id":(first.id),"text":(text),"metadata":(metadata),"chunk_ids":(ids),"chunk_coordinates":(coordinates),"excerpt_start":0,"retrieval_method":"complete_pinned_section","source_hash_verified":true,"section_text_complete":true}
    Do ##class(Contest.BusinessReviewV2).Decorate(entry)
    Quit entry
}

ClassMethod Read(config As %DynamicObject, section As %String) As %DynamicObject
{
    If '((section="45 CFR 164.502")||(section="45 CFR 164.506")||(section="45 CFR 164.514")) Do ##class(Demo.Protocol).Fail("Section outside staged engineering template")
    Try {
        Do ##class(Contest.KnowledgeService).ValidateVersion(config.table,config.%Get("index_version"))
        Set rs=##class(%SQL.Statement).%ExecDirect(,"SELECT id,text,metadata FROM "_config.table_" WHERE metadata LIKE ?","%""source_locator"":"""_section_"""%"), chunks=[]
        If rs.%SQLCODE<0 Do ##class(Demo.Protocol).Fail(rs.%Message)
        While rs.%Next() {
            Set meta={}.%FromJSON(rs.%Get("metadata"))
            If (meta.%Get("source_locator")'=section) || (meta.kind'="regulation_snapshot") || (meta.%Get("retrieval_scope")'="normative") Continue
            If chunks.%Size()>=32 Do ##class(Demo.Protocol).Fail("Section exceeds bounded complete-source lookup")
            Do chunks.%Push({"id":(rs.%Get("id")),"text":(rs.%Get("text")),"metadata":(meta)})
        }
        If rs.%SQLCODE<0 Do ##class(Demo.Protocol).Fail(rs.%Message)
        Set response={"section":(section),"availability":"unavailable","evidence":[],"section_chunks":(chunks.%Size()),"truncated":false,"source_hash_verified":false}
        If chunks.%Size()>0 {
            Do response.evidence.%Push(..Assemble(chunks,section))
            Set response.availability="available"
            Do response.%Set("source_hash_verified",1,"boolean")
        } Else {
            Do response.%Set("error","No exact normative section in the pinned index; no substitute evidence")
        }
    } Catch ex {
        Do ##class(Contest.KnowledgeService).Audit("risk.section.failed",section,ex.DisplayString())
        Throw ex
    }
    Quit response
}
}
