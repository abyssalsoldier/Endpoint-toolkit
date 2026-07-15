# Module: Install-Software.ps1 — Unified software package manager

function Register-SoftwareManager {
    @{
        Name         = 'Software-Manager'
        Label        = 'Software Manager'
        Description  = 'Install and update software packages from winget and local installers'
        RequiresAuth = $false
        SortOrder    = 20
        EntryPoint   = 'Start-SoftwareInstall'
        UIDefinition = 'Get-SoftwareManagerUI'
    }
}

# Default winget package catalog
function Get-WingetPackageCatalog {
    @(
        @{ Category = 'Browsers';       Name = 'Google Chrome';              Id = 'Google.Chrome';                        Source = 'winget' }
        @{ Category = 'Browsers';       Name = 'Mozilla Firefox';            Id = 'Mozilla.Firefox';                      Source = 'winget' }
        @{ Category = 'Productivity';   Name = 'Adobe Acrobat Reader';       Id = 'Adobe.Acrobat.Reader.64-bit';          Source = 'winget' }
        @{ Category = 'Productivity';   Name = 'Adobe Acrobat Reader 32-bit';Id = 'Adobe.Acrobat.Reader.32-bit';          Source = 'winget' }
        @{ Category = 'Productivity';   Name = 'Adobe Acrobat Pro';          Id = 'Adobe.Acrobat.Pro';                    Source = 'winget' }
        @{ Category = 'Productivity';   Name = 'Microsoft Office';           Id = 'Microsoft.Office';                     Source = 'winget' }
        @{ Category = 'Productivity';   Name = '7-Zip';                      Id = '7zip.7zip';                            Source = 'winget' }
        @{ Category = 'Productivity';   Name = 'Notepad++';                  Id = 'Notepad++.Notepad++';                  Source = 'winget' }
        @{ Category = 'Productivity';   Name = 'VLC Media Player';           Id = 'VideoLAN.VLC';                         Source = 'winget' }
        @{ Category = 'Communication';  Name = 'Microsoft Teams';            Id = 'Microsoft.Teams';                      Source = 'winget' }
        @{ Category = 'Communication';  Name = 'Zoom';                       Id = 'Zoom.Zoom';                            Source = 'winget' }
        @{ Category = 'Communication';  Name = 'Slack';                      Id = 'SlackTechnologies.Slack';              Source = 'winget' }
        @{ Category = 'Communication';  Name = 'RingCentral';                Id = 'RingCentral.RingCentral';              Source = 'winget' }
        @{ Category = 'Runtimes';       Name = '.NET Desktop Runtime 8';     Id = 'Microsoft.DotNet.DesktopRuntime.8';    Source = 'winget' }
        @{ Category = 'Runtimes';       Name = 'VC++ Redistributable 2015+'; Id = 'Microsoft.VCRedist.2015+.x64';         Source = 'winget' }
        @{ Category = 'Utilities';      Name = 'PowerShell 7';              Id = 'Microsoft.PowerShell';                  Source = 'winget' }
        @{ Category = 'Utilities';      Name = 'TreeSize Free';             Id = 'JAMSoftware.TreeSize.Free';             Source = 'winget' }
        @{ Category = 'Utilities';      Name = 'WinSCP';                    Id = 'WinSCP.WinSCP';                         Source = 'winget' }
        @{ Category = 'Utilities';      Name = 'PuTTY';                     Id = 'PuTTY.PuTTY';                           Source = 'winget' }
        @{ Category = 'Utilities';      Name = 'FileZilla';                 Id = 'TimKosse.FileZilla.Client';              Source = 'winget' }
        @{ Category = 'Drivers';        Name = 'Dell Command Update';       Id = 'Dell.CommandUpdate';                     Source = 'winget' }
        @{ Category = 'Drivers';        Name = 'Lenovo System Update';      Id = 'Lenovo.SystemUpdate';                    Source = 'winget' }
    )
}

# Query winget for installed/upgradeable status of catalog packages
function Get-WingetPackageStatus {
    param([string[]]$CatalogIds)

    $status = @{}
    foreach ($id in $CatalogIds) {
        $status[$id] = @{ Status = 'NotInstalled'; CurrentVersion = ''; AvailableVersion = '' }
    }

    # Check winget availability
    try { $null = winget --version 2>$null } catch { return $status }

    # Helper: parse winget table output and return rows as hashtables with Id and Version columns
    $parseTable = {
        param([string]$RawOutput, [string[]]$Columns)
        $lines = $RawOutput -split "`n"
        $sepIndex = -1
        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -match '^-{2,}') { $sepIndex = $i; break }
        }
        if ($sepIndex -lt 1) { return @() }

        $headerLine = $lines[$sepIndex - 1]
        $colPositions = @{}
        foreach ($col in $Columns) {
            $idx = $headerLine.IndexOf($col)
            if ($idx -ge 0) { $colPositions[$col] = $idx }
        }
        if ($colPositions.Count -lt $Columns.Count) { return @() }

        # Determine column widths from separator or next column start
        $sortedCols = $colPositions.GetEnumerator() | Sort-Object Value
        $results = @()
        for ($i = $sepIndex + 1; $i -lt $lines.Count; $i++) {
            $line = $lines[$i]
            if ([string]::IsNullOrWhiteSpace($line) -or $line -match '^\d+ upgrades available') { continue }
            $row = @{}
            for ($c = 0; $c -lt $sortedCols.Count; $c++) {
                $start = $sortedCols[$c].Value
                $end = if ($c -lt $sortedCols.Count - 1) { $sortedCols[$c + 1].Value } else { $line.Length }
                if ($start -lt $line.Length) {
                    $len = [Math]::Min($end - $start, $line.Length - $start)
                    $row[$sortedCols[$c].Key] = $line.Substring($start, $len).Trim()
                } else {
                    $row[$sortedCols[$c].Key] = ''
                }
            }
            $results += $row
        }
        return $results
    }

    # Helper: match a winget-reported ID to a catalog ID
    # Handles cases like Google.Chrome.EXE matching catalog entry Google.Chrome
    $matchCatalogId = {
        param([string]$RowId)
        if ($status.ContainsKey($RowId)) { return $RowId }
        foreach ($catId in $CatalogIds) {
            if ($RowId -like "$catId*") { return $catId }
        }
        return $null
    }

    # Get installed packages
    try {
        $listRaw = (winget list --accept-source-agreements 2>&1) | Out-String
        $installed = & $parseTable $listRaw @('Id', 'Version')
        foreach ($row in $installed) {
            $rowId = $row['Id']
            if (-not $rowId) { continue }
            $matched = & $matchCatalogId $rowId
            if ($matched) {
                $status[$matched].Status = 'UpToDate'
                $status[$matched].CurrentVersion = $row['Version']
            }
        }
    } catch { }

    # Get packages with available upgrades
    try {
        $upgradeRaw = (winget upgrade --accept-source-agreements 2>&1) | Out-String
        $upgradeable = & $parseTable $upgradeRaw @('Id', 'Version', 'Available')
        foreach ($row in $upgradeable) {
            $rowId = $row['Id']
            if (-not $rowId) { continue }
            $matched = & $matchCatalogId $rowId
            if ($matched) {
                $status[$matched].Status = 'UpdateAvailable'
                $status[$matched].CurrentVersion = $row['Version']
                $status[$matched].AvailableVersion = $row['Available']
            }
        }
    } catch { }

    return $status
}

# Launch (or re-launch) the background status query
function Start-SoftwareStatusRefresh {
    # Reset all status labels to "Checking..."
    $dimBrush = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString('#585B70'))
    for ($i = 0; $i -lt $Global:SyncHash.SoftwareStatusLabels.Count; $i++) {
        $lbl = $Global:SyncHash.SoftwareStatusLabels[$i]
        $cb = $Global:SyncHash.SoftwareCheckboxes[$i]
        if ($cb.Tag.Source -eq 'local') {
            $lbl.Text = ''
        } else {
            $lbl.Text = 'Checking...'
            $lbl.Foreground = $dimBrush
        }
    }
    if ($Global:SyncHash.SoftwareLoadingText) {
        $Global:SyncHash.SoftwareLoadingText.Visibility = 'Visible'
    }

    $rs = [runspacefactory]::CreateRunspace()
    $rs.ApartmentState = 'STA'
    $rs.Open()
    $rs.SessionStateProxy.SetVariable('SyncHash', $Global:SyncHash)

    $catalogIds = @()
    foreach ($cb in $Global:SyncHash.SoftwareCheckboxes) { $catalogIds += $cb.Tag.Id }
    $rs.SessionStateProxy.SetVariable('CatalogIds', $catalogIds)

    $ps = [powershell]::Create()
    $ps.Runspace = $rs
    $ps.AddScript({
        $toolkitRoot = $SyncHash.Toolkit.Root
        Get-ChildItem -Path "$toolkitRoot\Core" -Filter '*.ps1' -File | ForEach-Object { . $_.FullName }
        Get-ChildItem -Path "$toolkitRoot\UI" -Filter '*.ps1' -File | ForEach-Object { . $_.FullName }
        Get-ChildItem -Path "$toolkitRoot\Modules" -Filter '*.ps1' -File | ForEach-Object { . $_.FullName }

        $statusMap = Get-WingetPackageStatus -CatalogIds $CatalogIds

        $SyncHash.Window.Dispatcher.Invoke([action]{
            $SyncHash.SoftwarePackageStatus = $statusMap
            if ($SyncHash.SoftwareLoadingText) {
                $SyncHash.SoftwareLoadingText.Visibility = 'Collapsed'
            }

            $greenBrush = New-Object System.Windows.Media.SolidColorBrush(
                [System.Windows.Media.ColorConverter]::ConvertFromString('#A6E3A1'))
            $yellowBrush = New-Object System.Windows.Media.SolidColorBrush(
                [System.Windows.Media.ColorConverter]::ConvertFromString('#F9E2AF'))
            $grayBrush = New-Object System.Windows.Media.SolidColorBrush(
                [System.Windows.Media.ColorConverter]::ConvertFromString('#585B70'))

            for ($i = 0; $i -lt $SyncHash.SoftwareStatusLabels.Count; $i++) {
                $lbl = $SyncHash.SoftwareStatusLabels[$i]
                $cb  = $SyncHash.SoftwareCheckboxes[$i]
                $id  = $cb.Tag.Id
                $info = $statusMap[$id]

                if ($cb.Tag.Source -eq 'local') {
                    $lbl.Text = ''
                    continue
                }

                if (-not $info) {
                    $lbl.Text = "$([char]0x25CB) Not installed"
                    $lbl.Foreground = $grayBrush
                    continue
                }

                switch ($info.Status) {
                    'UpToDate' {
                        $ver = if ($info.CurrentVersion) { " (v$($info.CurrentVersion))" } else { '' }
                        $lbl.Text = "$([char]0x25CF) Installed$ver"
                        $lbl.Foreground = $greenBrush
                    }
                    'UpdateAvailable' {
                        $lbl.Text = "$([char]0x25CF) Update available ($($info.CurrentVersion) " + [char]0x2192 + " $($info.AvailableVersion))"
                        $lbl.Foreground = $yellowBrush
                    }
                    default {
                        $lbl.Text = "$([char]0x25CB) Not installed"
                        $lbl.Foreground = $grayBrush
                    }
                }
            }
        })
    }) | Out-Null
    $ps.BeginInvoke() | Out-Null
}

function Get-SoftwareManagerUI {
    $scroll = New-Object System.Windows.Controls.ScrollViewer
    $scroll.VerticalScrollBarVisibility = 'Auto'
    $scroll.HorizontalScrollBarVisibility = 'Disabled'

    $panel = New-Object System.Windows.Controls.StackPanel
    $panel.Margin = [System.Windows.Thickness]::new(0, 0, 12, 0)

    # Header
    $header = New-Object System.Windows.Controls.TextBlock
    $header.Text = 'Software Manager'
    $header.FontSize = 22
    $header.FontWeight = 'Bold'
    $header.Foreground = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString('#89B4FA'))
    $header.Margin = [System.Windows.Thickness]::new(0, 0, 0, 6)
    $panel.Children.Add($header) | Out-Null

    $desc = New-Object System.Windows.Controls.TextBlock
    $desc.Text = 'Install and update software packages from winget and local installers.'
    $desc.FontSize = 13
    $desc.Foreground = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString('#A6ADC8'))
    $desc.Margin = [System.Windows.Thickness]::new(0, 0, 0, 16)
    $desc.TextWrapping = 'Wrap'
    $panel.Children.Add($desc) | Out-Null

    # Build package list
    $catalog = Get-WingetPackageCatalog

    if ($Global:SyncHash.Toolkit.Root) {
        $customDir = Join-Path $Global:SyncHash.Toolkit.Root 'CustomInstallers'
        if (Test-Path $customDir) {
            $localFiles = Get-ChildItem -Path $customDir -Include '*.exe', '*.msi' -Recurse -File | Where-Object { $_.Directory.Name -ne 'Agent_Uninstaller' }
            foreach ($file in $localFiles) {
                $subDir = if ($file.DirectoryName -eq $customDir) { '' } else { " [$($file.Directory.Name)]" }
                $displayName = "$($file.Name)$subDir"
                $catalog += @{ Category = 'Custom Installers'; Name = $displayName; Id = $file.Name; Source = 'local'; Path = $file.FullName }
            }
        }
    }

    # Buttons row
    $btnRow = New-Object System.Windows.Controls.StackPanel
    $btnRow.Orientation = 'Horizontal'
    $btnRow.Margin = [System.Windows.Thickness]::new(0, 0, 0, 12)

    $selectAllBtn = New-Object System.Windows.Controls.Button
    $selectAllBtn.Content = 'Select All'
    $selectAllBtn.Padding = [System.Windows.Thickness]::new(12, 6, 12, 6)
    $selectAllBtn.Margin = [System.Windows.Thickness]::new(0, 0, 8, 0)
    $btnRow.Children.Add($selectAllBtn) | Out-Null

    $clearAllBtn = New-Object System.Windows.Controls.Button
    $clearAllBtn.Content = 'Clear All'
    $clearAllBtn.Padding = [System.Windows.Thickness]::new(12, 6, 12, 6)
    $clearAllBtn.Margin = [System.Windows.Thickness]::new(0, 0, 8, 0)
    $btnRow.Children.Add($clearAllBtn) | Out-Null

    $refreshBtn = New-Object System.Windows.Controls.Button
    $refreshBtn.Content = 'Refresh Status'
    $refreshBtn.Padding = [System.Windows.Thickness]::new(12, 6, 12, 6)
    $btnRow.Children.Add($refreshBtn) | Out-Null

    $panel.Children.Add($btnRow) | Out-Null

    # Package checkboxes by category
    $packageLabel = New-Object System.Windows.Controls.Label
    $packageLabel.Content = 'PACKAGES'
    $packageLabel.FontWeight = 'Bold'
    $packageLabel.Margin = [System.Windows.Thickness]::new(0, 0, 0, 8)
    $panel.Children.Add($packageLabel) | Out-Null

    # Loading indicator
    $loadingText = New-Object System.Windows.Controls.TextBlock
    $loadingText.Text = 'Checking installed packages...'
    $loadingText.FontSize = 12
    $loadingText.FontStyle = 'Italic'
    $loadingText.Foreground = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString('#A6ADC8'))
    $loadingText.Margin = [System.Windows.Thickness]::new(8, 0, 0, 8)
    $panel.Children.Add($loadingText) | Out-Null
    $Global:SyncHash.SoftwareLoadingText = $loadingText

    $allCheckboxes = [System.Collections.ArrayList]::new()
    $allStatusLabels = [System.Collections.ArrayList]::new()
    $lastCategory = ''

    foreach ($pkg in $catalog) {
        if ($pkg.Category -ne $lastCategory) {
            $catLabel = New-Object System.Windows.Controls.TextBlock
            $catLabel.Text = "-- $($pkg.Category) --"
            $catLabel.FontSize = 12
            $catLabel.FontWeight = 'Bold'
            $catLabel.Foreground = New-Object System.Windows.Media.SolidColorBrush(
                [System.Windows.Media.ColorConverter]::ConvertFromString('#A6ADC8'))
            $catLabel.Margin = [System.Windows.Thickness]::new(0, 8, 0, 4)
            $panel.Children.Add($catLabel) | Out-Null
            $lastCategory = $pkg.Category
        }

        # Package row: checkbox + status label
        $row = New-Object System.Windows.Controls.StackPanel
        $row.Orientation = 'Horizontal'
        $row.Margin = [System.Windows.Thickness]::new(8, 3, 0, 3)

        $cb = New-Object System.Windows.Controls.CheckBox
        $cb.Content = " $($pkg.Name)"
        $cb.Tag = $pkg
        $cb.Foreground = New-Object System.Windows.Media.SolidColorBrush(
            [System.Windows.Media.ColorConverter]::ConvertFromString('#CDD6F4'))
        $cb.FontSize = 13
        $cb.VerticalAlignment = 'Center'
        $row.Children.Add($cb) | Out-Null

        $statusLbl = New-Object System.Windows.Controls.TextBlock
        $statusLbl.Text = if ($pkg.Source -eq 'local') { '' } else { 'Checking...' }
        $statusLbl.FontSize = 11
        $statusLbl.Foreground = New-Object System.Windows.Media.SolidColorBrush(
            [System.Windows.Media.ColorConverter]::ConvertFromString('#585B70'))
        $statusLbl.VerticalAlignment = 'Center'
        $statusLbl.Margin = [System.Windows.Thickness]::new(10, 0, 0, 0)
        $row.Children.Add($statusLbl) | Out-Null

        $panel.Children.Add($row) | Out-Null
        $allCheckboxes.Add($cb) | Out-Null
        $allStatusLabels.Add($statusLbl) | Out-Null
    }

    # Store checkboxes and status labels for background updates and button actions
    $Global:SyncHash.SoftwareCheckboxes = $allCheckboxes
    $Global:SyncHash.SoftwareStatusLabels = $allStatusLabels
    if (-not $Global:SyncHash.SoftwarePackageStatus) {
        $Global:SyncHash.SoftwarePackageStatus = @{}
    }

    # Select All / Clear All handlers
    $selectAllBtn.Add_Click({
        foreach ($cb in $Global:SyncHash.SoftwareCheckboxes) {
            $cb.IsChecked = $true
        }
    })
    $clearAllBtn.Add_Click({
        foreach ($cb in $Global:SyncHash.SoftwareCheckboxes) {
            $cb.IsChecked = $false
        }
    })

    # Refresh Status handler
    $refreshBtn.Add_Click({ Start-SoftwareStatusRefresh })

    # Silent Install Custom Packages Checkbox
    $silentCheckbox = New-Object System.Windows.Controls.CheckBox
    $silentCheckbox.Content = ' Install Custom Packages Silently'
    $silentCheckbox.IsChecked = $true
    $silentCheckbox.Foreground = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString('#CDD6F4'))
    $silentCheckbox.FontSize = 13
    $silentCheckbox.Margin = [System.Windows.Thickness]::new(0, 0, 0, 12)
    $panel.Children.Add($silentCheckbox) | Out-Null
    $Global:SyncHash.SoftwareSilentCheckbox = $silentCheckbox

    # Spacer
    $spacer = New-Object System.Windows.Controls.Border
    $spacer.Height = 16
    $panel.Children.Add($spacer) | Out-Null

    # Install / Update button
    $installBtn = New-Object System.Windows.Controls.Button
    $installBtn.Content = 'Install / Update Selected'
    $installBtn.Padding = [System.Windows.Thickness]::new(24, 10, 24, 10)
    $installBtn.FontSize = 14
    $installBtn.FontWeight = 'Bold'
    $installBtn.Background = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString('#89B4FA'))
    $installBtn.Foreground = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString('#1E1E2E'))
    $installBtn.Margin = [System.Windows.Thickness]::new(0, 0, 0, 12)
    $panel.Children.Add($installBtn) | Out-Null

    # Progress bar
    $progress = New-Object System.Windows.Controls.ProgressBar
    $progress.Height = 4
    $progress.IsIndeterminate = $false
    $progress.Margin = [System.Windows.Thickness]::new(0, 0, 0, 8)
    $progress.Foreground = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString('#89B4FA'))
    $progress.Background = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString('#2D2D44'))
    $panel.Children.Add($progress) | Out-Null

    $statusText = New-Object System.Windows.Controls.TextBlock
    $statusText.FontSize = 13
    $statusText.TextWrapping = 'Wrap'
    $statusText.Foreground = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString('#A6ADC8'))
    $panel.Children.Add($statusText) | Out-Null

    $Global:SyncHash.SoftwareInstallBtn = $installBtn
    $Global:SyncHash.SoftwareProgress = $progress
    $Global:SyncHash.SoftwareStatusText = $statusText
    $Global:SyncHash.StatusText = $statusText

    # Install / Update button handler
    $installBtn.Add_Click({
        $selected = @()
        foreach ($cb in $Global:SyncHash.SoftwareCheckboxes) {
            if ($cb.IsChecked) {
                $selected += $cb.Tag
            }
        }

        if ($selected.Count -eq 0) {
            Write-Log 'No packages selected' -Level Warning
            return
        }

        $Global:SyncHash.SoftwareInstallBtn.IsEnabled = $false
        $Global:SyncHash.SoftwareProgress.IsIndeterminate = $true
        $Global:SyncHash.SoftwareStatusText.Text = "Processing $($selected.Count) package(s)..."

        # Serialize selected packages for the runspace
        $packageList = $selected | ForEach-Object { @{ Name = $_.Name; Id = $_.Id; Source = $_.Source; Path = $_.Path } }

        $rs = [runspacefactory]::CreateRunspace()
        $rs.ApartmentState = 'STA'
        $rs.Open()
        $rs.SessionStateProxy.SetVariable('SyncHash', $Global:SyncHash)
        $rs.SessionStateProxy.SetVariable('PackageList', $packageList)
        $rs.SessionStateProxy.SetVariable('IsSilent', $Global:SyncHash.SoftwareSilentCheckbox.IsChecked)

        $ps = [powershell]::Create()
        $ps.Runspace = $rs
        $ps.AddScript({
            $toolkitRoot = $SyncHash.Toolkit.Root
            Get-ChildItem -Path "$toolkitRoot\Core" -Filter '*.ps1' -File | ForEach-Object { . $_.FullName }
            Get-ChildItem -Path "$toolkitRoot\UI" -Filter '*.ps1' -File | ForEach-Object { . $_.FullName }

            $entry = @{
                Name = 'Software-Manager'; Label = 'Install / Update Software'
                StartTime = Get-Date; EndTime = $null; Status = 'Success'; Detail = ''
            }

            $total = $PackageList.Count
            $count = 0
            $failed = 0
            $skipped = 0

            # Check winget availability
            $wingetOk = $false
            try {
                $null = winget --version 2>$null
                $wingetOk = $true
            } catch { }

            # Snapshot current status for install/update decisions
            $pkgStatus = $SyncHash.SoftwarePackageStatus

            foreach ($pkg in $PackageList) {
                $count++

                # Determine action based on current status
                $info = if ($pkgStatus -and $pkgStatus.ContainsKey($pkg.Id)) { $pkgStatus[$pkg.Id] } else { $null }
                $currentStatus = if ($info) { $info.Status } else { 'NotInstalled' }

                if ($currentStatus -eq 'UpToDate') {
                    Write-Log "[$count/$total] $($pkg.Name) is already up to date - skipping" -Level Info
                    $skipped++
                    continue
                }

                $isUpdate = ($currentStatus -eq 'UpdateAvailable')
                $verb = if ($isUpdate) { 'Updating' } else { 'Installing' }
                $cmd = if ($isUpdate) { 'upgrade' } else { 'install' }

                Write-Log "[$count/$total] $verb $($pkg.Name)..." -Level Info
                Update-ActionStatus "$verb $($pkg.Name) ($count/$total)..." '#F9E2AF'

                if ($pkg.Source -eq 'winget') {
                    if (-not $wingetOk) {
                        Write-Log "  Skipped - winget not available" -Level Error
                        $failed++
                        continue
                    }
                    try {
                        $null = & winget $cmd --id $pkg.Id --accept-package-agreements --accept-source-agreements --silent --source winget 2>&1
                        $exitCode = $LASTEXITCODE
                        if ($exitCode -eq 0) {
                            $pastTense = if ($isUpdate) { 'updated' } else { 'installed' }
                            Write-Log "  $($pkg.Name) $pastTense successfully" -Level Success
                        } elseif ($exitCode -eq -1978335189) {
                            Write-Log "  $($pkg.Name) already installed" -Level Info
                        } else {
                            Write-Log "  $($pkg.Name) failed (exit code $exitCode)" -Level Error
                            $failed++
                        }
                    } catch {
                        Write-Log "  $($pkg.Name) error: $($_.Exception.Message)" -Level Error
                        $failed++
                    }

                } elseif ($pkg.Source -eq 'local') {
                    try {
                        if ($pkg.Path -match '\.msi$') {
                            $installArgs = if ($IsSilent) { "/i `"$($pkg.Path)`" /qn /norestart" } else { "/i `"$($pkg.Path)`" /norestart" }
                            $proc = Start-Process -FilePath "msiexec.exe" -ArgumentList $installArgs -Wait -PassThru
                        } else {
                            $installArgs = if ($IsSilent) { "/S", "/quiet", "/silent" } else { @() }
                            $proc = Start-Process -FilePath $pkg.Path -ArgumentList $installArgs -Wait -PassThru
                        }
                        if ($proc.ExitCode -eq 0 -or $proc.ExitCode -eq 3010) {
                            $pastTense = if ($isUpdate) { 'updated' } else { 'installed' }
                            Write-Log "  $($pkg.Name) $pastTense successfully" -Level Success
                        } else {
                            Write-Log "  $($pkg.Name) failed (exit code $($proc.ExitCode))" -Level Error
                            $failed++
                        }
                    } catch {
                        Write-Log "  $($pkg.Name) error: $($_.Exception.Message)" -Level Error
                        $failed++
                    }
                }
            }

            $processed = $total - $skipped
            if ($failed -gt 0) {
                $entry.Detail = "$failed of $processed failed"
                Write-Log "Software operation complete with $failed failure(s)" -Level Warning
            } elseif ($skipped -eq $total) {
                Write-Log "All $total package(s) already up to date" -Level Success
            } else {
                Write-Log "All $processed package(s) processed successfully ($skipped skipped)" -Level Success
            }

            $entry.EndTime = Get-Date
            $SyncHash.Window.Dispatcher.Invoke([action]{
                if ($SyncHash.Toolkit.Session) {
                    $SyncHash.Toolkit.Session.ModulesRun.Add($entry) | Out-Null
                }
                $SyncHash.SoftwareInstallBtn.IsEnabled = $true
                $SyncHash.SoftwareProgress.IsIndeterminate = $false
                $SyncHash.SoftwareStatusText.Text = ''
            })

            # Auto-refresh status badges after install/update
            $SyncHash.Window.Dispatcher.Invoke([action]{ Start-SoftwareStatusRefresh })
        }) | Out-Null
        $ps.BeginInvoke() | Out-Null
    })

    # Apply cached status if available, otherwise kick off initial query
    if ($Global:SyncHash.SoftwarePackageStatus -and $Global:SyncHash.SoftwarePackageStatus.Count -gt 0) {
        $loadingText.Visibility = 'Collapsed'
        $greenBrush = New-Object System.Windows.Media.SolidColorBrush(
            [System.Windows.Media.ColorConverter]::ConvertFromString('#A6E3A1'))
        $yellowBrush = New-Object System.Windows.Media.SolidColorBrush(
            [System.Windows.Media.ColorConverter]::ConvertFromString('#F9E2AF'))
        $grayBrush = New-Object System.Windows.Media.SolidColorBrush(
            [System.Windows.Media.ColorConverter]::ConvertFromString('#585B70'))
        $cached = $Global:SyncHash.SoftwarePackageStatus

        for ($i = 0; $i -lt $allStatusLabels.Count; $i++) {
            $lbl = $allStatusLabels[$i]
            $id  = $allCheckboxes[$i].Tag.Id
            $info = $cached[$id]

            if ($allCheckboxes[$i].Tag.Source -eq 'local') {
                $lbl.Text = ''
                continue
            }

            if (-not $info -or $info.Status -eq 'NotInstalled') {
                $lbl.Text = "$([char]0x25CB) Not installed"
                $lbl.Foreground = $grayBrush
            } elseif ($info.Status -eq 'UpToDate') {
                $ver = if ($info.CurrentVersion) { " (v$($info.CurrentVersion))" } else { '' }
                $lbl.Text = "$([char]0x25CF) Installed$ver"
                $lbl.Foreground = $greenBrush
            } elseif ($info.Status -eq 'UpdateAvailable') {
                $lbl.Text = "$([char]0x25CF) Update available ($($info.CurrentVersion) $([char]0x2192) $($info.AvailableVersion))"
                $lbl.Foreground = $yellowBrush
            }
        }
    } else {
        Start-SoftwareStatusRefresh
    }

    $scroll.Content = $panel
    return $scroll
}
