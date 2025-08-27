# Test Execution Policy Settings
# Run as Administrator to test different scopes

Write-Host "Testing Execution Policy Settings..." -ForegroundColor Cyan

# Check all scopes
$scopes = @('Process', 'CurrentUser', 'LocalMachine', 'UserPolicy', 'MachinePolicy')
foreach ($scope in $scopes) {
    $policy = Get-ExecutionPolicy -Scope $scope -ErrorAction SilentlyContinue
    Write-Host "  $scope : $policy" -ForegroundColor White
}

Write-Host "`nTrying to set ExecutionPolicy for different scopes..." -ForegroundColor Yellow

# Try CurrentUser first (doesn't require admin)
try {
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
    Write-Host "✅ CurrentUser scope: Set to RemoteSigned" -ForegroundColor Green
} catch {
    Write-Host "❌ CurrentUser scope failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Try LocalMachine (requires admin)
try {
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine -Force
    Write-Host "✅ LocalMachine scope: Set to RemoteSigned" -ForegroundColor Green
} catch {
    Write-Host "❌ LocalMachine scope failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Check results
Write-Host "`nFinal Execution Policy Status:" -ForegroundColor Cyan
foreach ($scope in $scopes) {
    $policy = Get-ExecutionPolicy -Scope $scope -ErrorAction SilentlyContinue
    $color = if ($policy -eq 'RemoteSigned') { 'Green' } else { 'White' }
    Write-Host "  $scope : $policy" -ForegroundColor $color
}

$effective = Get-ExecutionPolicy
Write-Host "`nEffective Policy: $effective" -ForegroundColor $(if ($effective -eq 'RemoteSigned') { 'Green' } else { 'Yellow' })

# Save receipt
$receipt = @{
    timestamp = Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffZ'
    action = 'execution-policy-test'
    effective_policy = $effective
    scopes = @{}
}
foreach ($scope in $scopes) {
    $receipt.scopes[$scope] = Get-ExecutionPolicy -Scope $scope -ErrorAction SilentlyContinue
}

$json = $receipt | ConvertTo-Json -Compress
Add-Content -Path "V:\Study\Reciepts\execution-policy-test.jsonl" -Value $json -Encoding UTF8
Write-Host "Results logged to: V:\Study\Reciepts\execution-policy-test.jsonl" -ForegroundColor Cyan
