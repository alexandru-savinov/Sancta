# Requires: PowerShell 5.1+, winget, ability to elevate for provisioned removal
param(
    [string[]] $Targets,           # Preferred: canonical winget IDs or AppX family names. Can be friendly names; we'll resolve.
    [switch]   $DryRun,            # No changes, only plan + receipts with result=dry-run
    [switch]   $Canary,            # Run canary (uninstall + reinstall one target) before batch
    [switch]   $Deprovision,       # Include AppX deprovisioning (phase 2), requires second confirmation
    [string]   $ReceiptsPath = "$env:USERPROFILE\Documents\Sancta\receipts\windows-app-cleanup.jsonl"
)

# --- Helpers -----------------------------------------------------------------

function Write-Receipt {
    param(
        [string] $Action,
        [hashtable] $Inputs,
        [string] $Result,
        [string] $Undo = "",
        [string] $Notes = "",
        [hashtable] $Validation = $null
    )
    $entry = [ordered]@{
        timestamp = (Get-Date).ToString("o")
        action    = $Action
        inputs    = $Inputs
        result    = $Result
        path      = ""
        elevated  = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        undo      = $Undo
        notes     = $Notes
        dryRun    = [bool]$DryRun
        hostname  = $env:COMPUTERNAME
        user      = $env:USERNAME
    }
    if ($Validation) { $entry["validation"] = $Validation }
    $json = ($entry | ConvertTo-Json -Compress)
    
    # Ensure receipts directory and file exist
    $receiptDir = Split-Path -Parent $ReceiptsPath
    if ($receiptDir) {
        New-Item -ItemType Directory -Force -Path $receiptDir | Out-Null
    }
    if (-not (Test-Path $ReceiptsPath)) {
        New-Item -ItemType File -Force -Path $ReceiptsPath | Out-Null
    }
    
    Add-Content -Path $ReceiptsPath -Value $json
    Write-Host $json
}

function Assert-Tool {
    param([string]$Name)
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        Write-Receipt -Action 'assert-tool' -Inputs @{tool=$Name} -Result 'missing'
        throw "Required tool not found: $Name"
    }
    Write-Receipt -Action 'assert-tool' -Inputs @{tool=$Name} -Result 'present'
}

function Invoke-Winget {
    param([string[]]$Args)
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "winget"
    $psi.Arguments = ($Args -join ' ')
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError  = $true
    $p = [System.Diagnostics.Process]::Start($psi)
    $out = $p.StandardOutput.ReadToEnd()
    $err = $p.StandardError.ReadToEnd()
    $p.WaitForExit()
    return [pscustomobject]@{ ExitCode=$p.ExitCode; StdOut=$out; StdErr=$err }
}

function Resolve-WingetId {
    param([string]$Query)
    # Try exact ID first
    $show = Invoke-Winget @("show","--id",$Query,"-e")
    if ($show.ExitCode -eq 0 -and $show.StdOut) {
        $pubMatch = $show.StdOut | Select-String -Pattern 'Publisher:\s*(.+)' -AllMatches
        $pub = if ($pubMatch -and $pubMatch.Matches) { 
            $pubMatch.Matches[0].Groups[1].Value.Trim() 
        } else { 
            "Unknown" 
        }
        return [pscustomobject]@{ Status="verified"; Id=$Query; Publisher=$pub; Source="winget" }
    }
    # Try search by id
    $search = Invoke-Winget @("search","--id",$Query)
    if ($search.ExitCode -eq 0 -and $search.StdOut -match '^\s*\S+') {
        # Heuristic: take the first match row that looks like an ID
        $line = ($search.StdOut -split "`r?`n" | Where-Object { $_ -match '^\S+\s+' } | Select-Object -First 1)
        $id = $line.Split() | Select-Object -First 1
        if ($id) {
            $show2 = Invoke-Winget @("show","--id",$id,"-e")
            $pubMatch2 = $show2.StdOut | Select-String -Pattern 'Publisher:\s*(.+)' -AllMatches
            $pub2 = if ($pubMatch2 -and $pubMatch2.Matches) { 
                $pubMatch2.Matches[0].Groups[1].Value.Trim() 
            } else { 
                "Unknown" 
            }
            return [pscustomobject]@{ Status="resolved"; Id=$id; Publisher=$pub2; Source="winget" }
        }
    }
    return [pscustomobject]@{ Status="invalid-id"; Id=$Query; Publisher=""; Source="winget" }
}

function Get-AppInventory {
    # Winget inventory
    $wg = Invoke-Winget @("list")
    $wingetRows = @()
    if ($wg.ExitCode -eq 0) {
        $wingetRows = ($wg.StdOut -split "`r?`n") | Where-Object { $_ -and $_ -notmatch 'Name\s+Id\s+Version' -and $_ -notmatch '^-+$' }
    }
    # AppX current-user
    $appx = Get-AppxPackage | Select-Object Name, PackageFamilyName, Publisher, Version
    # Provisioned (requires elevation)
    $prov = @()
    try {
        $prov = Get-AppxProvisionedPackage -Online -ErrorAction Stop | Select-Object DisplayName, PackageName, Version
    } catch {
        Write-Receipt -Action 'inventory-warning' -Inputs @{component='provisioned'} -Result 'skipped' -Notes "Provisioned package inventory requires elevation: $_"
    }
    return [pscustomobject]@{
        WingetRaw = $wingetRows
        Appx = $appx
        Provisioned = $prov
    }
}

function Confirm-YES {
    param([string]$Prompt)
    $reply = Read-Host $Prompt
    if ($reply -ne "YES") { throw "Aborted by user." }
}

function Uninstall-Winget {
    param([string]$Id)
    if ($DryRun) {
        Write-Receipt -Action 'winget-uninstall' -Inputs @{appId=$Id} -Result 'dry-run' -Undo "winget install --id $Id -e"
        return 0
    }
    $res = Invoke-Winget @("uninstall","--id",$Id,"-e","--silent","--accept-source-agreements")
    $result = if ($res.ExitCode -eq 0) { "success" } else { "failed" }
    Write-Receipt -Action 'winget-uninstall' -Inputs @{appId=$Id} -Result $result -Undo "winget install --id $Id -e" -Notes $res.StdErr
    return $res.ExitCode
}

function Remove-Appx-CurrentUser {
    param([string]$PackageNameOrFamily)
    if ($DryRun) {
        Write-Receipt -Action 'appx-remove' -Inputs @{target=$PackageNameOrFamily; scope="current-user"} -Result 'dry-run' -Undo 'Reinstall via Store or winget if available'
        return
    }
    try {
        Get-AppxPackage -Name $PackageNameOrFamily -ErrorAction Stop | Remove-AppxPackage -ErrorAction Stop
        Write-Receipt -Action 'appx-remove' -Inputs @{target=$PackageNameOrFamily; scope="current-user"} -Result 'success' -Undo 'Reinstall via Store or winget if available'
    } catch {
        Write-Receipt -Action 'appx-remove' -Inputs @{target=$PackageNameOrFamily; scope="current-user"} -Result 'failed' -Notes "$_"
    }
}

function Remove-AppxProvisioned {
    param([string]$DisplayNameOrPkg)
    if ($DryRun) {
        Write-Receipt -Action 'appx-deprovision' -Inputs @{target=$DisplayNameOrPkg} -Result 'dry-run' -Undo 'Add-AppxProvisionedPackage -Online ...'
        return
    }
    try {
        Remove-AppxProvisionedPackage -Online -PackageName $DisplayNameOrPkg -ErrorAction Stop | Out-Null
        Write-Receipt -Action 'appx-deprovision' -Inputs @{target=$DisplayNameOrPkg} -Result 'success' -Undo 'Add-AppxProvisionedPackage -Online ...'
    } catch {
        Write-Receipt -Action 'appx-deprovision' -Inputs @{target=$DisplayNameOrPkg} -Result 'failed' -Notes "$_"
    }
}

# --- Main --------------------------------------------------------------------

# Only execute main logic if script is run directly (not dot-sourced)
if ($MyInvocation.InvocationName -ne '.') {
    try {
        Assert-Tool -Name "winget"

        $invBefore = Get-AppInventory
        Write-Receipt -Action 'inventory' -Inputs @{phase='before'} -Result 'success' -Notes ("wingetRows=" + $invBefore.WingetRaw.Count)

    # Resolve targets (winget first). Agent can pass friendly names; we resolve and record provenance.
    $resolved = @()
    foreach ($t in ($Targets | Where-Object { $_ })) {
        $r = Resolve-WingetId -Query $t
        $resolved += $r
        Write-Receipt -Action 'validate-target' -Inputs @{requested=$t} -Result $r.Status -Notes $r.Publisher -Validation @{ status=$r.Status; publisher=$r.Publisher; checkedAt=(Get-Date).ToString("o") }
    }

    # Proposed plan (winget only for now; AppX will be discovered separately if -Deprovision)
    $plan = $resolved | Where-Object { $_.Status -in @("verified","resolved") } | Select-Object Id, Publisher, Source

    # Present plan and gate
    Write-Host "Proposed winget removals:" -ForegroundColor Cyan
    $plan | ForEach-Object { "{0} (Publisher: {1})" -f $_.Id, $_.Publisher } | Write-Host
    Confirm-YES -Prompt "Type 'YES' to proceed with Phase 1 winget uninstall (or Ctrl+C to abort)"

    # Optional canary
    if ($Canary -and $plan.Count -gt 0) {
        $first = $plan[0].Id
        Write-Host "Running canary uninstall+reinstall for $first ..." -ForegroundColor Yellow
        if (-not $DryRun) { Uninstall-Winget -Id $first | Out-Null } else { Uninstall-Winget -Id $first | Out-Null }
        if (-not $DryRun) {
            $re = Invoke-Winget @("install","--id",$first,"-e","--silent","--accept-source-agreements")
            $rRes = if ($re.ExitCode -eq 0) { "success" } else { "failed" }
            Write-Receipt -Action 'winget-install' -Inputs @{appId=$first; phase='canary-rollback'} -Result $rRes -Notes $re.StdErr
        } else {
            Write-Receipt -Action 'winget-install' -Inputs @{appId=$first; phase='canary-rollback'} -Result 'dry-run' -Undo ''
        }
    }

    # Phase 1: winget removals
    foreach ($p in $plan) {
        [void](Uninstall-Winget -Id $p.Id)
    }

    # Phase 2: AppX (optional, gated)
    if ($Deprovision) {
        Write-Host "Phase 2 (AppX) will remove current-user packages and deprovision for new users. Elevation may be required." -ForegroundColor Cyan
        Confirm-YES -Prompt "Type 'YES' to proceed with AppX deprovisioning"

        # Discover candidates loosely matching the requested names to avoid accidental core removals.
        # Agent should prefer explicit family/package names for safety.
        $currentUserAppx = Get-AppxPackage
        $provAppx = @()
        try {
            $provAppx = Get-AppxProvisionedPackage -Online -ErrorAction Stop
        } catch {
            Write-Receipt -Action 'deprovision-warning' -Inputs @{} -Result 'skipped' -Notes "Deprovisioning requires elevation: $_"
        }

        foreach ($t in ($Targets | Where-Object { $_ })) {
            $hits = $currentUserAppx | Where-Object { $_.Name -like "*$t*" -or $_.PackageFamilyName -like "*$t*" }
            foreach ($h in $hits) {
                Remove-Appx-CurrentUser -PackageNameOrFamily $h.Name
            }
            $phits = $provAppx | Where-Object { $_.DisplayName -like "*$t*" -or $_.PackageName -like "*$t*" }
            foreach ($ph in $phits) {
                Remove-AppxProvisioned -DisplayNameOrPkg $ph.PackageName
            }
        }
    }

    # Verify
    $invAfter = Get-AppInventory
    Write-Receipt -Action 'inventory' -Inputs @{phase='after'} -Result 'success' -Notes ("wingetRows=" + $invAfter.WingetRaw.Count)

    # Summary note (human-friendly line)
    $summary = "Cleanup run complete (DryRun=$DryRun, Canary=$Canary, Deprovision=$Deprovision). See $ReceiptsPath for JSON receipts."
    Write-Receipt -Action 'summary' -Inputs @{} -Result 'success' -Notes $summary
    Write-Host $summary -ForegroundColor Green

} catch {
    Write-Receipt -Action 'orchestrator-error' -Inputs @{} -Result 'failed' -Notes "$_"
    throw
}
}
