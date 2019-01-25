Function New-DBConnection {
<#
.SYNOPSIS
Internal function. Generates new SQL connection.
#>
  Param (
    [Alias("Server")]
    [parameter(Position = 1, Mandatory = $true, ValueFromPipeline = $true)]
      [string] $ServerInstance,
    [parameter(Position = 2)]
      [string] $Database = "master",
    [parameter(Position = 3)]
      [System.Management.Automation.PSCredential] $SqlCredential,
    [parameter(Position = 4)]
      [switch] $Open = $false
      
  )
  
  $DbConnectionString = "Server={0};Database={1};Connection Timeout=15;"
  
  If (!$SqlCredential) {
    $DbConnectionString += "Integrated Security=SSPI;"
  }
  Else {
    $DbConnectionString += "User ID={0};Password={1};" -f $SqlCredential.Username, $SqlCredential.GetNetworkCredential().Password
  }
  
  $DbConnection = New-Object System.Data.SqlClient.SqlConnection
  $DbConnection.ConnectionString = $DbConnectionString -f $ServerInstance, $Database
  
  <#
  If ($SqlCredential) {
    $SqlCredential.Password.MakeReadOnly()
    $ConnectionCredentials = New-Object System.Data.SqlClient.SqlCredential ($SqlCredential.Username, $SqlCredential.Password)
    
    $DbConnection.Credential = $ConnectionCredentials
  }
  #>
  
  If ($Open) {
    $DbConnection.Open()
  }
  
  $MessageHandler = [System.Data.SqlClient.SqlInfoMessageEventHandler] {
    Param($Sender, $Event) 
    Write-Debug $event.Message 
  }
  $DbConnection.add_InfoMessage($MessageHandler); 
  
  
  return $DbConnection
}

Function New-SMOConnection {
<#
.SYNOPSIS
Internal function. Generates new SMO object from an existing SQL connection.
#>
  Param (
    [Alias("Server")]
    [parameter(Position = 1, Mandatory = $true, ValueFromPipeline = $true)]
      [object] $Connection
     
  )
  If ($Connection.GetType().Name -eq "SqlConnection") {
    $conn = new-object Microsoft.SqlServer.Management.Common.ServerConnection($Connection)
    #Connect to the SMO instance of SQL Server
    $srv = new-object Microsoft.SqlServer.Management.Smo.Server($conn)
  }
  ElseIf ($Connection.GetType().Name -eq "String") {
    $srv = new-object Microsoft.SqlServer.Management.Smo.Server($Connection)
  }
  return $srv
}