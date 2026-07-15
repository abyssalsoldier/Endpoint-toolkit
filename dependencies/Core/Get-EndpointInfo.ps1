# Core: Get-EndpointInfo.ps1
# Data-gathering functions for the endpoint dashboard (no UI code)

function Get-EndpointIdentity {
    $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue
    $bios = Get-CimInstance Win32_BIOS -ErrorAction SilentlyContinue
    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
    $ntVer = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction SilentlyContinue

    # Get Device Join Status via dsregcmd
    $azureJoined = $false
    $domainJoined = $false
    try {
        $dsreg = dsregcmd /status 2>$null
        $azureJoined = [bool]($dsreg -match 'AzureAdJoined\s*:\s*YES')
        $domainJoined = [bool]($dsreg -match 'DomainJoined\s*:\s*YES')
    } catch {}

    $joinType = "Local (Standalone)"
    if ($azureJoined -and $domainJoined) { $joinType = "Hybrid Joined (AD + Azure AD)" }
    elseif ($azureJoined) { $joinType = "Azure AD Joined" }
    elseif ($domainJoined) { $joinType = "Active Directory Domain Joined" }

    @{
        Hostname     = $env:COMPUTERNAME
        Serial       = if ($bios.SerialNumber) { $bios.SerialNumber.Trim() } else { 'N/A' }
        Manufacturer = if ($cs.Manufacturer) { $cs.Manufacturer.Trim() } else { 'Unknown' }
        Model        = if ($cs.Model) { $cs.Model.Trim() } else { 'Unknown' }
        OSCaption    = if ($os.Caption) { $os.Caption } else { 'Unknown' }
        OSVersion    = if ($ntVer.DisplayVersion) { $ntVer.DisplayVersion } else { 'N/A' }
        OSBuild      = if ($os.BuildNumber) { $os.BuildNumber } else { 'N/A' }
        Domain       = if ($cs.PartOfDomain) { $cs.Domain } else { $cs.Workgroup + ' (Workgroup)' }
        JoinType     = $joinType
    }
}

function Get-EndpointHealth {
    $health = @{}

    # Windows Defender
    try {
        $mp = Get-MpComputerStatus -ErrorAction Stop
        $health.Defender = if ($mp.RealTimeProtectionEnabled) { 'ON' } else { 'OFF' }
        $health.DefenderOk = $mp.RealTimeProtectionEnabled
    } catch {
        $health.Defender = 'N/A'
        $health.DefenderOk = $false
    }

    # Firewall
    try {
        $fw = Get-NetFirewallProfile -ErrorAction Stop
        $allOn = ($fw | Where-Object { -not $_.Enabled }).Count -eq 0
        $health.Firewall = if ($allOn) { 'ON' } else { 'PARTIAL' }
        $health.FirewallOk = $allOn
    } catch {
        $health.Firewall = 'N/A'
        $health.FirewallOk = $false
    }

    # BitLocker
    try {
        $bl = Get-BitLockerVolume -MountPoint 'C:' -ErrorAction Stop
        $health.BitLocker = if ($bl.ProtectionStatus -eq 'On') { 'ON' } else { 'OFF' }
        $health.BitLockerOk = $bl.ProtectionStatus -eq 'On'
    } catch {
        $health.BitLocker = 'N/A'
        $health.BitLockerOk = $false
    }

    # TPM
    try {
        $tpm = Get-Tpm -ErrorAction Stop
        if ($tpm.TpmPresent) {
            $tpmVer = 'Present'
            try {
                $tpmWmi = Get-CimInstance -Namespace 'root\cimv2\Security\MicrosoftTpm' -ClassName Win32_Tpm -ErrorAction Stop
                if ($tpmWmi.SpecVersion) { $tpmVer = ($tpmWmi.SpecVersion -split ',')[0].Trim() }
            } catch { }
            $health.TPM = $tpmVer
            $health.TPMOk = $true
        } else {
            $health.TPM = 'Not Found'
            $health.TPMOk = $false
        }
    } catch {
        $health.TPM = 'N/A'
        $health.TPMOk = $false
    }



    # SentinelOne
    $s1Svc = Get-Service -Name 'SentinelAgent' -ErrorAction SilentlyContinue
    if ($s1Svc) {
        $health.SentinelOne = $s1Svc.Status.ToString()
        $health.SentinelOneOk = $s1Svc.Status -eq 'Running'
    } else {
        $health.SentinelOne = 'Not Found'
        $health.SentinelOneOk = $false
        $health.SentinelOneGray = $true
    }

    # BitDefender GravityZone
    $bdSvc = Get-Service -Name 'EPSecurityService' -ErrorAction SilentlyContinue
    if (-not $bdSvc) { $bdSvc = Get-Service -Name 'EPProtectedService' -ErrorAction SilentlyContinue }
    if ($bdSvc) {
        $health.BitDefender = $bdSvc.Status.ToString()
        $health.BitDefenderOk = $bdSvc.Status -eq 'Running'
    } else {
        $health.BitDefender = 'Not Found'
        $health.BitDefenderOk = $false
        $health.BitDefenderGray = $true
    }

    # Pending Reboot
    $rebootPending = $false
    $paths = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending',
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'
    )
    foreach ($p in $paths) {
        if (Test-Path $p) { $rebootPending = $true; break }
    }
    $health.PendingReboot = if ($rebootPending) { 'Yes' } else { 'No' }
    $health.PendingRebootOk = -not $rebootPending

    return $health
}

function Get-EndpointHardware {
    $cpu = Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue | Select-Object -First 1
    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
    $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue
    $disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'" -ErrorAction SilentlyContinue
    $phys = Get-PhysicalDisk -ErrorAction SilentlyContinue | Select-Object -First 1

    $totalRamGB = [math]::Round($cs.TotalPhysicalMemory / 1GB, 1)
    $freeRamGB = [math]::Round($os.FreePhysicalMemory / 1MB, 1)  # FreePhysicalMemory is in KB
    $usedRamGB = [math]::Round($totalRamGB - $freeRamGB, 1)
    $ramPercent = [math]::Round(($usedRamGB / $totalRamGB) * 100)

    $diskTotalGB = [math]::Round($disk.Size / 1GB, 0)
    $diskFreeGB = [math]::Round($disk.FreeSpace / 1GB, 0)
    $diskUsedGB = $diskTotalGB - $diskFreeGB
    $diskPercent = if ($diskTotalGB -gt 0) { [math]::Round(($diskUsedGB / $diskTotalGB) * 100) } else { 0 }

    @{
        CPU          = if ($cpu.Name) { $cpu.Name.Trim() } else { 'Unknown' }
        RAMUsedGB    = $usedRamGB
        RAMTotalGB   = $totalRamGB
        RAMPercent   = $ramPercent
        DiskUsedGB   = $diskUsedGB
        DiskTotalGB  = $diskTotalGB
        DiskPercent  = $diskPercent
        DiskHealth   = if ($phys.HealthStatus) { $phys.HealthStatus } else { 'Unknown' }
        DiskType     = if ($phys.MediaType) { $phys.MediaType } else { 'Unknown' }
    }
}

function Get-EndpointNetwork {
    $adapter = Get-NetIPConfiguration -ErrorAction SilentlyContinue |
        Where-Object { $_.IPv4DefaultGateway } | Select-Object -First 1

    $ip = if ($adapter.IPv4Address) { $adapter.IPv4Address.IPAddress } else { 'N/A' }
    $gateway = if ($adapter.IPv4DefaultGateway) { $adapter.IPv4DefaultGateway.NextHop } else { 'N/A' }
    $dns = if ($adapter.DNSServer) { ($adapter.DNSServer | Where-Object { $_.AddressFamily -eq 2 } | Select-Object -ExpandProperty ServerAddresses) -join ', ' } else { 'N/A' }
    $adapterName = if ($adapter.InterfaceAlias) { $adapter.InterfaceAlias } else { 'N/A' }

    # Azure AD status
    $azureAd = 'N/A'
    try {
        $dsreg = dsregcmd /status 2>$null
        if ($dsreg -match 'AzureAdJoined\s*:\s*YES') { $azureAd = 'Joined' }
        elseif ($dsreg -match 'DomainJoined\s*:\s*YES') { $azureAd = 'Domain Joined' }
        else { $azureAd = 'Not Joined' }
    } catch { }

    @{
        IP           = $ip
        Gateway      = $gateway
        DNS          = $dns
        Adapter      = $adapterName
        AzureAD      = $azureAd
    }
}
