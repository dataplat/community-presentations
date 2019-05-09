Break
Function prompt {"PS [DbaTools]> " }
#Installing the Module under your Current User (Doesn't require Admin)
Install-Module dbatools -Scope CurrentUser
Get-Module
# If you don't have PSGet you can use the following, but be aware that
# you should only execute Invoke-Expression against a URL you trust
#Invoke-Expression (Invoke-WebRequest https://dbatools.io/in)

# Use Alternative credentials if you aren't using your current login session
$cred = Get-Credential corrick\josh
Get-DbaDiskSpace -ComputerName sqltestbed -Credential $cred

# If you are trying to connect to an instance with a different port
#-SqlInstance sql2017:55559
#-SqlInstance 'sql2017,55559'

#Note: This demo was Adhoc as there was a small group of
# People who had little experience with PowerShell and Dbatools
# It ended up being audience driven.

#Traditional way to Find out which commands are avalible to you
Get-Command -Module Dbatools
Get-Command -Module Dbatools -Verb Get
Get-Command -Module Dbatools -Verb Get -Noun DbaDatabase

#Using Dbatools to find stuff
Find-DbaCommand -Pattern database
#someone asked if we had cmdlets about DacPacks
Find-DbaCommand -Pattern Dac
#We didn't know what New-DbaDacOption did so we looked at the help
Get-Help New-DbaDacOption -Full

#someone else asked if there were ways to install Ola Hallengren's maintenance solution
Find-DbaCommand -Pattern maintenance
#also they wanted to know if you could update using the Install-DbaMaintenanceSolution
Get-help Install-DbaMaintenanceSolution -Syntax

#Someone then asked if there was a way to query.
#We Began looking at this command.
Invoke-DbaQuery

#Then we steped back to figure out what we wanted to query.
Get-DbaDatabase -SqlInstance sqltestbed -ExcludeSystem

# Next we found WWImporters and put in into a variable
$database = Get-DbaDatabase -SqlInstance sqltestbed -Database WideWorldImporters

# Next we explored the tables
$database.Tables | Select-Object Name
$database.Tables | Where-Object {$_.name -eq 'Cities'}
$database.Tables | Where-Object {$_.name -eq 'Cities'} | Select-Object columns

#We ran out of time, but Here is a query then that we could write using this
Invoke-DbaQuery -SqlInstance Sqltestbed -Query "SELECT CityID,CityName FROM Application.cities" -Database WideWorldImporters