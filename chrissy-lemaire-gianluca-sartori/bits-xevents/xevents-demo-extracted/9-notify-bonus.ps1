# As an added bonus, you can even get email notifications

# Make sure the session is started
Start-DbaXESession -SqlInstance localhost\sql2017 -Session 'Deadlock Graphs'

# Use a PowerShell splat
$params = @{
    SmtpServer = "localhost"
    To = "sqldba@ad.local"
    Sender = "reports@ad.local"
    Subject = "Deadlock Captured"
    Body = "Caught a deadlock"
    Event = "xml_deadlock_report"
    Attachment = "xml_report"
    AttachmentFileName = "report.xdl"
}

$emailresponse = New-DbaXESmartEmail @params
Start-DbaXESmartTarget -SqlInstance localhost\sql2017 -Session 'Deadlock Graphs' -Responder $emailresponse

# Create deadlock
Start-Process -FilePath powershell -ArgumentList C:\github\xevents-demo\deadlock-maker.ps1 -Wait