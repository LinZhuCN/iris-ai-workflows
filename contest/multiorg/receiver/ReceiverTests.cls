Include %outUnitTest

Class Contest.MultiReceiverTests Extends %UnitTest.TestProduction
{
Parameter PRODUCTION = "Contest.Production";

Method TestControl() As %Status
{
    quit 1
}

Method TestDeliveryIdentifiers()
{
    do $$$AssertEquals(..Contract("test_delivery_id_bound"),1,"Bound and validate delivery identifiers")
}

Method TestExactPayloadHash()
{
    do $$$AssertEquals(..Contract("test_hash_is_exact_utf8"),1,"Hash exact UTF-8 bytes")
}

Method TestACKCorrelation()
{
    do $$$AssertEquals(..Contract("test_ack_requires_matching_control_id"),1,"Reject wrong/negative ACK")
}

Method TestPayloadShape()
{
    do $$$AssertEquals(..Contract("test_sql_shape_and_hl7_control_validation"),1,"Validate SQL columns and HL7 control ID")
}

Method TestNamespaceRestoration()
{
    do $$$AssertEquals(..Contract("test_read_restores_namespace_after_storage_exception"),1,"Restore caller namespace after failed readback")
}

Method TestLocalBranchBoundary()
{
    do $$$AssertEquals(..Contract("test_send_rejects_unknown_branch_before_any_network"),1,"Reject unknown destination before network I/O")
}

Method TestRecipientAliases()
{
    do $$$AssertEquals(..Contract("test_recipient_aliases_send_and_read"),1,"Institution aliases preserve transport send/read contracts")
}

ClassMethod Contract(test As %String) As %Integer [ Language = python ]
{
    import sys
    import unittest
    sys.path.insert(0, "/contest")
    from test_multiorg_receivers import ReceiverContract
    result = unittest.TestResult()
    ReceiverContract(test).run(result)
    return int(result.testsRun == 1 and result.wasSuccessful())
}
}
