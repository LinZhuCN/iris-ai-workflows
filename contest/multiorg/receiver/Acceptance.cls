Class MultiOrg.Receiver.Acceptance Extends %RegisteredObject
{
ClassMethod Run(branches As %String = "sql,rest,hl7") [ Language = python ]
{
    import sys
    sys.path.insert(0, "/contest/multiorg/receiver")
    import acceptance
    acceptance.run(branches.split(","))
}
}
