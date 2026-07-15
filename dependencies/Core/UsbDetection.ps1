# Core: UsbDetection.ps1
# USB drive detection and self-update mechanism

function Test-UsbExecution {
    $scriptDrive = Split-Path $script:Toolkit.Root -Qualifier
    $driveLetter = $scriptDrive.TrimEnd(':')

    try {
        $disk = Get-Partition -DriveLetter $driveLetter -ErrorAction SilentlyContinue |
                Get-Disk -ErrorAction SilentlyContinue
        if ($disk -and $disk.BusType -eq 'USB') {
            $script:Toolkit.IsUsb = $true
            $script:Toolkit.UsbDrive = $driveLetter
            return
        }
    } catch { }

    $script:Toolkit.IsUsb = $false
    $script:Toolkit.UsbDrive = $null
}

function Update-UsbToolkit {
    param(
        [string]$UpdateBaseUrl
    )

    if (-not $script:Toolkit.IsUsb) { return }

    $updateUrl = "$UpdateBaseUrl/version.txt"
    $zipUrl    = "$UpdateBaseUrl/latest.zip"

    try {
        $remoteVersion = (Invoke-WebRequest -Uri $updateUrl -UseBasicParsing -TimeoutSec 5).Content.Trim()

        if ($remoteVersion -ne $script:Toolkit.Version) {
            Write-Host ""
            Write-Host "Update available: v$($script:Toolkit.Version) -> v$remoteVersion" -ForegroundColor Yellow
            Write-Host "Update the USB now? (Y/N): " -ForegroundColor Cyan -NoNewline
            $choice = Read-Host

            if ($choice -eq 'Y' -or $choice -eq 'y') {
                Write-Host "Downloading latest toolkit (v$remoteVersion)..." -ForegroundColor Yellow
                $tempZip = "$env:TEMP\endpoint-toolkit-update.zip"
                $tempExtract = "$env:TEMP\endpoint-toolkit-update"

                Invoke-WebRequest -Uri $zipUrl -OutFile $tempZip -UseBasicParsing

                # SHA-256 integrity verification
                $hashUrl = "$UpdateBaseUrl/latest.sha256"
                try {
                    $expectedHash = (Invoke-WebRequest -Uri $hashUrl -UseBasicParsing -TimeoutSec 5).Content.Trim()
                    if ($expectedHash -and $expectedHash.Length -eq 64) {
                        $actualHash = (Get-FileHash -Path $tempZip -Algorithm SHA256).Hash.ToLower()
                        $expectedHash = $expectedHash.ToLower()
                        if ($actualHash -eq $expectedHash) {
                            Write-Host "Download integrity verified (SHA-256 match)." -ForegroundColor Green
                        } else {
                            Write-Host "INTEGRITY CHECK FAILED!" -ForegroundColor Red
                            Write-Host "  Expected: $expectedHash" -ForegroundColor Red
                            Write-Host "  Actual:   $actualHash" -ForegroundColor Red
                            Write-Host "Update aborted. Continuing with USB version (v$($script:Toolkit.Version))." -ForegroundColor Red
                            Remove-Item $tempZip -Force -ErrorAction SilentlyContinue
                            return
                        }
                    } else {
                        Write-Host "Checksum file format unexpected. Skipping verification." -ForegroundColor Yellow
                    }
                } catch {
                    Write-Host "Checksum file not available. Skipping verification." -ForegroundColor Yellow
                }

                # Extract and deploy
                if (Test-Path $tempExtract) { Remove-Item $tempExtract -Recurse -Force }
                Expand-Archive -Path $tempZip -DestinationPath $tempExtract -Force

                $extractedItems = Get-ChildItem $tempExtract
                $sourceDir = if ($extractedItems.Count -eq 1 -and $extractedItems[0].PSIsContainer) {
                    $extractedItems[0].FullName
                } else {
                    $tempExtract
                }

                $robocopyArgs = @(
                    "`"$sourceDir`"",
                    "`"$($script:Toolkit.Parent)`"",
                    "/MIR",
                    "/XD", ".git", ".github", ".claude", ".vscode", "Installers", "_builds",
                    "/XF", ".gitignore", ".toolkit-key", "toolkit-config.json", "clients.csv", "build.ps1",
                    "/NFL", "/NDL", "/NJH", "/NJS",
                    "/R:2", "/W:1"
                )
                Start-Process robocopy -ArgumentList $robocopyArgs -Wait -NoNewWindow

                Remove-Item $tempZip -Force -ErrorAction SilentlyContinue
                Remove-Item $tempExtract -Recurse -Force -ErrorAction SilentlyContinue

                Write-Host "USB updated to v$remoteVersion. Relaunching..." -ForegroundColor Green

                $updatedScript = Join-Path $script:Toolkit.Root "Invoke-EndpointSetup.ps1"
                if (Test-Path $updatedScript) {
                    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$updatedScript`"" -Verb RunAs
                    exit
                }
            }
        } else {
            Write-Host "USB toolkit is up to date (v$($script:Toolkit.Version))." -ForegroundColor Green
        }
    } catch {
        Write-Host "Offline or update check failed. Continuing with USB version (v$($script:Toolkit.Version))..." -ForegroundColor Yellow
    }
}
