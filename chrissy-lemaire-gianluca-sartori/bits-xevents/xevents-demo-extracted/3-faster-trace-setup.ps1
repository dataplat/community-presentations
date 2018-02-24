break

# Complaint: Faster to setup quick traces
# Complaint: Templates work remotely across all instances
# Answer: Now you can easily deploy all of your session templates SUCH AS LONG RUNNING QUERIES
$servers = "localhost\sql2016","localhost\sql2017"
Get-DbaXESessionTemplate | Out-GridView -PassThru | Import-DbaXESessionTemplate -SqlInstance $servers


<# 

      No suitable template? Use SSMS to create New Sessions

#>


# now redeploy existing sessions across your whole enterprise
Get-DbaXESession -SqlInstance localhost\sql2017 -Session 'Acme Sample' | Export-DbaXESessionTemplate | Import-DbaXESessionTemplate -SqlInstance localhost\sql2016

Start-Process "$home\Documents\SQL Server Management Studio\Templates\XEventTemplates"