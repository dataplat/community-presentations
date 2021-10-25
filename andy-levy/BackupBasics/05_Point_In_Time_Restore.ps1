Clear-Host;
<#
# Point In Time Restore
Who hasn't accidentally dropped a table?

## Function Demonstrated:
* `Invoke-DbaQuery`
#>

$PreUpdateTime = Get-Date;
$SOUpdateParams = @{
    SqlInstance = "FLEXO\sql17";
    Database    = "StackOverflow2010";
    Query = "drop table [Users];";
}
Invoke-DbaQuery @SOUpdateParams;

<#
Let's restore the database so we can fix the data

Take a log backup so we have something to work with
#>
Start-DbaAgentJob -SqlInstance FLEXO\sql17 -Job "DatabaseBackup - USER_DATABASES - Log" -Wait;

<#
Now we'll restore the database to a new one to use as a reference
#>
$RestoreParams = @{
    SqlInstance               = "FLEXO\sql17";
    Path                      = 'C:\sql\Backup\FLEXO$SQL17\StackOverflow2010\';
    DatabaseName              = "StackOverflow2010-Restored";
    RestoreTime               = $PreUpdateTime;
    ReplaceDbNameInFile       = $true;
    MaintenanceSolutionBackup = $true;
}
$RestoreResult = Restore-DbaDatabase @RestoreParams;

$RestoreResult | Format-List -Property *;

<#
Database is restored, let's verify the table is there
#>

$SOQueryParams = @{
    SqlInstance = "FLEXO\sql17";
    Database    = "StackOverflow2010";
    Query = "select count(*) as UserCount from [Users];"
}

Invoke-DbaQuery @SOQueryParams | Format-Table -AutoSize;

$SOQueryParams["Database"] = "StackOverflow2010-Restored";
Invoke-DbaQuery @SOQueryParams | Format-Table -AutoSize;

<#
## Cleanup

Data looks good in the restored database, so we'll fix things up in the live database using that data (not shown), then remove the restored database.
## Function Demonstrated:
* `Remove-DbaDatabase`
#>

Remove-DbaDatabase -SqlInstance FLEXO\SQL17 -Database StackOverflow2010-Restored;