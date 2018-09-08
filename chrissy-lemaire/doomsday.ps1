break

$cms = "localhost\sql2016"

# Get yo servers
$instance = Get-DbaRegisteredServer -SqlInstance $cms -Group Site1
$instance2 = Get-DbaRegisteredServer -SqlInstance $cms -Group Site2

# See commands
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
Get-DbaDbMailAccount -SqlInstance $instance -SqlCredential sqladmin | Export-DbaScript -Path C:\temp\export.sql -ScriptingOptionsObject $options -NoPrefix |
Invoke-Item

# So special
Export-DbaSpConfigure -SqlInstance $instance -Path C:\temp\sp_configure.sql
Export-DbaCredential -SqlInstance $instance -Path C:\temp\credential.sql
Export-DbaLogin -SqlInstance $instance -Path C:\temp\logins.sql

# Other specials
Backup-DbaDbMasterKey -SqlInstance sql2017 -Credential sup

# Nowadays, we don't just backup databases. Now, we're backing up logins
Export-DbaLogin -SqlInstance $instance -Path C:\temp\logins.sql
Invoke-Item C:\temp\logins.sql

# What if you just want to script out your restore?
Get-ChildItem -Directory \\workstation\backups\subset\ | Restore-DbaDatabase -SqlInstance $instance2 -OutputScriptOnly -WithReplace | Out-File -Filepath c:\temp\restore.sql
Invoke-Item c:\temp\restore.sql

# Do it all at once
Export-DbaInstance -SqlInstance $instance -Path \\workstation\backups\DR

# It ain't a DR plan without testing
Test-DbaLastBackup -SqlInstance $instance

# Apply stuff
Get-ChildItem -Path \\workstation\backups\DR | Invoke-DbaQuery

# Use Ola Hallengren's backup script? We can restore an *ENTIRE INSTANCE* with just one line
Get-ChildItem -Directory \\workstation\backups\sql2012 | Restore-DbaDatabase -SqlInstance $instance2 -WithReplace

#Imports
#Get Cert
#Show tests
# Do backups & exports
# Stop Site1
# Turn off thing
# Pester test bonus?
# Power Bi Bonus