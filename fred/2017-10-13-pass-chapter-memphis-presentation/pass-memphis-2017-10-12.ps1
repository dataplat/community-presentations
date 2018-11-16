# Failsafe
break

# Step 1: Introductions
# Step 2: Context
<#
Objectives

dbatools vs. SqlServer Module
- History
- Positioning / Role

The Community
- dbatools.io
- github
- slack

                                    dbatools Resources
                       dbatools.io/commands | List of commands
                        dbatools.io/offline | Installation instructions
                          dbatools.io/slack | Get in contact with us
                          dbatools.io/agent | Setting up PowerShell agent tasks (See Step 8)
github.com/sqlcollaborative/dbatools/issues | Report a bug, bring a feature request
#>

#---------------------------#
# Step 3: PowerShell basics #

# a) Google for PowerShell
Get-Command | Measure-Object
Get-Command *database*
# Hint: Use Verbs
Get-Command Get-*database*
# Hint2: Use Prefix
Get-Command Get-Dba*database*

# b) Help!
Get-Help dir
Get-Help dir -Examples


#-------------------------------#
# Step 4: dbatools preparations #

<#
Prerequisites
- PowerShell v3+
- When running on SQL Server directly: Elevation ("Run As Administrator" ; some commands require it for running against local server)
#>

# Requires Internet and not available by default on older PowerShell versions
Install-Module dbatools
# See website for install instructions if this is not an option for you

Import-Module dbatools


#----------------------------#
# Step 5: Database Migration #
Get-Command Copy-Dba*
Get-Help Copy-DbaDatabase -Examples

# Check source Database
Get-DbaDatabase -SqlInstance sql2014 | ft
Get-DbaDatabase -SqlInstance sql2014 -Database DBA

# Check destination for Database
Get-DbaDatabase -SqlInstance sql2016 -Database DBA

# Do it
Copy-DbaDatabase -Source sql2014 -Destination sql2016 -Database DBA -BackupRestore -SharedPath \\sql2014\Migration
Get-DbaDatabase -SqlInstance sql2016 | ft
Get-DbaDatabase -SqlInstance sql2016 -Database DBA

# OK, maybe undo the change before Chrissy notices
Get-DbaDatabase -SqlInstance sql2016 -Database DBA | Remove-DbaDatabase

# Dummy-Code, but demonstrates scaling up
Import-Csv C:\migration\mapping.csv | ForEach-Object {
    Copy-DbaDatabase -Source $_.SourceInstance -Destination $_.DestinationInstance -Database $_.Database -BackupRestore -SharedPath \\sql2014\Migration
}


#------------------------------#
# Step 6: Maintenance & Health #

# Connect to instance
$server = Connect-DbaInstance -SqlInstance sql2014
# Silence is golden, exception is OH NOES!
$server.Query("dbcc checkdb ([DBA])")

# Who likes waiting?
Get-DbaWaitStatistic -SqlInstance sql2016 -IncludeIgnorable | ft

# Ever heard of Glenn Berry?
# This would run them all, but we don't have the time for it
$tests = Invoke-DbaDiagnosticQuery -SqlInstance sql2016
$tests | ft
# Don't want to run the entire set of queries?
Invoke-DbaDiagnosticQuery -SqlInstance sql2016 -UseSelectionHelper
# There's also an export available. Will create a CSV per test in folder
Invoke-DbaDiagnosticQuery -SqlInstance sql2016 -UseSelectionHelper | Export-DbaDiagnosticQuery -Path C:\temp\glenn
explorer C:\temp\Glenn

# Who is active on my system?!
Install-DbaWhoIsActive -SqlInstance sql2016 -Database master
Find-DbaStoredProcedure -SqlInstance sql2016 -IncludeSystemDatabases -Database master -Pattern "Adam Machanic"
Invoke-DbaWhoisActive -SqlInstance sql2016 -ShowSystemSpids | ft
get-help Get-DbaCmsRegServer -Examples
Get-DbaCmsRegServer -SqlInstance sqlserver2014a | Install-DbaWhoIsActive -Database master
# Adam Machanic, supporting dbas since 2007 and still rocking
# Visit him on http://whoisactive.com

# What size is this?
Get-DbaDbSpace -SqlInstance sql2016 -IncludeSystemDBs | Out-GridView
Get-DbaDiskSpace -ComputerName sql2014 -CheckForSql


#--------------------------#
# Step 7: Backup & Restore #

# When was the last backup?
Get-DbaBackupHistory -SqlInstance sql2016 -Last

# All in one command
Get-Help Test-DbaLastBackup -Online
Test-DbaLastBackup -SqlInstance sql2016 | Out-GridView

# This would theoretically work, but take a bit right now
Get-DbaCmsRegServer -SqlInstance sqlserver2014a | Test-DbaLastBackup


#---------------------------------------#
# Step 8: PowerShell Jobs in SQL Server #

<#
Three ways to schedule tasks on a Sql Server

Windows Scheduled Tasks
- Requires local admin
- No reporting/discovery via Sql Server
- All infrastructure must be built by yourself

SQL Agent PowerShell Job Step
- Fixed Execution Policy
- Fixed PowerShell version
- Weird behavior, things will break
--> DON'T DO IT, JIM! <--

SQL Agent CmdExec Job Step running powershell.exe
- Respects system settings for PowerShell
- Always current version
- Reproducable results from interactive use, provided privileges are correct
--> Way to go

Related blog post:
https://dbatools.io/agent/
#>


#----------------------------------------#
# Step 9: Scripting Gotchas for dbatools #

# a) Exceptions are Opt-In
# Warning is nice and readable
Get-DbaService -ComputerName doesntexist
# Let's try/catch that
try { Get-DbaService -ComputerName doesntexist }
catch { "Failed" }
# Didn't work that well, did it?
# Give it the Silent Treatment!
try { Get-DbaService -ComputerName doesntexist -Silent }
catch { "Failed" }

# Note:
# Parameter will soon be renamed to '-EnableException' to be more intuitive to use
# '-Silent' will keep working

# b) Tab Expansion and the quest for usability
Get-DbaDatabase -SqlInstance sql2016 -Database Search_Service_Application_AnalyticsReportingStoreDB_21b749e8b05e470aa0e6bb5360a6bfd5

# Lots of options available
Get-DbatoolsConfig
# Looking at something of interest
Get-DbatoolsConfig -FullName tabexpansion.disable
# Since that's not necessary, let's shut it down
Set-DbatoolsConfig tabexpansion.disable $true





