$source_instance_name = "localhost\sql2016"
$target_instance_name = "localhost\sql2017"

$sql_createDB = "
IF DB_ID('ReplayDB') IS NULL
	CREATE DATABASE ReplayDB;
"

$sql_createTable = "

IF OBJECT_ID('testNumbers') IS NOT NULL 
	DROP TABLE testNumbers

CREATE TABLE testNumbers (
	num int identity(1,1)
)

"

sqlcmd -S $source_instance_name -Q $sql_createDB -d master
sqlcmd -S $target_instance_name -Q $sql_createDB -d master

sqlcmd -S $source_instance_name -Q $sql_createTable -d ReplayDB
sqlcmd -S $target_instance_name -Q $sql_createTable -d ReplayDB

$sql_login = "

IF SUSER_ID('replayuser') IS NOT NULL 
BEGIN
	DECLARE @spid int
	DECLARE @whoToKill varchar(max)

	DECLARE killer CURSOR FAST_FORWARD 
	FOR
	SELECT session_id
	FROM sys.dm_exec_sessions
	WHERE login_name = 'replayuser'

	OPEN killer

	FETCH NEXT FROM killer INTO @spid

	WHILE @@FETCH_STATUS = 0
	BEGIN
		SET @whoToKill = 'KILL ' + CAST(@spid AS varchar(50))
		EXEC(@whoToKill)
		FETCH NEXT FROM killer INTO @spid
	END

	CLOSE killer
	DEALLOCATE killer

	DROP LOGIN replayuser;
END

CREATE LOGIN replayuser WITH PASSWORD = 'replaypassword', CHECK_POLICY = OFF;
"


$sql_user = "
IF USER_ID('replayuser') IS NOT NULL 
	DROP USER replayuser;

CREATE USER replayuser FOR LOGIN replayuser
EXEC sp_addrolemember 'db_owner', 'replayuser'
"

sqlcmd -S $source_instance_name -Q $sql_login -d master
sqlcmd -S $target_instance_name -Q $sql_login -d master

sqlcmd -S $source_instance_name -Q $sql_user -d ReplayDB
sqlcmd -S $target_instance_name -Q $sql_user -d ReplayDB

$sql_session = "
IF EXISTS (SELECT * FROM sys.dm_xe_sessions WHERE name = 'WorkloadReplay')
BEGIN
	ALTER EVENT SESSION WorkloadReplay ON SERVER STATE = STOP
END


IF EXISTS (SELECT * FROM sys.server_event_sessions WHERE NAME = 'WorkloadReplay')
BEGIN
	DROP EVENT SESSION WorkloadReplay ON SERVER
END



CREATE EVENT SESSION WorkloadReplay ON SERVER
ADD 
EVENT sqlserver.rpc_completed( 
	set collect_data_stream = 1, 
	collect_statement = 1,
	collect_output_parameters = 1
	ACTION (
		sqlserver.session_id,
		sqlserver.request_id,
		sqlserver.database_id,
		sqlserver.database_name,
		sqlserver.is_system,
		package0.event_sequence,
		sqlserver.client_app_name,
		sqlserver.server_principal_name,
		sqlserver.transaction_id,
		sqlserver.plan_handle,
		package0.collect_current_thread_id,
		sqlos.system_thread_id,
		sqlos.task_address,
		sqlos.worker_address,
		sqlos.scheduler_id,
		sqlos.cpu_id
	) 
	WHERE (
		[sqlserver].[server_principal_name] = N'replayuser'
	)
),
ADD EVENT sqlserver.sql_batch_completed ( 
	SET collect_batch_text = 1
	ACTION (
		sqlserver.session_id,
		sqlserver.request_id,
		sqlserver.database_id,
		sqlserver.database_name,
		sqlserver.is_system,
		package0.event_sequence,
		sqlserver.client_app_name,
		sqlserver.server_principal_name,
		sqlserver.transaction_id,
		sqlserver.plan_handle,
		package0.collect_current_thread_id,
		sqlos.system_thread_id,
		sqlos.task_address,
		sqlos.worker_address,
		sqlos.scheduler_id,
		sqlos.cpu_id
	) 
	WHERE (
		[sqlserver].[server_principal_name] = N'replayuser'
	)
)
WITH( 
	MAX_DISPATCH_LATENCY = 1 SECONDS, 
	MAX_MEMORY = 40960 KB,
	EVENT_RETENTION_MODE = NO_EVENT_LOSS,		
	MEMORY_PARTITION_MODE = PER_CPU,
	STARTUP_STATE = OFF
);

"

sqlcmd -S $source_instance_name -Q $sql_session -d master
sqlcmd -S $target_instance_name -Q $sql_session -d master

# Set password for scripts

$password = "replayuser" | ConvertTo-SecureString -AsPlainText -Force
[pscredential]$cred = New-Object System.Management.Automation.PSCredential -ArgumentList "replayuser",$password