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
$new = "sql2016"
$old = $instance = "localhost"
$allservers = Get-DbaRegisteredServer -SqlInstance sql2014
$allservers = $allservers, "sql2014"

# disk space
$allservers  | Get-DbaDiskSpace | Out-GridView

# db space
Get-DbaDatabaseSpace -SqlInstance $old -IncludeSystemDBs | Out-GridView

# network latency
$allservers | Test-DbaNetworkLatency | Out-GridView

#region backuprestore

# standard
Restore-DbaDatabase -SqlInstance $instance -Path "C:\temp\backups\dbatoolsci_singlerestore_201710010039.bak"
Restore-DbaDatabase -SqlInstance $instance -Path "C:\temp\AdventureWorks2012-Full Database Backup.bak" -WithReplace

# ola!
Invoke-Item \\nas\sql\SQL2012\WSS_Content
Invoke-Item \\nas\sql\SQL2012\
Get-ChildItem -Directory \\nas\sql\SQL2012\ | Restore-DbaDatabase -SqlInstance localhost\sql2016

# What about backups?
Get-DbaDatabase -SqlInstance $instance -Database SharePoint_Config | Backup-DbaDatabase -BackupDirectory C:\temp

Get-Help Test-DbaLastBackup -Online
Test-DbaLastBackup -SqlInstance sql2016 -Destination localhost\sql2016 | Out-GridView

#endregion



# Exports
Export-DbaLogin -SqlInstance $instance -Path C:\temp\logins.sql
Invoke-Item C:\temp\logins.sql

# Other Exports
Get-DbaAgentJob -SqlInstance sql2016 | Export-DbaScript -Path C:\temp\jobs.sql

# In-depth spconfigure
Get-DbaSpConfigure -SqlInstance $instance | Out-GridView

# Reset-SqlAdmin
Reset-SqlAdmin -SqlInstance $instance -Login sqladmin -Verbose

# Build ref!
$allservers | Get-DbaSqlBuildReference | Format-Table

# SQL Modules - View, TableValuedFunction, DefaultConstraint, StoredProcedure, Rule, InlineTableValuedFunction, Trigger, ScalarFunction
Get-DbaSqlModule -SqlInstance $instance | Out-GridView
Get-DbaSqlModule -SqlInstance $instance -ModifiedSince (Get-Date).AddDays(-7) | Select-String -Pattern sp_executesql

# Reads trace files - default trace by default
Read-DbaTraceFile -SqlInstance $instance | Out-GridView

# Uses xp_dirtree
Get-DbaFile -SqlInstance $instance | Out-GridView
Get-DbaFile -SqlInstance $instance -Path C:\temp | Out-GridView
Get-DbaFile -SqlInstance $instance -Path C:\temp -Depth 3 | Out-GridView

# Network Encryption
# - Requires a certificate with DNS names (complex)
# - Requires specific properties in the certificate
# - Requires that the service account have read access to the private key
# - Clusters cannot be configured via the SQL Configuration Manager

Start-Process "C:\github\community-presentations\constantine-kokkinos-chrissy-lemaire\baton-rouge-forcednetwork.mp4"

# Find failed jobs
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
Get-DbaSchemaChangeHistory -SqlInstance $new | Out-GridView
$db.Query("DROP TABLE dbatoolsci_schemachange_new")

# Tests!
invoke-item C:\github\dbatools\tests\Get-DbaSchemaChangeHistory.Tests.ps1
Invoke-Item C:\github\dbatools\tests

# Database clone
Invoke-DbaDatabaseClone -SqlInstance sql2017 -Database clonemebaw -CloneDatabase clonemebaw_clone
Remove-DbaDatabase -SqlInstance sql2017 -Database clonemebaw_clone 

# Process exploration
Get-DbaProcess -SqlInstance sql2016

# More histories
Get-DbaAgentJobHistory -SqlInstance sql2016 | Out-GridView

# See protocols
Get-DbaServerProtocol -ComputerName sql2016, sql2017 | Out-GridView

# Get the registry root
Get-DbaSqlRegistryRoot -ComputerName $instance

#region SPN
Start-Process "C:\Program Files\Microsoft\Kerberos Configuration Manager for SQL Server\KerberosConfigMgr.exe"

# No domain - let's watch a video!

$servers | Test-DbaSpn | Out-GridView -PassThru | Set-DbaSpn -WhatIf
Start-Process "C:\github\community-presentations\constantine-kokkinos-chrissy-lemaire\baton-rouge-spn.mp4"

#endregion


# Remove dat orphan - by @sqlstad
Find-DbaOrphanedFile -SqlInstance $instance | Out-GridView
((Find-DbaOrphanedFile -SqlInstance $instance -LocalOnly | Get-ChildItem | Select -ExpandProperty Length | Measure-Object -Sum)).Sum / 1MB
Find-DbaOrphanedFile -SqlInstance $instance -LocalOnly | Remove-Item -Whatif

# OGV madness
Get-DbaDatabase -SqlInstance $old | Out-GridView -PassThru | Copy-DbaDatabase -Destination $new -BackupRestore -NetworkShare \\workstation\c$\temp -Force

# Find it! - JSON file powers command and website
Find-DbaCommand Backup
Find-DbaCommand -Tag Backup | Out-GridView

# Thanks, Fred! 
[dbainstance]"sql2016"
[dbainstance]"sqlcluster\sharepoint"

# Coming soon, more on Xevents!
Get-DbaXEventSession -SqlInstance $new
Get-DbaXEventSession -SqlInstance $new -Session system_health | Read-DbaXEventFile
Get-DbaXEventSession -SqlInstance $new -Session system_health | Watch-DbaXEventSession | Select -ExpandProperty Fields

Invoke-Item C:\github\community-presentations\constantine-kokkinos-chrissy-lemaire\baton-rouge-watch-xeventsession.png


# Find-DbaStoredProcdure - @claudioessilva, @cl, Stephen Bennett
# 37,545 SQL Server stored procedures on 9 servers evaluated in 8.67 seconds!
$new | Find-DbaStoredProcedure -Pattern dbatools
$new | Find-DbaStoredProcedure -Pattern dbatools | Select * | Out-GridView
$new | Find-DbaStoredProcedure -Pattern '\w+@\w+\.\w+'