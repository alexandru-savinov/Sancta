# Sancta Windows Security Audit
# Read-only audit of Windows security posture. No changes are made.
# Following Sancta principles of transparency, accessibilit            $state.TPMPresent = if ($tpm | Get-Member -Name 'TmpPresent' -ErrorAction SilentlyContinue) { $tpm.TmpPresent } elseif ($tpm | Get-Member -Name 'TmpPresent' -ErrorAction SilentlyContinue) { $tpm.TmpPresent } else { $null }           $state.TPMPresent = if ($tpm | Get-Member -Name 'TmpPresent' -ErrorAction SilentlyContinue) { $tpm.TmpPresent } elseif ($tpm | Get-Member -Name 'TpmPresent' -ErrorAction SilentlyContinue) { $tpm.TpmPresent } else { $null }, and defensive programming

# Define receipt path at script level
$ReceiptPath = "${PSScriptRoot}\..\..\receipts\windows-hardening.audit.jsonl"

# Ensure receipts directory exists
$ReceiptDir = Split-Path $ReceiptPath -Parent
if (-not (Test-Path $ReceiptDir)) {
    New-Item -ItemType Directory -Path $ReceiptDir -Force | Out-Null
}

# Defensive programming - wrap calls that might fail
function Invoke-Safely { 
    param([scriptblock]$Code)
    try { & $Code } catch { $null }
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
    $entry = @{
        timestamp = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffZ')
        action = $Action
        inputs = $Inputs
        result = $Result
        notes = $Notes
        undo_command = $UndoCommand
    } | ConvertTo-Json -Compress
    $entry | Out-File -FilePath $ReceiptPath -Append -Encoding UTF8
}

function Get-DefenderState {
    $state = [ordered]@{}
    try {
        $mp = Get-MpPreference -ErrorAction Stop
        $state.RealtimeProtectionEnabled = -not $mp.DisableRealtimeMonitoring
        $state.CloudProtectionEnabled    = ($mp.MAPSReporting -ne 0)
        $state.PUAProtection             = $mp.PUAProtection -in 1,2
        $state.NetworkProtection         = ($mp.EnableNetworkProtection -eq 1)
        $state.ControlledFolderAccess    = ($mp.EnableControlledFolderAccess -eq 1)
        $state.ASRRules                  = @()
        if ($mp.AttackSurfaceReductionRules_Ids) {
            for ($i=0; $i -lt $mp.AttackSurfaceReductionRules_Ids.Count; $i++) {
                $state.ASRRules += [pscustomobject]@{
                    Id    = $mp.AttackSurfaceReductionRules_Ids[$i]
                    State = $mp.AttackSurfaceReductionRules_Actions[$i]
                }
            }
        }
    }
    catch {
        $state.Error = "Get-MpPreference failed: $($_.Exception.Message)"
    }
    $res = if ($state.Contains('Error') -and $state.Error) { 'unavailable' } else { 'ok' }
    $notes = if ($state.Contains('Error')) { $state.Error } else { '' }
    Write-Receipt -Action 'audit-defender' -Inputs @{} -Result $res -Notes $notes
    return $state
}

function Get-FirewallState {
    $state = [ordered]@{}
    try {
        # Use registry for firewall status (more reliable)
        $fwPath = 'HKLM:\SYSTEM\CurrentControlSet\Services\SharedAccess\Parameters\FirewallPolicy'
        $domainProfile = Get-ItemProperty -Path "$fwPath\DomainProfile" -ErrorAction SilentlyContinue
        $privateProfile = Get-ItemProperty -Path "$fwPath\PrivateProfile" -ErrorAction SilentlyContinue
        $publicProfile = Get-ItemProperty -Path "$fwPath\PublicProfile" -ErrorAction SilentlyContinue
        
        $state.DomainProfile  = if ($domainProfile) { -not $domainProfile.EnableFirewall -eq 0 } else { $null }
        $state.PrivateProfile = if ($privateProfile) { -not $privateProfile.EnableFirewall -eq 0 } else { $null }
        $state.PublicProfile  = if ($publicProfile) { -not $publicProfile.EnableFirewall -eq 0 } else { $null }
        
        if (($null -eq $state.DomainProfile) -and ($null -eq $state.PrivateProfile) -and ($null -eq $state.PublicProfile)) {
            $state.Error = 'Firewall registry keys not accessible'
        }
    }
    catch {
        $state.Error = "Firewall check failed: $($_.Exception.Message)"
    }
    $res = if ($state.Contains('Error') -and $state.Error) { 'unavailable' } else { 'ok' }
    $notes = if ($state.Contains('Error')) { $state.Error } else { '' }
    Write-Receipt -Action 'audit-firewall' -Inputs @{} -Result $res -Notes $notes
    return $state
}

function Get-RDPState {
    $state = [ordered]@{}
    try {
        $rdp = Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server' -Name fDenyTSConnections -ErrorAction SilentlyContinue
        $state.Enabled = if ($rdp) { $rdp.fDenyTSConnections -eq 0 } else { $null }
        if ($null -eq $state.Enabled) { $state.Error = 'RDP registry key not accessible' }
    }
    catch {
        $state.Error = "RDP check failed: $($_.Exception.Message)"
    }
    $res = if ($state.Contains('Error') -and $state.Error) { 'unavailable' } else { 'ok' }
    $notes = if ($state.Contains('Error')) { $state.Error } else { '' }
    Write-Receipt -Action 'audit-rdp' -Inputs @{} -Result $res -Notes $notes
    return $state
}

function Get-SMB1State {
    $state = [ordered]@{}
    try {
        $smb1 = Invoke-Safely { Get-WindowsOptionalFeature -Online -FeatureName SMB1Protocol }
        $state.Enabled = if ($smb1) { $smb1.State -eq 'Enabled' } else { $null }
        if ($null -eq $state.Enabled) { $state.Error = 'SMB1 feature status unavailable' }
    }
    catch {
        $state.Error = "SMB1 check failed: $($_.Exception.Message)"
    }
    $res = if ($state.Contains('Error') -and $state.Error) { 'unavailable' } else { 'ok' }
    $notes = if ($state.Contains('Error')) { $state.Error } else { '' }
    Write-Receipt -Action 'audit-smb1' -Inputs @{} -Result $res -Notes $notes
    return $state
}

function Get-LSAState {
    $state = [ordered]@{}
    try {
        # Check LSA Protection
        $lsaPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa'
        $lsa = Get-ItemProperty -Path $lsaPath -ErrorAction SilentlyContinue
        $state.RunAsPPL = if ($lsa -and (Get-Member -InputObject $lsa -Name RunAsPPL)) { $lsa.RunAsPPL -eq 1 } else { $null }
        
        # Check Credential Guard
        $cgPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard'
        $cg = Get-ItemProperty -Path $cgPath -ErrorAction SilentlyContinue
        $state.CredentialGuard = if ($cg -and (Get-Member -InputObject $cg -Name LsaCfgFlags)) { $cg.LsaCfgFlags -eq 1 } else { $null }
        
        if (($null -eq $state.RunAsPPL) -and ($null -eq $state.CredentialGuard)) {
            $state.Error = 'LSA/Credential Guard registry keys not accessible'
        }
    }
    catch {
        $state.Error = "LSA check failed: $($_.Exception.Message)"
    }
    $res = if ($state.Contains('Error') -and $state.Error) { 'unavailable' } else { 'ok' }
    $notes = if ($state.Contains('Error')) { $state.Error } else { '' }
    Write-Receipt -Action 'audit-lsa' -Inputs @{} -Result $res -Notes $notes
    return $state
}

function Get-SecureBootTPMState {
    $state = [ordered]@{}
    try {
        # Check Secure Boot
        $sb = Invoke-Safely { Confirm-SecureBootUEFI }
        $state.SecureBoot = $sb
        
        # Check TPM with defensive property access
        $tpm = Invoke-Safely { Get-Tpm }
        if ($tpm) {
            $state.TPMPresent = if ($tpm | Get-Member -Name 'TmpPresent' -ErrorAction SilentlyContinue) { $tmp.TmpPresent } elseif ($tpm | Get-Member -Name 'TpmPresent' -ErrorAction SilentlyContinue) { $tpm.TpmPresent } else { $null }
            $state.TPMReady = if ($tpm | Get-Member -Name 'TmpReady' -ErrorAction SilentlyContinue) { $tpm.TmpReady } elseif ($tpm | Get-Member -Name 'TpmReady' -ErrorAction SilentlyContinue) { $tpm.TpmReady } else { $null }
        } else { 
            $state.TPMPresent = $null
            $state.TPMReady = $null
        }
        if (($null -eq $state.SecureBoot) -and ($null -eq $state.TPMPresent)) { $state.Error = 'SecureBoot/TPM status unavailable' }
    }
    catch {
        $state.Error = "SecureBoot/TPM check failed: $($_.Exception.Message)"
    }
    $res = if ($state.Contains('Error') -and $state.Error) { 'unavailable' } else { 'ok' }
    $notes = if ($state.Contains('Error')) { $state.Error } else { '' }
    Write-Receipt -Action 'audit-secureboot-tpm' -Inputs @{} -Result $res -Notes $notes
    return $state
}

function Get-BitLockerState {
    $state = [ordered]@{}
    try {
        $bl = Invoke-Safely { Get-BitLockerVolume }
        if ($bl) {
            $state.Volumes = @()
            foreach ($vol in $bl) {
                $state.Volumes += [pscustomobject]@{
                    MountPoint = $vol.MountPoint
                    ProtectionStatus = $vol.ProtectionStatus
                    EncryptionPercentage = $vol.EncryptionPercentage
                }
            }
        } else {
            $state.Error = 'BitLocker cmdlets unavailable'
        }
    }
    catch {
        $state.Error = "BitLocker check failed: $($_.Exception.Message)"
    }
    $res = if ($state.Contains('Error') -and $state.Error) { 'unavailable' } else { 'ok' }
    $notes = if ($state.Contains('Error')) { $state.Error } else { '' }
    Write-Receipt -Action 'audit-bitlocker' -Inputs @{} -Result $res -Notes $notes
    return $state
}

function Get-SmartScreenState {
    $state = [ordered]@{}
    try {
        $ssPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'
        $ss = Get-ItemProperty -Path $ssPath -Name EnableSmartScreen -ErrorAction SilentlyContinue
        $state.Enabled = if ($ss) { $ss.EnableSmartScreen -eq 1 } else { $null }
        if ($null -eq $state.Enabled) { $state.Error = 'SmartScreen registry key not accessible' }
    }
    catch {
        $state.Error = "SmartScreen check failed: $($_.Exception.Message)"
    }
    $res = if ($state.Contains('Error') -and $state.Error) { 'unavailable' } else { 'ok' }
    $notes = if ($state.Contains('Error')) { $state.Error } else { '' }
    Write-Receipt -Action 'audit-smartscreen' -Inputs @{} -Result $res -Notes $notes
    return $state
}

function Get-AutoRunState {
    $state = [ordered]@{}
    try {
        $arPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer'
        $ar = Get-ItemProperty -Path $arPath -Name NoDriveTypeAutoRun -ErrorAction SilentlyContinue
        $state.Disabled = if ($ar) { $ar.NoDriveTypeAutoRun -eq 255 } else { $null }
        if ($null -eq $state.Disabled) { $state.Error = 'AutoRun registry key not accessible' }
    }
    catch {
        $state.Error = "AutoRun check failed: $($_.Exception.Message)"
    }
    $res = if ($state.Contains('Error') -and $state.Error) { 'unavailable' } else { 'ok' }
    $notes = if ($state.Contains('Error')) { $state.Error } else { '' }
    Write-Receipt -Action 'audit-autorun' -Inputs @{} -Result $res -Notes $notes
    return $state
}

# Main audit function
function Invoke-WindowsSecurityAudit {
    $switches = @{
        Quiet = $false
        JsonOnly = $false
        NoColor = $false
        HighContrast = $false
        Wide = $false
    }
    
    # Manual argument parsing for PowerShell 5.1 compatibility
    foreach ($arg in $args) {
        switch -regex ($arg) {
            '^-Quiet$|^-Q$' { $switches.Quiet = $true }
            '^-JsonOnly$|^-J$' { $switches.JsonOnly = $true }
            '^-NoColor$|^-NC$' { $switches.NoColor = $true }
            '^-HighContrast$|^-HC$' { $switches.HighContrast = $true }
            '^-Wide$|^-W$' { $switches.Wide = $true }
        }
    }
    
    # Modal Unification: respect accessibility preferences
    if ($switches.JsonOnly) { $switches.Quiet = $true }
    
    if (-not $switches.Quiet) {
        $msg = "Starting Windows Security Audit..."
        if ($switches.HighContrast) { Write-Host $msg -ForegroundColor Yellow -BackgroundColor Black }
        else { Write-Host $msg -ForegroundColor Green }
    }
    
    # Collect audit data
    $audit = [ordered]@{
        Timestamp = Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffZ'
        Defender = Get-DefenderState
        Firewall = Get-FirewallState
        RDP = Get-RDPState
        SMB1 = Get-SMB1State
        LSA = Get-LSAState
        SecureBootTPM = Get-SecureBootTPMState
        BitLocker = Get-BitLockerState
        SmartScreen = Get-SmartScreenState
        AutoRun = Get-AutoRunState
    }
    
    # Output results
    if ($switches.JsonOnly) {
        $audit | ConvertTo-Json -Depth 5
    } else {
        if (-not $switches.Quiet) {
            $color = if ($switches.HighContrast) { @{ForegroundColor='White'; BackgroundColor='Black'} } else { @{ForegroundColor='Cyan'} }
            Write-Host "`nWindows Security Audit Results:" @color
            Write-Host ("=" * 40) @color
        }
        $audit | Format-List
    }
    
    Write-Receipt -Action 'audit-complete' -Inputs $switches -Result 'ok' -Notes "Audit completed at $(Get-Date)"
    return $audit
}

# If script is run directly (not dot-sourced), execute the audit
if ($MyInvocation.InvocationName -ne '.') {
    Invoke-WindowsSecurityAudit @args
}
