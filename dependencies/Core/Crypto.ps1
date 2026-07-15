# Module: Crypto.ps1

function Unprotect-ToolkitConfig {
    param(
        [string]$Password,
        [string]$EncPath
    )

    if (-not (Test-Path $EncPath)) {
        throw "Encrypted config not found at '$EncPath'."
    }

    $payload = [Convert]::FromBase64String((Get-Content $EncPath -Raw).Trim())

    # File format: [16 bytes salt][16 bytes IV][ciphertext]
    $salt = $payload[0..15]
    $iv = $payload[16..31]
    $ciphertext = $payload[32..($payload.Length - 1)]

    # Derive AES key from password via PBKDF2
    $derive = New-Object System.Security.Cryptography.Rfc2898DeriveBytes($Password, $salt, 100000, "SHA256")
    $aesKey = $derive.GetBytes(32)

    $aes = [System.Security.Cryptography.Aes]::Create()
    $aes.Key = $aesKey
    $aes.IV = $iv
    $decryptor = $aes.CreateDecryptor()
    $plainBytes = $decryptor.TransformFinalBlock($ciphertext, 0, $ciphertext.Length)
    $aes.Dispose()

    $json = [System.Text.Encoding]::UTF8.GetString($plainBytes)
    return ($json | ConvertFrom-Json)
}

function Get-DriveSerial {
    param([string]$DriveLetter)
    try {
        $partition = Get-Partition -DriveLetter $DriveLetter -ErrorAction SilentlyContinue
        $disk = $partition | Get-Disk -ErrorAction SilentlyContinue
        if ($disk.SerialNumber) { return $disk.SerialNumber.Trim() }
    } catch { }
    return $null
}

function Protect-CachedPassword {
    param([string]$Password, [string]$DriveSerial, [string]$UserPassword = '')
    $salt = [System.Text.Encoding]::UTF8.GetBytes("ToolkitUSB:$DriveSerial")
    $deriveStr = "USBBind:$DriveSerial"
    if ($UserPassword) { $deriveStr += ":$UserPassword" }
    $derive = New-Object System.Security.Cryptography.Rfc2898DeriveBytes($deriveStr, $salt, 50000, "SHA256")
    $key = $derive.GetBytes(32)
    $aes = [System.Security.Cryptography.Aes]::Create()
    $aes.Key = $key
    $aes.GenerateIV()
    $enc = $aes.CreateEncryptor()
    $plainBytes = [System.Text.Encoding]::UTF8.GetBytes($Password)
    $encBytes = $enc.TransformFinalBlock($plainBytes, 0, $plainBytes.Length)
    $payload = New-Object byte[] ($aes.IV.Length + $encBytes.Length)
    [Array]::Copy($aes.IV, 0, $payload, 0, $aes.IV.Length)
    [Array]::Copy($encBytes, 0, $payload, $aes.IV.Length, $encBytes.Length)
    $aes.Dispose()
    return [Convert]::ToBase64String($payload)
}

function Unprotect-CachedPassword {
    param([string]$EncryptedData, [string]$DriveSerial, [string]$UserPassword = '')
    $salt = [System.Text.Encoding]::UTF8.GetBytes("ToolkitUSB:$DriveSerial")
    $deriveStr = "USBBind:$DriveSerial"
    if ($UserPassword) { $deriveStr += ":$UserPassword" }
    $derive = New-Object System.Security.Cryptography.Rfc2898DeriveBytes($deriveStr, $salt, 50000, "SHA256")
    $key = $derive.GetBytes(32)
    $payload = [Convert]::FromBase64String($EncryptedData)
    $iv = $payload[0..15]
    $ciphertext = $payload[16..($payload.Length - 1)]
    $aes = [System.Security.Cryptography.Aes]::Create()
    $aes.Key = $key
    $aes.IV = $iv
    $dec = $aes.CreateDecryptor()
    $plainBytes = $dec.TransformFinalBlock($ciphertext, 0, $ciphertext.Length)
    $aes.Dispose()
    return [System.Text.Encoding]::UTF8.GetString($plainBytes)
}

function Protect-SfxPassword {
    param([string]$MainToolkitKey, [string]$SfxPassword)
    $salt = [System.Text.Encoding]::UTF8.GetBytes("ToolkitSFX:$SfxPassword")
    $deriveStr = "SFXBind:$SfxPassword"
    $derive = New-Object System.Security.Cryptography.Rfc2898DeriveBytes($deriveStr, $salt, 50000, "SHA256")
    $key = $derive.GetBytes(32)
    $aes = [System.Security.Cryptography.Aes]::Create()
    $aes.Key = $key
    $aes.GenerateIV()
    $enc = $aes.CreateEncryptor()
    $plainBytes = [System.Text.Encoding]::UTF8.GetBytes($MainToolkitKey)
    $encBytes = $enc.TransformFinalBlock($plainBytes, 0, $plainBytes.Length)
    $payload = New-Object byte[] ($aes.IV.Length + $encBytes.Length)
    [Array]::Copy($aes.IV, 0, $payload, 0, $aes.IV.Length)
    [Array]::Copy($encBytes, 0, $payload, $aes.IV.Length, $encBytes.Length)
    $aes.Dispose()
    return [Convert]::ToBase64String($payload)
}

function Unprotect-SfxPassword {
    param([string]$EncryptedData, [string]$SfxPassword)
    $salt = [System.Text.Encoding]::UTF8.GetBytes("ToolkitSFX:$SfxPassword")
    $deriveStr = "SFXBind:$SfxPassword"
    $derive = New-Object System.Security.Cryptography.Rfc2898DeriveBytes($deriveStr, $salt, 50000, "SHA256")
    $key = $derive.GetBytes(32)
    $payload = [Convert]::FromBase64String($EncryptedData)
    $iv = $payload[0..15]
    $ciphertext = $payload[16..($payload.Length - 1)]
    $aes = [System.Security.Cryptography.Aes]::Create()
    $aes.Key = $key
    $aes.IV = $iv
    $dec = $aes.CreateDecryptor()
    $plainBytes = $dec.TransformFinalBlock($ciphertext, 0, $ciphertext.Length)
    $aes.Dispose()
    return [System.Text.Encoding]::UTF8.GetString($plainBytes)
}
