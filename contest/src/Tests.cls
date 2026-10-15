Class Contest.Tests
{
ClassMethod Assert(condition As %Boolean, message As %String)
{
    If 'condition Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError,message))
    Write "PASS: ",message,!
}

ClassMethod Check(externalId As %String, payload As %String, outcome As %String) As %Integer
{
    Set sc = ##class(Contest.Setup).Submit(externalId,payload,.caseId)
    $$$ThrowOnError(sc)
    Set record = ##class(Contest.Case).%OpenId(caseId)
    Do ..Assert(record.Outcome = outcome,externalId_" outcome="_outcome)
    Set rs = ##class(%SQL.Statement).%ExecDirect(,"SELECT COUNT(*) AS N FROM Contest.Destination WHERE CaseId=?",caseId)
    If rs.%SQLCODE < 0 Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError,rs.%Message))
    Do rs.%Next()
    Do ..Assert(rs.%Get("N") = 1,externalId_" has exactly one persisted destination")
    Set rs = ##class(%SQL.Statement).%ExecDirect(,"SELECT COUNT(*) AS N FROM Contest.Event WHERE CaseId=? AND Stage='tool_facts'",caseId)
    If rs.%SQLCODE < 0 Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError,rs.%Message))
    Do rs.%Next()
    Do ..Assert(rs.%Get("N") = 1,externalId_" used the real AI Hub fact tool")
    Do ..Assert(record.AgentSession '= "",externalId_" has an AI Hub session ID")
    Do ..Assert(record.Usage '= "",externalId_" persists provider-reported usage")
    Quit caseId
}

ClassMethod Fail(externalId As %String, payload As %String, expected As %String) As %Status
{
    Set sc = ##class(Contest.Setup).Submit(externalId,payload,.id)
    Do ..Assert($SYSTEM.Status.IsError(sc),externalId_" explicitly fails")
    Set record = ##class(Contest.Case).OpenByExternalId(externalId)
    Do ..Assert($IsObject(record),externalId_" has a case record")
    Do ..Assert(record.Outcome = "failed",externalId_" has persisted failed outcome")
    Do ..Assert(record.Error [ expected,externalId_" reports expected error")
    Set rs = ##class(%SQL.Statement).%ExecDirect(,"SELECT COUNT(*) AS N FROM Contest.Destination WHERE CaseId=?",record.%Id())
    If rs.%SQLCODE < 0 Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError,rs.%Message))
    Do rs.%Next()
    Do ..Assert(rs.%Get("N") = 0,externalId_" produced no destination side effect")
    Set sc = ##class(Contest.Setup).Submit(externalId,payload,.id)
    Do ..Assert($SYSTEM.Status.IsError(sc),externalId_" cannot be automatically replayed")
    Quit $$$OK
}

ClassMethod Run(expectedMode As %String = "mock") As %Status
{
    Set sc = $$$OK
    Try {
        Do ..Assert($Namespace = "TRIAGE","tests execute in TRIAGE")
        Do ..Assert($System.Util.GetEnviron("TRIAGE_MODE") = expectedMode,"provider mode matches requested test mode")
        Set prefix = "test-"_$Translate($ZTIMESTAMP,",.","---")_"-"
        Set normal = "{""reference"":""synthetic-1"",""code"":""OBS"",""value"":""42""}"
        Set missing = "{""reference"":""synthetic-2"",""code"":""OBS""}"
        Set unknown = "{""reference"":""synthetic-3"",""code"":""OTHER"",""value"":""42""}"
        Set delivered = ..Check(prefix_"deliver",normal,"delivered")
        Set isolated = ..Check(prefix_"quarantine",missing,"quarantined")
        Set review = ..Check(prefix_"review",unknown,"pending_review")
        Set duplicate = ..Check(prefix_"deliver",normal,"delivered")
        Do ..Assert(delivered = duplicate,"duplicate returns original case without another model call or delivery")
        Set sc = ##class(Contest.Setup).Submit(prefix_"deliver",missing,.id)
        Do ..Assert($SYSTEM.Status.IsError(sc),"conflicting duplicate is rejected")
        Set sc = ##class(Contest.Setup).Submit(prefix_"invalid","not JSON",.id)
        Do ..Assert($SYSTEM.Status.IsError(sc),"invalid payload explicitly fails")
        Set record = ##class(Contest.Case).OpenByExternalId(prefix_"invalid")
        Do ..Assert(record.Outcome = "failed","invalid payload has a persisted failed outcome")
        Set sc = $$$OK
        Write "TRIAGE_TESTS_PASSED",!
    } Catch ex {
        Write "TRIAGE_TESTS_FAILED: ",ex.DisplayString(),!
        Set sc = ex.AsStatus()
    }
    Quit sc
}

ClassMethod Snapshot() As %String
{
    Set snapshot = ##class(%DynamicArray).%New()
    For query = "SELECT ID,ExternalId,Decision,Policy,Outcome,Error,AgentSession,Usage FROM Contest.""Case"" ORDER BY ID","SELECT ID,CaseId,Queue,Payload FROM Contest.Destination ORDER BY ID","SELECT ID,CaseId,Stage,Detail FROM Contest.Event ORDER BY ID" {
        Set rs = ##class(%SQL.Statement).%ExecDirect(,query)
        If rs.%SQLCODE < 0 Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError,rs.%Message))
        Set rows = ##class(%DynamicArray).%New()
        While rs.%Next() {
            Set row = ##class(%DynamicArray).%New()
            For col = 1:1:rs.%ResultColumnCount Do row.%Push(rs.%GetData(col))
            Do rows.%Push(row)
        }
        Do snapshot.%Push(rows)
    }
    Quit snapshot.%ToJSON()
}

ClassMethod Recheck() As %Status
{
    Set sc = $$$OK
    Try {
        Set rs = ##class(%SQL.Statement).%ExecDirect(,"SELECT ID,ExternalId,Payload,Outcome FROM Contest.""Case"" WHERE Outcome IN ('delivered','quarantined','pending_review')")
        If rs.%SQLCODE < 0 Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError,rs.%Message))
        Set count = 0
        While rs.%Next() {
            Set id = ..Check(rs.%Get("ExternalId"),rs.%Get("Payload"),rs.%Get("Outcome"))
            Do ..Assert(id = rs.%Get("ID"),"restart duplicate retains original case")
            Set count = count + 1
        }
        Do ..Assert(count >= 3,"restart verified all three completed routes")
        Write "RESTART_DUPLICATES_VERIFIED",!
    } Catch ex {
        Set sc = ex.AsStatus()
        Write "RESTART_DUPLICATES_FAILED: ",ex.DisplayString(),!
    }
    Quit sc
}
}
