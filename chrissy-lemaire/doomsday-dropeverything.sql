-- Dropping the snapshot articles
use [anotherdb]
exec sp_dropsubscription @publication = N'pubz', @article = N'anotherone', @subscriber = N'all', @destination_db = N'all'
GO
use [anotherdb]
exec sp_droparticle @publication = N'pubz', @article = N'anotherone', @force_invalidate_snapshot = 1
GO

-- Dropping the snapshot publication
use [anotherdb]
exec sp_droppublication @publication = N'pubz'
GO


exec sp_dropdistributor @no_checks = 1, @ignore_distributor = 1
go
USE [master]
GO


DECLARE @RoleName sysname
set @RoleName = N'whattup'

IF @RoleName <> N'public' and (select is_fixed_role from sys.server_principals where name = @RoleName) = 0
BEGIN
    DECLARE @RoleMemberName sysname
    DECLARE Member_Cursor CURSOR FOR
    select [name]
    from sys.server_principals
    where principal_id in ( 
        select member_principal_id 
        from sys.server_role_members 
        where role_principal_id in (
            select principal_id
            FROM sys.server_principals where [name] = @RoleName  AND type = 'R' ))

    OPEN Member_Cursor;

    FETCH NEXT FROM Member_Cursor
    into @RoleMemberName

    DECLARE @SQL NVARCHAR(4000)
        
    WHILE @@FETCH_STATUS = 0
    BEGIN
        
        SET @SQL = 'ALTER SERVER ROLE '+ QUOTENAME(@RoleName,'[') +' DROP MEMBER '+ QUOTENAME(@RoleMemberName,'[')
        EXEC(@SQL)
        
        FETCH NEXT FROM Member_Cursor
        into @RoleMemberName
    END;

    CLOSE Member_Cursor;
    DEALLOCATE Member_Cursor;
END
/****** Object:  ServerRole [whattup]    Script Date: 9/12/18 4:20:13 PM ******/

DROP SERVER ROLE [whattup]
GO



EXEC sp_dropmessage 50001
go
drop database anotherdb
go
drop database db1
go
drop database dbwithsprocs
go
DROP LOGIN [WORKSTATION\powershell]
GO
DROP LOGIN [login1]
GO
DROP LOGIN [login2]
GO
DROP LOGIN [login3]
GO
DROP LOGIN [login4]
GO
DROP LOGIN [login5]
GO

USE [master]
GO
/****** Object:  Credential [abc]    Script Date: 9/9/18 11:55:42 AM ******/
DROP CREDENTIAL [abc]
GO
USE [master]
GO
/****** Object:  Credential [AzureCredential]    Script Date: 9/9/18 11:55:42 AM ******/
DROP CREDENTIAL [AzureCredential]
GO
USE [master]
GO
/****** Object:  Credential [dbatools]    Script Date: 9/9/18 11:55:42 AM ******/
DROP CREDENTIAL [dbatools]
GO
USE [master]
GO
/****** Object:  Credential [https://dbatools.blob.core.windows.net/sql]    Script Date: 9/9/18 11:55:42 AM ******/
DROP CREDENTIAL [https://dbatools.blob.core.windows.net/sql]
GO
USE [master]
GO
/****** Object:  Credential [PowerShell Proxy Account]    Script Date: 9/9/18 11:55:42 AM ******/
DROP CREDENTIAL [PowerShell Proxy Account]
GO
USE [master]
GO
/****** Object:  Credential [PowerShell Service Account]    Script Date: 9/9/18 11:55:42 AM ******/
DROP CREDENTIAL [PowerShell Service Account]
GO
USE [master]
GO
/****** Object:  DdlTrigger [tr_MScdc_db_ddl_event]    Script Date: 9/9/18 11:58:18 AM ******/
DROP TRIGGER [tr_MScdc_db_ddl_event] ON ALL SERVER
GO
USE [master]
GO
/****** Object:  DdlTrigger [dbatoolsci-trigger]    Script Date: 9/9/18 4:59:30 PM ******/
DROP TRIGGER [dbatoolsci-trigger] ON ALL SERVER
GO
/****** Object:  LinkedServer [localhost]    Script Date: 9/9/18 11:58:57 AM ******/
EXEC master.dbo.sp_dropserver @server=N'localhost', @droplogins='droplogins'
GO
USE [master]
GO
/****** Object:  LinkedServer [repl_distributor]    Script Date: 9/9/18 11:58:57 AM ******/
EXEC master.dbo.sp_dropserver @server=N'repl_distributor', @droplogins='droplogins'
GO
USE [master]
GO
/****** Object:  LinkedServer [SQL2012]    Script Date: 9/9/18 11:58:57 AM ******/
EXEC master.dbo.sp_dropserver @server=N'SQL2012', @droplogins='droplogins'
GO
USE [master]
GO
/****** Object:  LinkedServer [SQL2014]    Script Date: 9/9/18 11:58:57 AM ******/
EXEC master.dbo.sp_dropserver @server=N'SQL2014', @droplogins='droplogins'
GO
USE [master]
GO
/****** Object:  LinkedServer [SQL2016]    Script Date: 9/9/18 11:58:57 AM ******/
EXEC master.dbo.sp_dropserver @server=N'SQL2016', @droplogins='droplogins'
GO
USE [master]
GO
/****** Object:  LinkedServer [SQL2016A]    Script Date: 9/9/18 11:58:57 AM ******/
EXEC master.dbo.sp_dropserver @server=N'SQL2016A', @droplogins='droplogins'
GO
USE [master]
GO
/****** Object:  BackupDevice [sup baw]    Script Date: 9/9/18 11:59:28 AM ******/
EXEC master.dbo.sp_dropdevice @logicalname = N'sup baw'
GO
EXEC msdb.dbo.sysmail_delete_profile_sp  @profile_name = 'The DBA Team'
GO
EXEC msdb.dbo.sysmail_delete_account_sp @account_name = 'The DBA Team'
GO
DROP EVENT SESSION [AlwaysOn_health] ON SERVER 
DROP EVENT SESSION [Queries and Resources] ON SERVER 
DROP EVENT SESSION [Query Timeouts] ON SERVER 
DROP EVENT SESSION [Query Wait Statistics] ON SERVER 
DROP EVENT SESSION [Query Wait Statistics Detail] ON SERVER 
DROP EVENT SESSION [Stored Procedure Parameters] ON SERVER 
DROP EVENT SESSION [system_health] ON SERVER 
DROP EVENT SESSION [telemetry_xevents] ON SERVER 
GO

/****** Object:  Job [syspolicy_purge_history]    Script Date: 9/9/18 12:08:34 PM ******/
EXEC msdb.dbo.sp_delete_job @job_id=N'e188bfc9-ccd8-4f16-8f3a-d6f42a8a58db', @delete_unused_schedule=1
GO

/****** Object:  Job [sp_purge_jobhistory]    Script Date: 9/9/18 12:08:34 PM ******/
EXEC msdb.dbo.sp_delete_job @job_id=N'3d679ab8-b5a6-4446-bfb8-4dba259f01c3', @delete_unused_schedule=1
GO

/****** Object:  Job [sp_delete_backuphistory]    Script Date: 9/9/18 12:08:34 PM ******/
EXEC msdb.dbo.sp_delete_job @job_id=N'aac2f4db-20a3-4d07-bbd5-6748f8e4c15a', @delete_unused_schedule=1
GO

/****** Object:  Job [Output File Cleanup]    Script Date: 9/9/18 12:08:34 PM ******/
EXEC msdb.dbo.sp_delete_job @job_id=N'f4f26f7b-336e-429a-bf4f-99e20c8203af', @delete_unused_schedule=1
GO

/****** Object:  Job [IndexOptimize - USER_DATABASES]    Script Date: 9/9/18 12:08:34 PM ******/
EXEC msdb.dbo.sp_delete_job @job_id=N'9a0c90f1-5ec3-441a-99f6-40d0cf5a7825', @delete_unused_schedule=1
GO

/****** Object:  Job [DatabaseIntegrityCheck - USER_DATABASES]    Script Date: 9/9/18 12:08:34 PM ******/
EXEC msdb.dbo.sp_delete_job @job_id=N'd9219588-4090-4aa1-9922-8e3bee93c3ec', @delete_unused_schedule=1
GO

/****** Object:  Job [DatabaseIntegrityCheck - SYSTEM_DATABASES]    Script Date: 9/9/18 12:08:34 PM ******/
EXEC msdb.dbo.sp_delete_job @job_id=N'af4676e0-19d5-4f93-bd01-1072f71a7d65', @delete_unused_schedule=1
GO

/****** Object:  Job [DatabaseBackup - USER_DATABASES - LOG]    Script Date: 9/9/18 12:08:34 PM ******/
EXEC msdb.dbo.sp_delete_job @job_id=N'41aeb80c-6278-4879-971f-4a86e46e2354', @delete_unused_schedule=1
GO

/****** Object:  Job [DatabaseBackup - USER_DATABASES - FULL]    Script Date: 9/9/18 12:08:34 PM ******/
EXEC msdb.dbo.sp_delete_job @job_id=N'029d2a61-9439-4308-ba20-86b63cfc1c39', @delete_unused_schedule=1
GO

/****** Object:  Job [DatabaseBackup - USER_DATABASES - DIFF]    Script Date: 9/9/18 12:08:34 PM ******/
EXEC msdb.dbo.sp_delete_job @job_id=N'3fd02c8b-cb2f-4c34-bfe8-106c5f21c850', @delete_unused_schedule=1
GO

/****** Object:  Job [DatabaseBackup - SYSTEM_DATABASES - FULL]    Script Date: 9/9/18 12:08:34 PM ******/
EXEC msdb.dbo.sp_delete_job @job_id=N'54a65cdf-73a0-48ad-9958-2f62ac6b732b', @delete_unused_schedule=1
GO

/****** Object:  Job [CommandLog Cleanup]    Script Date: 9/9/18 12:08:34 PM ******/
EXEC msdb.dbo.sp_delete_job @job_id=N'92530ce9-d454-4170-a0e7-037d659be2c6', @delete_unused_schedule=1
GO
USE [msdb]
GO

/****** Object:  Alert [Severity 025]    Script Date: 9/9/18 12:09:35 PM ******/
EXEC msdb.dbo.sp_delete_alert @name=N'Severity 025'
GO

/****** Object:  Alert [Severity 024]    Script Date: 9/9/18 12:09:35 PM ******/
EXEC msdb.dbo.sp_delete_alert @name=N'Severity 024'
GO

/****** Object:  Alert [Severity 023]    Script Date: 9/9/18 12:09:35 PM ******/
EXEC msdb.dbo.sp_delete_alert @name=N'Severity 023'
GO

/****** Object:  Alert [Severity 022]    Script Date: 9/9/18 12:09:35 PM ******/
EXEC msdb.dbo.sp_delete_alert @name=N'Severity 022'
GO

/****** Object:  Alert [Severity 021]    Script Date: 9/9/18 12:09:35 PM ******/
EXEC msdb.dbo.sp_delete_alert @name=N'Severity 021'
GO

/****** Object:  Alert [Severity 020]    Script Date: 9/9/18 12:09:35 PM ******/
EXEC msdb.dbo.sp_delete_alert @name=N'Severity 020'
GO

/****** Object:  Alert [Severity 019]    Script Date: 9/9/18 12:09:35 PM ******/
EXEC msdb.dbo.sp_delete_alert @name=N'Severity 019'
GO

/****** Object:  Alert [Severity 018]    Script Date: 9/9/18 12:09:35 PM ******/
EXEC msdb.dbo.sp_delete_alert @name=N'Severity 018'
GO

/****** Object:  Alert [Severity 017]    Script Date: 9/9/18 12:09:35 PM ******/
EXEC msdb.dbo.sp_delete_alert @name=N'Severity 017'
GO

/****** Object:  Alert [Severity 016]    Script Date: 9/9/18 12:09:35 PM ******/
EXEC msdb.dbo.sp_delete_alert @name=N'Severity 016'
GO

/****** Object:  Alert [Error Number 825]    Script Date: 9/9/18 12:09:35 PM ******/
EXEC msdb.dbo.sp_delete_alert @name=N'Error Number 825'
GO

/****** Object:  Alert [Error Number 824]    Script Date: 9/9/18 12:09:35 PM ******/
EXEC msdb.dbo.sp_delete_alert @name=N'Error Number 824'
GO

/****** Object:  Alert [Error Number 823]    Script Date: 9/9/18 12:09:35 PM ******/
EXEC msdb.dbo.sp_delete_alert @name=N'Error Number 823'
GO

/****** Object:  Alert [adf]    Script Date: 9/9/18 12:09:35 PM ******/
EXEC msdb.dbo.sp_delete_alert @name=N'adf'
GO

USE [msdb]
GO

/****** Object:  Operator [The DBA Team]    Script Date: 9/9/18 12:09:53 PM ******/
EXEC msdb.dbo.sp_delete_operator @name=N'The DBA Team'
GO

/****** Object:  Operator [Teste]    Script Date: 9/9/18 12:09:53 PM ******/
EXEC msdb.dbo.sp_delete_operator @name=N'Teste'
GO

/****** Object:  Operator [poobutt]    Script Date: 9/9/18 12:09:53 PM ******/
EXEC msdb.dbo.sp_delete_operator @name=N'poobutt'
GO

/****** Object:  Operator [MSXOperator]    Script Date: 9/9/18 12:09:53 PM ******/
EXEC msdb.dbo.sp_delete_operator @name=N'MSXOperator'
GO

/*
	Created by WORKSTATION\loulou using dbatools Export-DbaScript for objects on workstation$sql2016 at 09/08/2018 22:51:29
	See https://dbatools.io/Export-DbaScript for more information
*/
ALTER RESOURCE GOVERNOR WITH (CLASSIFIER_FUNCTION = NULL); ALTER RESOURCE GOVERNOR WITH (MAX_OUTSTANDING_IO_PER_VOLUME = DEFAULT); ALTER RESOURCE GOVERNOR RECONFIGURE;
GO

/*
	Created by WORKSTATION\loulou using dbatools Export-DbaScript for objects on workstation$sql2016 at 09/08/2018 22:51:29
	See https://dbatools.io/Export-DbaScript for more information
*/
DROP RESOURCE POOL [Test Pool] 
GO

USE [master]
GO

/****** Object:  Endpoint [endpoint_mirroring]    Script Date: 9/9/18 12:38:55 PM ******/
DROP ENDPOINT [endpoint_mirroring]
GO

USE [master]
GO
ALTER SERVER AUDIT SPECIFICATION [ServerAuditSpecification-20160502-100608]
WITH (STATE = OFF)
GO
USE [master]
GO
DROP SERVER AUDIT SPECIFICATION [ServerAuditSpecification-20160502-100608]
GO

USE [master]
GO
ALTER SERVER AUDIT [Audit-20160502-100608]
WITH (STATE = OFF)
GO
USE [master]
GO
/****** Object:  Audit [Audit-20160502-100608]    Script Date: 9/9/18 12:40:01 PM ******/
DROP SERVER AUDIT [Audit-20160502-100608]
GO
USE [master]
GO
ALTER SERVER AUDIT [Audit-20170210-150427]
WITH (STATE = OFF)
GO
USE [master]
GO
/****** Object:  Audit [Audit-20170210-150427]    Script Date: 9/9/18 12:40:01 PM ******/
DROP SERVER AUDIT [Audit-20170210-150427]
GO




EXEC msdb.dbo.sp_syspolicy_delete_policy @policy_id=65

GO

EXEC msdb.dbo.sp_syspolicy_delete_object_set @object_set_id=67

GO



EXEC msdb.dbo.sp_syspolicy_delete_condition @condition_id=18
GO



drop database distribution

go

USE [master]
GO

/****** Object:  Table [dbo].[CommandLog]    Script Date: 9/14/18 2:07:40 AM ******/
DROP TABLE [dbo].[CommandLog]
GO