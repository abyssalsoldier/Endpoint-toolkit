# Module: Setup-UsbToolkit.ps1
# Not registered as a nav module — accessed via the USB Toolkit button in the nav panel.
# Functions Get-UsbToolkitUI and Invoke-UsbToolkitSetup are called directly.

# --- WPF Action Panel UI ---
function Get-UsbToolkitUI {
    $scrollViewer = New-Object System.Windows.Controls.ScrollViewer
    $scrollViewer.VerticalScrollBarVisibility = 'Auto'
    $scrollViewer.HorizontalScrollBarVisibility = 'Disabled'

    $panel = New-Object System.Windows.Controls.StackPanel
    $panel.Margin = [System.Windows.Thickness]::new(0, 0, 12, 0)

    # ===== HEADER =====
    $header = New-Object System.Windows.Controls.TextBlock
    $header.Text = 'Setup / Update USB Toolkit'
    $header.FontSize = 22
    $header.FontWeight = 'Bold'
    $header.Foreground = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString('#89B4FA'))
    $header.Margin = [System.Windows.Thickness]::new(0, 0, 0, 6)
    $panel.Children.Add($header) | Out-Null

    $desc = New-Object System.Windows.Controls.TextBlock
    $desc.Text = 'Copy the toolkit to a USB drive for offline use at client sites.'
    $desc.FontSize = 13
    $desc.Foreground = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString('#A6ADC8'))
    $desc.Margin = [System.Windows.Thickness]::new(0, 0, 0, 20)
    $desc.TextWrapping = 'Wrap'
    $panel.Children.Add($desc) | Out-Null

    # ===== USB DRIVE SELECTION =====
    $driveLabel = New-Object System.Windows.Controls.Label
    $driveLabel.Content = 'USB DRIVE'
    $driveLabel.FontWeight = 'Bold'
    $panel.Children.Add($driveLabel) | Out-Null

    $driveRow = New-Object System.Windows.Controls.StackPanel
    $driveRow.Orientation = 'Horizontal'
    $driveRow.Margin = [System.Windows.Thickness]::new(0, 0, 0, 8)

    $driveCombo = New-Object System.Windows.Controls.ComboBox
    $driveCombo.MinWidth = 400
    $driveCombo.DisplayMemberPath = 'Display'
    $driveCombo.Foreground = [System.Windows.Media.Brushes]::Black
    $driveRow.Children.Add($driveCombo) | Out-Null

    $refreshBtn = New-Object System.Windows.Controls.Button
    $refreshBtn.Content = 'Refresh'
    $refreshBtn.Margin = [System.Windows.Thickness]::new(8, 0, 0, 0)
    $refreshBtn.Padding = [System.Windows.Thickness]::new(12, 6, 12, 6)
    $driveRow.Children.Add($refreshBtn) | Out-Null

    $panel.Children.Add($driveRow) | Out-Null

    # Drive status (fresh/update info)
    $driveStatus = New-Object System.Windows.Controls.TextBlock
    $driveStatus.FontSize = 12
    $driveStatus.Foreground = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString('#A6ADC8'))
    $driveStatus.Margin = [System.Windows.Thickness]::new(0, 0, 0, 16)
    $panel.Children.Add($driveStatus) | Out-Null

    # ===== DRIVE CHECKS =====
    $checksLabel = New-Object System.Windows.Controls.Label
    $checksLabel.Content = 'DRIVE CHECKS'
    $checksLabel.FontWeight = 'Bold'
    $checksLabel.Margin = [System.Windows.Thickness]::new(0, 0, 0, 4)
    $panel.Children.Add($checksLabel) | Out-Null

    $checkSize = New-Object System.Windows.Controls.TextBlock
    $checkSize.FontSize = 13
    $checkSize.Margin = [System.Windows.Thickness]::new(4, 2, 0, 2)
    $panel.Children.Add($checkSize) | Out-Null

    $checkFs = New-Object System.Windows.Controls.TextBlock
    $checkFs.FontSize = 13
    $checkFs.Margin = [System.Windows.Thickness]::new(4, 2, 0, 2)
    $panel.Children.Add($checkFs) | Out-Null

    $checkSerial = New-Object System.Windows.Controls.TextBlock
    $checkSerial.FontSize = 13
    $checkSerial.Margin = [System.Windows.Thickness]::new(4, 2, 0, 12)
    $panel.Children.Add($checkSerial) | Out-Null

    # ===== PREPARE DRIVE BUTTON =====
    $prepareBtn = New-Object System.Windows.Controls.Button
    $prepareBtn.Content = 'Prepare Drive (Format NTFS)'
    $prepareBtn.IsEnabled = $false
    $prepareBtn.Padding = [System.Windows.Thickness]::new(14, 8, 14, 8)
    $prepareBtn.Margin = [System.Windows.Thickness]::new(0, 0, 0, 20)
    $prepareBtn.Background = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString('#45243D'))
    $prepareBtn.Foreground = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString('#F38BA8'))
    $prepareBtn.HorizontalAlignment = 'Left'
    $panel.Children.Add($prepareBtn) | Out-Null

    # ===== TOOLKIT PASSWORD =====
    $pwdLabel = New-Object System.Windows.Controls.Label
    $pwdLabel.Content = 'USB Toolkit Password (Required)'
    $pwdLabel.FontWeight = 'Bold'
    $pwdLabel.Margin = [System.Windows.Thickness]::new(0, 0, 0, 4)
    $panel.Children.Add($pwdLabel) | Out-Null

    $pwdInputGrid = New-Object System.Windows.Controls.Grid
    $pwdInputGrid.Margin = [System.Windows.Thickness]::new(0, 0, 0, 16)
    $pwdInputGrid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{ Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star) }))
    $pwdInputGrid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{ Width = [System.Windows.GridLength]::new(34) }))
    
    $pwdBox = New-Object System.Windows.Controls.PasswordBox; $pwdBox.Height = 28; $pwdBox.VerticalContentAlignment = 'Center'
    $pwdRevealInput = New-Object System.Windows.Controls.TextBox; $pwdRevealInput.Height = 28; $pwdRevealInput.VerticalContentAlignment = 'Center'; $pwdRevealInput.Visibility = 'Collapsed'
    $pwdRevealBtn = New-Object System.Windows.Controls.Button; $pwdRevealBtn.Content = [System.Char]::ConvertFromUtf32(0x1F441); $pwdRevealBtn.Height = 28; $pwdRevealBtn.Margin = [System.Windows.Thickness]::new(2,0,0,0); $pwdRevealBtn.Cursor = 'Hand'
    $pwdRevealBtn.Background = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.ColorConverter]::ConvertFromString('#FF3D3D5C'))
    $pwdRevealBtn.Foreground = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.ColorConverter]::ConvertFromString('#FFCDD6F4'))
    $pwdRevealBtn.BorderThickness = [System.Windows.Thickness]::new(0)
    $pwdRevealBtn.Padding = [System.Windows.Thickness]::new(0)
    $pwdRevealBtn.FontSize = 16
    $pwdRevealBtn.ToolTip = 'Reveal Password'
    
    [System.Windows.Controls.Grid]::SetColumn($pwdBox, 0); $pwdInputGrid.Children.Add($pwdBox) | Out-Null
    [System.Windows.Controls.Grid]::SetColumn($pwdRevealInput, 0); $pwdInputGrid.Children.Add($pwdRevealInput) | Out-Null
    [System.Windows.Controls.Grid]::SetColumn($pwdRevealBtn, 1); $pwdInputGrid.Children.Add($pwdRevealBtn) | Out-Null
    
    $panel.Children.Add($pwdInputGrid) | Out-Null

    $Global:SyncHash.UsbPwdBox = $pwdBox
    $Global:SyncHash.UsbPwdRevealInput = $pwdRevealInput

    $pwdRevealBtn.Add_Click({
        if ($Global:SyncHash.UsbPwdBox.Visibility -eq 'Visible') {
            $Global:SyncHash.UsbPwdRevealInput.Text = $Global:SyncHash.UsbPwdBox.Password
            $Global:SyncHash.UsbPwdBox.Visibility = 'Collapsed'
            $Global:SyncHash.UsbPwdRevealInput.Visibility = 'Visible'
        } else {
            $Global:SyncHash.UsbPwdBox.Password = $Global:SyncHash.UsbPwdRevealInput.Text
            $Global:SyncHash.UsbPwdRevealInput.Visibility = 'Collapsed'
            $Global:SyncHash.UsbPwdBox.Visibility = 'Visible'
        }
    })


    # ===== SETUP USB BUTTON =====
    $setupBtn = New-Object System.Windows.Controls.Button
    $setupBtn.Content = 'Setup USB'
    $setupBtn.IsEnabled = $false
    $setupBtn.Padding = [System.Windows.Thickness]::new(24, 10, 24, 10)
    $setupBtn.FontSize = 14
    $setupBtn.FontWeight = 'Bold'
    $setupBtn.Background = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString('#A6E3A1'))
    $setupBtn.Foreground = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString('#1E1E2E'))
    $setupBtn.Margin = [System.Windows.Thickness]::new(0, 0, 0, 12)
    $panel.Children.Add($setupBtn) | Out-Null

    # Progress bar
    $progress = New-Object System.Windows.Controls.ProgressBar
    $progress.Height = 4
    $progress.IsIndeterminate = $false
    $progress.Margin = [System.Windows.Thickness]::new(0, 0, 0, 8)
    $progress.Foreground = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString('#A6E3A1'))
    $progress.Background = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString('#2D2D44'))
    $panel.Children.Add($progress) | Out-Null

    # Status text
    $statusText = New-Object System.Windows.Controls.TextBlock
    $statusText.FontSize = 13
    $statusText.TextWrapping = 'Wrap'
    $statusText.Foreground = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString('#A6ADC8'))
    $panel.Children.Add($statusText) | Out-Null

    # ===== Store all control refs in SyncHash =====
    $Global:SyncHash.UsbDriveCombo = $driveCombo
    $Global:SyncHash.UsbRefreshBtn = $refreshBtn
    $Global:SyncHash.UsbDriveStatus = $driveStatus
    $Global:SyncHash.UsbCheckSize = $checkSize
    $Global:SyncHash.UsbCheckFs = $checkFs
    $Global:SyncHash.UsbCheckSerial = $checkSerial
    $Global:SyncHash.UsbPrepareBtn = $prepareBtn
    $Global:SyncHash.UsbSetupBtn = $setupBtn
    $Global:SyncHash.UsbProgress = $progress
    $Global:SyncHash.UsbStatusText = $statusText

    $Global:SyncHash.UsbPwdBox = $pwdBox
    $Global:SyncHash.StatusText = $statusText

    # ===== Drive validation scriptblock =====
    $validateDrive = {
        $combo = $Global:SyncHash.UsbDriveCombo
        $sizeChk = $Global:SyncHash.UsbCheckSize
        $fsChk = $Global:SyncHash.UsbCheckFs
        $serialChk = $Global:SyncHash.UsbCheckSerial
        $setupB = $Global:SyncHash.UsbSetupBtn
        $prepB = $Global:SyncHash.UsbPrepareBtn
        $statusLbl = $Global:SyncHash.UsbDriveStatus

        $selected = $combo.SelectedItem
        if (-not $selected) {
            $sizeChk.Text = ''
            $fsChk.Text = ''
            $serialChk.Text = ''
            $setupB.IsEnabled = $false
            $prepB.IsEnabled = $false
            $statusLbl.Text = ''
            return
        }

        $prepB.IsEnabled = $true
        $allPass = $true

        # Size check (28 GB minimum = marketing 32GB)
        $sizeGB = $selected.SizeGB
        if ($sizeGB -ge 28) {
            $sizeChk.Text = "$([char]0x2713) Size: $sizeGB GB (minimum 28 GB)"
            $sizeChk.Foreground = New-Object System.Windows.Media.SolidColorBrush(
                [System.Windows.Media.ColorConverter]::ConvertFromString('#A6E3A1'))
        } else {
            $sizeChk.Text = "$([char]0x2717) Size: $sizeGB GB - minimum 32GB drive required"
            $sizeChk.Foreground = New-Object System.Windows.Media.SolidColorBrush(
                [System.Windows.Media.ColorConverter]::ConvertFromString('#F38BA8'))
            $allPass = $false
        }

        # File system check
        $vol = Get-Volume -DriveLetter $selected.DriveLetter -ErrorAction SilentlyContinue
        $fs = if ($vol) { $vol.FileSystemType } else { 'Unknown' }
        if ($fs -eq 'NTFS') {
            $fsChk.Text = "$([char]0x2713) File System: NTFS"
            $fsChk.Foreground = New-Object System.Windows.Media.SolidColorBrush(
                [System.Windows.Media.ColorConverter]::ConvertFromString('#A6E3A1'))
        } else {
            $fsChk.Text = "$([char]0x2717) File System: $fs - NTFS required. Use Prepare Drive to format."
            $fsChk.Foreground = New-Object System.Windows.Media.SolidColorBrush(
                [System.Windows.Media.ColorConverter]::ConvertFromString('#F38BA8'))
            $allPass = $false
        }

        # Hardware serial check
        $serial = Get-DriveSerial -DriveLetter $selected.DriveLetter
        if ($serial) {
            $serialChk.Text = "$([char]0x2713) Hardware Serial: detected"
            $serialChk.Foreground = New-Object System.Windows.Media.SolidColorBrush(
                [System.Windows.Media.ColorConverter]::ConvertFromString('#A6E3A1'))
        } else {
            $serialChk.Text = "$([char]0x26A0) No hardware serial - password caching will not work"
            $serialChk.Foreground = New-Object System.Windows.Media.SolidColorBrush(
                [System.Windows.Media.ColorConverter]::ConvertFromString('#F9E2AF'))
            # Warning only, not a blocker
        }

        $setupB.IsEnabled = $allPass

        # Version info
        $versionFile = "$($selected.DriveLetter):\dependencies\version.txt"
        if (Test-Path $versionFile) {
            $existingVer = (Get-Content $versionFile -Raw).Trim()
            $statusLbl.Text = "Update: v$existingVer -> v$($Global:SyncHash.Toolkit.Version)"
        } else {
            $statusLbl.Text = "Fresh setup (v$($Global:SyncHash.Toolkit.Version))"
        }
    }

    # ===== Populate drives scriptblock =====
    $populateDrives = {
        $combo = $Global:SyncHash.UsbDriveCombo
        $setupB = $Global:SyncHash.UsbSetupBtn
        $statusLbl = $Global:SyncHash.UsbDriveStatus
        $sizeChk = $Global:SyncHash.UsbCheckSize
        $fsChk = $Global:SyncHash.UsbCheckFs
        $serialChk = $Global:SyncHash.UsbCheckSerial
        $prepB = $Global:SyncHash.UsbPrepareBtn

        if (-not $combo) { return }

        $combo.Items.Clear()
        $setupB.IsEnabled = $false
        $prepB.IsEnabled = $false
        $statusLbl.Text = ''
        $sizeChk.Text = ''
        $fsChk.Text = ''
        $serialChk.Text = ''

        try {
            $removableDrives = Get-Disk | Where-Object { $_.BusType -eq 'USB' } |
                Get-Partition | Where-Object { $_.DriveLetter } |
                ForEach-Object {
                    $vol = Get-Volume -DriveLetter $_.DriveLetter -ErrorAction SilentlyContinue
                    if ($vol) {
                        [PSCustomObject]@{
                            DriveLetter = $_.DriveLetter
                            Label       = if ($vol.FileSystemLabel) { $vol.FileSystemLabel } else { 'USB Drive' }
                            SizeGB      = [math]::Round($vol.Size / 1GB, 1)
                            FreeGB      = [math]::Round($vol.SizeRemaining / 1GB, 1)
                            Display     = "$($_.DriveLetter): - $(if ($vol.FileSystemLabel) { $vol.FileSystemLabel } else { 'USB Drive' }) ($([math]::Round($vol.Size / 1GB, 1)) GB, $([math]::Round($vol.SizeRemaining / 1GB, 1)) GB free)"
                        }
                    }
                }

            if ($removableDrives) {
                foreach ($drv in $removableDrives) {
                    $combo.Items.Add($drv) | Out-Null
                }
                if ($combo.Items.Count -eq 1) {
                    $combo.SelectedIndex = 0
                }
            } else {
                $statusLbl.Text = 'No USB drives detected. Insert a drive and click Refresh.'
            }
        } catch {
            $statusLbl.Text = "Error detecting USB drives: $($_.Exception.Message)"
        }
    }

    $Global:SyncHash.UsbValidateDrive = $validateDrive
    $Global:SyncHash.UsbPopulateDrives = $populateDrives

    # ===== EVENT HANDLERS (register before initial population) =====

    # Refresh
    $refreshBtn.Add_Click({
        $pd = $Global:SyncHash.UsbPopulateDrives
        if ($pd) { & $pd }
        # Re-validate after refresh
        $vd = $Global:SyncHash.UsbValidateDrive
        if ($vd) { & $vd }
        Write-Log 'USB drive list refreshed' -Level Info
    })

    # Drive selection -> validate
    $driveCombo.Add_SelectionChanged({
        $vd = $Global:SyncHash.UsbValidateDrive
        if ($vd) { & $vd }
    })

    # Initial population + validation
    & $populateDrives
    & $validateDrive

    # Prepare Drive (format)
    $prepareBtn.Add_Click({
        $combo = $Global:SyncHash.UsbDriveCombo
        $selected = $combo.SelectedItem
        if (-not $selected) { return }

        $letter = $selected.DriveLetter
        $confirm = [System.Windows.MessageBox]::Show(
            "This will ERASE ALL DATA on drive ${letter}: ($($selected.Label)).`n`nAre you sure?",
            'Confirm Format', 'YesNo', 'Warning')
        if ($confirm -ne 'Yes') { return }

        $Global:SyncHash.UsbPrepareBtn.IsEnabled = $false
        $Global:SyncHash.UsbSetupBtn.IsEnabled = $false
        $Global:SyncHash.UsbProgress.IsIndeterminate = $true
        Write-Log "Formatting drive ${letter}: to NTFS..." -Level Info

        $rs = [runspacefactory]::CreateRunspace()
        $rs.ApartmentState = 'STA'
        $rs.Open()
        $rs.SessionStateProxy.SetVariable('SyncHash', $Global:SyncHash)
        $rs.SessionStateProxy.SetVariable('DriveLetter', $letter)

        $ps = [powershell]::Create()
        $ps.Runspace = $rs
        $ps.AddScript({
            $toolkitRoot = $SyncHash.Toolkit.Root
            Get-ChildItem -Path "$toolkitRoot\Core" -Filter '*.ps1' -File | ForEach-Object { . $_.FullName }
            Get-ChildItem -Path "$toolkitRoot\UI" -Filter '*.ps1' -File | ForEach-Object { . $_.FullName }

            try {
                Format-Volume -DriveLetter $DriveLetter -FileSystem NTFS -NewFileSystemLabel 'TOOLKIT' -Confirm:$false -Force -ErrorAction Stop
                Write-Log "Drive ${DriveLetter}: formatted to NTFS (TOOLKIT)" -Level Success
            } catch {
                Write-Log "Format failed: $($_.Exception.Message)" -Level Error
            }

            $SyncHash.Window.Dispatcher.Invoke([action]{
                $SyncHash.UsbProgress.IsIndeterminate = $false
                $SyncHash.UsbPrepareBtn.IsEnabled = $true
                # Refresh drive list and re-validate
                $pd = $SyncHash.UsbPopulateDrives
                if ($pd) { & $pd }
            })
        }) | Out-Null
        $ps.BeginInvoke() | Out-Null
    })

    # Setup USB
    $setupBtn.Add_Click({
        $combo = $Global:SyncHash.UsbDriveCombo
        $selected = $combo.SelectedItem
        if (-not $selected) { return }

        $Global:SyncHash.UsbSetupBtn.IsEnabled = $false
        $Global:SyncHash.UsbDriveCombo.IsEnabled = $false
        $Global:SyncHash.UsbRefreshBtn.IsEnabled = $false
        $Global:SyncHash.UsbPrepareBtn.IsEnabled = $false
        $Global:SyncHash.UsbProgress.IsIndeterminate = $true
        $Global:SyncHash.UsbStatusText.Text = 'Setting up USB...'

        $driveLetter = $selected.DriveLetter
        $downloadInstallers = $false
        if ($Global:SyncHash.UsbPwdBox.Visibility -eq 'Visible') {
            $pwdText = $Global:SyncHash.UsbPwdBox.Password
        } else {
            $pwdText = $Global:SyncHash.UsbPwdRevealInput.Text
        }
        
        if ([string]::IsNullOrEmpty($pwdText)) {
            $toolkitPassword = $null
        } else {
            $toolkitPassword = ConvertTo-SecureString -String $pwdText -AsPlainText -Force
        }

        if ($toolkitPassword -eq $null -or $toolkitPassword.Length -eq 0) {
            [System.Windows.MessageBox]::Show('Please enter a password for the USB toolkit.', 'Password Required', 'OK', 'Warning') | Out-Null
            $Global:SyncHash.UsbSetupBtn.IsEnabled = $true
            $Global:SyncHash.UsbDriveCombo.IsEnabled = $true
            $Global:SyncHash.UsbRefreshBtn.IsEnabled = $true
            $Global:SyncHash.UsbPrepareBtn.IsEnabled = $true
            $Global:SyncHash.UsbProgress.IsIndeterminate = $false
            $Global:SyncHash.UsbStatusText.Text = ''
            return
        }

        $rs = [runspacefactory]::CreateRunspace()
        $rs.ApartmentState = 'STA'
        $rs.ThreadOptions = 'ReuseThread'
        $rs.Open()
        $rs.SessionStateProxy.SetVariable('SyncHash', $Global:SyncHash)
        $rs.SessionStateProxy.SetVariable('DriveLetter', $driveLetter)
        $rs.SessionStateProxy.SetVariable('DownloadInstallers', $downloadInstallers)
        $rs.SessionStateProxy.SetVariable('ToolkitPassword', $toolkitPassword)
        $rs.SessionStateProxy.SetVariable('MainToolkitKey', $Global:SyncHash.ToolkitKey)

        $ps = [powershell]::Create()
        $ps.Runspace = $rs

        $ps.AddScript({
            $toolkitRoot = $SyncHash.Toolkit.Root
            Get-ChildItem -Path "$toolkitRoot\Core" -Filter '*.ps1' -File | ForEach-Object { . $_.FullName }
            Get-ChildItem -Path "$toolkitRoot\UI" -Filter '*.ps1' -File | ForEach-Object { . $_.FullName }
            Get-ChildItem -Path "$toolkitRoot\Modules" -Filter '*.ps1' -File | ForEach-Object { . $_.FullName }

            $entry = @{
                Name = 'Setup-UsbToolkit'; Label = 'Setup USB Toolkit'
                StartTime = Get-Date; EndTime = $null; Status = 'Success'; Detail = ''
            }

            try {
                Invoke-UsbToolkitSetup -DriveLetter $DriveLetter -DownloadInstallers $DownloadInstallers -ToolkitPassword $ToolkitPassword -MainToolkitKey $MainToolkitKey
            } catch {
                $entry.Status = 'Error'
                $entry.Detail = $_.Exception.Message
                Write-Log "Error: $($_.Exception.Message)" -Level Error
            } finally {
                $entry.EndTime = Get-Date
                $SyncHash.Window.Dispatcher.Invoke([action]{
                    if ($SyncHash.Toolkit.Session) {
                        $SyncHash.Toolkit.Session.ModulesRun.Add($entry) | Out-Null
                    }
                })
            }

            $SyncHash.Window.Dispatcher.Invoke([action]{
                $SyncHash.UsbStatusText.Text = ''
                $SyncHash.UsbProgress.IsIndeterminate = $false
                $SyncHash.UsbSetupBtn.IsEnabled = $true
                $SyncHash.UsbDriveCombo.IsEnabled = $true
                $SyncHash.UsbRefreshBtn.IsEnabled = $true
                $SyncHash.UsbPrepareBtn.IsEnabled = $true
            })
        }) | Out-Null

        $ps.BeginInvoke() | Out-Null
    })

    $scrollViewer.Content = $panel
    return $scrollViewer
}

# --- Business logic (runs in background runspace) ---
function Invoke-UsbToolkitSetup {
    param(
        [string]$DriveLetter,
        [bool]$DownloadInstallers = $false,
        [securestring]$ToolkitPassword,
        [string]$MainToolkitKey
    )

    $sourceRoot = $SyncHash.Toolkit.Parent
    $version = $SyncHash.Toolkit.Version

    Write-Log "Staging toolkit for SFX compilation on ${DriveLetter}:\ ..." -Level Info
    Update-ActionStatus 'Staging files...' '#F9E2AF'

    $tempStaging = Join-Path $env:TEMP "ToolkitUSBBuild_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    if (Test-Path $tempStaging) { Remove-Item $tempStaging -Recurse -Force }
    New-Item -ItemType Directory -Path $tempStaging -Force | Out-Null

    $robocopyArgs = @(
        "`"$sourceRoot`"",
        "`"$tempStaging`"",
        '/MIR',
        '/XD', '.git', '.github', '.claude', '.vscode', 'Installers', '_builds',
        '/XF', '.gitignore', 'Protect-Credentials.ps1', 'toolkit-config.json', 'clients.csv', '.toolkit-key', 'build.ps1',
        '/NFL', '/NDL', '/NJH', '/NJS',
        '/R:2', '/W:1'
    )
    $proc = Start-Process robocopy -ArgumentList $robocopyArgs -Wait -PassThru -NoNewWindow

    if ($proc.ExitCode -ge 8) {
        Write-Log "Error during staging copy (robocopy exit code $($proc.ExitCode))." -Level Error
        Update-ActionStatus 'Staging failed!' '#F38BA8'
        throw "Robocopy failed with exit code $($proc.ExitCode)"
    }

    $usbSerial = Get-DriveSerial -DriveLetter $DriveLetter

    # Generate .sfx-key if password provided
    if ($ToolkitPassword -and $MainToolkitKey) {
        $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($ToolkitPassword)
        $plainToolkitPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
        
        $encryptedPassword = Protect-SfxPassword -MainToolkitKey $MainToolkitKey -SfxPassword $plainToolkitPassword
        Set-Content -Path "$tempStaging\.sfx-key" -Value $encryptedPassword -NoNewline -Force
        (Get-Item "$tempStaging\.sfx-key" -Force).Attributes = 'Hidden'
        Write-Log 'Generated .sfx-key in staging directory.' -Level Success
    }



    Update-ActionStatus 'Compressing payload...' '#F9E2AF'
    Write-Log "Compressing staged files..." -Level Info
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zipPath = Join-Path $env:TEMP "toolkit-payload-$(Get-Date -Format 'yyyyMMdd_HHmmss').zip"
    if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
    [System.IO.Compression.ZipFile]::CreateFromDirectory($tempStaging, $zipPath)

    Update-ActionStatus 'Compiling SFX...' '#F9E2AF'
    Write-Log "Compiling custom C# extraction stub..." -Level Info

    $csharpCode = @"
using System;
using System.IO;
using System.IO.Compression;
using System.Diagnostics;
using System.Management;
using System.Reflection;

namespace EndpointToolkit
{
    class Program
    {
        static void Main(string[] args)
        {
            string exePath = Assembly.GetExecutingAssembly().Location;
            string driveLetter = Path.GetPathRoot(exePath).TrimEnd('\\');
            
            string expectedSerial = "$usbSerial";
            string actualSerial = "";
            
            if (!string.IsNullOrEmpty(expectedSerial)) {
                try {
                    var searcher = new ManagementObjectSearcher($"ASSOCIATORS OF {{Win32_LogicalDisk.DeviceID='{driveLetter}'}} WHERE AssocClass=Win32_LogicalDiskToPartition");
                    foreach (ManagementObject partition in searcher.Get()) {
                        var diskSearcher = new ManagementObjectSearcher($"ASSOCIATORS OF {{Win32_DiskPartition.DeviceID='{partition["DeviceID"]}'}} WHERE AssocClass=Win32_DiskDriveToDiskPartition");
                        foreach (ManagementObject disk in diskSearcher.Get()) {
                            if (disk["SerialNumber"] != null) {
                                actualSerial = disk["SerialNumber"].ToString().Trim();
                                break;
                            }
                        }
                        break;
                    }
                } catch { }

                if (actualSerial != expectedSerial) {
                    Console.ForegroundColor = ConsoleColor.Red;
                    Console.WriteLine("Hardware binding failed.");
                    Console.WriteLine("This executable cannot be copied from its original USB drive.");
                    Console.ResetColor();
                    Console.WriteLine("Press any key to exit...");
                    Console.ReadKey();
                    return;
                }
            }

            string tempDir = Path.Combine(Path.GetTempPath(), "EndpointToolkit_SC");
            if (Directory.Exists(tempDir)) {
                try { Directory.Delete(tempDir, true); } catch { }
            }
            Directory.CreateDirectory(tempDir);
            
            Console.WriteLine("Extracting Toolkit...");
            try {
                using (FileStream fs = new FileStream(exePath, FileMode.Open, FileAccess.Read)) {
                    using (ZipArchive archive = new ZipArchive(fs, ZipArchiveMode.Read)) {
                        archive.ExtractToDirectory(tempDir);
                    }
                }
            } catch (Exception ex) {
                Console.ForegroundColor = ConsoleColor.Red;
                Console.WriteLine("Extraction failed: " + ex.Message);
                Console.ResetColor();
                Console.ReadKey();
                return;
            }

            string setupScript = Path.Combine(tempDir, @"dependencies\Invoke-EndpointSetup.ps1");
            ProcessStartInfo psi = new ProcessStartInfo {
                FileName = "powershell.exe",
                Arguments = $"-NoProfile -ExecutionPolicy Bypass -File \"{setupScript}\"",
                UseShellExecute = true,
                Verb = "RunAs"
            };
            try {
                Process.Start(psi);
            } catch (Exception ex) {
                Console.ForegroundColor = ConsoleColor.Red;
                Console.WriteLine("Launch failed: " + ex.Message);
                Console.ResetColor();
                Console.ReadKey();
            }
        }
    }
}
"@

    $stubPath = Join-Path $env:TEMP "ToolkitStub-$(Get-Date -Format 'yyyyMMdd_HHmmss').exe"
    Add-Type -TypeDefinition $csharpCode -ReferencedAssemblies "System.Management", "System.IO.Compression", "System.IO.Compression.FileSystem" -OutputAssembly $stubPath -OutputType ConsoleApplication

    Write-Log "Bundling payload into executable..." -Level Info
    $targetExe = "${DriveLetter}:\EndpointToolkit.exe"
    if (Test-Path $targetExe) { Remove-Item $targetExe -Force -ErrorAction SilentlyContinue }

    # Append ZIP bytes to Stub EXE natively
    cmd.exe /c copy /b "`"$stubPath`"" + "`"$zipPath`"" "`"$targetExe`"" | Out-Null

    # Cleanup temp files
    Remove-Item $tempStaging -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
    Remove-Item $stubPath -Force -ErrorAction SilentlyContinue

    Write-Log "USB Toolkit setup complete (v$version) on ${DriveLetter}:" -Level Success
    Update-ActionStatus "USB setup complete! (v$version)" '#A6E3A1'
}
