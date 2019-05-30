#region Basics

# Get-DbaRegisteredServer
Get-DbaRegisteredServer



# Connect-DbaInstance
Get-DbaRegisteredServer -Name azuresqldb | Connect-DbaInstance



# CSV galore!
Get-ChildItem C:\temp\psconf\csv
Get-ChildItem C:\temp\psconf\csv | Import-DbaCsv -SqlInstance localhost\sql2017 -Database tempdb -AutoCreateTable -Encoding UTF8



# Query
# displays messages (aka print or raiserror) nicely, without interfering with the resultset, and asynchronously
# parametrized statements without incurring in sql-injection problems
Invoke-DbaQuery -SqlInstance localhost\sql2017 -Database tempdb -Query "Select top 10 * from [jmfh-year]"




# Write-DbaDbTableData
Get-ChildItem -File | Write-DbaDbTableData -SqlInstance localhost\sql2017 -Database tempdb -Table files -AutoCreateTable
Get-ChildItem -File | Select *
Invoke-DbaQuery -SqlInstance localhost\sql2017 -Database tempdb -Query "Select * from files"

#endregion

#region Must Haves

# Gotta find it
Find-DbaInstance -ComputerName localhost


Invoke-DbaDbMasking / Invoke-DbaDbDataGenerator

# Very Large Database Migration
$params = @{
    Source                          = 'localhost'
    Destination                     = 'localhost\sql2017'
    Database                        = 'bigoldb'
    BackupNetworkPath               = '\\localhost\backups'
    BackupScheduleFrequencyType     = 'Daily'
    BackupScheduleFrequencyInterval = 1
    CompressBackup                  = $true
    CopyScheduleFrequencyType       = 'Daily'
    CopyScheduleFrequencyInterval   = 1
    GenerateFullBackup              = $true
    Force                           = $true
}

# pass the splat
Invoke-DbaDbLogShipping @params

# Recover when ready
Invoke-DbaDbLogShipRecovery -SqlInstance localhost\sql2017 -Database bigoldb



# Install-DbaInstance / Update-DbaInstance
Invoke-Item 'C:\temp\psconf\Patch several SQL Servers at once using Update-DbaInstance by Kirill Kravtsov.mp4'

#endregion

#region Combo kills

# Start-DbaMigration wraps 30+ commands
Start-DbaMigration -Source localhost -Destination sql2016 -UseLastBackup -Exclude BackupDevices | Out-GridView

# Wraps
Export-DbaInstance -SqlInstance localhost\sql2017 -Path C:\temp\dr
Get-ChildItem -Path C:\temp\dr -Recurse -Filter *database* | Invoke-Item

# Wraps a bunch
Test-DbaLastBackup -SqlInstance localhost -Destination localhost\sql2016 | Select * | Out-GridView

# All in one, no hassle
# the password is dbatools.IO
$cred = Get-Credential -UserName sqladmin
 
# setup a powershell splat
$params = @{
    Primary = "localhost"
    PrimarySqlCredential = $cred
    Secondary = "localhost:14333"
    SecondarySqlCredential = $cred
    Name = "test-ag"
    Database = "pubs"
    ClusterType = "None"
    SeedingMode = "Automatic"
    FailoverMode = "Manual"
    Confirm = $false
 }
 
# execute the command
 New-DbaAvailabilityGroup @params

#endregion

#region fan favorites

# Diagnostic, add connection, preopen
New-DbaDiagnosticAdsNotebook -TargetVersion 2017 -Path c:\temp\myNotebook.ipynb | Invoke-Item
Invoke-DbaDiagnosticQuery -SqlInstance localhost\sql2017 | Export-DbaDiagnosticQuery

# Dope - https://dbatools.io/timeline/
Get-DbaAgentJobHistory -SqlInstance localhost\sql2017 -StartDate '2016-08-18 00:00' -EndDate '2018-08-19 23:59' -ExcludeJobSteps | ConvertTo-DbaTimeline | Out-File C:\temp\DbaAgentJobHistory.html -Encoding ASCII
Invoke-Item -Path C:\temp\DbaAgentJobHistory.html

# Prettier
Start-Process https://dbatools.io/wp-content/uploads/2018/08/Get-DbaAgentJobHistory-html.jpg

# ConvertTo-DbaXESession
Get-DbaTrace -SqlInstance localhost\sql2017 -Id 1 | ConvertTo-DbaXESession -Name 'Default Trace' | Start-DbaXESession

Install-DbaMaintenanceSolution -SqlInstance localhost\sql2017 -ReplaceExisting -InstallJobs
#endregion

#region BONUS: Invoke-DbatoolsRenameHelper
    Invoke-DbatoolsRenameHelper
#endregion
<#
    2 for sure, 1 I think it's a feature, most will think it's a limitation.
    1) it's the only way to issue parametrized statements without incurring in sql-injection problems
    2) it's a different beast from invoke-sqlcmd, which cannot do 1) BUT can handle the "sqlcmd" scripts, albeit with lots of limits. tl;dr: sqlcmd works with 100%, invoke-sqlcmd works for 80%. Invoke-DbaQuery is NOT invoke-sqlcmd, nor tends to be
    3) displays messages (aka print or raiserror) nicely, without interfering with the resultset, and asynchronously (think, post 1.0, being able to use ola's maintenance seeing the progress in realtime) (edited)
    4) database isolation (and that's the feature, at least for me). Being able to invoke a script without parsing it beforehand to inspect if, e.g., will drop msdb , to me is golden.
    you point it to a user database and you're certain it won't cross boundaries
    (surely, the only way to be certain would be to use a lowprivileged user, but, still, has a lot better isolation than sqlcmd or invoke-sqlcmd )
#>