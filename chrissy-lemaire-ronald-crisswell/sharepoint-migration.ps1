# Set the source database to Read-Only
Set-DbaDatabaseState -SqlInstance sqlcluster -Database WSS_Content -ReadOnly -Force

# Perform the database and accompanying login migration
Copy-DbaDatabase -Source sqlcluster -Destination sql2017 -Database WSS_Content -BackupRestore -NetworkShare \\nas\sql\migration
Copy-DbaLogin -Source sqlcluster -Destination sql2017 -Login base\sharepoint

# The destination database will be read-only, change to Read-Write
Set-DbaDatabaseState -SqlInstance sql2017 -Database WSS_Content -ReadWrite

# Create webapplication
$webappname = "SharePoint - 80"
New-SPWebApplication -Name $webappname -URL http://sharepoint  -Port 80 -ApplicationPool $webappname -ApplicationPoolAccount (Get-SPManagedAccount base\sharepoint) 

# Mount the webapp
Mount-SPContentDatabase -Name WSS_Content -DatabaseServer sql2017 -WebApplication $webappname

# Confirm
Get-SPWebApplication -Identity http://sharepoint



