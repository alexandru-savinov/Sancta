# Windows App Cleanup

A safe, auditable Windows application cleanup tool that follows Sancta principles with human oversight and complete rollback capabilities.

## Features

- **Safety First**: Dry-run mode and human confirmation gates
- **Complete Audit Trail**: JSONL receipts with undo commands
- **Flexible Targeting**: Support for both winget and AppX packages
- **Elevation Handling**: Graceful handling of administrator requirements
- **Configuration Driven**: Predefined target lists for consistency

## Quick Start

### 1. Test First (Always Recommended)
```powershell
# Quick test with safe targets
.\run-cleanup.ps1 -Mode DryRun

# Or test specific apps
.\windows-app-cleanup.ps1 -Targets 'Microsoft.BingWeather' -DryRun
```

### 2. Run Canary Test
```powershell
# Test uninstall+reinstall to verify safety
.\run-cleanup.ps1 -Mode Safe
```

### 3. Execute Cleanup
```powershell
# Standard cleanup (first 10 common targets)
.\run-cleanup.ps1 -Mode Standard

# Comprehensive cleanup with deprovisioning (requires elevation)
.\run-cleanup.ps1 -Mode Comprehensive -Elevated
```

## Files Overview

- **`windows-app-cleanup.ps1`** - Main cleanup script
- **`run-cleanup.ps1`** - Quick runner with predefined modes
- **`app-targets.psd1`** - Configuration with target app lists
- **`windows-app-cleanup.tests.ps1`** - Unit tests for components
- **`IMPLEMENTATION-SUMMARY.md`** - Technical implementation details

## Direct Script Usage

### Main Script Parameters
- **`-Targets`** - Array of package IDs to target
- **`-DryRun`** - Test mode (no actual changes)
- **`-Canary`** - Test uninstall+reinstall before bulk operation
- **`-Deprovision`** - Remove AppX packages for all users (requires elevation)
- **`-ReceiptsPath`** - Custom path for audit receipts

### Examples
```powershell
# Custom target list
.\windows-app-cleanup.ps1 -Targets 'Microsoft.BingWeather','Microsoft.XboxApp' -DryRun

# With canary testing
.\windows-app-cleanup.ps1 -Targets 'Microsoft.BingWeather','Microsoft.XboxApp' -Canary

# Include deprovisioning (requires elevation)
.\windows-app-cleanup.ps1 -Targets 'Microsoft.BingWeather' -Deprovision

# Custom receipts location
.\windows-app-cleanup.ps1 -Targets 'Microsoft.BingWeather' -ReceiptsPath "C:\CustomPath\receipts.jsonl"
```

## Safety Features

### Human Gates
- Requires typing "YES" to confirm destructive operations
- Second confirmation required for deprovisioning

### Audit Trail
- All operations logged to JSONL receipts
- Includes undo commands for rollback
- Records validation provenance and timestamps

### Rollback
```powershell
# Extract undo commands from receipts
$receipts = Get-Content "$env:USERPROFILE\Documents\Sancta\receipts\windows-app-cleanup.jsonl" | ConvertFrom-Json
$undoCommands = $receipts | Where-Object { $_.undo } | Select-Object -ExpandProperty undo
$undoCommands | ForEach-Object { Write-Output "Run: $_" }
```

## Prerequisites

1. **winget** - Must be installed and available in PATH
2. **PowerShell 5.1+** - For script execution
3. **Elevation** - Required only for AppX deprovisioning
4. **Execution Policy** - Set if needed: `Set-ExecutionPolicy -Scope Process Bypass`

## Configuration

Edit `app-targets.psd1` to customize:
- **DefaultTargets** - Standard cleanup list
- **CriticalApps** - Apps requiring extra caution
- **CanaryTargets** - Safe apps for testing

## Troubleshooting

**Receipts errors**: Ensure `c:\Users\User\Documents\Sancta\receipts\` directory exists
**Elevation errors**: Run PowerShell as Administrator for AppX deprovisioning
**Winget errors**: Verify winget is installed and updated
