break
#region Basics

# Get-DbaRegisteredServer
Get-DbaRegisteredServer



# Connect-DbaInstance
Get-DbaRegisteredServer -Name azuresqldb | Connect-DbaInstance | Get-DbaDatabase



# CSV galore!
Get-ChildItem C:\temp\psconf\csv
Get-ChildItem C:\temp\psconf\csv | Import-DbaCsv -SqlInstance localhost\sql2017 -Database tempdb -AutoCreateTable -Encoding UTF8
Invoke-DbaQuery -SqlInstance localhost\sql2017 -Database tempdb -Query "Select top 10 * from [jmfh-year]"



# Write-DbaDbTableData
Get-ChildItem -File | Write-DbaDbTableData -SqlInstance localhost\sql2017 -Database tempdb -Table files -AutoCreateTable
Get-ChildItem -File | Select *
Invoke-DbaQuery -SqlInstance localhost\sql2017 -Database tempdb -Query "Select * from files"

#endregion




#region Must Haves

# Gotta find it
Find-DbaInstance -ComputerName localhost | Select * | Out-GridView



# PII Management
Invoke-DbaDbPiiScan -SqlInstance localhost\sql2017 -Database AdventureWorks2014 | Out-GridView

New-DbaDbMaskingConfig -SqlInstance localhost\sql2017 -Database AdventureWorks2014 -Table EmployeeDepartmentHistory, Employee -Path C:\temp | Invoke-Item
Invoke-Item -Path 'C:\github\community-presentations\chrissy-lemaire\mask.json'

Invoke-DbaDbDataMasking -SqlInstance localhost\sql2017  -ExcludeTable EmployeeDepartmentHistory -FilePath 'C:\github\community-presentations\chrissy-lemaire\mask.json'


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


Invoke-DbaDbLogShipping @params

# Recover when ready
Invoke-DbaDbLogShipRecovery -SqlInstance localhost\sql2017 -Database bigoldb





# Install-DbaInstance / Update-DbaInstance
Invoke-Item 'C:\temp\psconf\Patch several SQL Servers at once using Update-DbaInstance by Kirill Kravtsov.mp4'

#endregion

#region fan favorites

# Diagnostic
Invoke-DbaDiagnosticQuery -SqlInstance localhost\sql2017 | Export-DbaDiagnosticQuery
New-DbaDiagnosticAdsNotebook -TargetVersion 2017 -Path C:\temp\myNotebook.ipynb | Invoke-Item





# Dope - https://dbatools.io/timeline/
Get-DbaAgentJobHistory -SqlInstance localhost\sql2017 -StartDate '2016-08-18 00:00' -EndDate '2018-08-19 23:59' -ExcludeJobSteps | ConvertTo-DbaTimeline | Out-File C:\temp\DbaAgentJobHistory.html -Encoding ASCII
Invoke-Item -Path C:\temp\DbaAgentJobHistory.html

# Prettier
Start-Process https://dbatools.io/wp-content/uploads/2018/08/Get-DbaAgentJobHistory-html.jpg



# ConvertTo-DbaXESession
Get-DbaTrace -SqlInstance localhost\sql2017 -Id 1 | ConvertTo-DbaXESession -Name 'Default Trace' | Start-DbaXESession



# Ola Hallengren supported
Install-DbaMaintenanceSolution -SqlInstance localhost\sql2017 -ReplaceExisting -InstallJobs
#endregion

#region Combo kills

# Start-DbaMigration wraps 30+ commands
Start-DbaMigration -Source localhost -Destination localhost\sql2016 -UseLastBackup -Exclude BackupDevices | Out-GridView



# Wraps like 20
Export-DbaInstance -SqlInstance localhost\sql2017 -Path C:\temp\dr
Get-ChildItem -Path C:\temp\dr -Recurse -Filter *database* | Invoke-Item



# Wraps a bunch
Test-DbaLastBackup -SqlInstance localhost -Destination localhost\sql2016 | Select * | Out-GridView



# All in one, no hassle - includes credentials!
$docker1 = Get-DbaRegisteredServer -Name dockersql1
$docker2 = Get-DbaRegisteredServer -Name dockersql2

# setup a powershell splat
$params = @{
    Primary = $docker1
    Secondary = $docker2
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

#region BONUS
Get-ChildItem C:\github\community-presentations\*ps1 -Recurse | Invoke-DbatoolsRenameHelper | Out-GridView
#endregion
