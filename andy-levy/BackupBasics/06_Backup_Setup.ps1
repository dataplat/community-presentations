Clear-Host;
<#
# Basic Backup Setup
## Where do backups go?
### Function Demonstrated
* `Get-DbaDefaultPath`
#>

Get-DbaDefaultPath -SqlInstance FLEXO\Sql17;

<#
## Check & Set Backup Compression
### Functions Demonstrated
* `Get-DbaSpConfigure`
* `Set-DbaSpConfigure`
#>

Get-DbaSpConfigure -SqlInstance FLEXO\Sql17 -Name DefaultBackupCompression;
Set-DbaSpConfigure -SqlInstance FLEXO\Sql17 -Name DefaultBackupCompression -Value 1;