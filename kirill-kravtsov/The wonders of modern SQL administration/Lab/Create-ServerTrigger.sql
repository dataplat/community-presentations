--====================================
--  Create server trigger template 
--====================================
IF EXISTS(
  SELECT *
    FROM sys.server_triggers
   WHERE name = N'MyServerTrigger'
     AND parent_class_desc = N'SERVER'
)
	DROP TRIGGER [MyServerTrigger] ON ALL SERVER
GO


CREATE TRIGGER MyServerTrigger ON ALL SERVER 
FOR DROP_DATABASE, ALTER_DATABASE
AS
IF IS_MEMBER ('db_owner') = 0
BEGIN
   PRINT 'You must ask your DBA to drop or alter databases!' 
   ROLLBACK TRANSACTION
END
GO