IF OBJECT_ID ('usp_copy_remote_db','P') IS NULL
EXEC ('CREATE PROCEDURE [usp_copy_remote_db] AS SELECT 1')
IF OBJECT_ID ('usp_remote_file_delete','P') IS NULL
EXEC ('CREATE PROCEDURE [usp_remote_file_delete] AS SELECT 1')

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Kirill Kravtsov
-- Create date: 2015-07-17
-- Description:	Delete file from a remote server, converting local file path to the UNC
-- =============================================
ALTER PROCEDURE usp_remote_file_delete
(
	@Filename nvarchar(max)
   ,@RemoteServer nvarchar(128) = @@SERVERNAME
)
AS
BEGIN
	DECLARE @SQLQuery nvarchar(max), @ExecRes int, @ErrorMessage nvarchar(max)
    SELECT @SQLQuery = 'EXEC @ExecRes = xp_cmdshell ''dir /b ' + Replace('"' + '\\' + @RemoteServer + '\' + REPLACE(@Filename,':','$') + '"','''','''''') + ''''
    EXEC sp_executesql @statement = @SQLQuery, @Params = N'@ExecRes int OUTPUT', @ExecRes = @ExecRes OUTPUT
    IF @ExecRes = 0
    BEGIN
        SELECT @SQLQuery = 'EXEC @ExecRes = xp_cmdshell ''del "' + '\\' + @RemoteServer + '\' + REPLACE(@Filename,':','$') + '"'''
        EXEC sp_executesql @statement = @SQLQuery, @Params = N'@ExecRes int OUTPUT', @ExecRes = @ExecRes OUTPUT
        IF @ExecRes <> 0
        BEGIN
            SET @ErrorMessage = 'Error during file removal: ' + @SQLQuery
            RAISERROR(@ErrorMessage,18,1) WITH NOWAIT
            RETURN 5
        END
	END
END
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Kirill Kravtsov
-- Create date: 2014-10-17
-- Description:	Copy offline database to the remote server
-- =============================================
ALTER PROCEDURE [dbo].[usp_copy_remote_db]
	  @SourceDatabase sysname
	, @RemoteInstance nvarchar(max)
	, @TargetDBName sysname
	, @DataFileDirectory nvarchar(max) = NULL
	, @LogsFileDirectory nvarchar(max) = NULL
    , @FilePostfix nvarchar(max) = '_copy'
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @SQLQuery nvarchar(max)
	DECLARE @ERMSG nvarchar(max)
    DECLARE @id int
	DECLARE @fgid int
    DECLARE @fid int
	DECLARE @LinkedServer sysname
	DECLARE @ErrorMessage nvarchar(max)
    DECLARE @ExecRes int
    DECLARE @FileExists int
    DECLARE @RemoteServer nvarchar(max)
	DECLARE @Filename nvarchar(max)

    DECLARE @FileMap TABLE (id int identity, name sysname, srcfile nvarchar(max), dstfile nvarchar(max))
    DECLARE @LocalDBParameters TABLE (FileID int, FileGroupID int, FileGroupName nvarchar(max), FileLogicalName nvarchar(max), Filename nvarchar(max))
	CREATE TABLE #DstFiles  (id int identity, name sysname, filename nvarchar(max))
	DECLARE @RemoteDBs TABLE (name sysname)

    -- Perform checks

    IF (SELECT value_in_use FROM master.sys.configurations WHERE name = 'xp_cmdshell') = 0
    BEGIN
        SET @ErrorMessage = 'xp_cmdshell server parameter should be enabled in order to use this procedure. Enable the parameter and rerun the query.'
		RAISERROR(@ErrorMessage,18,1) WITH NOWAIT
        RETURN 1
    END

	SET @RemoteServer = CASE WHEN CHARINDEX('\',@RemoteInstance) > 0 THEN SUBSTRING(@RemoteInstance,1,CHARINDEX('\',@RemoteInstance)-1)
                             ELSE @RemoteInstance
                        END


	-- Create linked server '

	SET @LinkedServer = 'REMOTE$DB$' + CHAR(65+ROUND(RAND()*25,0)) + CHAR(48+ROUND(RAND()*9,0)) + CHAR(65+ROUND(RAND()*25,0)) + CHAR(48+ROUND(RAND()*9,0)) + CHAR(65+ROUND(RAND()*25,0)) + CHAR(48+ROUND(RAND()*9,0))

	SET @SQLQuery = 'EXECUTE master.dbo.sp_addlinkedserver @server = @LinkedServer, @srvproduct=N''OLE DB'', @datasrc=@RemoteInstance, @provider=N''SQLNCLI'''
    SET @SQLQuery = @SQLQuery + CHAR(13) + CHAR(10) + 'EXECUTE master.dbo.sp_serveroption @server=@LinkedServer, @optname=N''rpc'', @optvalue=N''true'''
    SET @SQLQuery = @SQLQuery + CHAR(13) + CHAR(10) + 'EXECUTE master.dbo.sp_serveroption @server=@LinkedServer, @optname=N''rpc out'', @optvalue=N''true'''

	BEGIN TRY
		EXECUTE sp_executesql @statement = @SQLQuery, @params = N'@LinkedServer nvarchar(max), @RemoteInstance nvarchar(max)', @LinkedServer = @LinkedServer, @RemoteInstance = @RemoteInstance
	END TRY
	BEGIN CATCH
		SET @ErrorMessage = 'Failed to create a Linked Server to ' + @RemoteInstance
		RAISERROR(@ErrorMessage,18,1) WITH NOWAIT
        RETURN 2
	END CATCH

	--Get remote db list
	SET @SQLQuery = 'SELECT * FROM OPENQUERY(' + @LinkedServer + ', ''SELECT name FROM master.sys.databases'')'

	BEGIN TRY
		INSERT INTO @RemoteDBs
		EXEC (@SQLQuery)

		IF NOT EXISTS (SELECT * FROM @RemoteDBs)
		BEGIN
		  SET @ErrorMessage = 'Failed to read data from ' + @RemoteServer
		  RAISERROR(@ErrorMessage,18,1)
		END
	END TRY
	BEGIN CATCH
		SET @ErrorMessage = 'Failed to read data from ' + @RemoteServer
		RAISERROR(@ErrorMessage,18,1) WITH NOWAIT
        RETURN 3
	END CATCH

	--SELECT * FROM @RemoteDBs

	IF EXISTS (SELECT * FROM @RemoteDBs WHERE name = @TargetDBName )
	BEGIN
		--Get file information
		SET @SQLQuery = 'SELECT * FROM OPENQUERY(' + @LinkedServer + ', ''SELECT name COLLATE Latin1_General_CI_AS, filename COLLATE Latin1_General_CI_AS from master.dbo.sysaltfiles WHERE dbid = db_id(''''' + @TargetDBName + ''''')'')'

		INSERT INTO #DstFiles (name, filename)
		EXEC (@SQLQuery)

		-- Removing target database
		--SET @SQLQuery = 'EXEC @ExecRes = xp_cmdshell ''SQLCMD -b -S ' + @RemoteServer + ' -E -q "IF db_id(''''' + @TargetDBName + ''''') > 0 BEGIN ALTER DATABASE ' + QUOTENAME(@TargetDBName) + ' SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE ' + QUOTENAME(@TargetDBName) + ' END"'''
        SET @SQLQuery = 'IF db_id(''' + @TargetDBName + ''') > 0 BEGIN ALTER DATABASE ' + QUOTENAME(@TargetDBName) + ' SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE ' + QUOTENAME(@TargetDBName) + ' END'
        SET @SQLQuery = 'EXEC @ExecRes = ' + QUOTENAME(@LinkedServer) + '.master.dbo.sp_executesql @statement = N''' + Replace(@SQLQuery,'''','''''') + ''''
		EXEC sp_executesql @statement = @SQLQuery, @Params = N'@ExecRes int OUTPUT', @ExecRes = @ExecRes OUTPUT
        IF @ExecRes <> 0
        BEGIN
            SET @ErrorMessage = 'Error during remote database removal: ' + @SQLQuery
            RAISERROR(@ErrorMessage,18,1) WITH NOWAIT
            RETURN 4
        END

        -- Remove remote database files (if any)
        SET @id = 1
		WHILE EXISTS (SELECT * FROM #DstFiles WHERE id = @id)
		BEGIN
            SELECT @Filename = filename
            FROM #DstFiles
			WHERE id = @id
			EXEC usp_remote_file_delete @Filename = @Filename, @RemoteServer = @RemoteServer
			SET @id = @id + 1
		END
	END
    --SELECT * FROM #DstFiles
	SET @SQLQuery = '
	SELECT src.name
		, src.filename
		, CASE
			WHEN dst.filename IS NULL THEN
				CASE
					WHEN src.groupid > 0 THEN  replace(replace(COALESCE(@DataFileDirectory + ''\'' + reverse(left(reverse(src.filename COLLATE Latin1_General_CI_AS), charindex(''\'', reverse(src.filename COLLATE Latin1_General_CI_AS)) -1)), src.filename COLLATE Latin1_General_CI_AS),''.mdf'',''' + @FilePostfix + '.mdf''), ''.ndf'',''' + @FilePostfix + '.ndf'')
					ELSE replace(COALESCE(@LogsFileDirectory + ''\'' + reverse(left(reverse(src.filename COLLATE Latin1_General_CI_AS), charindex(''\'', reverse(src.filename COLLATE Latin1_General_CI_AS)) -1)), src.filename COLLATE Latin1_General_CI_AS),''.ldf'',''' + @FilePostfix + '.ldf'')
				END
			ELSE dst.filename
		  END
	from master.dbo.sysaltfiles src
	lEFT OUTER JOIN #DstFiles dst on src.name = dst.name
    WHERE src.dbid = DB_ID(''' + @SourceDatabase + ''')
	'
	INSERT INTO @FileMap
	EXEC sp_executesql @statement = @SQLQuery, @params = N'@DataFileDirectory nvarchar(max), @LogsFileDirectory nvarchar(max)', @DataFileDirectory = @DataFileDirectory, @LogsFileDirectory = @LogsFileDirectory

    --Get local DB information'

    SET @SQLQuery = 'SELECT sf.fileid, sf.groupid, sfg.name, sf.name, sf.filename FROM ' + QUOTENAME(@SourceDatabase) + '.dbo.sysfiles sf
                    LEFT OUTER JOIN ' + QUOTENAME(@SourceDatabase) + '.sys.filegroups sfg on (sf.groupid = sfg.data_space_id)'
    INSERT INTO @LocalDBParameters
    EXEC (@SQLQuery)

    --SELECT * FROM @LocalDBParameters
	-- Create Remote database

	SET @SQLQuery = 'CREATE DATABASE ' + QUOTENAME(@TargetDBName) + ' ON '
    SET @fgid  = 1

    WHILE EXISTS (SELECT * FROM @LocalDBParameters WHERE FileGroupID >= @fgid)
    BEGIN
        SELECT TOP 1 @SQLQuery = @SQLQuery + CASE WHEN FileGroupName = 'PRIMARY' THEN ' PRIMARY ' ELSE ' FILEGROUP ' + QUOTENAME(FileGroupName) + ' ' END
        FROM @LocalDBParameters
        WHERE FileGroupID = @fgid
        SELECT @fid = min(FileID) FROM @LocalDBParameters WHERE FileGroupID = @fgid
        WHILE EXISTS (SELECT * FROM @LocalDBParameters WHERE FileGroupID = @fgid AND FileID >= @fid)
        BEGIN
            SELECT TOP 1 @SQLQuery = @SQLQuery + '( NAME = ' + QUOTENAME(FileLogicalName,'''') + ', FILENAME = ' + QUOTENAME(fm.dstfile,'''') + ' ),'
						,@Filename = fm.dstfile
            FROM @LocalDBParameters l
            LEFT OUTER JOIN @FileMap fm ON fm.name = l.FileLogicalName
            WHERE FileGroupID = @fgid AND FileID = @fid

			--delete remote file if exists
			EXEC usp_remote_file_delete @Filename = @Filename, @RemoteServer = @RemoteServer

            SELECT @fid = min(FileID) FROM @LocalDBParameters WHERE FileGroupID = @fgid AND FileID > @fid
        END
        SELECT @fgid = min(FileGroupID) FROM @LocalDBParameters WHERE FileGroupID > @fgid
    END

    SET @SQLQuery = LEFT(@SQLQuery,LEN(@SQLQuery)-1) + ' LOG ON '


    SELECT @fid = min(FileID) FROM @LocalDBParameters WHERE FileGroupID = 0
    WHILE EXISTS (SELECT * FROM @LocalDBParameters WHERE FileGroupID = 0 AND FileID >= @fid)
    BEGIN
            SELECT TOP 1 @SQLQuery = @SQLQuery + '( NAME = ' + QUOTENAME(FileLogicalName,'''') + ', FILENAME = ' + QUOTENAME(fm.dstfile,'''') + ' ),'
						,@Filename = fm.dstfile
            FROM @LocalDBParameters l
            LEFT OUTER JOIN @FileMap fm ON fm.name = l.FileLogicalName
            WHERE FileGroupID = 0 AND FileID = @fid

			--delete remote file if exists
			EXEC usp_remote_file_delete @Filename = @Filename, @RemoteServer = @RemoteServer

            SELECT @fid = min(FileID) FROM @LocalDBParameters WHERE FileGroupID = 0 AND FileID > @fid
    END

    SET @SQLQuery = LEFT(@SQLQuery,LEN(@SQLQuery)-1)

    SET @SQLQuery = 'EXEC @ExecRes = ' + QUOTENAME(@LinkedServer) + '.master.dbo.sp_executesql @statement = N''' + Replace(@SQLQuery,'''','''''') + ''''

	EXEC sp_executesql @statement = @SQLQuery, @Params = N'@ExecRes int OUTPUT', @ExecRes = @ExecRes OUTPUT
    IF @ExecRes <> 0
    BEGIN
        SET @ErrorMessage = 'Error during remote database creation: ' + @SQLQuery
        RAISERROR(@ErrorMessage,18,1) WITH NOWAIT
        RETURN 6
    END

    -- Bring remote database offline

    SET @SQLQuery = 'ALTER DATABASE ' + Quotename(@TargetDBName) + ' SET OFFLINE WITH ROLLBACK IMMEDIATE'
    SET @SQLQuery = 'EXEC @ExecRes = ' + QUOTENAME(@LinkedServer) + '.master.dbo.sp_executesql @statement = N''' + Replace(@SQLQuery,'''','''''') + ''''
	EXEC sp_executesql @statement = @SQLQuery, @Params = N'@ExecRes int OUTPUT', @ExecRes = @ExecRes OUTPUT
    IF @ExecRes <> 0
    BEGIN
        SET @ErrorMessage = 'Error during remote database creation: ' + @SQLQuery
        RAISERROR(@ErrorMessage,18,1) WITH NOWAIT
        RETURN 7
    END


	BEGIN TRY
        -- Perform Checkpoint

        SET @SQLQuery = 'USE ' + Quotename(@SourceDatabase) + '; CHECKPOINT'
        EXEC (@SQLQuery)

        -- Bring local database offline

        IF NOT EXISTS (SELECT * FROM sys.databases WHERE name = @SourceDatabase AND state_desc = 'OFFLINE')
		BEGIN
            SET @SQLQuery = ' ALTER DATABASE ' + Quotename(@SourceDatabase) + ' SET OFFLINE WITH ROLLBACK IMMEDIATE'
            EXEC (@SQLQuery)
        END

		WAITFOR DELAY '00:00:01'

        -- Copy all files
		SET @id = 1
		WHILE EXISTS (SELECT * FROM @FileMap WHERE id = @id)
		BEGIN

			SELECT @SQLQuery = 'EXEC @ExecRes = xp_cmdshell ''copy "' + srcfile + '" "' + '\\' + @RemoteServer + '\' + REPLACE(dstfile,':','$') + '" /Y'''
			FROM @FileMap
			WHERE id = @id
			EXEC sp_executesql @statement = @SQLQuery, @Params = N'@ExecRes int OUTPUT', @ExecRes = @ExecRes OUTPUT
            IF @ExecRes <> 0
            BEGIN
                SET @ErrorMessage = 'Error during file copy: ' + @SQLQuery
                RAISERROR(@ErrorMessage,18,1) WITH NOWAIT
            END

			SET @id = @id + 1
		END


        -- Bring local database back online
		IF EXISTS (SELECT * FROM sys.databases WHERE name = @SourceDatabase AND state_desc = 'OFFLINE')
		BEGIN
			SET @SQLQuery = ' ALTER DATABASE ' + Quotename(@SourceDatabase) + ' SET ONLINE'
            EXEC (@SQLQuery)
		END

        -- Bring remote database online
        SET @SQLQuery = ' ALTER DATABASE ' + Quotename(@TargetDBName) + ' SET ONLINE'
        SET @SQLQuery = 'EXEC @ExecRes = ' + QUOTENAME(@LinkedServer) + '.master.dbo.sp_executesql @statement = N''' + Replace(@SQLQuery,'''','''''') + ''''
        EXEC sp_executesql @statement = @SQLQuery, @Params = N'@ExecRes int OUTPUT', @ExecRes = @ExecRes OUTPUT
        IF @ExecRes <> 0
        BEGIN
            SET @ErrorMessage = 'Error while bringing remote database online: ' + @SQLQuery
            RAISERROR(@ErrorMessage,18,1) WITH NOWAIT
        END

	END TRY
	BEGIN CATCH
		SET @ErrorMessage = ERROR_MESSAGE()
		IF EXISTS (SELECT * FROM sys.databases WHERE name = @SourceDatabase AND state_desc = 'OFFLINE')
		BEGIN
			SET @SQLQuery = ' ALTER DATABASE ' + Quotename(@SourceDatabase) + ' SET ONLINE'
            EXEC (@SQLQuery)
		END
		RAISERROR (@ErrorMessage,18,1)
        RETURN 8
	END CATCH

    -- Cleanup

    --Remove current linked server
    SET @SQLQuery = 'EXECUTE master.dbo.sp_dropserver @server = @LinkedServer, @droplogins = ''droplogins'''
    EXECUTE sp_executesql @statement = @SQLQuery, @params = N'@LinkedServer nvarchar(max)', @LinkedServer = @LinkedServer

    --Remove old linked servers if left from erroneous jobs
    WHILE EXISTS (SELECT * FROM sys.servers where name like 'REMOTE$DB$%' and modify_date < dateadd(d,-1, getdate()))
    BEGIN
        SELECT TOP 1 @LinkedServer = name FROM sys.servers where name like 'REMOTE$DB$%' and modify_date < dateadd(d,-1, getdate())
        SET @SQLQuery = 'EXECUTE master.dbo.sp_dropserver @server = @LinkedServer, @droplogins = ''droplogins'''
        EXECUTE sp_executesql @statement = @SQLQuery, @params = N'@LinkedServer nvarchar(max)', @LinkedServer = @LinkedServer
    END

	DROP TABLE #DstFiles
END


GO


