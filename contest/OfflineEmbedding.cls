Class User.OfflineEmbedding
{
ClassMethod Run()
{
    Try {
        If '##class(Config.Namespaces).Exists("TRIAGE") {
            Set directory = "/tmp/offline-embedding-triage/"
            If '##class(%File).CreateDirectoryChain(directory) Throw ##class(%Exception.General).%New("Cannot create offline test directory")
            Set sc = ##class(SYS.Database).CreateDatabase(directory) $$$ThrowOnError(sc)
            Set p("Directory") = directory
            Set sc = ##class(Config.Databases).Create("TRIAGE",.p) $$$ThrowOnError(sc)
            Kill p
            Set p("Globals") = "TRIAGE", p("Routines") = "TRIAGE"
            Set sc = ##class(Config.Namespaces).Create("TRIAGE",.p) $$$ThrowOnError(sc)
            Set sc = ##class(%EnsembleMgr).EnableNamespace("TRIAGE") $$$ThrowOnError(sc)
        }
        ZN "TRIAGE"
        Set ^UnitTestRoot = "/tests"
        Set sc = $System.OBJ.Load("/sources/LocalKnowledge.cls","ck") $$$ThrowOnError(sc)
        Set sc = $System.OBJ.Load("/tests/EmbeddingTests.cls","ck") $$$ThrowOnError(sc)
        Set sc = ##class(Contest.EmbeddingTests).Run() $$$ThrowOnError(sc)
        Set sc = ##class(Contest.LocalKnowledge).ImportFile("/hipaa.jsonl") $$$ThrowOnError(sc)
        Set sc = $System.OBJ.Load("/tests/EmbeddingStoreTests.cls","ck") $$$ThrowOnError(sc)
        Set sc = ##class(Contest.EmbeddingStoreTests).Run() $$$ThrowOnError(sc)
        Write "OFFLINE_HIPAA_DOCUMENTS=",^ContestLocalKnowledge("documents"),!
        Write "OFFLINE_EMBEDDING_COMPLETED",!
    } Catch ex {
        Write "OFFLINE_EMBEDDING_FAILED=",ex.DisplayString(),!
    }
}
}
