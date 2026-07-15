# Core: Authentication.ps1
# Console-based toolkit authentication (password prompt, USB cache, config decryption)

function Initialize-ToolkitAuth {
    $configEncPath = Join-Path $script:Toolkit.Root "Agent\config.enc"

    # Check if config.enc exists
    if (-not (Test-Path $configEncPath)) {
        Write-Host "WARNING: config.enc not found. Authenticated features will be unavailable." -ForegroundColor Yellow
        return
    }

    # Console password prompt (up to 3 attempts)
    $authAttempts = 0
    while (-not $script:Toolkit.Authenticated -and $authAttempts -lt 3) {
        $authAttempts++
        Write-Host ""
        $sfxKeyPath = Join-Path $script:Toolkit.Parent ".sfx-key"
        $isSfx = Test-Path $sfxKeyPath

        if ($isSfx) {
            Write-Host "Enter SFX toolkit password (attempt $authAttempts/3, or press Enter to skip): " -ForegroundColor Cyan -NoNewline
        } elseif ($script:Toolkit.IsUsb) {
            Write-Host "Enter USB toolkit password (attempt $authAttempts/3, or press Enter to skip): " -ForegroundColor Cyan -NoNewline
        } else {
            Write-Host "Enter toolkit password (attempt $authAttempts/3, or press Enter to skip): " -ForegroundColor Cyan -NoNewline
        }
        $securePass = Read-Host -AsSecureString

        # Convert SecureString to plain text
        $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePass)
        $enteredKey = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)

        if ([string]::IsNullOrWhiteSpace($enteredKey)) {
            Write-Host "Authentication skipped. Some features will be unavailable." -ForegroundColor Yellow
            return
        }

        $mainKeyToUse = $enteredKey
        $usbUnlocked = $false

        if ($isSfx) {
            try {
                $encryptedCache = (Get-Content $sfxKeyPath -Raw).Trim()
                $mainKeyToUse = Unprotect-SfxPassword -EncryptedData $encryptedCache -SfxPassword $enteredKey
                $usbUnlocked = $true
            } catch {
                # Decryption of the SFX key failed
            }
        } elseif ($script:Toolkit.IsUsb) {
            $cachedKeyPath = Join-Path $script:Toolkit.Parent ".toolkit-key"
            if (Test-Path $cachedKeyPath) {
                try {
                    $driveLetter = $script:Toolkit.UsbDrive
                    $usbSerial = Get-DriveSerial -DriveLetter $driveLetter
                    if ($usbSerial) {
                        $encryptedCache = (Get-Content $cachedKeyPath -Raw).Trim()
                        $mainKeyToUse = Unprotect-CachedPassword -EncryptedData $encryptedCache -DriveSerial $usbSerial -UserPassword $enteredKey
                        $usbUnlocked = $true
                    }
                } catch {
                    # Decryption of the cached key failed. We will fall through and try the entered key directly on the config.
                }
            }
        }

        try {
            $script:Toolkit.Config = Unprotect-ToolkitConfig -Password $mainKeyToUse -EncPath $configEncPath
            $script:Toolkit.Authenticated = $true
            $script:ToolkitKey = $mainKeyToUse
            Write-Host "Authentication successful." -ForegroundColor Green

            if ($isSfx) {
                Remove-Item $sfxKeyPath -Force -ErrorAction SilentlyContinue
            }

            # If on USB and we didn't unlock via a valid USB cache, offer to cache it
            if ($script:Toolkit.IsUsb -and -not $usbUnlocked) {
                Write-Host "Update the saved password on this USB? (Y/N): " -ForegroundColor Cyan -NoNewline
                $updateCache = Read-Host
                if ($updateCache -eq 'Y' -or $updateCache -eq 'y') {
                    $driveLetter = $script:Toolkit.UsbDrive
                    $usbSerial = Get-DriveSerial -DriveLetter $driveLetter
                    if ($usbSerial) {
                        $cachedKeyPath = Join-Path $script:Toolkit.Parent ".toolkit-key"
                        $encrypted = Protect-CachedPassword -Password $mainKeyToUse -DriveSerial $usbSerial
                        Set-Content -Path $cachedKeyPath -Value $encrypted -NoNewline -Force
                        (Get-Item $cachedKeyPath -Force).Attributes = 'Hidden'
                        Write-Host "USB password cache updated." -ForegroundColor Green
                    }
                }
            }
        } catch {
            $remaining = 3 - $authAttempts
            if ($remaining -gt 0) {
                Write-Host "Invalid password. $remaining attempt(s) remaining." -ForegroundColor Red
            } else {
                Write-Host "Authentication failed after 3 attempts. Some features will be unavailable." -ForegroundColor Red
            }
        }
    }
}
