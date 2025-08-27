# Sancta PowerShell Security Hardening
param(
    [string]$ReceiptPath = "V:\Study\Reciepts\powershell-hardening.jsonl",
    [switch]$DryRun,
    [switch]$Quiet,
    [switch]$Force
)

Write-Host "Starting PowerShell Security Hardening..." -ForegroundColor Green

# Check admin privileges
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin -and -not $DryRun) {
    Write-Host "Warning: Not running as Administrator." -ForegroundColor Yellow
    if (-not $Force) {
        Write-Host "Use -Force to continue or run as Administrator." -ForegroundColor Red
        exit 1
    }
}

Write-Host "Receipt Path: $ReceiptPath" -ForegroundColor Cyan
Write-Host "Dry Run: $($DryRun.IsPresent)" -ForegroundColor Cyan
Write-Host "Administrator: $isAdmin" -ForegroundColor Cyan

# Simple hardening actions
$results = @{}

# 1. Script Block Logging
$regPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging'
$currentEnabled = $false
if (Test-Path $regPath) {
    $currentEnabled = (Get-ItemProperty -Path $regPath -Name 'EnableScriptBlockLogging' -ErrorAction SilentlyContinue).EnableScriptBlockLogging -eq 1
}

if ($currentEnabled) {
    $results.ScriptBlockLogging = "Already enabled"
    Write-Host "Script Block Logging: Already enabled" -ForegroundColor Green
} elseif ($DryRun) {
    $results.ScriptBlockLogging = "[DRY RUN] Would enable"
    Write-Host "Script Block Logging: [DRY RUN] Would enable" -ForegroundColor Yellow
} else {
    try {
        if (-not (Test-Path $regPath)) {
            New-Item -Path $regPath -Force | Out-Null
        }
        Set-ItemProperty -Path $regPath -Name 'EnableScriptBlockLogging' -Value 1
        $results.ScriptBlockLogging = "Enabled"
        Write-Host "Script Block Logging: Enabled" -ForegroundColor Green
    } catch {
        $results.ScriptBlockLogging = "Failed: $($_.Exception.Message)"
        Write-Host "Script Block Logging: Failed - $($_.Exception.Message)" -ForegroundColor Red
    }
}

# 2. Execution Policy
$currentPolicy = Get-ExecutionPolicy -Scope MachinePolicy -ErrorAction SilentlyContinue
$targetPolicy = 'RemoteSigned'

if ($currentPolicy -eq $targetPolicy) {
    $results.ExecutionPolicy = "Already set to $targetPolicy"
    Write-Host "Execution Policy: Already set to $targetPolicy" -ForegroundColor Green
} elseif ($DryRun) {
    $results.ExecutionPolicy = "[DRY RUN] Would set to $targetPolicy"
    Write-Host "Execution Policy: [DRY RUN] Would set to $targetPolicy (current: $currentPolicy)" -ForegroundColor Yellow
} else {
    try {
        Set-ExecutionPolicy -ExecutionPolicy $targetPolicy -Scope MachinePolicy -Force
        $results.ExecutionPolicy = "Set to $targetPolicy"
        Write-Host "Execution Policy: Set to $targetPolicy (was: $currentPolicy)" -ForegroundColor Green
    } catch {
        $results.ExecutionPolicy = "Failed: $($_.Exception.Message)"
        Write-Host "Execution Policy: Failed - $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Write receipt
if (Test-Path (Split-Path $ReceiptPath -Parent)) {
    try {
        $entry = @{
            timestamp = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffZ')
            script = 'harden-powershell-security.ps1'
            action = 'hardening-complete'
            mode = if ($DryRun) { 'dry-run' } else { 'live' }
            results = $results
        }
        $json = $entry | ConvertTo-Json -Compress
        Add-Content -Path $ReceiptPath -Value $json -Encoding UTF8
        Write-Host "Receipt written to: $ReceiptPath" -ForegroundColor Cyan
    } catch {
        Write-Host "Warning: Could not write receipt - $($_.Exception.Message)" -ForegroundColor Yellow
    }
} else {
    Write-Host "Warning: Receipt directory not found, skipping receipt." -ForegroundColor Yellow
}

Write-Host "`nPowerShell Security Hardening Complete!" -ForegroundColor Green
