# Simple test script to verify PowerShell execution
param(
    [string]$ReceiptPath = "V:\Study\Reciepts\powershell-hardening.jsonl",
    [switch]$DryRun
)

Write-Host "Testing PowerShell script execution..." -ForegroundColor Green
Write-Host "ReceiptPath: $ReceiptPath"
Write-Host "DryRun: $($DryRun.IsPresent)"

if ($MyInvocation.InvocationName -ne '.') {
    Write-Host "Script executed directly" -ForegroundColor Yellow
}
