# Core: ModuleLoader.ps1
# Discovers and registers toolkit modules via convention-based Register-* functions
#
# Module files must be dot-sourced by the caller BEFORE calling Get-RegisteredModules.
# This ensures functions like Start-SoftwareInstall persist in the caller's scope.

function Get-RegisteredModules {
    $registered = @()

    # Find all Register-* functions currently in scope
    $registerFunctions = Get-Command -Name "Register-*" -CommandType Function -ErrorAction SilentlyContinue

    foreach ($fn in $registerFunctions) {
        # Only call functions defined in our Modules directory
        $source = $fn.ScriptBlock.File
        if (-not $source) { continue }
        $toolkitRoot = if ($Global:SyncHash) { $Global:SyncHash.Toolkit.Root } else { $script:Toolkit.Root }
        $modulesPath = Join-Path $toolkitRoot "Modules"
        if ($source -notlike "$modulesPath*") { continue }

        try {
            $meta = & $fn.Name
            if ($meta -and $meta.Name -and $meta.EntryPoint) {
                $registered += $meta
            }
        } catch {
            Write-Host "WARNING: Failed to register $($fn.Name): $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }

    return $registered | Sort-Object { $_.SortOrder }
}

function Invoke-RegisteredModule {
    param(
        [hashtable]$Module
    )

    if ($Module.RequiresAuth -and -not $script:Toolkit.Authenticated) {
        Write-Host "  $($Module.Label) requires authentication. Skipping." -ForegroundColor Yellow
        return
    }

    Write-SessionEvent -Name $Module.Name -Label $Module.Label -Action {
        & $Module.EntryPoint
    }
}
