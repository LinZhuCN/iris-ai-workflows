Class Contest.EmbeddingStoreTests Extends %UnitTest.TestProduction
{
Parameter PRODUCTION = "Contest.Production";

Method TestControl() As %Status
{
    Quit $$$OK
}

ClassMethod OpenKnowledge(table As %String, name As %String) As %AI.RAG.KnowledgeBase
{
    Set embedding = ##class(%AI.RAG.Embedding.FastEmbed).Create()
    Set store = ##class(%AI.RAG.VectorStore.IRIS).%New()
    Set store.TableName = table, store.Dimensions = 384, store.ModelName = "AllMiniLML6V2"
    Set sc = store.Build() $$$ThrowOnError(sc)
    Set knowledge = ##class(%AI.RAG.KnowledgeBase).%New(name,"Synthetic local embedding regression documents")
    Set knowledge.TopK = 1
    Set sc = knowledge.Build(embedding,store) $$$ThrowOnError(sc)
    Quit knowledge
}

Method TestRetrieval()
{
    Set knowledge = ..OpenKnowledge("Contest.LocalEmbeddingTests","local_embedding_tests")
    Set sc = knowledge.AddDocument("Synthetic analytics exports must remove medical record numbers under the demonstration policy.",{"source":"synthetic:analytics-mrn","scope":"normative","locator":"synthetic paragraph 1"})
    Do $$$AssertStatusOK(sc)
    Set sc = knowledge.AddDocument("Synthetic operational incidents include destination timeouts and failed network connections.",{"source":"synthetic:network-timeout","scope":"technical","locator":"synthetic paragraph 2"})
    Do $$$AssertStatusOK(sc)
    Set manager = ##class(%AI.ToolMgr).%New()
    Set sc = knowledge.AddToManager(manager)
    Do $$$AssertStatusOK(sc)
    Set catalog = manager.%Discover()
    Do $$$AssertEquals(catalog.%Size(),1)
    Do $$$AssertEquals(catalog.%Get(0).%Get("name"),"local_embedding_tests")
    Set result = manager.ExecuteTool("local_embedding_tests",{"query":"medical record number in analytics export"})
    Set rows = result.%Get("value")
    Do $$$AssertEquals(rows.%Size(),1)
    Set row = rows.%Get(0), metadata = row.%Get("metadata")
    Do $$$AssertEquals(metadata.%Get("source"),"synthetic:analytics-mrn")
    Do $$$AssertEquals(metadata.%Get("scope"),"normative")
    Do $$$AssertEquals(metadata.%Get("locator"),"synthetic paragraph 1")
    Do $$$AssertTrue(row.%Get("score") > 0.5)
    Do $$$AssertTrue(row.%Get("text") [ "medical record numbers")
}

Method TestStoreIsolation()
{
    Set knowledge = ..OpenKnowledge("Contest.LocalEmbeddingOtherTests","local_embedding_other_tests")
    Set sc = knowledge.AddDocument("Synthetic operational incidents include destination timeouts and failed network connections.",{"source":"synthetic:other-store"})
    Do $$$AssertStatusOK(sc)
    Set manager = ##class(%AI.ToolMgr).%New()
    Set sc = knowledge.AddToManager(manager)
    Do $$$AssertStatusOK(sc)
    Set result = manager.ExecuteTool("local_embedding_other_tests",{"query":"medical record number in analytics export"})
    Set rows = result.%Get("value")
    Do $$$AssertEquals(rows.%Size(),1)
    Do $$$AssertEquals(rows.%Get(0).%Get("metadata").%Get("source"),"synthetic:other-store")
}

Method TestHIPAALocalKnowledgeFactory()
{
    Set knowledge = ##class(Contest.LocalKnowledge).Open()
    Do $$$AssertEquals(knowledge.Name,"hipaa_local_v1")
}

Method TestLongSourceAndScopeGuard()
{
    Set knowledge = ..OpenKnowledge("Contest.LocalEmbeddingLongTests","local_embedding_long_tests")
    Set text = ""
    For i = 1:1:1200 Set text = text_"Medical record numbers must be removed from synthetic analytics exports. "
    Set sc = ##class(Contest.LocalKnowledge).IndexRecord(knowledge,{"id":"synthetic-long","text":(text),"retrieval_scope":"organization_policy","source_url":"https://example.invalid/synthetic-policy","source_locator":"Synthetic paragraph"})
    Do $$$AssertStatusOK(sc)
    Set sc = ##class(Contest.LocalKnowledge).IndexRecord(knowledge,{"id":"synthetic-rejected","text":"Historical guidance must not enter the default index.","retrieval_scope":"historical","source_url":"https://example.invalid/historical","source_locator":"Synthetic paragraph"})
    Do $$$AssertTrue($System.Status.IsError(sc))
    Set manager = ##class(%AI.ToolMgr).%New()
    Set sc = knowledge.AddToManager(manager)
    Do $$$AssertStatusOK(sc)
    Set result = manager.ExecuteTool("local_embedding_long_tests",{"query":"synthetic analytics export medical record numbers"})
    Set row = result.%Get("value").%Get(0)
    Do $$$AssertTrue($Length(row.%Get("text")) <= 2000)
    Do $$$AssertEquals(row.%Get("metadata").%Get("id"),"synthetic-long")
    Do $$$AssertEquals(row.%Get("metadata").%Get("retrieval_scope"),"organization_policy")
}

Method TestHIPAAIndex()
{
    Do $$$AssertEquals($Get(^ContestLocalKnowledge("state")),"ready")
    Do $$$AssertEquals($Get(^ContestLocalKnowledge("documents")),715)
    Set rows = $System.SQL.Execute("SELECT source,text,metadata FROM Contest.HIPAAKnowledgeV1")
    Do $$$AssertEquals(rows.%SQLCODE,0,rows.%Message)
    Set count = 0, maxLength = 0
    While rows.%Next() {
        Set metadata = {}.%FromJSON(rows.%Get("metadata"))
        Set ids(metadata.%Get("id")) = 1
        Set scopes(metadata.%Get("retrieval_scope")) = 1
        Set count = count + 1, maxLength = $Select($Length(rows.%Get("text")) > maxLength:$Length(rows.%Get("text")),1:maxLength)
    }
    Set id = "", documents = 0
    For { Set id = $Order(ids(id)) Quit:id=""  Set documents = documents + 1 }
    Do $$$AssertEquals(documents,715)
    Do $$$AssertEquals(count,1785)
    Do $$$AssertTrue(maxLength <= 2000)
    Do $$$AssertTrue('$Data(scopes("historical")))
    Do $$$AssertTrue('$Data(scopes("unreviewed")))
    Set rows = $System.SQL.Execute("SELECT model_name,dimensions FROM Contest.HIPAAKnowledgeV1_Config")
    Do $$$AssertEquals(rows.%SQLCODE,0,rows.%Message)
    Do $$$AssertTrue(rows.%Next())
    Do $$$AssertEquals(rows.%Get("dimensions"),384)
    Do $$$AssertEquals(rows.%Get("model_name"),"AllMiniLML6V2")
    Set result = ##class(Contest.LocalKnowledge).Search("Remove medical record numbers and all elements of dates except year Safe Harbor de-identification identifiers")
    Set hits = result.%Get("value"), found = 0
    Do $$$AssertEquals(hits.%Size(),5)
    For i = 0:1:hits.%Size()-1 {
        Set hit = hits.%Get(i), metadata = hit.%Get("metadata")
        Do $$$AssertTrue(metadata.%Get("source_url") '= "")
        Do $$$AssertTrue(metadata.%Get("source_locator") '= "")
        If metadata.%Get("source_locator") = "45 CFR 164.514" Set found = 1
    }
    Do $$$AssertTrue(found,"Safe Harbor query retrieves 45 CFR 164.514 in top five")
}
}
