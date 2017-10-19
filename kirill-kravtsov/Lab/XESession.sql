IF EXISTS (SELECT * FROM sys.server_event_sessions WHERE name = 'TestSession')
	DROP EVENT SESSION [TestSession] ON SERVER 
GO


CREATE EVENT SESSION [TestSession] ON SERVER 
ADD EVENT sqlserver.connectivity_ring_buffer_recorded(
    ACTION(sqlserver.client_app_name,sqlserver.client_connection_id,sqlserver.client_hostname,sqlserver.context_info,sqlserver.server_principal_name,sqlserver.session_id)),
ADD EVENT sqlserver.login(SET collect_options_text=(1)
    ACTION(sqlserver.client_app_name,sqlserver.client_connection_id,sqlserver.client_hostname,sqlserver.context_info,sqlserver.server_instance_name,sqlserver.server_principal_name)),
ADD EVENT sqlserver.logout(
    ACTION(sqlserver.client_app_name,sqlserver.client_connection_id,sqlserver.client_hostname,sqlserver.context_info,sqlserver.server_instance_name,sqlserver.server_principal_name,sqlserver.session_id))
ADD TARGET package0.ring_buffer
WITH (MAX_MEMORY=4096 KB,EVENT_RETENTION_MODE=ALLOW_SINGLE_EVENT_LOSS,MAX_DISPATCH_LATENCY=30 SECONDS,MAX_EVENT_SIZE=0 KB,MEMORY_PARTITION_MODE=NONE,TRACK_CAUSALITY=ON,STARTUP_STATE=OFF)
GO

