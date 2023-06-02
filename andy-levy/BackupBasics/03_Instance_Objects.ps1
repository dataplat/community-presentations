clear-host;
<#
# Instance-level Objects
## Keys & Certificates
### Functions Demonstrated
* `Backup-DbaServiceMasterKey`
* `Backup-DbaDbMasterKey`
* `Backup-DbaDbCertificate`

### Service Master Key
#>

$KeyBackupPassword = "MyP@$$w3rd" | ConvertTo-SecureString -AsPlainText -Force;
$KeyBackupParams = @{
    SqlInstance = "FLEXO\sql17";
    Path        = "C:\SQL\Backup";
    Password    = $KeyBackupPassword;
};
Backup-DbaServiceMasterKey @KeyBackupParams;

<#
### Database Master Key
#>

$KeyBackupParams += @{
    Database = "master";
};

Backup-DbaDbMasterKey @KeyBackupParams;

<#
### Certificates
#>
$CertBackupParams = @{
    SqlInstance        = "FLEXO\sql17";
    Path               = "C:\SQL\Backup";
    EncryptionPassword = "My0th3rP@ssw0rD" | ConvertTo-SecureString -AsPlainText -Force;
    DecryptionPassword = "bathrobe.rifleman.resent.demit" | ConvertTo-SecureString -AsPlainText -Force; # This is the password you set when creating the certificate
    Database           = "master";
    Certificate        = "TDECert_2021";
};

Backup-DbaDbCertificate @CertBackupParams;