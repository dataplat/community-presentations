Break
Function prompt {"PS [DbaTools]> " }
#Installing the Module under your Current User (Doesn't require Admin)


#Start Region Basics
#Basics
Install-Module Dbatools -Scope CurrentUser
Update-Module Dbatools
Import-Module Dbatools


#End Region Basics

# Use Alternative credentials if you aren't using your current login session
$cred = Get-Credential corrick\josh
Get-DbaDiskSpace -ComputerName sqltestbed -Credential $cred

#Region Start-DbaMigration

$Source = Connect-DbaInstance -SqlInstance sql2008r2
$Destination = Connect-DbaInstance -SqlInstance sqltestbed\sql2017
Get-DbaDatabase -SqlInstance $Source -UserDbOnly
Get-DbaDatabase -SqlInstance $Destination -UserDbOnly

# Start-DbaMigration is made up of ~30 cmdlets this is just an "Easy Button"
# There are two major ways Start-DbaMigration Works
# 1. Detatch/Copy/Restore (Need Admin FileShare Open, as well as DAC Enabled)
# 2. Backup/Restore

Start-DbaMigration -Source $Source -Destination $Destination -DetachAttach -Exclude DatabaseMail,SysDbUserObjects,AgentServer,ExtendedEvents  |  Out-GridView

Start-DbaMigration -Source $Source -Destination $Destination -BackupRestore -UseLastBackup


#If you want to just have things avalible to you for an "Offline" move, or backups
Export-DbaInstance -SqlInstance $Source -Path C:\users\Josh\Documents\


#Or if you are just migrating Users
Copy-DbaLogin -Source $Source -Destination $Destination -Login 'Josh'

#If you have larger databases 1Tb+ that need to be cut over quickly.

# Very Large Database Migration
$params = @{
    Source                          = 'localhost'
    Destination                     = 'localhost\sql2017'
    Database                        = 'shipped'
    SharedPath                      = '\\localhost\backups'
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