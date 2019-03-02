
# Constants

$instance1 = 'localhost'
$instance2 = 'localhost:14333'
$labFolder = '.\Lab'
$backupFolder = 'c:\Backups' # Careful, The folder will be cleaned up from backups!
$mappedBackups = '/backups'
$logins = 'Legolas', 'Gimli', 'Aragorn'
$password = 'dbatools.IO'

# adjust backup path for docker
Get-ChildItem $backupFolder | Remove-Item -Force
$null = New-Item $backupFolder -ItemType Directory -Force
$linuxBackupFolder = $backupFolder
if ($linuxBackupFolder.Contains(':')) {
    $linuxBackupFolder = "/" + ($linuxBackupFolder -replace '\:', '')
}
$linuxBackupFolder = $linuxBackupFolder -replace '\\', '/'

# remove old containers
docker stop dockersql1 dockersql2
docker rm dockersql1 dockersql2

# create a shared network
docker network create localnet

# start containers
docker run -p 1433:1433 --name dockersql1 `
    --network localnet --hostname dockersql1 `
    -v "$linuxBackupFolder`:$mappedBackups" `
    -d dbatools/sqlinstance

docker run -p 14333:1433 --name dockersql2 `
    --network localnet --hostname dockersql2 `
    -v "$linuxBackupFolder`:$mappedBackups" `
    -d dbatools/sqlinstance2

# Import
Import-Module dbatools

# defining variables and authentication
$sPassword = ConvertTo-SecureString $password -AsPlainText -Force
$cred = New-Object pscredential 'sqladmin', $sPassword
$PSDefaultParameterValues = @{
    Disabled               = $false
    "*-Dba*:SqlCredential" = $cred
}

# wait for connection
do {
    Write-Host "waiting for docker image 1..."
    Start-Sleep 3
} until((Invoke-DbaQuery -SqlInstance $instance1 -Query 'select 1' -As SingleValue -WarningAction SilentlyContinue) -eq 1 )
do {
    Write-Host "waiting for docker image 2..."
    Start-Sleep 3
} until((Invoke-DbaQuery -SqlInstance $instance2 -Query 'select 1' -As SingleValue -WarningAction SilentlyContinue) -eq 1 )

Repair-DbaServerName -SqlInstance $instance1, $instance2 -Confirm:$false
docker restart dockersql1 dockersql2

# wait for connection
do {
    Write-Host "waiting for docker image 1..."
    Start-Sleep 3
} until((Invoke-DbaQuery -SqlInstance $instance1 -Query 'select 1' -As SingleValue -WarningAction SilentlyContinue) -eq 1 )
do {
    Write-Host "waiting for docker image 2..."
    Start-Sleep 3
} until((Invoke-DbaQuery -SqlInstance $instance2 -Query 'select 1' -As SingleValue -WarningAction SilentlyContinue) -eq 1 )


$server1 = Connect-DbaInstance $instance1

# Copy backups to the backup folder
Copy-Item .\Lab\*.bak $backupFolder

#Restore databases
$mappedBackups | Restore-DbaDatabase -SqlInstance $server1

#Create logins
New-DbaLogin -SqlInstance $server1 -Login $logins -Password $sPassword

#Run scripts

$query = @"
IF EXISTS (SELECT * FROM sys.servers WHERE name = 'MYLINKEDSERVER')
    EXEC master.dbo.sp_dropserver @server = N'MYLINKEDSERVER', @droplogins = 'droplogins'
EXEC master.dbo.sp_addlinkedserver @server = N'MYLINKEDSERVER', @srvproduct=N'', @provider=N'SQLNCLI', @datasrc=N'dockersql2', @catalog=N'master'
EXEC master.dbo.sp_addlinkedsrvlogin @rmtsrvname=N'MYLINKEDSERVER',@useself=N'False',@locallogin=NULL,@rmtuser=N'sqladmin',@rmtpassword='$password'
EXEC master.dbo.sp_addlinkedsrvlogin @rmtsrvname=N'MYLINKEDSERVER',@useself=N'False',@locallogin=N'Legolas',@rmtuser=N'sqladmin',@rmtpassword='$password'
"@
Invoke-DbaQuery -SqlInstance $server1 -Query $query

Get-ChildItem $labFolder -Include '*.sql' -Recurse | ForEach-Object {
    Invoke-DbaQuery -SqlInstance $server1 -File $_.FullName
}

#Run backups
foreach ($type in 'Full', 'Log', 'Diff', 'Log', 'Log') {
    Write-Host "Running $type backups"
    Get-DbaDatabase -SqlInstance $server1 -ExcludeSystem | Backup-DbaDatabase -BackupDirectory $mappedBackups -Type $type
    (Get-DbaDatabase -SqlInstance $instance1 -ExcludeSystem).Invoke('CHECKPOINT')
}

#Grant database permissions
$logins | ForEach-Object { (Get-DbaDatabase -SqlInstance $instance1 -ExcludeAllSystemDb).Invoke("CREATE USER [$_] FOR LOGIN [$_]; ALTER ROLE db_datareader ADD MEMBER [$_]") }

#Set server parameters
Set-DbaSpConfigure -SqlInstance $server1 -Config MaxDegreeOfParallelism -Value 1
Set-DbaSpConfigure -SqlInstance $server1 -Config MaxServerMemory -Value 1024
Set-DbaSpConfigure -SqlInstance $server1 -Config IsSqlClrEnabled -Value $true

Set-DbaSpConfigure -SqlInstance $server1 -Config MaxDegreeOfParallelism -Value 0
Set-DbaSpConfigure -SqlInstance $server1 -Config MaxServerMemory -Value 512

#Create new credential
New-DbaCredential -SqlInstance $server1  -CredentialIdentity 'NewCred' -Password $sPassword -Force

