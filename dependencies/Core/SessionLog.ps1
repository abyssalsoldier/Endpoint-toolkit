# Core: SessionLog.ps1
# Session logging and close-out report (console-only, no WPF)

function Initialize-SessionLog {
    $script:Toolkit.Session = @{
        StartTime      = Get-Date
        ComputerName   = $env:COMPUTERNAME
        ScriptVersion  = $script:Toolkit.Version
        ModulesRun     = [System.Collections.ArrayList]::new()
        Errors         = [System.Collections.ArrayList]::new()
        ConnectWise    = @{ Client = $null; Site = $null }
    }
}

function Write-SessionEvent {
    param(
        [string]$Name,
        [string]$Label,
        [scriptblock]$Action
    )
    $entry = @{
        Name      = $Name
        Label     = $Label
        StartTime = Get-Date
        EndTime   = $null
        Status    = "Success"
        Detail    = ""
    }
    try {
        & $Action
    } catch {
        $entry.Status = "Error"
        $entry.Detail = $_.Exception.Message
        $script:Toolkit.Session.Errors.Add($_.Exception.Message) | Out-Null
        Write-Host "Error in ${Label}: $($_.Exception.Message)" -ForegroundColor Red
    } finally {
        $entry.EndTime = Get-Date
        $script:Toolkit.Session.ModulesRun.Add($entry) | Out-Null
    }
}

function Get-SessionReport {
    $log = $script:Toolkit.Session
    $duration = (Get-Date) - $log.StartTime

    $report = @()
    $report += "============================================"
    $report += "  ENDPOINT BUILD SESSION REPORT"
    $report += "============================================"
    $report += ""
    $report += "Computer Name  : $($log.ComputerName)"
    $report += "Toolkit Version: $($log.ScriptVersion)"
    $report += "Session Start  : $($log.StartTime.ToString('yyyy-MM-dd HH:mm:ss'))"
    $report += "Session End    : $((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))"
    $report += "Duration       : $($duration.ToString('hh\:mm\:ss'))"
    $report += ""

    if ($log.ConnectWise.Client) {
        $report += "ConnectWise    : $($log.ConnectWise.Client) / $($log.ConnectWise.Site)"
        $report += ""
    }

    $report += "--- Modules Executed ---"
    $report += ""

    if ($log.ModulesRun.Count -eq 0) {
        $report += "  (none)"
    } else {
        foreach ($m in $log.ModulesRun) {
            $moduleDuration = if ($m.EndTime) { ($m.EndTime - $m.StartTime).ToString('mm\:ss') } else { "??" }
            $statusIcon = switch ($m.Status) {
                "Success" { "[OK]" }
                "Skipped" { "[SKIP]" }
                "Error"   { "[FAIL]" }
            }
            $report += "  $statusIcon $($m.Label) ($moduleDuration)"
            if ($m.Detail) {
                $report += "        $($m.Detail)"
            }
        }
    }

    if ($log.Errors.Count -gt 0) {
        $report += ""
        $report += "--- Errors ---"
        $report += ""
        foreach ($err in $log.Errors) {
            $report += "  * $err"
        }
    }

    # Include full activity log if available
    if ($log.LogEntries -and $log.LogEntries.Count -gt 0) {
        $report += ""
        $report += "--- Activity Log ---"
        $report += ""
        foreach ($entry in $log.LogEntries) {
            $report += "  $entry"
        }
    }

    $report += ""
    $report += "============================================"

    return ($report -join "`r`n")
}

function Format-SessionLogText {
    if (-not $script:Toolkit.Session -or $script:Toolkit.Session.ModulesRun.Count -eq 0) {
        return "No modules have been run yet."
    }
    $lines = @()
    foreach ($m in $script:Toolkit.Session.ModulesRun) {
        $duration = if ($m.EndTime) { ($m.EndTime - $m.StartTime).ToString('mm\:ss') } else { "??:??" }
        $icon = switch ($m.Status) {
            "Success" { "[OK]" }
            "Skipped" { "[SKIP]" }
            "Error"   { "[FAIL]" }
        }
        $line = "  $icon $($m.Label) ($duration)"
        if ($m.Detail) { $line += " - $($m.Detail)" }
        $lines += $line
    }
    return ($lines -join "`r`n")
}

function Show-SessionReport {
    $reportText = Get-SessionReport
    Write-Host ""
    Write-Host $reportText
    Write-Host ""

    try {
        Set-Clipboard -Value $reportText
        Write-Host "Report copied to clipboard." -ForegroundColor Green
    } catch {
        Write-Host "Could not copy to clipboard. You can select and copy the text above." -ForegroundColor Yellow
    }
}
