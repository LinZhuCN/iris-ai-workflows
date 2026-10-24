Class Contest.Aggregation.Data
{
ClassMethod Fixture() As %DynamicObject
{
    Quit {"patients":[{"ID":"agg-p1","MRN":"SYNTHETIC-MRN-A","FamilyName":"SYNTHETIC-A","GivenName":"ALPHA","BirthDate":"1980-01-02"},{"ID":"agg-p2","MRN":"SYNTHETIC-MRN-B","FamilyName":"SYNTHETIC-B","GivenName":"BETA","BirthDate":"1990-03-04"}],"encounters":[{"ID":"agg-e1","PatientID":"agg-p1","Status":"finished","ClassCode":"AMB","StartDate":"2026-10-01"},{"ID":"agg-e2","PatientID":"agg-p2","Status":"finished","ClassCode":"AMB","StartDate":"2026-10-02"}],"diagnoses":[{"ID":"agg-c1","PatientID":"agg-p1","EncounterID":"agg-e1","Code":"demo-condition-a","Display":"Synthetic condition A"},{"ID":"agg-c2","PatientID":"agg-p2","EncounterID":"agg-e2","Code":"demo-condition-b","Display":"Synthetic condition B"}],"medications":[{"ID":"agg-m1","PatientID":"agg-p1","EncounterID":"agg-e1","Code":"demo-drug-a","Display":"Synthetic medication A"},{"ID":"agg-m2","PatientID":"agg-p2","EncounterID":"agg-e2","Code":"demo-drug-b","Display":"Synthetic medication B"}]}
}

ClassMethod Columns(kind As %String) As %String
{
    Do ..Table(kind)
    Quit $Select(kind="patients":"ID,MRN,FamilyName,GivenName,BirthDate",kind="encounters":"ID,PatientID,Status,ClassCode,StartDate",1:"ID,PatientID,EncounterID,Code,Display")
}

ClassMethod Table(kind As %String) As %String
{
    If (kind'="patients")&&(kind'="encounters")&&(kind'="diagnoses")&&(kind'="medications") Do ##class(Demo.Protocol).Fail("Unknown aggregation source kind")
    Quit $Select(kind="patients":"SQLUser.AggPatient",kind="encounters":"SQLUser.AggEncounter",kind="diagnoses":"SQLUser.AggDiagnosis",1:"SQLUser.AggMedicationOrder")
}

ClassMethod Check(result)
{
    If result.%SQLCODE<0 Do ##class(Demo.Protocol).Fail("Aggregation SQL failed: "_result.%Message)
}

ClassMethod EnsureAndSeed()
{
    If $Namespace'="PIPELINE" Do ##class(Demo.Protocol).Fail("Only isolated PIPELINE may own aggregation SQL")
    Set fixture=..Fixture()
    For kind="patients","encounters","diagnoses","medications" {
        Set table=..Table(kind), columns=..Columns(kind)
        Set result=##class(%SQL.Statement).%ExecDirect(,"SELECT COUNT(*) AS N FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA='SQLUser' AND TABLE_NAME=?",$Piece(table,".",2))
        Do ..Check(result) Set next=result.%Next()
        If result.%Get("N")=0 {
            Set ddl="CREATE TABLE "_table_" (ID VARCHAR(64) PRIMARY KEY"
            For j=2:1:$Length(columns,",") Set ddl=ddl_", "_$Piece(columns,",",j)_" VARCHAR(128) NOT NULL"
            Set result=##class(%SQL.Statement).%ExecDirect(,ddl_")") Do ..Check(result)
        }
    }
    TStart
    Try {
        For kind="patients","encounters","diagnoses","medications" {
            Set rows=fixture.%Get(kind), table=..Table(kind), columns=..Columns(kind)
            For i=0:1:rows.%Size()-1 {
                Set row=rows.%Get(i), result=##class(%SQL.Statement).%ExecDirect(,"SELECT * FROM "_table_" WHERE ID=?",row.ID)
                Do ..Check(result)
                If result.%Next() {
                    For j=1:1:5 {
                        Set column=$Piece(columns,",",j)
                        If result.%Get(column)'=row.%Get(column) Do ##class(Demo.Protocol).Fail("Seed identity conflict; existing rows are never overwritten")
                    }
                } Else {
                    Set result=##class(%SQL.Statement).%ExecDirect(,"INSERT INTO "_table_" ("_columns_") VALUES (?,?,?,?,?)",row.%Get($Piece(columns,",",1)),row.%Get($Piece(columns,",",2)),row.%Get($Piece(columns,",",3)),row.%Get($Piece(columns,",",4)),row.%Get($Piece(columns,",",5)))
                    Do ..Check(result)
                }
            }
        }
        TCommit
    } Catch ex { TRollback 1 Throw ex }
}

ClassMethod Snapshot() As %DynamicObject
{
    If $Namespace'="PIPELINE" Do ##class(Demo.Protocol).Fail("PIPELINE SQL source required")
    Set source={}
    TStart
    Try {
        For kind="patients","encounters","diagnoses","medications" {
            Set columns=..Columns(kind), rows=[]
            Set result=##class(%SQL.Statement).%ExecDirect(,"SELECT "_columns_" FROM "_..Table(kind)_" WHERE ID IN (?,?) ORDER BY ID",$Select(kind="patients":"agg-p1",kind="encounters":"agg-e1",kind="diagnoses":"agg-c1",1:"agg-m1"),$Select(kind="patients":"agg-p2",kind="encounters":"agg-e2",kind="diagnoses":"agg-c2",1:"agg-m2"))
            Do ..Check(result)
            While result.%Next() {
                Set row={}
                For j=1:1:5 { Set column=$Piece(columns,",",j) Do row.%Set(column,result.%Get(column),"string") }
                Do rows.%Push(row)
            }
            If rows.%Size()'=2 Do ##class(Demo.Protocol).Fail("Incomplete pinned synthetic source cohort")
            Do source.%Set(kind,rows)
        }
        TCommit
    } Catch ex { TRollback 1 Throw ex }
    Quit source
}
}
