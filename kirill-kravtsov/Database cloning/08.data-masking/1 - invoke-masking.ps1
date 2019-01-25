# restore a database
$params = @{
    SqlInstance          = 'localhost'
    DatabaseName         = 'AdventureWorksLT2012_clone_8.1'
    WithReplace          = $true
    ReplaceDbNameInFile  = $true
    TrustDbBackupHistory = $true
}

Get-DbaBackupHistory -SqlInstance localhost -Database AdventureWorksLT2012 | Restore-DbaDatabase @params

# create a masking config file
New-Item C:\Temp\clone -ItemType Directory -Force
New-DbaDbMaskingConfig -SqlInstance 'localhost' -Database 'AdventureWorksLT2012_clone_8.1' -Path C:\Temp\clone

# check what's there
code C:\Temp\clone

# initialize masking process
Invoke-DbaDbDataMasking -SqlInstance 'localhost' -Database 'AdventureWorksLT2012_clone_8.1' -FilePath C:\Temp\clone