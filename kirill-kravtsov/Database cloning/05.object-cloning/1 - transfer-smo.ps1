# get database object
$database = Get-DbaDatabase -SqlInstance 'localhost' -Database 'AdventureWorksLT2012'

# create a target database
New-DbaDatabase -SqlInstance 'localhost\I2' -Name AdventureWorksLT2012_clone_5.1

# create a transfer object
$transfer = New-Object Microsoft.SqlServer.Management.Smo.Transfer $database

# define transfer options
$transfer.CopyAllObjects = $true
$transfer.Options.WithDependencies = $true
$transfer.CreateTargetDatabase = $false
$transfer.DestinationDatabase = "AdventureWorksLT2012_clone_5.1"
$transfer.DestinationServer = 'localhost\I2'
$transfer.DestinationLoginSecure = $true
$transfer.CopySchema = $true
$transfer.CopyData = $true

# initiate the transfer
$transfer.TransferData()