Class Contest.KnowledgeService
{
ClassMethod ValidTable(table As %String) As %Boolean
{
    Quit ($Length(table) <= 64) && ((table = "Contest.HIPAAKnowledgeV1") || $Match(table,"^Contest[.]HIPAAIndex[0-9]+$"))
}

ClassMethod Now() As %Numeric
{
    Set time = $ZTIMESTAMP
    Quit $Piece(time,",",1)*86400+$Piece(time,",",2)
}

ClassMethod Audit(action As %String, object As %String, detail As %String = "")
{
    Set id = $Increment(^ContestPlatformAudit)
    Set ^ContestPlatformAudit(id) = {"actor":($Username),"action":(action),"object":(object),"detail":(detail),"time":($ZDATETIME($HOROLOG,3))}.%ToJSON()
}

ClassMethod Status() As %DynamicObject
{
    Set table = $Get(^ContestPlatform("activeTable"),"Contest.HIPAAKnowledgeV1")
    Set ready = ($Get(^ContestLocalKnowledge("state")) = "ready") || $Data(^ContestPlatform("activeTable"))
    Set count = 0
    If ready {
        If '..ValidTable(table) Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError,"Invalid active knowledge table"))
        Set rs = $System.SQL.Execute("SELECT COUNT(*) AS chunks FROM "_table)
        If rs.%SQLCODE < 0 Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError,rs.%Message))
        If rs.%Next() Set count = rs.%Get("chunks")
    }
    Set job = $Get(^ContestPlatform("latestJob"))
    Set result = {"ready":(ready),"table":(table),"documents":($Select(ready:715,1:0)),"chunks":(count),"dimensions":384,"model":"AllMiniLML6V2","latest_job":(job),"can_build":($System.Security.Check("ContestKnowledgeBuild","U")),"user":($Username),"corpus_id":($Get(^ContestPlatform("corpus"))),"index_version":($Get(^ContestPlatform("activeVersion"),"baseline-v1"))}
    Quit result
}

ClassMethod Search(query As %String) As %DynamicObject
{
    Set status = ..Status()
    If 'status.ready Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError,"Knowledge index is not ready"))
    Quit ..SearchVersion(query,status.table,status.%Get("index_version"))
}

ClassMethod ValidateVersion(table As %String, version As %String)
{
    If '..ValidTable(table) Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError,"Invalid pinned knowledge table"))
    If version = "baseline-v1" {
        If table '= "Contest.HIPAAKnowledgeV1" Do ##class(Demo.Protocol).Fail("Pinned baseline mismatch")
    } Else {
        If '$Match(version,"^[0-9]+$") Do ##class(Demo.Protocol).Fail("Unknown pinned knowledge version")
        If ($Get(^ContestKnowledgeJobs(version,"state")) '= "completed") || ($Get(^ContestKnowledgeJobs(version,"table")) '= table) Do ##class(Demo.Protocol).Fail("Pinned index is not a completed build")
    }
}

ClassMethod SearchVersion(query As %String, table As %String, version As %String) As %DynamicObject
{
    Do ..ValidateVersion(table,version)
    Set embedding = ##class(%AI.RAG.Embedding.FastEmbed).Create()
    Set store = ##class(Contest.ExistingVectorStore).%New()
    Set store.TableName = table, store.Dimensions = 384, store.ModelName = "AllMiniLML6V2"
    Set sc = store.Build() $$$ThrowOnError(sc)
    Set kb = ##class(%AI.RAG.KnowledgeBase).%New("hipaa_platform","Dated HIPAA reference evidence, not legal certification")
    Set kb.TopK = 5
    Set sc = kb.Build(embedding,store) $$$ThrowOnError(sc)
    Set manager = ##class(%AI.ToolMgr).%New()
    Set sc = kb.AddToManager(manager) $$$ThrowOnError(sc)
    Set result = manager.ExecuteTool("hipaa_platform",{"query":(query)})
    Do result.%Set("index_version",version)
    Do ..Audit("knowledge.search",table,"Query omitted from audit; public-knowledge retrieval")
    Quit result
}

ClassMethod JobStatus(id As %String) As %DynamicObject
{
    If '$Match(id,"^[0-9]+$") || '$Data(^ContestKnowledgeJobs(id,"state")) Quit ""
    Set state = ^ContestKnowledgeJobs(id,"state")
    If ((state = "running") || (state = "queued")) && ((..Now()-^ContestKnowledgeJobs(id,"heartbeat")) > 300) {
        Set state = "interrupted"
    }
    Quit {"id":(id),"state":(state),"documents":($Get(^ContestKnowledgeJobs(id,"documents"))),"expected":715,"stage":($Get(^ContestKnowledgeJobs(id,"stage"))),"error":($Get(^ContestKnowledgeJobs(id,"error"))),"started":($Get(^ContestKnowledgeJobs(id,"started"))),"completed":($Get(^ContestKnowledgeJobs(id,"completed"))),"table":($Get(^ContestKnowledgeJobs(id,"table")))}
}

ClassMethod StartBuild() As %String
{
    Lock +^ContestPlatform("schedule"):2
    If '$Test Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError,"Build scheduler is busy"))
    Try {
        Set latest = $Get(^ContestPlatform("latestJob"))
        If latest '= "" {
            Set previous = ..JobStatus(latest)
            If $IsObject(previous),((previous.state = "queued") || (previous.state = "running")) Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError,"A build is already active"))
        }
        Set id = $Increment(^ContestPlatform("sequence"))
        Set ^ContestKnowledgeJobs(id,"state") = "queued", ^ContestKnowledgeJobs(id,"heartbeat") = ..Now()
        Set ^ContestKnowledgeJobs(id,"started") = $ZDATETIME($HOROLOG,3)
        Set ^ContestKnowledgeJobs(id,"actor") = $Username
        Set ^ContestPlatform("latestJob") = id
        Do ..Audit("knowledge.build.requested",id)
        Job ##class(Contest.KnowledgeService).Build(id)::5
        If '$Test Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError,"Could not launch build worker"))
    } Catch ex {
        If $Get(id) '= "" {
            Set ^ContestKnowledgeJobs(id,"state") = "failed", ^ContestKnowledgeJobs(id,"error") = "Worker launch failed"
        }
        Lock -^ContestPlatform("schedule")
        Throw ex
    }
    Lock -^ContestPlatform("schedule")
    Quit id
}

ClassMethod Build(id As %String)
{
    Lock +^ContestPlatform("build"):0
    If '$Test {
        Set ^ContestKnowledgeJobs(id,"state") = "failed", ^ContestKnowledgeJobs(id,"error") = "Another build worker holds the lock"
        Quit
    }
    Try {
        Set ^ContestKnowledgeJobs(id,"state") = "running", ^ContestKnowledgeJobs(id,"stage") = "validating"
        Set ^ContestKnowledgeJobs(id,"heartbeat") = ..Now()
        Set table = "Contest.HIPAAIndex"_id
        Set ^ContestKnowledgeJobs(id,"table") = table
        Set binary = ##class(%Stream.FileBinary).%New()
        Set sc = binary.LinkToFile("/contest/data/knowledge/platform-default.jsonl") $$$ThrowOnError(sc)
        Set digest = $System.Encryption.SHAHashStream(256,binary,.sc) $$$ThrowOnError(sc)
        Set fingerprint = ""
        For byte = 1:1:$Length(digest) Set fingerprint = fingerprint_$ZConvert($Translate($Justify($ZHex($Ascii(digest,byte)),2)," ","0"),"L")
        Do binary.%Close()
        If fingerprint '= $Get(^ContestPlatform("corpus")) Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError,"Source fingerprint changed; refusing activation"))
        Set ^ContestKnowledgeJobs(id,"corpus") = fingerprint
        Set stream = ##class(%Stream.FileCharacter).%New(), stream.TranslateTable = "UTF8"
        Set sc = stream.LinkToFile("/contest/data/knowledge/platform-default.jsonl") $$$ThrowOnError(sc)
        Set embedding = ##class(%AI.RAG.Embedding.FastEmbed).Create(), store = ##class(%AI.RAG.VectorStore.IRIS).%New()
        Set store.TableName = table, store.Dimensions = 384, store.ModelName = "AllMiniLML6V2"
        Set sc = store.Build() $$$ThrowOnError(sc)
        Set kb = ##class(%AI.RAG.KnowledgeBase).%New("hipaa_build","Public HIPAA source indexing")
        Set sc = kb.Build(embedding,store) $$$ThrowOnError(sc)
        Set count = 0, ^ContestKnowledgeJobs(id,"stage") = "embedding"
        While 'stream.AtEnd {
            Set line = stream.ReadLine(2000000,.sc) $$$ThrowOnError(sc)
            If line = "" Continue
            Set record = {}.%FromJSON(line)
            Set sc = ##class(Contest.LocalKnowledge).IndexRecord(kb,record) $$$ThrowOnError(sc)
            Set count = count+1, ^ContestKnowledgeJobs(id,"documents") = count
            Set ^ContestKnowledgeJobs(id,"heartbeat") = ..Now()
        }
        Do stream.%Close()
        If count '= 715 Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError,"Unexpected source record count"))
        Set ^ContestKnowledgeJobs(id,"stage") = "verifying"
        Set rs = $System.SQL.Execute("SELECT COUNT(*) AS chunks FROM "_table)
        If rs.%SQLCODE < 0 Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError,rs.%Message))
        If 'rs.%Next() Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError,"Missing chunk count"))
        If rs.%Get("chunks") '= 1785 Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError,"Unexpected embedded chunk count"))
        Set manager = ##class(%AI.ToolMgr).%New()
        Set sc = kb.AddToManager(manager) $$$ThrowOnError(sc)
        Set hits = manager.ExecuteTool("hipaa_build",{"query":"Remove medical record numbers and all elements of dates except year Safe Harbor de-identification identifiers"})
        If hits.%Get("value").%Size() = 0 Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError,"Retrieval verification returned no evidence"))
        Set rs = $System.SQL.Execute("GRANT SELECT ON "_table_" TO ContestKnowledgeReader,ContestKnowledgeBuilder")
        If rs.%SQLCODE < 0 Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError,rs.%Message))
        Set rs = $System.SQL.Execute("GRANT SELECT ON "_table_"_Config TO ContestKnowledgeReader,ContestKnowledgeBuilder")
        If rs.%SQLCODE < 0 Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError,rs.%Message))
        TStart
        Set ^ContestPlatform("activeTable") = table, ^ContestPlatform("activeVersion") = id
        Set ^ContestKnowledgeJobs(id,"state") = "completed", ^ContestKnowledgeJobs(id,"stage") = "active"
        Set ^ContestKnowledgeJobs(id,"completed") = $ZDATETIME($HOROLOG,3)
        Set ^ContestKnowledgeJobs(id,"error") = ""
        Do ..Audit("knowledge.build.activated",id,table)
        TCommit
    } Catch ex {
        If $TLevel TRollback
        Set ^ContestKnowledgeJobs(id,"state") = "failed", ^ContestKnowledgeJobs(id,"stage") = "failed"
        Set ^ContestKnowledgeJobs(id,"error") = "Build failed; inspect the protected server audit."
        Do ..Audit("knowledge.build.failed",id,ex.DisplayString())
    }
    Lock -^ContestPlatform("build")
}
}
