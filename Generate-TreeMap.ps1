<#
.SYNOPSIS
    Generates a clean directory structure map using recursive filtering
.DESCRIPTION
    This script creates a visual representation of your project structure while
    excluding blacklisted folders and ALL their contents using a recursive approach.
.NOTES
    File Name      : Generate-TreeMap.ps1
    Author         : Your Name
    Prerequisite   : PowerShell 5.1 or later
#>

# Configuration Section
$blacklistFolders = @(
    # Version Control
    '.git',           # Git repository
    '.svn',           # Subversion
    '.hg',            # Mercurial
    '.bzr',           # Bazaar
    
    # IDE/Editor
    '.vscode',        # VS Code settings
    '.idea',          # IntelliJ IDEA
    '.vs',            # Visual Studio
    
    # Build/Compilation
    'out',            # Build output
    'bin',            # Binary files
    'obj',            # Intermediate build files
    'Debug',          # Debug build files
    'Release',        # Release build files
    'build',          # Build artifacts
    'dist',           # Distribution files
    'target',         # Maven/Gradle output
    '.zig-cache',
    
    # Dependencies
    'node_modules',   # Node.js dependencies
    'vendor',         # PHP/Composer dependencies
    'venv',           # Python virtual environment
    'env',            # Generic virtual environment
    '.env',           # Environment files
    
    # Cache/Temp
    '__pycache__',    # Python cache
    '.pytest_cache',  # Pytest cache
    'cache',          # Generic cache
    'temp',           # Temporary files
    'tmp',            # Temporary files
    '.tmp',           # Temporary files
    
    # Logs/Reports
    'logs',           # Log files
    'coverage',       # Coverage reports
    'test-results',   # Test results
    
    # System Files
    '.DS_Store',      # macOS metadata
    'Thumbs.db'       # Windows thumbnail cache
    'desktop.ini'     # Windows system file
    
    # Zig-specific
    'zig-cache',      # Zig build cache
    'zig-out'         # Zig build output
)

$blacklistFiles = @(
    # Version Control
    '.gitignore',     # Git ignore file
    '.gitattributes', # Git attributes
    '.gitmodules',    # Git submodules
    '.svnignore',     # SVN ignore file
    '.hgignore',      # Mercurial ignore file
    
    # Environment
    '.env',           # Environment variables
    '.env.local',     # Local environment
    '.env.*',         # All environment files
    
    # Configuration
    '.zigversion',    # Zig version file
    'treemap.txt',    # This script's output file
    
    # Compiled Files
    '*.pyc',          # Python bytecode
    '*.pyo',          # Python optimized bytecode
    '*.pyd',          # Python dynamic module
    # '*.dll',          # Dynamic link libraries
    '*.exe',          # Executable files
    '*.so',           # Shared objects
    # '*.dylib',        # Dynamic libraries (macOS)
    '*.a',            # Static libraries
    # '*.lib',          # Library files
    '*.obj',          # Object files
    '*.o',            # Object files
    '*.pdb',          # Program database
    '*.class',        # Java class files
    '*.jar',          # Java archive
    
    # Temporary Files
    '*.tmp',          # Temporary files
    '*.log',          # Log files
    '*.cache',        # Cache files
    '*.bak',          # Backup files
    '*.swp',          # Swap files
    '*.swo',          # Swap files
    '*~',             # Backup files
    '.#*',            # Emacs lock files
    '#*#'             # Emacs temporary files
)

# Main Script
$ErrorActionPreference = "SilentlyContinue"
$outputFile = "treemap.txt"
$rootPath = Get-Location

# Clear previous output file
if (Test-Path $outputFile) {
    Remove-Item $outputFile -Force
}

# Recursive function to process directories
function Process-Directory {
    param (
        [string]$path,
        [int]$depth = 0
    )
    
    $indent = '    ' * $depth
    $output = @()
    
    try {
        # Get items in current directory (only visible ones)
        $items = Get-ChildItem -Path $path -Force | 
                 Where-Object { -not ($_.Attributes -band [System.IO.FileAttributes]::Hidden) }
        
        # Process directories first
        $dirs = $items | Where-Object { $_.PSIsContainer } | Sort-Object Name
        
        foreach ($dir in $dirs) {
            # Skip if directory is blacklisted
            if ($blacklistFolders -contains $dir.Name) {
                continue
            }
            
            # Add directory to output
            $output += "$indent[+] $($dir.Name)"
            
            # Recursively process subdirectory
            $subOutput = Process-Directory -path $dir.FullName -depth ($depth + 1)
            if ($subOutput.Count -gt 0) {
                $output += $subOutput
            }
        }
        
        # Process files
        $files = $items | Where-Object { -not $_.PSIsContainer } | Sort-Object Name
        
        foreach ($file in $files) {
            # Skip if file matches blacklist patterns
            $blacklisted = $false
            foreach ($pattern in $blacklistFiles) {
                if ($file.Name -like $pattern) {
                    $blacklisted = $true
                    break
                }
            }
            
            if (-not $blacklisted) {
                $output += "$indent- $($file.Name)"
            }
        }
    }
    catch {
        # Handle access denied errors
        Write-Warning "Cannot access directory: $path"
    }
    
    return $output
}

# Generate output
Write-Host "🔍 Generating project structure..." -ForegroundColor Cyan
$outputLines = @(
    "Project Structure Map (Recursive Filtering)",
    "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')",
    "Root: $rootPath",
    "",
    "Structure:"
)

# Process root directory
$structure = Process-Directory -path $rootPath
$outputLines += $structure

# Save to file
$outputLines | Out-File -FilePath $outputFile -Encoding UTF8

# Final report
Write-Host "✅ Tree map generated successfully!" -ForegroundColor Green
Write-Host "📄 Output saved to: $(Resolve-Path $outputFile)" -ForegroundColor Cyan
Write-Host "📊 Total lines in output: $($outputLines.Count - 4)" -ForegroundColor Yellow