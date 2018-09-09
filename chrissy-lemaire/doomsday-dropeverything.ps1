Get-Process *ssms* | Stop-Process
Invoke-DbaQuery -File C:\github\community-presentations\chrissy-lemaire\doomsday-dropeverything.sql -SqlInstance workstation\sql2016 -ErrorAction Ignore
$null = Get-DbaRegisteredServerGroup -SqlInstance workstation\sql2016 | Remove-DbaRegisteredServerGroup -Confirm:$false
. "C:\Program Files (x86)\Microsoft SQL Server\140\Tools\Binn\ManagementStudio\Ssms.exe"