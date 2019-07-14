Install-module dbatools -Scope CurrentUser;
update-module dbatools;
import-module dbatools;

# What SQL Servers exist?
# Can scan your whole network or a single computer
# Can scan each device several ways
Find-DbaInstance -ComputerName localhost;

# Found an instance BUT I can't get in!
# Let's reset the sa password
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

# TODO: Poke around in server object

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
Get-DbaSpConfigure -sqlinstance $SQL16 -Name RemoteDacConnectionsEnabled, DefaultBackupCompression, OptimizeAdhocWorkloads
Set-DbaSpConfigure -SQLInstance $SQL16 -Name RemoteDacConnectionsEnabled, DefaultBackupCompression, OptimizeAdhocWorkloads -Value 1 -WhatIf

# Install a few of our standard tools
Install-DbaFirstResponderKit -SqlInstance $SQL16 -Database Master -Branch master;
Install-DbaWhoIsActive -SqlInstance $SQL16 -Database Master;

# We can see the application name in sp_whoisactive output
Invoke-DbaWhoIsActive -SqlInstance $SQL16 -ShowOwnSpid;
Invoke-DbaWhoIsActive -SqlInstance $SQL16 -ShowOwnSpid | Out-Gridview;

# List all the user databases on the instance
Get-DbaDatabase -sqlinstance $SQL16 -ExcludeSystem;

# When did we last run DBCC CHECKDB?
Get-DbaLastGoodCheckDb -SqlInstance $SQL16;

# When did we last perform a backup?
Get-DbaDbBackupHistory -SqlInstance $SQL16;

# Is anyone doing maintenance around here?
Get-DbaAgentJob -SqlInstance $SQL16;

# Install Ola Hallengren's Maintenance Solution
Install-DbaMaintenanceSolution -SqlInstance $SQL16 -Database Master -BackupLocation c:\sqlbackup\sql16 -CleanupTime 25 -ReplaceExisting -InstallJobs -Solution All -Verbose;

<#
Exception!
PS C:\Users\andy\Documents\GitHub\community-presentations\andy-levy> Install-DbaMaintenanceSolution -SqlInstance $SQL16 -Database Master -BackupLocation c:\sqlbackup\sql16 -CleanupTime 25 -ReplaceExisting -InstallJobs -Solution All -Verbose;
VERBOSE: GET https://github.com/olahallengren/sql-server-maintenance-solution/archive/master.zip with 0-byte payload
VERBOSE: received -1-byte response of content type application/zip
VERBOSE: Performing the operation "Dropping all objects created by Ola's Maintenance Solution" on target "WIN-0P9JV5IVQG2\sql16".
VERBOSE: Performing the operation "Installing MaintenanceSolution.sql" on target "WIN-0P9JV5IVQG2\sql16".
WARNING: [14:08:18][Install-DbaMaintenanceSolution] Could not execute MaintenanceSolution.sql in Master on WIN-0P9JV5IVQG2\sql16 | Invalid object name '#Config'.

ComputerName    InstanceName SqlInstance           Results
------------    ------------ -----------           -------
WIN-0P9JV5IVQG2 SQL16        WIN-0P9JV5IVQG2\sql16 Success
#>

# Using -Force here will set unspecified parameters to their defaults
# Most importantly, schedule start date will be today and the end will be 9999-12-31
$MinuteSchedule = New-DbaAgentSchedule -SqlInstance $SQL16 -Schedule EveryMinute -FrequencyType Daily -FrequencyInterval EveryDay -FrequencySubdayType Minutes -FrequencySubdayInterval 1 -Force;

$FiveMinuteSchedule = New-DbaAgentSchedule -SqlInstance $SQL16 -Schedule EveryFiveMinutes -FrequencyType Daily -FrequencyInterval EveryDay -FrequencySubdayType Minutes -FrequencySubdayInterval 5 -Force;

$TenMinuteSchedule = New-DbaAgentSchedule -SqlInstance $SQL16 -Schedule EveryTenMinutes -FrequencyType Daily -FrequencyInterval EveryDay -FrequencySubdayType Minutes -FrequencySubdayInterval 10 -Force;

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

# Now we can start it
$FullBackupJob.Start();

# Because MAXDOP is now a database-scoped configuration, each user DB is reported here
# MAXDOP is a database-scoped configuration so we can set it at the instance level but it may be overridden
Test-DbaMaxDop -SqlInstance $SQL16;

# We can do this at the instance level, or for individual databases, or for all databases
Set-DbaMaxDop -sqlinstance $sql16 -MaxDop 8 -whatif;
Set-DbaMaxDop -sqlinstance $sql16 -MaxDop 8 -AllDatabases -whatif;
Set-DbaMaxDop -sqlinstance $sql16 -MaxDop 2 -Database Movies -verbose -whatif;
Test-DbaMaxDop -SqlInstance $SQL16 | Set-DbaMaxDop -sqlinstance $sql16 -MaxDop 2 -Database Movies -verbose;
$SQL16.Refresh();
Test-DbaMaxDop -SqlInstance $SQL16

# Check our max server memory
# This uses Jonathan Kehiyas's formula https://www.sqlskills.com/blogs/jonathan/how-much-memory-does-my-sql-server-actually-need/
Test-DbaMaxMemory -SqlInstance $SQL16;

# Can pipe the output of this function right into setting the max memory
Test-DbaMaxMemory -sqlinstance $SQL16 | Set-DbaMaxMemory -sqlinstance $SQL16 -WhatIf;
Test-DbaMaxMemory -sqlinstance $SQL16 | Set-DbaMaxMemory -sqlinstance $SQL16 -Verbose;

# Check power settings
Test-DbaPowerPlan -ComputerName localhost;
Set-DbaPowerPlan -ComputerName localhost -PowerPlan "High Performance";
<#
See Issue #5895 for request to add pipeline support.
https://github.com/sqlcollaborative/dbatools/issues/5895
#>

# Add a couple more databases
invoke-item C:\DataToImport\CacheDB;
# What would the T-SQL look like?
Restore-DbaDatabase -SqlInstance $SQL16 -Path C:\DataToImport\CacheDB -DatabaseName CacheDB -MaintenanceSolutionBackup -RestoreTime '2019-07-11 21:50:00' -OutputScriptOnly;
# Let's restore 
Restore-DbaDatabase -SqlInstance $SQL16 -Path C:\DataToImport\CacheDB -DatabaseName CacheDB -MaintenanceSolutionBackup -Verbose -RestoreTime '2019-07-11 21:50:00';
<#
dbatools:
* Looked through all the backups
* Found the latest FULL and all the T-Logs through the one immediately after the RestoreTime
* Restored the full chain right up to 21:50:00
#>
Restore-DbaDatabase -SqlInstance $SQL16 -Path C:\DataToImport\AdventureWorks2016.bak -DatabaseName AdvetureWorks2016 -Verbose;

# Refresh instance-level details
$SQL16.Refresh();

# Refresh the list of databases
$SQL16.Databases.Refresh();

Get-DbaDatabase -SqlInstance $SQL16;

# What's our VLF situation?
Measure-DbaDbVirtualLogFile -SqlInstance $SQL16 | Out-GridView;

# Not good! Let's compact those and reset to something more reasonable
# Shrink down to (we hope) 512MB, then re-expand back to 1024MB and then set a growth increment of 1024MB
Expand-DbaDbLogFile -SqlInstance $SQL16 -database movies -ShrinkLogFile -shrinksize 512 -TargetLogSize 1024 -IncrementSize 1024;

Measure-DbaDbVirtualLogFile -SqlInstance $SQL16 | select-object -property * | Out-GridView;


# Test our database backups
Test-DbaLastBackup -SqlInstance $SQL16 -Database Movies;

# TODO: Database snapshots

# Create new login
# Works for Windows Auth too!
New-DbaLogin -SqlInstance $SQL16 -Login "SQLSat" -PasswordExpiration:$false -PasswordPolicy:$false

Get-DbaLogin -SqlInstance $SQL16 -Login SQLSat;
Set-DbaLogin -SqlInstance $SQL16 -Login SQLSat -AddRole serveradmin, sysadmin


# Let's migrate to SQL Server 2017!
New-Item -ItemType Directory -Path C:\SQLMigration;

$SQL17 = Connect-DbaInstance -SqlInstance localhost\sql17 -ClientName "SQL Saturday";

Copy-DbaDatabase -Database Movies -Source $SQL16 -Destination $SQL17 -BackupRestore -SharedPath C:\SQLMigration -SetSourceReadOnly -WithReplace;

# Copy SQL Login
Copy-DbaLogin -Source $SQL16 -Destination $SQL17 -Login SQLSat;
Get-DbaLogin -SqlInstance $SQL17 -Login "SQLSat"

# Passwords are hashed!
Export-DbaLogin -SqlInstance $SQL16 -Path C:\SQLMigration;
Export-DbaSpConfigure $SQL16 -Path C:\SQLMigration;
Get-DbaDbMailConfig -SqlInstance $SQL16 | Export-DbaScript -Path C:\SQLMigration;
Copy-DbaAgentJob -Source $SQL16 -Destination $SQL17 -DisableOnSource -DisableOnDestination

# Optional: Export-DbaInstance -SqlInstance $SQL16 -Path C:\SQLMigration;

# Let's just move everything over
Start-DbaMigration -Source $SQL16 -Destination $SQL17 -SetSourceReadOnly -DisableJobsOnSource -DisableJobsOnDestination -BackupRestore -SharedPath C:\SQLMigration -Force -Verbose;

#####################


$Cred = Get-Credential -UserName "sa" -Message "Container SA";
$sql17 = Connect-DbaInstance -SqlInstance "localhost,14337" -SqlCredential $Cred
$sql19 = Connect-DbaInstance -SqlInstance "localhost,14339" -SqlCredential $Cred


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