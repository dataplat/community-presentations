### using transfer class

# get database object
$database = Get-DbaDatabase -SqlInstance 'localhost' -Database 'AdventureWorksLT2012'

# create a transfer object
$transfer = New-Object Microsoft.SqlServer.Management.Smo.Transfer $database

# define transfer options
$transfer.CopyAllObjects = $true
$transfer.Options.WithDependencies = $true
$transfer.CreateTargetDatabase
$transfer.DestinationDatabase = "AdventureWorksLT2012_clone_5.1"
$transfer.DestinationServer = 'localhost\I2'
$transfer.DestinationLoginSecure = $true
$transfer.CopySchema = $true
$transfer.CopyData = $true

# get the script
$transfer.ScriptTransfer()

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