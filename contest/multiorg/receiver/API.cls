Class MultiOrg.Receiver.API Extends %RegisteredObject
{
ClassMethod Store(deliveryId As %String, payload As %String, branch As %String) As %String [ Language = python ]
{
    import sys
    sys.path.insert(0, "/contest/multiorg/receiver")
    import receiver
    return receiver.store(deliveryId, payload, branch)
}

ClassMethod Read(deliveryId As %String, branch As %String) As %String [ Language = python ]
{
    import sys
    sys.path.insert(0, "/contest/multiorg/receiver")
    import receiver
    return receiver.read(deliveryId, branch)
}

ClassMethod Listen()
{
    if '..Owned() {
        throw ##class(%Exception.General).%New("receiver namespace ownership conflict")
    }
    set stream=##class(%Stream.FileCharacter).%New()
    set sc=stream.LinkToFile("/dur/multiorg-receiver/credentials.json")
    if $system.Status.IsError(sc) {
        throw ##class(%Exception.General).%New("receiver credentials unavailable")
    }
    set config=##class(%DynamicObject).%FromJSON(stream)
    if '$system.Security.Login(config.%Get("clinic_user"),config.%Get("clinic_password")) {
        throw ##class(%Exception.General).%New("receiver clinic login failed")
    }
    do ..ListenPython()
}

ClassMethod ListenPython() [ Language = python ]
{
    import sys
    sys.path.insert(0, "/contest/multiorg/receiver")
    import receiver
    receiver.listen()
}

ClassMethod Start() As %Status
{
    job ##class(MultiOrg.Receiver.API).Listen()
    quit 1
}

ClassMethod StartIfNeeded() [ Language = python ]
{
    import socket
    import time
    import iris
    if not iris.cls("MultiOrg.Receiver.API").Owned():
        raise RuntimeError("receiver namespace ownership conflict")
    def probe():
        with socket.create_connection(("127.0.0.1", 25751), timeout=2) as conn:
            conn.settimeout(2)
            conn.sendall(b"\x0bM2-RECEIVER-HEALTH\x1c\r")
            if conn.recv(256) != b"\x0bM2-DEMOCLINIC-v1\x1c\r":
                raise RuntimeError("MLLP listener ownership conflict")
    try:
        probe()
        print("RECEIVER-LISTENER-ALREADY-READY")
        return
    except ConnectionRefusedError:
        pass
    iris.cls("MultiOrg.Receiver.API").Start()
    for _ in range(30):
        try:
            probe()
            print("RECEIVER-LISTENER-READY")
            return
        except ConnectionRefusedError:
            time.sleep(0.1)
    raise RuntimeError("MLLP listener did not become ready")
}

ClassMethod Owned() As %Boolean
{
    quit ($namespace="DEMOCLINIC")&&($get(^MultiOrgReceiverInstall("owner"))="multi-organization-receivers-v1")
}
}
