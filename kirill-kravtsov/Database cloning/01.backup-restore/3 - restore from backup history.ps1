## restore database based on backup history information
## builds a backup chain autmatically, performs the restore up to the most recent backup


$params = @{
    SqlInstance          = 'localhost'
    DatabaseName         = 'AdventureWorksLT2012_clone_1.3'
    WithReplace          = $true
    ReplaceDbNameInFile  = $true
    TrustDbBackupHistory = $true
}

Get-DbaBackupHistory -SqlInstance localhost -Database AdventureWorksLT2012 | Restore-DbaDatabase @params