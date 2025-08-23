# Quick Start Script for Windows App Cleanup
# This wrapper script demonstrates common usage patterns

param(
    [ValidateSet('DryRun', 'Safe', 'Standard', 'Comprehensive', 'Custom')]
    [string]$Mode = 'DryRun',
    [string[]]$CustomTargets = @(),
    [switch]$Elevated
)

# Load configuration
$configPath = Join-Path $PSScriptRoot "app-targets.psd1"
if (-not (Test-Path $configPath)) {
    throw "Configuration file not found: $configPath"
}
$config = Import-PowerShellDataFile $configPath

# Main script path
$scriptPath = Join-Path $PSScriptRoot "windows-app-cleanup.ps1"
if (-not (Test-Path $scriptPath)) {
    throw "Main script not found: $scriptPath"
}

# Determine targets based on mode
$targets = switch ($Mode) {
    'DryRun' { $config.CanaryTargets }
    'Safe' { $config.CanaryTargets }
    'Standard' { $config.DefaultTargets | Select-Object -First 10 }  # First 10 for initial runs
    'Comprehensive' { $config.DefaultTargets }
    'Custom' { $CustomTargets }
}

if (-not $targets) {
    Write-Warning "No targets specified for mode: $Mode"
    return
}

# Build arguments as hashtable for proper splatting
$scriptArgs = @{
    'Targets' = $targets
}

switch ($Mode) {
    'DryRun' { $scriptArgs['DryRun'] = $true }
    'Safe' { $scriptArgs['Canary'] = $true }
    'Standard' { $scriptArgs['Canary'] = $true }
    'Comprehensive' { 
        $scriptArgs['Canary'] = $true
        if ($Elevated) {
            $scriptArgs['Deprovision'] = $true
        }
    }
}

# Display plan
Write-Host "Windows App Cleanup - Mode: $Mode" -ForegroundColor Cyan
Write-Host "Targets ($($targets.Count)):" -ForegroundColor Yellow
$targets | ForEach-Object { Write-Host "  - $_" }
Write-Host ""

if ($Mode -ne 'DryRun') {
    $confirmation = Read-Host "Proceed with cleanup? (y/N)"
    if ($confirmation -notmatch '^[Yy]') {
        Write-Host "Aborted by user" -ForegroundColor Yellow
        return
    }
}

# Execute
if ($Elevated -and $Mode -eq 'Comprehensive') {
    # For elevated mode, we need to run as administrator
    # CRITICAL: Ensure receipts continuity by using original user's path
    $originalUserReceiptsPath = "$env:USERPROFILE\Documents\Sancta\receipts\windows-app-cleanup.jsonl"
    
    # Create a simple command that bypasses the complex argument parsing
    $simpleArgs = "-Targets @('$($targets -join "','")')"
    $simpleArgs += " -ReceiptsPath '$originalUserReceiptsPath'"
    if ($scriptArgs.ContainsKey('Canary')) { $simpleArgs += " -Canary" }
    if ($scriptArgs.ContainsKey('Deprovision')) { $simpleArgs += " -Deprovision" }
    
    Write-Host "Starting elevated process with receipts path: $originalUserReceiptsPath" -ForegroundColor Yellow
    $elevatedCommand = "Set-Location '$PSScriptRoot'; .\windows-app-cleanup.ps1 $simpleArgs"
    Start-Process powershell -Verb RunAs -ArgumentList "-Command", $elevatedCommand -Wait
} else {
    # Run normally
    & $scriptPath @scriptArgs
}

Write-Host "Cleanup completed. Check receipts for details." -ForegroundColor Green
