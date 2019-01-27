### using transfer class

# get database object
$database = Get-DbaDatabase -SqlInstance 'localhost' -Database 'AdventureWorksLT2012'

# create a target database
New-DbaDatabase -SqlInstance 'localhost\I2' -Name AdventureWorksLT2012_clone_6.2

# create a transfer object
$transfer = New-Object Microsoft.SqlServer.Management.Smo.Transfer $database

# define transfer options
$transfer.CopyAllObjects = $true
$transfer.Options.WithDependencies = $true
$transfer.CreateTargetDatabase = $false
$transfer.DestinationDatabase = "AdventureWorksLT2012_clone_6.2"
$transfer.DestinationServer = 'localhost\I2'
$transfer.DestinationLoginSecure = $true
$transfer.CopySchema = $true
$transfer.CopyData = $false

# get the script
$script = $transfer.ScriptTransfer()
foreach ($query in $script) {
    Invoke-DbaQuery -SqlInstance localhost\I2 -Database AdventureWorksLT2012_clone_6.2 -Query $query
}

### alternatively, using SMO object scripter

# get database object
$database = Get-DbaDatabase -SqlInstance 'localhost' -Database 'AdventureWorksLT2012'

# set export options
$options = New-DbaScriptingOption
$options.ScriptSchema = $true
$options.IncludeDatabaseContext  = $true
$options.IncludeHeaders = $false
$options.NoCommandTerminator = $false
$options.ScriptBatchTerminator = $true
$options.AnsiFile = $true

# script out everything in it
$database.Tables | Export-DbaScript -Passthru -ScriptingOptionsObject $options