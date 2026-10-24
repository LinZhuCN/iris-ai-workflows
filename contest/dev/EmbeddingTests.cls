Class Contest.EmbeddingTests Extends %UnitTest.TestProduction
{
Parameter PRODUCTION = "Contest.Production";

Method TestControl() As %Status
{
    Quit $$$OK
}

Method TestLocalEmbedding()
{
    Set embedding = ##class(%AI.RAG.Embedding.FastEmbed).Create()
    Do $$$AssertEquals(embedding.Dimensions,384)
    Do $$$AssertEquals(embedding.ModelName,"AllMiniLML6V2")
}
}
