# Author Sander Stad: https://github.com/sanderstad

Install-Module PSDatabaseClone -Scope CurrentUser


# generating a new base image
New-PSDCImage -SourceSqlInstance localhost -DestinationSqlInstance localhost -ImageNetworkPath \\localhost\Backups -Database AdventureWorksLT2012 -CreateFullBackup -CopyOnlyBackup
Get-PSDCImage

# creating a clone now
New-PSDCClone -SqlInstance localhost -Destination c:\data -CloneName AdventureWorksLT2012_clone_3.1 -Database AdventureWorksLT2012 -LatestImage
Get-PSDCClone

# remove a clone
Get-PSDCClone | Remove-PSDCClone

# removing an image
Get-PSDCImage | Remove-PSDCImage

