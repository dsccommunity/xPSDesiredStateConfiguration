# culture="en-US"
ConvertFrom-StringData -StringData @'
    ThrowCertificateThumbprint           = CertificateThumbprint must contain a certificate thumbprint, or "AllowUnencryptedTraffic" to opt-out from being secure.
    ThrowUseSecurityBestPractice         = Error: Cannot use best practice security settings with unencrypted traffic. Please set UseSecurityBestPractices to $false or use a certificate to encrypt pull server traffic.
    FindCertificateBySubjectMultiple     = More than one certificate found with subject containing {0} and using template "{1}".
    FindCertificateBySubjectNotFound     = Certificate not found with subject containing {0} and using template "{1}".
    IISInstallationPathNotFound          = IIS installation path not found
    IISWebAdministrationAssemblyNotFound = IIS version of Microsoft.Web.Administration.dll not found
    TemplateNameResolutionError          = Failed to resolve the template name from Active Directory certificate templates [{0}].
    TemplateNameNotFound                 = No template name found in Active Directory for [{0}].
    ActiveDirectoryTemplateSearch        = Failed to get the certificate templates from Active Directory.
'@
