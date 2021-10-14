<#
# Reset Environment
Do this after the demos are done
#>
Clear-Host;
Set-DbaSpConfigure -SqlInstance FLEXO\sql17 -Name DefaultBackupCompression -Value 0;
Remove-Item c:\users\andy\documents\BackupHistory.xlsx;
Remove-Item C:\users\andy\documents\BackupVerification.xlsx;
get-childitem -path C:\SQL\Backup -File | Remove-Item
Get-ChildItem -path C:\SQL\Export -recurse | remove-item -force -confirm:$false -recurse;
Remove-Item -Force -recurse -confirm:$false "C:\SQL\Backup\Satellites";
remove-item -Force -Recurse -Confirm:$false 'C:\SQL\Backup\FLEXO$SQL17\StackOverflow2010-Restored'
Remove-DbaDatabase -SqlInstance FLEXO\sql19 -Database Satellites19 -Confirm:$false;
Remove-DbaDatabase -SqlInstance FLEXO\sql17 -Database StackOverflow2010-Restored -Confirm:$false;
Restore-DbaDatabase -SqlInstance FLEXO\sql17 -DatabaseName StackOverflow2010 -ReplaceDbNameInFile -WithReplace -Path C:\Datasets\StackOverflow2010.bak;
Start-DbaAgentJob -SqlInstance FLEXO\sql17 -Job "DatabaseBackup - USER_DATABASES - FULL" -Wait;
Start-DbaAgentJob -SqlInstance FLEXO\sql17 -Job "DatabaseBackup - USER_DATABASES - LOG";
# Remove Ola jobs from flexo\sql19
Get-DbaAgentJob -SqlInstance FLEXO\sql19 -Category "Database Maintenance" | Remove-DbaAgentJob;
(Get-DbaDbTable -SqlInstance FLEXO\sql19 -database dbathings | Where-Object { $PSItem.name -in @("BackupValidation", "CommandLog") }).DropIfExists();

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