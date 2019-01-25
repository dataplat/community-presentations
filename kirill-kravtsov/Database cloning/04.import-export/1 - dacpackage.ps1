# define export options
$exportOptions = New-DbaDacOption -Type Dacpac -Action Export
$exportOptions.IgnorePermissions = $true
$exportOptions.IgnoreUserLoginMappings = $true
$exportOptions.ExtractAllTableData = $true

# export dacpac
$exportSplat = @{
    SqlInstance = 'localhost'
    Database    = 'AdventureWorksLT2012'
    Path        = 'c:\temp'
    DacOption   = $exportOptions
}
$exportFile = Export-DbaDacpac @exportSplat
$exportFile

# define publish options
$publishOptions = New-DbaDacOption -Type Dacpac -Action Publish
$publishOptions.DeployOptions.AllowIncompatiblePlatform = $true # allow cloning to a prior version of SQL Server
$publishOptions.DeployOptions.CreateNewDatabase = $true         # re-create the database every time
# ignore certain object types
$publishOptions.DeployOptions.ExcludeObjectTypes = 'Permissions', 'RoleMembership'
$publishOptions.DeployOptions.ExcludeLogins = $true
$publishOptions.DeployOptions.IgnorePermissions = $true
$publishOptions.DeployOptions.IgnoreUserSettingsObjects = $true
$publishOptions.DeployOptions.IgnoreLoginSids = $true
$publishOptions.DeployOptions.IgnoreRoleMembership = $true

# publish dacpac
$publishSplat = @{
    SqlInstance = 'localhost\I2'
    Database    = 'AdventureWorksLT2012_clone_4.1'
    Path        = $exportFile.Path
    DacOption   = $publishOptions
}
Publish-DbaDacpac @publishSplat