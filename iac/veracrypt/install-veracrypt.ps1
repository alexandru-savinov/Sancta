<#
install-veracrypt.ps1

Idempotent PowerShell IaC template for VeraCrypt (winget first, MSI fallback), canary test, production vault create, mount/test, secure auto-mount guidance, receipts and undo.

Usage:
  - Run interactively as the current user.
  - Edit variables in the PARAMETERS section if desired.
  - The script respects human gates and will prompt before destructive operations.

Security:
  - Never store the password in plaintext. Use SecretManagement/SecretStore or an enterprise vault.
#>

### PARAMETERS (edit as needed)
$VaultSize   = '20G'                     # production vault size (e.g., '20G')
$CanarySize  = '20M'                     # canary size for validation
$VaultDir    = Join-Path $env:USERPROFILE 'LocalVault'
$VaultName   = 'study-nb-prd-01-vault.hc'
$VaultPath   = Join-Path $VaultDir $VaultName
$DriveLetter = 'V'
$Label       = 'Local Vault'
$BackupDir   = 'D:\Sancta\Vaults\Backups'
$VeraCryptDir= 'C:\Program Files\VeraCrypt'
$ReceiptFile = Join-Path $VaultDir 'veracrypt-receipts.log'

function Write-Receipt {
    param($action, $inputs, $result, $path, $elevated, $undo)
    $entry = @{ ts = (Get-Date).ToString('o'); action = $action; inputs = $inputs; result = $result; path = $path; elevated = $elevated; undo = $undo }
    $json = $entry | ConvertTo-Json -Compress
    Add-Content -Path $ReceiptFile -Value $json
    Write-Host $json
}

### Helper: Ensure directories
New-Item -Path $VaultDir -ItemType Directory -Force | Out-Null
New-Item -Path $BackupDir -ItemType Directory -Force | Out-Null

### 1) Install VeraCrypt (winget preferred, MSI fallback)
function Install-VeraCrypt {
    $wingetId = 'IDRIX.VeraCrypt'
    $attempt = 0
    while ($attempt -lt 2) {
        $attempt++
        Write-Host "Attempting winget install (attempt $attempt)..."
        $proc = Start-Process -FilePath 'winget' -ArgumentList 'install','--id',$wingetId,'-e','--accept-package-agreements','--accept-source-agreements' -NoNewWindow -Wait -PassThru -ErrorAction SilentlyContinue
        if ($proc -and $proc.ExitCode -eq 0) { Write-Host 'winget install succeeded.'; return }
        Write-Host 'winget install failed or returned non-zero.'
        Start-Sleep -Seconds 2
    }
    Write-Host 'Falling back to official installer (interactive/elevated).'
    $msiUrl = 'https://launchpad.net/veracrypt/trunk/1.26.24/+download/VeraCrypt_1.26.24_Setup_x64.exe'
    $msiLocal = Join-Path $env:TEMP 'veracrypt-setup.exe'
    Write-Host "Downloading installer to $msiLocal..."
    Invoke-WebRequest -Uri $msiUrl -OutFile $msiLocal -UseBasicParsing
    # TODO: replace 'expectedSha256' with pinned hash from Principles doc
    $expectedSha256 = ''
    if ($expectedSha256) {
        $actual = (Get-FileHash -Path $msiLocal -Algorithm SHA256).Hash
        if ($actual -ne $expectedSha256) { throw "Installer SHA256 mismatch: expected $expectedSha256, got $actual" }
    }
    Write-Host 'Launching installer; elevation will be requested.'
    Start-Process -FilePath $msiLocal -ArgumentList '/S' -Verb RunAs -Wait
}

if (-not (Test-Path (Join-Path $VeraCryptDir 'VeraCrypt.exe'))) {
    Install-VeraCrypt
    Start-Sleep -Seconds 2
}

if (-not (Test-Path (Join-Path $VeraCryptDir 'VeraCrypt.exe'))) {
    Write-Host 'ERROR: VeraCrypt CLI not found after attempted install. Aborting.' -ForegroundColor Red
    Write-Receipt -action 'install-veracrypt' -inputs @{method='winget-or-msi'} -result 'failed' -path $VeraCryptDir -elevated $false -undo 'manual-uninstall-or-check'
    exit 1
}

Write-Receipt -action 'install-veracrypt' -inputs @{method='verified'} -result 'success' -path $VeraCryptDir -elevated $false -undo 'winget uninstall --id IDRIX.VeraCrypt -e'

### 2) Canary create + mount (validate CLI)
$canary = Join-Path $env:TEMP 'sancta-canary.hc'
Write-Host "Creating canary volume at $canary ($CanarySize)"
function Get-PlainPasswordFromSecretOrPrompt($prompt) {
    # Prefer SecretManagement if available; otherwise prompt securely
    if (Get-Command -Name Get-Secret -ErrorAction SilentlyContinue) {
        try { $sec = Get-Secret -Name 'LocalVaultPassword' -ErrorAction Stop; return $sec.GetNetworkCredential().Password } catch { }
    }
    $s = Read-Host -AsSecureString $prompt
    return [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($s))
}

$canaryPw = Get-PlainPasswordFromSecretOrPrompt 'Enter temporary canary password (hidden)'
& "${VeraCryptDir}\VeraCrypt Format.exe" /create $canary /password "$canaryPw" /filesystem NTFS /size $CanarySize /encryption AES /hash SHA-512 /quick /silent
if (!(Test-Path $canary)) { Write-Receipt -action 'create-canary' -inputs @{size=$CanarySize} -result 'failed' -path $canary -elevated $false -undo 'none'; throw 'Canary creation failed' }

& "${VeraCryptDir}\VeraCrypt.exe" /volume $canary /letter T /password "$canaryPw" /quit
Start-Sleep -Seconds 2
if (Test-Path 'T:\') {
    "$env:USERNAME canary test $(Get-Date)" | Out-File 'T:\sancta-canary.txt' -Encoding utf8
    $content = Get-Content 'T:\sancta-canary.txt' -ErrorAction SilentlyContinue
    Write-Receipt -action 'canary-mount-test' -inputs @{path=$canary} -result 'success' -path 'T:\sancta-canary.txt' -elevated $false -undo "VeraCrypt.exe /dismount T"
    & "${VeraCryptDir}\VeraCrypt.exe" /dismount T /quit
    Remove-Item $canary -Force
} else {
    Write-Receipt -action 'canary-mount-test' -inputs @{path=$canary} -result 'mount-failed' -path '' -elevated $false -undo 'remove-canary-file'
    Remove-Item $canary -Force
    throw 'Canary mount failed'
}

### 3) Production vault create (human gate)
Write-Host "Production vault will be created at: $VaultPath (size: $VaultSize)"
$confirm = Read-Host "Type 'YES' to create production vault"
if ($confirm -ne 'YES') { Write-Host 'Aborted by user.'; exit 0 }

$prodPw = Get-PlainPasswordFromSecretOrPrompt 'Enter production vault password (hidden)'
& "${VeraCryptDir}\VeraCrypt Format.exe" /create $VaultPath /password "$prodPw" /filesystem NTFS /size $VaultSize /encryption AES /hash SHA-512 /quick /silent
if (Test-Path $VaultPath) {
    $sizeBytes = (Get-Item $VaultPath).Length
    Write-Receipt -action 'create-vault' -inputs @{size=$VaultSize} -result 'success' -path $VaultPath -elevated $false -undo "Remove-Item '$VaultPath' -Force"
} else { Write-Receipt -action 'create-vault' -inputs @{size=$VaultSize} -result 'failed' -path $VaultPath -elevated $false -undo 'none'; throw 'Vault creation failed' }

### 4) Mount production vault and perform R/W test
& "${VeraCryptDir}\VeraCrypt.exe" /volume $VaultPath /letter $DriveLetter /password "$prodPw" /quit
Start-Sleep -Seconds 2
if (Test-Path "$DriveLetter`:\") {
    "$env:USERNAME vault test $(Get-Date)" | Out-File "$DriveLetter`:\sancta-vault-test.txt" -Encoding utf8
    $read = Get-Content "$DriveLetter`:\sancta-vault-test.txt"
    Write-Receipt -action 'mount-and-test' -inputs @{drive=$DriveLetter} -result 'success' -path "$DriveLetter`:\sancta-vault-test.txt" -elevated $false -undo "${VeraCryptDir}\VeraCrypt.exe /dismount $DriveLetter"
} else {
    Write-Receipt -action 'mount-and-test' -inputs @{drive=$DriveLetter} -result 'failed' -path '' -elevated $false -undo "${VeraCryptDir}\VeraCrypt.exe /dismount $DriveLetter"
    throw 'Mount failed'
}

### 5) Auto-mount recommendation (IaC pattern)
Write-Host "Auto-mount (IaC recommended): create a per-user scheduled task that reads the password from SecretStore and mounts the vault at logon. This requires user opt-in."
Write-Host "Example command (manual step):"
Write-Host "  - Create a scheduled task to run at logon that executes a small PowerShell one-liner which retrieves the secret and runs VeraCrypt.exe /volume '<path>' /letter <L> /password '<password>' /quit"
Write-Host "Manual Favorites fallback: In VeraCrypt UI, Favorites → Add Mounted Volume to Favorites → check 'Mount at logon'."
Write-Receipt -action 'autmount-recommendation' -inputs @{method='scheduled-task-or-favorites'} -result 'presented' -path '' -elevated $false -undo 'remove-scheduled-task-or-favorite'

### 6) Indexing & Defender guidance (manual)
Write-Host "Indexing: open Settings → Advanced indexing options → Modify and uncheck $VaultDir"
Write-Host "Defender CFA: Windows Security → Ransomware protection → Controlled folder access → Protected folders → Add $VaultDir"
Write-Receipt -action 'indexing-defender-guidance' -inputs @{indexPath=$VaultDir; defenderPath=$VaultDir} -result 'presented' -path '' -elevated $false -undo 'manual'

### 7) Header backup guidance (manual)
Write-Host "Create an external header backup using VeraCrypt UI: Tools → Backup Volume Header → select volume: $VaultPath → save to: $BackupDir"
Write-Receipt -action 'header-backup-guidance' -inputs @{backupDir=$BackupDir} -result 'presented' -path $BackupDir -elevated $false -undo 'delete-backup-file'

### Final summary
Write-Host "Setup complete. Receipts written to: $ReceiptFile"
Get-Content $ReceiptFile | Write-Host
