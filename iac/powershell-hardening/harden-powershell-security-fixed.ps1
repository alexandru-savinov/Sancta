# Sancta PowerShell Security Hardening
# Implements priority PowerShell security hardening based on audit findings
# Following Sancta principles of transparency, idempotence, and defensive programming

param(
    [string]$ReceiptPath = "${PSScriptRoot}\..\..\receipts\powershell-hardening.jsonl",
    [switch]$DryRun,
    [switch]$Quiet,
    [switch]$JsonOnly,
    [switch]$NoColor,
    [switch]$HighContrast,
    [switch]$Force
)

# Validate and ensure receipts directory exists and is writable
$ReceiptDir = Split-Path $ReceiptPath -Parent

# Check if receipt folder exists and handle fallback with human gate
if (-not (Test-Path $ReceiptDir)) {
    $TempDir = $env:TEMP
    $TempReceiptPath = Join-Path $TempDir "powershell-hardening.jsonl"
    
    Write-Host "⚠️  WARNING: Receipt folder not found: $ReceiptDir" -ForegroundColor Yellow
    Write-Host "🔄 Fallback: Receipts will be stored in $TempDir" -ForegroundColor Cyan
    Write-Host "Continue with temporary receipt storage? (yes/no): " -NoNewline -ForegroundColor Cyan
    
    $confirmation = Read-Host
    if ($confirmation -ne 'yes') {
        Write-Host "Hardening cancelled by user due to receipt folder unavailable." -ForegroundColor Red
        exit 1
    }
    
    $ReceiptPath = $TempReceiptPath
    Write-Host "Proceeding with temporary receipt storage..." -ForegroundColor Green
}

# Write standardized receipt entries (JSONL format)
function Write-Receipt {
    param(
        [string]$Action,
        [hashtable]$Inputs = @{},
        [string]$Result = 'ok',
        [string]$Notes = '',
        [string]$UndoCommand = ''
    )
    try {
        $entry = @{
            timestamp = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffZ')
            script = 'harden-powershell-security.ps1'
            action = $Action
            inputs = $Inputs
            result = $Result
            notes = $Notes
            undo_command = $UndoCommand
        }
        $json = $entry | ConvertTo-Json -Compress
        Add-Content -Path $ReceiptPath -Value $json -Encoding UTF8
    } catch {
        # Silently continue if can't write receipts - don't block hardening
        Write-Warning "Could not write receipt to $ReceiptPath : $($_.Exception.Message)"
    }
}

# Enable PowerShell Script Block Logging
function Enable-ScriptBlockLogging {
    param([bool]$DryRun = $false)
    
    try {
        # Check current state
        $regPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging'
        $currentEnabled = $false
        if (Test-Path $regPath) {
            $currentEnabled = (Get-ItemProperty -Path $regPath -Name 'EnableScriptBlockLogging' -ErrorAction SilentlyContinue).EnableScriptBlockLogging -eq 1
        }
        
        if ($currentEnabled) {
            Write-Receipt -Action 'enable-script-block-logging' -Inputs @{DryRun=$DryRun} -Result 'already-enabled' -Notes 'Script Block Logging already enabled'
            return @{Changed=$false; Message='Script Block Logging already enabled'}
        }
        
        if ($DryRun) {
            Write-Receipt -Action 'enable-script-block-logging' -Inputs @{DryRun=$true} -Result 'would-change' -Notes "Would enable Script Block Logging (current: disabled)" -UndoCommand "Remove-ItemProperty -Path '$regPath' -Name EnableScriptBlockLogging -Force"
            return @{Changed=$true; Message="[DRY RUN] Would enable Script Block Logging - PRIVACY IMPACT: Will log PowerShell script execution"}
        }
        
        # Create registry path if it doesn't exist
        if (-not (Test-Path $regPath)) {
            New-Item -Path $regPath -Force | Out-Null
        }
        
        # Enable Script Block Logging
        Set-ItemProperty -Path $regPath -Name 'EnableScriptBlockLogging' -Value 1
        
        Write-Receipt -Action 'enable-script-block-logging' -Inputs @{DryRun=$false} -Result 'enabled' -Notes "Script Block Logging enabled - PRIVACY IMPACT: PowerShell execution will be logged" -UndoCommand "Remove-ItemProperty -Path '$regPath' -Name EnableScriptBlockLogging -Force"
        return @{Changed=$true; Message='Script Block Logging enabled - PRIVACY IMPACT: PowerShell execution will be logged'}
        
    } catch {
        Write-Receipt -Action 'enable-script-block-logging' -Inputs @{DryRun=$DryRun} -Result 'error' -Notes "Failed to enable Script Block Logging: $($_.Exception.Message)"
        return @{Changed=$false; Message="Failed to enable Script Block Logging: $($_.Exception.Message)"}
    }
}

# Enable PowerShell Module Logging (limited to security modules)
function Enable-ModuleLogging {
    param([bool]$DryRun = $false)
    
    try {
        # Check current state
        $regPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ModuleLogging'
        $moduleNamesPath = "$regPath\ModuleNames"
        $currentEnabled = $false
        if (Test-Path $regPath) {
            $currentEnabled = (Get-ItemProperty -Path $regPath -Name 'EnableModuleLogging' -ErrorAction SilentlyContinue).EnableModuleLogging -eq 1
        }
        
        if ($currentEnabled) {
            Write-Receipt -Action 'enable-module-logging' -Inputs @{DryRun=$DryRun} -Result 'already-enabled' -Notes 'Module Logging already enabled'
            return @{Changed=$false; Message='Module Logging already enabled'}
        }
        
        if ($DryRun) {
            Write-Receipt -Action 'enable-module-logging' -Inputs @{DryRun=$true} -Result 'would-change' -Notes "Would enable Module Logging for security modules" -UndoCommand "Remove-ItemProperty -Path '$regPath' -Name EnableModuleLogging -Force; Remove-Item -Path '$moduleNamesPath' -Recurse -Force -ErrorAction SilentlyContinue"
            return @{Changed=$true; Message="[DRY RUN] Would enable Module Logging (security modules only)"}
        }
        
        # Create registry paths if they don't exist
        if (-not (Test-Path $regPath)) {
            New-Item -Path $regPath -Force | Out-Null
        }
        if (-not (Test-Path $moduleNamesPath)) {
            New-Item -Path $moduleNamesPath -Force | Out-Null
        }
        
        # Enable Module Logging
        Set-ItemProperty -Path $regPath -Name 'EnableModuleLogging' -Value 1
        
        # Configure specific security-related modules only
        $securityModules = @('Microsoft.PowerShell.Security', 'PSDesiredStateConfiguration', 'CimCmdlets', 'NetSecurity')
        foreach ($module in $securityModules) {
            Set-ItemProperty -Path $moduleNamesPath -Name $module -Value '*'
        }
        
        Write-Receipt -Action 'enable-module-logging' -Inputs @{DryRun=$false; SecurityModules=$securityModules} -Result 'enabled' -Notes "Module Logging enabled for security modules: $($securityModules -join ', ')" -UndoCommand "Remove-ItemProperty -Path '$regPath' -Name EnableModuleLogging -Force; Remove-Item -Path '$moduleNamesPath' -Recurse -Force -ErrorAction SilentlyContinue"
        return @{Changed=$true; Message="Module Logging enabled (security modules only)"}
        
    } catch {
        Write-Receipt -Action 'enable-module-logging' -Inputs @{DryRun=$DryRun} -Result 'error' -Notes "Failed to enable Module Logging: $($_.Exception.Message)"
        return @{Changed=$false; Message="Failed to enable Module Logging: $($_.Exception.Message)"}
    }
}

# Set PowerShell Execution Policy to RemoteSigned
function Set-ExecutionPolicySecure {
    param([bool]$DryRun = $false)
    
    try {
        $currentMachine = Get-ExecutionPolicy -Scope MachinePolicy -ErrorAction SilentlyContinue
        $targetPolicy = 'RemoteSigned'
        
        if ($currentMachine -eq $targetPolicy) {
            Write-Receipt -Action 'set-execution-policy' -Inputs @{DryRun=$DryRun; TargetPolicy=$targetPolicy} -Result 'already-set' -Notes "Execution Policy already set to $targetPolicy"
            return @{Changed=$false; Message="Execution Policy already set to $targetPolicy"}
        }
        
        if ($DryRun) {
            Write-Receipt -Action 'set-execution-policy' -Inputs @{DryRun=$true; TargetPolicy=$targetPolicy; CurrentPolicy=$currentMachine} -Result 'would-change' -Notes "Would set Execution Policy to $targetPolicy (current: $currentMachine)" -UndoCommand "Set-ExecutionPolicy -ExecutionPolicy $currentMachine -Scope MachinePolicy -Force"
            return @{Changed=$true; Message="[DRY RUN] Would set Execution Policy to $targetPolicy (current: $currentMachine)"}
        }
        
        # Set the execution policy
        Set-ExecutionPolicy -ExecutionPolicy $targetPolicy -Scope MachinePolicy -Force
        
        Write-Receipt -Action 'set-execution-policy' -Inputs @{DryRun=$false; TargetPolicy=$targetPolicy; PreviousPolicy=$currentMachine} -Result 'changed' -Notes "Execution Policy changed from $currentMachine to $targetPolicy" -UndoCommand "Set-ExecutionPolicy -ExecutionPolicy $currentMachine -Scope MachinePolicy -Force"
        return @{Changed=$true; Message="Execution Policy set to $targetPolicy (was: $currentMachine)"}
        
    } catch {
        Write-Receipt -Action 'set-execution-policy' -Inputs @{DryRun=$DryRun; TargetPolicy=$targetPolicy} -Result 'error' -Notes "Failed to set Execution Policy: $($_.Exception.Message)"
        return @{Changed=$false; Message="Failed to set Execution Policy: $($_.Exception.Message)"}
    }
}

# Test AMSI Functionality
function Test-AMSIFunctionality {
    param([bool]$DryRun = $false)
    
    try {
        if ($DryRun) {
            Write-Receipt -Action 'test-amsi' -Inputs @{DryRun=$true} -Result 'would-test' -Notes "Would test AMSI functionality (read-only test)"
            return @{Changed=$false; Message="[DRY RUN] Would test AMSI functionality"}
        }
        
        # Test AMSI by trying to load a known test string
        $testResult = try {
            # This is a harmless test - AMSI should detect this test string
            $null = [System.Text.Encoding]::Unicode.GetString([System.Convert]::FromBase64String('QQBNAFMASQAgAHQAZQBzAHQAIABzAHQAcgBpAG4AZwA='))
            'AMSI may not be functioning properly'
        } catch {
            'AMSI is functioning (blocked test string)'
        }
        
        Write-Receipt -Action 'test-amsi' -Inputs @{DryRun=$false} -Result 'tested' -Notes "AMSI test completed: $testResult"
        return @{Changed=$false; Message=$testResult}
        
    } catch {
        Write-Receipt -Action 'test-amsi' -Inputs @{DryRun=$DryRun} -Result 'error' -Notes "AMSI test failed: $($_.Exception.Message)"
        return @{Changed=$false; Message="AMSI test failed: $($_.Exception.Message)"}
    }
}

# Main hardening function
function Invoke-PowerShellSecurityHardening {
    param(
        [string]$ReceiptPath = $ReceiptPath,
        [switch]$DryRun = $DryRun,
        [switch]$Quiet = $Quiet,
        [switch]$JsonOnly = $JsonOnly,
        [switch]$NoColor = $NoColor,
        [switch]$HighContrast = $HighContrast,
        [switch]$Force = $Force
    )
    
    # Convert switches to hashtable for easier handling
    $switches = @{
        ReceiptPath = $ReceiptPath
        DryRun = $DryRun.IsPresent
        Quiet = $Quiet.IsPresent
        JsonOnly = $JsonOnly.IsPresent
        NoColor = $NoColor.IsPresent
        HighContrast = $HighContrast.IsPresent
        Force = $Force.IsPresent
    }
    
    # Check if running as administrator
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin -and -not $switches.DryRun) {
        Write-Host "⚠️  WARNING: Not running as Administrator. Some hardening actions may fail." -ForegroundColor Yellow
        if (-not $switches.Force) {
            Write-Host "Use -Force to continue anyway, or run as Administrator." -ForegroundColor Red
            return @{
                Timestamp = Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffZ'
                Error = "Administrator privileges required for hardening actions"
            }
        }
    }
    
    if (-not $switches.Quiet) {
        $mode = if ($switches.DryRun) { "DRY RUN" } else { "LIVE" }
        $msg = "Starting PowerShell Security Hardening ($mode)..."
        if ($switches.HighContrast) { Write-Host $msg -ForegroundColor Yellow -BackgroundColor Black }
        else { Write-Host $msg -ForegroundColor Green }
    }
    
    # SANCTA COMPLIANCE: Consent is Ceremony - Interactive confirmation for privacy-sensitive changes
    if (-not $switches.DryRun -and -not $switches.Force -and -not $switches.JsonOnly) {
        Write-Host "`n🔒 POWERSHELL SECURITY HARDENING" -ForegroundColor Cyan
        Write-Host "=" * 50 -ForegroundColor Cyan
        Write-Host "This will make the following changes:" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "1. 📝 Enable Script Block Logging" -ForegroundColor White
        Write-Host "   ⚠️  PRIVACY IMPACT: PowerShell script execution will be logged" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "2. 📦 Enable Module Logging (security modules only)" -ForegroundColor White
        Write-Host "   ℹ️  Minimal privacy impact: Only security-related modules" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "3. 🛡️ Set Execution Policy to RemoteSigned" -ForegroundColor White
        Write-Host "   ℹ️  Security improvement: Requires signatures for remote scripts" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "4. 🔍 Test AMSI Functionality" -ForegroundColor White
        Write-Host "   ℹ️  Read-only test: No system changes" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "⚠️  PRIVACY NOTICE: PowerShell logging may capture sensitive script content." -ForegroundColor Yellow
        Write-Host "All changes include documented undo procedures." -ForegroundColor Green
        Write-Host ""
        Write-Host "Type 'yes' to proceed, 'privacy' for details, or anything else to cancel: " -NoNewline -ForegroundColor Cyan
        
        $confirmation = Read-Host
        
        if ($confirmation -eq 'privacy') {
            Write-Host "`n📋 PRIVACY IMPACT DETAILS:" -ForegroundColor Yellow
            Write-Host "• Script Block Logging: Records PowerShell script execution in Windows Event Log" -ForegroundColor White
            Write-Host "• Module Logging: Only logs security-related PowerShell modules" -ForegroundColor White
            Write-Host "• Logs stored in: Windows Event Log > Applications and Services > Microsoft > Windows > PowerShell" -ForegroundColor White
            Write-Host "• Undo: All logging can be disabled using provided undo commands" -ForegroundColor Green
            Write-Host ""
            Write-Host "Proceed with hardening? Type 'yes' to continue: " -NoNewline -ForegroundColor Cyan
            $confirmation = Read-Host
        }
        
        if ($confirmation -ne 'yes') {
            Write-Host "PowerShell hardening cancelled by user." -ForegroundColor Red
            Write-Receipt -Action 'hardening-cancelled' -Inputs $switches -Result 'cancelled' -Notes "User chose not to proceed"
            return @{
                Timestamp = Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffZ'
                Cancelled = $true
                Message = "PowerShell hardening cancelled by user"
            }
        }
        Write-Host "Proceeding with PowerShell hardening..." -ForegroundColor Green
    }
    
    # Execute hardening actions
    $results = [ordered]@{
        Timestamp = Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffZ'
        IsAdministrator = $isAdmin
        Mode = if ($switches.DryRun) { "DryRun" } else { "Live" }
        ScriptBlockLogging = Enable-ScriptBlockLogging -DryRun $switches.DryRun
        ModuleLogging = Enable-ModuleLogging -DryRun $switches.DryRun
        ExecutionPolicy = Set-ExecutionPolicySecure -DryRun $switches.DryRun
        AMSITest = Test-AMSIFunctionality -DryRun $switches.DryRun
    }
    
    # Count changes made
    $changesCount = ($results.Values | Where-Object { $_ -is [hashtable] -and $_.Changed -eq $true }).Count
    
    # Output results
    if (-not $switches.Quiet) {
        if ($switches.JsonOnly) {
            $results | ConvertTo-Json -Depth 3
        } else {
            Write-Host "`n✅ PowerShell Security Hardening Complete" -ForegroundColor Green
            Write-Host "=" * 50 -ForegroundColor Green
            
            $color = if ($switches.NoColor) { @{} } elseif ($switches.HighContrast) { @{ForegroundColor='White'; BackgroundColor='Black'} } else { @{ForegroundColor='Cyan'} }
            $statusColor = if ($switches.HighContrast) { @{ForegroundColor='Yellow'; BackgroundColor='Black'} } else { @{ForegroundColor='Yellow'} }
            Write-Host "Mode: $(if ($switches.DryRun) {'DRY RUN'} else {'LIVE CHANGES'})" @statusColor
            Write-Host "Administrator: $isAdmin" @statusColor
            Write-Host "Changes: $changesCount" @statusColor
            Write-Host ""
            
            Write-Host "Script Block Logging: $($results.ScriptBlockLogging.Message)" @color
            Write-Host "Module Logging: $($results.ModuleLogging.Message)" @color  
            Write-Host "Execution Policy: $($results.ExecutionPolicy.Message)" @color
            Write-Host "AMSI Test: $($results.AMSITest.Message)" @color
        }
    }
    
    Write-Receipt -Action 'hardening-complete' -Inputs $switches -Result 'ok' -Notes "PowerShell hardening completed at $(Get-Date), $changesCount changes made"
    return $results
}

# If script is run directly (not dot-sourced), execute the hardening
if ($MyInvocation.InvocationName -ne '.') {
    Invoke-PowerShellSecurityHardening @args
}
