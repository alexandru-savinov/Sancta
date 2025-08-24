# Sancta Windows Security Hardening
# Implements priority security hardening based on audit findings
# Following Sancta principles of transparency, idempotence, and defensive programming

# Define receipt path at script level - handle elevated/non-elevated contexts
$ReceiptPath = "${PSScriptRoot}\..\..\receipts\windows-hardening.jsonl"

# Ensure receipts directory exists and is writable
$ReceiptDir = Split-Path $ReceiptPath -Parent
if (-not (Test-Path $ReceiptDir)) {
    try {
        New-Item -ItemType Directory -Path $ReceiptDir -Force | Out-Null
    }
    catch {
        # Fallback to temp directory if can't write to original location
        $ReceiptDir = $env:TEMP
        $ReceiptPath = Join-Path $ReceiptDir "windows-hardening.jsonl"
    }
}

# Test write access
try {
    "test" | Out-File -FilePath $ReceiptPath -Append -Encoding UTF8 -ErrorAction Stop
    # Remove test line
    $content = Get-Content $ReceiptPath | Where-Object { $_ -ne "test" }
    $content | Set-Content $ReceiptPath
}
catch {
    # Fallback to temp directory
    $ReceiptDir = $env:TEMP
    $ReceiptPath = Join-Path $ReceiptDir "windows-hardening.jsonl"
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
            action = $Action
            inputs = $Inputs
            result = $Result
            notes = $Notes
            undo_command = $UndoCommand
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

# Enable Windows Defender Network Protection
function Enable-NetworkProtection {
    param([bool]$DryRun = $false)
    
    try {
        $current = Get-MpPreference -ErrorAction Stop
        $currentState = $current.EnableNetworkProtection
        
        if ($currentState -eq 1) {
            Write-Receipt -Action 'enable-network-protection' -Inputs @{DryRun=$DryRun} -Result 'already-enabled' -Notes 'Network Protection already enabled'
            return @{Changed=$false; Message='Network Protection already enabled'}
        }
        
        if ($DryRun) {
            Write-Receipt -Action 'enable-network-protection' -Inputs @{DryRun=$true} -Result 'would-change' -Notes "Would enable Network Protection (current: $currentState)" -UndoCommand 'Set-MpPreference -EnableNetworkProtection Disabled'
            return @{Changed=$true; Message="[DRY RUN] Would enable Network Protection (current state: $currentState)"}
        }
        
        Set-MpPreference -EnableNetworkProtection Enabled -ErrorAction Stop
        Write-Receipt -Action 'enable-network-protection' -Inputs @{DryRun=$false} -Result 'enabled' -Notes "Network Protection enabled (was: $currentState)" -UndoCommand 'Set-MpPreference -EnableNetworkProtection Disabled'
        return @{Changed=$true; Message='Network Protection enabled successfully'}
    }
    catch {
        Write-Receipt -Action 'enable-network-protection' -Inputs @{DryRun=$DryRun} -Result 'error' -Notes "Failed: $($_.Exception.Message)"
        return @{Changed=$false; Message="Error: $($_.Exception.Message)"}
    }
}

# Enable LSA Protection (RunAsPPL)
function Enable-LSAProtection {
    param([bool]$DryRun = $false)
    
    try {
        $lsaPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa'
        $current = Get-ItemProperty -Path $lsaPath -Name RunAsPPL -ErrorAction SilentlyContinue
        $currentValue = if ($current) { $current.RunAsPPL } else { 0 }
        
        if ($currentValue -eq 1) {
            Write-Receipt -Action 'enable-lsa-protection' -Inputs @{DryRun=$DryRun} -Result 'already-enabled' -Notes 'LSA Protection already enabled'
            return @{Changed=$false; Message='LSA Protection already enabled'}
        }
        
        if ($DryRun) {
            Write-Receipt -Action 'enable-lsa-protection' -Inputs @{DryRun=$true} -Result 'would-change' -Notes "Would enable LSA Protection (current: $currentValue)" -UndoCommand "Set-ItemProperty -Path '$lsaPath' -Name RunAsPPL -Value 0"
            return @{Changed=$true; Message="[DRY RUN] Would enable LSA Protection (current: $currentValue) - REQUIRES REBOOT"}
        }
        
        Set-ItemProperty -Path $lsaPath -Name RunAsPPL -Value 1 -Type DWord -ErrorAction Stop
        Write-Receipt -Action 'enable-lsa-protection' -Inputs @{DryRun=$false} -Result 'enabled' -Notes "LSA Protection enabled (was: $currentValue) - REQUIRES REBOOT" -UndoCommand "Set-ItemProperty -Path '$lsaPath' -Name RunAsPPL -Value 0"
        return @{Changed=$true; Message='LSA Protection enabled - REBOOT REQUIRED for changes to take effect'}
    }
    catch {
        Write-Receipt -Action 'enable-lsa-protection' -Inputs @{DryRun=$DryRun} -Result 'error' -Notes "Failed: $($_.Exception.Message)"
        return @{Changed=$false; Message="Error: $($_.Exception.Message)"}
    }
}

# Configure essential Attack Surface Reduction Rules
function Enable-ASRRules {
    param([bool]$DryRun = $false)
    
    # Essential ASR rules for basic protection
    $essentialRules = @{
        '56a863a9-875e-4185-98a7-b882c64b5ce5' = 'Block abuse of exploited vulnerable signed drivers'
        '7674ba52-37eb-4a4f-a9a1-f0f9a1619a2c' = 'Block Adobe Reader from creating child processes'
        'd4f940ab-401b-4efc-aadc-ad5f3c50688a' = 'Block all Office applications from creating child processes'
        '9e6c4e1f-7d60-472f-ba1a-a39ef669e4b2' = 'Block credential stealing from Windows local security authority subsystem (lsass.exe)'
        'be9ba2d9-53ea-4cdc-84e5-9b1eeee46550' = 'Block executable content from email client and webmail'
    }
    
    try {
        $mp = Get-MpPreference -ErrorAction Stop
        $currentRules = @{}
        
        if ($mp.AttackSurfaceReductionRules_Ids) {
            for ($i = 0; $i -lt $mp.AttackSurfaceReductionRules_Ids.Count; $i++) {
                $currentRules[$mp.AttackSurfaceReductionRules_Ids[$i]] = $mp.AttackSurfaceReductionRules_Actions[$i]
            }
        }
        
        $rulesToAdd = @()
        $actionsToAdd = @()
        $changes = @()
        
        foreach ($ruleId in $essentialRules.Keys) {
            if (-not $currentRules.ContainsKey($ruleId) -or $currentRules[$ruleId] -ne 1) {
                $rulesToAdd += $ruleId
                $actionsToAdd += 1  # 1 = Block, 2 = Audit
                $changes += "Enable: $($essentialRules[$ruleId])"
            }
        }
        
        if ($rulesToAdd.Count -eq 0) {
            Write-Receipt -Action 'enable-asr-rules' -Inputs @{DryRun=$DryRun} -Result 'already-configured' -Notes 'Essential ASR rules already configured'
            return @{Changed=$false; Message='Essential ASR rules already configured'}
        }
        
        if ($DryRun) {
            $changesList = $changes -join '; '
            Write-Receipt -Action 'enable-asr-rules' -Inputs @{DryRun=$true; Rules=$rulesToAdd.Count} -Result 'would-change' -Notes "Would configure $($rulesToAdd.Count) ASR rules: $changesList" -UndoCommand 'Remove-MpPreference -AttackSurfaceReductionRules_Ids <ruleids>'
            return @{Changed=$true; Message="[DRY RUN] Would configure $($rulesToAdd.Count) essential ASR rules"}
        }
        
        # Combine existing rules with new ones
        $allRuleIds = @()
        $allActions = @()
        
        if ($mp.AttackSurfaceReductionRules_Ids) {
            $allRuleIds += $mp.AttackSurfaceReductionRules_Ids
            $allActions += $mp.AttackSurfaceReductionRules_Actions
        }
        
        $allRuleIds += $rulesToAdd
        $allActions += $actionsToAdd
        
        Set-MpPreference -AttackSurfaceReductionRules_Ids $allRuleIds -AttackSurfaceReductionRules_Actions $allActions -ErrorAction Stop
        
        $changesList = $changes -join '; '
        Write-Receipt -Action 'enable-asr-rules' -Inputs @{DryRun=$false; Rules=$rulesToAdd.Count} -Result 'configured' -Notes "Configured $($rulesToAdd.Count) ASR rules: $changesList" -UndoCommand 'Reset ASR rules via Group Policy or Remove-MpPreference'
        return @{Changed=$true; Message="Configured $($rulesToAdd.Count) essential ASR rules successfully"}
    }
    catch {
        Write-Receipt -Action 'enable-asr-rules' -Inputs @{DryRun=$DryRun} -Result 'error' -Notes "Failed: $($_.Exception.Message)"
        return @{Changed=$false; Message="Error: $($_.Exception.Message)"}
    }
}

# Check BitLocker status using multiple methods for better compatibility
function Get-BitLockerStatus {
    param([bool]$DryRun = $false)
    
    try {
        # Try manage-bde first
        $output = & manage-bde -status 2>&1
        if ($LASTEXITCODE -eq 0) {
            $drives = @()
            $currentDrive = $null
            
            foreach ($line in $output) {
                if ($line -match '^Volume ([A-Z]:)') {
                    if ($currentDrive) { $drives += $currentDrive }
                    $currentDrive = @{Drive = $Matches[1]; ProtectionStatus = 'Unknown'; EncryptionStatus = 'Unknown'}
                }
                elseif ($line -match 'Protection Status:\s*(.+)') {
                    if ($currentDrive) { $currentDrive.ProtectionStatus = $Matches[1].Trim() }
                }
                elseif ($line -match 'Conversion Status:\s*(.+)') {
                    if ($currentDrive) { $currentDrive.EncryptionStatus = $Matches[1].Trim() }
                }
            }
            if ($currentDrive) { $drives += $currentDrive }
            
            $status = @{
                Available = $true
                Method = 'manage-bde'
                Drives = $drives
                SystemDriveEncrypted = ($null -ne ($drives | Where-Object {$_.Drive -eq 'C:' -and $_.ProtectionStatus -eq 'Protection On'}))
            }
            
            Write-Receipt -Action 'check-bitlocker' -Inputs @{DryRun=$DryRun} -Result 'ok' -Notes "Found $($drives.Count) drives via manage-bde, System drive encrypted: $($status.SystemDriveEncrypted)"
            return $status
        }
        
        # Fallback to WMI if manage-bde fails
        $wmiVolumes = Get-WmiObject -Namespace "Root\cimv2\security\microsoftvolumeencryption" -Class "Win32_EncryptableVolume" -ErrorAction SilentlyContinue
        if ($wmiVolumes) {
            $drives = @()
            foreach ($vol in $wmiVolumes) {
                $drives += @{
                    Drive = $vol.DriveLetter + ':'
                    ProtectionStatus = switch ($vol.ProtectionStatus) {
                        0 { 'Protection Off' }
                        1 { 'Protection On' } 
                        2 { 'Protection Unknown' }
                        default { 'Unknown' }
                    }
                    EncryptionMethod = $vol.EncryptionMethod
                }
            }
            
            $status = @{
                Available = $true
                Method = 'WMI'
                Drives = $drives
                SystemDriveEncrypted = ($null -ne ($drives | Where-Object {$_.Drive -eq 'C:' -and $_.ProtectionStatus -eq 'Protection On'}))
            }
            
            Write-Receipt -Action 'check-bitlocker' -Inputs @{DryRun=$DryRun} -Result 'ok' -Notes "Found $($drives.Count) drives via WMI, System drive encrypted: $($status.SystemDriveEncrypted)"
            return $status
        }
        
        # If both methods fail
        Write-Receipt -Action 'check-bitlocker' -Inputs @{DryRun=$DryRun} -Result 'unavailable' -Notes 'Both manage-bde and WMI methods unavailable'
        return @{Available=$false; Method='none'; Message='BitLocker status unavailable (manage-bde and WMI failed)'}
        
    }
    catch {
        Write-Receipt -Action 'check-bitlocker' -Inputs @{DryRun=$DryRun} -Result 'error' -Notes "Failed: $($_.Exception.Message)"
        return @{Available=$false; Method='error'; Message="Error checking BitLocker: $($_.Exception.Message)"}
    }
}

# Main hardening function
function Invoke-WindowsSecurityHardening {
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
        $msg = "WARNING: Not running as Administrator. Some hardening actions may fail."
        if (-not $switches.Quiet) {
            if ($switches.HighContrast) { Write-Host $msg -ForegroundColor Red -BackgroundColor White }
            else { Write-Host $msg -ForegroundColor Yellow }
        }
    }
    
    if (-not $switches.Quiet) {
        $mode = if ($switches.DryRun) { "DRY RUN" } else { "LIVE" }
        $msg = "Starting Windows Security Hardening ($mode)..."
        if ($switches.HighContrast) { Write-Host $msg -ForegroundColor Yellow -BackgroundColor Black }
        else { Write-Host $msg -ForegroundColor Green }
    }
    
    # Interactive confirmation for live changes (unless -Force is used)
    if (-not $switches.DryRun -and -not $switches.Force -and -not $switches.JsonOnly) {
        Write-Host "`nPROCEED WITH HARDENING? This will make the following changes:" -ForegroundColor Cyan
        Write-Host "1. Enable Network Protection (immediate effect)" -ForegroundColor White
        Write-Host "2. Enable LSA Protection (requires reboot)" -ForegroundColor White  
        Write-Host "3. Configure 5 ASR rules (immediate effect)" -ForegroundColor White
        Write-Host "`nThese changes will improve your security but LSA Protection requires a reboot." -ForegroundColor Yellow
        Write-Host "Type 'yes' to continue or anything else to cancel: " -NoNewline -ForegroundColor Cyan
        
        $confirmation = Read-Host
        if ($confirmation -ne 'yes') {
            Write-Host "Hardening cancelled by user." -ForegroundColor Red
            Write-Receipt -Action 'hardening-cancelled' -Inputs $switches -Result 'cancelled' -Notes "User chose not to proceed"
            return @{
                Timestamp = Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffZ'
                Cancelled = $true
                Message = "Hardening cancelled by user"
            }
        }
        Write-Host "Proceeding with hardening..." -ForegroundColor Green
    }
    
    # Execute hardening actions
    $results = [ordered]@{
        Timestamp = Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffZ'
        IsAdministrator = $isAdmin
        DryRun = $switches.DryRun
        NetworkProtection = Enable-NetworkProtection -DryRun $switches.DryRun
        LSAProtection = Enable-LSAProtection -DryRun $switches.DryRun
        ASRRules = Enable-ASRRules -DryRun $switches.DryRun
        BitLockerStatus = Get-BitLockerStatus -DryRun $switches.DryRun
    }
    
    # Count changes
    $changesCount = ($results.NetworkProtection.Changed, $results.LSAProtection.Changed, $results.ASRRules.Changed | Where-Object {$_ -eq $true}).Count
    
    # Output results
    if ($switches.JsonOnly) {
        $results | ConvertTo-Json -Depth 3
    } else {
        if (-not $switches.Quiet) {
            $color = if ($switches.HighContrast) { @{ForegroundColor='White'; BackgroundColor='Black'} } else { @{ForegroundColor='Cyan'} }
            Write-Host "`nWindows Security Hardening Results:" @color
            Write-Host ("=" * 45) @color
            
            $statusColor = if ($switches.HighContrast) { @{ForegroundColor='Yellow'; BackgroundColor='Black'} } else { @{ForegroundColor='Yellow'} }
            Write-Host "Mode: $(if ($switches.DryRun) {'DRY RUN'} else {'LIVE CHANGES'})" @statusColor
            Write-Host "Administrator: $isAdmin" @statusColor
            Write-Host "Changes: $changesCount" @statusColor
            Write-Host ""
            
            Write-Host "Network Protection: $($results.NetworkProtection.Message)" @color
            Write-Host "LSA Protection: $($results.LSAProtection.Message)" @color  
            Write-Host "ASR Rules: $($results.ASRRules.Message)" @color
            
            if ($results.BitLockerStatus.Available) {
                Write-Host "BitLocker Status: System drive encrypted = $($results.BitLockerStatus.SystemDriveEncrypted)" @color
            } else {
                Write-Host "BitLocker Status: $($results.BitLockerStatus.Message)" @color
            }
        }
    }
    
    Write-Receipt -Action 'hardening-complete' -Inputs $switches -Result 'ok' -Notes "Hardening completed at $(Get-Date), $changesCount changes made"
    return $results
}

# If script is run directly (not dot-sourced), execute the hardening
if ($MyInvocation.InvocationName -ne '.') {
    Invoke-WindowsSecurityHardening @args
}
