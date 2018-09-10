break

# Get yo servers - read more at dbatools.io/cms
$site1servers = Get-DbaRegisteredServer -SqlInstance localhost\sql2016 -Group Site1
$site2servers = Get-DbaRegisteredServer -SqlInstance localhost\sql2016 -Group Site2

# But for the demo
$instance = "workstation\sql2016"

# See commands
Get-Command -Name Export-DbaScript -Module dbatools -Type Function
Get-Command -Name *export* -Module dbatools -Type Function
Get-Command -Name *backup* -Module dbatools -Type Function
Get-Command -Name *dbadac* -Module dbatools -Type Function


# First up! Export-DbaScript

# Start with something simple
Get-DbaAgentJob -SqlInstance $instance | Select -First 1 | Export-DbaScript

# Now let's look inside
Get-DbaAgentJob -SqlInstance $instance | Select -First 1 | Export-DbaScript | Invoke-Item

# Raw output and add a batch separator
Get-DbaAgentJob -SqlInstance $instance | Export-DbaScript -Passthru -BatchSeparator GO

# Get crazy
#Set Scripting Options
$options = New-DbaScriptingOption
$options.ScriptSchema = $true
$options.IncludeDatabaseContext  = $true
$options.IncludeHeaders = $false
$Options.NoCommandTerminator = $false
$Options.ScriptBatchTerminator = $true
$Options.AnsiFile = $true

"sqladmin" | clip
Get-DbaDbMailProfile -SqlInstance $instance -SqlCredential sqladmin | 
Export-DbaScript -Path C:\temp\export.sql -ScriptingOptionsObject $options -NoPrefix |
Invoke-Item

# So special
Export-DbaSpConfigure -SqlInstance $instance -Path C:\temp\sp_configure.sql
Export-DbaLinkedServer -SqlInstance $instance -Path C:\temp\linkedserver.sql | Invoke-Item
Export-DbaLogin -SqlInstance $instance -Path C:\temp\logins.sql | Invoke-Item

# Other specials, relative to the server itself
Backup-DbaDbMasterKey -SqlInstance $instance
Backup-DbaDbMasterKey -SqlInstance $instance -Path \\localhost\backups

# What if you just want to script out your restore? Invoke Backup-DbaDatabase or your maintenance job
Start-DbaAgentJob -SqlInstance localhost\sql2016 -Job 'DatabaseBackup - SYSTEM_DATABASES - FULL','DatabaseBackup - USER_DATABASES - FULL'
Get-DbaRunningJob -SqlInstance localhost\sql2016

Start-DbaAgentJob -SqlInstance localhost\sql2016 -Job 'DatabaseBackup - USER_DATABASES - DIFF'
Get-DbaRunningJob -SqlInstance localhost\sql2016

Start-DbaAgentJob -SqlInstance localhost\sql2016 -Job 'DatabaseBackup - USER_DATABASES - LOG'
Get-DbaRunningJob -SqlInstance localhost\sql2016

Start-DbaAgentJob -SqlInstance localhost\sql2016 -Job 'DatabaseBackup - USER_DATABASES - LOG'
Get-DbaRunningJob -SqlInstance localhost\sql2016

Start-DbaAgentJob -SqlInstance localhost\sql2016 -Job 'DatabaseBackup - USER_DATABASES - LOG'
Get-DbaRunningJob -SqlInstance localhost\sql2016

Get-ChildItem -Directory '\\localhost\backups\WORKSTATION$SQL2016' | Restore-DbaDatabase -SqlInstance localhost\sql2017 -OutputScriptOnly -WithReplace | Out-File -Filepath c:\temp\restore.sql
Invoke-Item c:\temp\restore.sql

# Log shipping, what's up - dbatools.io/logshipping
 $params = @{
    Source = 'localhost\sql2016'
    Destination = 'localhost\sql2017'
    Database = 'shipped'
    BackupNetworkPath= '\\localhost\backups'
    BackupScheduleFrequencyType = 'Daily'
    BackupScheduleFrequencyInterval = 1
    CompressBackup = $true
    CopyScheduleFrequencyType = 'Daily'
    CopyScheduleFrequencyInterval = 1
    GenerateFullBackup = $true
    Force = $true
}

Invoke-DbaLogShipping @params

# Test it!
Start-DbaAgentJob -SqlInstance localhost\sql2016 -Job LSBackup_shipped
Test-DbaLogShippingStatus -SqlInstance localhost\sql2016 | Out-GridView

# Use Ola Hallengren's backup script? We can restore an *ENTIRE INSTANCE* with just one line
Get-ChildItem -Directory \\workstation\backups\sql2012 | Restore-DbaDatabase -SqlInstance localhost\sql2017 -WithReplace



<# 

    Introducing Export-DbaInstance
    Written for #SQLGLA!

#>



# Check that everything exists prior to export
Invoke-Pester C:\github\community-presentations\chrissy-lemaire\doomsday.Tests.ps1

# Do it all at once
Export-DbaInstance -SqlInstance $instance -Path \\workstation\backups\DR
Invoke-Item \\workstation\backups\DR

# It ain't a DR plan without testing
Test-DbaLastBackup -SqlInstance $instance

# Now let's test the output scripts. 
# This will also kill SSMS so that I'm forced to refresh, and open it back up
. C:\github\community-presentations\chrissy-lemaire\doomsday-dropeverything.ps1

# Check that everything has been dropped
Invoke-Pester C:\github\community-presentations\chrissy-lemaire\doomsday.Tests.ps1

# Prep
Stop-DbaService -ComputerName localhost -InstanceName sql2016 -Type Agent
Get-DbaProcess -SqlInstance localhost\sql2016 -Database msdb | Stop-DbaProcess


# Perform restores and restart SQL Agent
$files = Get-ChildItem -Path \\workstation\backups\DR -Exclude *userobj*,*agent* | Sort-Object LastWriteTime
$files | ForEach-Object {
    Write-Output "Running $psitem"
    Invoke-DbaQuery -File $PSItem -SqlInstance workstation\sql2016 -ErrorAction Ignore -Verbose
}

Start-DbaService -ComputerName localhost -InstanceName sql2016 -Type Agent

# Check if everything is back
Invoke-Pester C:\github\community-presentations\chrissy-lemaire\doomsday.Tests.ps1