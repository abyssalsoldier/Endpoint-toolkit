# build.ps1 — Local build and test script for Endpoint Build Toolkit
# Mirrors the same exclusions as .github/workflows/release.yml
#
# Usage:
#   .\build.ps1              # Creates a timestamped zip build in _builds\
#   .\build.ps1 -Extract     # Also extracts the zip for inspection
#   .\build.ps1 -Dev         # Copies files directly (no zip) — fastest for testing
#   .\build.ps1 -Test        # Same as -Dev but also launches the toolkit

param(
    [switch]$Extract,
    [switch]$Dev,
    [switch]$Test,
    [switch]$SFX
)

$ErrorActionPreference = "Stop"

$repoRoot = $PSScriptRoot
$buildsRoot = Join-Path $repoRoot "_builds"

# Read version
$version = (Get-Content (Join-Path $repoRoot "dependencies\version.txt") -ErrorAction SilentlyContinue).Trim()
if (-not $version) { $version = "0.0.0" }

# Create timestamped build folder: _builds\v1.0.0_2026-03-26_1430
$timestamp = Get-Date -Format "yyyy-MM-dd_HHmm"
$buildName = "v${version}_${timestamp}"
$buildDir = Join-Path $buildsRoot $buildName

Write-Host "Building Endpoint Build Toolkit v$version" -ForegroundColor Cyan
Write-Host "  Output: _builds\$buildName\" -ForegroundColor White
Write-Host ""

New-Item -ItemType Directory -Path $buildDir -Force | Out-Null

# Common robocopy exclusions (mirrors release.yml)
$robocopyExcludeDirs = @(".git", ".github", ".claude", ".vscode", "_builds")
$robocopyExcludeFiles = @(".gitignore", ".gitattributes", "README.md", "build.ps1",
    "Protect-Credentials.ps1", "toolkit-config.json", "clients.csv")

if ($Dev -or $Test) {
    # --- Dev mode: copy files directly, no zip ---
    $outputPath = $buildDir

    $robocopyArgs = @(
        "`"$repoRoot`"",
        "`"$outputPath`"",
        "/MIR",
        "/XD") + $robocopyExcludeDirs + @("/XF") + $robocopyExcludeFiles + @(
        "/NFL", "/NDL", "/NJH", "/NJS",
        "/R:2", "/W:1"
    )
    $proc = Start-Process robocopy -ArgumentList $robocopyArgs -Wait -PassThru -NoNewWindow
    if ($proc.ExitCode -ge 8) {
        Write-Host "Error during copy (robocopy exit code $($proc.ExitCode))." -ForegroundColor Red
        exit 1
    }

    # Remove *.key files
    Get-ChildItem -Path $outputPath -Filter "*.key" -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Force

    Write-Host "Dev build complete: $outputPath" -ForegroundColor Green
    Write-Host ""

    if ($Test) {
        Write-Host "Launching toolkit..." -ForegroundColor Yellow
        $launchBat = Join-Path $outputPath "Launch.bat"
        if (Test-Path $launchBat) {
            Start-Process cmd.exe -ArgumentList "/c `"$launchBat`"" -Verb RunAs
        } else {
            $setupScript = Join-Path $outputPath "dependencies\Invoke-EndpointSetup.ps1"
            if (Test-Path $setupScript) {
                Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$setupScript`"" -Verb RunAs
            } else {
                Write-Host "Could not find launch entry point." -ForegroundColor Red
            }
        }
    }
} else {
    # --- Release mode: create zip + checksum ---
    Add-Type -AssemblyName System.IO.Compression.FileSystem

    $zipPath = Join-Path $buildDir "endpoint-build-toolkit.zip"
    $checksumPath = Join-Path $buildDir "latest.sha256"

    $tempStaging = Join-Path $env:TEMP "toolkit-build-staging"
    if (Test-Path $tempStaging) { Remove-Item $tempStaging -Recurse -Force }
    New-Item -ItemType Directory -Path $tempStaging -Force | Out-Null

    $robocopyArgs = @(
        "`"$repoRoot`"",
        "`"$tempStaging`"",
        "/MIR",
        "/XD") + $robocopyExcludeDirs + @("/XF") + $robocopyExcludeFiles + @(
        "/NFL", "/NDL", "/NJH", "/NJS",
        "/R:2", "/W:1"
    )
    $proc = Start-Process robocopy -ArgumentList $robocopyArgs -Wait -PassThru -NoNewWindow
    if ($proc.ExitCode -ge 8) {
        Write-Host "Error during staging copy (robocopy exit code $($proc.ExitCode))." -ForegroundColor Red
        exit 1
    }

    # Remove *.key files from staging
    Get-ChildItem -Path $tempStaging -Filter "*.key" -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Force


    # Create zip
    if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
    [System.IO.Compression.ZipFile]::CreateFromDirectory($tempStaging, $zipPath)
    Remove-Item $tempStaging -Recurse -Force

    # Generate SHA-256 checksum
    $hash = (Get-FileHash -Path $zipPath -Algorithm SHA256).Hash.ToLower()
    Set-Content -Path $checksumPath -Value $hash -NoNewline

    $zipSize = [math]::Round((Get-Item $zipPath).Length / 1MB, 2)

    Write-Host "Build complete:" -ForegroundColor Green
    Write-Host "  Zip : $zipPath ($zipSize MB)" -ForegroundColor White
    Write-Host "  SHA : $hash" -ForegroundColor White
    Write-Host ""

    if ($SFX) {
        Write-Host "Creating Self-Extracting EXE wrapper (SFX) using IExpress..." -ForegroundColor Cyan

        # Write output EXE directly to builds root to avoid folder conflicts during IExpress compilation
        $targetExe = Join-Path $buildsRoot "EndpointToolkit.exe"
        if (Test-Path $targetExe) { Remove-Item $targetExe -Force -ErrorAction SilentlyContinue }

        $bootstrapPath = Join-Path $buildDir "bootstrap.ps1"
        $sedPath = Join-Path $buildDir "sfx.sed"

        # 1. Write the bootstrap script
        $bootstrapScript = @'
# bootstrap.ps1 for Endpoint Build Toolkit SFX
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName PresentationFramework

$tempDir = Join-Path $env:TEMP "EndpointToolkit_SC"
if (Test-Path $tempDir) {
    Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
}
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

$zipPath = Join-Path $PSScriptRoot "endpoint-build-toolkit.zip"
if (-not (Test-Path $zipPath)) {
    [System.Windows.MessageBox]::Show("Fatal: Toolkit archive not found.", "Error", "OK", "Error") | Out-Null
    exit 1
}

try {
    # Extract zip archive
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory($zipPath, $tempDir)

    # Launch Invoke-EndpointSetup.ps1 as Admin
    $setupScript = Join-Path $tempDir "dependencies\Invoke-EndpointSetup.ps1"
    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$setupScript`"" -Verb RunAs -Wait
} catch {
    [System.Windows.MessageBox]::Show("Failed to launch toolkit: $($_.Exception.Message)", "Launch Error", "OK", "Error") | Out-Null
} finally {
    # Cleanup temp folder after exit
    if (Test-Path $tempDir) {
        Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}
'@
        Set-Content -Path $bootstrapPath -Value $bootstrapScript -Encoding ascii -Force

        # 2. Write the IExpress SED configuration file
        $srcDir = (Resolve-Path $buildDir).Path
        if (-not $srcDir.EndsWith("\")) { $srcDir += "\" }
        
        $sedContent = @"
[Version]
Class=IEXPRESS
SEDVersion=3

[Options]
PackagePurpose=InstallApp
ShowInstallProgramWindow=0
HideExtractAnimation=1
UseLongFileName=1
InsideCompressed=1
CAB_FixedSize=0
CAB_ResvCodeSigning=0
RebootMode=I
InstallPrompt=%InstallPrompt%
DisplayLicense=%DisplayLicense%
FinishMessage=%FinishMessage%
TargetName=%TargetName%
FriendlyName=%FriendlyName%
AppLaunched=%AppLaunched%
PostInstallCmd=%PostInstallCmd%
AdminQuietInstCmd=%AdminQuietInstCmd%
UserQuietInstCmd=%UserQuietInstCmd%
SourceFiles=SourceFiles

[Strings]
InstallPrompt=
DisplayLicense=
FinishMessage=
TargetName=$targetExe
FriendlyName=Endpoint Build Toolkit
AppLaunched=powershell.exe -NoProfile -ExecutionPolicy Bypass -File bootstrap.ps1
PostInstallCmd=<None>
AdminQuietInstCmd=
UserQuietInstCmd=
FILE0=endpoint-build-toolkit.zip
FILE1=bootstrap.ps1

[SourceFiles]
SourceFiles0=$srcDir

[SourceFiles0]
%FILE0%=
%FILE1%=
"@
        Set-Content -Path $sedPath -Value $sedContent -Encoding ascii -Force

        # Ensure files are not locked by the OS or Antivirus before compiling
        $filesToCheck = @($zipPath, $bootstrapPath, $sedPath)
        foreach ($file in $filesToCheck) {
            $unlocked = $false
            for ($i = 0; $i -lt 10; $i++) {
                try {
                    $stream = [System.IO.File]::Open($file, 'Open', 'Read', 'None')
                    $stream.Close()
                    $unlocked = $true
                    break
                } catch {
                    Write-Host "Waiting for file lock release on: $(Split-Path $file -Leaf)..." -ForegroundColor Yellow
                    Start-Sleep -Milliseconds 500
                }
            }
            if (-not $unlocked) {
                Write-Host "Warning: $(Split-Path $file -Leaf) may still be locked." -ForegroundColor Red
            }
        }

        # 3. Execute IExpress via Start-Process to wait for complete compilation
        Write-Host "Compiling SFX..." -ForegroundColor Yellow
        $proc = Start-Process iexpress -ArgumentList "/N", "/Q", $sedPath -Wait -NoNewWindow -PassThru
        $exitCode = $proc.ExitCode
        
        if ($exitCode -eq 0 -and (Test-Path $targetExe)) {
            # Clean up temporary build artifacts only on success
            Remove-Item $bootstrapPath -Force -ErrorAction SilentlyContinue
            Remove-Item $sedPath -Force -ErrorAction SilentlyContinue
            
            $exeSize = [math]::Round((Get-Item $targetExe).Length / 1MB, 2)
            Write-Host "SFX build complete: $targetExe ($exeSize MB)" -ForegroundColor Green
            Write-Host ""
        } else {
            Write-Host "SFX compilation failed (iexpress exit code $exitCode)." -ForegroundColor Red
            Write-Host "Staged files left at $buildDir for debugging (sfx.sed, bootstrap.ps1)." -ForegroundColor Yellow
            Write-Host ""
        }
    }

    # Extract if requested
    if ($Extract) {
        $extractPath = Join-Path $buildDir "extracted"
        Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force
        Write-Host "Extracted to: $extractPath" -ForegroundColor Green
    }
}
