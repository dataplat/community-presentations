# set up authentication
$instance1 = 'localhost'
$instance2 = 'localhost:14333'
$password = 'dbatools.IO'
$sPassword = ConvertTo-SecureString $password -AsPlainText -Force
$cred = New-Object pscredential 'sqladmin', $sPassword
$PSDefaultParameterValues = @{
    Disabled               = $false
    "*-Dba*:SqlCredential" = $cred
}

# setup a powershell splat
$params = @{
    Primary                = $instance1
    PrimarySqlCredential   = $cred
    Secondary              = $instance2
    SecondarySqlCredential = $cred
    Name                   = "test-ag"
    Database               = "pubs"
    ClusterType            = "None"
    SeedingMode            = "Automatic"
    FailoverMode           = "Manual"
    Confirm                = $false
}

# execute the command
New-DbaAvailabilityGroup @params -Verbose