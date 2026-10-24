Include %occStatus

Class MultiOrg.Receiver.Provision Extends %RegisteredObject
{
ClassMethod Apply() As %Status
{
    new $namespace
    set $namespace="%SYS"
    set result=$$$OK
    try {
        set stream=##class(%Stream.FileCharacter).%New()
        do ..Check(stream.LinkToFile("/dur/multiorg-receiver/credentials.json"))
        set config=##class(%DynamicObject).%FromJSON(stream)
        if config.owner'="multi-organization-receivers-v1" {
            throw ##class(%Exception.General).%New("receiver ownership marker missing")
        }
        // Fail before resource creation when a requested namespace belongs elsewhere.
        for i=1:1:3 {
            set ns=$piece("DEMOQUALITY,DEMORESEARCH,DEMOCLINIC",",",i)
            kill props,db
            if $$$ISOK(##class(Config.Namespaces).Get(ns,.props)) {
                if (props("Globals")'=ns)||(props("Routines")'=ns) {
                    throw ##class(%Exception.General).%New("namespace ownership conflict: "_ns)
                }
            }
            if $$$ISOK(##class(Config.Databases).Get(ns,.db)) {
                if db("Directory")'=("/dur/multiorg-receiver/"_ns_"/") {
                    throw ##class(%Exception.General).%New("database ownership conflict: "_ns)
                }
            }
        }
        for i=1:1:3 {
            set ns=$piece("DEMOQUALITY,DEMORESEARCH,DEMOCLINIC",",",i)
            set dir="/dur/multiorg-receiver/"_ns_"/"
            set resource="%DB_"_ns
            if '##class(Security.Resources).Exists(resource) {
                do ..Check(##class(Security.Resources).Create(resource,"Owned multi-organization recipient","",0))
            }
            kill db
            set sc=##class(Config.Databases).Get(ns,.db)
            if $$$ISOK(sc) {
                if db("Directory")'=dir {
                    throw ##class(%Exception.General).%New("database ownership conflict: "_ns)
                }
            } else {
                do ##class(%File).CreateDirectoryChain(dir)
                do ..Check(##class(SYS.Database).CreateDatabase(dir,1,8192,0,resource,1))
                set db("Directory")=dir
                do ..Check(##class(Config.Databases).Create(ns,.db))
            }
            kill props
            set sc=##class(Config.Namespaces).Get(ns,.props)
            if $$$ISOK(sc) {
                if (props("Globals")'=ns)||(props("Routines")'=ns) {
                    throw ##class(%Exception.General).%New("namespace ownership conflict: "_ns)
                }
            } else {
                set props("Globals")=ns,props("Routines")=ns
                do ..Check(##class(Config.Namespaces).Create(ns,.props))
            }
            set $namespace=ns
            if $data(^MultiOrgReceiverInstall("owner"))&&(^MultiOrgReceiverInstall("owner")'="multi-organization-receivers-v1") {
                throw ##class(%Exception.General).%New("recipient ownership marker conflict")
            }
            do ..Check($system.OBJ.Load("/contest/multiorg/receiver/Receipt.cls","ck"))
            do ..Check($system.OBJ.Load("/contest/multiorg/receiver/API.cls","ck"))
            if ns="DEMORESEARCH" {
                do ..Check($system.OBJ.Load("/contest/multiorg/receiver/REST.cls","ck"))
            }
            set ^MultiOrgReceiverInstall("owner")="multi-organization-receivers-v1"
            set $namespace="%SYS"
        }
        do ..Account("MultiOrgQuality","MultiOrgQualityRole",config.%Get("quality_password"),"%DB_DEMOQUALITY:RW,%Service_SQL:U","DEMOQUALITY")
        if '##class(Security.Resources).Exists("MultiOrgResearchAPI") {
            do ..Check(##class(Security.Resources).Create("MultiOrgResearchAPI","Owned multi-organization REST receiver","",0))
        }
        do ..Account("MultiOrgResearch","MultiOrgResearchRole",config.%Get("research_password"),"%DB_DEMORESEARCH:RW,%Service_EmbeddedPython:U,MultiOrgResearchAPI:U","DEMORESEARCH")
        do ..Account("MultiOrgClinic","MultiOrgClinicRole",config.%Get("clinic_password"),"%DB_DEMOCLINIC:RW,%Service_EmbeddedPython:U","DEMOCLINIC")
        set $namespace="DEMOQUALITY"
        set grant=##class(%SQL.Statement).%ExecDirect(,"GRANT SELECT, INSERT ON MultiOrg_Receiver.Receipt TO MultiOrgQualityRole")
        if grant.%SQLCODE<0 {
            throw ##class(%Exception.General).%New("quality SQL grant failed")
        }
        set $namespace="DEMORESEARCH"
        set grant=##class(%SQL.Statement).%ExecDirect(,"GRANT SELECT, INSERT ON MultiOrg_Receiver.Receipt TO MultiOrgResearchRole")
        if grant.%SQLCODE<0 {
            throw ##class(%Exception.General).%New("research SQL grant failed")
        }
        set $namespace="DEMOCLINIC"
        set grant=##class(%SQL.Statement).%ExecDirect(,"GRANT SELECT, INSERT ON MultiOrg_Receiver.Receipt TO MultiOrgClinicRole")
        if grant.%SQLCODE<0 {
            throw ##class(%Exception.General).%New("clinic SQL grant failed")
        }
        set $namespace="%SYS"
        kill app
        set sc=##class(Security.Applications).Get("/csp/multiresearch",.app)
        if $$$ISOK(sc) {
            if ($get(app("NameSpace"))'="DEMORESEARCH")||($get(app("DispatchClass"))'="MultiOrg.Receiver.REST") {
                throw ##class(%Exception.General).%New("REST web application ownership conflict")
            }
        } else {
            set app("NameSpace")="DEMORESEARCH"
            set app("DispatchClass")="MultiOrg.Receiver.REST"
            set app("Enabled")=1,app("AutheEnabled")=32
            set app("IsNameSpaceDefault")=0
            set app("Resource")="MultiOrgResearchAPI"
            do ..Check(##class(Security.Applications).Create("/csp/multiresearch",.app))
        }
    } catch ex {
        set result=ex.AsStatus()
    }
    quit result
}

ClassMethod Account(user As %String, role As %String, password As %String, resources As %String, ns As %String)
{
    if '##class(Security.Roles).Exists(role) {
        do ..Check(##class(Security.Roles).Create(role,"Owned multi-organization receiver",resources,""))
    } else {
        do ..Check(##class(Security.Roles).Get(role,.roleProps))
        if ($get(roleProps("Description"))'="Owned multi-organization receiver")||($get(roleProps("GrantedRoles"))'="") {
            throw ##class(%Exception.General).%New("receiver role ownership conflict")
        }
        if $get(roleProps("Resources"))'=resources {
            if (role="MultiOrgResearchRole")&&(($get(roleProps("Resources"))="%DB_DEMORESEARCH:RW")||($get(roleProps("Resources"))="%DB_DEMORESEARCH:RW,MultiOrgResearchAPI:U")) {
                set roleProps("Resources")=resources
                do ..Check(##class(Security.Roles).Modify(role,.roleProps))
            } else {
                throw ##class(%Exception.General).%New("receiver role resource conflict")
            }
        }
    }
    if '##class(Security.Users).Exists(user) {
        do ..Check(##class(Security.Users).Create(user,role,password,"Owned multi-organization receiver",ns,"","",0,1,"multi-organization-receivers-v1",,,,,1,1))
    } else {
        do ..Check(##class(Security.Users).Get(user,.userProps))
        if ($get(userProps("Comment"))'="multi-organization-receivers-v1")||($get(userProps("Roles"))'=role) {
            throw ##class(%Exception.General).%New("receiver user ownership conflict")
        }
    }
}

ClassMethod Check(sc As %Status)
{
    if $$$ISERR(sc) {
        throw ##class(%Exception.StatusException).CreateFromStatus(sc)
    }
}
}
