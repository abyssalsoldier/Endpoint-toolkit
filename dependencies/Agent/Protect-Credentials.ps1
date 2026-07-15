# Protect-Credentials.ps1
# Admin-only utility to manage the encrypted toolkit configuration.
# This script is NOT used by techs - it is run by the repo owner to:
#   1. Set a human-readable toolkit password (stored in 1Password for techs)
#   2. Create config.enc to verify passwords.
#
# Usage:
#   .\Protect-Credentials.ps1
#
# Output:
#   - config.enc : encrypted blob (commit this to git - safe without the password)

$ErrorActionPreference = "Stop"
$scriptDir = $PSScriptRoot

$configJsonPath = Join-Path $scriptDir "toolkit-config.json"
$clientsCsvPath = Join-Path $scriptDir "clients.csv"
$encPath        = Join-Path $scriptDir "config.enc"

function ConvertTo-AesKey {
    param([string]$Password, [byte[]]$Salt)
    $derive = New-Object System.Security.Cryptography.Rfc2898DeriveBytes($Password, $Salt, 100000, "SHA256")
    return $derive.GetBytes(32)
}

function Protect-ConfigData {
    param([string]$Password)

    $config = [PSCustomObject]@{
        auth = "success"
    }

    $jsonPayload = $config | ConvertTo-Json -Depth 5 -Compress

    # --- Derive AES key from password via PBKDF2 ---
    $salt = New-Object byte[] 16
    [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($salt)
    $aesKey = ConvertTo-AesKey -Password $Password -Salt $salt

    # --- AES-256-CBC encryption ---
    $aes = [System.Security.Cryptography.Aes]::Create()
    $aes.Key = $aesKey
    $aes.GenerateIV()
    $encryptor = $aes.CreateEncryptor()

    $plainBytes = [System.Text.Encoding]::UTF8.GetBytes($jsonPayload)
    $encBytes = $encryptor.TransformFinalBlock($plainBytes, 0, $plainBytes.Length)

    # File format: [16 bytes salt][16 bytes IV][ciphertext]
    $payload = New-Object byte[] ($salt.Length + $aes.IV.Length + $encBytes.Length)
    [Array]::Copy($salt, 0, $payload, 0, $salt.Length)
    [Array]::Copy($aes.IV, 0, $payload, $salt.Length, $aes.IV.Length)
    [Array]::Copy($encBytes, 0, $payload, $salt.Length + $aes.IV.Length, $encBytes.Length)

    $base64Payload = [Convert]::ToBase64String($payload)
    Set-Content -Path $encPath -Value $base64Payload -NoNewline

    $aes.Dispose()

    Write-Host "Encrypted config saved to: $encPath" -ForegroundColor Green
    return $true
}

# --- Main ---

Write-Host "=== Toolkit Configuration Encryption Utility ===" -ForegroundColor Cyan
Write-Host ""

# Prompt for password
$password1 = Read-Host "Enter the toolkit password (what techs will type)" -AsSecureString
$password2 = Read-Host "Confirm the toolkit password" -AsSecureString

$plain1 = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($password1))
$plain2 = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($password2))

if ($plain1 -ne $plain2) {
    Write-Host "ERROR: Passwords do not match." -ForegroundColor Red
    exit 1
}
if ($plain1.Length -lt 4) {
    Write-Host "ERROR: Password must be at least 4 characters." -ForegroundColor Red
    exit 1
}

Write-Host ""
$result = Protect-ConfigData -Password $plain1

# Clear password from memory
$plain1 = $null
$plain2 = $null

if ($result) {
    Write-Host ""
    Write-Host "=== Done ===" -ForegroundColor Cyan
    Write-Host "Output:"
    Write-Host "  - $encPath (encrypted config - commit this to git)" -ForegroundColor White
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Yellow
    Write-Host "  1. Commit config.enc to git" -ForegroundColor White
    Write-Host "  2. Store the toolkit password in 1Password for the tech team" -ForegroundColor White
    Write-Host "  3. To change the password later, just re-run this script" -ForegroundColor White
} else {
    Write-Host "`nEncryption failed. See errors above." -ForegroundColor Red
    exit 1
}
