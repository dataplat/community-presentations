Break # so everything doesn't run
Function prompt {"PS [DbaTools]> " }



#Start Region Basics
#Basics
#Installing the Module under your Current User (Doesn't require Admin)
Install-Module Dbatools -Scope CurrentUser
Update-Module Dbatools
# Also may manually download from github.com/sqlcollaborative
# Although the GitHub version is not Signed.

Import-Module Dbatools
Get-Module Dbatools

Get-Command -Module Dbatools | Measure-Object

Get-Command -name *Migration* -ModuleName Dbatools
Find-DbaCommand -Pattern Migration
Find-DbaCommand -Tag 'AG'


# Use Alternative credentials if you aren't using your current login session

# Toggle Screencast
$cred = Get-Credential corrick\astrid

$SQLCredentials = (Get-Credential)
$PSDefaultParameterValues['Invoke-DbaQuery:SqlCredential'] = $SQLCredentials
#Toggle ScreenCastMode

#Run as two differen users
$query = @"
SELECT TOP 5 [PurchaseOrderID],[StockItemID],[Description],[ReceivedOuters],[ExpectedUnitPricePerOuter]
FROM [WideWorldImporters].[Purchasing].[PurchaseOrderLines]
"@
Invoke-DbaQuery -SqlInstance sqltestbed -SqlCredential $cred -Query $query
Invoke-DbaQuery -SqlInstance sqltestbed -SqlCredential $cred -Query 'SELECT ORIGINAL_LOGIN()'

Invoke-DbaQuery -SqlInstance sqltestbed -Query @query
Invoke-DbaQuery -SqlInstance sqltestbed -Query 'SELECT ORIGINAL_LOGIN()'

cls
#End Region Basics


#Region Start-DbaMigration

$Source = Connect-DbaInstance -SqlInstance sql2008r2
$Destination1 = Connect-DbaInstance -SqlInstance sqltestbed
$Destination2 = 'sqltestbed\sql2017'
Get-DbaDatabase -SqlInstance $Source -UserDbOnly
Get-DbaDatabase -SqlInstance $Destination1,$Destination2 -UserDbOnly | Group-Object SqlInstance




# Start-DbaMigration is made up of ~20 cmdlets this is just an "Easy Button"
# There are two major ways Start-DbaMigration Works
Get-help -Name Start-DbaMigration -Parameter Exclude

# 1. Backup/Restore (Sql2008r2 > sqltestbed)
Start-DbaMigration -Source $Source -Destination $Destination1 -BackupRestore -SharedPath \\dsctest\SQLMigration -Exclude DatabaseMail,SysDbUserObjects,AgentServer,ExtendedEvents

Get-DbaDatabase -SqlInstance $Source -UserDbOnly | Select-Object Name,SQLInstance
Get-DbaDatabase -SqlInstance $Destination1 -UserDbOnly | Select-Object Name,SQLInstance



# 2. Detatch/Copy/Restore (sql2008r2 > sqltestbed\sql2017) (Need Admin FileShare Open)
Start-DbaMigration -Source $Source -Destination $Destination2 -DetachAttach -Exclude DatabaseMail,SysDbUserObjects,AgentServer,ExtendedEvents -Verbose






cls
#End Region Start-DbaMigration



#Region  A look inside

# Start-DbaMigration contains the following Copy cmdlets

Copy-DbaAgentServer
Copy-DbaBackupDevice
Copy-DbaCredential
Copy-DbaCustomError
Copy-DbaDatabase
Copy-DbaDataCollector
Copy-DbaDbMail
Copy-DbaEndpoint
Copy-DbaInstanceAudit
Copy-DbaInstanceAuditSpecification
Copy-DbaInstanceTrigger
Copy-DbaLinkedServer
Copy-DbaLogin
Copy-DbaPolicyManagement
Copy-DbaRegServer
Copy-DbaResourceGovernor
Copy-DbaSpConfigure
Copy-DbaStartupProcedure
Copy-DbaSysDbUserObject
Copy-DbaXESession

#But there are also these 11 cmdlets not included in Start-DbaMigration

# Copy-DbaAgentAlert
# Copy-DbaAgentJob
# Copy-DbaAgentJobCategory
# Copy-DbaAgentOperator
# Copy-DbaAgentProxy
# Copy-DbaAgentSchedule
# Copy-DbaDbAssembly
# Copy-DbaDbQueryStoreOption
# Copy-DbaDbTableData
# Copy-DbaSsisCatalog
# Copy-DbaXESessionTemplate


Copy-DbaDatabase -Source $Source -Destination $Destination2 -AllDatabases -DetachAttach -Verbose

Get-DbaDatabase -SqlInstance $Source -UserDbOnly | Select-Object Name,SQLInstance
Get-DbaDatabase -SqlInstance $Destination2 -UserDbOnly | Select-Object Name,SQLInstance


#Or if you are just migrating Users
Copy-DbaLogin -Source $Destination1 -Destination $Destination2 -Login 'Corrick\astrid','BobWard'
Sync-DbaLoginPermission -Source $Destination1 -Destination $Destination2 -Verbose

#New-DbaCredential
Copy-DbaCredential -Source $Destination1 -Destination $Destination2


#end Region A look inside


#Region offline migrations

#there are options for offline or slow link migrations
Backup-DbaDatabase

Export-DbaCredential
Export-DbaDacPackage
Export-DbaDbRole
Export-DbaDbTableData
Export-DbaDiagnosticQuery
Export-DbaExecutionPlan
Export-DbaInstance
Export-DbaLinkedServer
Export-DbaLogin
Export-DbaPfDataCollectorSetTemplate
Export-DbaRegServer
Export-DbaRepServerSetting
Export-DbaScript
Export-DbaServerRole
Export-DbaSpConfigure
Export-DbatoolsConfig
Export-DbaUser
Export-DbaXECsv
Export-DbaXESession
Export-DbaXESessionTemplate


#If you want to just have things avalible to you for an "Offline" move, or backups
$Destination1 = Connect-DbaInstance -SqlInstance sqltestbed
Export-DbaInstance -SqlInstance $Destination1 -FilePath C:\users\Josh.corrick\Documents\ -Verbose

explorer.exe C:\users\josh.CORRICK\Documents\DbatoolsExport

#end Region Export


#Begin Region Massive moves

#If you have larger databases 1Tb+ that need to be cut over quickly.
#Pre-Requisites
#       The following settings need to be made before log shipping can be initiated:
#        - Backup destination (the folder and the privileges)
#        - Copy destination (the folder and the privileges)

# Very Large Database Migration
$params = @{
    Source                          = 'sqltestbed\SQL2008R2SP2'
    Destination                     = 'sqltestbed'
    Database                        = 'AdventureWorksDW2008R2'
    SharedPath                      = '\\dsctest\SQLMigration'
    BackupScheduleFrequencyType     = 'Daily'
    BackupScheduleFrequencyInterval = 1
    CompressBackup                  = $true
    CopyScheduleFrequencyType       = 'Daily'
    CopyScheduleFrequencyInterval   = 1
    GenerateFullBackup              = $true
    Force                           = $true
}

Invoke-DbaDbLogShipping @params -Verbose

# Recover when ready
Invoke-DbaDbLogShipRecovery -SqlInstance sqltestbed -Database AdventureWorksDW2008R2 -Verbose



#End Region