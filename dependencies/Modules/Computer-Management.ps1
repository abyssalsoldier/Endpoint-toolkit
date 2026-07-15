# Module: Computer-Management.ps1

function Register-ComputerManagement {
    @{
        Name         = 'Computer-Management'
        Label        = 'Computer Management'
        Description  = 'Manage computer settings such as renaming the computer.'
        RequiresAuth = $false
        SortOrder    = 30
        EntryPoint   = 'Invoke-ComputerManagement'
        UIDefinition = 'Get-ComputerManagementUI'
    }
}

function Get-ComputerManagementUI {
    $scrollViewer = New-Object System.Windows.Controls.ScrollViewer
    $scrollViewer.VerticalScrollBarVisibility = 'Auto'
    $scrollViewer.HorizontalScrollBarVisibility = 'Disabled'

    $panel = New-Object System.Windows.Controls.StackPanel
    $panel.Margin = [System.Windows.Thickness]::new(0, 0, 12, 0)

    # ===== HEADER =====
    $header = New-Object System.Windows.Controls.TextBlock
    $header.Text = 'Computer Management'
    $header.FontSize = 22
    $header.FontWeight = 'Bold'
    $header.Foreground = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString('#89B4FA'))
    $header.Margin = [System.Windows.Thickness]::new(0, 0, 0, 6)
    $panel.Children.Add($header) | Out-Null

    $desc = New-Object System.Windows.Controls.TextBlock
    $desc.Text = 'Manage computer settings and properties.'
    $desc.FontSize = 13
    $desc.Foreground = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString('#A6ADC8'))
    $desc.Margin = [System.Windows.Thickness]::new(0, 0, 0, 20)
    $desc.TextWrapping = 'Wrap'
    $panel.Children.Add($desc) | Out-Null

    # ===== RENAME COMPUTER =====
    $renameSectionLabel = New-Object System.Windows.Controls.Label
    $renameSectionLabel.Content = 'RENAME COMPUTER'
    $renameSectionLabel.FontWeight = 'Bold'
    $renameSectionLabel.Margin = [System.Windows.Thickness]::new(0, 0, 0, 4)
    $panel.Children.Add($renameSectionLabel) | Out-Null

    $currentNameRow = New-Object System.Windows.Controls.StackPanel
    $currentNameRow.Orientation = 'Horizontal'
    $currentNameRow.Margin = [System.Windows.Thickness]::new(0, 0, 0, 10)

    $currentNameLabel = New-Object System.Windows.Controls.TextBlock
    $currentNameLabel.Text = 'Current Name:'
    $currentNameLabel.FontSize = 14
    $currentNameLabel.VerticalAlignment = 'Center'
    $currentNameLabel.Margin = [System.Windows.Thickness]::new(0, 0, 8, 0)
    $currentNameRow.Children.Add($currentNameLabel) | Out-Null

    $currentNameValue = New-Object System.Windows.Controls.TextBlock
    $currentNameValue.Text = $env:COMPUTERNAME
    $currentNameValue.FontSize = 14
    $currentNameValue.FontWeight = 'Bold'
    $currentNameValue.VerticalAlignment = 'Center'
    $currentNameRow.Children.Add($currentNameValue) | Out-Null

    $panel.Children.Add($currentNameRow) | Out-Null

    # --- Serial Number ---
    $serialNumber = (Get-CimInstance -ClassName Win32_BIOS).SerialNumber

    $serialRow = New-Object System.Windows.Controls.StackPanel
    $serialRow.Orientation = 'Horizontal'
    $serialRow.Margin = [System.Windows.Thickness]::new(0, 0, 0, 10)

    $serialLabel = New-Object System.Windows.Controls.TextBlock
    $serialLabel.Text = 'Serial Number:'
    $serialLabel.FontSize = 14
    $serialLabel.VerticalAlignment = 'Center'
    $serialLabel.Margin = [System.Windows.Thickness]::new(0, 0, 8, 0)
    $serialRow.Children.Add($serialLabel) | Out-Null

    $serialValue = New-Object System.Windows.Controls.TextBlock
    $serialValue.Text = $serialNumber
    $serialValue.FontSize = 14
    $serialValue.FontWeight = 'Bold'
    $serialValue.VerticalAlignment = 'Center'
    $serialRow.Children.Add($serialValue) | Out-Null

    $copySerialBtn = New-Object System.Windows.Controls.Button
    $copySerialBtn.Content = 'Copy'
    $copySerialBtn.Padding = [System.Windows.Thickness]::new(10, 2, 10, 2)
    $copySerialBtn.Margin = [System.Windows.Thickness]::new(12, 0, 0, 0)
    $copySerialBtn.VerticalAlignment = 'Center'
    $serialRow.Children.Add($copySerialBtn) | Out-Null

    $copySerialBtn.Add_Click({
        param($button, $e)
        [System.Windows.Clipboard]::SetText($serialNumber)
        Write-Log "Serial number '$($serialNumber)' copied to clipboard." -Level Info

        $originalContent = $button.Content
        $button.Content = 'Copied!'; $button.IsEnabled = $false
        $timer = New-Object System.Windows.Threading.DispatcherTimer; $timer.Interval = [TimeSpan]::FromSeconds(2)
        $timer.Add_Tick({ $button.Content = $originalContent; $button.IsEnabled = $true; $timer.Stop() }.GetNewClosure())
        $timer.Start()
    }.GetNewClosure())

    $panel.Children.Add($serialRow) | Out-Null

    $newNameRow = New-Object System.Windows.Controls.StackPanel
    $newNameRow.Orientation = 'Horizontal'
    $newNameRow.Margin = [System.Windows.Thickness]::new(0, 0, 0, 16)

    $newNameInput = New-Object System.Windows.Controls.TextBox
    $newNameInput.Width = 200
    $newNameInput.Height = 28
    $newNameInput.VerticalContentAlignment = 'Center'
    $newNameInput.Padding = [System.Windows.Thickness]::new(4, 0, 4, 0)
    $newNameInput.Margin = [System.Windows.Thickness]::new(0, 0, 8, 0)
    $newNameRow.Children.Add($newNameInput) | Out-Null

    $renameBtn = New-Object System.Windows.Controls.Button
    $renameBtn.Content = 'Rename'
    $renameBtn.Padding = [System.Windows.Thickness]::new(16, 4, 16, 4)
    $renameBtn.Background = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString('#89B4FA'))
    $renameBtn.Foreground = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString('#1E1E2E'))
    $newNameRow.Children.Add($renameBtn) | Out-Null

    $panel.Children.Add($newNameRow) | Out-Null

    $renameStatusText = New-Object System.Windows.Controls.TextBlock
    $renameStatusText.FontSize = 13
    $renameStatusText.TextWrapping = 'Wrap'
    $renameStatusText.Foreground = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString('#A6E3A1'))
    $renameStatusText.Margin = [System.Windows.Thickness]::new(0, 0, 0, 24)
    $panel.Children.Add($renameStatusText) | Out-Null

    # ===== DOMAIN JOIN =====
    $domainSectionLabel = New-Object System.Windows.Controls.Label
    $domainSectionLabel.Content = 'DOMAIN JOIN'
    $domainSectionLabel.FontWeight = 'Bold'
    $domainSectionLabel.Margin = [System.Windows.Thickness]::new(0, 0, 0, 4)
    $panel.Children.Add($domainSectionLabel) | Out-Null

    # --- Join Local Domain ---
    $localDomainDesc = New-Object System.Windows.Controls.TextBlock
    $localDomainDesc.Text = 'Join a local Active Directory domain. This action requires a reboot.'
    $localDomainDesc.FontSize = 13
    $localDomainDesc.Foreground = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString('#A6ADC8'))
    $localDomainDesc.Margin = [System.Windows.Thickness]::new(0, 4, 0, 10)
    $localDomainDesc.TextWrapping = 'Wrap'
    $panel.Children.Add($localDomainDesc) | Out-Null

    $domainNameGrid = New-Object System.Windows.Controls.Grid
    $domainNameGrid.Margin = [System.Windows.Thickness]::new(0, 0, 0, 8)
    $domainNameGrid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{ Width = [System.Windows.GridLength]::new(100) }))
    $domainNameGrid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{ Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star) }))

    $domainNameLabel = New-Object System.Windows.Controls.TextBlock; $domainNameLabel.Text = 'Domain:'; $domainNameLabel.VerticalAlignment = 'Center'
    $domainNameInput = New-Object System.Windows.Controls.TextBox; $domainNameInput.Height = 28; $domainNameInput.VerticalContentAlignment = 'Center'
    [System.Windows.Controls.Grid]::SetColumn($domainNameLabel, 0); $domainNameGrid.Children.Add($domainNameLabel) | Out-Null
    [System.Windows.Controls.Grid]::SetColumn($domainNameInput, 1); $domainNameGrid.Children.Add($domainNameInput) | Out-Null
    $panel.Children.Add($domainNameGrid) | Out-Null

    $domainUserGrid = New-Object System.Windows.Controls.Grid
    $domainUserGrid.Margin = [System.Windows.Thickness]::new(0, 0, 0, 8)
    $domainUserGrid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{ Width = [System.Windows.GridLength]::new(100) }))
    $domainUserGrid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{ Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star) }))

    $domainUserLabel = New-Object System.Windows.Controls.TextBlock; $domainUserLabel.Text = 'Username:'; $domainUserLabel.VerticalAlignment = 'Center'
    $domainUserInput = New-Object System.Windows.Controls.TextBox; $domainUserInput.Height = 28; $domainUserInput.VerticalContentAlignment = 'Center'
    [System.Windows.Controls.Grid]::SetColumn($domainUserLabel, 0); $domainUserGrid.Children.Add($domainUserLabel) | Out-Null
    [System.Windows.Controls.Grid]::SetColumn($domainUserInput, 1); $domainUserGrid.Children.Add($domainUserInput) | Out-Null
    $panel.Children.Add($domainUserGrid) | Out-Null

    $domainPassGrid = New-Object System.Windows.Controls.Grid
    $domainPassGrid.Margin = [System.Windows.Thickness]::new(0, 0, 0, 12)
    $domainPassGrid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{ Width = [System.Windows.GridLength]::new(100) }))
    $domainPassGrid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{ Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star) }))

    $domainPassLabel = New-Object System.Windows.Controls.TextBlock; $domainPassLabel.Text = 'Password:'; $domainPassLabel.VerticalAlignment = 'Center'
    
    $domainPassInputGrid = New-Object System.Windows.Controls.Grid
    $domainPassInputGrid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{ Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star) }))
    $domainPassInputGrid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{ Width = [System.Windows.GridLength]::new(34) }))
    
    $domainPassInput = New-Object System.Windows.Controls.PasswordBox; $domainPassInput.Height = 28; $domainPassInput.VerticalContentAlignment = 'Center'
    $domainPassRevealInput = New-Object System.Windows.Controls.TextBox; $domainPassRevealInput.Height = 28; $domainPassRevealInput.VerticalContentAlignment = 'Center'; $domainPassRevealInput.Visibility = 'Collapsed'
    $domainPassRevealBtn = New-Object System.Windows.Controls.Button; $domainPassRevealBtn.Content = [System.Char]::ConvertFromUtf32(0x1F441); $domainPassRevealBtn.Height = 28; $domainPassRevealBtn.Margin = [System.Windows.Thickness]::new(2,0,0,0); $domainPassRevealBtn.Cursor = 'Hand'
    $domainPassRevealBtn.Background = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.ColorConverter]::ConvertFromString('#FF3D3D5C'))
    $domainPassRevealBtn.Foreground = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.ColorConverter]::ConvertFromString('#FFCDD6F4'))
    $domainPassRevealBtn.BorderThickness = [System.Windows.Thickness]::new(0)
    $domainPassRevealBtn.Padding = [System.Windows.Thickness]::new(0)
    $domainPassRevealBtn.FontSize = 16
    $domainPassRevealBtn.ToolTip = 'Reveal Password'
    
    [System.Windows.Controls.Grid]::SetColumn($domainPassInput, 0); $domainPassInputGrid.Children.Add($domainPassInput) | Out-Null
    [System.Windows.Controls.Grid]::SetColumn($domainPassRevealInput, 0); $domainPassInputGrid.Children.Add($domainPassRevealInput) | Out-Null
    [System.Windows.Controls.Grid]::SetColumn($domainPassRevealBtn, 1); $domainPassInputGrid.Children.Add($domainPassRevealBtn) | Out-Null
    
    [System.Windows.Controls.Grid]::SetColumn($domainPassLabel, 0); $domainPassGrid.Children.Add($domainPassLabel) | Out-Null
    [System.Windows.Controls.Grid]::SetColumn($domainPassInputGrid, 1); $domainPassGrid.Children.Add($domainPassInputGrid) | Out-Null
    $panel.Children.Add($domainPassGrid) | Out-Null

    $domainPassRevealBtn.Add_Click({
        if ($Global:SyncHash.CmDomainPassInput.Visibility -eq 'Visible') {
            $Global:SyncHash.CmDomainPassRevealInput.Text = $Global:SyncHash.CmDomainPassInput.Password
            $Global:SyncHash.CmDomainPassInput.Visibility = 'Collapsed'
            $Global:SyncHash.CmDomainPassRevealInput.Visibility = 'Visible'
        } else {
            $Global:SyncHash.CmDomainPassInput.Password = $Global:SyncHash.CmDomainPassRevealInput.Text
            $Global:SyncHash.CmDomainPassRevealInput.Visibility = 'Collapsed'
            $Global:SyncHash.CmDomainPassInput.Visibility = 'Visible'
        }
    })

    $domainJoinBtn = New-Object System.Windows.Controls.Button
    $domainJoinBtn.Content = 'Join Domain'
    $domainJoinBtn.Padding = [System.Windows.Thickness]::new(16, 4, 16, 4)
    $domainJoinBtn.HorizontalAlignment = 'Left'
    $panel.Children.Add($domainJoinBtn) | Out-Null

    $domainStatusText = New-Object System.Windows.Controls.TextBlock
    $domainStatusText.FontSize = 13
    $domainStatusText.TextWrapping = 'Wrap'
    $domainStatusText.Margin = [System.Windows.Thickness]::new(0, 8, 0, 24)
    $panel.Children.Add($domainStatusText) | Out-Null

    # --- Join Azure AD ---
    $azureAdDesc = New-Object System.Windows.Controls.TextBlock
    $azureAdDesc.Text = 'Join Microsoft Entra ID (Azure AD). This will open the Windows "Access work or school" settings panel to complete the process.'
    $azureAdDesc.FontSize = 13
    $azureAdDesc.Foreground = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString('#A6ADC8'))
    $azureAdDesc.Margin = [System.Windows.Thickness]::new(0, 4, 0, 10)
    $azureAdDesc.TextWrapping = 'Wrap'
    $panel.Children.Add($azureAdDesc) | Out-Null

    $azureJoinBtn = New-Object System.Windows.Controls.Button
    $azureJoinBtn.Content = 'Open Azure AD Join Screen'
    $azureJoinBtn.Padding = [System.Windows.Thickness]::new(16, 4, 16, 4)
    $azureJoinBtn.HorizontalAlignment = 'Left'
    $azureJoinBtn.Margin = [System.Windows.Thickness]::new(0, 0, 0, 24)
    $panel.Children.Add($azureJoinBtn) | Out-Null

    $Global:SyncHash.CmCurrentNameValue = $currentNameValue
    $Global:SyncHash.CmNewNameInput = $newNameInput
    $Global:SyncHash.CmRenameBtn = $renameBtn
    $Global:SyncHash.CmRenameStatusText = $renameStatusText
    $Global:SyncHash.CmDomainNameInput = $domainNameInput
    $Global:SyncHash.CmDomainUserInput = $domainUserInput
    $Global:SyncHash.CmDomainPassInput = $domainPassInput
    $Global:SyncHash.CmDomainPassRevealInput = $domainPassRevealInput
    $Global:SyncHash.CmDomainJoinBtn = $domainJoinBtn
    $Global:SyncHash.CmDomainStatusText = $domainStatusText

    $renameBtn.Add_Click({
        $newName = $Global:SyncHash.CmNewNameInput.Text.Trim()
        if ([string]::IsNullOrEmpty($newName)) {
            $Global:SyncHash.CmRenameStatusText.Text = 'Please enter a new computer name.'
            $Global:SyncHash.CmRenameStatusText.Foreground = New-Object System.Windows.Media.SolidColorBrush(
                [System.Windows.Media.ColorConverter]::ConvertFromString('#F38BA8'))
            return
        }

        if ($newName -eq $env:COMPUTERNAME) {
            $Global:SyncHash.CmRenameStatusText.Text = 'New name is the same as the current name.'
            $Global:SyncHash.CmRenameStatusText.Foreground = New-Object System.Windows.Media.SolidColorBrush(
                [System.Windows.Media.ColorConverter]::ConvertFromString('#F9E2AF'))
            return
        }

        $Global:SyncHash.CmRenameBtn.IsEnabled = $false
        $Global:SyncHash.CmRenameStatusText.Text = 'Renaming computer...'
        $Global:SyncHash.CmRenameStatusText.Foreground = New-Object System.Windows.Media.SolidColorBrush(
            [System.Windows.Media.ColorConverter]::ConvertFromString('#A6ADC8'))

        $rs = [runspacefactory]::CreateRunspace()
        $rs.ApartmentState = 'STA'
        $rs.Open()
        $rs.SessionStateProxy.SetVariable('SyncHash', $Global:SyncHash)
        $rs.SessionStateProxy.SetVariable('NewComputerName', $newName)

        $ps = [powershell]::Create()
        $ps.Runspace = $rs
        $ps.AddScript({
            $toolkitRoot = $SyncHash.Toolkit.Root
            Get-ChildItem -Path "$toolkitRoot\Core" -Filter '*.ps1' -File | ForEach-Object { . $_.FullName }
            Get-ChildItem -Path "$toolkitRoot\UI" -Filter '*.ps1' -File | ForEach-Object { . $_.FullName }

            try {
                $entry = @{
                    Name = 'Rename-Computer'; Label = 'Rename Computer'
                    StartTime = Get-Date; EndTime = $null; Status = 'Success'; Detail = "New Name: $NewComputerName"
                }

                Rename-Computer -NewName $NewComputerName -Force -ErrorAction Stop
                Write-Log "Computer renamed to $NewComputerName. A reboot is required." -Level Success
                $SyncHash.Window.Dispatcher.Invoke([action]{
                    $SyncHash.CmRenameStatusText.Text = 'Computer renamed successfully. A reboot is required to apply changes.'
                    $SyncHash.CmRenameStatusText.Foreground = New-Object System.Windows.Media.SolidColorBrush(
                        [System.Windows.Media.ColorConverter]::ConvertFromString('#A6E3A1'))
                    # Update the current name display in the UI (name change requires reboot to be effective)
                    $SyncHash.CmCurrentNameValue.Text = $NewComputerName
                })
            } catch {
                Write-Log "Failed to rename computer: $($_.Exception.Message)" -Level Error
                $entry.Status = 'Error'
                $entry.Detail = $_.Exception.Message
                $SyncHash.Window.Dispatcher.Invoke([action]{
                    $SyncHash.CmRenameStatusText.Text = "Failed to rename: $($_.Exception.Message)"
                    $SyncHash.CmRenameStatusText.Foreground = New-Object System.Windows.Media.SolidColorBrush(
                        [System.Windows.Media.ColorConverter]::ConvertFromString('#F38BA8'))
                })
            } finally {
                $entry.EndTime = Get-Date
                $SyncHash.Window.Dispatcher.Invoke([action]{
                    $SyncHash.CmRenameBtn.IsEnabled = $true
                    if ($SyncHash.Toolkit.Session) {
                        $SyncHash.Toolkit.Session.ModulesRun.Add($entry) | Out-Null
                    }
                })
            }
        }) | Out-Null
        $ps.BeginInvoke() | Out-Null
    }.GetNewClosure())

    $domainJoinBtn.Add_Click({
        $domainName = $Global:SyncHash.CmDomainNameInput.Text.Trim()
        $userName = $Global:SyncHash.CmDomainUserInput.Text.Trim()
        if ($Global:SyncHash.CmDomainPassInput.Visibility -eq 'Visible') {
            $password = $Global:SyncHash.CmDomainPassInput.Password
        } else {
            $password = $Global:SyncHash.CmDomainPassRevealInput.Text
        }

        if ([string]::IsNullOrEmpty($domainName) -or [string]::IsNullOrEmpty($userName) -or [string]::IsNullOrEmpty($password)) {
            $Global:SyncHash.CmDomainStatusText.Text = 'Please enter a domain, username, and password.'
            $Global:SyncHash.CmDomainStatusText.Foreground = New-Object System.Windows.Media.SolidColorBrush(
                [System.Windows.Media.ColorConverter]::ConvertFromString('#F38BA8'))
            return
        }

        $Global:SyncHash.CmDomainJoinBtn.IsEnabled = $false
        $Global:SyncHash.CmDomainStatusText.Text = "Joining domain '$($domainName)'..."
        $Global:SyncHash.CmDomainStatusText.Foreground = New-Object System.Windows.Media.SolidColorBrush(
            [System.Windows.Media.ColorConverter]::ConvertFromString('#A6ADC8'))

        $rs = [runspacefactory]::CreateRunspace()
        $rs.ApartmentState = 'STA'
        $rs.Open()
        $rs.SessionStateProxy.SetVariable('SyncHash', $Global:SyncHash)
        $rs.SessionStateProxy.SetVariable('DomainName', $domainName)
        $rs.SessionStateProxy.SetVariable('Username', $userName)
        $rs.SessionStateProxy.SetVariable('Password', $password)

        $ps = [powershell]::Create()
        $ps.Runspace = $rs
        $ps.AddScript({
            $toolkitRoot = $SyncHash.Toolkit.Root
            Get-ChildItem -Path "$toolkitRoot\Core" -Filter '*.ps1' -File | ForEach-Object { . $_.FullName }
            Get-ChildItem -Path "$toolkitRoot\UI" -Filter '*.ps1' -File | ForEach-Object { . $_.FullName }

            try {
                $entry = @{
                    Name = 'Join-Domain'; Label = 'Join Local Domain'
                    StartTime = Get-Date; EndTime = $null; Status = 'Success'; Detail = "Domain: $DomainName"
                }

                $secPass = ConvertTo-SecureString $Password -AsPlainText -Force
                $cred = New-Object System.Management.Automation.PSCredential($Username, $secPass)

                Add-Computer -DomainName $DomainName -Credential $cred -Force -ErrorAction Stop

                Write-Log "Successfully joined domain '$DomainName'. A reboot is required." -Level Success
                $SyncHash.Window.Dispatcher.Invoke([action]{
                    $SyncHash.CmDomainStatusText.Text = 'Successfully joined domain. A reboot is required to apply changes.'
                    $SyncHash.CmDomainStatusText.Foreground = New-Object System.Windows.Media.SolidColorBrush(
                        [System.Windows.Media.ColorConverter]::ConvertFromString('#A6E3A1'))
                })
            } catch {
                Write-Log "Failed to join domain '$DomainName': $($_.Exception.Message)" -Level Error
                $entry.Status = 'Error'
                $entry.Detail = $_.Exception.Message
                $SyncHash.Window.Dispatcher.Invoke([action]{
                    $SyncHash.CmDomainStatusText.Text = "Failed to join domain: $($_.Exception.Message)"
                    $SyncHash.CmDomainStatusText.Foreground = New-Object System.Windows.Media.SolidColorBrush(
                        [System.Windows.Media.ColorConverter]::ConvertFromString('#F38BA8'))
                })
            } finally {
                $entry.EndTime = Get-Date
                $SyncHash.Window.Dispatcher.Invoke([action]{
                    $SyncHash.CmDomainJoinBtn.IsEnabled = $true
                    if ($SyncHash.Toolkit.Session) {
                        $SyncHash.Toolkit.Session.ModulesRun.Add($entry) | Out-Null
                    }
                })
            }
        }) | Out-Null
        $ps.BeginInvoke() | Out-Null
    }.GetNewClosure())

    $azureJoinBtn.Add_Click({
        Write-Log "Opening 'Access work or school' settings for Azure AD join." -Level Info
        Start-Process "ms-settings:workplace"
        if ($Global:SyncHash.Toolkit.Session) {
            $entry = @{ Name = 'Join-AzureAD'; Label = 'Join Azure AD'; StartTime = Get-Date; EndTime = Get-Date; Status = 'Success'; Detail = 'Opened settings panel.' }
            $Global:SyncHash.Toolkit.Session.ModulesRun.Add($entry) | Out-Null
        }
    }.GetNewClosure())

    # ===== BITLOCKER MANAGEMENT =====
    $bitlockerStatus = 'Unknown'
    $hasRecoveryKey = $false
    try {
        $bl = Get-BitLockerVolume -MountPoint 'C:' -ErrorAction Stop
        if ($bl) {
            $bitlockerStatus = if ($bl.ProtectionStatus -eq 'On') { 'Protected (On)' } else { 'Unprotected (Off)' }
            $keyProtectors = $bl.KeyProtector | Where-Object { $_.KeyProtectorType -eq 'RecoveryPassword' }
            if ($keyProtectors) {
                $hasRecoveryKey = $true
            }
        } else {
            $bitlockerStatus = 'No C: Volume'
        }
    } catch {
        $bitlockerStatus = 'Not Supported / Error'
    }

    $bitlockerSectionLabel = New-Object System.Windows.Controls.Label
    $bitlockerSectionLabel.Content = 'BITLOCKER MANAGEMENT'
    $bitlockerSectionLabel.FontWeight = 'Bold'
    $bitlockerSectionLabel.Margin = [System.Windows.Thickness]::new(0, 0, 0, 4)
    $panel.Children.Add($bitlockerSectionLabel) | Out-Null

    $bitlockerDesc = New-Object System.Windows.Controls.TextBlock
    $bitlockerDesc.Text = 'View the BitLocker encryption status for drive C: and export the recovery key.'
    $bitlockerDesc.FontSize = 13
    $bitlockerDesc.Foreground = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString('#A6ADC8'))
    $bitlockerDesc.Margin = [System.Windows.Thickness]::new(0, 4, 0, 10)
    $bitlockerDesc.TextWrapping = 'Wrap'
    $panel.Children.Add($bitlockerDesc) | Out-Null

    $blStatusRow = New-Object System.Windows.Controls.StackPanel
    $blStatusRow.Orientation = 'Horizontal'
    $blStatusRow.Margin = [System.Windows.Thickness]::new(0, 0, 0, 12)

    $blStatusLabel = New-Object System.Windows.Controls.TextBlock
    $blStatusLabel.Text = 'BitLocker Protection: '
    $blStatusLabel.FontSize = 14
    $blStatusLabel.VerticalAlignment = 'Center'
    $blStatusLabel.Margin = [System.Windows.Thickness]::new(0, 0, 8, 0)
    $blStatusRow.Children.Add($blStatusLabel) | Out-Null

    $blStatusValue = New-Object System.Windows.Controls.TextBlock
    $blStatusValue.Text = $bitlockerStatus
    $blStatusValue.FontSize = 14
    $blStatusValue.FontWeight = 'Bold'
    $blStatusValue.VerticalAlignment = 'Center'
    if ($bitlockerStatus -eq 'Protected (On)') {
        $blStatusValue.Foreground = New-Object System.Windows.Media.SolidColorBrush(
            [System.Windows.Media.ColorConverter]::ConvertFromString('#A6E3A1'))
    } else {
        $blStatusValue.Foreground = New-Object System.Windows.Media.SolidColorBrush(
            [System.Windows.Media.ColorConverter]::ConvertFromString('#F38BA8'))
    }
    $blStatusRow.Children.Add($blStatusValue) | Out-Null
    $panel.Children.Add($blStatusRow) | Out-Null

    $backupKeyBtn = New-Object System.Windows.Controls.Button
    $backupKeyBtn.Content = 'Backup Recovery Key'
    $backupKeyBtn.Padding = [System.Windows.Thickness]::new(16, 4, 16, 4)
    $backupKeyBtn.HorizontalAlignment = 'Left'
    if (-not $hasRecoveryKey) {
        $backupKeyBtn.IsEnabled = $false
        $backupKeyBtn.ToolTip = 'No Recovery Password protector found on C: drive.'
    }
    $panel.Children.Add($backupKeyBtn) | Out-Null

    $blStatusText = New-Object System.Windows.Controls.TextBlock
    $blStatusText.FontSize = 13
    $blStatusText.TextWrapping = 'Wrap'
    $blStatusText.Margin = [System.Windows.Thickness]::new(0, 8, 0, 24)
    $panel.Children.Add($blStatusText) | Out-Null

    $backupKeyBtn.Add_Click({
        $blStatusText.Text = ''
        try {
            $bl = Get-BitLockerVolume -MountPoint 'C:' -ErrorAction Stop
            $keyProtectors = $bl.KeyProtector | Where-Object { $_.KeyProtectorType -eq 'RecoveryPassword' }
            if (-not $keyProtectors) {
                [System.Windows.MessageBox]::Show("No Recovery Password protector found on C: drive.", "Backup BitLocker Key", "OK", "Warning") | Out-Null
                return
            }

            $saveFileDialog = New-Object Microsoft.Win32.SaveFileDialog
            $saveFileDialog.Filter = "Text files (*.txt)|*.txt|All files (*.*)|*.*"
            $saveFileDialog.FileName = "BitLocker_Recovery_Key_$($env:COMPUTERNAME).txt"
            $saveFileDialog.Title = "Save BitLocker Recovery Key Copy"
            
            if ($saveFileDialog.ShowDialog() -eq $true) {
                $filePath = $saveFileDialog.FileName
                
                $fileContent = @(
                    "==================================================",
                    "BitLocker Drive Encryption Recovery Key Backup",
                    "==================================================",
                    "Computer Name: $($env:COMPUTERNAME)",
                    "Backup Date  : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')",
                    "Mount Point  : C:",
                    ""
                )

                foreach ($kp in $keyProtectors) {
                    $fileContent += "Key Protector ID : $($kp.KeyProtectorId)"
                    $fileContent += "Recovery Password: $($kp.RecoveryPassword)"
                    $fileContent += "--------------------------------------------------"
                }

                $fileContent | Out-File -FilePath $filePath -Encoding utf8 -Force
                
                $blStatusText.Text = "Recovery key successfully saved to $filePath"
                $blStatusText.Foreground = New-Object System.Windows.Media.SolidColorBrush(
                    [System.Windows.Media.ColorConverter]::ConvertFromString('#A6E3A1'))
                Write-Log "BitLocker recovery key saved to $filePath." -Level Success

                if ($Global:SyncHash.Toolkit.Session) {
                    $entry = @{
                        Name = 'Backup-BitLockerKey'; Label = 'Backup BitLocker Key'
                        StartTime = Get-Date; EndTime = Get-Date; Status = 'Success'; Detail = "Saved to $filePath"
                    }
                    $Global:SyncHash.Toolkit.Session.ModulesRun.Add($entry) | Out-Null
                }
            }
        } catch {
            $blStatusText.Text = "Failed to backup recovery key: $($_.Exception.Message)"
            $blStatusText.Foreground = New-Object System.Windows.Media.SolidColorBrush(
                [System.Windows.Media.ColorConverter]::ConvertFromString('#F38BA8'))
            Write-Log "Failed to backup BitLocker recovery key: $($_.Exception.Message)" -Level Error
        }
    }.GetNewClosure())

    # ===== SYSTEM TOOLS =====
    $sysToolsLabel = New-Object System.Windows.Controls.Label
    $sysToolsLabel.Content = 'SYSTEM TOOLS'
    $sysToolsLabel.FontWeight = 'Bold'
    $sysToolsLabel.Margin = [System.Windows.Thickness]::new(0, 0, 0, 4)
    $panel.Children.Add($sysToolsLabel) | Out-Null

    $timeDateBtn = New-Object System.Windows.Controls.Button
    $timeDateBtn.Content = 'Date and Time Settings'
    $timeDateBtn.Padding = [System.Windows.Thickness]::new(16, 4, 16, 4)
    $timeDateBtn.HorizontalAlignment = 'Left'
    $timeDateBtn.Margin = [System.Windows.Thickness]::new(0, 0, 0, 8)
    $panel.Children.Add($timeDateBtn) | Out-Null

    $clearSpoolerBtn = New-Object System.Windows.Controls.Button
    $clearSpoolerBtn.Content = 'Clear Print Spooler'
    $clearSpoolerBtn.Padding = [System.Windows.Thickness]::new(16, 4, 16, 4)
    $clearSpoolerBtn.HorizontalAlignment = 'Left'
    $clearSpoolerBtn.Margin = [System.Windows.Thickness]::new(0, 0, 0, 24)
    $panel.Children.Add($clearSpoolerBtn) | Out-Null
    $Global:SyncHash.CmClearSpoolerBtn = $clearSpoolerBtn

    $timeDateBtn.Add_Click({
        Write-Log "Opening Date and Time Settings (timedate.cpl)." -Level Info
        Start-Process "timedate.cpl"
    }.GetNewClosure())

    $clearSpoolerBtn.Add_Click({
        $Global:SyncHash.CmClearSpoolerBtn.IsEnabled = $false
        $Global:SyncHash.CmClearSpoolerBtn.Content = 'Clearing...'

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
                Write-Log "Stopping Print Spooler service..." -Level Info
                Stop-Service -Name Spooler -Force -ErrorAction Stop

                Write-Log "Clearing print jobs from spool directory..." -Level Info
                $spoolDir = Join-Path $env:windir "System32\spool\PRINTERS"
                if (Test-Path $spoolDir) {
                    Get-ChildItem -Path $spoolDir -File | Remove-Item -Force -ErrorAction SilentlyContinue
                }

                Write-Log "Starting Print Spooler service..." -Level Info
                Start-Service -Name Spooler -ErrorAction Stop

                Write-Log "Print spooler cleared and restarted successfully." -Level Success
            } catch {
                Write-Log "Error clearing print spooler: $($_.Exception.Message)" -Level Error
            } finally {
                $SyncHash.Window.Dispatcher.Invoke([action]{
                    $SyncHash.CmClearSpoolerBtn.IsEnabled = $true
                    $SyncHash.CmClearSpoolerBtn.Content = 'Clear Print Spooler'
                })
            }
        }) | Out-Null
        $ps.BeginInvoke() | Out-Null
    }.GetNewClosure())

    $scrollViewer.Content = $panel
    return $scrollViewer
}

function Invoke-ComputerManagement {
    Write-Log 'Computer Management module invoked.' -Level Info
}