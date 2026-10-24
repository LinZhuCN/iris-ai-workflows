Class User.ContestPortalAdmin
{
ClassMethod Apply()
{
    If $Namespace'="%SYS" Throw ##class(%Exception.General).%New("Portal account setup requires %SYS")
    Set file="/contest/data/portal-admin-password", previous=$IO
    Open file:"R":5
    If '$Test Throw ##class(%Exception.General).%New("Local Portal administrator password file is required")
    Try { Use file Read password } Catch ex { Close file Use previous Throw ex }
    Close file Use previous
    If password="" Throw ##class(%Exception.General).%New("Local Portal administrator password is empty")
    Set user("Password")=password, user("Roles")="%All", user("Enabled")=1
    Set user("PasswordNeverExpires")=1, user("ChangePassword")=0
    If '##class(Security.Users).Exists("superuser") {
        Set sc=##class(Security.Users).Create("superuser","%All",password,"Local demo administrator","%SYS")
        $$$ThrowOnError(sc)
    }
    Set sc=##class(Security.Users).Modify("superuser",.user)
    Kill password,user
    $$$ThrowOnError(sc)
}
}
