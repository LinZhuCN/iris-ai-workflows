Class Contest.LocalKnowledge
{
ClassMethod Open() As %AI.RAG.KnowledgeBase
{
    Set embedding = ##class(%AI.RAG.Embedding.FastEmbed).Create()
    Set store = ##class(%AI.RAG.VectorStore.IRIS).%New()
    Set store.TableName = "Contest.HIPAAKnowledgeV1"
    Set store.Dimensions = embedding.Dimensions, store.ModelName = embedding.ModelName
    Set sc = store.Build() $$$ThrowOnError(sc)
    Set knowledge = ##class(%AI.RAG.KnowledgeBase).%New("hipaa_local_v1","Dated HIPAA reference texts and explicit demonstration policy; not a compliance verdict")
    Set knowledge.TopK = 5
    Set sc = knowledge.Build(embedding,store) $$$ThrowOnError(sc)
    Quit knowledge
}

ClassMethod IndexRecord(knowledge As %AI.RAG.KnowledgeBase, record As %DynamicObject) As %Status
{
    Set scope = record.%Get("retrieval_scope")
    If '((scope = "normative") || (scope = "technical") || (scope = "orientation") || (scope = "organization_policy")) {
        Quit $$$ERROR($$$GeneralError,"Disallowed retrieval scope in default import")
    }
    If (record.%Get("id") = "") || (record.%Get("source_url") = "") || (record.%Get("source_locator") = "") || (record.%Get("text") = "") {
        Quit $$$ERROR($$$GeneralError,"Knowledge record lacks source, locator, ID or text")
    }
    Set text = record.%Get("text"), id = record.%Get("id")
    Do record.%Remove("text")
    // Bound long unbroken source paragraphs before the SDK's own chunker.
    For offset = 1:1800:$Length(text) {
        Do record.%Set("source",id_":"_offset)
        Do record.%Set("character_offset",offset-1)
        Set sc = knowledge.AddDocument($Extract(text,offset,offset+1999),record)
        If $System.Status.IsError(sc) Quit
    }
    Quit sc
}

ClassMethod ImportFile(path As %String, expected As %Integer = 715) As %Status
{
    Lock +^ContestLocalKnowledge("import"):0
    If '$Test Quit $$$ERROR($$$GeneralError,"A local knowledge import is already running")
    Set stream = ##class(%Stream.FileCharacter).%New()
    Try {
        Set ^ContestLocalKnowledge("state") = "indexing"
        Set ^ContestLocalKnowledge("documents") = 0
        Set ^ContestLocalKnowledge("error") = ""
        Set ^ContestLocalKnowledge("started") = $ZDATETIME($HOROLOG,3)
        Set sc = stream.LinkToFile(path) $$$ThrowOnError(sc)
        Set stream.TranslateTable = "UTF8"
        Set knowledge = ..Open()
        Set deleted = $System.SQL.Execute("DELETE FROM Contest.HIPAAKnowledgeV1")
        If deleted.%SQLCODE < 0 {
            Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError,deleted.%Message))
        }
        While 'stream.AtEnd {
            Set line = stream.ReadLine(2000000,.sc) $$$ThrowOnError(sc)
            If line = "" Continue
            Set record = {}.%FromJSON(line)
            Set sc = ..IndexRecord(knowledge,record) $$$ThrowOnError(sc)
            Set ^ContestLocalKnowledge("documents") = ^ContestLocalKnowledge("documents") + 1
        }
        If ^ContestLocalKnowledge("documents") '= expected {
            Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError,"Knowledge document count does not match expected import"))
        }
        Set ^ContestLocalKnowledge("state") = "ready"
        Set ^ContestLocalKnowledge("completed") = $ZDATETIME($HOROLOG,3)
        Do stream.%Close()
        Lock -^ContestLocalKnowledge("import")
        Set sc = $$$OK
    } Catch ex {
        Set ^ContestLocalKnowledge("state") = "failed"
        Set ^ContestLocalKnowledge("error") = ex.DisplayString()
        Do stream.%Close()
        Lock -^ContestLocalKnowledge("import")
        Set sc = ex.AsStatus()
    }
    Quit sc
}

ClassMethod Search(query As %String) As %DynamicObject
{
    Lock +^ContestLocalKnowledge("import"):0
    If '$Test Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError,"HIPAA knowledge index is being rebuilt"))
    Try {
        If $Get(^ContestLocalKnowledge("state")) '= "ready" {
            Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError,"HIPAA knowledge index is not ready"))
        }
        Set knowledge = ..Open(), manager = ##class(%AI.ToolMgr).%New()
        Set sc = knowledge.AddToManager(manager) $$$ThrowOnError(sc)
        Set result = manager.ExecuteTool("hipaa_local_v1",{"query":(query)})
    } Catch ex {
        Lock -^ContestLocalKnowledge("import")
        Throw ex
    }
    Lock -^ContestLocalKnowledge("import")
    Quit result
}
}
