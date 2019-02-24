Describe "doomsday tests" -Tags "IntegrationTests" {
    It "Still has all the databases" {
        $results = Get-DbaDatabase -SqlInstance workstation\sql2016 
        'anotherdb', 'db1', 'dbwithsprocs' | Should -BeIn $results.Name
    }

    It "Still has all the logins" {
        $results = Get-DbaLogin -SqlInstance workstation\sql2016 
        'WORKSTATION\powershell','login1','login2','login3','login4','login5' | Should -BeIn $results.Name
    }

    It "Still has all the credentials" {
        $results = Get-DbaCredential -SqlInstance workstation\sql2016 
       'abc', 'AzureCredential', 'dbatools', 'https://dbatools.blob.core.windows.net/sql', 'PowerShell Proxy Account', 'PowerShell Service Account' | Should -BeIn $results.Name
    }

    It "Still has all the server triggers" {
        $results = Get-DbaServerTrigger -SqlInstance workstation\sql2016 
        'tr_MScdc_db_ddl_event','dbatoolsci-trigger' | Should -BeIn $results.Name
    }

    It "Still has user objects in system databases" {
        $results = Get-DbaDbTable -SqlInstance workstation\sql2016 -Database master -Table CommandLog
        'CommandLog' | Should -BeIn $results.Name
    }

    It "Still has all the linked servers" {
        $results = Get-DbaLinkedServer -SqlInstance workstation\sql2016 
        'localhost','repl_distributor','SQL2012','SQL2014','SQL2016','SQL2016A' | Should -BeIn $results.Name
    }

    It "Still has replication set up" {
        $results = Get-DbaRepServer -SqlInstance workstation\sql2016 
        'distribution' | Should -Be $results.DistributionDatabases.Name
    }

    It "Still has all the registered servers" {
        $results = Get-DbaCmsRegServer -SqlInstance workstation\sql2016 
        'sql2016','sql2017' | Should -BeIn $results.Name
    }

    It "Still has all the registered server groups" {
        $results = Get-DbaCmsRegServerGroup -SqlInstance workstation\sql2016 
        'Site1','Site2' | Should -BeIn $results.Name
    }
    It "Still has all the backup devices" {
        $results = Get-DbaBackupDevice -SqlInstance workstation\sql2016 
        'sup baw' | Should -BeIn $results.Name
    }

    It "Still has the proper configuration settings" {
        $results = Get-DbaSpConfigure -SqlInstance workstation\sql2016 -Name CursorThreshold
        $results.ConfiguredValue  | Should -Be 2000000000
    }

    It "Still has all the custom errors" {
        $results = Get-DbaCustomError -SqlInstance workstation\sql2016 
        $results.Id | Should -Contain 50001
    }

    It "Still has all the mail profiles" {
        $results = Get-DbaDbMailProfile -SqlInstance workstation\sql2016 
        'The DBA Team' | Should -BeIn $results.Name
    }

    It "Still has all the mail accounts" {
        $results = Get-DbaDbMailAccount -SqlInstance workstation\sql2016 
        'The DBA Team' | Should -BeIn $results.Name
    }

    It "Still has all the extended events" {
        $results = Get-DbaXeSession -SqlInstance workstation\sql2016 
        'AlwaysOn_health','Queries and Resources','Query Timeouts','Query Wait Statistics','Query Wait Statistics Detail','Stored Procedure Parameters','system_health','telemetry_xevents' | Should -BeIn $results.Name
    }

    It "Still has all the agent jobs" {
        $results = Get-DbaAgentJob -SqlInstance workstation\sql2016 
        'CommandLog Cleanup', 'DatabaseBackup - SYSTEM_DATABASES - FULL', 'DatabaseBackup - USER_DATABASES - DIFF', 'DatabaseBackup - USER_DATABASES - FULL', 'DatabaseBackup - USER_DATABASES - LOG', 'DatabaseIntegrityCheck - SYSTEM_DATABASES', 'DatabaseIntegrityCheck - USER_DATABASES', 'IndexOptimize - USER_DATABASES', 'Output File Cleanup', 'sp_delete_backuphistory', 'sp_purge_jobhistory', 'syspolicy_purge_history' | Should -BeIn $results.Name
    }

    It "Still has all the agent alerts" {
        $results = Get-DbaAgentAlert -SqlInstance workstation\sql2016 
        'adf','Error Number 823', 'Error Number 824', 'Error Number 825', 'Severity 016', 'Severity 017', 'Severity 018', 'Severity 019', 'Severity 020', 'Severity 021', 'Severity 022', 'Severity 023', 'Severity 024', 'Severity 025' | Should -BeIn $results.Name
    }

    It "Still has all the agent operators" {
        $results = Get-DbaAgentOperator -SqlInstance workstation\sql2016 
        'The DBA Team','Teste','poobutt','MSXOperator' | Should -BeIn $results.Name
    }

    It "Still has all the resource pools" {
        $results = Get-DbaRgResourcePool -SqlInstance workstation\sql2016 
        'Test Pool' | Should -BeIn $results.Name
    }

    It "Still has all the policies" {
        $results = Get-DbaPbmPolicy -SqlInstance workstation\sql2016 
        'awesome' | Should -BeIn $results.Name
    }

    It "Still has all the policy conditions" {
        $results = Get-DbaPbmCondition -SqlInstance workstation\sql2016 
        'hello' | Should -BeIn $results.Name
    }

    It "Still has all the server roles" {
        $results = Get-DbaServerRole -SqlInstance workstation\sql2016 
        'whattup' | Should -BeIn $results.Name
    }

    It "Still has all the endpoints" {
        $results = Get-DbaEndpoint -SqlInstance workstation\sql2016 
        'endpoint_mirroring' | Should -BeIn $results.Name
    }

    It "Still has all the audit specs" {
        $results = Get-DbaServerAuditSpecification -SqlInstance workstation\sql2016 
        'ServerAuditSpecification-20160502-100608', 'ServerAuditSpecification-20160502-100608' | Should -BeIn $results.Name
    }

    It "Still has all the audits" {
        $results = Get-DbaServerAudit -SqlInstance workstation\sql2016 
        'Audit-20160502-100608', 'Audit-20170210-150427' | Should -BeIn $results.Name
    }
}

