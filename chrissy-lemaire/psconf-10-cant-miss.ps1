# Basics - refresh

# Add psdbatools, install azure data studio 
Get-DbaRegisteredServer | Format-Table

# Connect-DbaInstance
Get-DbaRegisteredServer -Name psdbatools.database.windows.net | Connect-DbaInstance

# CSV galore! Delete Maximo Park
Get-ChildItem C:\csv
Get-ChildItem C:\csv | Import-DbaCsv -SqlInstance localhost\sql2017 -Database tempdb -AutoCreateTable

# Query
# displays messages (aka print or raiserror) nicely, without interfering with the resultset, and asynchronously
Invoke-DbaQuery -SqlInstance localhost\sql2017 -Database tempdb -Query "Select top 10 * from [jmfh-year]"

#region Must Haves
Find-DbaInstance -ComputerName localhost


Invoke-DbaDbMasking / Invoke-DbaDbDataGenerator
Invoke-DbaLogShipping - enables VLDB migs
Install-DbaInstance / Update-DbaInstance -> II Video
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
New-DbaAvailabilityGroup

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

#endregion

ConvertTo-DbaXESession
Test-DbaDbCompression

$params = @{
    Source                          = 'sql2008'
    Destination                     = 'sql2016', 'sql2017'
    Database                        = 'shipped'
    BackupNetworkPath               = '\\backups\sql'
    PrimaryMonitorServer            = 'sql2012'
    SecondaryMonitorServer          = 'sql2012'
    BackupScheduleFrequencyType     = 'Daily'
    BackupScheduleFrequencyInterval = 1
    CompressBackup                  = $true
    CopyScheduleFrequencyType       = 'Daily'
    CopyScheduleFrequencyInterval   = 1
    GenerateFullBackup              = $true
    Force                           = $true
}

# pass the splat
Invoke-DbaLogShipping @params

# BONUS: Invoke-DbatoolsRenameHelper
<#
    2 for sure, 1 I think it's a feature, most will think it's a limitation.
    1) it's the only way to issue parametrized statements without incurring in sql-injection problems
    2) it's a different beast from invoke-sqlcmd, which cannot do 1) BUT can handle the "sqlcmd" scripts, albeit with lots of limits. tl;dr: sqlcmd works with 100%, invoke-sqlcmd works for 80%. Invoke-DbaQuery is NOT invoke-sqlcmd, nor tends to be
    3) displays messages (aka print or raiserror) nicely, without interfering with the resultset, and asynchronously (think, post 1.0, being able to use ola's maintenance seeing the progress in realtime) (edited)
    4) database isolation (and that's the feature, at least for me). Being able to invoke a script without parsing it beforehand to inspect if, e.g., will drop msdb , to me is golden.
    you point it to a user database and you're certain it won't cross boundaries
    (surely, the only way to be certain would be to use a lowprivileged user, but, still, has a lot better isolation than sqlcmd or invoke-sqlcmd )
#>