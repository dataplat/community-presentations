break


#Start Region Basics
#Basics
Install-Module Dbatools -Scope CurrentUser
Update-Module Dbatools
Import-Module Dbatools

#how many cmdlets?
Get-Command -Module Dbatools | Measure-Object

Function prompt {"PS [Dbatools]> "}
#End Region Basics





#region #5 Finding DbaCommand

Start-Process https://dbatools.io/commands
Get-help Find-DbaCommand -Examples



Find-DbaCommand "AG"
Find-DbaCommand -Pattern "AG"
Find-DbaCommand -Tag AG
Find-DbaCommand -Tag Job,Owner
Find-DbaCommand -Author Chrissy -Tag AG




#Other Dbatools Cmdlets
Get-DbatoolsChangeLog -Local
Get-Help Invoke-DbatoolsRenameHelper


#PSFrameWork by @FredWeinmann
Get-DbatoolsConfig
Get-DbatoolsConfigValue
Set-DbatoolsConfig
#*-DbaToolsConfig*

#check for the latest Updates
Install-DbatoolsWatchUpdate

#End Region






#Region #4 Invoke-DbaQuery
# If you are not using AD Intigration No Need for Credentials
# If you are using Azure or SQLAuth you need Credentials

$SQLCredentials = (Get-Credential)
$PSDefaultParameterValues['Invoke-DbaQuery:SqlCredential'] = $SQLCredentials

Invoke-DbaQuery -SqlInstance "localhost,14333" -SqlCredential $SQLCredentials -Database SuperUser -Query "SELECT * FROM  dbo.Users where DisplayName like 'JoshC%'"








#Alternative Ways to Write Query with 'Here Strings'
$Query = @"
SELECT Id,DisplayName,CreationDate,LastAccessDate,AccountId,Views
FROM  SuperUser.dbo.Users
WHERE DisplayName like 'Sue%'
"@

Invoke-DbaQuery -SqlInstance "localhost,14333" -Query $Query



#What about providing Variables?
$Query = @"
SELECT Id,DisplayName,CreationDate,LastAccessDate,AccountId,Views
FROM  SuperUser.dbo.Users
WHERE DisplayName like @user
"@

Invoke-DbaQuery -SqlInstance "localhost,14333" -Query $Query -SqlParameters @{ User = "aspner%" }




#what if you don't know your data?
$PSDefaultParameterValues['Get-DbaDatabase:SqlCredential'] = $SQLCredentials
Get-DbaDatabase -SqlInstance "localhost,14333" -ExcludeSystem

#Put the Database into a Variable
$database = Get-DbaDatabase -SqlInstance "localhost,14333" -Database SuperUser

# Next explore the tables and columns
$database.Tables | Select-Object Name
$database.Tables | Where-Object {$_.name -eq 'Posts'}
#$database.Tables | Where-Object {$_.name -eq 'Posts'} | Select-Object columns
($database.Tables | Where-Object {$_.name -eq 'Posts'}).columns.name

$database.Tables | Gm
$Query = "SELECT TOP 10 Id,Title,ViewCount,Score FROM dbo.Posts WHERE Title IS NOT NULL Order BY Score Desc"
Invoke-DbaQuery -SqlInstance "localhost,14333" -Query $Query -Database SuperUser

# Different Data Types  'DataSet', 'DataTable', 'DataRow', 'PSObject', and 'SingleValue'
Invoke-DbaQuery -SqlInstance "localhost,14333" -Query $Query  -As PSObject

#Write Any kind of T-SQL Statement
#NOTE: Transactions Not Supported in PowerShell Try/Catch
#Need XACT_ABORT ON
#https://stackoverflow.com/questions/13977650/multiple-invoke-sqlcmd-and-sql-server-transaction



#Talking about Writing Quries, What about inserting data from other sources?
New-DbaDatabase -SqlInstance "localhost,14333" -SqlCredential $SQLCredentials -Name "CSVStuff"
Get-ChildItem -Path C:\windows\System32 -File | Import-DbaCsv -SqlInstance "localhost,14333" -SqlCredential $SQLCredentials -Database "CSVStuff" -AutoCreateTable -Encoding UTF8

Get-Service | Select-Object -ExcludeProperty Path | Write-DbaDbTableData -SqlInstance "localhost,14333" -SqlCredential $SQLCredentials -Database "CSVStuff" -AutoCreateTable -Table "Service"



#End Region

#Region #3 Update-DbaInstance

#Switch to VMS
Connect-DbaInstance -SqlInstance sql2008r2

#Will Need to Download the Updates First
#(Although a download feature is being worked on)
#https://buildnumbers.wordpress.com/sqlserver/

$Credential = Get-Credential
#Need Credentials because of the way that it copies over the files from a Share.
Update-DbaInstance -ComputerName sql2008r2 -Path \\sqltestbed\temp -Credential $Credential -Restart -Confirm:$false -Type ServicePack

#Similar Cmdlets
#Install-DbaInstance

#End Region


#Region #2 Install-DbaMaintenanceSolution
#Ola Hallengren Scripts https://ola.hallengren.com or https://github.com/olahallengren/sql-server-maintenance-solution

$Server = Get-DbaRegServer -Name OlaTheMan
Install-DbaMaintenanceSolution -SqlInstance $Server -Database Master -InstallJobs -LogToTable -CleanupTime 240

#install only a portion
Install-DbaMaintenanceSolution -SqlInstance $Server -Solution IntegrityCheck


Install-DbaMaintenanceSolution -SqlInstance $Server -Database Master -LocalFile .\josh-corrick\sql-server-maintenance-solution-master.zip -ReplaceExisting




#Let it Run on Schedule or Run it Manually
Get-DbaAgentJob -SqlInstance $Server -Category 'Database Maintenance' | Select-Object Name

Start-DbaAgentJob -SqlInstance $Server -Job 'DatabaseBackup - SYSTEM_DATABASES - FULL'

Get-DbaAgentJob -SqlInstance $Server -Job 'DatabaseBackup - SYSTEM_DATABASES - FULL'

Test-DbaLastBackup

Find-DbaCommand -Tag Agent
#Get-DbaAgentJobHistory -SqlInstance $Server

#Used to read text files if LogToTable='N'
#Get-DbaMaintenanceSolutionLog -SqlInstance $server




#Community Bonus
Save-DbaDiagnosticQueryScript Invoke-DbaDiagnosticQuery Export-DbaDiagnosticQuery # <-Glen Barry
Install-DbaWhoIsActive Invoke-DbaWhoIsActive # <- sp_WhoisActive by Adam Machanic
Install-DbaFirstResponderKit # <- sp_Blitz, sp_BlitzWho, sp_BlitzFirst, sp_BlitzIndex, sp_BlitzCache and sp_BlitzTrace, etc. By Brent Ozar
Install-DbaSqlWatch # <- https://sqlwatch.io by Marcin Gminski
#End Region





#Region #1 Start-DbaMigration

$Source = Connect-DbaInstance -SqlInstance sql2008r2
$Destination = Connect-DbaInstance -SqlInstance sqltestbed\sql2017
Get-DbaDatabase -SqlInstance $Source -UserDbOnly
Get-DbaDatabase -SqlInstance $Destination -UserDbOnly

# Start-DbaMigration is made up of ~30 cmdlets this is just an "Easy Button"
# There are two major ways Start-DbaMigration Works
# 1. Detatch/Copy/Restore (Need Admin FileShare Open, as well as DAC Enabled)
# 2. Backup/Restore

Start-DbaMigration -Source $Source -Destination $Destination -DetachAttach -Exclude DatabaseMail,SysDbUserObjects,AgentServer,ExtendedEvents  |  Out-GridView

Start-DbaMigration -Source $Source -Destination $Destination -BackupRestore -UseLastBackup


#If you want to just have things avalible to you for an "Offline" move, or backups
Export-DbaInstance -SqlInstance $Source -Path C:\users\Josh\Documents\


#Or if you are just migrating Users
Copy-DbaLogin -Source $Source -Destination $Destination -Login 'Josh'

#If you have larger databases 1Tb+ that need to be cut over quickly.

# Very Large Database Migration
$params = @{
    Source                          = 'localhost'
    Destination                     = 'localhost\sql2017'
    Database                        = 'shipped'
    SharedPath                      = '\\localhost\backups'
    BackupScheduleFrequencyType     = 'Daily'
    BackupScheduleFrequencyInterval = 1
    CompressBackup                  = $true
    CopyScheduleFrequencyType       = 'Daily'
    CopyScheduleFrequencyInterval   = 1
    GenerateFullBackup              = $true
    Force                           = $true
}

Invoke-DbaDbLogShipping @params

# Recover when ready
Invoke-DbaDbLogShipRecovery -SqlInstance localhost\sql2017 -Database shipped



#End Region










#Bonus Awesome Sauce

# Honorable Mentions

# Find-DbaInstance
# Find-DbaUserObject
# Invoke-DbaDbPiiScan - Find PII Data
# Invoke-DbaDbDataMasking - Moving Data to QA/Dev
# Publish-DbaDacPac
# Backup-DbaDatabase
# Import-DbaSpConfigure - great for sp_configure settings
# Get-DbaDeprecatedFeature - Does 2012 support x feature?
# Extended Events and Perf Mon cmdlets !!




# From Chrissy's PSConfEU and DataGrillen Talk
# All in one, no hassle - includes credentials!
$dbatools1 = Get-DbaRegisteredServer -Name dbatools1
$dbatools2 = Get-DbaRegisteredServer -Name dbatools2

# setup a powershell splat (has docker been reset?)
$params = @{
    Primary      = $dbatools1
    Secondary    = $dbatools2
    Name         = "test-ag"
    Database     = "DBAToolsRocks"
    ClusterType  = "None"
    SeedingMode  = "Automatic"
    FailoverMode = "Manual"
    Confirm      = $false
}

# execute the command
New-DbaAvailabilityGroup @params



#Lab Setup
#SO Server
docker pull mcr.microsoft.com/mssql/server:2019-CTP3.1-ubuntu
docker run -d -v SODataBackup:/var/opt/mssql -e 'ACCEPT_EULA=Y' -e 'SA_PASSWORD=Password123#' -p 14333:1433 --name SOData mcr.microsoft.com/mssql/server:2019-CTP3.1-ubuntu
docker cp C:\Users\josh\Downloads\SUPERUSER_201712_NoPostHistory.bak SOData:/var/opt/mssql/data
$SOData = Get-DbaRegServer -Name SOData
New-DbaLogin -SqlInstance $SOData -Login Josh

#OlaServer
docker build -t josh/mssqlagentlinux .
docker run -d -p 15789:1433 --env 'ACCEPT_EULA=Y' --env 'SA_PASSWORD=Password123#' --name OlaTheMan josh/mssqlagentlinux
