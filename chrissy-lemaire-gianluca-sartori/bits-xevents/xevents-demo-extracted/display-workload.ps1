$host.ui.RawUI.WindowTitle = "WorkloadReplay Session Watcher"
Write-Host -Foreground Green "Please go start your workload and come back"
Import-Module C:\temp\new\dbatools\dbatools.psm1

Get-DbaXESession -SqlInstance localhost\sql2016 -Session WorkloadReplay | Start-DbaXESession | Watch-DbaXESession | Select-Object -ExpandProperty batch_text

