Class Contest.ExistingVectorStore Extends %AI.RAG.VectorStore.IRIS
{
/// The SDK's Build registers the store after this check without requiring reader DDL.
Method CreateTable(promotedFields As %DynamicArray = "") As %Status
{
    If '##class(Contest.KnowledgeService).ValidTable(..TableName) Quit $$$ERROR($$$GeneralError,"Invalid knowledge table")
    Set rs = $System.SQL.Execute("SELECT model_name,dimensions FROM "_..TableName_"_Config")
    If rs.%SQLCODE < 0 Quit $$$ERROR($$$GeneralError,rs.%Message)
    If 'rs.%Next() Quit $$$ERROR($$$GeneralError,"Missing vector configuration")
    If (rs.%Get("model_name") '= "AllMiniLML6V2") || (rs.%Get("dimensions") '= 384) Quit $$$ERROR($$$GeneralError,"Incompatible vector configuration")
    Quit $$$OK
}
}
