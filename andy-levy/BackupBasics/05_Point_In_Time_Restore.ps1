Clear-Host;
<#
# Point In Time Restore
Who hasn't run a bad update? Let's try adjusting a Stack Overflow user's reputation.
## Function Demonstrated:
* `Invoke-DbaQuery`
#>

<#
Take a look at some data
#>
$SOQueryParams = @{
    SqlInstance = "FLEXO\sql17";
    Database    = "StackOverflow2010";
    Query       = "select getdate() AS [QueryDate],* from [Users] where [DisplayName] = 'user46185';";
}
Invoke-DbaQuery @SOQueryParams;

<#
Let's improve this user's reputation
#>
$PreUpdateTime = Get-Date;
$SOUpdateParams = $SOQueryParams
$SOUpdateParams["Query"] = "update [Users] set [Reputation] = 200 where [DisplayName] = 'user461855';";

Invoke-DbaQuery @SOUpdateParams;

<#
We made a mistake!
#>

$SOQueryParams["Query"] = "select getdate() AS [QueryDate],Id,DisplayName,Reputation,CreationDate,LastAccessDate from [Users] where [DisplayName] in ('user46185','user461855');";
Invoke-DbaQuery @SOQueryParams | Format-Table -AutoSize;

<#
Let's restore the database so we can fix the data

Take a log backup so we have something to work with
#>
$BackupParams = @{
    SqlInstance = "FLEXO\sql17";
    Type        = "Log";
    Database    = "StackOverflow2010";
    FilePath    = 'C:\SQL\Backup\FLEXO$SQL17\StackOverflow2010\LOG\FLEXO$SQL17_StackOverflow2010_LOG_' + (get-date -f "yyyyMMdd_HHmmss") + ".trn";
    BuildPath   = $true;
}
Backup-DbaDatabase @BackupParams;

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
Database is restored, let's verify the data is in the right state
#>
$SOQueryParams["Database"] = "StackOverflow2010-Restored";
$SOQueryParams["Query"] = "select getdate() AS [QueryDate],Id,DisplayName,Reputation,CreationDate,LastAccessDate from [Users] where [DisplayName] in ('user46185','user461855');";
Invoke-DbaQuery @SOQueryParams | Format-Table -AutoSize;

<#
## Cleanup

Data looks good in the restored database, so we'll fix things up in the live database using that data (not shown), then remove the restored database. I'm using `-Confirm:$false` because the prompt won't work in Azure Data Studio.
## Function Demonstrated:
* `Remove-DbaDatabase`
#>

Remove-DbaDatabase -SqlInstance FLEXO\SQL17 -Database StackOverflow2010-Restored -Confirm:$false;