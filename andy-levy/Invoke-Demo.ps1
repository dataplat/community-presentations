<#
PREFLIGHT:
Switch VSCode to Night Owl (colorblind) theme
Set font sizes
Start ZoomIt
Start SSMS w/ Object Explorer open

Reminder: Don't test in production!
#>






Install-module dbatools -Scope CurrentUser;
Update-Module dbatools -Verbose;
Import-Module dbatools;
Set-Location C:\;
Clear-Host;

# What SQL Servers exist?
# Can scan your whole network or a single computer
# Can scan each device several ways
Find-DbaInstance -ComputerName localhost;

# Found an instance BUT I can't get in!
Reset-DbaAdmin -SqlInstance localhost\sql16;

# Scan the instances to check what version & Service Pack/Cumulative Update level we're at
Test-DbaBuild -SqlInstance localhost\sql16, localhost\sql17 -Latest -Update;

# Update the SQL Server 2017 instance to the latest CU
Update-DbaInstance -ComputerName localhost -InstanceName SQL17 -Path C:\Updates;

# Let's connect to SQL Server
# First via SMO

Add-Type -AssemblyName "Microsoft.SqlServer.Smo,Version=11.0.0.0,Culture=neutral,PublicKeyToken=89845dcd8080cc91"
$SQL16 = New-Object Microsoft.SqlServer.Management.Smo.Server “localhost\sql16”

# Now via dbatools.
# Connect-DbaInstance lets us use SQL or Windows auth, even works with Azure & MFA!

$SQL16 = Connect-DbaInstance -SqlInstance localhost\SQL16 -ClientName "SQL Saturday";

# Look at server object
$SQL16

$SQL16 | Get-Member;

# Make sure Lock Pages in Memory and Instant File Initialization are set for my service account
# You may need to run winrm quickconfig to allow WinRM connections to the server first
Set-DbaPrivilege -ComputerName localhost -Type IFI, LPIM;

<#
WARNING: NT Service\MSSQL$SQL16 already has Instant File Initialization Privilege on WIN-0P9JV5IVQG2
WARNING: NT Service\MSSQL$SQL17 already has Instant File Initialization Privilege on WIN-0P9JV5IVQG2
WARNING: NT Service\MSSQL$SQL16 already has Lock Pages in Memory Privilege on WIN-0P9JV5IVQG2
WARNING: NT Service\MSSQL$SQL17 already has Lock Pages in Memory Privilege on WIN-0P9JV5IVQG2
#>

# Check some other configuration settings
Get-DbaSpConfigure -SqlInstance $SQL16 -Name DefaultBackupCompression, OptimizeAdhocWorkloads | Out-Gridview;
Set-DbaSpConfigure -SqlInstance $SQL16 -Name DefaultBackupCompression, OptimizeAdhocWorkloads -Value 1 -WhatIf;
Set-DbaSpConfigure -SqlInstance $SQL16 -Name DefaultBackupCompression, OptimizeAdhocWorkloads -Value 1;

# Install a few of our standard tools
Install-DbaFirstResponderKit -SqlInstance $SQL16 -Database Master -Branch master;
Install-DbaWhoIsActive -SqlInstance $SQL16 -Database Master;

# We can see the application name in sp_whoisactive output
Invoke-DbaWhoIsActive -SqlInstance $SQL16 -ShowOwnSpid | Out-Gridview;

# List all the user databases on the instance
Get-DbaDatabase -SqlInstance $SQL16 -ExcludeSystem;

# When did we last perform a backup?
Get-DbaDbBackupHistory -SqlInstance $SQL16;
Get-DbaDbBackupHistory -SqlInstance $SQL16 -Verbose;

# Where are the backups being written?
Get-DbaDefaultPath -SqlInstance $SQL16;
Invoke-Item (Get-DbaDefaultPath -SqlInstance $SQL16).Backup;

# When did we last run DBCC CHECKDB?
Get-DbaLastGoodCheckDb -SqlInstance $SQL16 -Verbose;

# Is anyone doing maintenance around here?
Get-DbaAgentJob -SqlInstance $SQL16;

# Install Ola Hallengren's Maintenance Solution
# Not using the Server object because reasons
# This is a bug, #5894
Install-DbaMaintenanceSolution -SqlInstance localhost\sql16 -Database Master -LogToTable -CleanupTime 25 -ReplaceExisting -InstallJobs -Solution All -Verbose;

# Using -Force here will set unspecified parameters to their defaults
# Most importantly, schedule start date will be today and the end will be 9999-12-31
$MinuteSchedule = New-DbaAgentSchedule -SqlInstance $SQL16 -Schedule EveryMinute -FrequencyType Daily -FrequencyInterval EveryDay -FrequencySubdayType Minutes -FrequencySubdayInterval 1 -Force;

$FiveMinuteSchedule = New-DbaAgentSchedule -SqlInstance $SQL16 -Schedule EveryFiveMinutes -FrequencyType Daily -FrequencyInterval EveryDay -FrequencySubdayType Minutes -FrequencySubdayInterval 5 -Force;

$TenMinuteSchedule = New-DbaAgentSchedule -SqlInstance $SQL16 -Schedule EveryTenMinutes -FrequencyType Daily -FrequencyInterval EveryDay -FrequencySubdayType Minutes -FrequencySubdayInterval 10 -Force;

$SQL16.JobServer.Jobs.Refresh();

# Assign the one-minute interval schedule to Transaction Log backups
Set-DbaAgentJob -Job "DatabaseBackup - USER_DATABASES - LOG" -SqlInstance $SQL16 -Schedule $MinuteSchedule;
# Assign the five-minute interval to Diff backups
Set-DbaAgentJob -Job "DatabaseBackup - USER_DATABASES - DIFF" -SqlInstance $SQL16 -Schedule $FiveMinuteSchedule;
# Assign the ten-minute interval to Full backups
Set-DbaAgentJob -Job "DatabaseBackup - USER_DATABASES - FULL" -SqlInstance $SQL16 -Schedule $TenMinuteSchedule;

# Run full backup job
$FullBackupJob = Get-DbaAgentJob -SqlInstance $SQL16 -Job "DatabaseBackup - USER_DATABASES - FULL";

# First let's look at the SMO object that was returned
$FullBackupJob;
$FullBackupJob.JobSchedules | Out-GridView;

# Now we can start it
# Two different ways!
$FullBackupJob.Start();
Start-DbaAgentJob -SqlInstance $SQL16 -Job "DatabaseBackup - USER_DATABASES - FULL"

# Add a couple more databases
Invoke-Item -Path C:\DataToImport\;
# What would the T-SQL look like?
Restore-DbaDatabase -SqlInstance $SQL16 -Path C:\DataToImport\CacheDB -DatabaseName CacheDB -MaintenanceSolutionBackup -RestoreTime '2019-07-11 21:50:00' -OutputScriptOnly;
# Let's restore 
Restore-DbaDatabase -SqlInstance $SQL16 -Path C:\DataToImport\CacheDB -DatabaseName CacheDB -MaintenanceSolutionBackup -Verbose -RestoreTime '2019-07-11 21:50:00';
<#
dbatools just:
* Looked through all the backups
* Found the latest FULL and all the T-Logs through the one immediately after the RestoreTime
* Restored the full chain right up to 21:50:00
#>
Restore-DbaDatabase -SqlInstance $SQL16 -Path C:\DataToImport\AdventureWorks2016.bak -DatabaseName AdventureWorks2016 -Verbose;

# Refresh instance-level details
$SQL16.Refresh();

# Refresh the list of databases
$SQL16.Databases.Refresh();

Get-DbaDatabase -SqlInstance $SQL16 | Out-GridView;

# What's our VLF situation?
# A VLF is created when the transaction log needs to grow
# If the growth increment is too small, we'll get lots of growth events and VLFs
# Large numbers of VLFs can make database startup, restore, and recovery slower
Measure-DbaDbVirtualLogFile -SqlInstance $SQL16 | Out-GridView;

# Let's look at the log size and growth settings
(Get-DbaDatabase -SqlInstance $sql16 -Database Movies).LogFiles | Select-Object -Property Name, Size, Growth, GrowthType | Format-Table -AutoSize;

# Not good! Let's compact those and reset to something more reasonable
# Shrink down to (we hope) 512MB, then re-expand back to 1024MB and then set a growth increment of 1024MB
Expand-DbaDbLogFile -SqlInstance $SQL16 -Database Movies -ShrinkLogFile -ShrinkSize 16 -TargetLogSize 1024 -IncrementSize 1024;

# For more about VLFs, check out https://www.sqlskills.com/blogs/kimberly/transaction-log-vlfs-too-many-or-too-few/ & https://www.sqlskills.com/blogs/paul/important-change-vlf-creation-algorithm-sql-server-2014/

# Test our database backups
Test-DbaLastBackup -SqlInstance $SQL16 -Database CacheDB -Verbose;

# Create new login
# Works for Windows Auth too!
New-DbaLogin -SqlInstance $SQL16 -Login "SQLSat" -PasswordExpiration:$false -PasswordPolicy:$false

Set-DbaLogin -SqlInstance $SQL16 -Login SQLSat -AddRole serveradmin, sysadmin

# Let's migrate to SQL Server 2017!
$SQL17 = Connect-DbaInstance -SqlInstance localhost\sql17 -ClientName "SQL Saturday";

Copy-DbaDatabase -Database CacheDB -Source $SQL16 -Destination $SQL17 -BackupRestore -SharedPath C:\SQLMigration -WithReplace -Verbose;

# Copy SQL Login
Get-DbaLogin -SqlInstance $SQL17 -Login "SQLSat"
Copy-DbaLogin -Source $SQL16 -Destination $SQL17 -Login SQLSat;
Get-DbaLogin -SqlInstance $SQL17 -Login "SQLSat"


Invoke-Item -Path C:\SQLMigration\;

# Passwords are hashed!
Export-DbaLogin -SqlInstance $SQL16 -Path C:\SQLMigration;
Export-DbaSpConfigure $SQL16 -Path C:\SQLMigration;
Get-DbaDbMailConfig -SqlInstance $SQL16 | Export-DbaScript -Path C:\SQLMigration;
Copy-DbaAgentJob -Source $SQL16 -Destination $SQL17 -DisableOnDestination

# Export everything for DR purposes
Export-DbaInstance -SqlInstance localhost\sql16 -Path C:\SQLMigration -Verbose -ErrorAction SilentlyContinue;

# Let's just move everything over
Start-DbaMigration -Source $SQL16 -Destination $SQL17 -SetSourceReadOnly -DisableJobsOnSource -DisableJobsOnDestination -BackupRestore -SharedPath C:\SQLMigration -Force -Verbose;

#####################

# Additional demos if we have time

# Check our max server memory
# This uses Jonathan Kehiyas's formula https://www.sqlskills.com/blogs/jonathan/how-much-memory-does-my-sql-server-actually-need/
Test-DbaMaxMemory -SqlInstance $SQL16;

# Can pipe the output of this function right into setting the max memory
Test-DbaMaxMemory -SqlInstance $SQL16 | Set-DbaMaxMemory -SqlInstance $SQL16 -Verbose;

# Work with database snapshots
Find-DbaCommand Snapshot;

New-DbaDbSnapshot -Database Movies -Name SQLSat;
Get-DbaDbSnapshot -Database Movies;

# TODO: Alter some data & show it
# Restoring the snapshot reverts
Restore-DbaDbSnapshot -Database Movies -Snapshot SQLSat;

# TODO: Show the data is reverted

# Removing the snapshot commits the changes
Remove-DbaDbSnapshot -Database Movies -Snapshot SQLSat;

# Create a new database for IMDB data
New-DbaDatabase -Name Movies -PrimaryFilesize 1024 -PrimaryFileGrowth 1024 -LogSize 16 -LogGrowth 16;

# Create a new database for Satellite data
New-DbaDatabase -Name Satellites -PrimaryFilesize 1024 -PrimaryFileGrowth 1024 -LogSize 16 -LogGrowth 16;

# Import some satellite data here


$SQL17.JobServer.Refresh();
Get-DbaAgentJob -SqlInstance $SQL17 | Foreach-object { $PSItem.IsEnabled = $true; $PSItem.Alter(); }

# Because MAXDOP is now a database-scoped configuration, each user DB is reported here
# MAXDOP is a database-scoped configuration so we can set it at the instance level but it may be overridden
Test-DbaMaxDop -SqlInstance $SQL16;

# We can do this at the instance level, or for individual databases, or for all databases
Set-DbaMaxDop -SqlInstance $SQL16 -MaxDop 8 -whatif;
Set-DbaMaxDop -SqlInstance $SQL16 -MaxDop 2 -Database Movies -verbose -whatif;

Set-DbaMaxDop -SqlInstance $SQL16 -MaxDop 2 -verbose;
Test-DbaMaxDop -SqlInstance $SQL16;

$SQL16.Refresh();
Test-DbaMaxDop -SqlInstance $SQL16;

$Cred = Get-Credential -UserName "SQLSat" -Message "SQL Authentication";
$SQL17 = Connect-DbaInstance -SqlInstance localhost\sql17 -SqlCredential $Cred

# Work with backups
Get-DbaDbBackupHistory

# Let's look at settings through SMO
$SQL16Instance.Settings;

# Switch to Mixed authentication mode
# Thanks to https://kushagrarakesh.blogspot.com/2018/07/change-sql-servers-authentication-mode.html
$SQL16Instance.Settings.LoginMode = [Microsoft.SqlServer.Management.SMO.ServerLoginMode]::Mixed;

# Changes have to be committed back to the instance
# Do I need a restart here? Yes!
$SQL16Instance.Alter();

$SQL16Instance = Connect-DbaInstance -SqlInstance ctx1315\sql16 -SqlCredential (Get-Credential -UserName "SQLSat" -Message "Welcome to SQL Saturday!");

$PSDefaultParameterValues['*:SqlInstance'] = $SQL16Instance;

# Let's change that
$SQL16Instance.Settings.BackupDirectory = 'TODO';
$SQL16Instance.Alter();

# Export DBA Instance stuff (for DR)

# Copy database - defaults to copy-only backup

# Copy table schema

# Copy table data

# Look at table schema, indexes, constraints

# Migrate 2016 to 2017