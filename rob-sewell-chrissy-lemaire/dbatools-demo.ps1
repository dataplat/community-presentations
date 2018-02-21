break

# Set some vars
$new = "localhost\sql2016"
$old = $instance = "localhost"
$allservers = $old, $new

# Alternatively, use Registered Servers? 
Get-DbaRegisteredServer -SqlInstance $instance | Out-GridView


# Quick overview of commands
Start-Process https://dbatools.io/commands


# You've probably heard about how easy migrations can be with dbatools. Here's an example 
$startDbaMigrationSplat = @{
    Source = $old
    Destination = $new
    BackupRestore = $true
    NetworkShare = 'C:\temp'
    NoSysDbUserObjects = $true
    NoCredentials = $true
    NoBackupDevices = $true
    NoEndPoints = $true
}

Start-DbaMigration @startDbaMigrationSplat -Force | Select * | Out-GridView


# Use Ola Hallengren's backup script? We can restore an *ENTIRE INSTNACE* with just one line
Get-ChildItem -Directory \\workstation\backups\sql2012 | Restore-DbaDatabase -SqlInstance $new -WithReplace


# Nowadays, we don't just backup databases. Now, we're backing up logins
Export-DbaLogin -SqlInstance $instance -Path C:\temp\logins.sql
Invoke-Item C:\temp\logins.sql

# And Agent Jobs
Get-DbaAgentJob -SqlInstance $old | Export-DbaScript -Path C:\temp\jobs.sql
Invoke-Item C:\temp\jobs.sql


# What if you just want to script out your restore?
Get-ChildItem -Directory \\workstation\backups\subset\ | Restore-DbaDatabase -SqlInstance $new -OutputScriptOnly -WithReplace | Out-File -Filepath c:\temp\restore.sql
Invoke-Item c:\temp\restore.sql



# Reads trace files - default trace by default
Read-DbaTraceFile -SqlInstance $instance | Out-GridView

# Convert Traces to XE (h/t Jonathan Kehayias)
Get-DbaTrace -SqlInstance $old | ConvertTo-DbaXESession -Name 'Default Trace' | Start-DbaXESession

# Easily import
Get-DbaXESessionTemplate | Out-GridView -PassThru | Import-DbaXESessionTemplate -SqlInstance $allservers |
Start-DbaXESession

# XEs Read and watch
Get-DbaXESession -SqlInstance $new -Session system_health | Read-DbaXEFile



# Know how snapshots used to be a PITA? Now they're super easy
New-DbaDatabaseSnapshot -SqlInstance $new -Database db1 -Name db1_snapshot
Get-DbaDatabaseSnapshot -SqlInstance $new
Get-DbaProcess -SqlInstance $new -Database db1 | Stop-DbaProcess
Restore-DbaFromDatabaseSnapshot -SqlInstance $new -Database db1 -Snapshot db1_snapshot
Remove-DbaDatabaseSnapshot -SqlInstance $new -Snapshot db1_snapshot # or -Database db1



# We evaluated 37,545 SQL Server stored procedures on 9 servers in 8.67 seconds!
$new | Find-DbaStoredProcedure -Pattern dbatools

# Have an employee who is leaving? Find all of their objects.
$allservers | Find-DbaUserObject -Pattern loulou | Out-GridView
 


# Find detached databases, by example
Detach-DbaDatabase -SqlInstance $instance -Database SharePoint_Config
Find-DbaOrphanedFile -SqlInstance $instance | Out-GridView -PassThru | Select -Expand FileName | Remove-Item


# View and change service account
Get-DbaSqlService -ComputerName workstation | Out-GridView
Get-DbaSqlService -ComputerName workstation | Select * | Out-GridView
Get-DbaSqlService -Instance SQL2016 -Type Agent | Update-DbaSqlServiceAccount -Username 'Local system'



# Check out how complete our sp_configure command is
Get-DbaSpConfigure -SqlInstance $new | Out-GridView
Get-DbaSpConfigure -SqlInstance $new -ConfigName XPCmdShellEnabled

# Easily update configuration values
Set-DbaSpConfigure -SqlInstance $new -ConfigName XPCmdShellEnabled -Value $true



# Reset-DbaAdmin
Reset-DbaAdmin -SqlInstance $instance -Login sqladmin -Verbose
Get-DbaDatabase -SqlInstance $instance -SqlCredential (Get-Credential sqladmin)



# sp_whoisactive
Install-DbaWhoIsActive -SqlInstance $instance -Database master
Invoke-DbaWhoIsActive -SqlInstance $instance -ShowOwnSpid -ShowSystemSpids

# Diagnostic query!
$instance | Invoke-DbaDiagnosticQuery -UseSelectionHelper | Export-DbaDiagnosticQuery -Path $home
Invoke-Item $home

# Ola, yall
$instance | Install-DbaMaintenanceSolution -ReplaceExisting -BackupLocation C:\temp -InstallJobs



# Get db space AND write it to table
Get-DbaDatabaseFile -SqlInstance $instance | Out-GridView
Get-DbaDatabaseFile -SqlInstance $instance | Write-DbaDataTable -SqlInstance $instance -Database tempdb -Table DiskSpaceExample -AutoCreateTable
Invoke-DbaSqlcmd -ServerInstance $instance -Database tempdb -Query 'SELECT * FROM dbo.DiskSpaceExample' | Out-GridView


# History
Get-Command -Module dbatools *history*

# More histories
Get-DbaAgentJobHistory -SqlInstance $instance | Out-GridView
Get-DbaBackupHistory -SqlInstance $new | Out-GridView


# don't have remoting access? Explore the filesystem. Uses master.sys.xp_dirtree
Get-DbaFile -SqlInstance $instance
Get-DbaFile -SqlInstance $instance -Depth 3 -Path 'C:\Program Files\Microsoft SQL Server' | Out-GridView
New-DbaSqlDirectory -SqlInstance $instance  -Path 'C:\temp\test'

# Test/Set SQL max memory
$allservers | Get-DbaMaxMemory
$allservers | Test-DbaMaxMemory | Format-Table


# We've even got our own config system!
Get-DbaConfig

# Check out our logs directory, so Enterprise :D
Invoke-Item (Get-DbaConfig -FullName path.dbatoolslogpath).Value

# Want to see what's in our logs?
Get-DbatoolsLog | Out-GridView

# Need to send us diagnostic information? Use this support package generator
New-DbatoolsSupportPackage