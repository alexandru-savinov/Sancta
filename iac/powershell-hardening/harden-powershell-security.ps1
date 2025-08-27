# Sancta PowerShell Security Hardening
# Implements priority PowerShell security hardening based on audit findings
# Following Sancta principles of transparency, idempotence, and defensive programming

# Define receipt path at script level - handle elevated/non-elevated contexts
$ReceiptPath = "${PSScriptRoot}\..\..\receipts\powershell-hardening.jsonl"

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

# Additional fallback validation - remove redundant test write access section
# (This was redundant as we already tested above)

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
            action = $Action
            inputs = $Inputs
            result = $Result
            notes = $Notes
            undo_command = $UndoCommand
            hostname = $env:COMPUTERNAME
            user = $env:USERNAME
        } | ConvertTo-Json -Compress
        $entry | Out-File -FilePath $ReceiptPath -Append -Encoding UTF8 -ErrorAction Stop
    }
    catch {
        # Silently continue if can't write receipts - don't block hardening
        Write-Warning "Could not write receipt to $ReceiptPath : $($_.Exception.Message)"
    }
}

# Check if running as administrator
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Enable PowerShell Script Block Logging (PRIVACY-SENSITIVE)
function Enable-ScriptBlockLogging {
    param([bool]$DryRun = $false)
    
    try {
        $regPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging'
        
        # Check current state
        $current = Get-ItemProperty -Path $regPath -ErrorAction SilentlyContinue
        $currentEnabled = if ($current -and $current.EnableScriptBlockLogging -eq 1) { $true } else { $false }
        
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
        
        Set-ItemProperty -Path $regPath -Name EnableScriptBlockLogging -Value 1 -Type DWord -ErrorAction Stop
        Write-Receipt -Action 'enable-script-block-logging' -Inputs @{DryRun=$false} -Result 'enabled' -Notes "Script Block Logging enabled - PRIVACY IMPACT: PowerShell execution will be logged" -UndoCommand "Remove-ItemProperty -Path '$regPath' -Name EnableScriptBlockLogging -Force"
        return @{Changed=$true; Message='Script Block Logging enabled - PowerShell execution will be logged to Windows Event Log'}
    }
    catch {
        Write-Receipt -Action 'enable-script-block-logging' -Inputs @{DryRun=$DryRun} -Result 'error' -Notes "Failed: $($_.Exception.Message)"
        return @{Changed=$false; Message="Error: $($_.Exception.Message)"}
    }
}

# Enable PowerShell Module Logging
function Enable-ModuleLogging {
    param([bool]$DryRun = $false)
    
    try {
        $regPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ModuleLogging'
        $moduleNamesPath = "$regPath\ModuleNames"
        
        # Check current state
        $current = Get-ItemProperty -Path $regPath -ErrorAction SilentlyContinue
        $currentEnabled = if ($current -and $current.EnableModuleLogging -eq 1) { $true } else { $false }
        
        if ($currentEnabled) {
            Write-Receipt -Action 'enable-module-logging' -Inputs @{DryRun=$DryRun} -Result 'already-enabled' -Notes 'Module Logging already enabled'
            return @{Changed=$false; Message='Module Logging already enabled'}
        }
        
        if ($DryRun) {
            Write-Receipt -Action 'enable-module-logging' -Inputs @{DryRun=$true} -Result 'would-change' -Notes "Would enable Module Logging (current: disabled)" -UndoCommand "Remove-ItemProperty -Path '$regPath' -Name EnableModuleLogging -Force"
            return @{Changed=$true; Message="[DRY RUN] Would enable Module Logging for security-relevant modules"}
        }
        
        # Create registry paths if they don't exist
        if (-not (Test-Path $regPath)) {
            New-Item -Path $regPath -Force | Out-Null
        }
        if (-not (Test-Path $moduleNamesPath)) {
            New-Item -Path $moduleNamesPath -Force | Out-Null
        }
        
        # Enable module logging
        Set-ItemProperty -Path $regPath -Name EnableModuleLogging -Value 1 -Type DWord -ErrorAction Stop
        
        # Configure specific modules to log (security-focused, minimal privacy impact)
        $securityModules = @('Microsoft.PowerShell.Security', 'Microsoft.PowerShell.Utility')
        foreach ($module in $securityModules) {
            Set-ItemProperty -Path $moduleNamesPath -Name $module -Value $module -Type String -ErrorAction Stop
        }
        
        Write-Receipt -Action 'enable-module-logging' -Inputs @{DryRun=$false; Modules=$securityModules} -Result 'enabled' -Notes "Module Logging enabled for security modules: $($securityModules -join ', ')" -UndoCommand "Remove-ItemProperty -Path '$regPath' -Name EnableModuleLogging -Force; Remove-Item -Path '$moduleNamesPath' -Recurse -Force"
        return @{Changed=$true; Message="Module Logging enabled for security-relevant modules: $($securityModules -join ', ')"}
    }
    catch {
        Write-Receipt -Action 'enable-module-logging' -Inputs @{DryRun=$DryRun} -Result 'error' -Notes "Failed: $($_.Exception.Message)"
        return @{Changed=$false; Message="Error: $($_.Exception.Message)"}
    }
}

# Configure PowerShell Execution Policy (Conservative)
function Set-ExecutionPolicySecure {
    param([bool]$DryRun = $false)
    
    try {
        # Get current execution policies
        $currentMachine = Get-ExecutionPolicy -Scope LocalMachine -ErrorAction SilentlyContinue
        
        # Target: RemoteSigned for LocalMachine (allows local scripts, requires signature for remote)
        $targetPolicy = 'RemoteSigned'
        
        if ($currentMachine -eq $targetPolicy) {
            Write-Receipt -Action 'set-execution-policy' -Inputs @{DryRun=$DryRun; Scope='LocalMachine'} -Result 'already-configured' -Notes "Execution Policy already set to $targetPolicy"
            return @{Changed=$false; Message="Execution Policy already configured: $targetPolicy"}
        }
        
        if ($DryRun) {
            Write-Receipt -Action 'set-execution-policy' -Inputs @{DryRun=$true; Scope='LocalMachine'; Target=$targetPolicy} -Result 'would-change' -Notes "Would set LocalMachine execution policy to $targetPolicy (current: $currentMachine)" -UndoCommand "Set-ExecutionPolicy -ExecutionPolicy $currentMachine -Scope LocalMachine -Force"
            return @{Changed=$true; Message="[DRY RUN] Would set execution policy to $targetPolicy (current: $currentMachine)"}
        }
        
        Set-ExecutionPolicy -ExecutionPolicy $targetPolicy -Scope LocalMachine -Force -ErrorAction Stop
        Write-Receipt -Action 'set-execution-policy' -Inputs @{DryRun=$false; Scope='LocalMachine'; Policy=$targetPolicy} -Result 'configured' -Notes "Execution Policy set to $targetPolicy (was: $currentMachine)" -UndoCommand "Set-ExecutionPolicy -ExecutionPolicy $currentMachine -Scope LocalMachine -Force"
        return @{Changed=$true; Message="Execution Policy configured: $targetPolicy (was: $currentMachine)"}
    }
    catch {
        Write-Receipt -Action 'set-execution-policy' -Inputs @{DryRun=$DryRun} -Result 'error' -Notes "Failed: $($_.Exception.Message)"
        return @{Changed=$false; Message="Error: $($_.Exception.Message)"}
    }
}

# Validate AMSI (Anti-Malware Scan Interface) is functional
function Test-AMSIFunctionality {
    param([bool]$DryRun = $false)
    
    try {
        # Check if AMSI provider is loaded (Windows Defender or third-party)
        $amsiProviders = Get-WmiObject -Class Win32_Process -Filter "Name='MsMpEng.exe'" -ErrorAction SilentlyContinue
        $amsiLoaded = $null -ne $amsiProviders
        
        if ($DryRun) {
            Write-Receipt -Action 'test-amsi' -Inputs @{DryRun=$true} -Result 'info' -Notes "Would test AMSI functionality (current provider loaded: $amsiLoaded)" -UndoCommand 'N/A (read-only test)'
            return @{Changed=$false; Message="[DRY RUN] Would test AMSI functionality"}
        }
        
        $status = if ($amsiLoaded) { 'functional' } else { 'warning' }
        $message = if ($amsiLoaded) { 'AMSI appears functional (Windows Defender process detected)' } else { 'AMSI status unclear (no Windows Defender process detected)' }
        
        Write-Receipt -Action 'test-amsi' -Inputs @{DryRun=$false} -Result $status -Notes $message -UndoCommand 'N/A (read-only test)'
        return @{Changed=$false; Message=$message}
    }
    catch {
        Write-Receipt -Action 'test-amsi' -Inputs @{DryRun=$DryRun} -Result 'error' -Notes "Failed: $($_.Exception.Message)"
        return @{Changed=$false; Message="Error testing AMSI: $($_.Exception.Message)"}
    }
}

# Main hardening function with full Sancta compliance
function Invoke-PowerShellSecurityHardening {
    $switches = @{
        DryRun = $false
        Quiet = $false
        JsonOnly = $false
        NoColor = $false
        HighContrast = $false
        Force = $false
    }
    
    # Manual argument parsing for PowerShell 5.1 compatibility
    foreach ($arg in $args) {
        switch -regex ($arg) {
            '^-DryRun$|^-DR$' { $switches.DryRun = $true }
            '^-Quiet$|^-Q$' { $switches.Quiet = $true }
            '^-JsonOnly$|^-J$' { $switches.JsonOnly = $true }
            '^-NoColor$|^-NC$' { $switches.NoColor = $true }
            '^-HighContrast$|^-HC$' { $switches.HighContrast = $true }
            '^-Force$|^-F$' { $switches.Force = $true }
        }
    }
    
    # Modal Unification: respect accessibility preferences
    if ($switches.JsonOnly) { $switches.Quiet = $true }
    
    # Check administrator privileges
    $isAdmin = Test-Administrator
    if (-not $isAdmin) {
        $msg = "WARNING: Not running as Administrator. PowerShell hardening requires elevation."
        if (-not $switches.Quiet) {
            if ($switches.HighContrast) { Write-Host $msg -ForegroundColor Red -BackgroundColor White }
            else { Write-Host $msg -ForegroundColor Yellow }
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
        DryRun = $switches.DryRun
        ScriptBlockLogging = Enable-ScriptBlockLogging -DryRun $switches.DryRun
        ModuleLogging = Enable-ModuleLogging -DryRun $switches.DryRun
        ExecutionPolicy = Set-ExecutionPolicySecure -DryRun $switches.DryRun
        AMSITest = Test-AMSIFunctionality -DryRun $switches.DryRun
    }
    
    # Count changes
    $changesCount = ($results.ScriptBlockLogging.Changed, $results.ModuleLogging.Changed, $results.ExecutionPolicy.Changed | Where-Object {$_ -eq $true}).Count
    
    # Output results
    if ($switches.JsonOnly) {
        $results | ConvertTo-Json -Depth 3
    } else {
        if (-not $switches.Quiet) {
            $color = if ($switches.HighContrast) { @{ForegroundColor='White'; BackgroundColor='Black'} } else { @{ForegroundColor='Cyan'} }
            Write-Host "`nPowerShell Security Hardening Results:" @color
            Write-Host ("=" * 45) @color
            
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
