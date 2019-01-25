function Copy-SQLDBProperties {
<# 
.SYNOPSIS 
Copies DB properties such as TRUSTWORTHY, READ_ONLY and DB chaining

.DESCRIPTION 
This procedure will create a blank database on the destination server and copy
a source database to this blank database by replacing underlying files while
databases are in the OFFLINE mode.
In case of failure, the source database will be reverted to its original
ONLINE state, while the destination database will be removed.

.PARAMETER SourceServer
A connection string to the source SQL Server; use the following format:
SERVERNAME[\INSTANCE][,PORT]

.PARAMETER SourceDatabase
A name of the source database on the source server that will be copied to
the destination.

.PARAMETER DestinationServer
A connection string to the destination SQL Server; use the following format:
SERVERNAME[\INSTANCE][,PORT]

.PARAMETER DestinationDatabase
A name of the destination database to which the source database would be copied.
#>
 [CmdletBinding()]
  Param (
    [parameter(Position = 1, Mandatory = $true)] 
      [string]$SourceServer,
    [parameter(Position = 2, Mandatory = $true)] 
      [string]$SourceDatabase,
    [parameter(Position = 3, Mandatory = $true)] 
      [string]$DestinationServer,
    [parameter(Position = 4, Mandatory = $true)] 
      [string]$DestinationDatabase
 )
 BEGIN
  {
    $ErrorActionPreference = "Stop"
    
    If ($PSBoundParameters['Verbose']) {
      $OldVerbosePreference = $VerbosePreference
      $VerbosePreference = "Continue"
    }
  
    If ($PSBoundParameters['Debug']) {
      $OldDebugPreference = $DebugPreference
      $DebugPreference = "Continue"
    }
    
    # Create SQL connections with ADO.NET
    $SourceConnection = New-DBConnection -Server $SourceServer -SqlCredential $SourceSqlCredential -Open
    $DestinationConnection = New-DBConnection -Server $DestinationServer -SqlCredential $DestinationSqlCredential -Open
    
    $SourceServerObject = New-SMOConnection $SourceConnection
    $DestinationServerObject = New-SMOConnection $DestinationConnection
    
   
  }  
  PROCESS {     
    #$SourceDBObject = $SourceServerObject.Databases[$SourceDatabase]
    #$DestinationDBObject = $SourceServerObject.Databases[$SourceDatabase]
    
    If ($SourceServerObject.Databases[$SourceDatabase].DatabaseOwnershipChaining -ne $DestinationServerObject.Databases[$DestinationDatabase].DatabaseOwnershipChaining) {
			try
			{
				$DestinationServerObject.Databases[$DestinationDatabase].DatabaseOwnershipChaining = $SourceServerObject.Databases[$SourceDatabase].DatabaseOwnershipChaining
				$DestinationServerObject.Databases[$DestinationDatabase].Alter()
			}
			catch
			{
				Write-Warning "Failed to update DatabaseOwnershipChaining property of $DestinationServer on $DestinationServer"
				Write-Error $_
			}
		}
		
		If ($SourceServerObject.Databases[$SourceDatabase].Trustworthy -ne $DestinationServerObject.Databases[$DestinationDatabase].Trustworthy) {
			try
			{
				$DestinationServerObject.Databases[$DestinationDatabase].Trustworthy = $SourceServerObject.Databases[$SourceDatabase].Trustworthy
				$DestinationServerObject.Databases[$DestinationDatabase].Alter()
			}
			catch
			{
				Write-Warning "Failed to update Trustworthy property of $DestinationServer on $DestinationServer"
				Write-Error $_
			}
		}
		
	  If ($SourceServerObject.Databases[$SourceDatabase].BrokerEnabled -ne $DestinationServerObject.Databases[$DestinationDatabase].BrokerEnabled) {
			try
			{
				$DestinationServerObject.Databases[$DestinationDatabase].BrokerEnabled = $SourceServerObject.Databases[$SourceDatabase].BrokerEnabled
				$DestinationServerObject.Databases[$DestinationDatabase].Alter()
			}
			catch
			{
				Write-Warning "Failed to update BrokerEnabled property of $DestinationServer on $DestinationServer"
				Write-Error $_
			}
		}
  	
  	If ($SourceServerObject.Databases[$SourceDatabase].ReadOnly -ne $DestinationServerObject.Databases[$DestinationDatabase].ReadOnly) {
      $ReadOnlyQuery = "ALTER DATABASE [$DestinationDatabase] SET READ_ONLY WITH NO_WAIT"
      try {
        $x = ExecNonQuery $DestinationConnection $ReadOnlyQuery
      }
      catch
			{
				Write-Warning "Failed to update READ_ONLY property of $DestinationServer on $DestinationServer"
				Write-Error $_
			}
  	}
  }
  
  END
  {
    $SourceConnection.Close()
    $DestinationConnection.Close()  
    $VerbosePreference = $OldVerbosePreference
    $DebugPreference = $OldDebugPreference
  }
}

function Get-SQLDBProperties {
<# 
.SYNOPSIS 
Outputs an object that can be used in Set-SQLDBProperties. Allows you to gather DB properties before putting it offline.

.DESCRIPTION 
Gathers the following parameters:
- Database Ownership Chaining
- Trustworthy
- Broker Enabled
- Read-Only

.PARAMETER Server
A connection string to the SQL Server; use the following format:
SERVERNAME[\INSTANCE][,PORT]

.PARAMETER Database
A name (or array of names) of the database on the server. Can be pipelined.

.PARAMETER SqlCredential
PSCredential object containing login and password for logging onto the SQL server using SQL authentication.

#>
 [CmdletBinding()]
  Param (
    [parameter(Position = 1, Mandatory = $true)] 
      [string]$Server,
    [parameter(Position = 2, Mandatory = $false, ValueFromPipeline = $true)] 
      [array]$Database,
    [parameter(Position = 3)] 
      [System.Management.Automation.PSCredential]$SqlCredential
 )
 BEGIN
  {
    $ErrorActionPreference = "Stop"
    
    If ($PSBoundParameters['Verbose']) {
      $OldVerbosePreference = $VerbosePreference
      $VerbosePreference = "Continue"
    }
  
    If ($PSBoundParameters['Debug']) {
      $OldDebugPreference = $DebugPreference
      $DebugPreference = "Continue"
    }
    
    # Create SQL connections with ADO.NET
    $Connection = New-DBConnection -Server $Server -SqlCredential $SqlCredential -Open
    
    $ServerObject = New-SMOConnection $Connection
    $ServerObject.SetDefaultInitFields([Microsoft.SqlServer.Management.Smo.Database], 'BrokerEnabled', 'Name', 'Owner', 'ReadOnly', 'Status', 'Trustworthy', 'DatabaseOwnershipChaining')
  }  
  PROCESS {     
    #$SourceDBObject = $SourceServerObject.Databases[$SourceDatabase]
    #$DestinationDBObject = $SourceServerObject.Databases[$SourceDatabase]
    
    $Result = @()
    
    If (!$Database) {
      $Database = $ServerObject.Databases.Name
    }
    ForEach ($DatabaseItem in $Database) {
      $DBProperties = @{
        DatabaseName = $DatabaseItem
        DatabaseOwnershipChaining = $ServerObject.Databases[$DatabaseItem].DatabaseOwnershipChaining
        Trustworthy = $ServerObject.Databases[$DatabaseItem].Trustworthy
        BrokerEnabled = $ServerObject.Databases[$DatabaseItem].BrokerEnabled
        ReadOnly = $ServerObject.Databases[$DatabaseItem].ReadOnly
        Owner = $ServerObject.Databases[$DatabaseItem].Owner
      }
      $Result += $DBProperties
    }
    Return $Result
  }
  
  END
  {
    $Connection.Close()
    $VerbosePreference = $OldVerbosePreference
    $DebugPreference = $OldDebugPreference
  }
}

function Set-SQLDBProperties {
<# 
.SYNOPSIS 
Accepts an output of the Get-SQLDBProperties cmdlet and sets DB properties to the databases in the list.

.DESCRIPTION 
Sets the following parameters:
- Database Ownership Chaining
- Trustworthy
- Broker Enabled
- Read-Only

.PARAMETER Server
A connection string to the SQL Server; use the following format:
SERVERNAME[\INSTANCE][,PORT]

.PARAMETER Database
A name (or array of names) of the database on the server. Non-mandatory, will use database names from the ParameterSet object be default. Can be used to limit activity to certain databases.

.PARAMETER ParameterSet
A set of parameters - utput of the Get-SQLDBProperties cmdlet. Can be pipelined.

.PARAMETER SqlCredential
PSCredential object containing login and password for logging onto the SQL server using SQL authentication.

#>
 [CmdletBinding()]
  Param (
    [parameter(Position = 1, Mandatory = $true)] 
      [string]$Server,
    [parameter(Position = 2, Mandatory = $true, ValueFromPipeline = $true)] 
      [array]$ParameterSet,
    [parameter(Position = 3, Mandatory = $false)] 
      [array]$Database,
    [parameter(Position = 4)] 
      [System.Management.Automation.PSCredential]$SqlCredential
 )
 BEGIN
  {
    $ErrorActionPreference = "Stop"
    
    If ($PSBoundParameters['Verbose']) {
      $OldVerbosePreference = $VerbosePreference
      $VerbosePreference = "Continue"
    }
  
    If ($PSBoundParameters['Debug']) {
      $OldDebugPreference = $DebugPreference
      $DebugPreference = "Continue"
    }
    
    # Create SQL connections with ADO.NET
    $Connection = New-DBConnection -Server $Server -SqlCredential $SqlCredential -Open
    
    $ServerObject = New-SMOConnection $Connection
  }  
  PROCESS {     
    #$SourceDBObject = $SourceServerObject.Databases[$SourceDatabase]
    #$DestinationDBObject = $SourceServerObject.Databases[$SourceDatabase]
    
    If (!$Database) {
      $Database = $ServerObject.Databases.Name
    }
    
    ForEach ($Parameter in $ParameterSet) {
      If ($Database -contains $Parameter.DatabaseName) {
        If ($Parameter.DatabaseOwnershipChaining -ne $ServerObject.Databases[$Parameter.DatabaseName].DatabaseOwnershipChaining) {
    			try
    			{
    				$ServerObject.Databases[$Parameter.DatabaseName].DatabaseOwnershipChaining = $Parameter.DatabaseOwnershipChaining
    				$ServerObject.Databases[$Parameter.DatabaseName].Alter()
    			}
    			catch
    			{
    				Write-Warning "Failed to update DatabaseOwnershipChaining property of $($Parameter.DatabaseName) on $ServerObject"
    				Write-Error $_
    			}
    		}
    		If ($Parameter.Trustworthy -ne $ServerObject.Databases[$Parameter.DatabaseName].Trustworthy) {
    			try
    			{
    				$ServerObject.Databases[$Parameter.DatabaseName].Trustworthy = $Parameter.Trustworthy
    				$ServerObject.Databases[$Parameter.DatabaseName].Alter()
    			}
    			catch
    			{
    				Write-Warning "Failed to update Trustworthy property of $($Parameter.DatabaseName) on $ServerObject"
    				Write-Error $_
    			}
    		}
    		If ($Parameter.BrokerEnabled -ne $ServerObject.Databases[$Parameter.DatabaseName].BrokerEnabled) {
    			try
    			{
    				$ServerObject.Databases[$Parameter.DatabaseName].BrokerEnabled = $Parameter.BrokerEnabled
    				$ServerObject.Databases[$Parameter.DatabaseName].Alter()
    			}
    			catch
    			{
    				Write-Warning "Failed to update BrokerEnabled property of $($Parameter.DatabaseName) on $ServerObject"
    				Write-Error $_
    			}
    		}
      	
      	If ($Parameter.ReadOnly -ne $ServerObject.Databases[$Parameter.DatabaseName].ReadOnly) {
          $ReadOnlyQuery = "ALTER DATABASE [$($Parameter.DatabaseName)] SET READ_ONLY WITH NO_WAIT"
          try {
            $x = ExecNonQuery $Connection $ReadOnlyQuery
          }
          catch
    			{
    				Write-Warning "Failed to update READ_ONLY property of $($Parameter.DatabaseName) on $ServerObject"
    				Write-Error $_
    			}
      	}
      }
    }
  }
  
  END
  {
    $Connection.Close()
    $VerbosePreference = $OldVerbosePreference
    $DebugPreference = $OldDebugPreference
  }
}