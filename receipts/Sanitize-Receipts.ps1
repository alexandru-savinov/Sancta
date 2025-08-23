# Receipt Sanitization Script
# Creates sanitized versions of receipt files safe for sharing

param(
    [Parameter(Mandatory=$true)]
    [string]$InputPath,
    
    [string]$OutputPath,
    
    [switch]$RedactAll,
    
    [string[]]$RedactFields = @('hostname', 'user', 'path'),
    
    [string]$RedactValue = 'REDACTED'
)

if (-not $OutputPath) {
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($InputPath)
    $extension = [System.IO.Path]::GetExtension($InputPath)
    $directory = [System.IO.Path]::GetDirectoryName($InputPath)
    $OutputPath = Join-Path $directory "$baseName.sanitized$extension"
}

if (-not (Test-Path $InputPath)) {
    throw "Input file not found: $InputPath"
}

Write-Host "Sanitizing receipts from $InputPath to $OutputPath"

$receipts = Get-Content $InputPath | ForEach-Object {
    $receipt = $_ | ConvertFrom-Json
    
    # Redact specified fields
    foreach ($field in $RedactFields) {
        if ($receipt.PSObject.Properties.Name -contains $field) {
            $receipt.$field = $RedactValue
        }
    }
    
    # Handle nested validation object
    if ($receipt.validation -and $receipt.validation.PSObject.Properties.Name -contains 'hostname') {
        $receipt.validation.hostname = $RedactValue
    }
    
    # Optionally redact all potentially sensitive fields
    if ($RedactAll) {
        $sensitiveFields = @('notes', 'inputs', 'undo')
        foreach ($field in $sensitiveFields) {
            if ($receipt.PSObject.Properties.Name -contains $field) {
                if ($receipt.$field -is [string]) {
                    $receipt.$field = $RedactValue
                } elseif ($receipt.$field -is [hashtable] -or $receipt.$field.GetType().Name -eq 'PSCustomObject') {
                    $receipt.$field = @{redacted = $true}
                }
            }
        }
    }
    
    return $receipt
}

# Write sanitized receipts
$receipts | ForEach-Object { $_ | ConvertTo-Json -Compress } | Set-Content $OutputPath

Write-Host "Sanitized $(($receipts | Measure-Object).Count) receipts"
Write-Host "Output written to: $OutputPath"
Write-Host ""
Write-Host "Safe to commit with: git add '$OutputPath'"
