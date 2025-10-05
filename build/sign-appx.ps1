#sign-appx.ps1
# PowerShell script for signing UWP packages
param(
    [string]$PackagePath = "zig-out/bin/zigUWP.appx",
    [string]$SignToolPath = "",
    [string]$PublisherName = "CN=Massoud, O=Massoud, C=IR",
    [string]$CertPassword = "zigUWP123!",
    [string]$CertSubject = "zigUWP Self-Signed Certificate",
    [string]$CertFilePath = "zig-out/sign/zigUWP.pfx"
)

# Check if SKIP_SIGNING environment variable is set
$skipSigning = [Environment]::GetEnvironmentVariable('SKIP_SIGNING')
if ($skipSigning -eq 'true') {
    Write-Host 'Skipping package signing (SKIP_SIGNING=true)'
    exit 0
}

# Set default SignTool path if not provided
if (-not $SignToolPath) {
    $SignToolPath = "C:\Program Files (x86)\Windows Kits\10\bin\10.0.26100.0\x64"
}

# Add SignTool to PATH
$env:PATH += ';' + $SignToolPath

# Try to find SignTool in different locations
$signToolExe = $null
if (Get-Command 'SignTool' -ErrorAction SilentlyContinue) {
    $signToolExe = 'SignTool'
}
elseif (Test-Path ($SignToolPath + '\SignTool.exe')) {
    $signToolExe = $SignToolPath + '\SignTool.exe'
}
else {
    Write-Host 'SignTool not found in expected locations'
    exit 1
}

# Function to create self-signed certificate
function Create-SelfSignedCertificate {
    param(
        [string]$Subject,
        [string]$Password,
        [string]$FilePath
    )
    
    Write-Host 'Creating self-signed certificate...'
    try {
        $cert = New-SelfSignedCertificate -Subject $Subject -CertStoreLocation Cert:\CurrentUser\My -DnsName $Subject -KeySpec Signature -KeyUsage DigitalSignature -NotAfter (Get-Date).AddYears(1)
        $securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
        $certDir = Split-Path $FilePath -Parent
        New-Item -ItemType Directory -Path $certDir -Force
        Export-PfxCertificate -Cert $cert -FilePath $FilePath -Password $securePassword
        Write-Host 'Self-signed certificate created successfully at:' $FilePath
        return $cert
    }
    catch {
        Write-Host 'Failed to create self-signed certificate:' $_.Exception.Message
        return $null
    }
}

# Check if we have a certificate
$cert = $null
$usePfx = $false

if (Test-Path $CertFilePath) {
    Write-Host 'Existing PFX certificate found, importing...'
    $securePassword = ConvertTo-SecureString $CertPassword -AsPlainText -Force
    try {
        $cert = Import-PfxCertificate -FilePath $CertFilePath -CertStoreLocation Cert:\CurrentUser\My -Password $securePassword
        Write-Host 'Certificate imported successfully'
        $usePfx = $true
    }
    catch {
        Write-Host 'Failed to import existing certificate:' $_.Exception.Message
        Write-Host 'Creating new self-signed certificate...'
        Remove-Item $CertFilePath -Force -ErrorAction SilentlyContinue
        try {
            $cert = New-SelfSignedCertificate -Subject $PublisherName -CertStoreLocation Cert:\CurrentUser\My -Type CodeSigningCert -NotAfter (Get-Date).AddYears(1)
            $securePassword = ConvertTo-SecureString $CertPassword -AsPlainText -Force
            $certDir = Split-Path $CertFilePath -Parent
            New-Item -ItemType Directory -Path $certDir -Force
            Export-PfxCertificate -Cert $cert -FilePath $CertFilePath -Password $securePassword
            Write-Host 'Self-signed certificate created successfully at:' $CertFilePath
            $usePfx = $true
        }
        catch {
            Write-Host 'Failed to create self-signed certificate:' $_.Exception.Message
            $usePfx = $false
        }
    }
} else {
    Write-Host 'Creating new self-signed certificate...'
    try {
        $cert = New-SelfSignedCertificate -Subject $PublisherName -CertStoreLocation Cert:\CurrentUser\My -Type CodeSigningCert -NotAfter (Get-Date).AddYears(1)
        $securePassword = ConvertTo-SecureString $CertPassword -AsPlainText -Force
        $certDir = Split-Path $CertFilePath -Parent
        New-Item -ItemType Directory -Path $certDir -Force
        Export-PfxCertificate -Cert $cert -FilePath $CertFilePath -Password $securePassword
        Write-Host 'Self-signed certificate created successfully at:' $CertFilePath
        $usePfx = $true
    }
    catch {
        Write-Host 'Failed to create self-signed certificate:' $_.Exception.Message
        $usePfx = $false
    }
}

# Check if SignTool is available
if (Get-Command 'SignTool' -ErrorAction SilentlyContinue) {
    try {
        Write-Host 'Attempting to sign package...'
        
        if ($usePfx -and (Test-Path $CertFilePath)) {
            Write-Host 'Signing package with certificate from store...'
            Write-Host 'Certificate details:'
            $cert | Format-List
            Write-Host 'Attempting to sign with debug info...'
            & $signToolExe sign /s My /sha1 $cert.Thumbprint /fd sha256 /td sha256 /tr 'http://timestamp.digicert.com' /debug $PackagePath
            if ($LASTEXITCODE -ne 0) {
                Write-Host "SignTool failed with exit code: $LASTEXITCODE"
                Write-Host 'Trying without timestamp...'
                & $signToolExe sign /s My /sha1 $cert.Thumbprint /fd sha256 /debug $PackagePath
                if ($LASTEXITCODE -ne 0) {
                    Write-Host "SignTool failed with exit code: $LASTEXITCODE"
                    exit 1
                }
            }
        }
        elseif ($cert) {
            Write-Host 'Signing package with certificate from store...'
            & SignTool sign /s My /sha1 $cert.Thumbprint /fd sha256 $PackagePath
            if ($LASTEXITCODE -ne 0) {
                Write-Host "SignTool failed with exit code: $LASTEXITCODE"
                exit 1
            }
        }
        else {
            Write-Host 'No certificate available for signing'
            exit 1
        }
        
        Write-Host 'Package signed successfully'
        exit 0
    }
    catch {
        Write-Host 'SignTool failed with error:' $_.Exception.Message
        
        # Show certificate information for debugging
        Write-Host '=== Certificate Information ==='
        if (Get-ChildItem -Path Cert:\CurrentUser\My -ErrorAction SilentlyContinue) {
            Write-Host 'Certificates in My store:'
            Get-ChildItem -Path Cert:\CurrentUser\My | Select-Object Subject, Thumbprint, NotAfter | Format-Table -AutoSize
        } else {
            Write-Host 'No certificates found in My store'
        }
        
        Write-Host 'Available certificate stores:'
        Get-ChildItem -Path Cert:\ -Recurse | Where-Object { $_.PSIsContainer } | Select-Object -ExpandProperty Name
        
        Write-Host ''
        Write-Host 'To skip signing, set environment variable: SKIP_SIGNING=true'
        exit 1
    }
}
else {
    if (Test-Path ($SignToolPath + '\SignTool.exe')) {
        try {
            Write-Host 'Attempting to sign package with full path...'
            
            if ($usePfx -and (Test-Path $CertFilePath)) {
                Write-Host 'Signing package with PFX certificate...'
                & $signToolExe sign /f $CertFilePath /p $CertPassword /fd sha256 /td sha256 /tr 'http://timestamp.digicert.com' $PackagePath
                if ($LASTEXITCODE -ne 0) {
                    Write-Host "SignTool failed with exit code: $LASTEXITCODE"
                    Write-Host 'Trying without timestamp...'
                    & $signToolExe sign /f $CertFilePath /p $CertPassword /fd sha256 $PackagePath
                    if ($LASTEXITCODE -ne 0) {
                        Write-Host "SignTool failed with exit code: $LASTEXITCODE"
                        exit 1
                    }
                }
            }
            elseif ($cert) {
                Write-Host 'Signing package with certificate from store...'
                & ($SignToolPath + '\SignTool.exe') sign /s My /sha1 $cert.Thumbprint /fd sha256 $PackagePath
                if ($LASTEXITCODE -ne 0) {
                    Write-Host "SignTool failed with exit code: $LASTEXITCODE"
                    exit 1
                }
            }
            else {
                Write-Host 'No certificate available for signing'
                exit 1
            }
            
            Write-Host 'Package signed successfully'
            exit 0
        }
        catch {
            Write-Host 'SignTool failed with error:' $_.Exception.Message
            
            # Show certificate information for debugging
            Write-Host '=== Certificate Information ==='
            if (Get-ChildItem -Path Cert:\CurrentUser\My -ErrorAction SilentlyContinue) {
                Write-Host 'Certificates in My store:'
                Get-ChildItem -Path Cert:\CurrentUser\My | Select-Object Subject, Thumbprint, NotAfter | Format-Table -AutoSize
            } else {
                Write-Host 'No certificates found in My store'
            }
            
            Write-Host 'Available certificate stores:'
            Get-ChildItem -Path Cert:\ -Recurse | Where-Object { $_.PSIsContainer } | Select-Object -ExpandProperty Name
            
            Write-Host ''
            Write-Host 'To skip signing, set environment variable: SKIP_SIGNING=true'
            exit 1
        }
    }
    else {
        Write-Host 'SignTool not found, skipping package signing'
        exit 0
    }
}