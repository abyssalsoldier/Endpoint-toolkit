# Endpoint Toolkit - Technician Manual

Welcome to the Endpoint Toolkit. This manual provides step-by-step instructions for technicians to efficiently set up, configure, and onboard Windows client workstations.

## 🚀 Getting Started

1. **Launch the Toolkit:** Double-click the `Launch.bat` file.
   * If you are running the local base repository, it will open instantly.
   * If you are running a distributed `.exe` or a USB portable toolkit, you will be prompted for a password. You have up to 3 attempts. Successfully authenticating unlocks the toolkit and its features.
2. **Navigation:** The toolkit interface consists of three main panels:
   * **Navigation Panel (Left):** Select modules to use (Dashboard, Software Manager, etc.), build a USB Toolkit, view the Session Report, or Quit.
   * **Action Panel (Center):** Displays the active module's interface (defaults to the Dashboard).
   * **Log Panel (Bottom):** Shows live execution logs. You can click and drag to resize this panel.

---

## 🛠️ Using the Modules

### 📊 Dashboard
The Dashboard provides an immediate, comprehensive overview of the endpoint's current state.
* **Review Health Badges:** Quickly scan the color-coded indicators for Windows Defender, Firewall, BitLocker, TPM, SentinelOne, and BitDefender.
    * 🟢 **Green:** Healthy / Active
    * 🔴 **Red:** Issue / Disabled
    * 🟡 **Yellow:** Warning (e.g. pending reboot)
    * ⚪ **Gray:** Unknown or Not Installed
* **Check Resources:** Monitor live CPU and RAM usage via the visual progress bars.
* **Refresh Data:** After running installations or fixes in other modules, click the **Refresh** button at the top to re-poll all system data.

### 📦 Software Manager
A unified software installer that pulls packages from Winget and local bundled installers.
1. **Load a Profile:** Click the **Client Profile** dropdown menu. Select a client's JSON profile to automatically check all software required for their standard build.
2. **Manual Selection:** Browse the categorized grids (Browsers, Productivity, etc.) and check/uncheck software manually as needed.
3. **Execute:** Click **Install Selected Software**. The toolkit will batch install everything sequentially, providing progress updates in the log panel. If Winget is missing on the machine, it will automatically install it first.

### 🖥️ Computer Management
Simplifies renaming the workstation and joining it to a domain.
* **Copy Serial Number:** Your current computer name and hardware serial number are displayed. Click the **Copy** button next to the serial number to quickly copy it to your clipboard for asset tracking.
* **Rename Computer:** Type a new name into the field and click **Rename**. (Requires a reboot to take effect).
* **Join Local Domain:** Enter the target Domain Name, along with your admin Username and Password, and click **Join Domain**. (Requires a reboot).
* **Join Azure AD (Entra ID):** Click the **Open Azure AD Join Screen** button. This instantly launches the native Windows "Access work or school" settings panel so you can complete the Entra join process.

### 🌐 Network Diagnostics
One-click troubleshooting for network connectivity issues.
* **Run Diagnostics:** Click the **Start Diagnostics** button. The toolkit will systematically test local connectivity, DNS resolution, Gateway ping, and DHCP status.
* **Review Results:** Each test provides a straightforward Pass/Fail indicator. If the "DNS Server Ping" fails but the "Public DNS Ping (1.1.1.1)" passes, you instantly know it's a local DNS issue and not an internet outage.

---

## 🔒 Advanced Distribution

### 📤 Exporting a Standalone Toolkit (For Remote Clients)
You can package your toolkit into a secure, password-protected executable (`.exe`) to email or send to external sites.
1. Open a PowerShell console as Administrator.
2. Run the export script: `.\dependencies\Agent\Export-LockedToolkit.ps1`
3. Enter a custom password when prompted (the recipient will need this password).
4. Provide an output path (e.g., `C:\Users\Public\Desktop`).
5. The script will bundle the entire toolkit and compile it into `EndpointToolkit_Locked.exe`.

### 💾 Building a USB Portable Toolkit (For Offline Sites)
The USB Toolkit allows you to build a secure, portable, offline version for client sites with zero internet access.
1. Insert a USB flash drive.
2. Click the **USB Toolkit** button in the left navigation panel.
3. Click **Prepare Drive** to automatically format the drive to NTFS and label it "TOOLKIT".
4. Input your custom password into the **USB Toolkit Password** field.
5. Click **Build USB Toolkit**. The module will package the toolkit and all local installers into an `EndpointToolkit.exe` file on your USB drive.

**Using the USB Toolkit:**
1. Plug the USB drive into a client computer and double-click `EndpointToolkit.exe`.
2. The executable will verify it is running from the original authorized USB drive.
3. Once it extracts, the `.exe` will close immediately. **You can safely unplug the USB drive at this point and move to the next computer!**
4. Enter your custom password to decrypt the toolkit and unlock its features.

---

## 🧹 Proper Cleanup
* **Always use the Quit button:** When you are finished, click the **Quit** button in the bottom-left corner of the navigation panel.
* This explicitly triggers the Zero-Trust cleanup routines, wiping all temporary files, extracted contents, and session data from the endpoint. Do not simply click the "X" in the top right corner.