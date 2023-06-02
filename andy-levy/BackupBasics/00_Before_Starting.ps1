<#
Do this before starting new session
#>
Clear-Host;
Remove-DbaDatabase -SqlInstance flexo\sql17 -database stackoverflow2010 -confirm:$false;
Remove-Item -force -Path 'C:\SQL\Backup\FLEXO$SQL17\StackOverflow2010' -recurse -confirm:$false;
Restore-DbaDatabase -SqlInstance FLEXO\sql17 -DatabaseName StackOverflow2010 -ReplaceDbNameInFile -WithReplace -Path C:\Datasets\StackOverflow2010.bak;
Invoke-DbaQuery -SqlInstance FLEXO\sql17 -Database msdb -Query "exec sp_delete_database_backuphistory @database_name='StackOverflow2010';";
Start-DbaAgentJob -SqlInstance FLEXO\sql17 -Job "DatabaseBackup - USER_DATABASES - FULL" -Wait;
Start-DbaAgentJob -SqlInstance FLEXO\sql17 -Job "DatabaseBackup - USER_DATABASES - Log" -Wait;