# PowerShell Hardening with Elevated Visibility
# This version keeps the window open to show results
param(
    [string]$ReceiptPath = "V:\Study\Reciepts\powershell-hardening.elevated.jsonl",
    [switch]$DryRun,
    [switch]$Force
)

Write-Host "=== ELEVATED POWERSHELL HARDENING ===" -ForegroundColor Cyan
Write-Host "Receipt Path: $ReceiptPath" -ForegroundColor White
Write-Host "Dry Run: $($DryRun.IsPresent)" -ForegroundColor White
Write-Host "Administrator: $(([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))" -ForegroundColor White
Write-Host ""

# Run the main hardening script
& "$PSScriptRoot\harden-powershell-security.ps1" -ReceiptPath $ReceiptPath -DryRun:$DryRun -Force:$Force

Write-Host ""
Write-Host "=== FINAL VERIFICATION ===" -ForegroundColor Cyan

# Verify Script Block Logging
$regPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging'
if (Test-Path $regPath) {
    $enabled = (Get-ItemProperty -Path $regPath -Name 'EnableScriptBlockLogging' -ErrorAction SilentlyContinue).EnableScriptBlockLogging
    if ($enabled -eq 1) {
        Write-Host "✅ Script Block Logging: Registry confirmed enabled" -ForegroundColor Green
    } else {
        Write-Host "❌ Script Block Logging: Not enabled in registry" -ForegroundColor Red
    }
} else {
    Write-Host "❌ Script Block Logging: Registry path missing" -ForegroundColor Red
}

# Verify Execution Policy
$policy = Get-ExecutionPolicy -Scope LocalMachine
Write-Host "✅ Execution Policy (LocalMachine): $policy" -ForegroundColor $(if ($policy -eq 'RemoteSigned') { 'Green' } else { 'Yellow' })

Write-Host ""
Write-Host "Press any key to close this window..." -ForegroundColor Yellow
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
