<#
# Checking on Backups
## Last Backup of Each Database

`Get-DbaLastBackup` retrieves the most recent backup of each database.
### Function Demonstrated
* `Get-DbaLastBackup`
#>

Get-DbaLastBackup -SqlInstance FLEXO\sql17 | Format-Table -AutoSize;

<#
## Backup History for One Database
### Function Demonstrated
* `Get-DbaDbBackupHistory`
#>

Get-DbaDbBackupHistory -SqlInstance FLEXO\sql17 -Database stackoverflow2010 | Sort-Object -Property Start;

<#
## Recent Backups
#>

$HistoryParams = @{
    SqlInstance     = "FLEXO\sql17";
    IncludeCopyOnly = $true;
    Since           = (Get-Date).AddDays(-1);
    DeviceType      = "Disk";
}
Get-DbaDbBackupHistory @HistoryParams | Sort-Object -Property Start | Format-Table -AutoSize;

<#
### Let's send that to Excel instead
### Function Demonstrated
* `Export-Excel`
#>

$HistoryParams = @{
    SqlInstance     = "FLEXO\sql17";
    IncludeCopyOnly = $true;
    Since           = (Get-Date).AddDays(-1);
    DeviceType      = "Disk";
};

$BackupHistory = Get-DbaDbBackupHistory @HistoryParams;

$ExcelParams = @{
    Path         = "C:\users\andy\documents\BackupHistory.xlsx";
    ClearSheet   = $true;
    AutoSize     = $true;
    FreezeTopRow = $true;
    BoldTopRow   = $true;
    AutoFilter   = $true;
    Show         = $true;
}
$BackupHistory | Export-Excel @ExcelParams;

<#
## Backup Integrity
Backups don't mean much if they can't be restored, right? How can we test that we have good, usable backups of our databases?

And then, how can we prove that we're doing it?
### Function Demonstrated
* `Test-DbaLastBackup`
#>
$BackupTestParams = @{
    SqlInstance = "FLEXO\sql17";
    Destination = "FLEXO\sql19";
    Database    = @("DBAThings", "Geocaches", "Satellites");
}
$BackupTestResults = Test-DbaLastBackup @BackupTestParams;
$BackupTestResults | Format-List -Property *;

<#
## DBCC History to Table
### Functions Demonstrated
* `ConvertTo-DbaDataTable`
* `Write-DbaDataTable`
#>

$OutputParams = @{
    SqlInstance            = "FLEXO\sql19";
    Database               = "DBAThings";
    Schema                 = "dbo";
    Table                  = "BackupValidation";
    AutoCreateTable        = $true;
    UseDynamicStringLength = $true;
}
$BackupTestResults | ConvertTo-DbaDataTable | Write-DbaDataTable @OutputParams;

<#
The auditors are coming! Provide documentation!
#>
$ExcelParams = @{
    Path         = "C:\users\andy\documents\BackupVerification.xlsx";
    ClearSheet   = $true;
    AutoSize     = $true;
    FreezeTopRow = $true;
    BoldTopRow   = $true;
    AutoFilter   = $true;
    Show         = $true;
}
$QueryParams = @{
    SqlInstance = "FLEXO\sql19";
    Database    = "DBAThings";
    Query       = "select * from BackupValidation";
}
invoke-dbaquery @QueryParams | convertto-dbadatatable | Export-Excel @ExcelParams;

<#
## Backup Speed
How fast are our backups?
### Function Demonstrated
* `Measure-DbaBackupThroughput`
#>
$ThroughputParams = @{
    SqlInstance = "flexo\Sql17";
    Type        = "Full"
}
$MeasurementFields = @(
    "SqlInstance"
    , "Database"
    , "MaxBackupDate"
    , "AvgThroughput"
    , "AvgDuration"
    , "MinThroughput"
    , "MaxThroughput"
    , "BackupCount"
)
Measure-DbaBackupThroughput @ThroughputParams | Select-object -Property $MeasurementFields | Format-Table -AutoSize;