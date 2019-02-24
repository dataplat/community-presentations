# Constants

$instance1 = 'localhost'
$instance2 = 'localhost\I2'
$labFolder = '.\Lab'
$backupFolder = 'C:\Backups' # Careful, The folder will be cleaned up from backups!
$logins = 'Legolas','Gimli','Aragorn'
$password = 'MyS3cur3P@ssw0rd'
# Import
Import-Module dbatools

$server = $server1 = Connect-DbaInstance $instance1
$server2 = Connect-DbaInstance $instance2
$instances = $instance1,$instance2
$servers = @($server1, $server2)

$sPassword = ConvertTo-SecureString $password -AsPlainText -Force

# Cleanup
$backupFiles = Get-ChildItem $labFolder -Include '*.bak' -Recurse | Read-DbaBackupHeader -ServerInstance $server1
Remove-DbaDatabase -SqlInstance $instances -Database $backupFiles.DatabaseName -Confirm:$false
Remove-DbaDatabase -SqlInstance $instances -Database WonderDB -Confirm:$false

if ($l = Get-DbaErrorLogin -SqlInstance $instances -Login $logins) {
    Get-DbaProcess -SqlInstance $instances -Login $logins | Stop-DbaProcess
    $l.Drop()
}

#Remove old backups
Get-ChildItem $backupFolder -Include '*.bak','*.trn' -Recurse | Remove-Item

#Drop jobs
(Get-DbaAgentJob -SqlInstance $instances -ExcludeJob 'syspolicy_purge_history').Drop()

#Drop SSIS catalog
foreach ($srv in $servers) {
    $ssis = New-Object 'Microsoft.SqlServer.Management.IntegrationServices.IntegrationServices' $srv
    if ( $ssisCatalog = $ssis.Catalogs | Where name -eq 'SSISDB') {
        $ssisCatalog.Drop()
    }
}

$server = $server1 = Connect-DbaInstance $instance1
$server2 = Connect-DbaInstance $instance2
$servers = @($server1, $server2)
#Drop linked servers
foreach ($srv in $servers) {
    while (($srv.LinkedServers | Measure-Object).Count -gt 0) {
        while (($srv.LinkedServers[0].LinkedServerLogins | Measure-Object).Count -gt 0) {
            $srv.LinkedServers[0].LinkedServerLogins[0].Drop()
            $srv.Refresh()
        }
        $srv.LinkedServers[0].Drop()
        $srv.Refresh()
    }
}

#Reset job history and backup history
$servers.Invoke('declare @date datetime = getdate(); EXECUTE msdb.dbo.sp_purge_jobhistory @oldest_date = @date')
$servers.Invoke('declare @date datetime = getdate(); EXECUTE msdb.dbo.sp_delete_backuphistory @oldest_date = @date')

#end of cleanup
#Create network share
New-SmbShare -Name Backups -Path $backupFolder -FullAccess .\users -ErrorAction SilentlyContinue

#Restore databases
Get-ChildItem $labFolder -Include '*.bak' -Recurse | Restore-DbaDatabase -SqlInstance $server1

#Create logins
New-DbaLogin -SqlInstance $server1 -Login $logins -Password $sPassword

#Run scripts
Get-ChildItem $labFolder -Include '*.sql' -Recurse | % { $server1.Invoke((Get-Content $_ -Raw)) }

#Create SSIS catalog
New-DbaSsisCatalog -SqlInstance $server1 -Password $sPassword

#Run backups
foreach ($type in 'Full','Log','Diff','Log','Log') {
    Write-Host "Running $type backups"
    $jobs = Get-DbaAgentJob -SqlInstance $instance1 | Where name -match $type| Start-DbaAgentJob
    While ((Get-DbaAgentJob -SqlInstance $instance1 -Job $jobs.Name | Where CurrentRunStatus -match 'Executing')) { Start-Sleep 1 }
    (Get-DbaDatabase -SqlInstance $instance1).Invoke('CHECKPOINT')

}

#Grant database permissions
$logins | % { (Get-DbaDatabase -SqlInstance $instance1 -ExcludeSystem).Invoke("CREATE USER [$_] FOR LOGIN [$_]; ALTER ROLE db_datareader ADD MEMBER [$_]") }

#Set server parameters
Set-DbaMaxMemory -SqlInstance $server1 -MaxMB 1024
Set-DbaMaxDop -SqlInstance $server1 -MaxDop 1
Set-DbaSpConfigure -SqlInstance $server1 -Config IsSqlClrEnabled -Value $true

Set-DbaMaxMemory -SqlInstance $server2 -MaxMB 5120
Set-DbaMaxDop -SqlInstance $server2 -MaxDop 0

#Create new credential
New-DbaCredential -SqlInstance $server1  -CredentialIdentity 'NewCred' -Password $sPassword -Force
