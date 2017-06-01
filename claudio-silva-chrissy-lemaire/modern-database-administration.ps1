# Don't run everything, thanks @alexandair!
clear
break

# This is the [development] aka beta branch
Import-Module C:\github\dbatools -Force
cd C:\github\dbatools

# Start!

$SQLServers = "sql2005", "sql2008", "sql2012", "sql2014", "sql2016", "sql2016\STANDARDRTM", "sql2016\sqlEXPRESS", "sql2016\vnext"
$singleServer = "sql2016"

#Test connection to instances
Test-DbaConnection -SqlInstance $SingleServer

<#
    Test Latency
    You can use a custom query and define the number of retries
#>
Test-DbaNetworkLatency -SqlInstance $SQLServers -Query "SELECT * FROM master.sys.databases" -Count 4 | Format-Table -AutoSize

<#
    Get TCP port
    Use -Detailed to find all instances on the server
#>
Get-DbaTcpPort -SqlInstance $sqlservers | Format-Table -AutoSize


<# Find a database #>
Find-DbaDatabase -SqlInstance $sqlservers -Pattern Works -Verbose


<# Find-DBAStoredProcedure 
# Find-DbaStoredProcdure - @claudioessilva, @cl, Stephen Bennett
# 37,545 SQL Server stored procedures on 9 servers evaluated in 8.67 seconds!
#>
Find-DbaStoredProcedure -SqlInstance sql2014 -Database AdventureWorks2014 -Pattern 'Name' | Out-GridView

#$sqlservers | 
Find-DbaStoredProcedure -SQlInstance sql2014 -Pattern '\w+@\w+\.\w+'


<# Find-DbaDatabaseGrowthEvent #>
Find-DbaDatabaseGrowthEvent -SqlInstance $singleServer -Database AutoGrowth | Where-Object StartTime -gt (Get-Date).AddMinutes(-165) | Out-GridView
(Find-DbaDatabaseGrowthEvent -SqlInstance $singleServer -Database AutoGrowth | Where-Object StartTime -gt (Get-Date).AddMinutes(-165)).Count


Test-DbaVirtualLogFile -SqlInstance $singleServer -Database AutoGrowth
Get-DbaDatabaseFreespace -SqlInstance $singleServer -Database AutoGrowth

<# Expand-DbaTLogResponsibly #>
Expand-DbaTLogResponsibly -SqlInstance $singleServer -Database AutoGrowth -TargetLogSizeMB 512 -ShrinkLogFile -ShrinkSizeMB 1 -BackupDirectory "\\nas\sql\SQLGrillen"


<# Orphaned File #>
$Files = Find-DbaOrphanedFile -SqlInstance $singleServer
$Files 

(($Files | ForEach-Object { Get-ChildItem $_.RemoteFileName | Select -ExpandProperty Length} ) | Measure-Object -Sum).Sum / 1Mb

$Files.RemoteFileName  | Remove-Item -WhatIf


<# Remove-DbaDatabaseSafely NoCheckDB#>
Get-Help Remove-DbaDatabaseSafely -Online
Remove-DbaDatabaseSafely -SqlInstance sql2008 -Database dbOrphanUsers -BackupFolder "\\nas\sql\sqlgrillen\dbOrphanUsers" -Verbose

<# Repair-DbaOrphanUser #>

## Refresh database
$source = "sql2008"
$destination = $singleServer
$databaseToRefresh = "db1"

Backup-DbaDatabase -SqlInstance $source -Database $databaseToRefresh -BackupDirectory "\\nas\sql\sqlgrillen" -CompressBackup | Restore-DbaDatabase -SqlInstance $destination -WithReplace

Repair-DbaOrphanUser -SqlInstance $destination -Database $databaseToRefresh -Verbose -WhatIf


break
#Import-Module C:\github\dbatools\dbatools.psd1
$old = "sql2014"
$instance = $new = "sql2016a"
$sqlservers = "sql2005", "sql2008", "sql2012", "sql2014", "sql2016"

# standard
Restore-DbaDatabase -SqlInstance $instance -Path "\\nas\sql\SQL2014\AdventureWorks2014\FULL\SQL2014_AdventureWorks2014_FULL_20170411_124147.bak" # LocalPath
Restore-DbaDatabase -SqlInstance $instance -Path "\\nas\sql\SQL2014\AdventureWorks2014\FULL\SQL2014_AdventureWorks2014_FULL_20170411_124147.bak" -WithReplace

# ola!
Invoke-Item \\nas\sql\smalloladir
Get-ChildItem -Directory \\nas\sql\smalloladir | Restore-DbaDatabase -SqlInstance $new -WithReplace

# What about backups?
Get-DbaDatabase -SqlInstance $instance -Database db3 | Backup-DbaDatabase -BackupDirectory C:\temp -NoCopyOnly

# backup header
Read-DbaBackupHeader -SqlInstance $instance -Path "\\nas\sql\unknown.bak" | SELECT * # ServerName, DatabaseName, UserName, BackupFinishDate, SqlVersion, BackupSizeMB
#endregion

# Did you see? SqlServer module is now in the Powershell Gallery too!
Get-Help Test-DbaLastBackup -Online
Test-DbaLastBackup -SqlInstance $old | Out-GridView

# Anyone leaving? - maybe this should be garbo? with ctrlb or claudio
Find-DbaUserObject -SqlInstance $instance -Pattern claudio

# Find it! - not that im in love with the command, but wanna comfort ppl who are like oh fuck that's a lot
Find-DbaCommand -Tag Backup

#Either of us - this one is one of our most popular
Invoke-DbaWhoisActive -SqlInstance $instance -ShowOwnSpid -ShowSystemSpids
Install-DbaWhoIsActive -SqlInstance $instance -Database master
Invoke-DbaWhoisActive -SqlInstance $instance -ShowOwnSpid -ShowSystemSpid
Invoke-DbaWhoisActive -SqlInstance $instance -ShowOwnSpid -ShowSystemSpid | Out-GridView
#either one can do this but one must
#region holiday

# Get-DbaLastBackup - by @powerdbaklaas
$sqlservers | Get-DbaLastBackup | Out-GridView
$sqlservers | Get-DbaLastBackup | Where-Object LastFullBackup -eq $null | Format-Table -AutoSize
$sqlservers | Get-DbaLastBackup | Where-Object { $_.SinceLog -gt '00:15:00' -and $_.RecoveryModel -ne 'Simple' -and $_.Database -ne 'model' } | Select Server, Database, SinceFull, DatabaseCreated | Out-GridView

# LastGoodCheckDb - by @jagoop
$checkdbs = Get-DbaLastGoodCheckDb -SqlInstance $instance
$checkdbs
$checkdbs | Where LastGoodCheckDb -eq $null
$checkdbs | Where LastGoodCheckDb -lt (Get-Date).AddDays(-1)

# Disk Space - by a bunch of us
Get-DbaDiskSpace -SqlInstance $sqlservers
$diskspace = Get-DbaDiskSpace -SqlInstance $sqlservers -Detailed
$diskspace | Where PercentFree -lt 20

#Commands that should be run on garbo
#SPN
#Find-DbaStoredProcedure


#region SPN
Start-Process https://dbatools.io/schwifty
Start-Process "C:\Program Files\Microsoft\Kerberos Configuration Manager for SQL Server\KerberosConfigMgr.exe"
# Get it
Get-DbaSpn | Format-Table
$sqlservers | Test-DbaSpn | Out-GridView -PassThru | Set-DbaSpn -Whatif
Get-DbaSpn | Remove-DbaSpn -Whatif

$sqlservers | Test-DbaSpn -Credential (Get-Credential)
