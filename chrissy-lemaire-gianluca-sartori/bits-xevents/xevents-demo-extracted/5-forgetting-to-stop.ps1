break
# Complaint: Remembering to turn off Xevent
# Answer: PowerShell can help in 3 ways

# Answer: Auto create a disappearing Agent job
Start-DbaXESession -SqlInstance localhost\sql2017 -Session 'Long Running Queries' -StopAt (Get-Date).AddMinutes(30)

# Answer: Use dbachecks
Set-DbcConfig -Name policy.xevent.requiredstoppedsession -Value 'Long Running Queries'

# Imagine a scheduled run
Invoke-DbcCheck -SqlInstance localhost\sql2017 -Check XESessionStopped

# Sessions can be easily stopped (or started) en masse
$servers | Get-DbaXESession | Out-GridView -PassThru | Stop-DbaXESession