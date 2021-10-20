Clear-Host;
<#
# Scheduled Backups
Manual backups are one thing, but we should be scheduling our backups to run regularly.

dbatools makes it easy to install & schedule backups with [Ola Hallengren's Maintenance Solution](https://ola.hallengren.com/).

## Installation
`Install-DbaMaintenanceSolution` retrieves the latest version from Github _or_ can use a locally-stored copy.

### Function Demonstrated
* `Install-DbaMaintenanceSolution`
#>

$InstallParams = @{
    SqlInstance     = "FLEXO\sql19";
    Solution        = "All";
    Database        = "DBAThings";
    CleanupTime     = 25;
    InstallJobs     = $true;
    LogToTable      = $true;
    ReplaceExisting = $true;
    Force           = $true;
}
Install-DbaMaintenanceSolution @InstallParams;
<#
Just need to update?
#>
Update-DbaMaintenanceSolution -SqlInstance FLEXO\sql19 -Database DBAThings;

<#
## Verifying Installation
Ola's scripts get installed with a categoy of "Database Maintenance" so we can filter the list of installed jobs.
### Function Demonstrated
* `Get-DbaAgentJob`
#>

Get-DbaAgentJob -SqlInstance FLEXO\sql19 -Category "Database Maintenance" | Select-Object -Property Name;

<#
## Check job info

Do the backup jobs have schedules assigned to them?
#>

$JobInfoParams = @{
    SqlInstance = "FLEXO\sql19";
    Job         = @("DatabaseBackup - USER_DATABASES - Log", "DatabaseBackup - USER_DATABASES - Full");
}

Get-DbaAgentJob  @JobInfoParams | Select-Object Name, @{n = "ScheduleCount"; e = { $_.JobSchedules.Count } }

<#
## Scheduling

Let's assign 5-minute and 15-minute schedules to our Log and Full backup jobs, respectively.

### Functions Demonstrated
* `New-DbaAgentSchedule`
* `Set-DbaAgentJob`
* `Start-DbaAgentJob`
#>
$StandardParams = @{
    SqlInstance         = "FLEXO\sql19";
    FrequencyType       = "Daily";
    FrequencyInterval   = 1;
    FrequencySubdayType = "Minutes";
    Force               = $true;
}

$FiveMinuteParams = $StandardParams;
$FiveMinuteParams += @{
    Schedule                = "Five Minutes";
    FrequencySubdayInterval = 5;
}
$FifteenMinuteParams = $StandardParams;
$FifteenMinuteParams += @{
    Schedule                = "Fifteen Minutes";
    FrequencySubdayInterval = 15;
}

$EveryFiveMinutes = New-DbaAgentSchedule @FiveMinuteParams;
$EveryFifteenMinutes = New-DbaAgentSchedule @FifteenMinuteParams;

$LogBackupParams = @{
    SqlInstance = "FLEXO\sql19";
    Job         = "DatabaseBackup - USER_DATABASES - LOG";
    Schedule    = $EveryFiveMinutes;
};

$FullBackupParams = @{
    SqlInstance = "FLEXO\sql19";
    Job         = "DatabaseBackup - USER_DATABASES - FULL";
    Schedule    = $EveryFifteenMinutes;
};

Set-DbaAgentJob @LogBackupParams;
Set-DbaAgentJob @FullBackupParams;

<#
Start the full backup job
#>
Start-DbaAgentJob -SqlInstance FLEXO\sql19 -Job "DatabaseBackup - USER_DATABASES - FULL";