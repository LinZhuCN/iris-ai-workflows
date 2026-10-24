Class MultiOrg.Receiver.REST Extends %CSP.REST
{
Parameter HandleCorsRequest = 0;

XData UrlMap [ XMLNamespace = "http://www.intersystems.com/urlmap" ]
{
<Routes>
<Route Url="/receipts" Method="POST" Call="Post"/>
<Route Url="/receipts/:id" Method="GET" Call="Get"/>
</Routes>
}

ClassMethod Post() As %Status
{
    set %response.ContentType="application/json"
    set %response.CharSet="utf-8"
    try {
        if %request.Content.Size>40000 {
            set %response.Status="413 Payload Too Large"
            write "{""error"":""request too large""}"
        } else {
            set raw=%request.Content.Read(40000)
            set body=##class(%DynamicObject).%FromJSON($zconvert(raw,"I","UTF8"))
            if (body.%GetTypeOf("delivery_id")'="string")||(body.%GetTypeOf("payload")'="string") {
                set %response.Status="400 Bad Request"
                write "{""error"":""delivery_id and raw JSON payload string required""}"
            } else {
                write ##class(MultiOrg.Receiver.API).Store(body.%Get("delivery_id"),body.payload,"rest")
            }
        }
    } catch ex {
        set %response.Status="409 Conflict"
        write "{""error"":""invalid payload or delivery ID conflict""}"
    }
    quit 1
}

ClassMethod Get(id As %String) As %Status
{
    set %response.ContentType="application/json"
    set %response.CharSet="utf-8"
    try {
        write ##class(MultiOrg.Receiver.API).Read(id,"rest")
    } catch ex {
        set %response.Status="400 Bad Request"
        write "{""error"":""invalid receipt ID""}"
    }
    quit 1
}
}
