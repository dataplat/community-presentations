break
# Complaint: Already have a library of Profiler templates
# Answer: Convert them instantly to Sessions (h/t Jonathan Kehayias)
Get-DbaTrace -SqlInstance localhost\sql2017 -Id 1 | ConvertTo-DbaXESession -Name 'Default Trace' | Start-DbaXESession

# Go look in SSMS! :D

# Stop or remove those bad boys
Get-DbaTrace -SqlInstance localhost\sql2017 -Id 2 | Stop-DbaTrace
Get-DbaTrace -SqlInstance localhost, localhost\sql2016, localhost\sql2017 | Out-GridView -PassThru | Remove-DbaTrace

# now that you're done with traces, let's talk about xevents