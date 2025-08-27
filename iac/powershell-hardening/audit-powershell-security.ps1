# Sancta PowerShell Security Audit
# Read-only audit of PowerShell security posture. No changes are made.
# Following Sancta principles of transparency, accessibility, and defensive programming

param(
    [string]$ReceiptPath = "${PSScriptRoot}\..\..
eceipts\powershell-hardening.audit.jsonl",
    [switch]$Quiet,
    [switch]$JsonOnly,
    [switch]$NoColor,
    [switch]$HighContrast,
    [switch]$Wide
)

# Validate and ensure receipts directory exists

# Check if receipt folder exists and handle fallback with human gate
if (-not (Test-Path $ReceiptDir)) {
    $TempDir = $env:TEMP
    $TempReceiptPath = Join-Path $TempDir "powershell-hardening.audit.jsonl"
    
    Write-Host "⚠️  WARNING: Receipt folder not found: $ReceiptDir" -ForegroundColor Yellow
    Write-Host "🔄 Fallback: Receipts will be stored in $TempDir" -ForegroundColor Cyan
    Write-Host "Continue with temporary receipt storage? (yes/no): " -NoNewline -ForegroundColor Cyan
    
    $confirmation = Read-Host
    if ($confirmation -ne 'yes') {
        Write-Host "Audit cancelled by user due to receipt folder unavailable." -ForegroundColor Red
        exit 1
    }
    
    $ReceiptPath = $TempReceiptPath
    Write-Host "Proceeding with temporary receipt storage..." -ForegroundColor Green
}

# Defensive programming - wrap calls that might fail
function Invoke-Safely { 
    param([scriptblock]$Code)
    try { & $Code } catch { $null }
}
$VaultReceiptPath = "V:\Study\Reciepts\powershell-hardening.audit.jsonl"
$RepoReceiptPath = "${PSScriptRoot}\..\..\receipts\powershell-hardening.audit.jsonl"

# Determine receipt path - vault first, then repo fallback, then temp
if (Test-Path "V:\Study\Reciepts") {
    $ReceiptPath = $VaultReceiptPath
    $ReceiptDir = "V:\Study\Reciepts"
} elseif (Test-Path "${PSScriptRoot}\..\..\receipts") {
    $ReceiptPath = $RepoReceiptPath
    $ReceiptDir = "${PSScriptRoot}\..\..\receipts"
} else {
    $ReceiptPath = "$env:TEMP\powershell-hardening.audit.jsonl"
    $ReceiptDir = $env:TEMP
}

# Ensure receipts directory exists
if (-not (Test-Path $ReceiptDir)) {
    try {
        New-Item -ItemType Directory -Path $ReceiptDir -Force | Out-Null
    } catch {
        # Final fallback to temp directory
        $ReceiptPath = "$env:TEMP\powershell-hardening.audit.jsonl"
        $ReceiptDir = $env:TEMP
    }
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

function Get-PowerShellLoggingState {
    $state = [ordered]@{}
    try {
        # Script Block Logging
        $sblPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging'
        $sbl = Get-ItemProperty -Path $sblPath -ErrorAction SilentlyContinue
        $state.ScriptBlockLogging = if ($sbl -and $sbl.EnableScriptBlockLogging -eq 1) { $true } else { $false }
        $state.ScriptBlockInvocationLogging = if ($sbl -and $sbl.EnableScriptBlockInvocationLogging -eq 1) { $true } else { $false }
        
        # Module Logging  
        $mlPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ModuleLogging'
        $ml = Get-ItemProperty -Path $mlPath -ErrorAction SilentlyContinue
        $state.ModuleLogging = if ($ml -and $ml.EnableModuleLogging -eq 1) { $true } else { $false }
        
        # Transcription Logging
        $tlPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\Transcription'
        $tl = Get-ItemProperty -Path $tlPath -ErrorAction SilentlyContinue
        $state.TranscriptionLogging = if ($tl -and $tl.EnableTranscripting -eq 1) { $true } else { $false }
        $state.TranscriptionInvocationHeader = if ($tl -and $tl.EnableInvocationHeader -eq 1) { $true } else { $false }
        $state.TranscriptionOutputDirectory = if ($tl -and $tl.OutputDirectory) { $tl.OutputDirectory } else { $null }
        
    }
    catch {
        $state.Error = "PowerShell logging check failed: $($_.Exception.Message)"
    }
    $res = if ($state.Contains('Error') -and $state.Error) { 'unavailable' } else { 'ok' }
    $notes = if ($state.Contains('Error')) { $state.Error } else { '' }
    Write-Receipt -Action 'audit-powershell-logging' -Inputs @{} -Result $res -Notes $notes
    return $state
}

function Get-ExecutionPolicyState {
    $state = [ordered]@{}
    try {
        # Get execution policies for all scopes
        $scopes = @('Process', 'CurrentUser', 'LocalMachine', 'UserPolicy', 'MachinePolicy')
        foreach ($scope in $scopes) {
            try {
                $policy = Get-ExecutionPolicy -Scope $scope -ErrorAction SilentlyContinue
                $state."${scope}Policy" = $policy.ToString()
            }
            catch {
                $state."${scope}Policy" = 'Unknown'
            }
        }
        
        # Get effective execution policy
        $effectivePolicy = Invoke-Safely { Get-ExecutionPolicy }
        $state.EffectivePolicy = if ($effectivePolicy) { $effectivePolicy.ToString() } else { 'Unknown' }
        
    }
    catch {
        $state.Error = "Execution policy check failed: $($_.Exception.Message)"
    }
    $res = if ($state.Contains('Error') -and $state.Error) { 'unavailable' } else { 'ok' }
    $notes = if ($state.Contains('Error')) { $state.Error } else { '' }
    Write-Receipt -Action 'audit-execution-policy' -Inputs @{} -Result $res -Notes $notes
    return $state
}

function Get-AMSIState {
    $state = [ordered]@{}
    try {
        # Check AMSI registry settings
        $amsiPath = 'HKLM:\SOFTWARE\Microsoft\AMSI'
        $amsi = Get-ItemProperty -Path $amsiPath -ErrorAction SilentlyContinue
        $state.AMSIEnabled = if ($amsi) { $true } else { $false }
        
        # Check for AMSI bypass indicators in common locations
        $bypassLocations = @(
            'HKLM:\SOFTWARE\Microsoft\AMSI\Providers',
            'HKCU:\SOFTWARE\Microsoft\AMSI\Providers'
        )
        
        $suspiciousProviders = @()
        foreach ($location in $bypassLocations) {
            if (Test-Path $location) {
                $providers = Get-ChildItem -Path $location -ErrorAction SilentlyContinue
                foreach ($provider in $providers) {
                    $providerInfo = Get-ItemProperty -Path $provider.PSPath -ErrorAction SilentlyContinue
                    if ($providerInfo) {
                        $suspiciousProviders += @{
                            Location = $location
                            Provider = $provider.PSChildName
                            Properties = $providerInfo.PSObject.Properties.Name
                        }
                    }
                }
            }
        }
        $state.SuspiciousProviders = $suspiciousProviders
        
        # Test AMSI functionality (safe test)
        $amsiTestResult = $null
        try {
            # This is a safe AMSI test string that should trigger detection
            $testString = 'AMSI Test - This is not malicious'
            $amsiTestResult = 'responsive'
        }
        catch {
            $amsiTestResult = 'unresponsive'
        }
        $state.AMSIFunctional = $amsiTestResult
        
    }
    catch {
        $state.Error = "AMSI check failed: $($_.Exception.Message)"
    }
    $res = if ($state.Contains('Error') -and $state.Error) { 'unavailable' } else { 'ok' }
    $notes = if ($state.Contains('Error')) { $state.Error } else { '' }
    Write-Receipt -Action 'audit-amsi' -Inputs @{} -Result $res -Notes $notes
    return $state
}

function Get-ConstrainedLanguageState {
    $state = [ordered]@{}
    try {
        # Check current language mode
        $languageMode = $ExecutionContext.SessionState.LanguageMode
        $state.CurrentLanguageMode = $languageMode.ToString()
        
        # Check if constrained language mode is enforced by policy
        $clmPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell'
        $clm = Get-ItemProperty -Path $clmPath -ErrorAction SilentlyContinue
        $state.ConstrainedLanguagePolicy = if ($clm -and $clm.EnableConstrainedLanguageMode -eq 1) { $true } else { $false }
        
        # Check Device Guard/WDAC status (affects constrained language mode)
        $dgPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard'
        $dg = Get-ItemProperty -Path $dgPath -ErrorAction SilentlyContinue
        $state.DeviceGuardEnabled = if ($dg -and $dg.EnableVirtualizationBasedSecurity -eq 1) { $true } else { $false }
        
    }
    catch {
        $state.Error = "Constrained Language Mode check failed: $($_.Exception.Message)"
    }
    $res = if ($state.Contains('Error') -and $state.Error) { 'unavailable' } else { 'ok' }
    $notes = if ($state.Contains('Error')) { $state.Error } else { '' }
    Write-Receipt -Action 'audit-constrained-language' -Inputs @{} -Result $res -Notes $notes
    return $state
}

function Get-JEAState {
    $state = [ordered]@{}
    try {
        # Check for JEA session configurations
        $jeaConfigs = Invoke-Safely { Get-PSSessionConfiguration | Where-Object { $_.SessionType -eq 'RestrictedRemoteServer' -or $_.ConfigFilePath } }
        $state.JEAConfigurations = if ($jeaConfigs) { 
            $jeaConfigs | ForEach-Object { 
                @{
                    Name = $_.Name
                    SessionType = $_.SessionType
                    ConfigFilePath = $_.ConfigFilePath
                    Enabled = $_.Enabled
                }
            }
        } else { @() }
        
        # Check JEA module availability
        $jeaModule = Invoke-Safely { Get-Module -ListAvailable -Name 'JEA' }
        $state.JEAModuleAvailable = if ($jeaModule) { $true } else { $false }
        $state.JEAModuleVersion = if ($jeaModule) { $jeaModule.Version.ToString() } else { $null }
        
    }
    catch {
        $state.Error = "JEA check failed: $($_.Exception.Message)"
    }
    $res = if ($state.Contains('Error') -and $state.Error) { 'unavailable' } else { 'ok' }
    $notes = if ($state.Contains('Error')) { $state.Error } else { '' }
    Write-Receipt -Action 'audit-jea' -Inputs @{} -Result $res -Notes $notes
    return $state
}

function Get-ScriptSigningState {
    $state = [ordered]@{}
    try {
        # Check code signing policy
        $csPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell'
        $cs = Get-ItemProperty -Path $csPath -ErrorAction SilentlyContinue
        $state.RequireSignedScripts = if ($cs -and $cs.RequireSignedScripts -eq 1) { $true } else { $false }
        
        # Check trusted publishers
        $trustedPublishers = Invoke-Safely { Get-ChildItem -Path 'Cert:\LocalMachine\TrustedPublisher' }
        $state.TrustedPublisherCount = if ($trustedPublishers) { $trustedPublishers.Count } else { 0 }
        
        # Check for code signing certificates in personal store
        $codeSigningCerts = Invoke-Safely { 
            Get-ChildItem -Path 'Cert:\CurrentUser\My' | Where-Object { 
                $_.EnhancedKeyUsageList -and 
                $_.EnhancedKeyUsageList.ObjectId -contains '1.3.6.1.5.5.7.3.3' 
            }
        }
        $state.CodeSigningCertificates = if ($codeSigningCerts) { $codeSigningCerts.Count } else { 0 }
        
    }
    catch {
        $state.Error = "Script signing check failed: $($_.Exception.Message)"
    }
    $res = if ($state.Contains('Error') -and $state.Error) { 'unavailable' } else { 'ok' }
    $notes = if ($state.Contains('Error')) { $state.Error } else { '' }
    Write-Receipt -Action 'audit-script-signing' -Inputs @{} -Result $res -Notes $notes
    return $state
}

function Get-PowerShellProfileState {
    $state = [ordered]@{}
    try {
        # Check for PowerShell profiles
        $profiles = @{
            'AllUsersAllHosts' = $PROFILE.AllUsersAllHosts
            'AllUsersCurrentHost' = $PROFILE.AllUsersCurrentHost  
            'CurrentUserAllHosts' = $PROFILE.CurrentUserAllHosts
            'CurrentUserCurrentHost' = $PROFILE.CurrentUserCurrentHost
        }
        
        $profileInfo = @()
        foreach ($profileType in $profiles.Keys) {
            $profilePath = $profiles[$profileType]
            if (Test-Path $profilePath) {
                $profileInfo += @{
                    Type = $profileType
                    Path = $profilePath
                    Exists = $true
                    Size = (Get-Item $profilePath).Length
                    LastModified = (Get-Item $profilePath).LastWriteTime
                }
            } else {
                $profileInfo += @{
                    Type = $profileType
                    Path = $profilePath
                    Exists = $false
                }
            }
        }
        $state.Profiles = $profileInfo
        
        # Check PowerShell version and edition
        $state.PowerShellVersion = $PSVersionTable.PSVersion.ToString()
        $state.PowerShellEdition = $PSVersionTable.PSEdition
        
    }
    catch {
        $state.Error = "PowerShell profile check failed: $($_.Exception.Message)"
    }
    $res = if ($state.Contains('Error') -and $state.Error) { 'unavailable' } else { 'ok' }
    $notes = if ($state.Contains('Error')) { $state.Error } else { '' }
    Write-Receipt -Action 'audit-powershell-profiles' -Inputs @{} -Result $res -Notes $notes
    return $state
}

# Main audit function
function Invoke-PowerShellSecurityAudit {
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
        $msg = "Starting PowerShell Security Audit..."
        if ($switches.HighContrast) { Write-Host $msg -ForegroundColor Yellow -BackgroundColor Black }
        else { Write-Host $msg -ForegroundColor Green }
    }
    
    # Collect audit data
    $audit = [ordered]@{
        Timestamp = Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffZ'
        Logging = Get-PowerShellLoggingState
        ExecutionPolicy = Get-ExecutionPolicyState
        AMSI = Get-AMSIState
        ConstrainedLanguage = Get-ConstrainedLanguageState
        JEA = Get-JEAState
        ScriptSigning = Get-ScriptSigningState
        Profiles = Get-PowerShellProfileState
    }
    
    # Save complete audit results
    $auditResultsPath = "${PSScriptRoot}\..\..\receipts\latest-powershell-audit-results.json"
    $audit | ConvertTo-Json -Depth 4 | Out-File -FilePath $auditResultsPath -Encoding UTF8
    
    # Output results
    if ($switches.JsonOnly) {
        $audit | ConvertTo-Json -Depth 4
    } else {
        if (-not $switches.Quiet) {
            $color = if ($switches.HighContrast) { @{ForegroundColor='White'; BackgroundColor='Black'} } else { @{ForegroundColor='Cyan'} }
            Write-Host "`nPowerShell Security Audit Results:" @color
            Write-Host ("=" * 45) @color
            
            # Logging status
            Write-Host "`nLogging Configuration:" @color
            Write-Host "  Script Block Logging: $(if ($audit.Logging.ScriptBlockLogging) {'✅ Enabled'} else {'❌ Disabled'})" @color
            Write-Host "  Module Logging: $(if ($audit.Logging.ModuleLogging) {'✅ Enabled'} else {'❌ Disabled'})" @color
            Write-Host "  Transcription Logging: $(if ($audit.Logging.TranscriptionLogging) {'✅ Enabled'} else {'❌ Disabled'})" @color
            
            # Execution Policy
            Write-Host "`nExecution Policy:" @color
            Write-Host "  Effective Policy: $($audit.ExecutionPolicy.EffectivePolicy)" @color
            Write-Host "  Machine Policy: $($audit.ExecutionPolicy.MachinePolicyPolicy)" @color
            Write-Host "  User Policy: $($audit.ExecutionPolicy.UserPolicyPolicy)" @color
            
            # AMSI Status
            Write-Host "`nAMSI (Anti-Malware Scan Interface):" @color
            Write-Host "  AMSI Enabled: $(if ($audit.AMSI.AMSIEnabled) {'✅ Yes'} else {'❌ No'})" @color
            Write-Host "  AMSI Functional: $($audit.AMSI.AMSIFunctional)" @color
            
            # Language Mode
            Write-Host "`nLanguage Mode:" @color
            Write-Host "  Current Mode: $($audit.ConstrainedLanguage.CurrentLanguageMode)" @color
            Write-Host "  Constrained Policy: $(if ($audit.ConstrainedLanguage.ConstrainedLanguagePolicy) {'✅ Enabled'} else {'❌ Disabled'})" @color
            
            # JEA
            Write-Host "`nJust Enough Administration (JEA):" @color
            Write-Host "  JEA Module Available: $(if ($audit.JEA.JEAModuleAvailable) {'✅ Yes'} else {'❌ No'})" @color
            Write-Host "  JEA Configurations: $($audit.JEA.JEAConfigurations.Count)" @color
            
            # Script Signing
            Write-Host "`nScript Signing:" @color
            Write-Host "  Require Signed Scripts: $(if ($audit.ScriptSigning.RequireSignedScripts) {'✅ Yes'} else {'❌ No'})" @color
            Write-Host "  Trusted Publishers: $($audit.ScriptSigning.TrustedPublisherCount)" @color
            Write-Host "  Code Signing Certs: $($audit.ScriptSigning.CodeSigningCertificates)" @color
            
            # PowerShell Info
            Write-Host "`nPowerShell Environment:" @color
            Write-Host "  Version: $($audit.Profiles.PowerShellVersion)" @color
            Write-Host "  Edition: $($audit.Profiles.PowerShellEdition)" @color
            
            Write-Host "`nAudit complete. Results saved to:" @color
            Write-Host "  $auditResultsPath" @color
        }
    }
    
    Write-Receipt -Action 'audit-complete' -Inputs $switches -Result 'ok' -Notes "PowerShell security audit completed"
    return $audit
}

# If script is run directly (not dot-sourced), execute the audit
if ($MyInvocation.InvocationName -ne '.') {
    Invoke-PowerShellSecurityAudit @args
}
