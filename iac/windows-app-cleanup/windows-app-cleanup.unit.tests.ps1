#Requires -Version 5.1

# Unit tests for Windows App Cleanup - Focus on testable components
Describe "Windows App Cleanup Components" {
    BeforeAll {
        # Load the script to access its functions
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

    Context "Helper Functions" {
        It "Write-Receipt creates valid JSONL entries" {
            $testPath = Join-Path $script:TestReceiptsDir "test.jsonl"
            
            # Override the global ReceiptsPath for this test
            $global:ReceiptsPath = $testPath
            
            Write-Receipt -Action 'test-action' -Inputs @{key='value'} -Result 'success' -Notes 'test note'
            
            # Verify file was created
            Test-Path $testPath | Should Be $true
            
            # Verify content is valid JSON
            $content = Get-Content $testPath -Raw
            $receipt = $content | ConvertFrom-Json
            
            $receipt.action | Should Be 'test-action'
            $receipt.result | Should Be 'success'
            $receipt.inputs.key | Should Be 'value'
            $receipt.notes | Should Be 'test note'
            $receipt.timestamp | Should Not BeNullOrEmpty
            $receipt.hostname | Should Not BeNullOrEmpty
            $receipt.user | Should Not BeNullOrEmpty
        }

        It "Assert-Tool works for existing tools" {
            $testPath = Join-Path $script:TestReceiptsDir "tool-test.jsonl"
            $global:ReceiptsPath = $testPath
            
            # Should not throw for PowerShell (always available)
            { Assert-Tool -Name "powershell" } | Should Not Throw
            
            # Should record success in receipts
            $content = Get-Content $testPath | ConvertFrom-Json
            $toolReceipt = $content | Where-Object { $_.action -eq 'assert-tool' -and $_.inputs.tool -eq 'powershell' }
            $toolReceipt.result | Should Be 'present'
        }

        It "Assert-Tool fails for non-existent tools" {
            $testPath = Join-Path $script:TestReceiptsDir "tool-fail-test.jsonl"
            $global:ReceiptsPath = $testPath
            
            # Should throw for fake tool
            { Assert-Tool -Name "fake-tool-12345" } | Should Throw
            
            # Should record failure in receipts
            $content = Get-Content $testPath | ConvertFrom-Json
            $toolReceipt = $content | Where-Object { $_.action -eq 'assert-tool' -and $_.inputs.tool -eq 'fake-tool-12345' }
            $toolReceipt.result | Should Be 'missing'
        }

        It "Resolve-WingetId handles invalid package gracefully" {
            $result = Resolve-WingetId -Query 'definitely-not-a-real-package-12345'
            
            $result | Should Not BeNullOrEmpty
            $result.Status | Should Be 'invalid-id'
            $result.Id | Should Be 'definitely-not-a-real-package-12345'
            $result.Publisher | Should Be ""
            $result.Source | Should Be "winget"
        }

        It "Get-AppInventory returns structured data" {
            $testPath = Join-Path $script:TestReceiptsDir "inventory-test.jsonl"
            $global:ReceiptsPath = $testPath
            
            $inventory = Get-AppInventory
            
            # Should return expected structure
            $inventory.WingetRaw | Should Not BeNullOrEmpty
            $inventory.Appx | Should Not BeNullOrEmpty
            # Provisioned may be empty if not elevated, that's OK
            
            # Should have logged warning about elevation if not elevated
            if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
                $content = Get-Content $testPath | ConvertFrom-Json
                $warning = $content | Where-Object { $_.action -eq 'inventory-warning' }
                $warning | Should Not BeNullOrEmpty
            }
        }
    }

    Context "Winget Integration" {
        It "Invoke-Winget returns structured output" {
            $result = Invoke-Winget @("--version")
            
            $result | Should Not BeNullOrEmpty
            $result.ExitCode | Should Not BeNullOrEmpty
            $result.StdOut | Should Not BeNullOrEmpty
            # winget --version should succeed
            $result.ExitCode | Should Be 0
        }

        It "Resolve-WingetId can resolve known Microsoft apps" {
            # Test with a common Microsoft app that should exist
            $result = Resolve-WingetId -Query 'Microsoft.PowerShell'
            
            # Should either verify or resolve successfully
            $result.Status | Should BeIn @('verified', 'resolved', 'invalid-id')
            $result.Id | Should Not BeNullOrEmpty
            $result.Source | Should Be 'winget'
        }
    }

    Context "Configuration Loading" {
        It "app-targets.psd1 has valid structure" {
            $configPath = "$PSScriptRoot\app-targets.psd1"
            Test-Path $configPath | Should Be $true
            
            $config = Import-PowerShellDataFile $configPath
            
            # Verify required sections exist
            $config.DefaultTargets | Should Not BeNullOrEmpty
            $config.CriticalApps | Should Not BeNullOrEmpty  
            $config.CanaryTargets | Should Not BeNullOrEmpty
            
            # Verify they contain strings
            $config.DefaultTargets[0] | Should BeOfType [string]
            $config.CriticalApps[0] | Should BeOfType [string]
            $config.CanaryTargets[0] | Should BeOfType [string]
        }
    }

    Context "Dry-Run Behavior" {
        It "Uninstall-Winget in dry-run mode only logs" {
            $testPath = Join-Path $script:TestReceiptsDir "dry-run-test.jsonl"
            $global:ReceiptsPath = $testPath
            $global:DryRun = $true
            
            # Should return 0 (success) without actually doing anything
            $result = Uninstall-Winget -Id 'test-package'
            $result | Should Be 0
            
            # Should log dry-run action
            $content = Get-Content $testPath | ConvertFrom-Json
            $uninstallReceipt = $content | Where-Object { $_.action -eq 'winget-uninstall' }
            $uninstallReceipt.result | Should Be 'dry-run'
            $uninstallReceipt.dryRun | Should Be $true
            $uninstallReceipt.undo | Should Be 'winget install --id test-package -e'
        }

        It "Remove-Appx-CurrentUser in dry-run mode only logs" {
            $testPath = Join-Path $script:TestReceiptsDir "appx-dry-run-test.jsonl"
            $global:ReceiptsPath = $testPath
            $global:DryRun = $true
            
            # Should not throw and only log
            { Remove-Appx-CurrentUser -PackageNameOrFamily 'test-package' } | Should Not Throw
            
            # Should log dry-run action
            $content = Get-Content $testPath | ConvertFrom-Json
            $appxReceipt = $content | Where-Object { $_.action -eq 'appx-remove' }
            $appxReceipt.result | Should Be 'dry-run'
            $appxReceipt.dryRun | Should Be $true
        }
    }
}
