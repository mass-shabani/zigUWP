# PowerShell script for signing UWP packages
param(
    [string]$PackagePath = "zig-out/bin/zigUWP.appx",
    [string]$SignToolPath = "",
    [string]$PublisherName = "CN=Massoud, O=Massoud, C=IR",
    [string]$CertPassword = "zigUWP123!",
    [string]$CertSubject = "zigUWP Self-Signed Certificate",
    [string]$CertFilePath = "zig-out/bin/zigUWP.pfx"
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

# Function to create self-signed certificate
function Create-SelfSignedCertificate {
    param(
        [string]$Subject,
        [string]$Password,
        [string]$FilePath
    )
    
    Write-Host 'Creating self-signed certificate...'
    try {
        $cert = New-SelfSignedCertificate -Subject $Subject -CertStoreLocation Cert:\LocalMachine\My -KeySpec KeyExchange -KeyUsage DigitalSignature -KeyUsage KeyEncipherment -NotAfter (Get-Date).AddYears(1)
        $securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
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

# First, try to use PFX file if it exists
if (Test-Path $CertFilePath) {
    Write-Host 'Found existing PFX certificate at:' $CertFilePath
    $usePfx = $true
}
else {
    # Try to find certificate in My store by subject
    $cert = Get-ChildItem -Path Cert:\LocalMachine\My -ErrorAction SilentlyContinue | Where-Object { $_.Subject -like "*$CertSubject*" }
    if ($cert) {
        Write-Host 'Found certificate in My store with subject:' $CertSubject
    }
    else {
        Write-Host 'No certificate found in My store with subject:' $CertSubject
        Write-Host 'Attempting to create self-signed certificate...'
        $cert = Create-SelfSignedCertificate -Subject $CertSubject -Password $CertPassword -FilePath $CertFilePath
        if ($cert) {
            $usePfx = $true
        }
    }
}

# Check if SignTool is available
if (Get-Command 'SignTool' -ErrorAction SilentlyContinue) {
    try {
        Write-Host 'Attempting to sign package...'
        
        if ($usePfx -and (Test-Path $CertFilePath)) {
            Write-Host 'Signing package with PFX certificate...'
            SignTool sign /f $CertFilePath /p $CertPassword /fd SHA256 /td SHA256 /tr 'http://timestamp.digicert.com' $PackagePath
        }
        elseif ($cert) {
            Write-Host 'Signing package with certificate from store...'
            SignTool sign /s 'LocalMachine\My' /n $cert.Subject /fd SHA256 /td SHA256 /tr 'http://timestamp.digicert.com' $PackagePath
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
        if (Get-ChildItem -Path Cert:\LocalMachine\My -ErrorAction SilentlyContinue) {
            Write-Host 'Certificates in My store:'
            Get-ChildItem -Path Cert:\LocalMachine\My | Select-Object Subject, Thumbprint, NotAfter | Format-Table -AutoSize
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
                & ($SignToolPath + '\SignTool.exe') sign /f $CertFilePath /p $CertPassword /fd SHA256 /td SHA256 /tr 'http://timestamp.digicert.com' $PackagePath
            }
            elseif ($cert) {
                Write-Host 'Signing package with certificate from store...'
                & ($SignToolPath + '\SignTool.exe') sign /s 'LocalMachine\My' /n $cert.Subject /fd SHA256 /td SHA256 /tr 'http://timestamp.digicert.com' $PackagePath
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
            if (Get-ChildItem -Path Cert:\LocalMachine\My -ErrorAction SilentlyContinue) {
                Write-Host 'Certificates in My store:'
                Get-ChildItem -Path Cert:\LocalMachine\My | Select-Object Subject, Thumbprint, NotAfter | Format-Table -AutoSize
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