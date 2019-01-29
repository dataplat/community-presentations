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

# db space
Get-DbaDbSpace -SqlInstance $new -IncludeSystemDBs | Out-GridView

#region backuprestore

# standard
Restore-DbaDatabase -SqlInstance $instance -Path "C:\temp\AdventureWorks2012-Full Database Backup.bak"
Restore-DbaDatabase -SqlInstance $instance -Path "C:\temp\AdventureWorks2012-Full Database Backup.bak" -WithReplace

# ola!
Invoke-Item \\workstation\backups\WORKSTATION\SharePoint_Config
Invoke-Item \\workstation\backups\sql2012 
Get-ChildItem -Directory \\workstation\backups\sql2012 | Restore-DbaDatabase -SqlInstance $new

# What about backups?
Get-DbaDatabase -SqlInstance $instance -Database SharePoint_Config | Backup-DbaDatabase -BackupDirectory C:\temp

# Did you see? SqlServer module is now in the Powershell Gallery too!
Get-Help Test-DbaLastBackup -Online
Import-Module SqlServer
Invoke-Item (Get-Item SQLSERVER:\SQL\$instance\DEFAULT).DefaultFile

Test-DbaLastBackup -SqlInstance $instance -Destination $new | Out-GridView

#endregion


# Exports
Export-DbaLogin -SqlInstance $instance -Path C:\temp\logins.sql
Invoke-Item C:\temp\logins.sql

# Other Exports
Get-DbaAgentJob -SqlInstance $old | Export-DbaScript -Path C:\temp\jobs.sql

# Reset-DbaAdmin
Reset-DbaAdmin -SqlInstance $instance -Login sqladmin -Verbose

# Build ref!
$allservers | Get-DbaBuildReference | Format-Table

# SQL Modules - View, TableValuedFunction, DefaultConstraint, StoredProcedure, Rule, InlineTableValuedFunction, Trigger, ScalarFunction
Get-DbaModule -SqlInstance $instance | Out-GridView
Get-DbaModule -SqlInstance $instance -ModifiedSince (Get-Date).AddDays(-7) | Select-String -Pattern sp_executesql

# Reads trace files - default trace by default
Read-DbaTraceFile -SqlInstance $instance | Out-GridView

# Uses xp_dirtree
Get-DbaFile -SqlInstance $instance | Out-GridView
Get-DbaFile -SqlInstance $instance -Path C:\temp
Get-DbaFile -SqlInstance $instance -Path C:\temp -Depth 2

# Network Encryption
# - Requires a certificate with DNS names (complex)
# - Requires specific properties in the certificate
# - Requires that the service account have read access to the private key
# - Clusters cannot be configured via the SQL Configuration Manager

Start-Process "C:\github\community-presentations\rob-sewell-chrissy-lemaire\belgium-forcednetwork.mp4"

# Find failed jobs - just thought of this today so nothing has failed
$allservers | Find-DbaAgentJob -IsFailed | Start-DbaAgentJob
$allservers | Get-DbaAgentJob
$allservers | Get-DbaAgentJob | Out-Gridview -PassThru | Start-DbaAgentJob
$allservers | Get-DbaRunningJob

# History
Get-Command -Module dbatools *history*

# Schema change!
$db = Get-DbaDatabase -SqlInstance $new -Database tempdb
$db.Query("CREATE TABLE dbatoolsci_schemachange (id int identity)")
$db.Query("EXEC sp_rename 'dbatoolsci_schemachange', 'dbatoolsci_schemachange_new'")
Get-DbaSchemaChangeHistory -SqlInstance $new
$db.Query("DROP TABLE dbatoolsci_schemachange_new")

# Tests!
invoke-item C:\github\dbatools\tests\Get-DbaSchemaChangeHistory.Tests.ps1
Invoke-Item C:\github\dbatools\tests

# Database clone
Invoke-DbaDbClone -SqlInstance $new -Database dbwithsprocs -CloneDatabase dbwithsprocs_clone

# Process exploration
Get-DbaProcess -SqlInstance $instance | Out-GridView

# More histories
Get-DbaAgentJobHistory -SqlInstance $instance | Out-GridView

# See protocols
Get-DbaServerProtocol -ComputerName $instance | Out-GridView

# In-depth spconfigure
Get-DbaSpConfigure -SqlInstance $instance | Out-GridView

# Get the registry root
Get-DbaRegistryRoot -ComputerName $instance

#region SPN
Start-Process "C:\Program Files\Microsoft\Kerberos Configuration Manager for SQL Server\KerberosConfigMgr.exe"

# No domain - let's watch a video!

$servers | Test-DbaSpn | Out-GridView -PassThru | Set-DbaSpn -WhatIf
Start-Process "C:\github\community-presentations\rob-sewell-chrissy-lemaire\belgium-spn.mp4"

#endregion


# Find-DbaStoredProcdure - @claudioessilva, @cl, Stephen Bennett
# 37,545 SQL Server stored procedures on 9 servers evaluated in 8.67 seconds!
$new | Find-DbaStoredProcedure -Pattern dbatools
$new | Find-DbaStoredProcedure -Pattern dbatools | Select * | Out-GridView
$new | Find-DbaStoredProcedure -Pattern '\w+@\w+\.\w+'

# Remove dat orphan - by @sqlstad
Find-DbaOrphanedFile -SqlInstance $instance | Out-GridView
((Find-DbaOrphanedFile -SqlInstance $instance -LocalOnly | Get-ChildItem | Select -ExpandProperty Length | Measure-Object -Sum)).Sum / 1MB
Find-DbaOrphanedFile -SqlInstance $instance -LocalOnly | Remove-Item -Whatif

# OGV madness
Get-DbaDatabase -SqlInstance $old | Out-GridView -PassThru | Copy-DbaDatabase -Destination $new -BackupRestore -SharedPath \\workstation\c$\temp -Force

# Find it! - JSON file powers command and website
Find-DbaCommand Backup
Find-DbaCommand -Tag Backup | Out-GridView

# Thanks, Fred! 
[dbainstance]"sql2016"
[dbainstance]"sqlcluster\sharepoint"

# Coming soon, more on Xevents!
Get-DbaXESession -SqlInstance $new
Get-DbaXESession -SqlInstance $new -Session system_health | Read-DbaXEFile
Get-DbaXESession -SqlInstance $new -Session system_health | Watch-DbaXESession | Select -ExpandProperty Fields

Invoke-Item C:\github\community-presentations\rob-sewell-chrissy-lemaire\belgium-watch-xeventsession.png










