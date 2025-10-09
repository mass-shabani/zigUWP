<#
.SYNOPSIS
    Manages code signing certificates for UWP app development.

.DESCRIPTION
    This script adds or removes a PFX certificate to/from Windows certificate stores for code signing.
    Usage: ./register-cert.ps1 [-Action add|remove] [-CertFilePath path] [-CertPassword password]
#>

param(
    [string]$CertFilePath = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "./zig-out/sign/zigUWP.pfx")),
    [string]$CertPassword = "zigUWP123!",
    [ValidateSet("add", "remove")]
    [string]$Action = "add"
)

# Function to list certificates with matching CN and O
function List-Certificates {
    param([object]$Certificate)

    if ($Certificate -is [System.Array]) {
        $Certificate = $Certificate[0]
    }
    $Certificate = [System.Security.Cryptography.X509Certificates.X509Certificate2]$Certificate

    $signingCN = if ($Certificate.Subject -match 'CN=([^,]+)') { $matches[1] } else { '' }
    $signingO = if ($Certificate.Subject -match 'O=([^,]+)') { $matches[1] } else { '' }

    Write-Host "Listing certificates with CN='$signingCN' and O='$signingO':"
    Write-Host "Store           | Subject                         | Thumbprint"
    Write-Host "----------------|---------------------------------|--------------------------------"

    $allCerts = Get-ChildItem -Path Cert:\ -Recurse | Select-Object `
        @{Name="CN";Expression={try { if ($_.Subject -and $_.Subject -match 'CN=([^,]+)') { $matches[1] } else { '' } } catch { '' }}}, `
        @{Name="O";Expression={try { if ($_.Subject -and $_.Subject -match 'O=([^,]+)') { $matches[1] } else { '' } } catch { '' }}}, `
        @{Name="Store";Expression={try { $_.PSParentPath -replace '.*Certificate::', '' } catch { '' }}}, `
        Subject, Thumbprint

    $filteredCerts = $allCerts | Where-Object { $_.CN -eq $signingCN -and $_.O -eq $signingO }

    foreach ($certItem in $filteredCerts) {
        $store = if ($certItem.Store) { $certItem.Store.PadRight(16).Substring(0,16) } else { ''.PadRight(16).Substring(0,16) }
        $subject = if ($certItem.Subject) { $certItem.Subject.PadRight(32).Substring(0,32) } else { ''.PadRight(32).Substring(0,32) }
        $thumb = if ($certItem.Thumbprint) { $certItem.Thumbprint } else { '' }

        if ($certItem.Thumbprint -and $certItem.Thumbprint -eq $Certificate.Thumbprint) {
            Write-Host "$store| $subject| $thumb" -ForegroundColor Green
        } else {
            Write-Host "$store| $subject| $thumb"
        }
    }

    $count = $filteredCerts.Count
    Write-Host "Certificates found in system: $count"
    Write-Host ""
}

# Function to ensure certificate is trusted in CurrentUser\Root
function Ensure-CertificateTrusted {
    param([object]$Certificate)

    if ($Certificate -is [System.Array]) {
        $Certificate = $Certificate[0]
    }
    $Certificate = [System.Security.Cryptography.X509Certificates.X509Certificate2]$Certificate

    $thumbprint = $Certificate.Thumbprint

    # Check if already in CurrentUser\Root
    $trustedCert = Get-ChildItem -Path Cert:\CurrentUser\Root | Where-Object { $_.Thumbprint -eq $thumbprint }

    if (-not $trustedCert) {
        Write-Host 'Adding certificate to CurrentUser\Root for trust...'
        try {
            $Certificate | Export-Certificate -FilePath "temp.cer" -Type CERT
            Import-Certificate -FilePath "temp.cer" -CertStoreLocation Cert:\CurrentUser\Root
            Remove-Item "temp.cer"
            Write-Host '✓ Certificate added to trusted root successfully' -ForegroundColor Green
        } catch {
            Write-Host "Failed to add certificate to trusted root: $($_.Exception.Message)" -ForegroundColor Red
        }
    } else {
        Write-Host 'Certificate is already trusted in CurrentUser\Root'
    }
}

# Function to remove certificate from stores
function Remove-Certificate {
    param([object]$Certificate)

    if ($Certificate -is [System.Array]) {
        $Certificate = $Certificate[0]
    }
    $Certificate = [System.Security.Cryptography.X509Certificates.X509Certificate2]$Certificate

    $thumbprint = $Certificate.Thumbprint

    Write-Host 'Removing certificate from stores...'

    # Remove from CurrentUser\My
    $certInMy = Get-ChildItem -Path Cert:\CurrentUser\My | Where-Object { $_.Thumbprint -eq $thumbprint }
    if ($certInMy) {
        $certInMy | Remove-Item
        Write-Host '✓ Removed from CurrentUser\My' -ForegroundColor Green
    }

    # Remove from CurrentUser\Root
    $certInRoot = Get-ChildItem -Path Cert:\CurrentUser\Root | Where-Object { $_.Thumbprint -eq $thumbprint }
    if ($certInRoot) {
        $certInRoot | Remove-Item
        Write-Host '✓ Removed from CurrentUser\Root' -ForegroundColor Green
    }

    # Remove from CurrentUser\CA if exists
    $certInCA = Get-ChildItem -Path Cert:\CurrentUser\CA | Where-Object { $_.Thumbprint -eq $thumbprint }
    if ($certInCA) {
        $certInCA | Remove-Item
        Write-Host '✓ Removed from CurrentUser\CA' -ForegroundColor Green
    }

    Write-Host 'Certificate removal completed.'
}

# Main script logic
try {
    Write-Host "Checking certificate file: $CertFilePath"
    if (-not (Test-Path $CertFilePath)) {
        Write-Host "Certificate file not found: $CertFilePath" -ForegroundColor Yellow
        exit 0
    }
    Write-Host "Certificate file found."

    Write-Host "Converting password to secure string..."
    $securePassword = ConvertTo-SecureString $CertPassword -AsPlainText -Force

    Write-Host "Loading certificate..."
    $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2
    $cert.Import($CertFilePath, $securePassword, [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::Exportable)
    Write-Host "Certificate loaded successfully."

    if ($Action -eq "add") {
        Write-Host "Checking if certificate is already in CurrentUser\My..."
        # Import to CurrentUser\My if not already there
        $existingCert = Get-ChildItem -Path Cert:\CurrentUser\My | Where-Object { $_.Thumbprint -eq $cert.Thumbprint }
        if (-not $existingCert) {
            Write-Host "Importing certificate to CurrentUser\My..."
            Import-PfxCertificate -FilePath $CertFilePath -CertStoreLocation Cert:\CurrentUser\My -Password $securePassword | Out-Null
            Write-Host '✓ Certificate imported to CurrentUser\My' -ForegroundColor Green
        } else {
            Write-Host "Certificate already in CurrentUser\My."
        }

        Write-Host "Ensuring certificate is trusted..."
        Ensure-CertificateTrusted -Certificate $cert

        Write-Host "Listing certificates..."
        List-Certificates -Certificate $cert
        Write-Host 'Certificate trust setup completed.'
    } elseif ($Action -eq "remove") {
        Write-Host "Removing certificate..."
        Remove-Certificate -Certificate $cert
        List-Certificates -Certificate $cert
        Write-Host 'Certificate removal completed.'
    }
} catch {
    Write-Error "Failed to process certificate: $_"
    exit 1
}