Get-DbaCustomError -SqlInstance localhost\sql2016 | Where Id -eq 50001
Get-DbaDatabase -SqlInstance localhost\sql2016 -Database anotherdb, db1, dbwithsprocs

Get-DbaLogin -SqlInstance localhost\sql2016 -Login 'WORKSTATION\powershell','login1','login2','login3','login4','login5'

Get-DbaCredential -SqlInstance localhost\sql2016 -Name abc, AzureCredential, dbatools, 'https://dbatools.blob.core.windows.net/sql', 'PowerShell Proxy Account', 'PowerShell Service Account'

Get-DbaServerTrigger -SqlInstance localhost\sql2016 | Where Name -in 'tr_MScdc_db_ddl_event','dbatoolsci-trigger'

Get-DbaLinkedServer -SqlInstance localhost\sql2016 -LinkedServer 'localhost','repl_distributor','SQL2012','SQL2014','SQL2016','SQL2016A'

Get-DbaBackupDevice -SqlInstance localhost\sql2016 | Where Name -eq 'sup baw'

Get-DbaDbMailProfile -SqlInstance localhost\sql2016 -Profile 'The DBA Team'
Get-DbaDbMailAccount -SqlInstance localhost\sql2016 -Account 'The DBA Team'

Get-DbaXeSession -SqlInstance localhost\sql2016 -Session 'AlwaysOn_health','Queries and Resources','Query Timeouts','Query Wait Statistics','Query Wait Statistics Detail','Stored Procedure Parameters','system_health','telemetry_xevents'

Get-DbaAgentJob -SqlInstance localhost\sql2016 -Job 'CommandLog Cleanup', 'DatabaseBackup - SYSTEM_DATABASES - FULL', 'DatabaseBackup - USER_DATABASES - DIFF', 'DatabaseBackup - USER_DATABASES - FULL', 'DatabaseBackup - USER_DATABASES - LOG', 'DatabaseIntegrityCheck - SYSTEM_DATABASES', 'DatabaseIntegrityCheck - USER_DATABASES', 'IndexOptimize - USER_DATABASES', 'Output File Cleanup', 'sp_delete_backuphistory', 'sp_purge_jobhistory', 'syspolicy_purge_history'

Get-DbaAgentAlert -SqlInstance localhost\sql2016 | Where Name -in 'adf', 'Error Number 823', 'Error Number 824', 'Error Number 825', 'Severity 016', 'Severity 017', 'Severity 018', 'Severity 019', 'Severity 020', 'Severity 021', 'Severity 022', 'Severity 023', 'Severity 024', 'Severity 025'

Get-DbaAgentOperator -SqlInstance localhost\sql2016 -Operator 'The DBA Team','Teste','poobutt','MSXOperator'

Get-DbaRgResourcePool -SqlInstance localhost\sql2016 | Where Name -eq 'Test Pool'

Get-DbaEndpoint -SqlInstance localhost\sql2016 | Where Name -in endpoint_mirroring

Get-DbaServerAuditSpecification -SqlInstance localhost\sql2016 | Where Name -in 'ServerAuditSpecification-20160502-100608', 'ServerAuditSpecification-20160502-100608'

Get-DbaServerAudit -SqlInstance localhost\sql2016 | Where Name -in 'Audit-20160502-100608', 'Audit-20170210-150427'