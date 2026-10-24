Class Contest.KnowledgeTests Extends %UnitTest.TestProduction
{
Parameter PRODUCTION = "Contest.Production";

Method TestControl() As %Status
{
    Quit $$$OK
}

Method TestQueryValidation()
{
    Do $$$AssertTrue(##class(Contest.KnowledgeAPI).ValidQuery({"query":"Safe Harbor identifiers"}))
    Do $$$AssertTrue('##class(Contest.KnowledgeAPI).ValidQuery({"query":""}))
    Do $$$AssertTrue('##class(Contest.KnowledgeAPI).ValidQuery({"query":12}))
    Do $$$AssertTrue('##class(Contest.KnowledgeAPI).ValidQuery({"query":"   "}))
    Do $$$AssertTrue('##class(Contest.KnowledgeAPI).ValidQuery({"query":"safe","scope":"historical"}))
}

Method TestTableBoundary()
{
    Do $$$AssertTrue(##class(Contest.KnowledgeService).ValidTable("Contest.HIPAAKnowledgeV1"))
    Do $$$AssertTrue(##class(Contest.KnowledgeService).ValidTable("Contest.HIPAAIndex42"))
    Do $$$AssertTrue('##class(Contest.KnowledgeService).ValidTable("Contest.Case"))
    Do $$$AssertTrue('##class(Contest.KnowledgeService).ValidTable("Contest.HIPAAIndex1;DROP TABLE x"))
}
}
