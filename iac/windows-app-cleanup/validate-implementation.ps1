# Manual validation tests for Windows App Cleanup
# Run these manually to verify functionality

Write-Host "=== Manual Validation Tests for Windows App Cleanup ===" -ForegroundColor Cyan

# Test 1: Load functions without executing main script
Write-Host "`n1. Testing function loading..." -ForegroundColor Yellow
try {
    . "$PSScriptRoot\windows-app-cleanup.ps1"
    Write-Host "   ✓ Functions loaded successfully" -ForegroundColor Green
    
    # Verify key functions exist
    $requiredFunctions = @('Write-Receipt', 'Assert-Tool', 'Resolve-WingetId', 'Get-AppInventory', 'Uninstall-Winget')
    foreach ($func in $requiredFunctions) {
        if (Get-Command $func -ErrorAction SilentlyContinue) {
            Write-Host "   ✓ $func function available" -ForegroundColor Green
        } else {
            Write-Host "   ✗ $func function missing" -ForegroundColor Red
        }
    }
} catch {
    Write-Host "   ✗ Error loading functions: $_" -ForegroundColor Red
}

# Test 2: Configuration file
Write-Host "`n2. Testing configuration file..." -ForegroundColor Yellow
try {
    $config = Import-PowerShellDataFile "$PSScriptRoot\app-targets.psd1"
    Write-Host "   ✓ Configuration loaded: $($config.DefaultTargets.Count) default targets" -ForegroundColor Green
    Write-Host "   ✓ Critical apps: $($config.CriticalApps.Count)" -ForegroundColor Green
    Write-Host "   ✓ Canary targets: $($config.CanaryTargets.Count)" -ForegroundColor Green
} catch {
    Write-Host "   ✗ Error loading configuration: $_" -ForegroundColor Red
}

# Test 3: Receipts directory creation
Write-Host "`n3. Testing receipts functionality..." -ForegroundColor Yellow
try {
    $testReceiptsPath = Join-Path $env:TEMP "test-receipts-$(Get-Random).jsonl"
    $originalPath = $ReceiptsPath
    $global:ReceiptsPath = $testReceiptsPath
    
    Write-Receipt -Action 'test' -Inputs @{test='value'} -Result 'success'
    
    if (Test-Path $testReceiptsPath) {
        $content = Get-Content $testReceiptsPath | ConvertFrom-Json
        Write-Host "   ✓ Receipt written successfully" -ForegroundColor Green
        Write-Host "   ✓ Valid JSON structure" -ForegroundColor Green
        Remove-Item $testReceiptsPath -Force
    } else {
        Write-Host "   ✗ Receipt file not created" -ForegroundColor Red
    }
    
    $global:ReceiptsPath = $originalPath
} catch {
    Write-Host "   ✗ Error with receipts: $_" -ForegroundColor Red
}

# Test 4: Winget integration
Write-Host "`n4. Testing winget integration..." -ForegroundColor Yellow
try {
    $result = Invoke-Winget @("--version")
    if ($result.ExitCode -eq 0) {
        Write-Host "   ✓ Winget available and working" -ForegroundColor Green
    } else {
        Write-Host "   ✗ Winget not working properly" -ForegroundColor Red
    }
} catch {
    Write-Host "   ✗ Error testing winget: $_" -ForegroundColor Red
}

# Test 5: Package resolution
Write-Host "`n5. Testing package resolution..." -ForegroundColor Yellow
try {
    $invalidResult = Resolve-WingetId -Query 'definitely-invalid-package-12345'
    if ($invalidResult.Status -eq 'invalid-id') {
        Write-Host "   ✓ Invalid package handled correctly" -ForegroundColor Green
    } else {
        Write-Host "   ✗ Invalid package not handled correctly" -ForegroundColor Red
    }
} catch {
    Write-Host "   ✗ Error testing package resolution: $_" -ForegroundColor Red
}

# Test 6: Dry-run behavior
Write-Host "`n6. Testing dry-run behavior..." -ForegroundColor Yellow
try {
    $testReceiptsPath = Join-Path $env:TEMP "dry-run-test-$(Get-Random).jsonl"
    $global:ReceiptsPath = $testReceiptsPath
    $global:DryRun = $true
    
    $result = Uninstall-Winget -Id 'test-package'
    
    if ($result -eq 0 -and (Test-Path $testReceiptsPath)) {
        $content = Get-Content $testReceiptsPath | ConvertFrom-Json
        $dryRunReceipt = $content | Where-Object { $_.action -eq 'winget-uninstall' -and $_.dryRun -eq $true }
        if ($dryRunReceipt) {
            Write-Host "   ✓ Dry-run works correctly" -ForegroundColor Green
        } else {
            Write-Host "   ✗ Dry-run not recorded properly" -ForegroundColor Red
        }
        Remove-Item $testReceiptsPath -Force
    } else {
        Write-Host "   ✗ Dry-run test failed" -ForegroundColor Red
    }
    
    $global:DryRun = $false
} catch {
    Write-Host "   ✗ Error testing dry-run: $_" -ForegroundColor Red
}

# Test 7: Integration test
Write-Host "`n7. Testing full script with dry-run..." -ForegroundColor Yellow
try {
    $testReceiptsPath = Join-Path $env:TEMP "integration-test-$(Get-Random).jsonl"
    
    # Create the receipts directory
    $receiptsDir = Split-Path $testReceiptsPath -Parent
    if (-not (Test-Path $receiptsDir)) {
        New-Item -ItemType Directory -Path $receiptsDir -Force | Out-Null
    }
    
    # Run script with invalid package and capture any prompts
    $job = Start-Job -ScriptBlock {
        param($ScriptPath, $ReceiptsPath)
        & $ScriptPath -Targets 'invalid-test-package-12345' -DryRun -ReceiptsPath $ReceiptsPath
    } -ArgumentList "$PSScriptRoot\windows-app-cleanup.ps1", $testReceiptsPath
    
    # Wait for completion or timeout
    $job | Wait-Job -Timeout 30 | Out-Null
    $jobResult = Receive-Job $job
    Remove-Job $job -Force
    
    if (Test-Path $testReceiptsPath) {
        $receipts = Get-Content $testReceiptsPath | ConvertFrom-Json
        if ($receipts.Count -gt 0) {
            Write-Host "   ✓ Integration test completed with receipts" -ForegroundColor Green
        } else {
            Write-Host "   ✗ No receipts generated" -ForegroundColor Red
        }
        Remove-Item $testReceiptsPath -Force
    } else {
        Write-Host "   ⚠ Integration test completed but no receipts file (expected for invalid package)" -ForegroundColor Yellow
    }
} catch {
    Write-Host "   ✗ Error in integration test: $_" -ForegroundColor Red
}

Write-Host "`n=== Manual Validation Complete ===" -ForegroundColor Cyan
Write-Host "If most tests show ✓, the implementation is working correctly." -ForegroundColor White
