$VerbosePreference = 'SilentlyContinue';
import-module dbatools -Verbose:$false;
$VerbosePreference = 'Continue';
# $PSDefaultParameterValues['*:SqlInstance'] = 'ctx1315\sql16';

$Cred = Get-Credential -UserName "sa" -Message "Container SA";
$sql17 = Connect-DbaInstance -SqlInstance "localhost,14337" -SqlCredential $Cred;
$sql19 = Connect-DbaInstance -SqlInstance "localhost,14339" -SqlCredential $Cred;

new-dbadatabase -name ToCopy -SqlInstance $sql19
backup-dbadatabase -SqlInstance $sql19 -Database ToCopy
copy-dbadatabase -Source $sql19 -Destination $sql19 -Database ToCopy -BackupRestore -SharedPath /var/opt/mssql/backup -WithReplace -NewName ToCopyClone