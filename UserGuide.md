# Endpoint Toolkit - User Guide

**⚠️ Important Restrictions Regarding USB Usage:**
* **Do not manually install to USB:** The toolkit program itself should not be manually copied or installed onto a USB drive. You must use the toolkit's built-in **USB Toolkit** builder to create a functional portable drive.
* **Hardware Binding:** Because the offline authentication is cryptographically bound to the physical USB drive's hardware serial number, copying the files from a working USB drive to any other device, local computer, or another flash drive **will not work**.

Welcome to the Endpoint Toolkit. This toolkit is a PowerShell-based endpoint onboarding automation utility designed for technicians to efficiently set up and configure Windows client workstations, whether on-site or remotely.

## Getting Started

1. **Launch the Toolkit:** Run the `Launch.bat` file as an Administrator. (If you don't run it as Administrator, the toolkit will prompt and attempt to relaunch itself with the necessary privileges).
2. **Authentication:** Upon launch, you will be prompted for a password (the password can be located by searching "Endpoint" in 1Password). You have up to 3 attempts. Successfully authenticating unlocks auth-gated features like USB Toolkit creation. You can choose to "Skip", but restricted features will remain locked.
3. **Navigation:** The toolkit interface consists of three main panels:
   - **Navigation Panel (Left):** Select modules to use, build a USB Toolkit, view the Session Report, or Quit.
   - **Action Panel (Center):** Displays the active module's interface (defaults to the Dashboard).
   - **Log Panel (Bottom):** Shows live, color-coded execution logs and timestamps. You can resize this panel.

---

## Features and Modules

### Dashboard (Default View)
The Dashboard provides an immediate, comprehensive overview of the endpoint's current state:
* **Identity:** Hostname, Serial Number, Manufacturer/Model, OS Version/Build, and Domain status.
* **Health Badges:** Quick color-coded indicators (Green = Good, Red = Issue, Yellow = Warning, Gray = Unknown/Inactive) for Windows Defender, Firewall, BitLocker, TPM, SentinelOne, BitDefender, and Pending Reboots.
* **Hardware:** CPU and RAM usage (with visual progress bars), disk usage, health, and type.
* **Network:** Active network adapter details, IP Address, Gateway, DNS, and Azure AD join status.
* **Refresh Button:** Re-check and update all dashboard data (useful after running installations or fixes).

### Software Manager
A unified software installer that pulls packages from Windows Package Manager (winget) and local bundled installers.
* **Categorized Selection:** Browse and select software via a checkbox grid categorized into Browsers, Productivity, Communication, Runtimes, and Utilities.
* **Client Profiles:** Load per-client JSON profiles from a dropdown menu to auto-populate the necessary checkboxes for standardized builds.
* **Batch Install:** Install multiple selected packages sequentially with individual progress tracking. It will automatically bootstrap `winget` if it is missing from the system.

### Computer Management
Simplifies renaming the workstation and joining it to a domain.
* **Rename Computer:** Displays the current computer name alongside the hardware serial number (with a convenient copy button) to easily standardize names.
* **Domain Join:** Allows joining to a local Active Directory (providing domain, username, and password fields) or Azure AD (by launching the native Windows system settings).
* *Note: Does not require toolkit authentication.*

### Network Diagnostics
One-click troubleshooting for network connectivity issues.
* **Automated Checks:** Tests internet connectivity, DNS resolution, Gateway ping, DNS server ping, public DNS bypass, and DHCP status.
* **Clear Results:** Provides straightforward Pass/Fail indicators for each test to quickly identify the breaking point in the network chain.
* *Note: Does not require toolkit authentication.*

### Client Templates
*Placeholder feature - Coming in a future release.* Will allow the application of broader client-specific software and configuration templates.

---

## Advanced Usage

### USB Portable Mode (USB Toolkit)
The USB Toolkit feature allows technicians to build a secure, portable, offline version of the toolkit for use at client sites with limited or no internet access.

**How to build:**
1. Insert a USB drive.
2. Select the **USB Toolkit** button in the left navigation panel.
3. Use **Prepare Drive** to format the drive to NTFS and label it "TOOLKIT".
4. Input your custom password into the **USB Toolkit Password (Required)** field.
5. The module will package the toolkit and all bundled installers into a single `EndpointToolkit.exe` file on your USB drive.

**Using the USB Toolkit:**
1. Plug the USB drive into a client computer and double-click `EndpointToolkit.exe`.
2. **Hardware-Bound Protection:** The executable will verify that it is running from the original authorized USB drive. If copied elsewhere, it will refuse to run.
3. **Detached Execution:** Once the `.exe` extracts the payload to the local temporary folder, it will launch the toolkit and the `.exe` will immediately close itself. **You can safely unplug the USB drive at this point and move to the next computer!**
4. Enter your custom password into the GUI prompt to decrypt the toolkit and unlock its features.

---

## Security and Cleanup
The Endpoint Toolkit is designed with security in mind:
* **No Persistent Data:** All temporary files and injected credentials are automatically wiped from the endpoint when the toolkit is closed.
* **Hidden Credentials:** Admin credentials are AES-256 encrypted and are never displayed within the UI. 

Always ensure you close the toolkit properly using the **Quit** button to allow the cleanup processes to complete successfully.