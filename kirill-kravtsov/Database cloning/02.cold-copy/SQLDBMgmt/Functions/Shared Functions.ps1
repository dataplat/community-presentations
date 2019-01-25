#Shared functions
Function Join-AdminUnc
{
<#
.SYNOPSIS
Internal function. Parses a path to make it an admin UNC.
#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $false)]
		#[ValidateNotNullOrEmpty()]
		[string]$servername,
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string]$filepath
		
	)
	
	if (!$filepath) { return }
	if ($filepath.StartsWith("\\")) { return $filepath }
	
	$servername = $servername.Split("\")[0]
	
	if ($filepath.length -gt 0 -and $filepath -ne [System.DbNull]::Value)
	{
		$newpath = Join-Path "\\$servername\" $filepath.replace(':', '$')
		If ($env:COMPUTERNAME -eq $servername -or (!$servername)) {
		  return $filepath
		}
		Else {
		  return $newpath
		}
	}
	else { return }
}
Function Get-RestoreStatements {
<#
.SYNOPSIS
Internal function. Generates restore T-SQL statements.
#>
  Param (
    [Microsoft.SqlServer.Management.Smo.Database] $Database,
    [string]$DestinationDatabase,
    [nullable[datetime]]$ToDate,
    [hashtable]$Files,
    [decimal]$CurrentLSN,
    #[string]$BackupFolder,
    [bool]$Replace,
    [bool]$NoDiff,
    [bool]$NoLog
  )
  
  Function Get-MoveRestoreStatments ([object]$DatabaseObject, [object]$BackupRecord) {
    $BackupFiles = $DatabaseObject.EnumBackupSetFiles($BackupRecord.ID)
    $MoveStatements = ""
    ForEach ($bf in $BackupFiles) {
      If ($Files -and $Files[$bf.LogicalName]) {
        $MoveStatements += ", MOVE '$($bf.LogicalName)' TO '$($files[$bf.LogicalName])'`r`n"
      }
    }
    Return $MoveStatements.Trim()
  }
  
  Function Get-DiskRestoreStatments ([object]$DatabaseObject, [object]$BackupRecord) {
    $MediaFiles = Get-MediaSetFiles $DatabaseObject $BackupRecord.MediaSetId | Where {$_.device_type -eq 2 -and $_.mirror -eq 0 }|Sort-Object family_sequence_number
    $DiskStatements = ""
    ForEach ($mf in $MediaFiles) {
      #If ($BackupFolder) {
      #  $BackupFile = $BackupFolder.TrimEnd('\') + '\' + (Split-Path $mf.physical_device_name -leaf)
      #}
      #Else {
      $BackupFile = Join-AdminUnc $DatabaseObject.Parent.NetName $mf.physical_device_name
      #}
      $DiskStatements += " DISK = '$BackupFile',"
    }
    $DiskStatements = $DiskStatements.TrimEnd(",")
    Return $DiskStatements
  }
  
  # Add function to Enum media sets
  Function Get-MediaSetFiles {
  #Add-Member -MemberType ScriptMethod -Name "EnumMediaSetFiles" -InputObject $db -Force -Value {
    Param ([object]$DatabaseObject,[string]$MediaSetID)
    try {
      $Res = $DatabaseObject.Parent.ConnectionContext.ExecuteWithResults("SELECT * FROM msdb.dbo.backupmediafamily WHERE media_set_id = $MediaSetID")
    }
    catch {
      Throw $_
      return
    }
    return $Res.Tables[0]
  } 
  
  #$db = $Database
  
  $ServerName = $Database.Parent.NetName
  If ($Database.Parent.InstanceName) { $ServerName += "\$($Database.Parent.InstanceName)" }
    
  $Backups = $Database.EnumBackupSets() | where { $_.IsSnapShot -eq $false  -and $_.ServerName -eq $ServerName -and $_.IsCopyOnly -eq $false }
  $BackupScript = @()
  
  If (!$CurrentLSN) {
    #Get script for the most recent full backup
    $FullBackup = $Backups | where {($_.BackupFinishDate -le $ToDate -or (!$ToDate)) -and $_.BackupSetType -eq 1 }| sort-object lastlsn -Descending | select -first 1 
    
    If (!$FullBackup) {
      If ($ToDate) { $DateError = " before $($ToDate.ToString('yyyyMMdd HH:mm:ss'))" }
      Throw "No full backups were found on $servername for database [$SourceDatabase]$DateError. Restore script cannot be generated."
      return
    }
    $FullBackupScript = "RESTORE DATABASE [$DestinationDatabase] FROM"
    $FullBackupScript += Get-DiskRestoreStatments $Database $FullBackup
    $FullBackupScript += " WITH FILE = $($FullBackup.Position)`r`n"
    If ($Replace) { $FullBackupScript += ", REPLACE" }
    $FullBackupScript += ", NORECOVERY`r`n"
    $FullBackupScript += Get-MoveRestoreStatments $Database $FullBackup
    
    $BackupScript += $FullBackupScript
    
    $CurrentLSN = $FullBackup.LastLsn
  }
  
  If (!$NoDiff) {
    #Get script for the most recent diff backup
    $DiffBackup = $Backups | where {($_.BackupFinishDate -le $ToDate -or (!$ToDate)) -and $_.BackupSetType -eq 2 -and $_.LastLsn -gt $CurrentLSN}| sort-object lastlsn -Descending | select -first 1 
    
    If ($DiffBackup) {
      $DiffBackupScript = "RESTORE DATABASE [$DestinationDatabase] FROM"
      $DiffBackupScript += Get-DiskRestoreStatments $Database $DiffBackup
      $DiffBackupScript += " WITH FILE = $($DiffBackup.Position)`r`n"
      $DiffBackupScript += ", NORECOVERY`r`n"
      $DiffBackupScript += Get-MoveRestoreStatments $Database $DiffBackup
      
      $BackupScript += $DiffBackupScript
    
      $CurrentLSN = $DiffBackup.LastLsn
    }
  }
  
  #If ($Database.RecoveryModel -ne "SIMPLE") {
  #Get script for all log backups after CurrentLSN
  If (!$NoLog) {
    #Get most recent LSN
    [decimal]$LastLSN = ($Backups | where {($_.BackupFinishDate -le $ToDate -or (!$ToDate)) -and $_.BackupSetType -eq 3 -and $_.LastLsn -gt $CurrentLSN}| sort-object lastlsn -Descending | select -first 1 ).LastLsn
    If ($ToDate) {
      #If ToDate was specified, get the next backup
      $ToDateBackup = $Backups | where {$_.BackupFinishDate -gt $ToDate -and $_.BackupSetType -eq 3}| sort-object lastlsn | select -first 1 
      $LastLSN = $ToDateBackup.LastLsn
    }
    #Get log backups for defined LSN range: between $CurrentLSN and $LastLSN
    $LogBackups = $Backups | where {$_.BackupSetType -eq 3 -and $_.LastLsn -gt $CurrentLSN -and $_.LastLsn -le $LastLSN}| sort-object FirstLsn,LastLsn
    
    
    If ($LogBackups) {
      ForEach ($LogBackup in $LogBackups) {
        #Check if log backup contains current LSN
        If ($LogBackup.FirstLsn -gt $CurrentLSN) {
          Throw "Backupset $LogBackup.ID is too recent to be applied to the backup chain after LSN $CurrentLSN. Backup chain of the database [$SourceDatabase] on $servername is broken, cannot generate restore statements."
          Return
        }
        $LogBackupScript = "RESTORE LOG [$DestinationDatabase] FROM"
        $LogBackupScript += Get-DiskRestoreStatments $Database $LogBackup
        $LogBackupScript += " WITH FILE = $($LogBackup.Position)`r`n"
        $LogBackupScript += ", NORECOVERY`r`n"
        If ($ToDate -and $LogBackup.BackupFinishDate -gt $ToDate) {
          $LogBackupScript += ", STOPAT = '$($ToDate.ToString('yyyyMMdd HH:mm:ss'))'`r`n"
        }
        $LogBackupScript += Get-MoveRestoreStatments $Database $LogBackup
        
        $BackupScript += $LogBackupScript
        $CurrentLSN = $LogBackup.LastLsn
      }
    }
  }
  
  Return $BackupScript
}

function ExecNonQuery([System.Data.SqlClient.SqlConnection]$Connection, [string]$Query) {
<#
.SYNOPSIS
Internal function. Executes T-SQL statement.
#>
  $DbCommand = New-Object System.Data.SQLClient.SQLCommand  
  $DbCommand.Connection = $Connection 
  $DbCommand.CommandText = $Query
  $DbCommand.CommandTimeout = 0

  
  try {
    Write-VerboseTimeStamp "Starting SQL statement on $($Connection.DataSource):"
    Write-Verbose $Query.Trim()
    $x = $DbCommand.ExecuteNonQuery()
    Write-VerboseTimeStamp "Command completed successfully."
    return $x
  }
  catch {
    Throw $_
    return
  }
}
    
function ExecScalar([System.Data.SqlClient.SqlConnection]$Connection, [string]$Query) {
<#
.SYNOPSIS
Internal function. Executes T-SQL statement and returns a scalar result.
#>
  $DbCommand = New-Object System.Data.SQLClient.SQLCommand  
  $DbCommand.Connection = $Connection 
  $DbCommand.CommandText = $Query 
  $DbCommand.CommandTimeout = 0
  try {
    Write-VerboseTimeStamp "Starting SQL statement on $($Connection.DataSource):"
    Write-Verbose $Query.Trim()  
    $x = $DbCommand.ExecuteScalar()
    Write-VerboseTimeStamp "Command completed successfully."
    return $x
  }
  catch {
    Throw $_
    return
  }
}
function ExecSqlQuery([System.Data.SqlClient.SqlConnection]$Connection, [string]$Query) {
<#
.SYNOPSIS
Internal function. Executes T-SQL statement and returns a table.
#>
  $DbCommand = New-Object System.Data.SQLClient.SQLCommand  
  $DataTable = New-Object System.Data.DataTable
  
  $DbCommand.Connection = $Connection 
  $DbCommand.CommandText = $Query 
  $DbCommand.CommandTimeout = 0
  try {
    Write-VerboseTimeStamp "Starting SQL statement on $($Connection.DataSource):"
    Write-Verbose $Query.Trim()
    $Reader = $DbCommand.ExecuteReader()
  }
  catch {
    Throw $_
    return
  }
  $DataTable.Load($Reader)
  $Reader.Close()
  Write-VerboseTimeStamp "Command completed successfully."
  return $DataTable
}

Function Get-DefaultDirectory {
<#
.SYNOPSIS
Get default directories for log and data files
#>
  Param (
    [parameter(Position = 1, Mandatory = $true)] 
      [object]$Server,
    [parameter(Position = 2, Mandatory = $false, ParameterSetName = "Data")] 
      [switch]$Data,
    [parameter(Position = 3, Mandatory = $false, ParameterSetName = "Log")] 
      [Switch]$Log
  )
  If ($Log) {
    # First attempt
		$Path = $Server.DefaultLog
		# Second attempt
		if ($Path.Length -eq 0) { $Path = $Server.Information.MasterDbLogPath }
		# Third attempt
		if ($Path.Length -eq 0)
		{
			$sql = "select SERVERPROPERTY('InstanceDefaultLogPath') as physical_name"
			$Path = $Server.ConnectionContext.ExecuteScalar($sql)
		}
  }
  If ($Data) {
		# First attempt
		$Path = $Server.DefaultFile
		# Second attempt
		if ($Path.Length -eq 0) { $Path = $Server.Information.MasterDbPath }
		# Third attempt
		if ($Path.Length -eq 0)
		{
			$sql = "select SERVERPROPERTY('InstanceDefaultDataPath') as physical_name"
			$Path = $Server.ConnectionContext.ExecuteScalar($sql)
		}
	}
  Return $Path
}

Function Add-DatabaseMasterFilesProperty {
<#
.SYNOPSIS
Get default directories for log and data files
#>
  Param (
    [parameter(Position = 1, Mandatory = $true)] 
      [object]$Database      
  )
  # Add custom method to the DB object
  Add-Member -MemberType ScriptProperty -Name "MasterFiles" -InputObject $Database -Force -Value {
    $that = $this
    Function Get-FilePhysicalName ($obj, $fileid) {
      try {
        $Query = "SELECT physical_name as name FROM sys.master_files WHERE database_id = {0} AND file_id = {1}"
        $x = $obj.ExecuteWithResults(($Query -f $obj.ID, $fileid))
      }
      catch {
        Throw $_
        return
      }
      Return ($x.Tables[0]|select name -first 1).name
    }
    $Structure = @{
      FileGroups = @{}
      LogFiles = @{}
    }
    ForEach ($FileGroup in $that.Filegroups) {
      $Structure.FileGroups[$FileGroup.Name] = @{ Name = $FileGroup.Name}
      ForEach ($DBFile in $FileGroup.Files) {
        $Structure.FileGroups[$FileGroup.Name].Files += @{
          $DBFile.Name = @{
            Name = $DBFile.Name
            FileName = Get-FilePhysicalName $that $DBFile.ID
            Size = $DBFile.size
          }
        }
        $Structure.FileGroups[$FileGroup.Name].Files[$DBFile.Name].UNCFileName = Join-AdminUnc $that.Parent.NetName $Structure.FileGroups[$FileGroup.Name].Files[$DBFile.Name].FileName
      }
    }
    ForEach ($LogFile in $that.LogFiles) {
      $Structure.LogFiles += @{
        $LogFile.Name = @{
          Name = $LogFile.Name
          FileName = Get-FilePhysicalName $that $LogFile.ID
          Size = $LogFile.size
        }
      }
      $Structure.LogFiles[$LogFile.Name].UNCFileName = Join-AdminUnc $that.Parent.NetName $Structure.LogFiles[$LogFile.Name].FileName
    }
    return $Structure
  } 
}

Function Get-DatabaseFilesFromBackups {
<#
.SYNOPSIS
Get database file information from system tables
#>
  Param (
    [parameter(Position = 1, Mandatory = $true)] 
      [object]$BackupSet,
    [parameter(Position = 2, Mandatory = $true)] 
      [string]$DatabaseName
  )
  
  $Structure = @{
    FileGroups = @{}
    LogFiles = @{}
  }
  
  $RelevantBackups = $BackupSet.BackupSets | Where {$_.DatabaseName -eq $DatabaseName}
  [array]$FileLogicalName = $RelevantBackups.Files.LogicalName | Sort -Unique
  
  ForEach ($File in $FileLogicalName) {
    $MostRecentBackup = $RelevantBackups | Where {$_.Files.LogicalName -eq $File}| Sort @{Expression = {[decimal]$_.LastLSN}} -desc | Select -first 1
    $ServerName = $MostRecentBackup.ServerName
    $FileData = $MostRecentBackup.Files | Where {$_.LogicalName -eq $File}
    $Node = @{
      $File = @{
        Name = $File
        FileName = $FileData.PhysicalName
        Size = $FileData.Size
        UNCFileName = Join-AdminUnc $MostRecentBackup.ServerName $FileData.PhysicalName
      }
    }
    If ($FileData.Type -eq 'D') {
      If (!($Structure.Filegroups[$FileData.FileGroupID])) {
        $Structure.Filegroups[$FileData.FileGroupID] = @{ Name = $FileData.FileGroupID; Files = @{}}
      }
      $Structure.Filegroups[$FileData.FileGroupID].Files += $Node
    }
    ElseIf ($FileData.Type -eq 'L') {
      $Structure.LogFiles += $Node
    }
  }
  return $Structure
}


Function Get-DatabaseMasterFiles {
<#
.SYNOPSIS
Get database file information from system tables
#>
  Param (
    [parameter(Position = 1, Mandatory = $true)] 
      [object]$Database,
    [parameter(Position = 2)] 
      [switch]$Offline
  )
  
  Function Get-FilePhysicalName ($obj, $fileid) {
    try {
      $Query = "SELECT physical_name as name FROM sys.master_files WHERE database_id = {0} AND file_id = {1}"
      $x = $obj.ExecuteWithResults(($Query -f $obj.ID, $fileid))
    }
    catch {
      Throw $_
      return
    }
    Return ($x.Tables[0]|select name -first 1).name
  }
  
  Function Get-DatabaseFileList($obj) {
    try {
      
      $Query = "SELECT * FROM sys.master_files WHERE database_id = {0}"
      $x = $obj.Parent.ConnectionContext.ExecuteWithResults(($Query -f $obj.ID))
    }
    catch {
      Throw $_
      return
    }
    Return $x.Tables[0]
  }
  
  $Structure = @{
    FileGroups = @{}
    LogFiles = @{}
  }
  If ($Offline) {
    ForEach ($DBFile in Get-DatabaseFileList($Database)) {
      If ($DBFile.type -eq 0) { #Rows
        If (!($Structure.Filegroups[$DBfile.data_space_id])) {
          $Structure.Filegroups[$DBFile.data_space_id] = @{ Name = $DBfile.data_space_id; Files = @{}}
        }
        $Structure.FileGroups[$DBfile.data_space_id].Files += @{
          $DBFile.Name = @{
            Name = $DBFile.Name
            FileName = $DBFile.physical_name
            Size = $DBFile.size * 8 * 1024
            UNCFileName = Join-AdminUnc $Database.Parent.NetName $DBFile.physical_name
          }
        }
      }
      ElseIf ($DBFile.type -eq 1) { #Logs 
        $Structure.LogFiles += @{
          $DBFile.Name = @{
            Name = $DBFile.Name
            FileName = $DBFile.physical_name
            Size = $DBFile.size * 8 * 1024
            UNCFileName = Join-AdminUnc $Database.Parent.NetName $DBFile.physical_name
          }
        }
      }
    }
  }
  Else {
    ForEach ($FileGroup in $Database.Filegroups) {
      $Structure.FileGroups[$FileGroup.Name] = @{ Name = $FileGroup.Name}
      ForEach ($DBFile in $FileGroup.Files) {
        $Structure.FileGroups[$FileGroup.Name].Files += @{
          $DBFile.Name = @{
            Name = $DBFile.Name
            FileName = Get-FilePhysicalName $Database $DBFile.ID
            Size = $DBFile.size
          }
        }
        $Structure.FileGroups[$FileGroup.Name].Files[$DBFile.Name].UNCFileName = Join-AdminUnc $Database.Parent.NetName $Structure.FileGroups[$FileGroup.Name].Files[$DBFile.Name].FileName
      }
    }
    ForEach ($LogFile in $Database.LogFiles) {
      $Structure.LogFiles += @{
        $LogFile.Name = @{
          Name = $LogFile.Name
          FileName = Get-FilePhysicalName $Database $LogFile.ID
          Size = $LogFile.size
        }
      }
      $Structure.LogFiles[$LogFile.Name].UNCFileName = Join-AdminUnc $Database.Parent.NetName $Structure.LogFiles[$LogFile.Name].FileName
    }
  }
  return $Structure
}

Function Add-DatabaseOfflineMasterFilesProperty {
<#
.SYNOPSIS
Get file structure without accessing db-related objects
#>
  Param (
    [parameter(Position = 1, Mandatory = $true)] 
      [object]$Database      
  )
  # Add custom method to the DB object
  Add-Member -MemberType ScriptProperty -Name "OfflineMasterFiles" -InputObject $Database -Force -Value {
    $that = $this
    $Structure = @{}
    $x = $that.Parent.ConnectionContext.ExecuteWithResults("SELECT type_desc as type, physical_name as FileName, name, size*8 as size FROM master.sys.master_files WHERE database_id = $($that.ID) and state IN (0,1)").Tables[0]
    
    ForEach($Record in $x) {
      $Structure += @{ 
        $Record.name = @{
          Name = $Record.name
          FileName = $Record.FileName
          Size = $Record.size
          Type = $Record.type
          UNCFileName = Join-AdminUnc $that.Parent.NetName $Record.FileName
        }
      }
    }
    return $Structure
  } 
}

Function Get-DatabaseOfflineMasterFiles {
<#
.SYNOPSIS
Get file structure without accessing db-related objects
#>
  Param (
    [parameter(Position = 1, Mandatory = $true)] 
      [object]$Database      
  )

  $Structure = @{}
  $x = $Database.Parent.ConnectionContext.ExecuteWithResults("SELECT type_desc as type, physical_name as FileName, name, size*8 as size FROM master.sys.master_files WHERE database_id = $($Database.ID) and state IN (0,1)").Tables[0]
  
  ForEach($Record in $x) {
    $Structure += @{ 
      $Record.name = @{
        Name = $Record.name
        FileName = $Record.FileName
        Size = $Record.size
        Type = $Record.type
        UNCFileName = Join-AdminUnc $Database.Parent.NetName $Record.FileName
      }
    }
  }
  return $Structure
}

Function Get-DBFileTable {
<#
.SYNOPSIS
Returns flat file list from a full DB file structure.
#>
  Param (
    [hashtable]$Structure,
    [switch]$UNC
  )
  $DBFiles = @{}
  If ($UNC) { $Node = "UNCFileName" } 
  Else { $Node = "FileName" } 
    
  ForEach ($FileGroup in $Structure.FileGroups.values) {
    ForEach ($DBFile in $FileGroup.Files.values) {
      $DBFiles += @{ $DBFile.Name = $DBFile[$Node] }
    }
  }
  ForEach ($DBFile in $Structure.LogFiles.values) {
    $DBFiles += @{ $DBFile.Name = $DBFile[$Node] }
  }
  
  Return $DBFiles
}

Function Get-DBFileSize ($Structure) {
<#
.SYNOPSIS
Returns a total size of all DB files.
#>
  $TotalSize = 0
  ForEach ($FileGroup in $Structure.FileGroups.values) {
    ForEach ($DBFile in $FileGroup.Files.values) {
      $TotalSize += $DBFile.Size
    }
  }
  ForEach ($DBFile in $Structure.LogFiles.values) {
    $TotalSize += $DBFile.Size
  }
  
  Return $TotalSize
}

Function Get-DestinationFileTable {
<#
.SYNOPSIS
Returns a hashtable containing a modified fileset of the source filegroup.
#>  
  Param (
    [hashtable]$SourceNode,
    [hashtable]$DestinationFileStructure,
    [switch]$ReuseFolderStructure,
    [string]$Prefix,
    [string]$DestinationFolder,
    [string]$DefaultFolder,
    [string]$DestinationServerName
  )
  
  $FilesNode = @{}

  ForEach ($DBFile in $SourceNode.values) {
    If ($ReuseFolderStructure) {
      $fn = (Split-Path $DBFile.FileName) + "\$Prefix" + (Split-Path $DBFile.FileName -leaf) 
    }
    ElseIf (($DestinationFileStructure) -and ($DestinationFileStructure[$DBFile.Name] )) {
      $fn = $DestinationFileStructure[$DBFile.Name]
    }
    ElseIf($DestinationFolder) {
      $fn = $DestinationFolder.TrimEnd('\') + "\$Prefix" + (Split-Path $DBFile.FileName -leaf)
    }
    ElseIf($DefaultFolder) {
      $fn = $DefaultFolder.TrimEnd('\') + "\$Prefix" + (Split-Path $DBFile.FileName -leaf)
    }
    Else {
      $fn = (Split-Path $DBFile.FileName -parent) + "\$Prefix" + (Split-Path $DBFile.FileName -leaf)
    }

    $FilesNode += @{
      $DBFile.Name = @{
        Name = $DBFile.Name
        FileName = $fn
        UNCFileName = (Join-AdminUnc $DestinationServerName $fn)
      }
    }
  }
  
  Return $FilesNode
}

Function Get-CreateDatabaseQuery {
<#
.SYNOPSIS
Returns a CREATE DATABASE statement based on a file structure.
#>  
  Param (
    [hashtable]$Structure,
    [string]$DatabaseName,
    [switch]$ForAttach
  )
  
  $Query = "CREATE DATABASE [$DatabaseName] ON "
  $FilegroupsPart = ""
  
  ForEach ($FileGroup in $Structure.FileGroups.values) {
    $QueryPart = "`n"
    If ($FileGroup.Name -ne "PRIMARY") { $QueryPart += "FILEGROUP " }
    $QueryPart += $FileGroup.Name
    ForEach ($File in $FileGroup.Files.values) {
      $QueryPart += "`n(Name = '$($File.Name)', Filename = '$($File.FileName)'),"
    }
    
    If ($FileGroup.Name -eq "PRIMARY") { $PrimaryPart = $QueryPart }
    Else { $FilegroupsPart += $QueryPart }
  }
  $Query += $PrimaryPart + $FilegroupsPart
  $Query = $Query.TrimEnd(",")
  $Query += "`nLOG ON"
  ForEach ($File in $Structure.LogFiles.values) {
    $Query += "`n(Name = '$($File.Name)', Filename = '$($File.FileName)'),"
  }
  $Query = $Query.TrimEnd(",")
  
  If ($ForAttach) { $Query += "`nFOR ATTACH" }
  
  Return $Query
}

Function Get-DetachDatabaseQuery {
<#
.SYNOPSIS
Returns a DETACH DATABASE statement based on a file structure.
#>  
  Param (
    [string]$DatabaseName
  )
  RETURN "EXEC sp_detach_db '$DatabaseName', 'true'"
}
<#  
Function Write-HostTimeStamp ([string]$String, [string]$Format = 'yyyy-MM-dd HH:mm:ss') {
  $FormattedDateString = "[$([datetime]::Now.ToString($Format))] "
  If ($host.Name -eq "ConsoleHost") {
    Write-Host $FormattedDateString -NoNewLine -ForegroundColor Cyan
    Write-Host $String
  }
  Else {
    Write-Output ($FormattedDateString + $String)
  }
}
#>
Function Write-VerboseTimeStamp {
  [CmdletBinding()]
  Param (
  [string]$Message,
  [string]$TimeFormat = 'yyyy-MM-dd HH:mm:ss'
  )
  Write-Verbose "[$([datetime]::Now.ToString($Format))] $Message"
}

Function Get-RestoreStatementsFromBackupSet {
<#
.SYNOPSIS
Internal function. Generates restore T-SQL statements from backup files.
#>
  Param (
    [object]$BackupSet,
    [string]$SourceDatabase,
    [string]$DestinationDatabase,
    [nullable[datetime]]$ToDate,
    [hashtable]$Files,
    #[hashtable]$RuntimeProperties,
    [decimal]$CurrentLSN,
    [bool]$Replace,
    [bool]$NoDiff
  )
  
  Function Get-MoveRestoreStatments ([object]$BackupRecord) {
    $MoveStatements = ""
    ForEach ($bf in $BackupRecord.Files) {
      If ($Files -and $Files[$bf.LogicalName]) {
        $MoveStatements += ", MOVE '$($bf.LogicalName)' TO '$($files[$bf.LogicalName])'`r`n"
      }
    }
    Return $MoveStatements.Trim()
  }
  
  
  Function Get-DiskRestoreStatments ([array]$MediaFiles, [string]$MediaID) {
    $DiskStatements = ""
    ForEach ($MediaFile in ($MediaFiles | Where {$_.ID -eq $MediaID})) {
      $DiskStatements += " DISK = '$($MediaFile.FileName)',"
    }
    $DiskStatements = $DiskStatements.TrimEnd(",")
    Return $DiskStatements
  }
  
  $Backups = $BackupSet.BackupSets  | Where {$_.DatabaseName -eq $SourceDatabase}
  
  If (!$Backups) {
    Write-Error "No backups found in specified folders"
    Return
  }
  
  $BackupScript = @()
  
  If (!$CurrentLSN) {
    #Get script for the most recent full backup
    $FullBackup = $Backups | where {($_.BackupFinishDate -le $ToDate -or (!$ToDate)) -and $_.BackupSetType -eq 1}| sort-object {$_.LastLSN} -Descending | select -first 1 
    
    If (!$FullBackup) {
      If ($ToDate) { $DateError = " before $($ToDate.ToString('yyyyMMdd HH:mm:ss'))" }
      Throw "No full backups were found in specified folder(s) for database [$SourceDatabase]$DateError. Restore script cannot be generated."
      return
    }
    $FullBackupScript = "RESTORE DATABASE [$DestinationDatabase] FROM"
    $FullBackupScript += Get-DiskRestoreStatments $BackupSet.MediaSets $FullBackup.MediaSetId
    $FullBackupScript += " WITH FILE = $($FullBackup.Position)`r`n"
    If ($Replace) { $FullBackupScript += ", REPLACE" }
    $FullBackupScript += ", NORECOVERY`r`n"
    $FullBackupScript += Get-MoveRestoreStatments $FullBackup
    
    $BackupScript += $FullBackupScript
    
    $CurrentLSN = $FullBackup.LastLsn
  }
  
  If (!$NoDiff) {
    #Get script for the most recent diff backup
    $DiffBackup = $Backups | where {($_.BackupFinishDate -le $ToDate -or (!$ToDate)) -and $_.BackupSetType -eq 5 -and $_.LastLsn -gt $CurrentLSN}| sort-object {$_.LastLSN} -Descending | select -first 1 
    
    If ($DiffBackup) {
      $DiffBackupScript = "RESTORE DATABASE [$DestinationDatabase] FROM"
      $DiffBackupScript += Get-DiskRestoreStatments $BackupSet.MediaSets $DiffBackup.MediaSetId
      $DiffBackupScript += " WITH FILE = $($DiffBackup.Position)`r`n"
      $DiffBackupScript += ", NORECOVERY`r`n"
      $DiffBackupScript += Get-MoveRestoreStatments $DiffBackup
      
      $BackupScript += $DiffBackupScript
    
      $CurrentLSN = $DiffBackup.LastLsn
    }
  }
  
  #Get script for all log backups after CurrentLSN
  
  #Get most recent LSN
  If (!$NoLog) {
    [decimal]$LastLSN = ($Backups | where {($_.BackupFinishDate -le $ToDate -or (!$ToDate)) -and $_.BackupSetType -eq 2 -and $_.LastLsn -gt $CurrentLSN}| sort-object {$_.LastLSN}  -Descending | select -first 1 ).LastLsn
    If ($ToDate) {
      #If ToDate was specified, get the next backup
      $ToDateBackup = $Backups | where {$_.BackupFinishDate -gt $ToDate -and $_.BackupSetType -eq 2}| sort-object {$_.LastLSN}  | select -first 1 
      $LastLSN = $ToDateBackup.LastLsn
    }
    #Get log backups for defined LSN range: between $CurrentLSN and $LastLSN
    $LogBackups = $Backups | where {$_.BackupSetType -eq 2 -and $_.LastLsn -gt $CurrentLSN -and $_.LastLsn -le $LastLSN}| sort-object {$_.FirstLsn}, {$_.LastLsn }
    
    
    If ($LogBackups) {
      ForEach ($LogBackup in $LogBackups) {
        #Check if log backup contains current LSN
        If ($LogBackup.FirstLsn -gt $CurrentLSN) {
          Throw "Backupset $($LogBackup.ID) is too recent to be applied to the backup chain after LSN $CurrentLSN. Backup chain of the database [$SourceDatabase] on $servername is broken, cannot generate restore statements."
          Return
        }
        $LogBackupScript = "RESTORE LOG [$DestinationDatabase] FROM"
        $LogBackupScript += Get-DiskRestoreStatments $BackupSet.MediaSets $LogBackup.MediaSetId
        $LogBackupScript += " WITH FILE = $($LogBackup.Position)`r`n"
        $LogBackupScript += ", NORECOVERY`r`n"
        If ($ToDate -and $LogBackup.BackupFinishDate -gt $ToDate) {
          $LogBackupScript += ", STOPAT = '$($ToDate.ToString('yyyyMMdd HH:mm:ss'))'`r`n"
        }
        $LogBackupScript += Get-MoveRestoreStatments $LogBackup
        
        $BackupScript += $LogBackupScript
        $CurrentLSN = $LogBackup.LastLsn
      }
    }
  }
  
  Return $BackupScript
}

Function Get-BackupSetFromDisk {
<#
.SYNOPSIS
Internal function. Runs Get-BackupSet for each path in the array and merges resultant backupsets.
#>
  Param (
    [System.Data.SqlClient.SqlConnection]$Connection,
    [array]$Path
  )
  If ($Backups) {  Clear-variable -Name "Backups" }
  ForEach ($PathItem in $Path) {
    $Backups = Merge-BackupSets $Backups (Get-BackupSet $Connection $PathItem)
  }
  $BackupsObject = @{BackupSets = @(); MediaSets = @()}
  ForEach($b in $Backups.BackupSets) { $BackupsObject.Backupsets += New-Object -TypeName psobject -Property $b}
  ForEach($m in $Backups.MediaSets) { $BackupsObject.MediaSets += New-Object -TypeName psobject -Property $m}
  
  Return New-Object -TypeName psobject -Property $BackupsObject
}

Function Merge-BackupSets {
<#
.SYNOPSIS
Internal function. Merges two backupsets into one.
#>
  Param ([hashtable]$First,[hashtable]$Second)
  If (!$Second) { Return $First }
  If ($Second.BackupSets.Length -eq 0) { Return $First }
  If (!$First) { Return $Second }
  If ($First.BackupSets.Length -eq 0) { Return $Second }
  If ($First.BackupSets.Length -gt $Second.BackupSets.Length ) {
    $Result = $First
    $Source = $Second 
  }
  Else {
    $Result = $Second
    $Source = $First 
  }
  ForEach ($BackupItem in $Source.BackupSets) {
    If (!($Result.BackupSets | WHERE { $_.ID -eq $BackupItem.ID })) {
      $Result.BackupSets += $BackupItem
    }
  }
  ForEach($MediaItem in $Source.MediaSets) {
    If (!($Result.MediaSets | WHERE { $_.ID -eq $MediaItem.ID -and $_.FamilySequenceNumber -eq $MediaItem.FamilySequenceNumber})) {
      $Result.MediaSets += $MediaItem
    }
  }
  Return $Result
}

Function Get-BackupSet {
<#
.SYNOPSIS
Returns a backupset from a path by parsing all of the files in a path using a SQL Server connection by executing RESTORE HEADERONLY and RESTORE FILELISTONLY statements.
#>
  Param (
  [System.Data.SqlClient.SqlConnection]$Connection,
  [string]$Path
  )
  
  Function Get-BackupProperties {
    Param ([string]$File)
    $Result = @{
      BackupSets = @()
      MediaSets = @()
    }
    $GetHeaderQuery = "RESTORE HEADERONLY FROM DISK = '{0}'"
    $GetLabelQuery = "RESTORE LABELONLY FROM DISK = '{0}'"
    $GetFileListQuery = "RESTORE FILELISTONLY FROM DISK = '{0}' WITH FILE = {1}"
    Write-Verbose "Processing file: $File"
    Try {
      $BackupFileLabel = ExecSqlQuery $Connection ($GetLabelQuery -f $File)
    }
    Catch {
      switch ($_.Exception.InnerException.Number) {
        3241 { 
          Write-Verbose "File '$File' is not a valid SQL backup."
          break
        }
        default {
          #echo $_.Exception.InnerException.Number
          throw $_
          return
        }
      }
    }
    
    If ($BackupFileLabel) {
      $Result.MediaSets += @{
        ID = $BackupFileLabel.MediaSetId
        FamilySequenceNumber = $BackupFileLabel.FamilySequenceNumber
        FileName = $File
      }
        
      $BackupFileHeader = ExecSqlQuery $Connection ($GetHeaderQuery -f $File)
  
      ForEach($BackupSetRecord in $BackupFileHeader) {
        $CurrentBackupSet = @{
          ID = $BackupSetRecord.BackupSetGUID
          BackupFinishDate = $BackupSetRecord.BackupFinishDate
          BackupSetType = $BackupSetRecord.BackupType
          FirstLSN = $BackupSetRecord.FirstLSN
          LastLSN = $BackupSetRecord.LastLSN
          Position = $BackupSetRecord.Position
          DatabaseName = $BackupSetRecord.DatabaseName
          BackupSize = $BackupSetRecord.BackupSize
          FamilyGUID = $BackupSetRecord.FamilyGUID
          MediaSetId = $BackupFileLabel.MediaSetId
          RecoveryForkID = $BackupSetRecord.RecoveryForkID
          ServerName = $BackupSetRecord.ServerName
          Files = @()
        }
        $BackupFileList = ExecSqlQuery $Connection ($GetFileListQuery -f $File,$BackupSetRecord.Position)
        ForEach ($BackupFile in $BackupFileList) {
          $CurrentBackupSet.Files += @{
            LogicalName = $BackupFile.LogicalName
            Type = $BackupFile.Type
            FileID = $BackupFile.FileId
            DifferentialBaseGUID = $BackupFile.DifferentialBaseGUID
            DifferentialBaseLSN = $BackupFile.DifferentialBaseLSN
            FileGroupID = $BackupFile.FileGroupId
            FileGroupName = $BackupFile.FileGroupName
            PhysicalName = $BackupFile.PhysicalName
            Size = $BackupFile.Size
          }
        }
        $Result.BackupSets += $CurrentBackupSet
      }
    }
    Return $Result
  }
  
  
  $WildPath = Get-Item "filesystem::$Path"
  ForEach ($MatchedPath in $WildPath) {
    If ($MatchedPath.PSIsContainer) {
      If ($MatchedPath.EnumerateDirectories()) {
        ForEach($Dir in $MatchedPath.EnumerateDirectories().FullName) {
          $Result = Merge-BackupSets $Result (Get-BackupSet $Connection $Dir)
        }
      }
      If ($MatchedPath.EnumerateFiles()) {
        ForEach($File in $MatchedPath.EnumerateFiles().FullName) {
          $Result = Merge-BackupSets $Result (Get-BackupProperties $File)
        }
      }
    }
    Else {
      $Result = Merge-BackupSets $Result (Get-BackupProperties $MatchedPath)
    }
  }
  Return $Result
}

Function Get-LastLSN ($Connection, $Database) {
<#
.SYNOPSIS
Get latest LSN from sys.master_files
#>
  $GetLastLsnQuery = "select TOP 1 redo_start_lsn from sys.master_files 
        WHERE type = 0 
          AND data_space_id = 1
          AND database_id = db_id('$Database')
        ORDER BY redo_start_lsn" 
  $x = ExecScalar $Connection $GetLastLsnQuery
  If ($x -and $x.GetType().Name -ne 'DBNull') {
    [decimal]$LastLSN = $x
  }
  Else {
    $LastLSN = $null
  }
  Return $LastLSN
}