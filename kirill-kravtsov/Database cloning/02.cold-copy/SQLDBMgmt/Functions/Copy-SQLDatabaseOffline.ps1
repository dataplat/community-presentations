function Copy-SQLDatabaseOffline {
<#
.SYNOPSIS
Copies SQL Server database from one server to another in the OFFLINE mode.

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

.PARAMETER ReuseFolderStructure
All database files will preserve their source structure and will be copiedto the same folders and with the same names. If the -Prefix parameter was specified as well, file names would be altered correspondingly.

.PARAMETER DestinationFileStructure
You can provide a custom layout for destination database files by passing a hashtable as a parameter, which would use the following format:
@{
  LogicalFileName1 = "Z:\Folder\filename.mdf";
  LogicalFileName2 = "Y:\Folder2\filename2.ndf";
  LogicalLogFileName1 = "X:\Fodler3\filename3.ldf"
}
The -Prefix parameter would NOT affect files, explicitly specified in the hashtable. If not all of the files were provided, the script will use default DATA and LOG folders from the destination files to accomodate such files.

.PARAMETER DestinationDataFolder
All data files not specified in -DestinationFileStructure will be put into this folder on the destination server.
Alias: Data

.PARAMETER DestinationLogFolder
All transaction log files not specified in -DestinationFileStructure will be put into this folder on the destination server.
Aliases: Log, Logs

.PARAMETER Prefix
All destination database files not specified in -DestinationFileStructure will obtain a filename prefix upon copy completion. If, for example, Prefix = "copied_" and source filename = "C:\DATA\Northwind.mdf", destination filename would be "C:\DATA\copied_Northwind.mdf"

.PARAMETER Replace
Will replace existing DATABASE on the destination server in case such database already exists. Will also allow you to use destination database file structure if the destination database exists and is identical to the source.
Alias: WithReplace

.PARAMETER Force
Will overwrite existing files on the disk drive in case they already exist.

.PARAMETER SourceSqlCredential
PSCredential object containing login and password for logging onto the source SQL server using SQL authentication.

.PARAMETER DestinationSqlCredential
PSCredential object containing login and password for logging onto the destination SQL server using SQL authentication.

.PARAMETER OutputDBObject
The function will return a database object of the restored destination database.

.EXAMPLE
Copy-SQLDatabaseOffline -SourceServer "LAB01\SQL2008,1431" -SourceDatabase "DBAdmin" -DestinationServer "LAB01,1430" -DestinationDatabase "DBAdmin_copied" -Prefix "copied_" -ReuseFolderStructure -DestinationLogFolder "J:\LOGS" -WithReplace -Force
will copy DBAdmin database from LAB01\SQL2008,1431 to LAB01,1430 using the follofing name: DBAdmin_copied. All data files on the destination server will be using directory structure of the source database and will have "copied_" prefix in their names. All log files fill be copied to J:\LOGS on the destination server and will have the same prefix. Existing files and databases will be overwritten.

.EXAMPLE
Copy-SQLDatabaseOffline -SourceServer "LAB01" -SourceDatabase "DBAdmin" -DestinationServer "LAB02,1430" -DestinationDatabase "DBAdmin"  -DestinationFileStructure @{DBAdmin_data1 = "I:\DATA\DBadmin.mdf"; DBAdmin_log = "J:\LOGS\DBadmin.ldf"}
will copy DBAdmin database from LAB01 to LAB02,1430 using the same name. Files DBAdmin_data1 and DBAdmin_log will be put into specified locations, while all other files (if any) will be copied to the default DATA and LOG folders of the destination server. The copy operation will be aborted if such database or such files already exist on the destination server.

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
      [string]$DestinationDatabase,
    [parameter(Position = 5, Mandatory = $false)]
      [switch]$ReuseFolderStructure,
    [parameter(Position = 5, Mandatory = $false)]
      [object]$DestinationFileStructure = @{},
    [Alias("Data","DataFolder")]
    [parameter(Position = 6, Mandatory = $false)]
      [string]$DestinationDataFolder,
    [Alias("Log","Logs","LogFolder","LogsFolder")]
    [parameter(Position = 7, Mandatory = $false)]
      [string]$DestinationLogFolder,
    [parameter(Position = 8, Mandatory = $false)]
      [string]$Prefix,
    [Alias("WithReplace")]
    [parameter(Position = 9)] [switch]$Replace,
    [parameter(Position = 10)] [switch]$Force,
    [parameter(Position = 11)] [System.Management.Automation.PSCredential]$SourceSqlCredential,
    [parameter(Position = 12)] [System.Management.Automation.PSCredential]$DestinationSqlCredential,
    [parameter(Position = 13)] [switch]$OutputDBObject,
    [parameter(Position = 14)] [string]$OutputFile
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

    $SourceServerObject.SetDefaultInitFields([Microsoft.SqlServer.Management.Smo.Database], 'ID', 'IsAccessible', 'Name', 'Owner', 'RecoveryModel', 'Status', 'Version')
    $DestinationServerObject.SetDefaultInitFields([Microsoft.SqlServer.Management.Smo.Database], 'ID', 'IsAccessible', 'Name', 'Status')

  }
  PROCESS {
    Write-Progress -Id 1 -Activity "Processing server and database parameters" -Status "Getting server and database objects"

    $SourceServerName = $SourceServerObject.NetName
    $DestinationServerName = $DestinationServerObject.NetName

    $SourceDBObject = $SourceServerObject.Databases[$SourceDatabase]
    #Add-DatabaseMasterFilesProperty $SourceDBObject
    If ($DestinationServerObject.Databases[$DestinationDatabase]) { $DestinationDBExists = $true }

    If (! $SourceDBObject) {
      Throw "Database $SourceDatabase does not exist on $SourceServer."
    }

    #Check status of the source database
    If ($SourceDBObject.Status -notmatch "Normal")
	  {
		  Throw "Database is not online. Aborting."
		  Return
	  }

	  #Check server versions
    If (($SourceServerObject.VersionMajor -gt $DestinationServerObject.VersionMajor) -or `
    ($SourceServerObject.VersionMajor -eq $DestinationServerObject.VersionMajor -and `
       $SourceServerObject.VersionMinor -gt $DestinationServerObject.VersionMinor `
    )) {
      Throw "The version of $DestinationServer is lower than $SourceServer, newer versions of SQL Server databases cannot be copied to the servers that have lower versions."
      Return
    }

    #Check permissions on the source server
    If ($SourceServerObject.ConnectionContext.FixedServerRoles -notmatch "SysAdmin")
	  {
		  Throw "Not a sysadmin on $DestinationServer. Quitting."
		  Return
	  }

	  #Check permissions on the destination server
    If ($DestinationServerObject.ConnectionContext.FixedServerRoles -notmatch "SysAdmin")
	  {
		  Throw "Not a sysadmin on $DestinationServer. Quitting."
		  Return
	  }

    # Get default directories for log and data files

    $DataPath = Get-DefaultDirectory $DestinationServerObject -Data
    $LogPath = Get-DefaultDirectory $DestinationServerObject -Log

		Write-Progress -Id 1 -Activity "Processing server and database parameters" -Status "Complete" -Completed

    # Get source DB file parameters

    Write-Progress -Id 1 -Activity "Processing database file structure" -Status "Getting file parameters"

    $FolderStructure = @{
      source = Get-DatabaseMasterFiles $SourceDBObject
      destination = @{
        FileGroups = @{}
      }
    }

    $sFolderStructure = $FolderStructure.source
    $dFolderStructure = $FolderStructure.destination

    $totalBatchSize = Get-DBFileSize $sFolderStructure

    # Construct destination DB structure


    Write-Progress -Id 1 -Activity "Processing database file structure" -Status "Generating destination file structure" -percentcomplete 50

    if ($DestinationDBExists) {
      $DestinationDBObject = $DestinationServerObject.Databases[$DestinationDatabase]
      #Add-DatabaseOfflineMasterFilesProperty $DestinationDBObject
      $DestinationMasterFiles = Get-DatabaseOfflineMasterFiles $DestinationDBObject

      #Add target database filenames to the $DestinationFileStructure if they don't exist there and target data/log folders were not specified
      ForEach ($File in $DestinationMasterFiles.values) {
        If ( ($File.Type -eq "LOG" -and !$DestinationFileStructure[$File.Name] -and !$DestinationLogFolder) `
          -or ($File.Type -eq "ROWS" -and !$DestinationFileStructure[$File.Name] -and !$DestinationDataFolder) ) {
          $DestinationFileStructure += @{ $File.Name = $File.FileName }
        }
      }
    }

    #Data files
    ForEach ($FileGroup in $sFolderStructure.FileGroups.values) {
      $DestFileTable = @{
        SourceNode = $FileGroup.Files
        DestinationFileStructure = $DestinationFileStructure
        ReuseFolderStructure = $ReuseFolderStructure
        Prefix = $Prefix
        DestinationFolder = $DestinationDataFolder
        DefaultFolder = $DataPath
        DestinationServerName = $DestinationServerName
      }
      $dFolderStructure.FileGroups[$FileGroup.Name] = @{
        Files = Get-DestinationFileTable @DestFileTable
        Name = $FileGroup.Name
      }
    }
    #Log files
    $DestFileTable = @{
      SourceNode = $sFolderStructure.LogFiles
      DestinationFileStructure = $DestinationFileStructure
      ReuseFolderStructure = $ReuseFolderStructure
      Prefix = $Prefix
      DestinationFolder = $DestinationLogFolder
      DefaultFolder = $LogPath
      DestinationServerName = $DestinationServerName
    }
    $dFolderStructure.LogFiles = Get-DestinationFileTable @DestFileTable


    Write-Progress -Id 1 -Activity "Processing database file structure" -Status "Completed" -Completed

    # Drop destination DB if exists and -Replace

    $DropDBQuery = "USE [master]
    IF EXISTS (SELECT * FROM sys.databases WHERE name = '$DestinationDatabase')
      BEGIN
        ALTER DATABASE [$DestinationDatabase] SET SINGLE_USER WITH ROLLBACK IMMEDIATE
        DROP DATABASE [$DestinationDatabase]
      END"

    if ($DestinationDBExists) {
      Write-Progress -Id 1 -Activity "Drop destination database" -Status "Running SQL commands"
      if (!$Replace) {
        Throw "Database $DestinationDatabase already exists on $DestinationServer, but -Replace was not specified. Aborting cloning."
      }

      $x = ExecNonQuery $DestinationConnection $DropDBQuery

      Write-Progress -Id 1 -Activity "Drop destination database" -Status "Completed" -Completed
    }

    # Check that remote files don't exist, delete if -Force

    Write-Progress -Id 1 -Activity "Checking destination files existance" -Status "Deleting files if exist"

    $DestinationFiles = Get-DBFileTable $dFolderStructure -UNC
    ForEach ($DBFile in $DestinationFiles.values) {
      If((Test-Path "filesystem::$DBFile") -and !$Force) {
        Throw "File $DBFile already exists. Use -Force switch to overwrite the file. Operation aborted."
      }
    }
    ForEach ($DBFile in $DestinationFiles.values) {
      If(Test-Path "filesystem::$DBFile") {
        Write-VerboseTimeStamp "Deleting file: $DBFile"
        Remove-Item "filesystem::$DBFile"
      }
    }

    Write-Progress -Id 1 -Activity "Checking destination files existance" -Status "Completed" -Completed

    # Create new DB with identical to source DB structure
    Write-Progress -Id 1 -Activity "Creating new database on the destination server" -Status "Running CREATE DATABASE script"

    $NewDBQuery = Get-CreateDatabaseQuery $dFolderStructure $DestinationDatabase
    $x = ExecNonQuery $DestinationConnection $NewDBQuery

    #Detach-attach the new database to fix permissions
    #$DetachQuery = Get-DetachDatabaseQuery $DestinationDatabase
    #$x = ExecNonQuery $DestinationConnection $DetachQuery

    #$AttachQuery = Get-CreateDatabaseQuery $dFolderStructure $DestinationDatabase -ForAttach
    #$x = ExecNonQuery $DestinationConnection $AttachQuery

    Write-Progress -Id 1 -Activity "Creating new database on the destination server" -Status "Completed" -Completed

    Write-Progress -Id 1 -Activity "Putting source and destination databases offline" -Status "Processing destination database"

    $SetOfflineQuery = "ALTER DATABASE [#dbname] SET OFFLINE WITH ROLLBACK IMMEDIATE"
    $x = ExecNonQuery $DestinationConnection $SetOfflineQuery.Replace("#dbname",$DestinationDatabase)
    Write-Progress -Id 1 -Activity "Putting source and destination databases offline" -Status "Processing source database" -percentcomplete 50
    $x = ExecNonQuery $SourceConnection $SetOfflineQuery.Replace("#dbname",$SourceDatabase)

    Write-Progress -Id 1 -Activity "Putting source and destination databases offline" -Status "Completed" -Completed

    # Copy over DB files
    Write-Progress -Id 1 -Activity "Copying database files" -Status "Copying files from the source server"  -percentcomplete 0

    $CopyFileList = @{}
    $SQLServerAccount = $DestinationServerObject.ServiceAccount
    $BatchSize = 0

    ForEach ($FileGroup in $sFolderStructure.FileGroups.values) {
      ForEach ($sDBF in $FileGroup.Files.values) {
        $dDBF = $dFolderStructure.FileGroups[$FileGroup.Name].Files[$sDBF.Name]
        $CopyFileList += @{$sDBF.Name = @{ Source = $sDBF.UNCFileName; Destination = $dDBF.UNCFileName; Size = $sDBF.Size } }
      }
    }
    ForEach ($sDBF in $sFolderStructure.LogFiles.values) {
      $dDBF = $dFolderStructure.LogFiles[$sDBF.Name]
      $CopyFileList += @{$sDBF.Name = @{ Source = $sDBF.UNCFileName; Destination = $dDBF.UNCFileName; Size = $sDBF.Size } }
    }

    $SetOnlineQuery = "ALTER DATABASE [#dbname] SET ONLINE"

    try {
      Push-Location $env:USERPROFILE
      ForEach ($File in $CopyFileList.GetEnumerator()) {

        $CopyParams = @{ Path = $File.Value.Source; Destination = $File.Value.Destination}
        Write-VerboseTimeStamp "Copying $($File.Name) to $($File.Value.Destination) ($($File.Value.Size/1024)MB)"
  			Copy-Item @CopyParams -Force

        #Set NTFS file permissions for newly copied files

        #Set owner
        Set-Owner -Path $File.Value.Destination

        $acl = Get-Acl -Path $File.Value.Destination
        #$acl = (Get-Item $File.Value.Destination).GetAccessControl("Access")
        $perm = $SQLServerAccount, 'FullControl', 'None', 'None', 'Allow'
        $rule = New-Object -TypeName System.Security.AccessControl.FileSystemAccessRule -ArgumentList $perm
        $acl.SetAccessRule($rule)
        $acl | Set-Acl -Path $File.Value.Destination

        $BatchSize += $File.Value.Size
        Write-Progress -Id 1 -Activity "Copying database files" -Status "$([math]::Round($BatchSize*100 / $totalBatchSize).ToString())%" -percentcomplete ($BatchSize*100 / $totalBatchSize)
      }
      Pop-Location
    }
    catch {
      Write-VerboseTimeStamp "Error found, performing cleanup"
      Write-VerboseTimeStamp "Removing target DB"
      $x = ExecNonQuery $DestinationConnection $DropDBQuery


      Write-VerboseTimeStamp "Removing target DB files that has been copied to the destination server"
      ForEach ($FileName in $DestinationFiles) {
        If(Test-Path "filesystem::$FileName") {
          Write-VerboseTimeStamp "Deleting file: $FileName"
          try {Remove-Item "filesystem::$FileName"}
          catch {Write-VerboseTimeStamp "Failed to delete $FileName`: $_"}
        }
      }
      Throw $_
    }
    finally {
      # Bring the source database back online in any case
      Write-Progress -Id 1 -Activity "Copying database files" -Status "Completed" -Completed
      Write-Progress -Id 1 -Activity "Bringing databases back online" -Status "Processing source database" -percentcomplete 0

      $x = ExecNonQuery $SourceConnection $SetOnlineQuery.Replace("#dbname",$SourceDatabase)
    }

    # Bring the target DB back ONLINE
    Write-Progress -Id 1 -Activity "Bringing databases back online" -Status "Processing destination database" -percentcomplete 50

    try {
      $x = ExecNonQuery $DestinationConnection $SetOnlineQuery.Replace("#dbname",$DestinationDatabase)
    }
    catch {
      Write-VerboseTimeStamp "Error found, performing cleanup: removing target DB"
      $x = ExecNonQuery $DestinationConnection $DropDBQuery

      Write-VerboseTimeStamp "Removing target DB files that has been copied to the destination server"
      ForEach ($FileName in $DestinationFiles) {
        If(Test-Path "filesystem::$FileName") {
          Write-VerboseTimeStamp "Deleting file: $FileName"
          try {Remove-Item "filesystem::$FileName"}
          catch {Write-VerboseTimeStamp "Failed to delete $FileName`: $_"}
        }
      }
      Throw $_
    }

    Write-Progress -Id 1 -Activity "Bringing databases back online" -Status "Completed" -Completed

    If ($OutputDBObject) {
      $OutputConnection = New-DBConnection -Server $DestinationServer -SqlCredential $DestinationSqlCredential -Open
      $OutputServerObject = New-SMOConnection $OutputConnection
      Return $OutputServerObject.Databases[$DestinationDatabase]
    }
    Else { Return }
  }

  END
  {
    $SourceConnection.Close()
    $DestinationConnection.Close()
    $VerbosePreference = $OldVerbosePreference
    $DebugPreference = $OldDebugPreference
  }

}