Class Contest.DeclarationEvidence Extends Contest.RiskEvidence
{
ClassMethod Read(config As %DynamicObject, section As %String) As %DynamicObject
{
    If (section'="45 CFR 164.501")&&(section'="45 CFR 164.508") Quit ##super(config,section)
    Try {
        Do ##class(Contest.KnowledgeService).ValidateVersion(config.table,config.%Get("index_version"))
        Set rs=##class(%SQL.Statement).%ExecDirect(,"SELECT id,text,metadata FROM "_config.table_" WHERE metadata LIKE ?","%""source_locator"":"""_section_"""%"), chunks=[]
        If rs.%SQLCODE<0 Do ##class(Demo.Protocol).Fail(rs.%Message)
        While rs.%Next() {
            Set meta={}.%FromJSON(rs.%Get("metadata"))
            If (meta.%Get("source_locator")'=section)||(meta.kind'="regulation_snapshot")||(meta.%Get("retrieval_scope")'="normative") Continue
            If chunks.%Size()>=32 Do ##class(Demo.Protocol).Fail("Declaration section exceeds bounded source lookup")
            Do chunks.%Push({"id":(rs.%Get("id")),"text":(rs.%Get("text")),"metadata":(meta)})
        }
        If rs.%SQLCODE<0 Do ##class(Demo.Protocol).Fail(rs.%Message)
        Set response={"section":(section),"availability":"unavailable","evidence":[],"section_chunks":(chunks.%Size()),"truncated":false,"source_hash_verified":false}
        If chunks.%Size()>0 {
            Do response.evidence.%Push(..Assemble(chunks,section))
            Set response.availability="available"
            Do response.%Set("source_hash_verified",1,"boolean")
        } Else {
            Do response.%Set("error","Required normative section is absent from the pinned index")
        }
    } Catch ex {
        Do ##class(Contest.KnowledgeService).Audit("declaration.section.failed",section,ex.DisplayString())
        Throw ex
    }
    Quit response
}
}
