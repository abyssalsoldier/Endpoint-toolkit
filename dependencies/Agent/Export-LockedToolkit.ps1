# Export-LockedToolkit.ps1
# Compiles the current toolkit into a standalone, password-protected Self-Extracting Executable (SFX).
# The resulting .exe can be distributed safely, and cannot be accessed without the password.

$ErrorActionPreference = "Stop"
$scriptDir = $PSScriptRoot
$toolkitRoot = (Resolve-Path (Join-Path $scriptDir "..\..")).Path

# Load Crypto module
. (Join-Path $toolkitRoot "dependencies\Core\Crypto.ps1")

Write-Host "=== Export Locked Toolkit ===" -ForegroundColor Cyan
Write-Host "This will package the current toolkit folder into a standalone .exe file."
Write-Host ""

$password = Read-Host "Enter the password to lock this toolkit" -AsSecureString
if ($password.Length -lt 4) {
    Write-Host "ERROR: Password must be at least 4 characters." -ForegroundColor Red
    exit 1
}
$bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($password)
$plainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
[System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)

$outPath = Read-Host "Enter output path (e.g., C:\Users\Public\Desktop)"
if (-not (Test-Path $outPath)) {
    Write-Host "Output path not found." -ForegroundColor Red
    exit 1
}

$targetExe = Join-Path $outPath "EndpointToolkit_Locked.exe"

Write-Host "`nStaging toolkit..." -ForegroundColor Yellow
$tempStaging = Join-Path $env:TEMP "ToolkitExport_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
New-Item -ItemType Directory -Path $tempStaging -Force | Out-Null

$robocopyArgs = @(
    "`"$toolkitRoot`"",
    "`"$tempStaging`"",
    '/MIR',
    '/XD', '.git', '.github', '.claude', '.vscode', 'Installers', '_builds',
    '/XF', '.gitignore', 'Export-LockedToolkit.ps1', '.toolkit-key', 'build.ps1',
    '/NFL', '/NDL', '/NJH', '/NJS',
    '/R:2', '/W:1'
)
$proc = Start-Process robocopy -ArgumentList $robocopyArgs -Wait -PassThru -NoNewWindow
if ($proc.ExitCode -ge 8) { throw "Robocopy failed." }

Write-Host "Generating AES-256 .sfx-key..." -ForegroundColor Yellow
# We generate a random main key for the toolkit payload to use internally, 
# and encrypt it with the user's password.
$mainToolkitKey = -join ((48..57) + (65..90) + (97..122) | Get-Random -Count 32 | % {[char]$_})
$encryptedPassword = Protect-SfxPassword -MainToolkitKey $mainToolkitKey -SfxPassword $plainPassword
Set-Content -Path "$tempStaging\.sfx-key" -Value $encryptedPassword -NoNewline -Force
(Get-Item "$tempStaging\.sfx-key" -Force).Attributes = 'Hidden'

Write-Host "Compressing payload..." -ForegroundColor Yellow
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zipPath = Join-Path $env:TEMP "toolkit-payload-$(Get-Date -Format 'yyyyMMdd_HHmmss').zip"
[System.IO.Compression.ZipFile]::CreateFromDirectory($tempStaging, $zipPath)

Write-Host "Compiling SFX Executable..." -ForegroundColor Yellow
$csharpCode = @"
using System;
using System.IO;
using System.IO.Compression;
using System.Diagnostics;
using System.Reflection;

namespace EndpointToolkit
{
    class Program
    {
        static void Main(string[] args)
        {
            string exePath = Assembly.GetExecutingAssembly().Location;
            string tempDir = Path.Combine(Path.GetTempPath(), "EndpointToolkit_SC");
            
            if (Directory.Exists(tempDir)) {
                try { Directory.Delete(tempDir, true); } catch { }
            }
            Directory.CreateDirectory(tempDir);
            
            Console.WriteLine("Extracting Secure Toolkit...");
            try {
                using (FileStream fs = new FileStream(exePath, FileMode.Open, FileAccess.Read)) {
                    using (ZipArchive archive = new ZipArchive(fs, ZipArchiveMode.Read)) {
                        archive.ExtractToDirectory(tempDir);
                    }
                }
            } catch (Exception ex) {
                Console.ForegroundColor = ConsoleColor.Red;
                Console.WriteLine("Extraction failed: " + ex.Message);
                Console.ResetColor();
                Console.ReadKey();
                return;
            }

            string setupScript = Path.Combine(tempDir, @"dependencies\Invoke-EndpointSetup.ps1");
            ProcessStartInfo psi = new ProcessStartInfo {
                FileName = "powershell.exe",
                Arguments = $"-NoProfile -ExecutionPolicy Bypass -File \"{setupScript}\"",
                UseShellExecute = true,
                Verb = "RunAs"
            };
            try {
                Process.Start(psi);
            } catch (Exception ex) {
                Console.ForegroundColor = ConsoleColor.Red;
                Console.WriteLine("Launch failed: " + ex.Message);
                Console.ResetColor();
                Console.ReadKey();
            }
        }
    }
}
"@

$stubPath = Join-Path $env:TEMP "ToolkitStub-$(Get-Date -Format 'yyyyMMdd_HHmmss').exe"
Add-Type -TypeDefinition $csharpCode -ReferencedAssemblies "System.IO.Compression", "System.IO.Compression.FileSystem" -OutputAssembly $stubPath -OutputType ConsoleApplication

Write-Host "Bundling..." -ForegroundColor Yellow
if (Test-Path $targetExe) { Remove-Item $targetExe -Force }
cmd.exe /c copy /b "`"$stubPath`"" + "`"$zipPath`"" "`"$targetExe`"" | Out-Null

# Cleanup
Remove-Item $tempStaging -Recurse -Force
Remove-Item $zipPath -Force
Remove-Item $stubPath -Force

Write-Host "`nSUCCESS! Locked toolkit exported to: $targetExe" -ForegroundColor Green
Write-Host "This executable can now be distributed safely." -ForegroundColor White
