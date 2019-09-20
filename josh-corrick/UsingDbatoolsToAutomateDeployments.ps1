Break # so everything doesn't run
Function prompt {"PS [DbaTools]> " }



#Start Region Basics
#Basics
#Installing the Module under your Current User (Doesn't require Admin)
Install-Module Dbatools -Scope CurrentUser
Update-Module Dbatools
# Also may manually download from github.com/sqlcollaborative

Import-Module Dbatools
Get-Module Dbatools

Get-Command -Module Dbatools | Measure-Object

Find-Command -ModuleName Dbatools
Find-DbaCommand -Pattern Migration
Find-DbaCommand -Tag 'Migration'


#End Region Basics

# Use Alternative credentials if you aren't using your current login session
$cred = Get-Credential corrick\astrid

$SQLCredentials = (Get-Credential)
$PSDefaultParameterValues['Invoke-DbaQuery:SqlCredential'] = $SQLCredentials








#Region Start-DbaMigration

$Source = Connect-DbaInstance -SqlInstance sql2008r2
$Destination1 = Connect-DbaInstance -SqlInstance sqltestbed\sql2017
$Destination2 = 'sqltestbed'
Get-DbaDatabase -SqlInstance $Source -UserDbOnly
Get-DbaDatabase -SqlInstance $Destination1,$Destination2 -UserDbOnly




# Start-DbaMigration is made up of ~20 cmdlets this is just an "Easy Button"
# There are two major ways Start-DbaMigration Works
Get-help -Name Start-DbaMigration -Parameter Exclude

# 1. Detatch/Copy/Restore (Need Admin FileShare Open, as well as DAC Enabled for some setting migrations)
Start-DbaMigration -Source $Source -Destination $Destination1 -DetachAttach -Exclude DatabaseMail,SysDbUserObjects,AgentServer,ExtendedEvents  |  Out-GridView


# 2. Backup/Restore
Start-DbaMigration -Source $Source -Destination $Destination2 -BackupRestore -LastBackup





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



Copy-DbaDatabase -Source $Source -Destination $Destination2 -BackupRestore -SharedPath \\dsctest\SQLMigration\ -Verbose
#Or if you are just migrating Users
Copy-DbaLogin -Source $Source -Destination $Destination2 -Login 'Josh'
Copy-DbaCredential -Source $Source -Destination $Destination2


#end Region A look inside


#Region offline migrations



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
Export-DbaInstance -SqlInstance $Destination2 -FilePath C:\users\Josh.corrick\Documents\

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
    Source                          = 'Sql2008r2'
    Destination                     = 'sqltestbed\sql2017'
    Database                        = 'SuperBigDB'
    SharedPath                      = '\\dsctest\SQLMigration'
    BackupScheduleFrequencyType     = 'Daily'
    BackupScheduleFrequencyInterval = 1
    CompressBackup                  = $true
    CopyScheduleFrequencyType       = 'Daily'
    CopyScheduleFrequencyInterval   = 1
    GenerateFullBackup              = $true
    Force                           = $true
}

Invoke-DbaDbLogShipping @params

# Recover when ready
Invoke-DbaDbLogShipRecovery -SqlInstance localhost\sql2017 -Database shipped



#End Region