docker stop SQL19; docker rm SQL19;
docker stop SQL17; docker rm SQL17;
remove-item -path C:\DockerData\sql17 -recurse -force;
remove-item -path C:\DockerData\SQL19 -recurse -force;
remove-item -path c:\dockerdata\backup -Recurse -Force;

new-item -Path C:\DockerData\sql17 -ItemType Directory
new-item -Path C:\DockerData\sql19 -ItemType Directory
new-item -Path c:\dockerdata\backup -ItemType Directory

$ContainerID = docker run --name SQL19 -p 14339:1433 -e "ACCEPT_EULA=Y" -e "SA_PASSWORD=SuperStrong123" -v C:\DockerData\sql19:/var/opt/mssql/data -v c:\dockerdata\backup:/var/opt/mssql/backup -d mcr.microsoft.com/mssql/server:2019-CTP3.0-ubuntu
docker container exec $ContainerID mkdir /var/opt/mssql/backup/sql19
docker container exec $ContainerID /opt/mssql/bin/mssql-conf set filelocation.defaultbackupdir /var/opt/mssql/backup/sql19
docker restart $ContainerID;

$ContainerID = docker run --name SQL17 -p 14337:1433 -e "ACCEPT_EULA=Y" -e "SA_PASSWORD=SuperStrong123" -v C:\DockerData\sql17:/var/opt/mssql/data -v c:\dockerdata\backup:/var/opt/mssql/backup -d mcr.microsoft.com/mssql/server:2017-latest-ubuntu
docker container exec $ContainerID mkdir /var/opt/mssql/backup/sql17
docker container exec $ContainerID /opt/mssql/bin/mssql-conf set filelocation.defaultbackupdir /var/opt/mssql/backup/sql17
docker restart $ContainerID;

<#
For each of the above containers:
docker stop SQL19;docker rm SQL19
docker stop SQL17;docker rm SQL17
#>