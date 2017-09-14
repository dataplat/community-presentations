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

Test-DbaLastBackup -SqlInstance $instance | Out-GridView
Test-DbaLastBackup -SqlInstance $old -Destination $new -VerifyOnly | Out-GridView

#endregion


#region mindblown

# Find-DbaStoredProcdure - @claudioessilva, @cl, Stephen Bennett
# 37,545 SQL Server stored procedures on 9 servers evaluated in 8.67 seconds!

$new | Get-DbaDatabase -ExcludeDatabase anotherdb -NoSystemDb | Remove-DbaDatabase | Out-Null
$new | Find-DbaStoredProcedure -Pattern dbatools
$new | Find-DbaStoredProcedure -Pattern dbatools | Select * | Out-GridView
$new | Find-DbaStoredProcedure -Pattern '\w+@\w+\.\w+'

# Remove dat orphan - by @sqlstad
Find-DbaOrphanedFile -SqlInstance $instance | Out-GridView
((Find-DbaOrphanedFile -SqlInstance $instance -LocalOnly | Get-ChildItem | Select -ExpandProperty Length | Measure-Object -Sum)).Sum / 1MB
Find-DbaOrphanedFile -SqlInstance $instance -LocalOnly | Remove-Item -Whatif

# Reset-SqlAdmin
Reset-SqlAdmin -SqlInstance $instance -Login sqladmin -Verbose

#endregion

# Exports
Get-DbaDatabase -SqlInstance $old | Export-DbaScript
$options = New-DbaScriptingOption
$options.ScriptDrops = $false
$options.WithDependencies = $true
Get-DbaAgentJob -SqlInstance $old | Export-DbaScript -ScriptingOptionsObject $options

# Build ref!
$allservers | Get-DbaSqlBuildReference | Format-Table

# Identity usage
Test-DbaIdentityUsage -SqlInstance $instance | Out-GridView

# Execution plan export
Get-DbaExecutionPlan -SqlInstance $instance -Database ReportServer | Export-DbaExecutionPlan -Path C:\temp

# OGV madness
Get-DbaDatabase -SqlInstance $old | Out-GridView -PassThru | Copy-DbaDatabase -Destination $new -BackupRestore -NetworkShare \\workstation\c$\temp

#
Get-DbaSqlModule -ModifiedSince (Get-Date).AddDays(-1) | Select-String -Pattern sp_executesql
Export-DbaLogin
Read-DbaTraceFile
Get-DbaFile
Get-DbaSchemaChangeHistory
Get-DbaProcess
Get-DbaAgentJobHistory
Get-DbaServerProtocol
Get-DbaSpConfigure
Get-DbaSqlRegistryRoot
Get-DbaForceNetworkEncryption

#region SPN
Start-Process "C:\Program Files\Microsoft\Kerberos Configuration Manager for SQL Server\KerberosConfigMgr.exe"

# No domain - let's watch a video!

$servers | Test-DbaSpn | Out-GridView -PassThru | Set-DbaSpn #-WhatIf
Start-Process "C:\github\community-presentations\constantine-kokkinos-chrissy-lemaire\spn.mp4"

#endregion

# Find it! - JSON file powers command and website
Find-DbaCommand Backup
Find-DbaCommand -Tag Backup | Out-GridView