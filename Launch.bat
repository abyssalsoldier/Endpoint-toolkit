@echo off
title Endpoint Toolkit

:: Prefer PowerShell 7 (pwsh) if available, fall back to Windows PowerShell 5.1
where pwsh >nul 2>&1 && (
    start "" pwsh.exe -WindowStyle Hidden -NoProfile -ExecutionPolicy Bypass -File "%~dp0dependencies\Invoke-EndpointSetup.ps1"
    goto :EOF
)

start "" powershell.exe -WindowStyle Hidden -NoProfile -ExecutionPolicy Bypass -File "%~dp0dependencies\Invoke-EndpointSetup.ps1"
