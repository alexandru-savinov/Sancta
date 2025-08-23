#Requires -Version 5.1

# Unit tests for Windows App Cleanup components
# These tests validate individual functions without executing the full script

Describe "Windows App Cleanup Unit Tests" {
    BeforeAll {
        # Load functions without executing main script
        . "$PSScriptRoot\windows-app-cleanup.ps1"
        
        # Create temp directory for test receipts
        $script:TestReceiptsDir = Join-Path $env:TEMP "sancta-test-receipts"
        if (Test-Path $script:TestReceiptsDir) {
            Remove-Item $script:TestReceiptsDir -Recurse -Force
        }
        New-Item -ItemType Directory -Path $script:TestReceiptsDir -Force | Out-Null
    }
    
    AfterAll {
        if (Test-Path $script:TestReceiptsDir) {
            Remove-Item $script:TestReceiptsDir -Recurse -Force
        }
    }

    Context "Core Functions" {
        It "Write-Receipt creates valid JSONL entries" {
            $testPath = Join-Path $script:TestReceiptsDir "test.jsonl"
            $global:ReceiptsPath = $testPath
            
            Write-Receipt -Action 'test-action' -Inputs @{key='value'} -Result 'success' -Notes 'test note'
            
            Test-Path $testPath | Should Be $true
            $receipt = Get-Content $testPath | ConvertFrom-Json
            
            $receipt.action | Should Be 'test-action'
            $receipt.result | Should Be 'success'
            $receipt.inputs.key | Should Be 'value'
            $receipt.notes | Should Be 'test note'
            $receipt.timestamp | Should Not BeNullOrEmpty
        }

        It "Resolve-WingetId handles invalid packages gracefully" {
            $result = Resolve-WingetId -Query 'definitely-not-a-real-package-12345'
            
            $result.Status | Should Be 'invalid-id'
            $result.Id | Should Be 'definitely-not-a-real-package-12345'
            $result.Source | Should Be 'winget'
        }

        It "Get-AppInventory returns structured data" {
            $inventory = Get-AppInventory
            
            $inventory.WingetRaw | Should Not BeNullOrEmpty
            $inventory.Appx | Should Not BeNullOrEmpty
            # Provisioned may be empty if not elevated
        }
    }

    Context "Configuration" {
        It "app-targets.psd1 loads correctly" {
            $configPath = "$PSScriptRoot\app-targets.psd1"
            Test-Path $configPath | Should Be $true
            
            $config = Import-PowerShellDataFile $configPath
            $config.DefaultTargets | Should Not BeNullOrEmpty
            $config.CriticalApps | Should Not BeNullOrEmpty  
            $config.CanaryTargets | Should Not BeNullOrEmpty
        }
    }

    Context "Dry-Run Safety" {
        It "Dry-run mode prevents actual uninstalls" {
            $testPath = Join-Path $script:TestReceiptsDir "dry-run-test.jsonl"
            $global:ReceiptsPath = $testPath
            $global:DryRun = $true
            
            $result = Uninstall-Winget -Id 'test-package'
            
            $result | Should Be 0
            $receipt = Get-Content $testPath | ConvertFrom-Json
            $receipt.result | Should Be 'dry-run'
            $receipt.dryRun | Should Be $true
            $receipt.undo | Should Be 'winget install --id test-package -e'
        }
    }
}

    Context "Dry-run functionality" {
        It "writes receipts in dry-run" {
            $receiptsPath = Join-Path $script:tempDir "receipts-$([guid]::NewGuid()).jsonl"
            
            # Run the script in dry-run mode with a common Microsoft app
            & $script:scriptPath -Targets 'Microsoft.OneDrive' -DryRun -ReceiptsPath $receiptsPath
            
            # Verify receipts file was created
            Test-Path $receiptsPath | Should -BeTrue
            
            # Verify receipts contain dry-run entries
            $lines = Get-Content $receiptsPath
            $receipts = $lines | ConvertFrom-Json
            ($receipts | Where-Object { $_.dryRun -eq $true }).Count | Should -BeGreaterThan 0
        }

        It "does not perform actual uninstalls in dry-run" {
            $receiptsPath = Join-Path $script:tempDir "receipts-$([guid]::NewGuid()).jsonl"
            
            & $script:scriptPath -Targets 'Microsoft.OneDrive' -DryRun -ReceiptsPath $receiptsPath
            
            $lines = Get-Content $receiptsPath
            $receipts = $lines | ConvertFrom-Json
            
            # Check that any uninstall actions are marked as dry-run
            $uninstallReceipts = $receipts | Where-Object { $_.action -eq 'winget-uninstall' }
            if ($uninstallReceipts) {
                $uninstallReceipts | ForEach-Object { $_.result | Should -Be 'dry-run' }
            }
        }
    }

    Context "Target validation" {
        It "validates target IDs and records validation" {
            $receiptsPath = Join-Path $script:tempDir "receipts-$([guid]::NewGuid()).jsonl"
            
            # Test with both valid and invalid package names
            & $script:scriptPath -Targets 'not-a-real-package-12345','Microsoft.OneDrive' -DryRun -ReceiptsPath $receiptsPath
            
            $lines = Get-Content $receiptsPath
            $receipts = $lines | ConvertFrom-Json
            
            # Verify validation actions were recorded
            $validationReceipts = $receipts | Where-Object { $_.action -eq 'validate-target' }
            $validationReceipts.Count | Should -BeGreaterThan 0
            
            # Check that validation includes status and timestamp
            $validationReceipts | ForEach-Object { 
                $_.validation | Should -Not -BeNullOrEmpty
                $_.validation.status | Should -Not -BeNullOrEmpty
                $_.validation.checkedAt | Should -Not -BeNullOrEmpty
            }
        }

        It "handles invalid package IDs gracefully" {
            $receiptsPath = Join-Path $script:tempDir "receipts-$([guid]::NewGuid()).jsonl"
            
            & $script:scriptPath -Targets 'invalid-package-xyz-123' -DryRun -ReceiptsPath $receiptsPath
            
            $lines = Get-Content $receiptsPath
            $receipts = $lines | ConvertFrom-Json
            
            $validationReceipts = $receipts | Where-Object { $_.action -eq 'validate-target' }
            $invalidValidation = $validationReceipts | Where-Object { $_.validation.status -eq 'invalid-id' }
            $invalidValidation.Count | Should -BeGreaterThan 0
        }
    }

    Context "Tool validation" {
        It "checks for required tools" {
            $receiptsPath = Join-Path $script:tempDir "receipts-$([guid]::NewGuid()).jsonl"
            
            & $script:scriptPath -Targets 'Microsoft.OneDrive' -DryRun -ReceiptsPath $receiptsPath
            
            $lines = Get-Content $receiptsPath
            $receipts = $lines | ConvertFrom-Json
            
            # Should have tool assertion for winget
            $toolReceipts = $receipts | Where-Object { $_.action -eq 'assert-tool' }
            $wingetCheck = $toolReceipts | Where-Object { $_.inputs.tool -eq 'winget' }
            $wingetCheck | Should -Not -BeNullOrEmpty
        }
    }

    Context "Receipt structure" {
        It "writes well-formed JSON receipts" {
            $receiptsPath = Join-Path $script:tempDir "receipts-$([guid]::NewGuid()).jsonl"
            
            & $script:scriptPath -Targets 'Microsoft.OneDrive' -DryRun -ReceiptsPath $receiptsPath
            
            $lines = Get-Content $receiptsPath
            
            # Each line should be valid JSON
            $lines | ForEach-Object {
                { $_ | ConvertFrom-Json } | Should -Not -Throw
            }
            
            # Verify required fields are present
            $receipts = $lines | ConvertFrom-Json
            $receipts | ForEach-Object {
                $_.timestamp | Should -Not -BeNullOrEmpty
                $_.action | Should -Not -BeNullOrEmpty
                $_.result | Should -Not -BeNullOrEmpty
                $_.dryRun | Should -BeOfType [bool]
                $_.hostname | Should -Not -BeNullOrEmpty
                $_.user | Should -Not -BeNullOrEmpty
            }
        }
    }

    Context "Inventory functionality" {
        It "records before and after inventory" {
            $receiptsPath = Join-Path $script:tempDir "receipts-$([guid]::NewGuid()).jsonl"
            
            & $script:scriptPath -Targets 'Microsoft.OneDrive' -DryRun -ReceiptsPath $receiptsPath
            
            $lines = Get-Content $receiptsPath
            $receipts = $lines | ConvertFrom-Json
            
            # Should have before inventory
            $beforeInventory = $receipts | Where-Object { $_.action -eq 'inventory' -and $_.inputs.phase -eq 'before' }
            $beforeInventory | Should -Not -BeNullOrEmpty
            
            # Should have after inventory
            $afterInventory = $receipts | Where-Object { $_.action -eq 'inventory' -and $_.inputs.phase -eq 'after' }
            $afterInventory | Should -Not -BeNullOrEmpty
        }
    }
}
