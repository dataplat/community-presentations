
## restore database from a folder with existing backups
## reads the backup headers, builds a backup chain, performs the restore

$params = @{
    SqlInstance         = 'localhost'
    DatabaseName        = 'AdventureWorksLT2012_clone_1.2'
    WithReplace         = $true
    ReplaceDbNameInFile = $true
}

Get-ChildItem -Directory \\localhost\Backups\SQL1\AdventureWorksLT2012 | Restore-DbaDatabase @params