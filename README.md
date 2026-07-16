# Endpoint Toolkit Architecture

A powerful, PowerShell-based endpoint onboarding and automation toolkit designed for managed service providers (MSPs). This document outlines the technical architecture, security mechanisms, and extensibility of the toolkit. For step-by-step instructions on *using* the toolkit, please see the [User Guide](UserGuide.md).

## 🏗️ Core Architecture & UI

### WPF & PowerShell Runspaces
The toolkit interface is built using Windows Presentation Foundation (WPF) rendered entirely via PowerShell. To prevent the UI thread from freezing during long-running tasks (like software installations or WMI queries), the toolkit employs an advanced asynchronous **Runspace Architecture**:
*   **Synchronized State:** A global thread-safe synchronized hash table (`$Global:SyncHash`) is used to pass data seamlessly between the background runspaces and the primary UI thread.
*   **Non-Blocking Execution:** Heavy tasks (e.g., retrieving system metrics, polling Winget, joining domains) are dispatched to independent runspaces. When complete, a dispatcher invokes updates directly back to the WPF UI controls, keeping the dashboard highly responsive.

### Extensible Module System
The toolkit is built on a dynamic, plug-and-play architecture:
*   **Auto-Discovery:** Modules are automatically discovered and registered by dropping a `.ps1` file into the `dependencies/Modules/` directory.
*   **Registration:** Modules must expose a `Register-<Name>` function returning a hash table with `Name`, `Label`, `RequiresAuth`, `EntryPoint`, and `UIDefinition`. The core orchestrator dynamically builds the navigation menu based on these functions.

## 🔒 Zero-Trust Security & Distribution

The toolkit handles sensitive environment access, so the entire repository and execution lifecycle is built under a strict zero-trust philosophy.

### Unlocked Base Repository
The raw repository code (in `dependencies/`) contains no hardcoded credentials, API keys, or client data. When run locally via `Launch.bat`, the base toolkit launches completely unlocked. This ensures a frictionless experience for developers and kit builders.

### Password-Protected SFX Export
For external deployment, the toolkit can be securely compiled using `Export-LockedToolkit.ps1`. 
*   **Compilation:** The script copies the raw toolkit into a temporary folder, prompts the admin for a distribution password, and generates an AES-256 encrypted `.sfx-key`. 
*   **Stub Injection:** It compiles a standalone C# Self-Extracting Executable (SFX) on the fly and binds the zip payload to it.
*   **Execution:** When run on a client machine, the SFX demands the correct password to decrypt the `.sfx-key` before allowing access.

### Hardware-Bound USB Portable Mode
For off-grid environments, the toolkit can transform a standard USB flash drive into a secure, self-contained payload via the `Setup-UsbToolkit` module.
*   **Hardware Binding:** During compilation, the toolkit queries WMI to retrieve the physical hardware serial number of the USB drive's controller chip. This serial is injected directly into the C# SFX source code before compiling.
*   **Anti-Tampering:** When executed on an endpoint, the SFX verifies the current drive's hardware serial against the hardcoded hash. If the `.exe` was copied to a local drive or a different USB stick, extraction instantly aborts.

### Volatile Execution & Cleanup
Whether executing from a distributed SFX `.exe` or a USB drive, the toolkit strictly enforces ephemeral execution:
1.  **Extraction:** Payloads are extracted silently to a randomized folder in the Windows `%TEMP%` directory.
2.  **Detached Execution:** Once the payload launches, the `.exe` detaches and exits immediately. (For USBs, this allows the technician to pull the drive and move to the next PC while the toolkit remains running in memory).
3.  **Wipe:** Upon clicking the **Quit** button in the UI, a cleanup routine explicitly wipes all temporary folders, downloaded installers, decrypted keys, and active PowerShell sessions from memory and disk.

## 📂 File Structure

```text
endpoint-build-toolkit/
├── Launch.bat                          Entry point (elevates, prioritizes PowerShell 7)
├── dependencies/
│   ├── Invoke-EndpointSetup.ps1        WPF orchestrator & cleanup routine
│   ├── Core/                           Infrastructure (Crypto, Auth, USB Detection)
│   ├── UI/                             XAML layouts and Runspace synchronization
│   ├── Modules/                        Feature Modules (Software, Diagnostics)
│   ├── Profiles/                       JSON templates for client software builds
│   ├── Agent/                          Admin tools (e.g., Export-LockedToolkit.ps1)
│   └── CustomInstallers/               Bundled static offline installers
```

## ⚙️ Administration & Requirements

### Automated Software Provisioning
The `Install-Software` module acts as a hybrid package manager. It dynamically queries Microsoft's `winget` repository alongside the `CustomInstallers/` directory. If `winget` is missing from the target endpoint, the toolkit will automatically bootstrap and install it before proceeding.

### Requirements
*   **OS:** Windows 10 / 11
*   **PowerShell:** v5.1 minimum (v7+ natively preferred by Launch.bat)
*   **Privileges:** Local Administrator (toolkit will prompt to self-elevate)
*   **Connectivity:** Internet required for winget (unless running fully cached in USB Portable Mode).