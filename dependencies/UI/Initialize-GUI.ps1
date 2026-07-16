# UI: Initialize-GUI.ps1
# Loads XAML, sets up synchronized state, handles auth dialog, launches WPF event loop

function Load-XamlWindow {
    param([string]$XamlPath)
    $content = Get-Content $XamlPath -Raw
    $content = $content -replace 'x:Name="', 'Name="'
    $reader = New-Object System.Xml.XmlTextReader([System.IO.StringReader]::new($content))
    return [System.Windows.Markup.XamlReader]::Load($reader)
}

function Start-ToolkitGUI {
    # Load WPF assemblies
    Add-Type -AssemblyName PresentationFramework
    Add-Type -AssemblyName PresentationCore
    Add-Type -AssemblyName WindowsBase

    # --- Load main window XAML ---
    $xamlPath = Join-Path $script:Toolkit.Root 'UI\MainWindow.xaml'
    if (-not (Test-Path $xamlPath)) {
        Write-Host 'FATAL: MainWindow.xaml not found' -ForegroundColor Red
        Read-Host 'Press Enter to exit'
        exit
    }

    $window = Load-XamlWindow -XamlPath $xamlPath

    # --- Initialize synchronized state ---
    $Global:SyncHash = [hashtable]::Synchronized(@{
        Window        = $window
        LogPanel      = $window.FindName('LogOutput')
        ActionContent = $window.FindName('ActionContent')
        NavList       = $window.FindName('lstModules')
        StatusText    = $null
        Toolkit       = $script:Toolkit
        ToolkitKey    = $null
        Modules       = @()
    })

    $Global:SyncHash.UpdateDashboardUI = {
        $Global:SyncHash.CachedDashboard = Build-DashboardUI -Data $Global:SyncHash.DashboardData
        $selected = $Global:SyncHash.NavList.SelectedItem
        if ($selected -and $selected.Tag.Name -eq 'Dashboard') {
            $Global:SyncHash.ActionContent.Content = $Global:SyncHash.CachedDashboard
        }
    }

    # Set version in title bar
    $txtVersion = $window.FindName('txtVersion')
    $txtVersion.Text = "v$($script:Toolkit.Version)"
    $window.Title = "Endpoint Toolkit v$($script:Toolkit.Version)"

    # --- Authentication ---
    Show-AuthDialog

    # Update auth indicator
    $authIcon = $window.FindName('txtAuthIcon')
    $authStatusLabel = $window.FindName('txtAuthStatus')
    if ($Global:SyncHash.Toolkit.Authenticated) {
        $authIcon.Text = [char]0x2705
        $authStatusLabel.Text = 'Authenticated'
        $authStatusLabel.Foreground = New-Object System.Windows.Media.SolidColorBrush(
            [System.Windows.Media.ColorConverter]::ConvertFromString('#A6E3A1'))
    } else {
        $authIcon.Text = [char]0x1F512
        $authStatusLabel.Text = 'Locked'
        $authStatusLabel.Foreground = New-Object System.Windows.Media.SolidColorBrush(
            [System.Windows.Media.ColorConverter]::ConvertFromString('#F38BA8'))
    }

    # --- Initialize session logging ---
    Initialize-SessionLog

    # --- Load and register modules ---
    $modulesPath = Join-Path $script:Toolkit.Root 'Modules'
    if (Test-Path $modulesPath) {
        Get-ChildItem -Path $modulesPath -Filter '*.ps1' -File | ForEach-Object { . $_.FullName }
    }
    $Global:SyncHash.Modules = @(Get-RegisteredModules)

    # Populate nav panel — Dashboard first
    $dashItem = New-Object System.Windows.Controls.ListBoxItem
    $dashItem.Content = 'Dashboard'
    $dashItem.Tag = @{ Name = 'Dashboard'; UIDefinition = $null }
    $Global:SyncHash.NavList.Items.Add($dashItem) | Out-Null

    foreach ($mod in $Global:SyncHash.Modules) {
        $item = New-Object System.Windows.Controls.ListBoxItem
        $item.Content = $mod.Label
        $item.Tag = $mod

        if ($mod.RequiresAuth -and -not $Global:SyncHash.Toolkit.Authenticated) {
            $item.Content = "$($mod.Label) [LOCKED]"
            $item.IsEnabled = $false
        }

        $Global:SyncHash.NavList.Items.Add($item) | Out-Null
    }

    # Nav selection handler
    $Global:SyncHash.NavList.Add_SelectionChanged({
        $selected = $Global:SyncHash.NavList.SelectedItem
        if (-not $selected -or -not $selected.IsEnabled) { return }

        $mod = $selected.Tag
        if ($mod.Name -eq 'Dashboard') {
            Load-Dashboard
            return
        }
        if ($mod.UIDefinition) {
            try {
                $uiPanel = & $mod.UIDefinition
                if ($uiPanel) {
                    $Global:SyncHash.ActionContent.Content = $uiPanel
                }
            } catch {
                Write-Log "Failed to load UI for $($mod.Label): $($_.Exception.Message)" -Level Error
            }
        } else {
            # Default: simple run button for modules without UIDefinition
            $panel = New-Object System.Windows.Controls.StackPanel
            $panel.VerticalAlignment = 'Center'
            $panel.HorizontalAlignment = 'Center'

            $hdr = New-Object System.Windows.Controls.TextBlock
            $hdr.Text = $mod.Label
            $hdr.FontSize = 20
            $hdr.FontWeight = 'Bold'
            $hdr.Foreground = New-Object System.Windows.Media.SolidColorBrush(
                [System.Windows.Media.ColorConverter]::ConvertFromString('#89B4FA'))
            $hdr.Margin = [System.Windows.Thickness]::new(0, 0, 0, 20)
            $panel.Children.Add($hdr) | Out-Null

            $runBtn = New-Object System.Windows.Controls.Button
            $runBtn.Content = "Run $($mod.Label)"
            $runBtn.Tag = $mod
            $runBtn.Add_Click({
                $m = $this.Tag
                $this.IsEnabled = $false
                Start-ModuleInBackground -Module $m
            })
            $panel.Children.Add($runBtn) | Out-Null

            $Global:SyncHash.ActionContent.Content = $panel
        }
    })

    # USB Toolkit button (above Session Report)
    $btnUsbToolkit = $window.FindName('btnUsbToolkit')
    if (-not $Global:SyncHash.Toolkit.Authenticated) {
        $btnUsbToolkit.IsEnabled = $false
        $btnUsbToolkit.Content = 'USB Toolkit [LOCKED]'
        $btnUsbToolkit.Opacity = 0.4
    }
    $btnUsbToolkit.Add_Click({
        # Deselect any module in the nav
        $Global:SyncHash.NavList.SelectedIndex = -1
        $uiPanel = Get-UsbToolkitUI
        if ($uiPanel) {
            $Global:SyncHash.ActionContent.Content = $uiPanel
        }
    })

    # Session Report button
    $btnSessionReport = $window.FindName('btnSessionReport')
    $btnSessionReport.Add_Click({
        Show-SessionReportDialog
    })

    # Quit button
    $btnQuit = $window.FindName('btnQuit')
    $btnQuit.Add_Click({
        $Global:SyncHash.Window.Close()
    })

    # Log startup
    Write-Log "Endpoint Toolkit v$($Global:SyncHash.Toolkit.Version) started" -Level Info
    if ($Global:SyncHash.Toolkit.Authenticated) {
        Write-Log 'Authentication successful' -Level Success
    } else {
        Write-Log 'Running in unauthenticated mode - some features are locked' -Level Warning
    }
    if ($Global:SyncHash.Toolkit.IsUsb) {
        Write-Log "Running from USB drive $($Global:SyncHash.Toolkit.UsbDrive):" -Level Info
    }

    # --- Load dashboard async as default content ---
    $Global:SyncHash.NavList.SelectedIndex = 0
    Load-Dashboard

    # --- Show window (blocks until closed) ---
    $window.ShowDialog() | Out-Null

    # --- Cleanup ---
    $Global:SyncHash.Toolkit.Config = $null
    $Global:SyncHash.ToolkitKey = $null
    $Global:SyncHash.Toolkit.Session = $null
    $script:Toolkit.Config = $null
    $script:ToolkitKey = $null
}

function Show-AuthDialog {
    $sfxKeyPath = Join-Path $Global:SyncHash.Toolkit.Parent '.sfx-key'
    $cachedKeyPath = Join-Path $Global:SyncHash.Toolkit.Parent '.toolkit-key'
    $isSfx = Test-Path $sfxKeyPath
    $hasUsbCache = Test-Path $cachedKeyPath

    # If this is the base toolkit folder (not an exported SFX and not a cached USB)
    if (-not $isSfx -and -not ($Global:SyncHash.Toolkit.IsUsb -and $hasUsbCache)) {
        Write-Log "Base Toolkit Mode - Running Unlocked" -Level Success
        $Global:SyncHash.Toolkit.Authenticated = $true
        $Global:SyncHash.ToolkitKey = "unlocked"
        return
    }

    # WPF password dialog (up to 3 attempts)
    $authXamlPath = Join-Path $Global:SyncHash.Toolkit.Root 'UI\AuthDialog.xaml'
    $authAttempts = 0
    while (-not $Global:SyncHash.Toolkit.Authenticated -and $authAttempts -lt 3) {
        $authAttempts++

        $authWindow = Load-XamlWindow -XamlPath $authXamlPath
        $authWindow.Topmost = $true

        $txtAuthMsg  = $authWindow.FindName('txtAuthMsg')
        $btnSkip     = $authWindow.FindName('btnSkip')
        $btnUnlock   = $authWindow.FindName('btnUnlock')
        $txtPassword = $authWindow.FindName('txtPassword')
        $txtPasswordReveal = $authWindow.FindName('txtPasswordReveal')
        $btnReveal   = $authWindow.FindName('btnReveal')

        if ($isSfx) {
            $txtAuthMsg.Text = "Enter the Toolkit password to unlock. (Attempt $authAttempts/3)"
        } elseif ($Global:SyncHash.Toolkit.IsUsb) {
            $txtAuthMsg.Text = "Enter the USB Toolkit password to unlock. (Attempt $authAttempts/3)"
        }

        $script:authSubmitted = $false
        $btnSkip.Add_Click({ $authWindow.Close() })
        $btnUnlock.Add_Click({
            $script:authSubmitted = $true
            $authWindow.Close()
        })
        $txtPassword.Add_KeyDown({
            param($s, $e)
            if ($e.Key -eq 'Return') { $script:authSubmitted = $true; $authWindow.Close() }
        })
        $txtPasswordReveal.Add_KeyDown({
            param($s, $e)
            if ($e.Key -eq 'Return') { $script:authSubmitted = $true; $authWindow.Close() }
        })
        $btnReveal.Add_Click({
            if ($txtPassword.Visibility -eq 'Visible') {
                $txtPasswordReveal.Text = $txtPassword.Password
                $txtPassword.Visibility = 'Collapsed'
                $txtPasswordReveal.Visibility = 'Visible'
            } else {
                $txtPassword.Password = $txtPasswordReveal.Text
                $txtPasswordReveal.Visibility = 'Collapsed'
                $txtPassword.Visibility = 'Visible'
            }
        })

        $authWindow.ShowDialog() | Out-Null

        if (-not $script:authSubmitted) { return }

        if ($txtPassword.Visibility -eq 'Visible') {
            $enteredKey = $txtPassword.Password.Trim()
        } else {
            $enteredKey = $txtPasswordReveal.Text.Trim()
        }
        if ([string]::IsNullOrWhiteSpace($enteredKey)) { continue }

        $mainKeyToUse = $enteredKey
        $isValid = $false
        $usbUnlocked = $false

        if ($isSfx) {
            try {
                $encryptedCache = (Get-Content $sfxKeyPath -Raw).Trim()
                $mainKeyToUse = Unprotect-SfxPassword -EncryptedData $encryptedCache -SfxPassword $enteredKey
                if ($mainKeyToUse) { $isValid = $true }
            } catch {
                # Decryption of the SFX key failed
            }
        } elseif ($Global:SyncHash.Toolkit.IsUsb -and $hasUsbCache) {
            try {
                $driveLetter = $Global:SyncHash.Toolkit.UsbDrive
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
            $Global:SyncHash.Toolkit.Authenticated = $true
            $Global:SyncHash.ToolkitKey = $mainKeyToUse

            if ($isSfx) {
                Remove-Item $sfxKeyPath -Force -ErrorAction SilentlyContinue
            }
        } else {
            $remaining = 3 - $authAttempts
            if ($remaining -gt 0) {
                [System.Windows.MessageBox]::Show(
                    "Invalid password. $remaining attempt(s) remaining.",
                    'Authentication Failed', 'OK', 'Warning') | Out-Null
            } else {
                [System.Windows.MessageBox]::Show(
                    "Authentication failed after 3 attempts.",
                    'Authentication Failed', 'OK', 'Error') | Out-Null
            }
        }
    }
}

function Start-ModuleInBackground {
    param(
        [hashtable]$Module
    )

    Write-Log "Starting: $($Module.Label)" -Level Info

    $entry = @{
        Name      = $Module.Name
        Label     = $Module.Label
        StartTime = Get-Date
        EndTime   = $null
        Status    = 'Success'
        Detail    = ''
    }

    $runspace = [runspacefactory]::CreateRunspace()
    $runspace.ApartmentState = 'STA'
    $runspace.ThreadOptions = 'ReuseThread'
    $runspace.Open()
    $runspace.SessionStateProxy.SetVariable('SyncHash', $Global:SyncHash)
    $runspace.SessionStateProxy.SetVariable('EntryPoint', $Module.EntryPoint)
    $runspace.SessionStateProxy.SetVariable('SessionEntry', $entry)

    $ps = [powershell]::Create()
    $ps.Runspace = $runspace
    $ps.AddScript({
        $toolkitRoot = $SyncHash.Toolkit.Root

        # Load Core modules
        Get-ChildItem -Path "$toolkitRoot\Core" -Filter '*.ps1' -File | ForEach-Object { . $_.FullName }
        # Load UI modules (for Write-Log)
        Get-ChildItem -Path "$toolkitRoot\UI" -Filter '*.ps1' -File | ForEach-Object { . $_.FullName }
        # Load feature modules
        Get-ChildItem -Path "$toolkitRoot\Modules" -Filter '*.ps1' -File | ForEach-Object { . $_.FullName }

        try {
            & $EntryPoint
            $SessionEntry.Status = 'Success'
        } catch {
            $SessionEntry.Status = 'Error'
            $SessionEntry.Detail = $_.Exception.Message
            Write-Log "Error: $($_.Exception.Message)" -Level Error
        } finally {
            $SessionEntry.EndTime = Get-Date
            $SyncHash.Window.Dispatcher.Invoke([action]{
                if ($SyncHash.Toolkit.Session) {
                    $SyncHash.Toolkit.Session.ModulesRun.Add($SessionEntry) | Out-Null
                }
            })
        }
    }) | Out-Null

    $ps.BeginInvoke() | Out-Null
}

function Show-SessionReportDialog {
    $reportText = Get-SessionReport

    $reportXamlPath = Join-Path $Global:SyncHash.Toolkit.Root 'UI\ReportDialog.xaml'
    $reportWindow = Load-XamlWindow -XamlPath $reportXamlPath
    $reportWindow.Owner = $Global:SyncHash.Window

    $txtReport      = $reportWindow.FindName('txtReport')
    $btnCopy        = $reportWindow.FindName('btnCopy')
    $btnCloseReport = $reportWindow.FindName('btnCloseReport')

    $txtReport.Text = $reportText
    $btnCopy.Add_Click({
        [System.Windows.Clipboard]::SetText($reportText)
        $this.Content = 'Copied'
    })
    $btnCloseReport.Add_Click({
        $reportWindow.Close()
    })

    $reportWindow.ShowDialog() | Out-Null
}

function Load-Dashboard {
    param([switch]$ForceRefresh)

    # Return cached dashboard if available (unless forced refresh)
    if (-not $ForceRefresh -and $Global:SyncHash.CachedDashboard) {
        $Global:SyncHash.ActionContent.Content = $Global:SyncHash.CachedDashboard
        return
    }

    # Show placeholder UI immediately, then gather data in background
    $Global:SyncHash.ActionContent.Content = Build-DashboardPlaceholderUI
    Start-DashboardDataRefresh
}

function Build-DashboardPlaceholderUI {
    $scroll = New-Object System.Windows.Controls.ScrollViewer
    $scroll.VerticalScrollBarVisibility = 'Auto'
    $scroll.HorizontalScrollBarVisibility = 'Disabled'

    $panel = New-Object System.Windows.Controls.StackPanel
    $panel.Margin = [System.Windows.Thickness]::new(0, 0, 12, 0)

    $dimBrush = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString('#585B70'))

    $makeSection = {
        param([string]$Title)
        $lbl = New-Object System.Windows.Controls.Label
        $lbl.Content = $Title
        $lbl.FontWeight = 'Bold'
        $lbl.Margin = [System.Windows.Thickness]::new(0, 0, 0, 4)
        $panel.Children.Add($lbl) | Out-Null

        $status = New-Object System.Windows.Controls.TextBlock
        $status.Text = 'Checking...'
        $status.FontSize = 13
        $status.Foreground = $dimBrush
        $status.Margin = [System.Windows.Thickness]::new(4, 2, 0, 2)
        $panel.Children.Add($status) | Out-Null

        $spacer = New-Object System.Windows.Controls.Border
        $spacer.Height = 16
        $panel.Children.Add($spacer) | Out-Null
    }

    & $makeSection 'IDENTITY'
    & $makeSection 'HEALTH'
    & $makeSection 'HARDWARE'
    & $makeSection 'NETWORK'

    $scroll.Content = $panel
    return $scroll
}

function Start-DashboardDataRefresh {
    $rs = [runspacefactory]::CreateRunspace()
    $rs.ApartmentState = 'STA'
    $rs.Open()
    $rs.SessionStateProxy.SetVariable('SyncHash', $Global:SyncHash)

    $ps = [powershell]::Create()
    $ps.Runspace = $rs
    $ps.AddScript({
        $toolkitRoot = $SyncHash.Toolkit.Root
        Get-ChildItem -Path "$toolkitRoot\Core" -Filter '*.ps1' -File | ForEach-Object { . $_.FullName }
        Get-ChildItem -Path "$toolkitRoot\UI" -Filter '*.ps1' -File | ForEach-Object { . $_.FullName }

        $SyncHash.DashboardData = @{
            Identity = Get-EndpointIdentity
            Health   = Get-EndpointHealth
            Hardware = Get-EndpointHardware
            Network  = Get-EndpointNetwork
        }

        $SyncHash.Window.Dispatcher.Invoke($SyncHash.UpdateDashboardUI)
    }) | Out-Null
    $ps.BeginInvoke() | Out-Null
}

function Build-DashboardUI {
    param([hashtable]$Data)

    $scroll = New-Object System.Windows.Controls.ScrollViewer
    $scroll.VerticalScrollBarVisibility = 'Auto'
    $scroll.HorizontalScrollBarVisibility = 'Disabled'

    $panel = New-Object System.Windows.Controls.StackPanel
    $panel.Margin = [System.Windows.Thickness]::new(0, 0, 12, 0)

    $accentBrush = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString('#89B4FA'))
    $dimBrush = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString('#A6ADC8'))
    $textBrush = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString('#CDD6F4'))
    $greenBrush = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString('#A6E3A1'))
    $redBrush = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString('#F38BA8'))
    $yellowBrush = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString('#F9E2AF'))
    $grayBrush = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString('#6C7086'))

    # Helper: create a label + value row
    $makeRow = {
        param([string]$Label, [string]$Value)
        $row = New-Object System.Windows.Controls.StackPanel
        $row.Orientation = 'Horizontal'
        $row.Margin = [System.Windows.Thickness]::new(4, 2, 0, 2)
        $lbl = New-Object System.Windows.Controls.TextBlock
        $lbl.Text = "${Label}: "
        $lbl.FontSize = 13
        $lbl.Foreground = $dimBrush
        $lbl.MinWidth = 120
        $row.Children.Add($lbl) | Out-Null
        $val = New-Object System.Windows.Controls.TextBlock
        $val.Text = $Value
        $val.FontSize = 13
        $val.Foreground = $textBrush
        $row.Children.Add($val) | Out-Null
        return $row
    }

    # Helper: health badge
    $makeBadge = {
        param([string]$Label, [string]$Value, $Ok, $Gray, $Warning)
        $badge = New-Object System.Windows.Controls.Border
        $badge.CornerRadius = [System.Windows.CornerRadius]::new(4)
        $badge.Padding = [System.Windows.Thickness]::new(10, 4, 10, 4)
        $badge.Margin = [System.Windows.Thickness]::new(0, 0, 6, 6)
        $tb = New-Object System.Windows.Controls.TextBlock
        $tb.Text = "${Label}: $Value"
        $tb.FontSize = 12
        if ($Gray) {
            $badge.Background = New-Object System.Windows.Media.SolidColorBrush(
                [System.Windows.Media.ColorConverter]::ConvertFromString('#FF2D2D44'))
            $tb.Foreground = $grayBrush
        } elseif ($Warning) {
            $badge.Background = New-Object System.Windows.Media.SolidColorBrush(
                [System.Windows.Media.ColorConverter]::ConvertFromString('#FF3E351A')) # Gold/Dark Yellow
            $tb.Foreground = $yellowBrush
        } elseif ($Ok) {
            $badge.Background = New-Object System.Windows.Media.SolidColorBrush(
                [System.Windows.Media.ColorConverter]::ConvertFromString('#FF1A3A2A'))
            $tb.Foreground = $greenBrush
        } else {
            $badge.Background = New-Object System.Windows.Media.SolidColorBrush(
                [System.Windows.Media.ColorConverter]::ConvertFromString('#FF3A1A1A'))
            $tb.Foreground = $redBrush
        }
        $badge.Child = $tb
        return $badge
    }

    # ===== Use pre-gathered data =====
    $identity = $Data.Identity
    $health = $Data.Health
    $hw = $Data.Hardware
    $net = $Data.Network

    # ===== IDENTITY SECTION =====
    $idLabel = New-Object System.Windows.Controls.Label
    $idLabel.Content = 'IDENTITY'
    $idLabel.FontWeight = 'Bold'
    $idLabel.Margin = [System.Windows.Thickness]::new(0, 0, 0, 4)
    $panel.Children.Add($idLabel) | Out-Null

    $panel.Children.Add((& $makeRow 'Hostname' $identity.Hostname)) | Out-Null
    $panel.Children.Add((& $makeRow 'Serial' $identity.Serial)) | Out-Null
    $panel.Children.Add((& $makeRow 'Model' "$($identity.Manufacturer) $($identity.Model)")) | Out-Null
    $panel.Children.Add((& $makeRow 'OS' "$($identity.OSCaption) $($identity.OSVersion) (Build $($identity.OSBuild))")) | Out-Null
    $panel.Children.Add((& $makeRow 'Domain' $identity.Domain)) | Out-Null
    $panel.Children.Add((& $makeRow 'Management State' $identity.JoinType)) | Out-Null

    if ($health.BitLockerOk -and $identity.JoinType -eq 'Local (Standalone)') {
        $warningRow = New-Object System.Windows.Controls.StackPanel
        $warningRow.Orientation = 'Horizontal'
        $warningRow.Margin = [System.Windows.Thickness]::new(4, 6, 0, 4)

        $warnIcon = New-Object System.Windows.Controls.TextBlock
        $warnIcon.Text = [char]0x26A0 + " "
        $warnIcon.FontSize = 13
        $warnIcon.FontWeight = 'Bold'
        $warnIcon.Foreground = $yellowBrush
        $warningRow.Children.Add($warnIcon) | Out-Null

        $warnText = New-Object System.Windows.Controls.TextBlock
        $warnText.Text = 'WARNING: BitLocker is active but Local-Only. No central recovery key escrow.'
        $warnText.FontSize = 13
        $warnText.FontWeight = 'Bold'
        $warnText.Foreground = $yellowBrush
        $warnText.TextWrapping = 'Wrap'
        $warningRow.Children.Add($warnText) | Out-Null

        $panel.Children.Add($warningRow) | Out-Null
    }

    $spacer1 = New-Object System.Windows.Controls.Border
    $spacer1.Height = 16
    $panel.Children.Add($spacer1) | Out-Null

    # ===== HEALTH SECTION =====
    $healthRow = New-Object System.Windows.Controls.StackPanel
    $healthRow.Orientation = 'Horizontal'
    $healthRow.Margin = [System.Windows.Thickness]::new(0, 0, 0, 4)

    $healthLabel = New-Object System.Windows.Controls.Label
    $healthLabel.Content = 'HEALTH'
    $healthLabel.FontWeight = 'Bold'
    $healthRow.Children.Add($healthLabel) | Out-Null

    $dashRefreshBtn = New-Object System.Windows.Controls.Button
    $dashRefreshBtn.Content = 'Refresh'
    $dashRefreshBtn.Padding = [System.Windows.Thickness]::new(10, 2, 10, 2)
    $dashRefreshBtn.Margin = [System.Windows.Thickness]::new(8, 0, 0, 0)
    $dashRefreshBtn.VerticalAlignment = 'Center'
    $dashRefreshBtn.Add_Click({
        # Refresh asynchronously in a background runspace to avoid freezing/crashing the UI thread
        $Global:SyncHash.Window.Dispatcher.BeginInvoke([action]{
            Load-Dashboard -ForceRefresh
        }) | Out-Null
        Write-Log 'Initiated dashboard refresh...' -Level Info
    })
    $healthRow.Children.Add($dashRefreshBtn) | Out-Null
    $panel.Children.Add($healthRow) | Out-Null

    $badgeWrap = New-Object System.Windows.Controls.WrapPanel
    $badgeWrap.Margin = [System.Windows.Thickness]::new(4, 4, 0, 0)

    $isBitLockerWarning = $health.BitLockerOk -and ($identity.JoinType -eq 'Local (Standalone)')
    $bitLockerBadgeOk = $health.BitLockerOk -and -not $isBitLockerWarning

    $badgeWrap.Children.Add((& $makeBadge 'Defender' $health.Defender $health.DefenderOk $false)) | Out-Null
    $badgeWrap.Children.Add((& $makeBadge 'Firewall' $health.Firewall $health.FirewallOk $false)) | Out-Null
    $badgeWrap.Children.Add((& $makeBadge 'BitLocker' $health.BitLocker $bitLockerBadgeOk $false $isBitLockerWarning)) | Out-Null
    $badgeWrap.Children.Add((& $makeBadge 'TPM' $health.TPM $health.TPMOk $false)) | Out-Null

    $badgeWrap.Children.Add((& $makeBadge 'SentinelOne' $health.SentinelOne $health.SentinelOneOk $health.SentinelOneGray)) | Out-Null
    $badgeWrap.Children.Add((& $makeBadge 'BitDefender' $health.BitDefender $health.BitDefenderOk $health.BitDefenderGray)) | Out-Null
    $badgeWrap.Children.Add((& $makeBadge 'Reboot' $health.PendingReboot $health.PendingRebootOk $false)) | Out-Null

    $panel.Children.Add($badgeWrap) | Out-Null

    $spacer2 = New-Object System.Windows.Controls.Border
    $spacer2.Height = 16
    $panel.Children.Add($spacer2) | Out-Null

    # ===== HARDWARE SECTION =====
    $hwLabel = New-Object System.Windows.Controls.Label
    $hwLabel.Content = 'HARDWARE'
    $hwLabel.FontWeight = 'Bold'
    $hwLabel.Margin = [System.Windows.Thickness]::new(0, 0, 0, 4)
    $panel.Children.Add($hwLabel) | Out-Null

    $panel.Children.Add((& $makeRow 'CPU' $hw.CPU)) | Out-Null

    # RAM bar
    $ramRow = New-Object System.Windows.Controls.StackPanel
    $ramRow.Orientation = 'Horizontal'
    $ramRow.Margin = [System.Windows.Thickness]::new(4, 2, 0, 2)
    $ramLbl = New-Object System.Windows.Controls.TextBlock
    $ramLbl.Text = 'RAM: '
    $ramLbl.FontSize = 13
    $ramLbl.Foreground = $dimBrush
    $ramLbl.MinWidth = 120
    $ramRow.Children.Add($ramLbl) | Out-Null
    $ramVal = New-Object System.Windows.Controls.TextBlock
    $ramVal.Text = "$($hw.RAMUsedGB) / $($hw.RAMTotalGB) GB ($($hw.RAMPercent)%)"
    $ramVal.FontSize = 13
    $ramVal.Foreground = $textBrush
    $ramVal.Margin = [System.Windows.Thickness]::new(0, 0, 10, 0)
    $ramRow.Children.Add($ramVal) | Out-Null
    $ramBar = New-Object System.Windows.Controls.ProgressBar
    $ramBar.Width = 150
    $ramBar.Height = 10
    $ramBar.Value = $hw.RAMPercent
    $ramBar.Maximum = 100
    $ramBar.Background = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString('#FF2D2D44'))
    if ($hw.RAMPercent -gt 90) { $ramBar.Foreground = $redBrush }
    elseif ($hw.RAMPercent -gt 70) { $ramBar.Foreground = $yellowBrush }
    else { $ramBar.Foreground = $greenBrush }
    $ramRow.Children.Add($ramBar) | Out-Null
    $panel.Children.Add($ramRow) | Out-Null

    # Disk bar
    $diskRow = New-Object System.Windows.Controls.StackPanel
    $diskRow.Orientation = 'Horizontal'
    $diskRow.Margin = [System.Windows.Thickness]::new(4, 2, 0, 2)
    $diskLbl = New-Object System.Windows.Controls.TextBlock
    $diskLbl.Text = 'Disk C: '
    $diskLbl.FontSize = 13
    $diskLbl.Foreground = $dimBrush
    $diskLbl.MinWidth = 120
    $diskRow.Children.Add($diskLbl) | Out-Null
    $diskVal = New-Object System.Windows.Controls.TextBlock
    $diskVal.Text = "$($hw.DiskUsedGB) / $($hw.DiskTotalGB) GB ($($hw.DiskPercent)%)"
    $diskVal.FontSize = 13
    $diskVal.Foreground = $textBrush
    $diskVal.Margin = [System.Windows.Thickness]::new(0, 0, 10, 0)
    $diskRow.Children.Add($diskVal) | Out-Null
    $diskBar = New-Object System.Windows.Controls.ProgressBar
    $diskBar.Width = 150
    $diskBar.Height = 10
    $diskBar.Value = $hw.DiskPercent
    $diskBar.Maximum = 100
    $diskBar.Background = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString('#FF2D2D44'))
    if ($hw.DiskPercent -gt 90) { $diskBar.Foreground = $redBrush }
    elseif ($hw.DiskPercent -gt 70) { $diskBar.Foreground = $yellowBrush }
    else { $diskBar.Foreground = $greenBrush }
    $diskRow.Children.Add($diskBar) | Out-Null
    $panel.Children.Add($diskRow) | Out-Null

    $panel.Children.Add((& $makeRow 'Disk Health' "$($hw.DiskHealth) ($($hw.DiskType))")) | Out-Null

    $spacer3 = New-Object System.Windows.Controls.Border
    $spacer3.Height = 16
    $panel.Children.Add($spacer3) | Out-Null

    # ===== NETWORK SECTION =====
    $netLabel = New-Object System.Windows.Controls.Label
    $netLabel.Content = 'NETWORK'
    $netLabel.FontWeight = 'Bold'
    $netLabel.Margin = [System.Windows.Thickness]::new(0, 0, 0, 4)
    $panel.Children.Add($netLabel) | Out-Null

    $panel.Children.Add((& $makeRow 'Adapter' $net.Adapter)) | Out-Null
    $panel.Children.Add((& $makeRow 'IP' $net.IP)) | Out-Null
    $panel.Children.Add((& $makeRow 'Gateway' $net.Gateway)) | Out-Null
    $panel.Children.Add((& $makeRow 'DNS' $net.DNS)) | Out-Null

    $scroll.Content = $panel
    return $scroll
}
