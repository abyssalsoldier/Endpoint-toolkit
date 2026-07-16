# Core: Authentication.ps1
# Console-based toolkit authentication (password prompt, USB cache, config decryption)

function Initialize-ToolkitAuth {
    $sfxKeyPath = Join-Path $script:Toolkit.Parent ".sfx-key"
    $cachedKeyPath = Join-Path $script:Toolkit.Parent ".toolkit-key"
    $isSfx = Test-Path $sfxKeyPath
    $hasUsbCache = Test-Path $cachedKeyPath

    # If this is the base toolkit folder (not an exported SFX and not a cached USB)
    if (-not $isSfx -and -not ($script:Toolkit.IsUsb -and $hasUsbCache)) {
        Write-Host "Base Toolkit Mode - Running Unlocked" -ForegroundColor Green
        $script:Toolkit.Authenticated = $true
        $script:ToolkitKey = "unlocked"
        return
    }

    # Console password prompt (up to 3 attempts)
    $authAttempts = 0
    while (-not $script:Toolkit.Authenticated -and $authAttempts -lt 3) {
        $authAttempts++
        Write-Host ""

        if ($isSfx) {
            Write-Host "Enter Toolkit Password (attempt $authAttempts/3, or press Enter to skip): " -ForegroundColor Cyan -NoNewline
        } elseif ($script:Toolkit.IsUsb) {
            Write-Host "Enter USB Toolkit Password (attempt $authAttempts/3, or press Enter to skip): " -ForegroundColor Cyan -NoNewline
        }
        
        $securePass = Read-Host -AsSecureString
        $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePass)
        $enteredKey = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)

        if ([string]::IsNullOrWhiteSpace($enteredKey)) {
            Write-Host "Authentication skipped. Toolkit will be locked." -ForegroundColor Yellow
            return
        }

        $mainKeyToUse = $enteredKey
        $isValid = $false
        $usbUnlocked = $false

        if ($isSfx) {
            try {
                $encryptedCache = (Get-Content $sfxKeyPath -Raw).Trim()
                # Verify we can decrypt the main toolkit key stored inside .sfx-key
                $mainKeyToUse = Unprotect-SfxPassword -EncryptedData $encryptedCache -SfxPassword $enteredKey
                if ($mainKeyToUse) { $isValid = $true }
            } catch {
                # Decryption of the SFX key failed
            }
        } elseif ($script:Toolkit.IsUsb -and $hasUsbCache) {
            try {
                $driveLetter = $script:Toolkit.UsbDrive
                $usbSerial = Get-DriveSerial -DriveLetter $driveLetter
                if ($usbSerial) {
                    $encryptedCache = (Get-Content $cachedKeyPath -Raw).Trim()
                    $mainKeyToUse = Unprotect-CachedPassword -EncryptedData $encryptedCache -DriveSerial $usbSerial -UserPassword $enteredKey
                    if ($mainKeyToUse) { 
                        $isValid = $true
                        $usbUnlocked = $true
                    }
                }
            } catch {
                # Decryption of the cached key failed.
            }
        }

        if ($isValid) {
            $script:Toolkit.Authenticated = $true
            $script:ToolkitKey = $mainKeyToUse
            Write-Host "Authentication successful." -ForegroundColor Green

            # Automatically delete the SFX key from memory/disk once unlocked
            if ($isSfx) {
                Remove-Item $sfxKeyPath -Force -ErrorAction SilentlyContinue
            }
        } else {
            $remaining = 3 - $authAttempts
            if ($remaining -gt 0) {
                Write-Host "Invalid password. $remaining attempt(s) remaining." -ForegroundColor Red
            } else {
                Write-Host "Authentication failed after 3 attempts." -ForegroundColor Red
            }
        }
    }
}
