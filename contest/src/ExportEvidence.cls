Class Contest.ExportEvidence
{
ClassMethod Digest(value) As %String
{
    Quit ##class(Demo.Protocol).Hash($ZConvert(value.%ToJSON(),"O","UTF8"))
}

ClassMethod ValidateConfig(config As %DynamicObject)
{
    Do ##class(Contest.RiskReview).Object(config)
    If (config.%Size()'=3) || (config.%GetTypeOf("revision")'="number") || (config.revision<1) || (config.revision>100000) || ((config.revision\1)'=config.revision) Do ##class(Demo.Protocol).Fail("Exact bounded synthetic export configuration required")
    If '((config.%Get("recipient")="local-analytics-a")||(config.%Get("recipient")="local-analytics-b")) Do ##class(Demo.Protocol).Fail("Only local synthetic recipient identities are supported")
    If '((config.%Get("transform")="retain")||(config.%Get("transform")="remove_direct")||(config.%Get("transform")="year_only")) Do ##class(Demo.Protocol).Fail("Unknown synthetic transform")
}

ClassMethod SourceRows() As %DynamicArray [ Private ]
{
    Quit [{"name":"SYNTHETIC-NAME-A","mrn":"SYNTHETIC-MRN-A","email":"synthetic-a@example.invalid","birth_date":"2001-02-03","admission_date":"2026-10-01","region":"MA"},{"name":"SYNTHETIC-NAME-B","mrn":"SYNTHETIC-MRN-B","email":"synthetic-b@example.invalid","birth_date":"2002-03-04","admission_date":"2026-10-02","region":"CA"}]
}

ClassMethod Transform(rows As %DynamicArray, config As %DynamicObject) As %DynamicArray [ Private ]
{
    Set output=[].%FromJSON(rows.%ToJSON())
    For i=0:1:output.%Size()-1 {
        Set row=output.%Get(i)
        If config.transform'="retain" {
            For field="name","mrn","email" Do row.%Set(field,"")
        }
        If config.transform="year_only" {
            For field="birth_date","admission_date" Do row.%Set(field,$Extract(row.%Get(field),1,4))
        }
    }
    Quit output
}

ClassMethod Inspect(rows As %DynamicArray) As %DynamicObject
{
    If '$IsObject(rows) Do ##class(Demo.Protocol).Fail("Output rows required")
    If 'rows.%IsA("%DynamicArray") Do ##class(Demo.Protocol).Fail("Output row array required")
    If (rows.%Size()<1)||(rows.%Size()>100) Do ##class(Demo.Protocol).Fail("Bounded nonempty output required; empty output is not a clean check")
    Set counts={"name":0,"mrn":0,"email":0,"full_dates":0}, fields=["name","mrn","email","birth_date","admission_date","region"]
    For i=0:1:rows.%Size()-1 {
        Set row=rows.%Get(i)
        Do ##class(Contest.RiskReview).Object(row)
        If row.%Size()'=6 Do ##class(Demo.Protocol).Fail("Unclassified or missing output columns require a checker revision")
        For j=0:1:fields.%Size()-1 {
            Set field=fields.%Get(j)
            If (row.%GetTypeOf(field)'="string")||($Length(row.%Get(field))>128) Do ##class(Demo.Protocol).Fail("Unexpected output column or value type")
        }
        For field="name","mrn","email" {
            If row.%Get(field)'="" Do counts.%Set(field,counts.%Get(field)+1)
        }
        For field="birth_date","admission_date" {
            Set value=row.%Get(field)
            If value="" Continue
            If $Match(value,"^[0-9]{4}$") {
                If value<1 Do ##class(Demo.Protocol).Fail("Invalid year value")
                Continue
            }
            If '$Match(value,"^[0-9]{4}-[0-9]{2}-[0-9]{2}$") Do ##class(Demo.Protocol).Fail("Unsupported date representation; no clean substitute")
            Set day=$ZDATEH(value,3)
            If $ZDATE(day,3)'=value Do ##class(Demo.Protocol).Fail("Invalid calendar date")
            Do counts.%Set("full_dates",counts.%Get("full_dates")+1)
        }
        If '((row.region="MA")||(row.region="CA")) Do ##class(Demo.Protocol).Fail("Unexpected geography requires a checker revision")
    }
    Set present=(counts.name+counts.mrn+counts.email+counts.%Get("full_dates"))>0
    Quit {"checker":"allowed-output-columns-v1","row_count":(rows.%Size()),"columns":(fields),"identifier_counts":(counts),"checked_identifier_result":($Select(present:"present",1:"not_detected")),"complete_hipaa_check":false,"not_checked":["All other Safe Harbor conditions and actual knowledge","Expert determination applicability","Authorization, exceptions and approved release path","Current-law and independent legal applicability"]}
}

ClassMethod CheckAccess(write As %Boolean = 0) [ Private ]
{
    If $Namespace'="TRIAGE" Do ##class(Demo.Protocol).Fail("TRIAGE evidence namespace required")
    Set resource=$Select(write:"ContestMonitorDeploy",1:"ContestMonitorRead")
    If '$System.Security.Check(resource,"U") Do ##class(Demo.Protocol).Fail("Export evidence capability required")
}

ClassMethod Collect(key As %String, config As %DynamicObject) As %DynamicObject
{
    Do ..CheckAccess(1)
    Try {
        Do ..ValidateConfig(config)
        If '$Match(key,"^[A-Za-z0-9-]{1,80}$") Do ##class(Demo.Protocol).Fail("Bounded immutable evidence key required")
        Set configHash=..Digest(config)
        Lock +^ContestExportEvidence("lock",key):2
        If '$Test Do ##class(Demo.Protocol).Fail("Export evidence collection busy")
        Try {
            Set id=$Get(^ContestExportEvidence("request",key))
            If id'="" {
                Set record=..Load(id)
                If record.%Get("config_hash")'=configHash Do ##class(Demo.Protocol).Fail("Immutable evidence key scope conflict; create a new export")
            } Else {
                Set id="export-evidence-"_$System.Util.CreateGUID(), source=..SourceRows(), output=..Transform(source,config)
                Set inspection=..Inspect(output), now=##class(Demo.Protocol).Now()
                Set record={"id":(id),"collector":"local-synthetic-export-v1","generator":"synthetic-two-rows-v1","transformer":"synthetic-column-transform-v1","actor":($Username),"observed_at":(now),"scope":{"synthetic":true,"namespace":"TRIAGE","stage":"config_review","delivery_state":"not_sent","production_binding":"none"},"config":(config),"config_hash":(configHash),"source":(source),"source_hash":(..Digest(source)),"output":(output),"output_hash":(..Digest(output)),"inspection":(inspection)}
                Do record.%Set("record_hash",..Digest(record))
                TStart
                Try {
                    Set ^ContestExportEvidence("record",id)=record.%ToJSON(), ^ContestExportEvidence("request",key)=id
                    TCommit
                } Catch ex { TRollback 1 Throw ex }
                Do ##class(Contest.KnowledgeService).Audit("export.evidence.collected",id,"Local synthetic artifact only; no provider or delivery")
            }
            Set result=..Project(record)
        } Catch ex { Lock -^ContestExportEvidence("lock",key) Throw ex }
        Lock -^ContestExportEvidence("lock",key)
    } Catch ex {
        Do ##class(Contest.KnowledgeService).Audit("export.evidence.collect.failed","local-synthetic",ex.DisplayString())
        Throw ex
    }
    Quit result
}

ClassMethod Load(id As %String) As %DynamicObject [ Private ]
{
    If '$Match(id,"^export-evidence-[A-Za-z0-9-]+$") Do ##class(Demo.Protocol).Fail("Invalid export evidence identity")
    If '$Data(^ContestExportEvidence("record",id)) Do ##class(Demo.Protocol).Fail("Export evidence record not found; never substitute empty facts")
    Set record={}.%FromJSON(^ContestExportEvidence("record",id))
    Do ..ValidateConfig(record.config)
    Set scope={"synthetic":true,"namespace":"TRIAGE","stage":"config_review","delivery_state":"not_sent","production_binding":"none"}
    If (record.%Size()'=15)||(record.scope.%ToJSON()'=scope.%ToJSON()) Do ##class(Demo.Protocol).Fail("Unexpected evidence receipt shape or nonlocal scope")
    Set copy={}.%FromJSON(record.%ToJSON()), digest=copy.%Get("record_hash")
    Do copy.%Remove("record_hash")
    If (digest'=..Digest(copy))||(record.id'=id)||(record.collector'="local-synthetic-export-v1")||(record.generator'="synthetic-two-rows-v1")||(record.transformer'="synthetic-column-transform-v1") Do ##class(Demo.Protocol).Fail("Evidence receipt integrity or implementation version changed")
    If (record.%Get("config_hash")'=..Digest(record.config))||(record.%Get("source_hash")'=..Digest(record.source))||(record.%Get("output_hash")'=..Digest(record.output)) Do ##class(Demo.Protocol).Fail("Evidence source/config/output digest mismatch")
    If (record.source.%ToJSON()'=..SourceRows().%ToJSON())||(record.output.%ToJSON()'=..Transform(record.source,record.config).%ToJSON()) Do ##class(Demo.Protocol).Fail("Stored artifact does not match the pinned local generator and transform")
    Set inspected=..Inspect(record.output)
    If record.inspection.%ToJSON()'=inspected.%ToJSON() Do ##class(Demo.Protocol).Fail("Stored checks differ from actual artifact inspection")
    Quit record
}

ClassMethod Read(id As %String, configHash As %String, outputHash As %String) As %DynamicObject
{
    Do ..CheckAccess()
    Try {
        Set record=..Load(id)
        If (record.%Get("config_hash")'=configHash)||(record.%Get("output_hash")'=outputHash) Do ##class(Demo.Protocol).Fail("Evidence scope mismatch: configuration, recipient, revision or artifact changed")
        Set result=..Project(record)
    } Catch ex {
        Do ##class(Contest.KnowledgeService).Audit("export.evidence.read.failed","local-synthetic",ex.DisplayString())
        Throw ex
    }
    Quit result
}

ClassMethod Project(record As %DynamicObject) As %DynamicObject [ Private ]
{
    Set facts=[
        {"id":"output_check","kind":"observation","origin":"local_artifact_inspection","verification":"verified","text":("The actual materialized synthetic output was inspected by allowed-output-columns-v1: "_record.inspection.%ToJSON())},
        {"id":"export_scope","kind":"observation","origin":"local_export_configuration","verification":"verified","text":("The local synthetic configuration is "_record.config.%ToJSON()_". It identifies a transform and local recipient, NOT an approved legal release basis. This independent artifact was not sent and is not bound to a Production message.")},
        {"id":"basis_gap","kind":"missing_information","origin":"unconnected_business_records","verification":"unknown","text":"Authorization, expert determination, approved release path and applicable local release policy have not been collected. Their absence here does not establish that they do not exist. No clean legal conclusion is supported by this limited column inspection."}
    ]
    Set packet={"synthetic":true,"stage":"config_review","facts":(facts),"required_questions":[{"topic":"deidentification","fact_ids":["output_check","export_scope","basis_gap"],"question":"Assess only the observed output checks and explicit evidence gaps; do not invent an approved path or infer absent authorization/expert review. No actual patient values are needed."}]}, refs=[]
    For i=0:1:facts.%Size()-1 {
        Do refs.%Push({"fact_id":(facts.%Get(i).id),"record_id":(record.id),"record_hash":(record.%Get("record_hash")),"config_hash":(record.%Get("config_hash")),"output_hash":(record.%Get("output_hash")),"method":($Select(i=0:"allowed-output-columns-v1",i=1:"stored-local-config-v1",1:"explicit-unconnected-sources-v1"))})
    }
    Quit {"id":(record.id),"record_hash":(record.%Get("record_hash")),"config_hash":(record.%Get("config_hash")),"source_hash":(record.%Get("source_hash")),"output_hash":(record.%Get("output_hash")),"collector":(record.collector),"actor":(record.actor),"observed_at":(record.%Get("observed_at")),"scope":(record.scope),"config":(record.config),"inspection":(record.inspection),"business_basis":{"authorization":"not_collected","expert_determination":"not_collected","release_approval":"not_collected"},"fact_evidence":(refs),"packet":(packet),"execution":"not_executed","model_calls":0}
}
}
