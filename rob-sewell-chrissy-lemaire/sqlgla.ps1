# Don't run everything, thanks @alexandair!
break

# IF THIS SCRIPT IS RUN ON LOCAL SQL INSTANCES, YOU MUST RUN ISE OR POWERSHELL AS ADMIN
# Otherwise, a bunch of commands won't work.
cls

# Paths that auto-load modules
$env:PSModulePath -Split ";"

# This is the [development] aka beta branch
Import-Module C:\github\dbatools -Force
cd C:\github\dbatools

# Set some vars
$new = "localhost\sql2016"
$old = $instance = "localhost"
$allservers = $old, $new

# Quick overview of commands
Start-Process https://dbatools.io/commands

#region backuprestore

# standard
Restore-DbaDatabase -SqlInstance $instance -Path "C:\temp\AdventureWorks2012-Full Database Backup.bak"
Restore-DbaDatabase -SqlInstance $instance -Path "C:\temp\AdventureWorks2012-Full Database Backup.bak" -WithReplace

# ola!
Invoke-Item \\workstation\backups\WORKSTATION\SharePoint_Config
Invoke-Item \\workstation\backups\sql2012 
Get-ChildItem -Directory \\workstation\backups\sql2012 | Restore-DbaDatabase -SqlInstance $new

#endregion

# Make a quick backup!
Get-DbaDatabase -SqlInstance $new | Backup-DbaDatabase

# Test your backups
# Did you see? SqlServer module is now in the Powershell Gallery too!
Get-Help Test-DbaLastBackup -Online
Import-Module SqlServer
Invoke-Item (Get-Item SQLSERVER:\SQL\$instance\DEFAULT).DefaultFile

Test-DbaLastBackup -SqlInstance $new | Out-GridView

# db space
Get-DbaDatabaseSpace -SqlInstance $new -IncludeSystemDBs | Out-GridView

# Exports
Export-DbaLogin -SqlInstance $instance -Path C:\temp\logins.sql
Invoke-Item C:\temp\logins.sql

# Other Exports
Get-DbaAgentJob -SqlInstance $old | Export-DbaScript -Path C:\temp\jobs.sql

# Snapshots!
New-DbaDatabaseSnapshot -SqlInstance $new -Database db1 -Name db1_snapshot
Get-DbaDatabaseSnapshot -SqlInstance $new
Get-DbaProcess -SqlInstance $new -Database db1 | Stop-DbaProcess
Restore-DbaFromDatabaseSnapshot -SqlInstance $new -Database db1 -Snapshot db1_snapshot
Remove-DbaDatabaseSnapshot -SqlInstance $new -Snapshot db1_snapshot # or -Database db1

# Checkdb & Jobs
$old | Get-DbaLastGoodCheckDb | Out-GridView
$old | Get-DbaAgentJob | Where Name -match integrity | Start-DbaAgentJob
$old | Get-DbaRunningJob
$old | Get-DbaLastGoodCheckDb

# build info!
Start-Process https://dbatools.io/builds
$allservers | Get-DbaSqlBuildReference

# Registered Server
$allservers | Get-DbaRegisteredServer | Out-GridView

# Find-DbaStoredProcdure - @claudioessilva, @cl, Stephen Bennett
# 37,545 SQL Server stored procedures on 9 servers evaluated in 8.67 seconds!
$new | Find-DbaStoredProcedure -Pattern dbatools
$new | Find-DbaStoredProcedure -Pattern dbatools | Select * | Out-GridView
$new | Find-DbaStoredProcedure -Pattern '\w+@\w+\.\w+'

# Spconfigure
Get-DbaSpConfigure -SqlInstance $new | Out-GridView
Get-DbaSpConfigure -SqlInstance $new -ConfigName XPCmdShellEnabled
Set-DbaSpConfigure -SqlInstance $new -ConfigName XPCmdShellEnabled -Value $true

# DB Cloning too!
Invoke-DbaDatabaseClone -SqlInstance $new -Database db1 -CloneDatabase db1_clone

# XEvents - more coming soon, like easy replays on remote servers

# Easy start/stop
Get-DbaXESession -SqlInstance $new
$session = Get-DbaXESession -SqlInstance $new -Session system_health | Stop-DbaXESession
$session | Start-DbaXESession

# Read and watch
Get-DbaXEventSession -SqlInstance $new -Session system_health | Read-DbaXEventFile
Get-DbaXEventSession -SqlInstance $new -Session system_health | Read-DbaXEventFile | Select -ExpandProperty Fields

<#
    Get-DbaXEventSession -SqlInstance $new -Session system_health | Watch-DbaXEventSession | Select -ExpandProperty Fields
#>

Invoke-Item C:\github\community-presentations\rob-sewell-chrissy-lemaire\watch-xeventsession.png

# Log Files
Get-DbaDbVirtualLogFile -SqlInstance $new -Database db1

# Reset-DbaAdmin
Reset-DbaAdmin -SqlInstance $instance -Login sqladmin -Verbose

# SQL Modules - View, TableValuedFunction, DefaultConstraint, StoredProcedure, Rule, InlineTableValuedFunction, Trigger, ScalarFunction
Get-DbaSqlModule -SqlInstance $instance | Out-GridView
Get-DbaSqlModule -SqlInstance $instance -ModifiedSince (Get-Date).AddDays(-7) | Select-String -Pattern sp_executesql

# Reads trace files - default trace by default
Read-DbaTraceFile -SqlInstance $instance | Out-GridView

# Find failed jobs
$allservers | Find-DbaAgentJob -IsFailed | Start-DbaAgentJob
$allservers | Get-DbaAgentJob
$allservers | Get-DbaAgentJob | Out-Gridview -PassThru | Start-DbaAgentJob
$allservers | Get-DbaRunningJob


# don't have remoting access? Explore the filesystem. Uses master.sys.xp_dirtree
Get-DbaFile -SqlInstance $instance -Depth 3 -Path 'C:\Program Files\Microsoft SQL Server' | Out-GridView
New-DbaSqlDirectory -SqlInstance $instance  -Path 'C:\Program Files\Microsoft SQL Server\MSSQL14.MSSQLSERVER\test'

# Database clone
Invoke-DbaDatabaseClone -SqlInstance $new -Database dbwithsprocs -CloneDatabase dbwithsprocs_clone

# Schema change!
Invoke-Sqlcmd2 -SqlInstance $new -Database tempdb -Query "CREATE TABLE dbatoolsci_schemachange (id int identity)"
Invoke-Sqlcmd2 -SqlInstance $new -Database tempdb -Query "EXEC sp_rename 'dbatoolsci_schemachange', 'dbatoolsci_schemachange_new'"
Get-DbaSchemaChangeHistory -SqlInstance $new -Database tempdb
Invoke-Sqlcmd2 -SqlInstance $new -Database tempdb -Query "DROP TABLE dbatoolsci_schemachange_new"

# History
Get-Command -Module dbatools *history*

# More histories
Get-DbaAgentJobHistory -SqlInstance $instance | Out-GridView
Get-DbaBackupHistory -SqlInstance $instance | Out-GridView
Get-DbaDbMailHistory -SqlInstance $instance | Out-GridView

# Configs and enterprise logging
Get-DbaConfig | Out-GridView
Invoke-Item (Get-DbaConfig -FullName path.dbatoolslogpath).Value

Get-DbaConfig -Module tabexpansion
Set-DbaConfig -Name tabexpansion.disable -Value $true

Get-DbatoolsLog | Out-GridView
New-DbatoolsSupportPackage

# See protocols
Get-DbaServerProtocol -ComputerName $instance | Out-GridView

# In-depth spconfigure
Get-DbaSpConfigure -SqlInstance $instance | Out-GridView

# Get the registry root
Get-DbaSqlRegistryRoot -ComputerName $instance

# Thanks, Fred! 
[dbainstance]"sql2016"
[dbainstance]"sqlcluster\sharepoint"

# Network Encryption
# - Requires a certificate with DNS names (complex)
# - Requires specific properties in the certificate
# - Requires that the service account have read access to the private key
# - Clusters cannot be configured via the SQL Configuration Manager

Start-Process "C:\github\community-presentations\rob-sewell-chrissy-lemaire\forcednetwork.mp4"

#region SPN
Start-Process "C:\Program Files\Microsoft\Kerberos Configuration Manager for SQL Server\KerberosConfigMgr.exe"

# No domain - let's watch a video!

$servers | Test-DbaSpn | Out-GridView -PassThru | Set-DbaSpn -WhatIf
Start-Process "C:\github\community-presentations\rob-sewell-chrissy-lemaire\spn.mp4"

#endregion

# OGV madness
Get-DbaDatabase -SqlInstance $old | Out-GridView -PassThru | Copy-DbaDatabase -Destination $new -BackupRestore -NetworkShare \\workstation\c$\temp -Force

# Find it! - JSON file powers command and website
Find-DbaCommand Backup
Find-DbaCommand -Tag Backup | Out-GridView
