# Module: Network-Diagnostics.ps1

function Register-NetworkDiagnostics {
    @{
        Name         = 'Network-Diagnostics'
        Label        = 'Network Diagnostics'
        Description  = 'Connectivity tools and DNS health checks'
        RequiresAuth = $false
        SortOrder    = 30
        EntryPoint   = 'Start-NetworkDiagnostics'
        UIDefinition = 'Get-NetworkDiagnosticsUI'
    }
}

function Get-NetworkDiagnosticsUI {
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

    # Header
    $header = New-Object System.Windows.Controls.TextBlock
    $header.Text = 'Network Diagnostics'
    $header.FontSize = 22
    $header.FontWeight = 'Bold'
    $header.Foreground = $accentBrush
    $header.Margin = [System.Windows.Thickness]::new(0, 0, 0, 6)
    $panel.Children.Add($header) | Out-Null

    $desc = New-Object System.Windows.Controls.TextBlock
    $desc.Text = 'Connectivity tools and DNS health checks.'
    $desc.FontSize = 13
    $desc.Foreground = $dimBrush
    $desc.Margin = [System.Windows.Thickness]::new(0, 0, 0, 20)
    $desc.TextWrapping = 'Wrap'
    $panel.Children.Add($desc) | Out-Null

    # ===== NETWORK INFO (always visible) =====
    $infoLabel = New-Object System.Windows.Controls.Label
    $infoLabel.Content = 'NETWORK INFO'
    $infoLabel.FontWeight = 'Bold'
    $infoLabel.Margin = [System.Windows.Thickness]::new(0, 0, 0, 4)
    $panel.Children.Add($infoLabel) | Out-Null

    $infoBlock = New-Object System.Windows.Controls.TextBlock
    $infoBlock.FontSize = 13
    $infoBlock.Foreground = $textBrush
    $infoBlock.FontFamily = New-Object System.Windows.Media.FontFamily('Consolas')
    $infoBlock.Margin = [System.Windows.Thickness]::new(4, 0, 0, 20)
    $infoBlock.Text = 'Loading...'
    $panel.Children.Add($infoBlock) | Out-Null

    # Populate network info immediately
    try {
        $cfg = Get-NetIPConfiguration -ErrorAction SilentlyContinue |
            Where-Object { $_.IPv4DefaultGateway } | Select-Object -First 1
        $ip = if ($cfg.IPv4Address) { $cfg.IPv4Address.IPAddress } else { 'N/A' }
        $gw = if ($cfg.IPv4DefaultGateway) { $cfg.IPv4DefaultGateway.NextHop } else { 'N/A' }
        $dnsStr = if ($cfg.DNSServer) {
            ($cfg.DNSServer | Where-Object { $_.AddressFamily -eq 2 } | Select-Object -ExpandProperty ServerAddresses) -join ', '
        } else { 'N/A' }
        $adapterName = if ($cfg.InterfaceAlias) { $cfg.InterfaceAlias } else { 'N/A' }
        $mac = (Get-NetAdapter -Name $adapterName -ErrorAction SilentlyContinue).MacAddress
        $infoBlock.Text = "Adapter:  $adapterName`r`nIP:       $ip`r`nGateway:  $gw`r`nDNS:      $dnsStr`r`nMAC:      $mac"
    } catch {
        $infoBlock.Text = 'Could not detect network info'
    }

    # ===== QUICK CHECKS =====
    $checksLabel = New-Object System.Windows.Controls.Label
    $checksLabel.Content = 'QUICK CHECKS'
    $checksLabel.FontWeight = 'Bold'
    $checksLabel.Margin = [System.Windows.Thickness]::new(0, 0, 0, 8)
    $panel.Children.Add($checksLabel) | Out-Null

    $runAllBtn = New-Object System.Windows.Controls.Button
    $runAllBtn.Content = 'Run All Checks'
    $runAllBtn.Padding = [System.Windows.Thickness]::new(16, 8, 16, 8)
    $runAllBtn.FontWeight = 'Bold'
    $runAllBtn.Background = $accentBrush
    $runAllBtn.Foreground = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString('#1E1E2E'))
    $runAllBtn.Margin = [System.Windows.Thickness]::new(0, 0, 0, 12)
    $runAllBtn.HorizontalAlignment = 'Left'
    $panel.Children.Add($runAllBtn) | Out-Null

    # Result blocks for quick checks
    $checkNames = @('Internet Connectivity', 'DNS Resolution', 'Gateway Ping', 'DNS Server Ping', 'Public DNS Test', 'DHCP Status')
    $resultBlocks = @{}
    foreach ($name in $checkNames) {
        $tb = New-Object System.Windows.Controls.TextBlock
        $tb.Text = "  - $name"
        $tb.FontSize = 13
        $tb.Foreground = $dimBrush
        $tb.Margin = [System.Windows.Thickness]::new(4, 3, 0, 3)
        $panel.Children.Add($tb) | Out-Null
        $resultBlocks[$name] = $tb
    }
    $Global:SyncHash.NetDiagResults = $resultBlocks

    $spacer = New-Object System.Windows.Controls.Border
    $spacer.Height = 20
    $panel.Children.Add($spacer) | Out-Null

    # ===== TOOLS =====
    $toolsLabel = New-Object System.Windows.Controls.Label
    $toolsLabel.Content = 'TOOLS'
    $toolsLabel.FontWeight = 'Bold'
    $toolsLabel.Margin = [System.Windows.Thickness]::new(0, 0, 0, 8)
    $panel.Children.Add($toolsLabel) | Out-Null

    # Ping tool
    $pingRow = New-Object System.Windows.Controls.StackPanel
    $pingRow.Orientation = 'Horizontal'
    $pingRow.Margin = [System.Windows.Thickness]::new(0, 0, 0, 8)

    $pingInput = New-Object System.Windows.Controls.TextBox
    $pingInput.Width = 250
    $pingInput.Height = 30
    $pingInput.FontSize = 13
    $pingInput.Text = '8.8.8.8'
    $pingInput.VerticalContentAlignment = 'Center'
    $pingInput.Padding = [System.Windows.Thickness]::new(6, 0, 6, 0)
    $pingRow.Children.Add($pingInput) | Out-Null

    $pingBtn = New-Object System.Windows.Controls.Button
    $pingBtn.Content = 'Ping'
    $pingBtn.Padding = [System.Windows.Thickness]::new(16, 6, 16, 6)
    $pingBtn.Margin = [System.Windows.Thickness]::new(8, 0, 0, 0)
    $pingRow.Children.Add($pingBtn) | Out-Null

    $panel.Children.Add($pingRow) | Out-Null

    # DNS Lookup tool
    $dnsRow = New-Object System.Windows.Controls.StackPanel
    $dnsRow.Orientation = 'Horizontal'
    $dnsRow.Margin = [System.Windows.Thickness]::new(0, 0, 0, 8)

    $dnsInput = New-Object System.Windows.Controls.TextBox
    $dnsInput.Width = 250
    $dnsInput.Height = 30
    $dnsInput.FontSize = 13
    $dnsInput.Text = 'google.com'
    $dnsInput.VerticalContentAlignment = 'Center'
    $dnsInput.Padding = [System.Windows.Thickness]::new(6, 0, 6, 0)
    $dnsRow.Children.Add($dnsInput) | Out-Null

    $dnsBtn = New-Object System.Windows.Controls.Button
    $dnsBtn.Content = 'DNS Lookup'
    $dnsBtn.Padding = [System.Windows.Thickness]::new(16, 6, 16, 6)
    $dnsBtn.Margin = [System.Windows.Thickness]::new(8, 0, 0, 0)
    $dnsRow.Children.Add($dnsBtn) | Out-Null

    $panel.Children.Add($dnsRow) | Out-Null

    # Port test tool
    $portRow = New-Object System.Windows.Controls.StackPanel
    $portRow.Orientation = 'Horizontal'
    $portRow.Margin = [System.Windows.Thickness]::new(0, 0, 0, 8)

    $portHostInput = New-Object System.Windows.Controls.TextBox
    $portHostInput.Width = 180
    $portHostInput.Height = 30
    $portHostInput.FontSize = 13
    $portHostInput.Text = '8.8.8.8'
    $portHostInput.VerticalContentAlignment = 'Center'
    $portHostInput.Padding = [System.Windows.Thickness]::new(6, 0, 6, 0)
    $portRow.Children.Add($portHostInput) | Out-Null

    $portLabel = New-Object System.Windows.Controls.TextBlock
    $portLabel.Text = ' : '
    $portLabel.FontSize = 14
    $portLabel.Foreground = $dimBrush
    $portLabel.VerticalAlignment = 'Center'
    $portRow.Children.Add($portLabel) | Out-Null

    $portNumInput = New-Object System.Windows.Controls.TextBox
    $portNumInput.Width = 60
    $portNumInput.Height = 30
    $portNumInput.FontSize = 13
    $portNumInput.Text = '443'
    $portNumInput.VerticalContentAlignment = 'Center'
    $portNumInput.Padding = [System.Windows.Thickness]::new(6, 0, 6, 0)
    $portRow.Children.Add($portNumInput) | Out-Null

    $portBtn = New-Object System.Windows.Controls.Button
    $portBtn.Content = 'Test Port'
    $portBtn.Padding = [System.Windows.Thickness]::new(16, 6, 16, 6)
    $portBtn.Margin = [System.Windows.Thickness]::new(8, 0, 0, 0)
    $portRow.Children.Add($portBtn) | Out-Null

    $panel.Children.Add($portRow) | Out-Null

    # Network Connections
    $ncpaBtn = New-Object System.Windows.Controls.Button
    $ncpaBtn.Content = 'Network Connections'
    $ncpaBtn.Padding = [System.Windows.Thickness]::new(16, 6, 16, 6)
    $ncpaBtn.Margin = [System.Windows.Thickness]::new(0, 0, 0, 8)
    $ncpaBtn.HorizontalAlignment = 'Left'
    $panel.Children.Add($ncpaBtn) | Out-Null

    # Release and Renew
    $releaseRenewBtn = New-Object System.Windows.Controls.Button
    $releaseRenewBtn.Content = 'Release & Renew IP'
    $releaseRenewBtn.Padding = [System.Windows.Thickness]::new(16, 6, 16, 6)
    $releaseRenewBtn.Margin = [System.Windows.Thickness]::new(0, 0, 0, 8)
    $releaseRenewBtn.HorizontalAlignment = 'Left'
    $panel.Children.Add($releaseRenewBtn) | Out-Null
    $Global:SyncHash.ReleaseRenewBtn = $releaseRenewBtn

    # ===== NETWORK SCANNER =====
    $scannerLabel = New-Object System.Windows.Controls.Label
    $scannerLabel.Content = 'NETWORK SCANNER'
    $scannerLabel.FontWeight = 'Bold'
    $scannerLabel.Margin = [System.Windows.Thickness]::new(0, 20, 0, 4)
    $panel.Children.Add($scannerLabel) | Out-Null

    $scannerDesc = New-Object System.Windows.Controls.TextBlock
    $scannerDesc.Text = 'Scan a range of IP addresses to discover active devices on the network.'
    $scannerDesc.FontSize = 13
    $scannerDesc.Foreground = $dimBrush
    $scannerDesc.Margin = [System.Windows.Thickness]::new(0, 0, 0, 10)
    $scannerDesc.TextWrapping = 'Wrap'
    $panel.Children.Add($scannerDesc) | Out-Null

    $scanInputRow = New-Object System.Windows.Controls.Grid
    $scanInputRow.Margin = [System.Windows.Thickness]::new(0, 0, 0, 8)
    $scanInputRow.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{ Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star) }))
    $scanInputRow.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{ Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Auto) }))

    $ipRangeInput = New-Object System.Windows.Controls.TextBox
    $ipRangeInput.Height = 30
    $ipRangeInput.FontSize = 13
    $ipRangeInput.VerticalContentAlignment = 'Center'
    $ipRangeInput.Padding = [System.Windows.Thickness]::new(6, 0, 6, 0)
    [System.Windows.Controls.Grid]::SetColumn($ipRangeInput, 0)
    $scanInputRow.Children.Add($ipRangeInput) | Out-Null

    # Auto-populate IP range
    $defaultIpRange = '192.168.1.1-254' # Fallback
    try {
        $netConfig = Get-NetIPConfiguration -ErrorAction SilentlyContinue | Where-Object { $_.IPv4DefaultGateway } | Select-Object -First 1
        if ($netConfig) {
            $ipAddress = $netConfig.IPv4Address.IPAddress
            if ($ipAddress.Contains('.')) {
                $baseIp = ($ipAddress.Split('.')[0..2]) -join '.'
                $defaultIpRange = "$baseIp.1-254"
            }
        }
    } catch {}
    $ipRangeInput.Text = $defaultIpRange

    $scanBtn = New-Object System.Windows.Controls.Button
    $scanBtn.Content = 'Scan Network'
    $scanBtn.Padding = [System.Windows.Thickness]::new(16, 6, 16, 6)
    $scanBtn.Margin = [System.Windows.Thickness]::new(8, 0, 0, 0)
    [System.Windows.Controls.Grid]::SetColumn($scanBtn, 1)
    $scanInputRow.Children.Add($scanBtn) | Out-Null

    $panel.Children.Add($scanInputRow) | Out-Null

    $ouiRow = New-Object System.Windows.Controls.Grid
    $ouiRow.Margin = [System.Windows.Thickness]::new(0, 0, 0, 8)
    $ouiRow.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{ Width = [System.Windows.GridLength]::Auto }))
    $ouiRow.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{ Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star) }))

    $updateOuiBtn = New-Object System.Windows.Controls.Button
    $updateOuiBtn.Content = 'Update Vendor List'
    $updateOuiBtn.Padding = [System.Windows.Thickness]::new(16, 6, 16, 6)
    [System.Windows.Controls.Grid]::SetColumn($updateOuiBtn, 0)
    $ouiRow.Children.Add($updateOuiBtn) | Out-Null

    $ouiStatusText = New-Object System.Windows.Controls.TextBlock
    $ouiStatusText.FontSize = 12
    $ouiStatusText.Foreground = $dimBrush
    $ouiStatusText.Margin = [System.Windows.Thickness]::new(8, 0, 0, 0)
    $ouiStatusText.VerticalAlignment = 'Center'
    [System.Windows.Controls.Grid]::SetColumn($ouiStatusText, 1)
    $ouiRow.Children.Add($ouiStatusText) | Out-Null

    $panel.Children.Add($ouiRow) | Out-Null

    $scanStatusText = New-Object System.Windows.Controls.TextBlock
    $scanStatusText.FontSize = 12
    $scanStatusText.Foreground = $dimBrush
    $scanStatusText.Margin = [System.Windows.Thickness]::new(0, 4, 0, 2)
    $panel.Children.Add($scanStatusText) | Out-Null

    $scanProgressBar = New-Object System.Windows.Controls.ProgressBar
    $scanProgressBar.Height = 8
    $scanProgressBar.Margin = [System.Windows.Thickness]::new(0, 0, 0, 10)
    $scanProgressBar.Visibility = 'Collapsed'
    $panel.Children.Add($scanProgressBar) | Out-Null

    $scanResultsView = New-Object System.Windows.Controls.ListView
    $scanResultsView.Height = 250
    $scanResultsView.Background = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString('#181825')) # Slightly darker than main background
    $scanResultsView.Foreground = $textBrush

    $gridView = New-Object System.Windows.Controls.GridView
    $gridView.Columns.Add((New-Object System.Windows.Controls.GridViewColumn -Property @{
        Header = 'Status'; DisplayMemberBinding = (New-Object System.Windows.Data.Binding 'Status'); Width = 50 }))
    $gridView.Columns.Add((New-Object System.Windows.Controls.GridViewColumn -Property @{
        Header = 'IP Address'; DisplayMemberBinding = (New-Object System.Windows.Data.Binding 'IPAddress'); Width = 110 }))
    $gridView.Columns.Add((New-Object System.Windows.Controls.GridViewColumn -Property @{
        Header = 'Hostname'; DisplayMemberBinding = (New-Object System.Windows.Data.Binding 'Hostname'); Width = 150 }))
    $gridView.Columns.Add((New-Object System.Windows.Controls.GridViewColumn -Property @{
        Header = 'MAC Address'; DisplayMemberBinding = (New-Object System.Windows.Data.Binding 'MACAddress'); Width = 110 }))
    $gridView.Columns.Add((New-Object System.Windows.Controls.GridViewColumn -Property @{
        Header = 'Vendor'; DisplayMemberBinding = (New-Object System.Windows.Data.Binding 'Vendor'); Width = 120 }))
    $gridView.Columns.Add((New-Object System.Windows.Controls.GridViewColumn -Property @{
        Header = 'Response'; DisplayMemberBinding = (New-Object System.Windows.Data.Binding 'ResponseTime'); Width = 70 }))
    $scanResultsView.View = $gridView

    $panel.Children.Add($scanResultsView) | Out-Null

    $Global:SyncHash.Scanner = @{
        IpRangeInput  = $ipRangeInput
        ScanBtn       = $scanBtn
        StatusText    = $scanStatusText
        ProgressBar   = $scanProgressBar
        ResultsView   = $scanResultsView
        UpdateOuiBtn  = $updateOuiBtn
        OuiStatusText = $ouiStatusText
        IpsToScan     = $null
        SortColumn       = $null
        SortDirection    = 'Ascending'
        LastSortedHeader = $null
    }

    # ===== EVENT HANDLERS =====

    # ListView Column Header Click for Sorting
    $scanResultsView.AddHandler([System.Windows.Controls.GridViewColumnHeader]::ClickEvent, [System.Windows.RoutedEventHandler]{
        param($eventSender, $e)

        $headerClicked = $e.OriginalSource
        if (-not ($headerClicked -is [System.Windows.Controls.GridViewColumnHeader])) { return }

        $sortBy = $headerClicked.Column.DisplayMemberBinding.Path.Path
        if ([string]::IsNullOrEmpty($sortBy)) { return }

        $direction = [System.ComponentModel.ListSortDirection]::Ascending
        if ($Global:SyncHash.Scanner.SortColumn -eq $sortBy -and $Global:SyncHash.Scanner.SortDirection -eq 'Ascending') {
            $direction = [System.ComponentModel.ListSortDirection]::Descending
        }

        $view = [System.Windows.Data.CollectionViewSource]::GetDefaultView($Global:SyncHash.Scanner.ResultsView.Items)
        if ($view) {
            $view.SortDescriptions.Clear()
            $view.SortDescriptions.Add((New-Object System.ComponentModel.SortDescription($sortBy, $direction)))
            $view.Refresh()
        }

        if ($Global:SyncHash.Scanner.LastSortedHeader) {
            $Global:SyncHash.Scanner.LastSortedHeader.Column.Header = $Global:SyncHash.Scanner.LastSortedHeader.Column.Header.ToString() -replace ' (▲|▼)$'
        }

        $arrow = if ($direction -eq [System.ComponentModel.ListSortDirection]::Ascending) { '▲' } else { '▼' }
        $headerClicked.Column.Header = "$($headerClicked.Column.Header) $arrow"

        $Global:SyncHash.Scanner.SortColumn = $sortBy
        $Global:SyncHash.Scanner.SortDirection = if ($direction -eq [System.ComponentModel.ListSortDirection]::Ascending) { 'Ascending' } else { 'Descending' }
        $Global:SyncHash.Scanner.LastSortedHeader = $headerClicked
    }.GetNewClosure())

    # Ping button
    $pingBtn.Add_Click({
        $target = $pingInput.Text.Trim()
        if (-not $target) { return }
        Write-Log "Pinging $target..." -Level Info
        try {
            $result = Test-Connection -ComputerName $target -Count 4 -ErrorAction Stop
            foreach ($r in $result) {
                Write-Log "  Reply from $target - ${($r.ResponseTime)}ms" -Level Success
            }
        } catch {
            Write-Log "  Ping failed: $($_.Exception.Message)" -Level Error
        }
    }.GetNewClosure())

    # DNS Lookup button
    $dnsBtn.Add_Click({
        $target = $dnsInput.Text.Trim()
        if (-not $target) { return }
        Write-Log "Resolving $target..." -Level Info
        try {
            $results = Resolve-DnsName -Name $target -ErrorAction Stop
            foreach ($r in $results) {
                if ($r.IPAddress) {
                    Write-Log "  $($r.Name) -> $($r.IPAddress) ($($r.Type))" -Level Success
                } elseif ($r.NameHost) {
                    Write-Log "  $($r.Name) -> $($r.NameHost) ($($r.Type))" -Level Success
                }
            }
        } catch {
            Write-Log "  DNS lookup failed: $($_.Exception.Message)" -Level Error
        }
    }.GetNewClosure())

    # Port test button
    $portBtn.Add_Click({
        $host_ = $portHostInput.Text.Trim()
        $port = $portNumInput.Text.Trim()
        if (-not $host_ -or -not $port) { return }
        Write-Log "Testing ${host_}:${port}..." -Level Info
        try {
            $result = Test-NetConnection -ComputerName $host_ -Port ([int]$port) -WarningAction SilentlyContinue
            if ($result.TcpTestSucceeded) {
                Write-Log "  ${host_}:${port} is OPEN (${($result.PingReplyDetails.RoundtripTime)}ms)" -Level Success
            } else {
                Write-Log "  ${host_}:${port} is CLOSED or filtered" -Level Error
            }
        } catch {
            Write-Log "  Port test failed: $($_.Exception.Message)" -Level Error
        }
    }.GetNewClosure())

    # Network Connections button
    $ncpaBtn.Add_Click({
        Write-Log "Opening Network Connections (ncpa.cpl)." -Level Info
        Start-Process "ncpa.cpl"
    }.GetNewClosure())

    # Release and Renew button
    $releaseRenewBtn.Add_Click({
        $Global:SyncHash.ReleaseRenewBtn.IsEnabled = $false
        $Global:SyncHash.ReleaseRenewBtn.Content = 'Releasing & Renewing...'

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

            try {
                Write-Log "Releasing IP address..." -Level Info
                ipconfig /release | Out-Null
                Write-Log "Renewing IP address..." -Level Info
                $out = ipconfig /renew | Out-String
                if ($out -match "IPv4 Address" -or $out -match "IP Address") {
                    Write-Log "IP address renewed successfully." -Level Success
                } else {
                    Write-Log "IP address renew completed, but check connection." -Level Warn
                }
            } catch {
                Write-Log "Error during release/renew: $($_.Exception.Message)" -Level Error
            } finally {
                $SyncHash.Window.Dispatcher.Invoke([action]{
                    $SyncHash.ReleaseRenewBtn.IsEnabled = $true
                    $SyncHash.ReleaseRenewBtn.Content = 'Release & Renew IP'
                })
            }
        }) | Out-Null
        $ps.BeginInvoke() | Out-Null
    }.GetNewClosure())

    # Initial OUI status
    $vendorFilePath = Join-Path $Global:SyncHash.Toolkit.Root 'Modules\Module Resources\manuf.txt'
    if (Test-Path $vendorFilePath) {
        $lastWrite = (Get-Item $vendorFilePath).LastWriteTime
        $ouiStatusText.Text = "Vendor list last updated: $lastWrite"
    } else {
        $ouiStatusText.Text = 'Vendor list not found. Click the button to download.'
    }

    # OUI Update action
    $updateOuiAction = {
        $Global:SyncHash.Scanner.UpdateOuiBtn.IsEnabled = $false
        $Global:SyncHash.Scanner.OuiStatusText.Text = 'Downloading vendor list...'

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

            $vendorFileDir = Join-Path $SyncHash.Toolkit.Root 'Modules\Module Resources'
            if (-not (Test-Path $vendorFileDir)) {
                New-Item -Path $vendorFileDir -ItemType Directory -Force | Out-Null
            }
            $vendorFilePath = Join-Path $vendorFileDir 'manuf.txt'

            # Use Wireshark's automated build OUI list (bypasses IEEE's strict bot blocking)
            $url = 'https://www.wireshark.org/download/automated/data/manuf'
            try {
                # Force TLS 1.2 for secure download
                [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

                $userAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'
                Invoke-WebRequest -Uri $url -OutFile $vendorFilePath -UseBasicParsing -UserAgent $userAgent -ErrorAction Stop
                $lastWrite = (Get-Item $vendorFilePath).LastWriteTime

                # Clean up old CSV if it exists
                $oldCsv = Join-Path $SyncHash.Toolkit.Root 'oui.csv'
                if (Test-Path $oldCsv) { Remove-Item -Path $oldCsv -Force -ErrorAction SilentlyContinue }

                # Clean up old manuf file from root if it was placed there previously
                $oldManuf = Join-Path $SyncHash.Toolkit.Root 'manuf.txt'
                if (Test-Path $oldManuf) { Remove-Item -Path $oldManuf -Force -ErrorAction SilentlyContinue }

                # Clean up old manuf file from Modules folder if it was placed there previously
                $oldManufInModules = Join-Path $SyncHash.Toolkit.Root 'Modules\manuf.txt'
                if (Test-Path $oldManufInModules) { Remove-Item -Path $oldManufInModules -Force -ErrorAction SilentlyContinue }

                $SyncHash.Window.Dispatcher.Invoke([action]{
                    $SyncHash.Scanner.OuiStatusText.Text = "Update successful. Last updated: $lastWrite"
                })
                Write-Log "Successfully downloaded vendor list." -Level Success
            } catch {
                $SyncHash.Window.Dispatcher.Invoke([action]{
                    $SyncHash.Scanner.OuiStatusText.Text = "Error downloading list: $($_.Exception.Message)"
                })
                Write-Log "Failed to download vendor list: $($_.Exception.Message)" -Level Error
            } finally {
                $SyncHash.Window.Dispatcher.Invoke([action]{
                    $SyncHash.Scanner.UpdateOuiBtn.IsEnabled = $true
                })
            }
        }) | Out-Null
        $ps.BeginInvoke() | Out-Null
    }.GetNewClosure()

    $updateOuiBtn.Add_Click($updateOuiAction)

    # Automatically attempt update once per session
    if (-not $Global:SyncHash.OuiUpdatedThisSession) {
        $Global:SyncHash.OuiUpdatedThisSession = $true
        & $updateOuiAction
    }

    # Network Scan button
    $scanBtn.Add_Click({
        $rangeText = $Global:SyncHash.Scanner.IpRangeInput.Text.Trim()
        $ipsToScan = [System.Collections.ArrayList]::new()
        try {
            if ($rangeText -match '^((\d{1,3}\.){3})(\d{1,3})-(\d{1,3})$') {
                $baseIp = $matches[1]
                $start = [int]$matches[3]
                $end = [int]$matches[4]
                if ($start -le $end -and $start -ge 0 -and $end -le 255) {
                    for ($i = $start; $i -le $end; $i++) {
                        $ipsToScan.Add("$baseIp$i") | Out-Null
                    }
                }
            }
            if ($ipsToScan.Count -eq 0) { throw "Invalid range format. Use e.g. 192.168.1.1-254" }
        } catch {
            $Global:SyncHash.Scanner.StatusText.Text = "Error: $($_.Exception.Message)"
            return
        }

        # Prepare MAC vendor list (always starts with built-in list)
        $macVendors = @{
            '000393'='Apple'; '000A27'='Apple'; '000A95'='Apple'; '0016CB'='Apple';
            '001F5B'='Apple'; '002500'='Apple'; '3C5AB4'='Apple'; 'A0A3B3'='Apple';
            '000C29'='VMware'; '005056'='VMware'; '080027'='Oracle (VirtualBox)';
            'CC46D6'='Cisco'; '00127F'='Cisco'; '001469'='Cisco';
            '001A2A'='Dell'; '001788'='Dell'; '180373'='Dell'; 'B88584'='Dell';
            '9CFC84'='HP'; '3C5282'='HP'; '10604B'='HP';
            'E8B1FC'='Intel'; 'D4F4E1'='Intel'; '40F201'='Intel'; 'A434D9'='Intel';
            '00E04C'='Realtek'; '0000E8'='Realtek';
            'B42E99'='Broadcom'; '001018'='Broadcom';
            '0024D7'='Asus'; '107B44'='Asus';
            '18C04D'='Amazon'; '74C63F'='Amazon';
            'B827EB'='Raspberry Pi'; 'DCA632'='Raspberry Pi';
            'F8E43B'='Ubiquiti'; '44D9E7'='Ubiquiti';
            '00155D'='Microsoft'; 'C0335E'='Microsoft';
            'E02CB9'='Google'; '3C5C07'='Google'
        }

        $vendorFilePath = Join-Path $Global:SyncHash.Toolkit.Root 'Modules\Module Resources\manuf.txt'
        if (Test-Path $vendorFilePath) {
            try {
                $lines = [System.IO.File]::ReadLines($vendorFilePath)
                $count = 0
                foreach ($line in $lines) {
                    if ([string]::IsNullOrWhiteSpace($line) -or $line.StartsWith('#')) { continue }
                    $parts = $line -split "`t"
                    if ($parts.Count -ge 2) {
                        $prefix = ($parts[0] -replace ':', '').Trim().ToUpper()
                        if ($prefix.Length -eq 6) {
                            $vendorName = $parts[1].Trim()
                            if ($parts.Count -ge 3 -and -not [string]::IsNullOrWhiteSpace($parts[2])) { $vendorName = $parts[2].Trim() }
                            $macVendors[$prefix] = $vendorName
                            $count++
                        }
                    }
                }
                Write-Log "Loaded $count vendors from manuf.txt" -Level Info
            } catch {
                Write-Log "Error reading manuf.txt: $($_.Exception.Message). Using built-in list." -Level Warn
            }
        }

        $Global:SyncHash.Scanner.ScanBtn.IsEnabled = $false
        $Global:SyncHash.Scanner.ScanBtn.Content = 'Scanning...'
        $Global:SyncHash.Scanner.ResultsView.Items.Clear()
        $Global:SyncHash.Scanner.ProgressBar.Maximum = $ipsToScan.Count
        $Global:SyncHash.Scanner.ProgressBar.Value = 0
        $Global:SyncHash.Scanner.ProgressBar.Visibility = 'Visible'
        $Global:SyncHash.Scanner.StatusText.Text = "Preparing to scan $($ipsToScan.Count) hosts..."
        $Global:SyncHash.Scanner.IpsToScan = $ipsToScan

        $rs = [runspacefactory]::CreateRunspace()
        $rs.ApartmentState = 'STA'
        $rs.Open()
        $rs.SessionStateProxy.SetVariable('SyncHash', $Global:SyncHash)
        $rs.SessionStateProxy.SetVariable('MacVendors', $macVendors)

        $ps = [powershell]::Create()
        $ps.Runspace = $rs
        $ps.AddScript({
            $ipsToScan = $SyncHash.Scanner.IpsToScan
            $macVendors = $MacVendors
            $workerScript = {
                param($ip, $localMacVendors)

                $ping = $null
                try {
                    $ping = [System.Net.NetworkInformation.Ping]::new()
                    $reply = $ping.Send($ip, 1000)

                    # Get all IPv4 neighbors for this IP to avoid grabbing invalid ones (like 00-00-00-00-00-00)
                    $neighbors = Get-NetNeighbor -IPAddress $ip -AddressFamily IPv4 -ErrorAction SilentlyContinue
                    $validNeighbor = $neighbors | Where-Object {
                        $c = $_.LinkLayerAddress -replace '[^a-fA-F0-9]', ''
                        $c.Length -eq 12 -and $c -ne '000000000000' -and $c -ne 'FFFFFFFFFFFF'
                    } | Select-Object -First 1

                    $arpAlive = $null -ne $validNeighbor -and $validNeighbor.State -match 'Reachable|Stale|Delay|Probe|Permanent'

                    # Fallback: Parse `arp -a` in case Get-NetNeighbor misses it on certain network interfaces
                    $legacyMac = ''
                    if (-not $arpAlive -and $reply.Status -ne 'Success') {
                        $arpOut = arp -a $ip 2>$null
                        if ($arpOut) {
                            $match = $arpOut | Select-String -Pattern "^\s*$([regex]::Escape($ip))\s+([0-9a-fA-F\-]{17})\s+"
                            if ($match) {
                                $macFound = $match.Matches[0].Groups[2].Value
                                $c = $macFound -replace '[^a-fA-F0-9]', ''
                                if ($c.Length -eq 12 -and $c -ne '000000000000' -and $c -ne 'FFFFFFFFFFFF') {
                                    $legacyMac = $c.ToUpper()
                                    $arpAlive = $true
                                }
                            }
                        }
                    }

                    if ($reply.Status -eq 'Success' -or $arpAlive) {
                        # 1. Get Hostname (try .NET DNS, fallback to timed NetBIOS query)
                        $hostname = ''
                        try { $hostname = ([System.Net.Dns]::GetHostEntry($ip).HostName).Split('.')[0] } catch {}

                        if ([string]::IsNullOrEmpty($hostname) -or $hostname -eq $ip) {
                            try {
                                # nbtstat can hang, so run it in a job with a timeout
                                $job = Start-Job -ScriptBlock { param($targetIp) nbtstat -A $targetIp } -ArgumentList $ip
                                if (Wait-Job $job -Timeout 3) {
                                    $nbtstatResult = Receive-Job $job
                                    $nameLine = $nbtstatResult | Select-String -Pattern '\s+<00>\s+UNIQUE\s+Registered' -List | Select-Object -First 1
                                    if ($nameLine) { $hostname = ($nameLine.Line.Trim() -split '\s+')[0] }
                                }
                                Remove-Job $job -Force
                            } catch {}
                        }

                        # 2. Get MAC and Vendor
                        $mac = ''
                        if ($validNeighbor) {
                            $mac = ($validNeighbor.LinkLayerAddress -replace '[^a-fA-F0-9]', '').ToUpper()
                        } elseif ($legacyMac) {
                            $mac = $legacyMac
                        } elseif ($reply.Status -eq 'Success') {
                            try {
                                $n2 = Get-NetNeighbor -IPAddress $ip -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object {
                                    $c = $_.LinkLayerAddress -replace '[^a-fA-F0-9]', ''
                                    $c.Length -eq 12 -and $c -ne '000000000000' -and $c -ne 'FFFFFFFFFFFF'
                                } | Select-Object -First 1
                                if ($n2) {
                                    $mac = ($n2.LinkLayerAddress -replace '[^a-fA-F0-9]', '').ToUpper()
                                } else {
                                    $arpOut2 = arp -a $ip 2>$null
                                    $match2 = $arpOut2 | Select-String -Pattern "^\s*$([regex]::Escape($ip))\s+([0-9a-fA-F\-]{17})\s+"
                                    if ($match2) {
                                        $c2 = $match2.Matches[0].Groups[2].Value -replace '[^a-fA-F0-9]', ''
                                        if ($c2.Length -eq 12 -and $c2 -ne '000000000000' -and $c2 -ne 'FFFFFFFFFFFF') { $mac = $c2.ToUpper() }
                                    }
                                }
                            } catch {}
                        }

                        $vendor = ''
                        if ($mac.Length -ge 6 -and $localMacVendors) {
                            $oui = $mac.Substring(0, 6)
                            $vendorMatch = $localMacVendors[$oui]
                            if ($vendorMatch) { $vendor = $vendorMatch }
                        }

                        return [PSCustomObject]@{
                            Status       = if ($reply.Status -eq 'Success') { 'Up' } else { 'ARP' }
                            IPAddress    = $ip
                            Hostname     = if ([string]::IsNullOrEmpty($hostname) -or $hostname -eq $ip) { '<unknown>' } else { $hostname }
                            MACAddress   = if ([string]::IsNullOrEmpty($mac)) { '<unknown>' } else { $mac }
                            Vendor       = if ([string]::IsNullOrEmpty($vendor)) { '<unknown>' } else { $vendor }
                            ResponseTime = if ($reply.Status -eq 'Success') { "$($reply.RoundtripTime)ms" } else { '-' }
                        }
                    }
                } catch {}
                finally {
                    if ($ping) { $ping.Dispose() }
                }
                return $null
            }

            $pool = [runspacefactory]::CreateRunspacePool(1, 50)
            $pool.Open()
            $tasks = [System.Collections.ArrayList]::new()

            foreach ($ip in $ipsToScan) {
                $p = [powershell]::Create()
                $p.RunspacePool = $pool
                $p.AddScript($workerScript).AddArgument($ip).AddArgument($macVendors) | Out-Null
                $tasks.Add(@{ PS = $p; AsyncResult = $p.BeginInvoke() }) | Out-Null
            }

            $total = $tasks.Count
            $completed = 0
            $found = 0

            while ($tasks.Count -gt 0) {
                $i = $tasks.Count - 1
                while ($i -ge 0) {
                    $taskInfo = $tasks[$i]
                    if ($taskInfo.AsyncResult.IsCompleted) {
                        $psInstance = $taskInfo.PS
                        try {
                            $results = $psInstance.EndInvoke($taskInfo.AsyncResult)
                            if ($results) {
                                foreach ($res in $results) {
                                    $found++
                                    $SyncHash.Window.Dispatcher.Invoke([action]{
                                        $SyncHash.Scanner.ResultsView.Items.Add($res) | Out-Null
                                    })
                                }
                            }
                        } catch {}
                        finally {
                            $psInstance.Dispose()
                            $tasks.RemoveAt($i)
                            $completed++
                        }
                    }
                    $i--
                }

                $SyncHash.Window.Dispatcher.Invoke([action]{
                    $SyncHash.Scanner.ProgressBar.Value = $completed
                    $SyncHash.Scanner.StatusText.Text = "Scanning... ($completed / $total completed, $found found)"
                })
                Start-Sleep -Milliseconds 100
            }

            $pool.Close()
            $pool.Dispose()

            $SyncHash.Window.Dispatcher.Invoke([action]{
                $SyncHash.Scanner.StatusText.Text = "Scan complete. Found $found devices."
                $SyncHash.Scanner.ProgressBar.Visibility = 'Collapsed'
                $SyncHash.Scanner.ScanBtn.IsEnabled = $true
                $SyncHash.Scanner.ScanBtn.Content = 'Scan Network'
            })
        }).GetNewClosure()
        $ps.BeginInvoke() | Out-Null
    }.GetNewClosure())

    # Run All Checks button
    $runAllBtn.Add_Click({
        $runAllBtn.IsEnabled = $false
        $runAllBtn.Content = 'Running...'

        foreach ($key in $Global:SyncHash.NetDiagResults.Keys) {
            $Global:SyncHash.NetDiagResults[$key].Text = "  ... $key"
            $Global:SyncHash.NetDiagResults[$key].Foreground = $dimBrush
        }

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

            $green = '#A6E3A1'
            $red = '#F38BA8'
            $yellow = '#F9E2AF'

            $setResult = {
                param([string]$Name, [string]$Text, [string]$Color)
                $SyncHash.Window.Dispatcher.Invoke([action]{
                    $tb = $SyncHash.NetDiagResults[$Name]
                    if ($tb) {
                        $tb.Text = $Text
                        $tb.Foreground = New-Object System.Windows.Media.SolidColorBrush(
                            [System.Windows.Media.ColorConverter]::ConvertFromString($Color))
                    }
                })
            }

            # 1. Internet
            try {
                $r = Test-NetConnection -ComputerName '8.8.8.8' -Port 443 -WarningAction SilentlyContinue
                if ($r.TcpTestSucceeded) {
                    & $setResult 'Internet Connectivity' "$([char]0x2713)  Internet: 8.8.8.8:443 reachable" $green
                } else {
                    & $setResult 'Internet Connectivity' "$([char]0x2717)  Internet: 8.8.8.8:443 not reachable" $red
                }
            } catch { & $setResult 'Internet Connectivity' "$([char]0x2717)  Internet: Failed" $red }

            # 2. DNS Resolution
            try {
                $d = Resolve-DnsName 'google.com' -Type A -ErrorAction Stop | Select-Object -First 1
                & $setResult 'DNS Resolution' "$([char]0x2713)  DNS: google.com -> $($d.IPAddress)" $green
            } catch { & $setResult 'DNS Resolution' "$([char]0x2717)  DNS: Failed to resolve google.com" $red }

            # 3. Gateway
            try {
                $gw = (Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction Stop | Select-Object -First 1).NextHop
                $p = Test-Connection -ComputerName $gw -Count 1 -ErrorAction Stop
                & $setResult 'Gateway Ping' "$([char]0x2713)  Gateway: $gw ($($p.ResponseTime)ms)" $green
            } catch { & $setResult 'Gateway Ping' "$([char]0x2717)  Gateway: Failed" $red }

            # 4. DNS Server
            try {
                $servers = (Get-DnsClientServerAddress -AddressFamily IPv4 -ErrorAction Stop |
                    Where-Object { $_.ServerAddresses } | Select-Object -ExpandProperty ServerAddresses -First 2) | Select-Object -Unique
                $detail = ($servers | ForEach-Object { try { $p = Test-Connection $_ -Count 1 -ErrorAction Stop; "$_ ($($p.ResponseTime)ms)" } catch { "$_ (fail)" } }) -join ', '
                & $setResult 'DNS Server Ping' "$([char]0x2713)  DNS Servers: $detail" $green
            } catch { & $setResult 'DNS Server Ping' "$([char]0x2717)  DNS Servers: Failed" $red }

            # 5. Public DNS
            try {
                $pd = Resolve-DnsName 'google.com' -Server '8.8.8.8' -Type A -ErrorAction Stop | Select-Object -First 1
                & $setResult 'Public DNS Test' "$([char]0x2713)  Public DNS: google.com via 8.8.8.8 -> $($pd.IPAddress)" $green
            } catch { & $setResult 'Public DNS Test' "$([char]0x2717)  Public DNS: Failed via 8.8.8.8" $red }

            # 6. DHCP
            try {
                $iface = Get-NetIPInterface -AddressFamily IPv4 -ErrorAction Stop |
                    Where-Object { $_.ConnectionState -eq 'Connected' -and $_.InterfaceAlias -notmatch 'Loopback' } | Select-Object -First 1
                if ($iface.Dhcp -eq 'Enabled') {
                    & $setResult 'DHCP Status' "$([char]0x2713)  DHCP: Enabled on $($iface.InterfaceAlias)" $green
                } else {
                    & $setResult 'DHCP Status' "$([char]0x26A0)  DHCP: Static IP on $($iface.InterfaceAlias)" $yellow
                }
            } catch { & $setResult 'DHCP Status' "$([char]0x2717)  DHCP: Could not determine" $red }

            Write-Log 'Network checks complete' -Level Success

            $SyncHash.Window.Dispatcher.Invoke([action]{
                $SyncHash.Window.FindName('lstModules')  # just to ensure we're on UI thread
            })
        }) | Out-Null
        $ps.BeginInvoke() | Out-Null

        # Re-enable button after a delay (checks take ~10-15 seconds)
        $runAllBtn.IsEnabled = $true
        $runAllBtn.Content = 'Run All Checks'
    }.GetNewClosure())

    $scroll.Content = $panel
    return $scroll
}
