EXEC [dbo].[usp_copy_remote_db]
    @SourceDatabase = 'AdventureWorksLT2012'
    @RemoteInstance = 'localhost\I2'
    @TargetDBName = 'AdventureWorksLT2012_clone_2.2'
    @DataFileDirectory = 'C:\Data'
    @LogsFileDirectory = 'C:\Logs'
    @FilePostfix = '_clone_2.2'