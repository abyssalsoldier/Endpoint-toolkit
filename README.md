# Endpoint Toolkit

A powerful, PowerShell-based endpoint onboarding and automation toolkit designed for managed service providers (MSPs). It provides technicians with a unified, responsive WPF interface to efficiently configure, diagnose, and deploy software to Windows client workstations—both on-site via secure USB and remotely via cloud download.

## 🌟 Core Features & How They Work

### 📊 Comprehensive Health Dashboard
The default landing screen is a live, data-rich dashboard that aggregates system metrics in real-time.
*   **How it works:** The UI utilizes background PowerShell runspaces to execute non-blocking WMI/CIM queries, ensuring the WPF interface remains highly responsive while gathering deep system metrics.
*   **Features:**
    *   **Identity & Domain:** Instantly fetches Hostname, Serial Number, OS Build, and Active Directory / Azure AD join status.
    *   **Health Badges:** Evaluates the state of critical services (Windows Defender, Firewall, BitLocker, TPM, SentinelOne, BitDefender) and renders clear color-coded health badges.
    *   **Hardware Telemetry:** Real-time CPU and RAM utilization using visual progress bars, alongside disk health and type detection.
    *   **Network Status:** Surfaces active adapter details, Gateway, and DNS configurations instantly.

### 🔌 Extensible Module System
The toolkit is built on a dynamic, plug-and-play architecture. Modules are automatically discovered and registered simply by dropping a `.ps1` file into the `Modules/` directory with a `Register-*` function. All heavy lifting within modules is passed to background runspaces to keep the UI perfectly fluid.

#### 📦 Unified Software Manager (Winget + Local Installers)
*   **How it works:** This module operates as a hybrid package manager. It dynamically queries Microsoft's `winget` repository alongside a directory of bundled local installers, unifying them into a single installation queue.
*   **Features:** 
    *   Categorized software grids (Browsers, Utilities, Runtimes, etc.).
    *   **JSON Profiles:** Administrators can define per-client `.json` builds that technicians load via a dropdown to automatically check required software.
    *   **Automated Bootstrapping:** Automatically detects and installs the winget framework if the endpoint is missing it.
    *   Batch execution with per-package UI progress tracking.

#### 🖥️ Computer Management & 🌐 Network Diagnostics
*   **Computer Management:** Allows technicians to seamlessly rename the workstation (with a quick-copy button for the hardware serial) and execute domain joins for local AD or Azure AD directly from the toolkit.
*   **Network Diagnostics:** A single-click troubleshooting suite that rapidly validates internet connectivity, DNS resolution, Gateway pings, public DNS bypasses, and DHCP status, returning instantaneous Pass/Fail metrics to quickly isolate breaking points.

### 🛡️ Hardware-Bound USB Portable Mode
For off-grid or low-bandwidth deployments, the toolkit can transform a standard USB flash drive into a secure, self-contained toolkit.
*   **How it works (The Security Deep-Dive):**
    *   When creating the drive, the toolkit dynamically compiles a standalone C# Self-Extracting Executable (SFX) named `EndpointToolkit.exe` that contains the entire toolkit and bundled offline installers.
    *   During compilation, the **physical hardware serial number** of the flash drive's controller chip is hardcoded directly into the executable's source code.
    *   When executed, the SFX verifies the current drive's hardware serial number. If the executable was copied to another device or local drive, the extraction instantly aborts, ensuring the payload remains secure.
    *   Once extraction finishes, the `.exe` detaches and exits immediately. This allows the technician to **pull the USB drive** and plug it into the next computer while the toolkit continues running in memory on the current machine!
*   **Features:** Automated formatting (NTFS, labeled "TOOLKIT"), custom SFX passwords for runtime decryption, and rapid multi-machine onboarding through detached execution.

## 🔒 Zero-Trust Security Model
The toolkit distribution is built under a strict zero-trust philosophy.
*   **Unlocked Base Repository:** The raw repository is completely unlocked and runs frictionless for developers or kit builders. 
*   **Password-Protected SFX Export:** Using `Export-LockedToolkit.ps1`, administrators can compile the current toolkit into a password-protected, encrypted Self-Extracting Executable (SFX). The password generates an AES-256 `.sfx-key` to secure the distributed `.exe`.
*   **Volatile Execution:** The distributed SFX application cleans up after itself. Upon clicking Quit, all temp files, extracted contents, downloaded installers, and active PowerShell sessions are explicitly wiped from memory and disk.

## 🏗️ Architecture & File Structure

```text
endpoint-build-toolkit/
├── Launch.bat                          Entry point (elevates, prioritizes PowerShell 7)
├── dependencies/
│   ├── Invoke-EndpointSetup.ps1        WPF orchestrator & cleanup routine
│   ├── Core/                           Infrastructure (Crypto, Auth, USB Detection)
│   ├── UI/                             XAML layouts and Runspace synchronization
│   ├── Modules/                        Feature Modules (Software, Diagnostics)
│   ├── Profiles/                       JSON templates for client software builds
│   ├── Agent/                          Encrypted configurations and admin tools
│   └── CustomInstallers/               Bundled static installers
└── .github/workflows/release.yml       CI/CD automated release build pipeline
```

## 🚀 Adding New Modules & Profiles

**Creating a Module:**
1. Drop a `.ps1` file into `dependencies/Modules/`.
2. Define a `Register-<Name>` function that returns UI and EntryPoint metadata. 
3. The toolkit handles the rest, automatically registering it and rendering it in the Navigation panel.

**Adding a Client Profile:**
Create a simple JSON array in `dependencies/Profiles/`:
```json
{
    "name": "Standard Build",
    "packages": ["Google.Chrome", "7zip.7zip", "Microsoft.Teams"]
}
```

## ⚙️ Administration & CI/CD
*   **Secure Distribution:** Admin utilities like `Export-LockedToolkit.ps1` package the toolkit into an AES-secured SFX executable, ensuring kits sent to external sites cannot be executed without the password.
*   **Automated Pipelines:** Merging code into the `main` branch triggers a GitHub Action that compiles a lean `.zip` and generates a `SHA-256` checksum for releases.

## 📋 Requirements
*   **OS:** Windows 10 / 11
*   **PowerShell:** v5.1 minimum (v7+ seamlessly preferred)
*   **Privileges:** Local Administrator (toolkit will self-elevate if needed)
*   **Connectivity:** Internet required for winget (unless running in offline USB Portable Mode).