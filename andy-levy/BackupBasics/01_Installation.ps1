Clear-Host;
<#
Installation & Maintenance

Check for an existing dbatools module installation
#>
Get-Module -ListAvailable dbatools;

<#
Update the existing module or install if it's not there
#>

if (Get-Module -ListAvailable -Name dbatools) {
    Update-Module -Name dbatools -Verbose;
}
else {
    Install-Module -Name dbatools -Scope CurrentUser -Verbose;
}
<#
Trust the PowerShell Gallery
#>
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted;