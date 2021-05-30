# Description

Provides a mechanism to configure and manage multiple xGroup resources with
common settings but different names

## Parameters

| Parameter | Attribute | DataType | Description | Allowed Values |
| --- | --- | --- | --- | --- |
| **DestinationPath** | Key | String | The destination SMB share path to upload the file or folder to. | |
| **SourcePath** | Key | String | The source path of the file or folder to upload. | |
| **Credential** | Required | PSCredential | Credentials to access the destination SMB share path where file or folder should be uploaded. | |
| **CertificateThumbprint** | Write | String | Thumbprint of the certificate which should be used for encryption/decryption. | |

## Examples

- [Upload file or folder to a SMB share](/source/Examples/xFileUpload/1-xFileUpload_UploadToSMBShare_Config.ps1)
