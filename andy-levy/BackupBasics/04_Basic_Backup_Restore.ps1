Clear-Host;
<#
# Database Backup
## Basic Backup
### Function Demonstrated
* `Backup-DbaDatabase`
#>
$BackupPath = "C:\SQL\Backup\";
$BackupParams = @{
    SqlInstance  = "FLEXO\sql17";
    Path         = $BackupPath;
    Database     = "satellites";
    CreateFolder = $true;
}
$BackupResult = Backup-DbaDatabase @BackupParams;
# Save this for later
$SingleBackupFile = $BackupResult.BackupPath;

$BackupResult | Format-List -Property *;

<#
Let's go a bit more complex
- Copy-only
- Multiple files
- Compression
- Checksum & Verify
- Custom timestamp format
- Adjust `MaxTransferSize` and `BufferCount`

See https://sirsql.net/2012/12/13/20121212automated-backup-tuning/ for scripts to test your own backup performance
#>
$BackupParams += @{
    CopyOnly        = $true;
    Type            = "Full";
    FileCount       = 4;
    CompressBackup  = $true;
    Checksum        = $true;
    Verify          = $true;
    BufferCount     = 1000;
    MaxTransfersize = 2 * 1MB;
    TimeStampFormat = "yyyy-MMM-dd HH.mm.ss";
}
$BackupResult = Backup-DbaDatabase @BackupParams;

$BackupResult | Format-List -Property *;

<#
What are we running?

The -OutputScriptOnly switch parameter tells -Backup-DbaDatabase to not perform the backup but instead show the T-SQL to execute the backup.
#>
$BackupParams += @{
    OutputScriptOnly = $true;
}
Backup-DbaDatabase @BackupParams;

<#
## Restoring the Latest Backup
* The `-Path` parameter specifies a path to search for backups. If multiple backups are found, the most recent one will be used.
* `-Database` is the name the database will have when restored, not the original name of the database when it was backed up.

### Function Demonstrated
* `Restore-DbaDatabase`
#>
Clear-Host;
$RestoreParams = @{
    SqlInstance = "FLEXO\sql19";
    Path        = "C:\SQL\Backup\Satellites";
    Database    = "Satellites19";
}
$RestoreResult = Restore-DbaDatabase @RestoreParams;

$RestoreResult | Format-List -Property *;

<#
## Restoring a Specific Backup
If the database name we're restoring to already exists, `-WithReplace` will overwrite it. **Use with caution!**

### Function Demonstrated
* `Set-DbaDbOwner`
#>
$RestoreParams["Path"] = $SingleBackupFile;
$RestoreParams += @{
    WithReplace = $true;
}
$RestoreResult = Restore-DbaDatabase @RestoreParams;

$RestoreResult | Format-List -Property *;

Set-DbaDbOwner -SqlInstance FLEXO\sql19 -Database Satellites19 -TargetLogin sa;

<#
## Just Looking!

Maybe I'm just looking to learn how to construct a `RESTORE DATABASE` SQL statement. Other times, I just want to review the statement before it's executed.

The `-ReplaceDbNameInFile` renames the pysical files to match the database name when restored.
#>

$RestoreParams += @{
    OutputScriptOnly    = $true;
    ReplaceDbNameInFile = $true;
}
Restore-DbaDatabase @RestoreParams;

Restore-DbaDatabase @RestoreParams | Set-Clipboard;