foreach ($function in (Get-ChildItem "$PSScriptRoot\functions\*.ps1")) { . $function }

# In order to keep backwards compatability, these are loaded here instead of in the manifest.
$null = [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.Management.Sdk.Sfc")
$null = [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SqlEnum")
$null = [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.ConnectionInfo")
$null = [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SqlWmiManagement")