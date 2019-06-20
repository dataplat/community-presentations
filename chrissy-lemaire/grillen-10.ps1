break
#region Basics

# Registered Servers
Get-DbaRegisteredServer # aliased
Connect-DbaInstance -SqlInstance localhost -SqlCredential sqladmin | Add-DbaRegServer
Get-DbaRegisteredServer -Group onprem | Get-DbaDatabase | Select SqlInstance, Name | Format-Table -AutoSize



# Connect-DbaInstance, supports everything! MFA
Get-DbaRegisteredServer -Name azuresqldb | Connect-DbaInstance




# CSV galore! - Rob
Get-ChildItem C:\temp\grillen\csv
Get-ChildItem C:\temp\grillen\csv | Import-DbaCsv -SqlInstance sql2017 -Database tempdb -AutoCreateTable -Encoding UTF8
Invoke-DbaQuery -SqlInstance sql2017 -Database tempdb -Query "Select top 10 * from [jmfh-year]"



# Write-DbaDbTableData - Claudio
Get-ChildItem -File | Write-DbaDbTableData -SqlInstance sql2017 -Database tempdb -Table files -AutoCreateTable
Get-ChildItem -File | Select *
Invoke-DbaQuery -SqlInstance sql2017 -Database tempdb -Query "Select * from files"


# New-DbaLogin - Claudio
$instance = "localhost\sql2017"
$database = "AdventureWorks2014"
$login = "u_DataGrillen"
$username = $login
$newRole = "SPExecuter"
$roles = "db_datareader", "db_datawriter", $newRole

<# Reset
# Remove new DB role
Remove-DbaDbRole -SqlInstance $instance -Database $database -Role $newRole -Confirm:$false

#Remove database user
Remove-DbaDbUser -SqlInstance $instance -Database $database -User $username -Confirm:$false

#Remove instance login
Remove-DbaLogin -SqlInstance $instance -Login $login -Confirm:$false
#>

# Create new login
New-DbaLogin -SqlInstance $instance -Login $login -DefaultDatabase $database -SecurePassword $password

# Create new user
New-DbaDbUser -SqlInstance $instance -Database $database -Username $username -Login $login

# Create new DB role
New-DbaDbRole -SqlInstance $instance -Database $database -Role $newRole

# Add new Role
Add-DbaDbRoleMember -SqlInstance $instance -Database $database -Role $roles -User $username -Confirm:$false

# Get roles where user is member
Get-DbaDbRoleMember -SqlInstance $instance -Database $database -Role $roles | Where-Object Username -eq $username

#endregion




#region Must Haves

# Gotta find it, run this once - Chrissy & Rob
Find-DbaInstance -ComputerName localhost




# PII Management - Chrissy & Rob
Invoke-DbaDbPiiScan -SqlInstance localhost\sql2017 -Database AdventureWorks2014 | Out-GridView


# Mask that
New-DbaDbMaskingConfig -SqlInstance localhost\sql2017 -Database AdventureWorks2014 -Table EmployeeDepartmentHistory, Employee -Path C:\temp | Invoke-Item
Invoke-DbaDbDataMasking -SqlInstance localhost\sql2017 -FilePath 'C:\github\community-presentations\chrissy-lemaire\mask.json' -ExcludeTable EmployeeDepartmentHistory



# VLDB / Combo kill  - Rob
Invoke-Item 'C:\temp\grillen\click-a-rama.mp4'

# All in one, no hassle - includes credentials!
$docker1 = Get-DbaRegisteredServer -Name dockersql1
$docker2 = Get-DbaRegisteredServer -Name dockersql2

# setup a powershell splat (has docker been reset?)
$params = @{
    Primary      = $docker1
    Secondary    = $docker2
    Name         = "test-ag"
    Database     = "pubs"
    ClusterType  = "None"
    SeedingMode  = "Automatic"
    FailoverMode = "Manual"
    Confirm      = $false
}

# execute the command
New-DbaAvailabilityGroup @params


# Install-DbaInstance / Update-DbaInstance - Claudio
Update-DbaInstance -ComputerName sql2017 -Path \\dc\share\patch -Credential base\ctrlb
Invoke-Item 'C:\temp\grillen\Patch several SQL Servers at once using Update-DbaInstance by Kirill Kravtsov.mp4'



#endregion





#region fan favorites

# Spaghetti!
New-DbaDiagnosticAdsNotebook -TargetVersion 2017 -Path C:\temp\myNotebook.ipynb | Invoke-Item


# Compression! Jess
$results = Test-DbaDbCompression -SqlInstance localhost\sql2017 -Database AdventureWorks
$results | Where-Object TableName -eq SalesOrderDetail |
Select-Object TableName, IndexName, CompressionTypeRecommendation, SizeCurrent, SizeRequested, PercentCompression | Format-Table

Set-DbaDbCompression -SqlInstance localhost\sql2017 -InputObject $results

# Diagnostic! Andre
Invoke-DbaDiagnosticQuery -SqlInstance localhost\sql2017 | Export-DbaDiagnosticQuery -OutVariable exports
$exports | Select-Object -Skip 3 -First 1 | Invoke-Item


#endregion



#region Combo kills

# Start-DbaMigration wraps 30+ commands - Rob
$params = @{
    Source      = "localhost"
    Destination = "localhost\sql2016"
    UseLastBackup = $true
    Exclude = "BackupDevices", "SysDbUserObjects"
 }

Start-DbaMigration @params -WarningAction SilentlyContinue | Out-GridView



# Wraps like 20 - Chrissy
Export-DbaInstance -SqlInstance localhost\sql2017 -Path C:\temp\dr
Get-ChildItem -Path C:\temp\dr -Recurse -Filter *database* | Invoke-Item

#endregion


#region BONUS
Get-ChildItem C:\github\community-presentations\*ps1 -Recurse | Invoke-DbatoolsRenameHelper | Out-GridView
#endregion


# All together
# Find-DbaCommand
# dbatools.io/commands 
# https://docs.dbatools.io/


# More VLDB
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
