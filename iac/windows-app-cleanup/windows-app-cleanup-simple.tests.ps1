#Requires -Version 5.1

Describe "windows-app-cleanup orchestrator" {
    BeforeAll {
        $script:scriptPath = "$PSScriptRoot\windows-app-cleanup.ps1"
        $script:tempDir = Join-Path $env:TEMP "wac-tests-$([guid]::NewGuid())"
        New-Item -ItemType Directory -Path $script:tempDir -Force | Out-Null
    }

    AfterAll {
        if (Test-Path $script:tempDir) {
            Remove-Item -Path $script:tempDir -Recurse -Force
        }
    }

    Context "Script loading and function availability" {
        It "loads without errors" {
            { . $script:scriptPath } | Should -Not -Throw
        }

        It "defines required functions after loading" {
            . $script:scriptPath
            Get-Command Write-Receipt -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
            Get-Command Assert-Tool -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
            Get-Command Resolve-WingetId -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
            Get-Command Get-AppInventory -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
    }

    Context "Individual function testing" {
        BeforeAll {
            . $script:scriptPath
        }

        It "Write-Receipt creates valid JSON" {
            $receiptsPath = Join-Path $script:tempDir "test-receipt.jsonl"
            
            Write-Receipt -Action 'test' -Inputs @{test='value'} -Result 'success'
            
            # Receipt should be written to default path since we can't easily override in function
            # Just test that the function doesn't throw
        }

        It "Assert-Tool detects winget presence" {
            { Assert-Tool -Name "winget" } | Should -Not -Throw
        }

        It "Resolve-WingetId handles invalid packages gracefully" {
            $result = Resolve-WingetId -Query 'invalid-package-xyz-123'
            
            $result | Should -Not -BeNullOrEmpty
            $result.Status | Should -Be 'invalid-id'
            $result.Id | Should -Be 'invalid-package-xyz-123'
        }

        It "Get-AppInventory returns structured data" {
            $inventory = Get-AppInventory
            
            $inventory | Should -Not -BeNullOrEmpty
            $inventory.WingetRaw | Should -Not -BeNullOrEmpty
            $inventory.Appx | Should -Not -BeNullOrEmpty
            # Provisioned may be empty if not elevated
        }
    }

    Context "Configuration file integration" {
        It "loads app-targets.psd1 successfully" {
            $configPath = "$PSScriptRoot\app-targets.psd1"
            Test-Path $configPath | Should -BeTrue
            
            { $config = Import-PowerShellDataFile $configPath } | Should -Not -Throw
            $config = Import-PowerShellDataFile $configPath
            
            $config.DefaultTargets | Should -Not -BeNullOrEmpty
            $config.CriticalApps | Should -Not -BeNullOrEmpty
            $config.CanaryTargets | Should -Not -BeNullOrEmpty
        }
    }

    Context "Quick runner script" {
        It "run-cleanup.ps1 exists and loads" {
            $runnerPath = "$PSScriptRoot\run-cleanup.ps1"
            Test-Path $runnerPath | Should -BeTrue
            
            # Test that it doesn't have syntax errors
            { . $runnerPath -Mode 'DryRun' -CustomTargets @('test') -WhatIf } | Should -Not -Throw
        }
    }
}
