break
# Complaint: Reading using xe_file_target_read_file taxes the SQL Server CPU
# Answer: Now you can read files from any workstation or server
Get-ChildItem small-sample.xel | Read-DbaXEFile
Get-DbaXESession -SqlInstance localhost\sql2017 -Session 'Deadlock Graphs' | Read-DbaXEFile


# Or, again, you can read locally and export to remote table
Get-DbaXESession -SqlInstance localhost\sql2017 -Session 'Deadlock Graphs' | Read-DbaXEFile |
Write-DbaDataTable -SqlInstance localhost\sql2016 -Table tempdb.dbo.profiler -AutoCreateTable