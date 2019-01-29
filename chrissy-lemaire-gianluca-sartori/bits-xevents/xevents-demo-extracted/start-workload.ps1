$target_instance_name = "localhost\sql2017"

$sql = "
INSERT INTO ReplayDB.dbo.testNumbers OUTPUT(INSERTED.num) DEFAULT VALUES;

WAITFOR DELAY '00:00:01';
"

while($true) {
    Write-Host $sql
    sqlcmd -S $target_instance_name -Q $sql -U replayuser -P replaypassword -d ReplayDB
}