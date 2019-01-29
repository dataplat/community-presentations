USE [master]
GO

/****** Object:  LinkedServer [MYLINKEDSERVER]    Script Date: 10/11/2017 1:07:38 PM ******/
EXEC master.dbo.sp_addlinkedserver @server = N'MYLINKEDSERVER', @srvproduct=N'', @provider=N'SQLNCLI', @datasrc=N'sql1\i2', @catalog=N'master'
 /* For security reasons the linked server remote logins password is changed with ######## */
EXEC master.dbo.sp_addlinkedsrvlogin @rmtsrvname=N'MYLINKEDSERVER',@useself=N'True',@locallogin=NULL,@rmtuser=NULL,@rmtpassword=NULL
EXEC master.dbo.sp_addlinkedsrvlogin @rmtsrvname=N'MYLINKEDSERVER',@useself=N'False',@locallogin=N'Legolas',@rmtuser=N'sa',@rmtpassword='########'
GO

EXEC master.dbo.sp_serveroption @server=N'MYLINKEDSERVER', @optname=N'collation compatible', @optvalue=N'false'
GO

EXEC master.dbo.sp_serveroption @server=N'MYLINKEDSERVER', @optname=N'data access', @optvalue=N'true'
GO

EXEC master.dbo.sp_serveroption @server=N'MYLINKEDSERVER', @optname=N'dist', @optvalue=N'false'
GO

EXEC master.dbo.sp_serveroption @server=N'MYLINKEDSERVER', @optname=N'pub', @optvalue=N'false'
GO

EXEC master.dbo.sp_serveroption @server=N'MYLINKEDSERVER', @optname=N'rpc', @optvalue=N'false'
GO

EXEC master.dbo.sp_serveroption @server=N'MYLINKEDSERVER', @optname=N'rpc out', @optvalue=N'false'
GO

EXEC master.dbo.sp_serveroption @server=N'MYLINKEDSERVER', @optname=N'sub', @optvalue=N'false'
GO

EXEC master.dbo.sp_serveroption @server=N'MYLINKEDSERVER', @optname=N'connect timeout', @optvalue=N'0'
GO

EXEC master.dbo.sp_serveroption @server=N'MYLINKEDSERVER', @optname=N'collation name', @optvalue=null
GO

EXEC master.dbo.sp_serveroption @server=N'MYLINKEDSERVER', @optname=N'lazy schema validation', @optvalue=N'false'
GO

EXEC master.dbo.sp_serveroption @server=N'MYLINKEDSERVER', @optname=N'query timeout', @optvalue=N'0'
GO

EXEC master.dbo.sp_serveroption @server=N'MYLINKEDSERVER', @optname=N'use remote collation', @optvalue=N'true'
GO

EXEC master.dbo.sp_serveroption @server=N'MYLINKEDSERVER', @optname=N'remote proc transaction promotion', @optvalue=N'true'
GO


