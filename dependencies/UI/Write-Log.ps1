# UI: Write-Log.ps1
# Thread-safe dual-output logging (WPF RichTextBox + console)

function Write-Log {
    param(
        [Parameter(Position = 0)]
        [string]$Message,

        [ValidateSet("Info", "Success", "Warning", "Error", "Debug")]
        [string]$Level = "Info"
    )

    $timestamp = Get-Date -Format "HH:mm:ss"
    $formatted = "[$timestamp] $Message"

    # Accumulate log entries for session report
    if ($Global:SyncHash -and $Global:SyncHash.Toolkit.Session) {
        if (-not $Global:SyncHash.Toolkit.Session.LogEntries) {
            $Global:SyncHash.Toolkit.Session.LogEntries = [System.Collections.ArrayList]::new()
        }
        $Global:SyncHash.Toolkit.Session.LogEntries.Add($formatted) | Out-Null
    }

    # Console output (always works, even if GUI isn't loaded)
    $consoleColor = switch ($Level) {
        "Info"    { "White" }
        "Success" { "Green" }
        "Warning" { "Yellow" }
        "Error"   { "Red" }
        "Debug"   { "DarkGray" }
    }
    Write-Host $formatted -ForegroundColor $consoleColor

    # WPF RichTextBox output (if GUI is active)
    if ($Global:SyncHash -and $Global:SyncHash.LogPanel) {
        $wpfColor = switch ($Level) {
            "Info"    { "#CDD6F4" }
            "Success" { "#A6E3A1" }
            "Warning" { "#F9E2AF" }
            "Error"   { "#F38BA8" }
            "Debug"   { "#6C7086" }
        }

        $action = [action]{
            $rtb = $Global:SyncHash.LogPanel
            $paragraph = $rtb.Document.Blocks.LastBlock
            if (-not $paragraph -or $paragraph -isnot [System.Windows.Documents.Paragraph]) {
                $paragraph = New-Object System.Windows.Documents.Paragraph
                $paragraph.Margin = [System.Windows.Thickness]::new(0)
                $rtb.Document.Blocks.Add($paragraph)
            }
            $run = New-Object System.Windows.Documents.Run("$formatted`r`n")
            $run.Foreground = New-Object System.Windows.Media.SolidColorBrush(
                [System.Windows.Media.ColorConverter]::ConvertFromString($wpfColor))
            $paragraph.Inlines.Add($run)
            $rtb.ScrollToEnd()
        }

        try {
            if ($Global:SyncHash.Window.Dispatcher.CheckAccess()) {
                $action.Invoke()
            } else {
                $Global:SyncHash.Window.Dispatcher.Invoke($action)
            }
        } catch {
            # GUI may have closed — silently ignore
        }
    }
}

function Update-ActionStatus {
    param(
        [string]$Text,
        [string]$Color = "#CDD6F4"
    )

    if ($Global:SyncHash -and $Global:SyncHash.StatusText) {
        $action = [action]{
            $Global:SyncHash.StatusText.Text = $Text
            $Global:SyncHash.StatusText.Foreground = New-Object System.Windows.Media.SolidColorBrush(
                [System.Windows.Media.ColorConverter]::ConvertFromString($Color))
        }

        try {
            if ($Global:SyncHash.Window.Dispatcher.CheckAccess()) {
                $action.Invoke()
            } else {
                $Global:SyncHash.Window.Dispatcher.Invoke($action)
            }
        } catch { }
    }
}
