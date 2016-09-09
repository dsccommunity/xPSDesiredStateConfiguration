# This module file contains a utility to perform SChannel setup
# Module exports XXXXXX function to perform the SChannel setup and test
#
# Copyright (c) Microsoft Corporation, 2016
#

# ============ Up to Date Security Settings Block =========
$insecureProtocols            = @("SSL 2.0", "SSL 3.0", "TLS 1.0", "PCT 1.0", "Multi-Protocol Unified Hello")
$secureProtocols              = @("TLS 1.1", "TLS 1.2")

$insecureCiphers              = @('DES 56/56', 'NULL', 'RC2 128/128', 'RC2 40/128', 'RC2 56/128', 'RC4 128/128', 'RC4 40/128', 'RC4 56/128', 'RC4 64/128', 'RC4 128/128')
$secureCiphers                = @('AES 128/128','AES 256/256','Triple DES 168/168')

$enableHashes                 = @("SHA","SHA256","SHA384","SHA512")
$disableHashes                = @("MD5")

$enableKeyExchangeAlgorithms  = @("ECDH", "PKCS")

$cipherSuitesOrder = @(
  'TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA384_P521',
  'TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA384_P384',
  'TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA384_P256',
  'TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA_P521',
  'TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA_P384',
  'TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA_P256',
  'TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA256_P521',
  'TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA_P521',
  'TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA256_P384',
  'TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA256_P256',
  'TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA_P384',
  'TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA_P256',
  'TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384_P521',
  'TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384_P384',
  'TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256_P521',
  'TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256_P384',
  'TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256_P256',
  'TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA384_P521',
  'TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA384_P384',
  'TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA_P521',
  'TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA_P384',
  'TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA_P256',
  'TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA256_P521',
  'TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA256_P384',
  'TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA256_P256',
  'TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA_P521',
  'TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA_P384',
  'TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA_P256',
  'TLS_DHE_DSS_WITH_AES_256_CBC_SHA256',
  'TLS_DHE_DSS_WITH_AES_256_CBC_SHA',
  'TLS_DHE_DSS_WITH_AES_128_CBC_SHA256',
  'TLS_DHE_DSS_WITH_AES_128_CBC_SHA',
  'TLS_DHE_DSS_WITH_3DES_EDE_CBC_SHA',
  'TLS_RSA_WITH_AES_256_CBC_SHA256',
  'TLS_RSA_WITH_AES_256_CBC_SHA',
  'TLS_RSA_WITH_AES_128_CBC_SHA256',
  'TLS_RSA_WITH_AES_128_CBC_SHA',
  'TLS_RSA_WITH_3DES_EDE_CBC_SHA'
)
$cipherSuitesOrderString = [string]::join(',', $cipherSuitesOrder)
# ===========================================================

function Test-Protocol
{
    foreach ($protocol in $insecureProtocols)
    {
        $registryPath = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\$protocol\Server"
        if (($null -ne (Get-Item -Path $registryPath -ErrorAction SilentlyContinue)) -and ($null -ne (Get-ItemProperty -Path $registryPath)) -and ((Get-ItemProperty -Path $registryPath).Enabled -ne 0))
        {
            return $false
        }
    }
    foreach ($protocol in $secureProtocols)
    {
        $registryPath = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\$protocol\Server"
        if (($null -eq (Get-Item -Path $registryPath -ErrorAction SilentlyContinue -ErrorVariable ev)) -or ($null -eq (Get-ItemProperty -Path $registryPath)) -or ((Get-ItemProperty -Path $registryPath).Enabled -eq 0))
        {
            return $false
        }
    }
    return $true
}

function Set-Protocol
{
    foreach ($protocol in $insecureProtocols)
    {
        $registryPath = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\$protocol\Server"
        New-Item -Path $registryPath -Force | Out-Null
        New-ItemProperty -Path $registryPath -Name Enabled -Value 0 -PropertyType 'DWord' -Force | Out-Null
    }
    foreach ($protocol in $secureProtocols)
    {
        $registryPath = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\$protocol\Server"
        New-Item -Path $registryPath -Force | Out-Null
        New-ItemProperty -Path $registryPath -Name Enabled -Value '0xffffffff' -PropertyType 'DWord' -Force | Out-Null
        New-ItemProperty -Path $registryPath -Name DisabledByDefault -Value 0 -PropertyType 'DWord' -Force | Out-Null
    }
}

function Test-Cipher
{
    $registryPath = "SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Ciphers"
    $key = (Get-Item HKLM:\).OpenSubKey($registryPath, $true)
    foreach ($cipher in $insecureCiphers)
    {
        if (($null -ne $key.OpenSubKey($cipher)) -and ($null -ne (Get-ItemProperty -Path "HKLM:\$registryPath\$cipher")) -and ((Get-ItemProperty -Path "HKLM:\$registryPath\$cipher").Enabled -ne 0))
        {
            $key.Close()
            return $false
        }
    }
    foreach ($cipher in $secureCiphers)
    {
        if ($null -eq ($key.OpenSubKey($cipher)) -or ($null -eq (Get-ItemProperty -Path "HKLM:\$registryPath\$cipher")) -or ((Get-ItemProperty -Path "HKLM:\$registryPath\$cipher").Enabled -eq 0))
        {
            $key.Close()
            return $false
        }
    }
    $key.Close();
    return $true

}

function Set-Cipher
{
    $registryPath = "SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Ciphers"
    foreach ($cipher in $insecureCiphers)
    {
        $key = (Get-Item HKLM:\).OpenSubKey($registryPath, $true).CreateSubKey($cipher)
        $key.SetValue('Enabled', 0, 'DWord')
        $key.close()
    }
    foreach ($cipher in $secureCiphers)
    {
        $key = (Get-Item HKLM:\).OpenSubKey($registryPath, $true).CreateSubKey($cipher)
        New-ItemProperty -path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Ciphers\$cipher" -name 'Enabled' -value '0xffffffff' -PropertyType 'DWord' -Force | Out-Null
        $key.close()
    }
}

function Test-Hash
{
    foreach ($hash in $disableHashes)
    {
        $registryPath = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Hashes\$hash"
        if (($null -ne (Get-Item -Path $registryPath -ErrorAction SilentlyContinue)) -and ($null -ne (Get-ItemProperty -Path $registryPath)) -and ((Get-ItemProperty -Path $registryPath).Enabled -ne 0))
        {
            return $false
        }
    }
    foreach ($hash in $enableHashes)
    {
        $registryPath = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Hashes\$hash"
        if (($null -eq (Get-Item -Path $registryPath -ErrorAction SilentlyContinue)) -or ($null -eq (Get-ItemProperty -Path $registryPath)) -or ((Get-ItemProperty -Path $registryPath).Enabled -eq 0))
        {
            return $false
        }
    }
    return $true
}

function Set-Hash
{
    foreach ($hash in $disableHashes)
    {
        $registryPath = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Hashes\$hash"
        New-Item -Path $registryPath -Force | Out-Null
        New-ItemProperty -Path $registryPath -Name Enabled -Value 0 -PropertyType 'DWord' -Force | Out-Null
    }
    foreach ($hash in $enableHashes)
    {
        $registryPath = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Hashes\$hash"
        New-Item -Path $registryPath -Force | Out-Null
        New-ItemProperty -Path $registryPath -Name Enabled -Value '0xffffffff' -PropertyType 'DWord' -Force | Out-Null
    }
}

function Test-KeyExchangeAlgorithm
{
    foreach ($algorithm in $enableKeyExchangeAlgorithms)
    {
        $registryPath = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\KeyExchangeAlgorithms\$algorithm"
        if (($null -eq (Get-Item -Path $registryPath -ErrorAction SilentlyContinue)) -or ($null -eq (Get-ItemProperty -Path $registryPath)) -or ((Get-ItemProperty -Path $registryPath).Enabled -eq 0))
        {
            return $false
        }
    }
    return $true
}

function Set-KeyExchangeAlgorithm
{
    foreach ($algorithm in $enableKeyExchangeAlgorithms)
    {
        $registryPath = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\KeyExchangeAlgorithms\$algorithm"
        New-Item -Path $registryPath -Force | Out-Null
        New-ItemProperty -Path $registryPath -Name Enabled -Value '0xffffffff' -PropertyType 'DWord' -Force | Out-Null
    }
}

function Test-CipherSuiteOrder
{
    $registryPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Cryptography\Configuration\SSL\00010002'
    if (($null -eq (Get-Item -Path $registryPath -ErrorAction SilentlyContinue)) -or ($null -eq (Get-ItemProperty -Path $registryPath)) -or ((Get-ItemProperty -Path $registryPath).Functions -ne $cipherSuitesOrderString))
    {
        return $false
    }
    return $true
}

function Set-CipherSuiteOrder
{
    New-ItemProperty -path 'HKLM:\SOFTWARE\Policies\Microsoft\Cryptography\Configuration\SSL\00010002' -name 'Functions' -value $cipherSuitesOrderString -PropertyType 'String' -Force | Out-Null
}

<#
    .SYNOPSIS
        This function tests whether the node uses enhanced security settings:
        a. insecure protocols are disabled, secure protocols are enabled
        b. insecure ciphers are disabled, secure ciphers are enabled
        c. insecure hash algorithms are disabled, secure hash algorithms are enabled
        d. insecure key exchange algorithms are disabled, secure key exchange algorithms are enabled
        e. cipher suite order conforms with up to date standard
        The settings (protocols, ciphers, etc.) defined in this module are subject to change with new findings in network volunability
#>
function Test-EnhancedSecurity
{
    return ((Test-Protocol) -and (Test-Cipher) -and (Test-Hash) -and (Test-KeyExchangeAlgorithm) -and (Test-CipherSuiteOrder))
}

<#
    .SYNOPSIS
        This function sets the node to use enhanced security settings:
        a. disable insecure protocols and enable secure protocols
        b. disable insecure ciphers and enable secure ciphers
        c. disable insecure hash algorithms and enable secure hash algorithms
        d. disable insecure key exchange algorithms and enable secure key exchange algorithms
        e. set cipher suite order according to up to date standard
        The settings (protocols, ciphers, etc.) defined in this module are subject to change with new findings in network volunability
#>
function Set-EnhancedSecurity
{
    Set-Protocol
    Set-Cipher
    Set-Hash
    Set-KeyExchangeAlgorithm
    Set-CipherSuiteOrder
}

Export-ModuleMember -function *-EnhancedSecurity
