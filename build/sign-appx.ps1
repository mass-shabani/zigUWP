# build\sign-appx.ps1
# PowerShell script for signing UWP packages with improved readability and functionality

<#
.SYNOPSIS
    Signs UWP app packages with a code signing certificate.

.DESCRIPTION
    Creates or uses an existing self-signed certificate to sign .appx packages for development and testing.
    Usage: ./sign-appx.ps1 [-PackagePath path] [-CertFilePath path] [-CertPassword password]
#>

param(
    [string]$PackagePath = "zig-out/bin/zigUWP.appx",
    [string]$SignToolPath = "",
    [string]$PublisherName = "CN=Massoud, O=Massoud, C=US",
    [string]$CertPassword = "zigUWP123!",
    [string]$CertSubject = "zigUWP Self-Signed Certificate",
    [string]$CertFilePath = "zig-out/sign/zigUWP.pfx"
)

# Function to find SignTool executable
function Find-SignTool {
    param([string]$SignToolPath)

    if (-not $SignToolPath) {
        $SignToolPath = "C:\Program Files (x86)\Windows Kits\10\bin\10.0.26100.0\x64"
    }

    $env:PATH += ';' + $SignToolPath

    if (Get-Command 'SignTool' -ErrorAction SilentlyContinue) {
        return 'SignTool'
    } elseif (Test-Path ($SignToolPath + '\SignTool.exe')) {
        return $SignToolPath + '\SignTool.exe'
    } else {
        Write-Host 'SignTool not found in expected locations'
        exit 1
    }
}

# Function to create or import certificate in CurrentUser\My store
function Get-Certificate {
    param(
        [string]$PublisherName,
        [string]$CertPassword,
        [string]$CertFilePath
    )

    $cert = $null

    if (Test-Path $CertFilePath) {
        Write-Host 'Existing PFX certificate found, importing to CurrentUser\My...'
        $securePassword = ConvertTo-SecureString $CertPassword -AsPlainText -Force
        try {
            $cert = Import-PfxCertificate -FilePath $CertFilePath -CertStoreLocation Cert:\CurrentUser\My -Password $securePassword
            Write-Host 'Certificate imported successfully to CurrentUser\My'
        } catch {
            Write-Host 'Failed to import existing certificate:' $_.Exception.Message
            Write-Host 'Removing invalid PFX and creating new certificate...'
            Remove-Item $CertFilePath -Force -ErrorAction SilentlyContinue
            $cert = New-SelfSignedCertificate -Subject $PublisherName -CertStoreLocation Cert:\CurrentUser\My -Type CodeSigningCert -NotAfter (Get-Date).AddYears(1)
        }
    } else {
        Write-Host 'Creating new self-signed certificate in CurrentUser\My...'
        $cert = New-SelfSignedCertificate -Subject $PublisherName -CertStoreLocation Cert:\CurrentUser\My -Type CodeSigningCert -NotAfter (Get-Date).AddYears(1)
    }

    # Ensure $cert is a single certificate object
    if ($cert -is [System.Array]) {
        $cert = $cert[0]
    }

    if ($cert) {
        # Export to PFX for persistence
        $securePassword = ConvertTo-SecureString $CertPassword -AsPlainText -Force
        $certDir = Split-Path $CertFilePath -Parent
        New-Item -ItemType Directory -Path $certDir -Force | Out-Null
        try {
            Export-PfxCertificate -Cert $cert -FilePath $CertFilePath -Password $securePassword
            Write-Host 'Certificate exported to PFX successfully at:' $CertFilePath
        } catch {
            Write-Host 'Certificate already exists in PFX or private key is non-exportable. Using existing PFX.'
        }
    } else {
        Write-Host 'Failed to obtain certificate'
        exit 1
    }

    return $cert
}

# Function to sign the package
function Sign-Package {
    param(
        [string]$PackagePath,
        [string]$SignToolExe,
        [object]$Certificate
    )

    if ($Certificate -is [System.Array]) {
        $Certificate = $Certificate[0]
    }
    $Certificate = [System.Security.Cryptography.X509Certificates.X509Certificate2]$Certificate

    Write-Host 'Attempting to sign package...'
    Write-Host 'Certificate details:'
    $Certificate | Format-List Subject, Thumbprint, NotAfter

    # Try signing with timestamp first
    & $SignToolExe sign /s My /sha1 $Certificate.Thumbprint /fd sha256 /td sha256 /tr 'http://timestamp.digicert.com' $PackagePath 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "SignTool failed with timestamp, trying without..." -ForegroundColor red
        & $SignToolExe sign /s My /sha1 $Certificate.Thumbprint /fd sha256 $PackagePath 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Host "SignTool failed with exit code: $LASTEXITCODE" -ForegroundColor red
            exit 1
        }
    }

    $fullPath = $PackagePath
    Write-Host "[OK] Successfully signed: $fullPath" -ForegroundColor Green
     Write-Host ""
}

# Main script logic

# Check if SKIP_SIGNING is set
$skipSigning = [Environment]::GetEnvironmentVariable('SKIP_SIGNING')
if ($skipSigning -eq 'true') {
    Write-Host 'Skipping package signing (SKIP_SIGNING=true)'
    exit 0
}

# Find SignTool
$signToolExe = Find-SignTool -SignToolPath $SignToolPath

# Get or create certificate in CurrentUser
$cert = Get-Certificate -PublisherName $PublisherName -CertPassword $CertPassword -CertFilePath $CertFilePath

# Sign the package
Sign-Package -PackagePath $PackagePath -SignToolExe $signToolExe -Certificate $cert

exit 0
