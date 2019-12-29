param
(
    [Parameter(Mandatory = $true)]
    [System.String]
    $ConfigurationName
)

Configuration $ConfigurationName
{
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $DestinationPath,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $URI,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ChecksumType,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Checksum
    )

    Import-DscResource -ModuleName 'xPSDesiredStateConfiguration'

    node localhost {
        xRemoteFile Integration_Test {
            DestinationPath = $DestinationPath
            Uri             = $URI
            ChecksumType    = $ChecksumType
            Checksum        = $Checksum
        }
    }
}
