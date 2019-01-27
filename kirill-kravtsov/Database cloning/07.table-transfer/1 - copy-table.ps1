# create a new target database
New-DbaDatabase -SqlInstance 'localhost\I2' -Name 'AdventureWorksLT2012_clone_7.1'

$tables = Get-DbaDbTable -SqlInstance 'localhost' -Database 'AdventureWorksLT2012'
$copySplat = @{
    SqlInstance = 'localhost'
    Database    = 'AdventureWorksLT2012'
    Destination = 'localhost\I2'
    DestinationDatabase = 'AdventureWorksLT2012_clone_7.1'
    AutoCreateTable = $true
}
foreach ($t in $tables) {
    Copy-DbaDbTableData @copySplat -Table $t
}