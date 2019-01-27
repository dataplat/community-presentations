Import-Module .\02.cold-copy\SQLDBMgmt

$params = @{
    SourceServer         = 'localhost'
    SourceDatabase       = 'AdventureWorksLT2012'
    DestinationServer    = 'localhost\i2'
    DestinationDatabase  = 'AdventureWorksLT2012_clone_2.3'
    Prefix               = 'clone_2.3_'
    ReuseFolderStructure = $true
    DestinationLogFolder = 'C:\Logs'
    WithReplace          = $true
    Force                = $true
}
Copy-SQLDatabaseOffline @params -Verbose