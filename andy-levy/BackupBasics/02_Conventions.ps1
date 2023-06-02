Clear-Host;
<#
# Conventions
## Getting Help
Every dbatools function has extensive comment-based help accessible via `Get-Help`. This help is also available at https://docs.dbatools.io/

`Find-DbaCommand <searchterm>` is your friend! Use this function to locate functions related to what you need to do.
#>
$BackupFunctions = Find-DbaCommand -Pattern backup;

$BackupFunctions.Count;

$BackupFunctions;

<#
## Naming Conventions

* dbatools follows standard Powershell function naming conventions
  * All dbatools function names follow the convention `Verb-DbaNoun`
  * Most `Get`s have a corresponding `Set`
* Functions with `Db` in their name _usually_ want to operate on the database level, not the whole instance.
#>
<#
## Splatting

Variable splatting is a method in Powershell where we can pass a collection of parameters to a function. This makes it easier to:
* Read without scrolling horizontally
* Dynamically change the parameter list passed to a function
For more information, see [`get-help about_splatting`](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_splatting?view=powershell-7.1)

When using splatting with switch parameters, you must explicitly state `$true` or `$false` for the switch value. For example, `-Verbose` becomes `Verbose = $true;`
#>

$BackupParams = @{
    SqlInstance  = "FLEXO\sql17";
    Path         = $BackupPath;
    Database     = "satellites";
    CreateFolder = $true;
}