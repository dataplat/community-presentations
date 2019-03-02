### Original authors: @cl and @ck
# Don't run everything
break

#region Starting Up
# IF THIS SCRIPT IS RUN ON LOCAL SQL INSTANCES, YOU MUST RUN ISE OR POWERSHELL AS ADMIN
Clear-Host

# Paths that auto-load modules
$env:PSModulePath -Split ";"

# Get new dbatools from github/PSGallery
Set-Location c:\git
Remove-Item .\dbatools -Recurse -Force
git clone https://github.com/sqlcollaborative/dbatools.git dbatools
Install-Module dbatools -Scope CurrentUser

# Import module
Import-Module C:\git\dbatools -Force
Import-Module dbatools -Force

# defining variables and authentication
$new = "localhost:14333"
$old = $instance = "localhost"
$allservers = $old, $new
$password = 'dbatools.IO'
$backupFolder = 'c:\Backups'
$sPassword = ConvertTo-SecureString $password -AsPlainText -Force
$cred = New-Object pscredential 'sqladmin', $sPassword
$PSDefaultParameterValues = @{
    Disabled               = $false
    "*-Dba*:SqlCredential" = $cred
}
#endregion

#region Backup/Restore

# Simple restores
Restore-DbaDatabase -SqlInstance $new -Path "/backups/AdventureWorksLT2012.bak"
Restore-DbaDatabase -SqlInstance $new -Path "/backups/AdventureWorksLT2012.bak" -WithReplace

## using splatting now
$splatRestore = @{
    SqlInstance           = $old
    Path                  = "/backups/AdventureWorksLT2012.bak"
    DatabaseName          = 'WonderDB'
    DestinationFilePrefix = 'Wonder_'
}
Restore-DbaDatabase @splatRestore

# Restore backups to a different instance
Invoke-Item $backupFolder
'/backups' | Restore-DbaDatabase -SqlInstance $new -WithReplace

# Drop databases
Remove-DbaDatabase -SqlInstance $new -Database AdventureWorksLT2012 -Confirm:$false

# What about backups?
Get-DbaDatabase -SqlInstance $instance -Database WonderDB | Backup-DbaDatabase -BackupDirectory '/backups'
Get-ChildItem $backupFolder

# Get backup history
Get-DbaBackupHistory -SqlInstance $instance -Database AdventureWorksLT2012, WonderDB | Format-Table -AutoSize

# Restore from backup history
$splatRestore = @{
    SqlInstance           = $instance
    DatabaseName          = 'WonderDB'
    WithReplace           = $true
    TrustDbBackupHistory  = $true
    DestinationFilePrefix = 'Wonder_'
}
Get-DbaBackupHistory -SqlInstance $instance -Database AdventureWorksLT2012 -Last | Restore-DbaDatabase @splatRestore


#endregion

#region Searching for stuff

# Find it! - JSON file powers command and website
Find-DbaCommand Backup
Find-DbaCommand -Tag Backup | Out-GridView

# Search for SP text
$instance | Find-DbaStoredProcedure -Pattern usp

# Search for unused indexes
Find-DbaDbUnusedIndex -SqlInstance $old -Database WonderDB


#endregion

#region Checks and validations

# Verify last backups
$allservers | Get-DbaLastBackup | Format-Table -AutoSize

$allservers | Get-DbaLastBackup | Where-Object LastFullBackup -eq $null

$allservers | Get-DbaLastBackup |
    Where-Object { $_.RecoveryModel -ne 'Simple' -and $_.Database -ne 'model' } |
    Select-Object Server, Database, SinceFull, SinceLog, DatabaseCreated | Format-Table -AutoSize

# Verify checkDB
Get-DbaLastGoodCheckDb -SqlInstance $instance | Format-Table -AutoSize

Get-DbaLastGoodCheckDb -SqlInstance $instance | Where-Object LastGoodCheckDb -lt (Get-Date).AddDays(-1) | Format-Table -AutoSize

# Verify disk space
Get-DbaDiskSpace -SqlInstance $allservers

$diskspace = Get-DbaDiskSpace -SqlInstance $allservers
$diskspace | Where-Object PercentFree -lt 80 | Select-Object * | Out-GridView

# Test last backups
Get-Help Test-DbaLastBackup -Online

# Test on the server itself
Test-DbaLastBackup -SqlInstance $instance | Out-GridView

# Test on a different server without DBCC checks
Test-DbaLastBackup -SqlInstance $old -Destination $new -DestinationCredential $cred -VerifyOnly | Out-GridView

# Identity usage
Test-DbaIdentityUsage -SqlInstance $instance -Database AdventureWorksLT2012 | Select-Object -First 10 | Format-Table -AutoSize

#endregion

#region FreeSpace

# Get Db Free Space
Get-DbaDbSpace -SqlInstance $instance | Out-GridView

# Get Db Free Space AND write it to table
$writeTable = @{
    SqlInstance     = $instance
    Database        = 'tempdb'
    Table           = 'dbo.DiskSpaceExample'
    AutoCreateTable = $true
}
Get-DbaDbSpace -SqlInstance $instance | Write-DbaDataTable @writeTable

Invoke-DbaQuery -ServerInstance $instance -Database tempdb -Query 'SELECT * FROM dbo.DiskSpaceExample' | Out-GridView
#endregion

#region Blogpost-inspired

# Test/Set SQL max memory
# Inspired by Jonathan Kehayias's post about SQL Server Max memory (http://bit.ly/sqlmemcalc)
$allservers | Get-DbaMaxMemory
$allservers | Test-DbaMaxMemory | Format-Table
$allservers | Test-DbaMaxMemory | Where-Object { $_.MaxValue -gt $_.Total } | Set-DbaMaxMemory
Set-DbaMaxMemory -SqlInstance $instance -Max 1023

# RecoveryModel
# Inspired by Paul Randal's post (http://www.sqlskills.com/blogs/paul/new-script-is-that-database-really-in-the-full-recovery-mode/)
Test-DbaDbRecoveryModel -SqlInstance $new
Test-DbaDbRecoveryModel -SqlInstance $new | Where-Object { $_.ConfiguredRecoveryModel -ne $_.ActualRecoveryModel }


# Testing sql server linked server connections
# Inspired by Thomas LaRock's post (https://thomaslarock.com/2016/03/sql-server-linked-server-connection-test/)
Test-DbaLinkedServerConnection -SqlInstance $instance

# Check VLF count
# Inspired by Mark Weber's post (https://blogs.msdn.microsoft.com/saponsqlserver/2012/02/22/too-many-virtual-log-files-vlfs-can-cause-slow-database-recovery/)
$allservers | Test-DbaDbVirtualLogFile | Sort-Object Count -Descending | Format-Table -AutoSize

#endregion

#region Maintenance

# maintenance solution
$allservers | Install-DbaMaintenanceSolution -ReplaceExisting -BackupLocation /backups/ -InstallJobs

# Reset Password
# Reset-DbaAdmin -SqlInstance $instance -Login sqladmin -Verbose

# Services
# Get-DbaService -Instance I2

# Changing service account back and forth
# $login = (Get-DbaService -Instance I2 -Type Agent).StartName
# Get-DbaService -Instance I2 -Type Agent | Update-DbaServiceAccount -Username 'Local system'

# Update-DbaServiceAccount -ServiceName 'SqlAgent$I2' -Username $login
# Get-DbaService -Instance I2 | Restart-DbaService

# Find user owned objects
Find-DbaUserObject -SqlInstance $instance -Pattern sa | Format-Table -AutoSize

# Startup parameters
# Get-DbaStartupParameter -SqlInstance $instance
# Set-DbaStartupParameter -SqlInstance $instance -SingleUser -WhatIf

# WhoIsActive
Install-DbaWhoIsActive -SqlInstance $instance -Database master
Invoke-DbaWhoisActive -SqlInstance $instance -ShowOwnSpid

# Build reference
$allservers | Get-DbaBuildReference | Format-Table
$allservers | Test-DbaBuild -MaxBehind 0CU | Format-Table -AutoSize

# Updates - Windows only
# Update-DbaInstance -Path c:\updates

# sp_configure
Get-DbaSpConfigure -SqlInstance $old | Out-GridView

$oldprops = Get-DbaSpConfigure -SqlInstance $old
$newprops = Get-DbaSpConfigure -SqlInstance $new
Compare-Object -ReferenceObject $oldprops -DifferenceObject $newprops -Property ConfiguredValue -PassThru |
    Select-Object ComputerName, DisplayName, ConfiguredValue, RunningValue | Format-Table

$copyConfig = @{
    Source                   = $old
    SourceSqlCredential      = $cred
    Destination              = $new
    DestinationSqlCredential = $cred
}
Copy-DbaSpConfigure @copyConfig -Config DefaultBackupCompression, IsSqlClrEnabled

# Table compression
$compression = Test-DbaDbCompression -SqlInstance $instance -Database AdventureWorksLT2012 -Table Customer
$compression | Select-Object TableName, IndexName, CompressionTypeRecommendation, SizeCurrent, SizeRequested, PercentCompression | Format-Table

Set-DbaDbCompression -SqlInstance $instance -InputObject $compression
Get-DbaDbTable -SqlInstance $instance -Database AdventureWorksLT2012 -Table Customer |
    Select-Object Database, Name, HasCompressedPartitions, DataSpaceUsed

#endregion

#region Database migrations

# Copy database
Get-DbaDatabase -SqlInstance $old | Out-GridView -PassThru |
    Copy-DbaDatabase -Destination $new -DestinationSqlCredential $cred -BackupRestore -SharedPath /backups -Force




# Drop databases
Get-DbaDatabase -SqlInstance $new -ExcludeAllSystemDb | Remove-DbaDatabase




# Copy... everything!
$migration = @{
    Source                   = $old
    SourceSqlCredential      = $cred
    Destination              = $new
    DestinationSqlCredential = $cred
    SharedPath               = '/backups'
}
Start-DbaMigration @migration -BackupRestore -Force

# Script out the instance
Export-DbaInstance -SqlInstance $old -Path $backupFolder
Invoke-Item $backupFolder

#endregion