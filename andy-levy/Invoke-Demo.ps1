Install-module dbatools;
update-module dbatools;
$VerbosePreference = 'SilentlyContinue';
import-module dbatools -Verbose:$false;
$VerbosePreference = 'Continue';

# Set this to your dev instance for safety
$PSDefaultParameterValues['*:SqlInstance'] = 'ctx1315\sql16';

$WhatIfPreference = $true;

# TODO: Answer questions in the abstract

Find-DbaInstance -ComputerName localhost;
Reset-DbaAdmin -SqlInstance localhost\sql16;
Test-DbaBuild -SqlInstance localhost\sql16, localhost\sql17 -Latest -Update;
Update-DbaInstance -ComputerName localhost -InstanceName SQL17;
$SQL16 = Connect-DbaInstance -SqlInstance localhost\SQL16;
Get-DbaDatabase -sqlinstance $SQL16;
Get-DbaLastGoodCheckDb -SqlInstance $SQL16;
Get-DbaDbBackupHistory -SqlInstance $SQL16;
Get-DbaAgentJob -SqlInstance $SQL16;
Install-DbaMaintenanceSolution -SqlInstance $SQL16 -Database Master -BackupLocation c:\sqlbackup\sql16 -CleanupTime 25 -ReplaceExisting -InstallJobs -Solution All;
Install-DbaFirstResponderKit -SqlInstance $SQL16 -Database Master -Branch master;
Install-DbaWhoIsActive -SqlInstance $SQL16 -Database master;
# TODO: Set these two
Test-DbaMaxMemory -SqlInstance $SQL16;
Test-DbaMaxDop -SqlInstance $SQL16;
Measure-DbaDbVirtualLogFile -SqlInstance $SQL16;
Expand-DbaDbLogFile -SqlInstance $SQL16 -database movies -ShrinkLogFile -TargetLogSize 1024 -IncrementSize 1024;

# TODO: Test backups


# Work this in
# Reset-DbaAdmin

$Cred = Get-Credential -UserName "sa" -Message "Container SA";
$sql17 = Connect-DbaInstance -SqlInstance "localhost,14337" -SqlCredential $Cred
$sql19 = Connect-DbaInstance -SqlInstance "localhost,14339" -SqlCredential $Cred

# How many instances of SQL Server are on my laptop?
Find-DbaInstance -ComputerName ctx1315;

# Break into one of the instances
Reset-DbaAdmin -WhatIf

# What versions am I running?
Test-DbaBuild -Latest -SqlInstance ctx1315\sql16, ctx1315\sql17 -Update;

# Connect to the server
# TODO: Show connecting via SMO first
$SQL16Instance = Connect-DbaInstance -SqlInstance ctx1315\sql16;

# Work with backups
Get-DbaDbBackupHistory

# Test last backup
Test-DbaLastBackup

# Restore point in time

# Check up on DBCC status
Get-DbaLastGoodCheckDB

# Make sure Lock Pages in Memory and Instant File Initialization are set for my service account
# You may need to run winrm quickconfig to allow WinRM connections to the server first
Set-DbaPrivilege -ComputerName ctx1315 -Type IFI, LPIM;

# TODO: POke around in server object

New-DbaLogin -SqlInstance $SQL16Instance -Login "SQLSat" -PasswordExpiration:$false -PasswordPolicy:$false

# Let's look at settings through SMO
$SQL16Instance.Settings;

# Switch to Mixed authentication mode
# Thanks to https://kushagrarakesh.blogspot.com/2018/07/change-sql-servers-authentication-mode.html
$SQL16Instance.Settings.LoginMode = [Microsoft.SqlServer.Management.SMO.ServerLoginMode]::Mixed;

# Changes have to be committed back to the instance
$SQL16Instance.Alter();

# Do I need a restart here? Yes!
$SQL16Instance = Connect-DbaInstance -SqlInstance ctx1315\sql16 -SqlCredential (Get-Credential -UserName "SQLSat" -Message "Welcome to SQL Saturday!");

Get-DbaLogin -SqlInstance $SQL16Instance -Login SQLSat
Set-DbaLogin -SqlInstance $SQL16Instance -Login SQLSat -AddRole serveradmin, sysadmin

$PSDefaultParameterValues['*:SqlInstance'] = $SQL16Instance;

# Check configured maximum server memory against Jonathan Kehiyas's recommended formula
Test-DbaMaxMemory;
# TODO: Missing the $MaxMemory step
# TODO: Maybe show SMO?
# TODO: Show Set-DbaSpConfigure
# TODO: Show Invoke-DbaQuery w/ sp_configure
Test-DbaMaxMemory | Set-DbaMaxMemory -Max $MaxMemory -WhatIf;

# Because MAXDOP is now a database-scoped configuration, each user DB is reported here
Test-DbaMaxDop;

# We can do this at the instance level, or for individual databases, or for all databases
Set-DbaMaxDop -MaxDop 8 -whatif;
Set-DbaMaxDop -MaxDop 8 -AllDatabases -whatif;
Set-DbaMaxDop -MaxDop 2 -Database SSISDB -whatif;

# Check some other configuration settings
Get-DbaSpConfigure -Name RemoteDacConnectionsEnabled, DefaultBackupCompression, OptimizeAdhocWorkloads
Set-DbaSpConfigure -Name RemoteDacConnectionsEnabled, DefaultBackupCompression, OptimizeAdhocWorkloads -Value 1 -WhatIf

# We can install Brent Ozar's First Responder Kit to any database, and select the release or development branch
Install-DbaFirstResponderKit -Database master;

# We can install Adam Machanic's sp_whoisactive
Install-DbaWhoIsActive -Database master;

# And then we can execute it, including with filters
Invoke-DbaWhoIsActive -ShowOwnSpid | Out-GridView;

# We can install Ola Hallengren's maintenance solution
# Can select everything, or just a portion - Backup, Integrity Check, IndexOptimize
Install-DbaMaintenanceSolution -Database master -CleanupTime 25 -InstallJobs -ReplaceExisting;

# But it's not enough to install the solution and jobs, the jobs need to be scheduled!
Get-DbaAgentJob
# TODO: Show there are no schedules

# Using -Force here will set unspecified parameters to their defaults
# Most importantly, schedule start date will be today and the end will be 9999-12-31
$MinuteSchedule = New-DbaAgentSchedule -Schedule EveryMinute -FrequencyType Daily -FrequencyInterval EveryDay -FrequencySubdayType Minutes -FrequencySubdayInterval 1 -Force;
$FiveMinuteSchedule = New-DbaAgentSchedule -Schedule EveryMinute -FrequencyType Daily -FrequencyInterval EveryDay -FrequencySubdayType Minutes -FrequencySubdayInterval 5 -Force;
$TenMinuteSchedule = New-DbaAgentSchedule -Schedule EveryMinute -FrequencyType Daily -FrequencyInterval EveryDay -FrequencySubdayType Minutes -FrequencySubdayInterval 10 -Force;

# Assign the one-minute interval schedule to Transaction Log backups
# Assign the five-minute interval to Diff backups
# Assign the ten-minute interval to Full backups

# Where are the backups being written?
Get-DbaDefaultPath

# Let's change that
$SQL16Instance.Settings.BackupDirectory = 'TODO';
$SQL16Instance.Alter();

# Create a new database for IMDB data
New-DbaDatabase -Name Movies -PrimaryFilesize 1024 -PrimaryFileGrowth 1024 -LogSize 16 -LogGrowth 16;

# Create a new database for Satellite data
New-DbaDatabase -Name Satellites -PrimaryFilesize 1024 -PrimaryFileGrowth 1024 -LogSize 16 -LogGrowth 16;

# Import some satellite data here

<#
(get-dbadatabase -database movies).logfiles[0] | select size, usedspace
Test-DbaDbVirtualLogFile -Database Movies
Expand-DbaDbLogFile -Database Movies -TargetLogSize 1024 -ShrinkLogFile -WhatIf
#>

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


# Export DBA Instance stuff (for DR)

# Copy database - defaults to copy-only backup

# Copy table schema

# Copy table data

# Look at table schema, indexes, constraints

# Migrate 2016 to 2017