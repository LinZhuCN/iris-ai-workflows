Class Contest.RiskEvidenceTests Extends %UnitTest.TestProduction
{
Parameter PRODUCTION = "Contest.Production";
Method TestControl() As %Status { Quit $$$OK }

Method Chunks() As %DynamicArray
{
    Set full="Section heading"_$Char(10)_"Condition one; exception two.", hash=##class(Demo.Protocol).Hash($ZConvert(full,"O","UTF8"))
    Set meta={"id":"source","source_locator":"45 CFR 164.514","source_version":"unit-snapshot","content_sha256":(hash),"source_sha256":"unit-source-hash","source_url":"https://example.invalid/unit-source","kind":"regulation_snapshot","retrieval_scope":"normative","character_offset":0}
    Set second={}.%FromJSON(meta.%ToJSON())
    Do second.%Set("character_offset",16)
    Quit [{"id":"chunk-0","text":($Extract(full,1,24)),"metadata":(meta)},{"id":"chunk-1","text":($Extract(full,17,*)),"metadata":(second)}]
}

Method TestCompleteSourceAndHash()
{
    Set chunks=..Chunks(), section=##class(Contest.RiskEvidence).Assemble(chunks,"45 CFR 164.514")
    Do $$$AssertEquals(section.text,"Section heading"_$Char(10)_"Condition one; exception two.")
    Do $$$AssertEquals(section.%Get("source_hash_verified"),1)
    Do $$$AssertEquals(section.%Get("section_text_complete"),1)
    Do $$$AssertEquals(section.%Get("chunk_ids").%Size(),2)
    Set combined=""
    For i=0:1:section.passages.%Size()-1 Set combined=combined_section.passages.%Get(i).text
    Do $$$AssertEquals(combined,section.text)
}

Method TestStrippedChunkCoordinatesRequireFullHash()
{
    Set chunks=..Chunks()
    Do chunks.%Get(1).metadata.%Set("character_offset",15)
    Set section=##class(Contest.RiskEvidence).Assemble(chunks,"45 CFR 164.514")
    Do $$$AssertEquals(section.%Get("chunk_coordinates").%Get(1).%Get("index_offset"),15)
    Do $$$AssertEquals(section.%Get("chunk_coordinates").%Get(1).%Get("resolved_offset"),16)
    Do $$$AssertTrue(section.%Get("source_hash_verified"))
    Set chunks=..Chunks()
    Do chunks.%Get(1).metadata.%Set("character_offset",14)
    Set rejected=0
    Try { Set section=##class(Contest.RiskEvidence).Assemble(chunks,"45 CFR 164.514") } Catch ex { Set rejected=1 }
    Do $$$AssertTrue(rejected,"Never shift across non-whitespace to make text fit")
}

Method TestIncompleteOrConflictingSourceFails()
{
    For mode="gap","overlap","hash","duplicate","source","version","locator","kind","offset","nonbmp","empty" {
        Set chunks=..Chunks(), rejected=0
        If mode="gap" Do chunks.%Get(1).metadata.%Set("character_offset",30)
        If mode="overlap" Set chunks.%Get(1).text="Unexpected replacement of overlapped source text."
        If mode="hash" Do chunks.%Get(0).metadata.%Set("content_sha256","changed")
        If mode="duplicate" Do chunks.%Get(1).metadata.%Set("character_offset",0)
        If mode="source" Set chunks.%Get(1).metadata.id="other-source"
        If mode="version" Do chunks.%Get(1).metadata.%Set("source_version","other-version")
        If mode="locator" Do chunks.%Get(1).metadata.%Set("source_locator","45 CFR 164.506")
        If mode="kind" Set chunks.%Get(1).metadata.kind="llm_brief"
        If mode="offset" Do chunks.%Get(1).metadata.%Set("character_offset",-1)
        If mode="nonbmp" Set chunks.%Get(1).text=$Char(55357,56832)_chunks.%Get(1).text
        If mode="empty" Set chunks=[]
        Try { Set ignored=##class(Contest.RiskEvidence).Assemble(chunks,"45 CFR 164.514") } Catch ex { Set rejected=1 }
        Do $$$AssertTrue(rejected,mode)
    }
}
}
