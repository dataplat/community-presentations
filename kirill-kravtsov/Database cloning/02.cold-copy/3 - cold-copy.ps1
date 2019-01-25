Import-Module .\SQLDBMgmt

$params = @{
    SourceServer         = 'localhost'
    SourceDatabase       = 'AdventureWorksLT2012'
    DestinationServer    = 'localhost\i2'
    DestinationDatabase  = 'AdventureWorksLT2012_clone_3.3'
    Prefix               = 'copied_'
    ReuseFolderStructure = $true
    DestinationLogFolder = 'C:\Logs'
    WithReplace          = $true
    Force                = $true
}
Copy-SQLDatabaseOffline @params