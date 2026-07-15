# Invoke-EndpointSetup.ps1
# Endpoint Build Toolkit v1.0 — WPF GUI orchestrator
# Run as Administrator

# --- Admin elevation ---
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "This script requires Administrator privileges. Relaunching as Administrator..."

    $scriptPath = $PSCommandPath
    if (-not $scriptPath) { $scriptPath = $MyInvocation.MyCommand.Path }

    if (-not $scriptPath) {
        Write-Host "Error: Could not determine script path. Ensure the file is saved before running." -ForegroundColor Red
        Read-Host "Press Enter to exit"
        exit
    }

    Start-Process powershell -WindowStyle Hidden -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`"" -Verb RunAs
    exit
}

# --- Initialize toolkit context ---
$script:Toolkit = @{
    Version       = (Get-Content "$PSScriptRoot\version.txt" -ErrorAction SilentlyContinue).Trim()
    Root          = $PSScriptRoot                          # dependencies/

    Parent        = Split-Path $PSScriptRoot -Parent       # repo root (where Launch.bat lives)
    IsUsb         = $false
    UsbDrive      = $null
    Config        = $null
    Authenticated = $false
    Session       = $null
}

# Hide the console window
$win32Signature = @'
[DllImport("user32.dll")]
public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
[DllImport("kernel32.dll")]
public static extern IntPtr GetConsoleWindow();
'@
$win32Api = Add-Type -MemberDefinition $win32Signature -Name 'Win32Console' -Namespace 'Win32' -PassThru
$win32Api::ShowWindow($win32Api::GetConsoleWindow(), 0) | Out-Null


if (-not $script:Toolkit.Version) { $script:Toolkit.Version = "0.0.0" }

$script:ToolkitKey = $null
$Host.UI.RawUI.WindowTitle = "Endpoint Build Toolkit v$($script:Toolkit.Version)"

Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

# Create working directory
$workDir = "$env:TEMP\InstallApps"
New-Item -ItemType Directory -Path $workDir -Force | Out-Null

# --- Load Core modules ---
$corePath = "$PSScriptRoot\Core"
if (Test-Path $corePath) {
    Get-ChildItem -Path $corePath -Filter "*.ps1" -File | ForEach-Object { . $_.FullName }
} else {
    Write-Host "FATAL: Core directory not found at '$corePath'." -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit
}

# --- Load UI modules ---
$uiPath = "$PSScriptRoot\UI"
if (Test-Path $uiPath) {
    Get-ChildItem -Path $uiPath -Filter "*.ps1" -File | ForEach-Object { . $_.FullName }
} else {
    Write-Host "FATAL: UI directory not found at '$uiPath'." -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit
}

# --- USB detection ---
Test-UsbExecution
if ($script:Toolkit.IsUsb) {
    # Update logic removed
}

# --- Launch GUI ---
Start-ToolkitGUI

# --- Cleanup: wipe sensitive data from memory and disk ---
Write-Host "Cleaning up sensitive data..." -ForegroundColor Yellow

$script:Toolkit.Config = $null
$script:ToolkitKey = $null
$script:Toolkit.Session = $null
if ($Global:SyncHash) {
    $Global:SyncHash.Toolkit.Config = $null
    $Global:SyncHash.ToolkitKey = $null
    $Global:SyncHash = $null
}

$tempPaths = @(
    "$env:TEMP\InstallApps",
    "$env:TEMP\endpoint-toolkit-update",
    "$env:TEMP\endpoint-toolkit-update.zip"
)
foreach ($p in $tempPaths) {
    if (Test-Path $p) { Remove-Item $p -Recurse -Force -ErrorAction SilentlyContinue }
}



[System.GC]::Collect()
Write-Host "Done. Session cleaned." -ForegroundColor Green
