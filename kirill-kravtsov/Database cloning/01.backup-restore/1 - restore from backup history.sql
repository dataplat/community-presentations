DECLARE @source_db sysname
DECLARE @dest_db sysname
DECLARE @date datetime
DECLARE @filemap nvarchar(max)
DECLARE @mirror int
DECLARE @use_copy_only int
SET @source_db = 'AdventureWorksLT2012'
SET @dest_db = 'AdventureWorks_clone'
SET @date = null
SET @filemap = '*DATA*->C:\Data\clone_*;*LOGS*->C:\Logs\clone_*'
SET @mirror = 0
SET @use_copy_only = 0

/* Get filemap string:
SELECT (
    SELECT f.name + '->' + f.physical_name + ';'
    FROM sys.database_files f
    FOR XML PATH(''), TYPE
    ).value('.','nvarchar(max)')
*/

-- begin
DECLARE @recovery_fork uniqueidentifier
IF @mirror IS NULL
	SET @mirror = 0
IF NOT EXISTS (SELECT * FROM sys.databases WHERE NAME = @source_db)
BEGIN
	RAISERROR('Database %s is not found on %s.',15,1, @source_db, @@SERVERNAME)
	RETURN
END

SELECT TOP 1 @recovery_fork = last_recovery_fork_guid
FROM msdb..backupset b
WHERE b.database_name = @source_db
AND b.is_snapshot = 0
	AND (b.backup_finish_date <= @date
		OR @date IS NULL
		)
ORDER BY b.backup_finish_date DESC

IF NOT EXISTS (SELECT * FROM msdb..backupset b
				WHERE b.database_name = @source_db
				  AND b.is_snapshot = 0
				  AND ( b.backup_finish_date <= @date
						OR @date IS NULL
					  )
			  )
BEGIN
	DECLARE @datestr varchar(30)
	SET @datestr = CONVERT(varchar(30),@date,120)
	RAISERROR('No backup entries were found on %s matching provided parameters. db: %s; date: %s.',15,1, @@SERVERNAME, @source_db, @datestr)
	RETURN
END
DECLARE @SQLString VARCHAR(MAX), @delim1 varchar(16),  @delim2 varchar(16);
DECLARE @filetable TABLE (name nvarchar(256), filename nvarchar(512), map_order int);
DECLARE @backups TABLE (
	[database_name] [nvarchar](128) NULL,
	[type] [char](1) NULL,
	[backup_start_date] [datetime] NULL,
	[backup_finish_date] [datetime] NULL,
	[position] [varchar](3) NULL,
	[first_lsn] [numeric](25, 0) NULL,
	[last_lsn] [numeric](25, 0) NULL,
	[backup_set_uuid] [uniqueidentifier] NOT NULL,
	[backup_set_id] [int] NOT NULL,
	[is_copy_only] [bit] NULL,
	[media_set_id] [int] NOT NULL
);
SET @SQLString = @filemap;
SET @delim1 = ';';
SET @delim2 = '->';
SELECT @SQLString = @SQLString + @delim1;
WITH
    L0   AS(SELECT 1 AS C UNION ALL SELECT 1 AS O), -- 2 rows
    L1   AS(SELECT 1 AS C FROM L0 AS A CROSS JOIN L0 AS B), -- 4 rows
    L2   AS(SELECT 1 AS C FROM L1 AS A CROSS JOIN L1 AS B), -- 16 rows
    L3   AS(SELECT 1 AS C FROM L2 AS A CROSS JOIN L2 AS B), -- 256 rows
    L4   AS(SELECT 1 AS C FROM L3 AS A CROSS JOIN L3 AS B), -- 65536 rows
    Nums AS(SELECT ROW_NUMBER() OVER(ORDER BY (SELECT NULL)) AS N FROM L4)
, Delim AS (
SELECT SUBSTRING(@SQLString, n+LEN(@delim1), CHARINDEX(@delim1, @SQLString, n+LEN(@delim1)) - n-LEN(@delim1)) as name
, n as r_num
FROM
(
    SELECT TOP(LEN(@SQLString)) N - LEN(@delim1) AS 'n'
    FROM Nums
) x
WHERE SUBSTRING(@SQLString, n, LEN(@delim1)) = @delim1 OR n = 1 - LEN(@delim1)
)
INSERT INTO @filetable(name,filename,map_order)
SELECT CASE WHEN CHARINDEX(@delim2,name,1) > 0
				THEN SUBSTRING(name,1,CHARINDEX(@delim2,name,1)-1)
			ELSE NULL
		END AS name
	, CASE WHEN CHARINDEX(@delim2,name,1) > 0
				THEN SUBSTRING(name,CHARINDEX(@delim2,name,1)+LEN(@delim2),LEN(name) - CHARINDEX(@delim2,name,1) - (LEN(@delim2) - 1) )
			ELSE NULL
		END as filename
	, DENSE_RANK() OVER (ORDER BY r_num)
FROM Delim;

INSERT INTO @backups
SELECT b.database_name
		, b.type
		, b.backup_start_date
		, b.backup_finish_date
		, cast(b.position as VARCHAR(3)) as position
		, b.first_lsn
		, b.last_lsn
		, b.backup_set_uuid
		, b.backup_set_id
		, b.is_copy_only
		, b.media_set_id
FROM msdb..backupset b
WHERE b.database_name = @source_db
	AND b.is_snapshot = 0
	AND (b.backup_finish_date <= @date
		OR @date IS NULL
		)
	--AND b.server_name = @@SERVERNAME
	AND last_recovery_fork_guid = @recovery_fork
UNION ALL
SELECT TOP 1 b.database_name
		, b.type
		, b.backup_start_date
		, b.backup_finish_date
		, cast(b.position as VARCHAR(3)) as position
		, b.first_lsn
		, b.last_lsn
		, b.backup_set_uuid
		, b.backup_set_id
		, b.is_copy_only
		, b.media_set_id
FROM msdb..backupset b
WHERE b.database_name = @source_db
	AND b.is_snapshot = 0
	AND b.backup_finish_date > @date
	AND @date IS NOT NULL
	--AND b.server_name = @@SERVERNAME
	AND b.type = 'L'
	AND last_recovery_fork_guid = @recovery_fork
ORDER BY b.last_lsn;


WITH DiskList(backup_set_id, script) AS (
  SELECT
    b.backup_set_id
  , STUFF((SELECT ', DISK = ''' + bmf.physical_device_name + ''''
				  FROM msdb..backupmediafamily bmf
				  WHERE b.media_set_id = bmf.media_set_id
				    AND (
				      bmf.mirror = @mirror
				      OR  (
				        NOT EXISTS (SELECT * FROM msdb..backupmediafamily bmf2 WHERE bmf.media_set_id = bmf2.media_set_id AND bmf2.mirror = @mirror)
					    AND bmf.mirror = (SELECT TOP 1 mirror FROM msdb..backupmediafamily bmf3 WHERE bmf.media_set_id = bmf3.media_set_id ORDER BY mirror DESC)
					    )
					  )
				  FOR XML PATH (''), TYPE).value ('.','nvarchar(max)')
		  , 1,1,'')
  FROM @backups b
)
, MoveList (backup_set_id, script) AS (
	--SELECT ', REPLACE', -1
  SELECT
    ob.backup_set_id
  , (
    SELECT
	    script
	  FROM (
      SELECT
		    CHAR(13) + CHAR(10) + ', MOVE ' + QUOTENAME(f.logical_name,'''') + ' TO '
			  + CASE
			      WHEN ft.name IN ('*DATA*','*LOGS*')
			        THEN QUOTENAME(COALESCE(REPLACE(ft.filename,'*',RIGHT(f.physical_name,CHARINDEX(CHAR(92),REVERSE(f.physical_name))-1)),f.physical_name),'''')
				  ELSE
				    QUOTENAME(COALESCE(ft.filename,f.physical_name),'''')
			    END AS script
		  , f.file_number
		  --, ft.map_order
      , b.backup_set_id
      , ROW_NUMBER() OVER (PARTITION BY b.backup_set_id, f.file_number ORDER BY ft.map_order) as map_order
		  FROM @backups b
		    INNER JOIN msdb.dbo.backupfile f ON f.backup_set_id = b.backup_set_id
		    LEFT OUTER JOIN @filetable ft
			  ON f.logical_name = ft.name
			  OR f.file_type = 'D' AND ft.name = '*DATA*'
			  OR f.file_type = 'L' AND ft.name = '*LOGS*'
      WHERE b.backup_set_id = ob.backup_set_id
		  ) a
    WHERE map_order = 1
    ORDER BY file_number
    FOR XML PATH (''), TYPE).value ('.','nvarchar(max)') as script
  FROM @backups ob
)
,FullBackup (script, first_lsn, last_lsn, backup_set_id) as (
	SELECT TOP 1
	   'RESTORE DATABASE ' + QUOTENAME(@dest_db) + ' FROM' +
		 + d.script +
		 ' WITH FILE = ' + position +
		 CASE WHEN b.last_lsn = (SELECT MAX(last_lsn)
									FROM @backups
									WHERE type IN ('D','I','L')
								)
				THEN ', RECOVERY'
			  ELSE ', NORECOVERY '
		 END +
     CHAR(13) + CHAR(10) + ', REPLACE' +
     m.script
	 , b.first_lsn
	 , b.last_lsn
   , b.backup_set_id
	FROM @backups b
  INNER JOIN DiskList d on d.backup_set_id = b.backup_set_id
  INNER JOIN MoveList m on b.backup_set_id = m.backup_set_id
	WHERE b.type = 'D'
	  AND (
      b.is_copy_only = 0  OR (
        @use_copy_only = 1 AND (
          b.is_copy_only = 1
          AND b.last_lsn = (SELECT MAX(last_lsn) FROM @backups WHERE type IN ('D','I'))
        )
      )
    )
	ORDER BY b.last_lsn DESC
)
, DiffBackup (script, first_lsn, last_lsn) as (
	SELECT TOP 1
	   'RESTORE DATABASE ' + QUOTENAME(@dest_db) + ' FROM' +
		 d.script +
		 ' WITH FILE = ' + position +
		 CASE WHEN b.last_lsn = (SELECT MAX(last_lsn)
									FROM @backups
									WHERE type IN ('D','I','L')
								)
				THEN ', RECOVERY'
			  ELSE ', NORECOVERY '
		 END +
     ISNULL(m.script,'')
	 , first_lsn
	 , last_lsn
	FROM @backups b
  INNER JOIN DiskList d on d.backup_set_id = b.backup_set_id
  INNER JOIN MoveList m on b.backup_set_id = m.backup_set_id
	WHERE b.type = 'I'
	  AND last_lsn > (SELECT MAX(last_lsn) FROM FullBackup)
	ORDER BY b.last_lsn DESC
)
, LogBackups (script, first_lsn, last_lsn) as (
	SELECT TOP 1 WITH TIES
	   'RESTORE LOG ' + QUOTENAME(@dest_db) + ' FROM' +
		 d.script +
		 ' WITH FILE = ' + position +
		 CASE WHEN b.last_lsn = (SELECT MAX(last_lsn) FROM @backups
								WHERE type IN ('L')
								)
			   AND b.first_lsn = (SELECT MAX(first_lsn) FROM @backups
								WHERE type IN ('L')
								)
				THEN ', RECOVERY'
			  ELSE ', NORECOVERY'
		 END +
		 CASE WHEN @date IS NOT NULL AND (@date <= b.backup_finish_date) THEN ', STOPAT = ''' + CONVERT(varchar(30),@date,120) + '''' ELSE '' END +
     ISNULL(m.script,'')
	 , first_lsn
	 , last_lsn
	FROM @backups b
  INNER JOIN DiskList d on d.backup_set_id = b.backup_set_id
  INNER JOIN MoveList m on b.backup_set_id = m.backup_set_id
	WHERE type = 'L'
	  AND b.last_lsn > (SELECT MAX(last_lsn) FROM (SELECT last_lsn FROM FullBackup UNION ALL SELECT last_lsn FROM DiffBackup) a)
	  AND (b.is_copy_only = 0 OR (b.is_copy_only = 1 AND b.last_lsn >= (SELECT MAX(last_lsn) FROM @backups WHERE type IN ('L') AND is_copy_only = 0)))
	ORDER BY ROW_NUMBER() OVER (PARTITION BY first_lsn,last_lsn ORDER BY first_lsn,last_lsn)
)
SELECT script
FROM (
	SELECT 'USE [master]' as script, 0 as first_lsn, 0 as last_lsn, 1 as RowN
	UNION ALL
	SELECT 'IF EXISTS (SELECT * FROM sys.databases WHERE name = ' + QUOTENAME(@dest_db,'''') + ' AND state_desc = ''ONLINE'') EXEC (''ALTER DATABASE ' + QUOTENAME(@dest_db) + ' SET SINGLE_USER WITH ROLLBACK IMMEDIATE'')', 0, 0, 2
	UNION ALL
	SELECT script, first_lsn, last_lsn, 3	FROM FullBackup
	UNION ALL
	SELECT script, first_lsn, last_lsn, 4 FROM DiffBackup
	UNION ALL
	SELECT script, first_lsn, last_lsn, 5 FROM LogBackups
	) a
ORDER BY RowN, first_lsn, last_lsn