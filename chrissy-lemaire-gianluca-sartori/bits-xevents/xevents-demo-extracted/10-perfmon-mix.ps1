break
# Complaint: Ability to import PerfMon data and look at Trace and PerfMon counter data at the same time

# Goal
# - Xevents CSV
# - Perfmon CSV
# - Mash them together

# First we enabled exporting to CSV from command line
Get-ChildItem -Path C:\github\xevents-demo\sample.xel | Export-DbaXECsv -Path c:\temp\sample.csv
Invoke-Item c:\temp\sample.csv


# Or convert to CSV right from the XESession
Get-DbaXESession -SqlInstance localhost\sql2017 -Session 'Deadlock Graphs' | Export-DbaXECsv -Path C:\temp\deadlock
Invoke-Item C:\temp\deadlock


# Then, we ensured you can write to a local database so you can use Power BI with that data source
Get-DbaXESession -SqlInstance localhost\sql2017 -Session 'Queries and Resources' | Read-DbaXEFile |
Write-DbaDataTable -SqlInstance localhost\sql2016 -Table tempdb.dbo.queriesandresources -AutoCreateTable


# Perfmon
Get-DbaPfDataCollectorSetTemplate | Out-GridView -PassThru | Import-DbaPfDataCollectorSetTemplate | Start-DbaPfDataCollectorSet


# We also made it easy to export perfmon to CSV so you can easily use Power BI
Get-DbaPfDataCollectorSet -CollectorSet 'PAL - SQL Server 2014 and Up' | Invoke-DbaPfRelog | Select -Expand FullName | Invoke-Item
Start-Process C:\temp\perfmon.pbix


# Coming soon - shoutout to any Power BI wiz who'd like to help
Get-DbaPfDataCollectorSet -ComputerName sql2016 -CollectorSet 'Long Running Queries' | Invoke-DbaPfRelog | Update-DbaPowerBiDataSource
Get-DbaXESession -SqlInstance sql2016 -Session 'Long Running Queries' | Export-DbaXECsv | Update-DbaPowerBiDataSource
Start-DbaPowerBi