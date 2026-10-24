Class Contest.ExportEvidenceTests Extends %UnitTest.TestProduction
{
Parameter PRODUCTION = "Contest.Production";
Method TestControl() As %Status { Quit $$$OK }

Method Config(transform As %String = "retain") As %DynamicObject
{
    Quit {"revision":1,"recipient":"local-analytics-a","transform":(transform)}
}

Method TestActualRowsNotScenarioDetermineInspection()
{
    Set rows=[{"name":"SYNTHETIC-NAME","mrn":"","email":"synthetic@example.invalid","birth_date":"2001-02-03","admission_date":"","region":"MA"}]
    Set check=##class(Contest.ExportEvidence).Inspect(rows)
    Set counts=check.%Get("identifier_counts")
    Do $$$AssertEquals(check.%Get("row_count"),1)
    Do $$$AssertEquals(counts.name,1)
    Do $$$AssertEquals(counts.mrn,0)
    Do $$$AssertEquals(counts.email,1)
    Do $$$AssertEquals(counts.%Get("full_dates"),1)
    Do rows.%Get(0).%Set("name",""), rows.%Get(0).%Set("email",""), rows.%Get(0).%Set("birth_date","2001")
    Set check=##class(Contest.ExportEvidence).Inspect(rows)
    Do $$$AssertEquals(check.%Get("checked_identifier_result"),"not_detected")
    Do $$$AssertEquals(check.%Get("identifier_counts").%Get("full_dates"),0)
    Do $$$AssertTrue(check.%Get("complete_hipaa_check")=0)
}

Method TestUnknownColumnsAndMalformedDatesDoNotPass()
{
    For variant="unknown","date","type","empty" {
        Set rows=[{"name":"","mrn":"","email":"","birth_date":"2001","admission_date":"","region":"MA"}]
        If variant="unknown" Do rows.%Get(0).%Set("opaque","unclassified data")
        If variant="date" Do rows.%Get(0).%Set("birth_date","not-a-date")
        If variant="type" Do rows.%Get(0).%Set("mrn",123)
        If variant="empty" Set rows=[]
        Set rejected=0
        Try { Set check=##class(Contest.ExportEvidence).Inspect(rows) } Catch ex { Set rejected=1 }
        Do $$$AssertTrue(rejected,variant)
    }
    Set rejected=0
    Try { Set check=##class(Contest.ExportEvidence).Inspect([{"name":"","mrn":"","email":"","birth_date":"2026-02-31","admission_date":"","region":"MA"}]) } Catch ex { Set rejected=1 }
    Do $$$AssertTrue(rejected,"Invalid calendar dates cannot be counted as valid observations")
}

Method TestConfigCannotAssertApprovalOrAcceptArbitraryData()
{
    For variant="approval","recipient","transform","revision" {
        Set config=..Config()
        If variant="approval" Do config.%Set("approved",1,"boolean")
        If variant="recipient" Set config.recipient="external-endpoint"
        If variant="transform" Set config.transform="arbitrary-code"
        If variant="revision" Set config.revision=0
        Set rejected=0
        Try { Do ##class(Contest.ExportEvidence).ValidateConfig(config) } Catch ex { Set rejected=1 }
        Do $$$AssertTrue(rejected,variant)
    }
}

Method TestPermissionBoundary()
{
    If $System.Security.Check("ContestMonitorDeploy","U") {
        Do $$$AssertTrue(1,"Authorized durable tests run separately below")
    } Else {
        Set rejected=0
        Try { Set value=##class(Contest.ExportEvidence).Collect("unit-denied",..Config()) } Catch ex { Set rejected=1 }
        Do $$$AssertTrue(rejected)
    }
}

Method TestDurableTransformScopeAndProjection()
{
    If '$System.Security.Check("ContestMonitorDeploy","U") Quit
    TStart
    Try {
        Set key="unit-evidence-"_$System.Util.CreateGUID()
        For transform="retain","remove_direct","year_only" {
            Set config=..Config(transform), requestKey=key_"-"_$Translate(transform,"_","-"), value=##class(Contest.ExportEvidence).Collect(requestKey,config)
            Set check=value.inspection, identifiers=check.%Get("identifier_counts"), basis=value.%Get("business_basis")
            If transform="retain" Do $$$AssertEquals(identifiers.mrn,2)
            If transform="remove_direct" Do $$$AssertEquals(identifiers.mrn,0)
            If transform="year_only" Do $$$AssertEquals(check.%Get("checked_identifier_result"),"not_detected")
            Do $$$AssertEquals(identifiers.%Get("full_dates"),$Select(transform="year_only":0,1:4))
            Do $$$AssertEquals(value.scope.%Get("delivery_state"),"not_sent")
            Do $$$AssertEquals(basis.authorization,"not_collected")
            Do $$$AssertEquals(basis.%Get("expert_determination"),"not_collected")
            Do $$$AssertEquals(basis.%Get("release_approval"),"not_collected")
            Do $$$AssertTrue('value.%IsDefined("output"))
            Do $$$AssertTrue('value.%IsDefined("source"))
            Do $$$AssertTrue(value.%ToJSON()'["SYNTHETIC-NAME")
            Do $$$AssertTrue(value.%ToJSON()'["@example.invalid")
            Do $$$AssertTrue(value.%ToJSON()'["2001-02-03")
            Do ##class(Contest.RiskReview).ValidatePacket(value.packet)
            Set replay=##class(Contest.ExportEvidence).Collect(requestKey,config)
            Do $$$AssertEquals(value.%ToJSON(),replay.%ToJSON())
            Set read=##class(Contest.ExportEvidence).Read(value.id,value.%Get("config_hash"),value.%Get("output_hash"))
            Do $$$AssertEquals(value.%ToJSON(),read.%ToJSON())
        }
    } Catch ex { TRollback 1 Throw ex }
    TRollback 1
}

Method TestStaleScopeAndImmutableKeyFail()
{
    If '$System.Security.Check("ContestMonitorDeploy","U") Quit
    TStart
    Try {
        Set key="unit-scope-"_$System.Util.CreateGUID(), config=..Config()
        Set value=##class(Contest.ExportEvidence).Collect(key,config)
        For variant="recipient","revision","output" {
            Set changed=..Config(), rejected=0, outputHash=value.%Get("output_hash")
            If variant="recipient" Set changed.recipient="local-analytics-b"
            If variant="revision" Set changed.revision=2
            If variant="output" Set outputHash="stale"
            Try { Set ignored=##class(Contest.ExportEvidence).Read(value.id,##class(Contest.ExportEvidence).Digest(changed),outputHash) } Catch ex { Set rejected=1 }
            Do $$$AssertTrue(rejected,variant)
        }
        Set config.revision=2, rejected=0
        Try { Set ignored=##class(Contest.ExportEvidence).Collect(key,config) } Catch ex { Set rejected=1 }
        Do $$$AssertTrue(rejected,"An immutable key cannot be rebound to a new revision")
    } Catch ex { TRollback 1 Throw ex }
    TRollback 1
}

Method TestTamperingFailsWithoutSubstituteEvidence()
{
    If '$System.Security.Check("ContestMonitorDeploy","U") Quit
    TStart
    Try {
        Set key="unit-tamper-"_$System.Util.CreateGUID(), value=##class(Contest.ExportEvidence).Collect(key,..Config())
        Set original=^ContestExportEvidence("record",value.id)
        For variant="output","inspection","actor","digest","rehashed-output","rehashed-inspection","rehashed-scope" {
            Set record={}.%FromJSON(original)
            If variant="output" Set record.output.%Get(0).mrn="modified"
            If variant="inspection" {
                Set inspection=record.inspection, identifiers=inspection.%Get("identifier_counts"), identifiers.mrn=0
            }
            If variant="actor" Set record.actor="different"
            If variant="digest" Do record.%Set("output_hash","modified")
            If variant="rehashed-output" {
                Set record.output.%Get(0).mrn="modified"
                Do record.%Set("output_hash",##class(Contest.ExportEvidence).Digest(record.output))
            }
            If variant="rehashed-inspection" {
                Set identifiers=record.inspection.%Get("identifier_counts"), identifiers.mrn=0
            }
            If variant="rehashed-scope" Do record.scope.%Set("synthetic",0,"boolean")
            If variant["rehashed" {
                Do record.%Remove("record_hash")
                Do record.%Set("record_hash",##class(Contest.ExportEvidence).Digest(record))
            }
            Set ^ContestExportEvidence("record",value.id)=record.%ToJSON(), rejected=0
            Try { Set ignored=##class(Contest.ExportEvidence).Read(value.id,value.%Get("config_hash"),value.%Get("output_hash")) } Catch ex { Set rejected=1 }
            Do $$$AssertTrue(rejected,variant)
        }
    } Catch ex { TRollback 1 Throw ex }
    TRollback 1
}
}
