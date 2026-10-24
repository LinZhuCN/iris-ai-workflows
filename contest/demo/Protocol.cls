Class Demo.Protocol
{
ClassMethod CanQueue(pending As %Integer) As %Boolean
{
    Quit (pending >= 0) && (pending < 1000)
}

ClassMethod Now() As %Numeric
{
    Quit $Piece($ZTIMESTAMP,",",1)*86400+$Piece($ZTIMESTAMP,",",2)
}

ClassMethod Hash(text As %String) As %String
{
    Set digest = $System.Encryption.SHAHash(256,text), hash = ""
    For byte = 1:1:$Length(digest) Set hash = hash_$ZConvert($Translate($Justify($ZHex($Ascii(digest,byte)),2)," ","0"),"L")
    Quit hash
}

ClassMethod Fail(message As %String)
{
    Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError,message))
}

ClassMethod Call(path As %String, account As %String, body As %DynamicObject = "") As %DynamicObject
{
    If (account '= "ContestConnectorReader") && (account '= "ContestConnectorManager") && (account '= "ContestDemoSource") Do ..Fail("Invalid machine identity")
    Set file = "/contest/data/platform/"_account_".password"
    Set device = $IO
    Open file:"R":2
    If '$Test Do ..Fail("Machine credential unavailable")
    Try { Use file Read password }
    Catch ex {
        Close file
        Use device
        Throw ex
    }
    Close file
    Use device
    Set http = ##class(%Net.HttpRequest).%New()
    Set http.Server = "gateway", http.Port = 80, http.Timeout = 3
    Set encoded = $Translate($System.Encryption.Base64Encode(account_":"_password),$Char(13,10))
    Set sc = http.SetHeader("Authorization","Basic "_encoded) $$$ThrowOnError(sc)
    Set sc = http.SetHeader("Accept","application/json") $$$ThrowOnError(sc)
    Kill password,encoded
    If $IsObject(body) {
        Set http.ContentType = "application/json"
        Do http.EntityBody.Write(body.%ToJSON())
        Set sc = http.Post(path)
    } Else {
        Set sc = http.Get(path)
    }
    $$$ThrowOnError(sc)
    If '$IsObject(http.HttpResponse) Do ..Fail("Connector returned no response")
    If (http.HttpResponse.StatusCode < 200) || (http.HttpResponse.StatusCode > 299) Do ..Fail("Connector HTTP "_http.HttpResponse.StatusCode)
    Quit {}.%FromJSON(http.HttpResponse.Data)
}
}
