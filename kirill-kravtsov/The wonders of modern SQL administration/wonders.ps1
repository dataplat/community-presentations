### Original authors: @cl and @ck
# Don't run everything
break

# IF THIS SCRIPT IS RUN ON LOCAL SQL INSTANCES, YOU MUST RUN ISE OR POWERSHELL AS ADMIN
cls

# Paths that auto-load modules
$env:PSModulePath -Split ";"

# Get new dbatools from github/PSGallery
cd c:\git
Remove-Item .\dbatools -Recurse -Force
git clone https://github.com/sqlcollaborative/dbatools.git dbatools
Install-Module dbatools -Scope CurrentUser

# Import module
Import-Module C:\git\dbatools -Force

# Set some vars
$new = "localhost\i2"
$old = $instance = "localhost"
$allservers = $old, $new


######## BACKUP/RESTORES ########

# Simple restores
Restore-DbaDatabase -SqlInstance $new -Path "C:\Lab\AdventureWorksLT2012.bak"
Restore-DbaDatabase -SqlInstance $new -Path "C:\Lab\AdventureWorksLT2012.bak" -WithReplace
Restore-DbaDatabase -SqlInstance $old -Path "C:\Lab\AdventureWorksLT2012.bak" -DatabaseName WonderDB -DestinationFilePrefix 'Wonder_'

# Ola backups - restore on a different instance
Invoke-Item \\localhost\Backups\SQL1\AdventureWorksLT2012
Get-ChildItem -Directory \\localhost\Backups\SQL1\AdventureWorksLT2012 | Restore-DbaDatabase -SqlInstance $new -WithReplace

# Drop databases
Remove-DbaDatabase -SqlInstance $new -Database AdventureWorksLT2012 -Confirm:$false

# What about backups?
Get-DbaDatabase -SqlInstance $instance -Database WonderDB | Backup-DbaDatabase -BackupDirectory \\localhost\Backups
Get-ChildItem \\localhost\Backups

# history
Get-DbaBackupHistory -SqlInstance $instance -Database AdventureWorksLT2012, WonderDB | Out-GridView
Get-DbaBackupHistory -SqlInstance $instance -Database AdventureWorksLT2012 -Last | Restore-DbaDatabase -SqlInstance $instance -DatabaseName WonderDB -WithReplace -TrustDbBackupHistory -DestinationFilePrefix 'Wonder_'


######## END OF BACKUP/RESTORES ########

######## SEARCH ########

# Find it! - JSON file powers command and website
Find-DbaCommand Backup
Find-DbaCommand -Tag Backup | Out-GridView

# Search for SP text
$instance | Find-DbaStoredProcedure -Pattern usp


######## END OF SEARCH ########

######## TESTS ########

# Verify last backups
$allservers | Get-DbaLastBackup | Out-GridView

$allservers | Get-DbaLastBackup | Where-Object LastFullBackup -eq $null | Out-GridView

$allservers | Get-DbaLastBackup | 
    Where-Object { $_.SinceLog -gt '00:15:00' -and $_.RecoveryModel -ne 'Simple' -and $_.Database -ne 'model' } | 
    Select-Object Server, Database, SinceFull, SinceLog, DatabaseCreated | Out-GridView

# Verify checkDB
Get-DbaLastGoodCheckDb -SqlInstance $instance | Out-GridView

Get-DbaLastGoodCheckDb -SqlInstance $instance | Where LastGoodCheckDb -lt (Get-Date).AddDays(-1) 

# Verify disk space 
Get-DbaDiskSpace -SqlInstance $allservers

$diskspace = Get-DbaDiskSpace -SqlInstance $allservers
$diskspace | Where PercentFree -lt 80 | Select * | Out-GridView

# Test last backups
Get-Help Test-DbaLastBackup -Online

# Test on the server itself
Test-DbaLastBackup -SqlInstance $instance | Out-GridView

# Test on a different server
Test-DbaLastBackup -SqlInstance $old -Destination $new -VerifyOnly | Out-GridView

# Identity usage
Test-DbaIdentityUsage -SqlInstance $instance | Out-GridView

######## END OF TESTS ########

######## DB SPACE ########

# Get Db Free Space AND write it to table
Get-DbaDbSpace -SqlInstance $instance | Out-GridView

Get-DbaDbSpace -SqlInstance $instance -IncludeSystemDB | ConvertTo-DbaDataTable | Write-DbaDataTable -SqlInstance $instance -Database tempdb -Table DiskSpaceExample -AutoCreateTable

Invoke-DbaQuery -ServerInstance $instance -Database tempdb -Query 'SELECT * FROM dbo.DiskSpaceExample' | Out-GridView


######## END OF DB SPACE  ########

######## Blogpost-inspired ########

# Test/Set SQL max memory
$allservers | Get-DbaMaxMemory
$allservers | Test-DbaMaxMemory | Format-Table
$allservers | Test-DbaMaxMemory | Where-Object { $_.SqlMaxMB -gt $_.TotalMB } | Set-DbaMaxMemory -WhatIf
Set-DbaMaxMemory -SqlInstance $instance -MaxMb 1023

# RecoveryModel
Test-DbaDbRecoveryModel -SqlInstance $new
Test-DbaDbRecoveryModel -SqlInstance $new | Where { $_.ConfiguredRecoveryModel -ne $_.ActualRecoveryModel }


# Testing sql server linked server connections
Test-DbaLinkedServerConnection -SqlInstance $instance

# Some vlfs
$allservers | Test-DbaDbVirtualLogFile | Where-Object {$_.Count -ge 50} | Sort-Object Count -Descending | Out-GridView


######## END OF Blogpost-inspired ########

######## MAINTENANCE ########

# maintenance solution
$instance | Install-DbaMaintenanceSolution -ReplaceExisting -BackupLocation \\localhost\Backups -InstallJobs

# Reset Password
Reset-DbaAdmin -SqlInstance $instance -Login sqladmin -Verbose

# Services
Get-DbaService -Instance I2

# Changing service account back and forth
$login = (Get-DbaService -Instance I2 -Type Agent).StartName
Get-DbaService -Instance I2 -Type Agent | Update-DbaServiceAccount -Username 'Local system'

Update-DbaServiceAccount -ServiceName 'SqlAgent$I2' -Username $login
Get-DbaService -Instance I2 | Restart-DbaService

# Find user owned objects
Find-DbaUserObject -SqlInstance $instance -Pattern sa

# Startup parameters
Get-DbaStartupParameter -SqlInstance $instance
Set-DbaStartupParameter -SqlInstance $instance -SingleUser -WhatIf

# WhoIsActive
Install-DbaWhoIsActive -SqlInstance $instance -Database master
Invoke-DbaWhoisActive -SqlInstance $instance -ShowOwnSpid | Out-GridView

# Build reference
$allservers | Get-DbaBuildReference | Format-Table

# sp_configure
Get-DbaSpConfigure -SqlInstance $old

$oldprops = Get-DbaSpConfigure -SqlInstance $old
$newprops = Get-DbaSpConfigure -SqlInstance $new
$propcompare = foreach ($prop in $oldprops) {
  [pscustomobject]@{
  Config = $prop.DisplayName
  $old = $prop.RunningValue
  $new = $newprops | Where ConfigName -eq $prop.ConfigName | Select -ExpandProperty RunningValue
  }
} 
$propcompare | Out-GridView

# Copy-DbaSpConfigure
Copy-DbaSpConfigure -Source $old -Destination $new -Config DefaultBackupCompression, IsSqlClrEnabled

# Copy database
Get-DbaDatabase -SqlInstance $old | Out-GridView -PassThru | Copy-DbaDatabase -Destination $new -BackupRestore -SharedPath \\localhost\backups -Force

# Drop databases
Get-DbaDatabase -SqlInstance $new -ExcludeSystem | Remove-DbaDatabase

# Copy SSIS catalog
Copy-DbaSSISCatalog -Source $old -Destination $new

# Copy... everything!
Start-DbaMigration -Source $old -Destination $new -BackupRestore \\localhost\backups -Force
