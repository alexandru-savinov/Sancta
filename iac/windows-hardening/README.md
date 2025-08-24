# Windows Security Audit & Hardening

A comprehensive security assessment and hardening solution for Windows, aligned with Sancta principles (human primacy, least privilege, receipts, reversibility).

## Components

### 1. Security Audit (audit-windows-security.ps1)
- **Read-only assessment** - No changes made to system
- **Comprehensive coverage** - 9 security domains analyzed
- **JSONL receipts** - Full transparency and auditability

### 2. Security Hardening (harden-windows-security.ps1) 
- **Idempotent operations** - Safe to run multiple times
- **Interactive confirmation** - Human consent for all changes
- **Administrator privileges** - Required for security modifications
- **Comprehensive logging** - All actions recorded with undo commands

## Principles
- Human primacy and explicit consent for any change (this module is audit-only)
- Least privilege (no elevation required for audit)
- Transparency (console summary + JSON receipts)
- Reversibility (changes, when implemented, must have clear undo)
- Idempotent by design:
	- Re-running audits produces the same system state (no side effects)
	- Future "apply" scripts must check state first and only change when drift is detected
	- Safe to interrupt and re-run; operations are convergent to desired state

## Security Coverage

### Windows Defender Protection
- ✅ Real-time Protection (active malware scanning)
- ✅ Cloud Protection (latest threat intelligence)
- ✅ PUA Protection (potentially unwanted apps)
- ✅ **Network Protection** (web-based threat blocking) - *Hardening enables*
- ✅ Controlled Folder Access (ransomware protection)
- ✅ **Attack Surface Reduction Rules** - *Hardening configures 5 essential rules*

### System Security Controls
- ✅ **LSA Protection** (credential dumping prevention) - *Hardening enables*
- ✅ Windows Firewall (Domain, Private, Public profiles)
- ✅ Remote Desktop status (should be disabled)
- ✅ SMB1 Protocol status (should be disabled)
- ✅ Credential Guard configuration
- ✅ Secure Boot and TPM availability
- ✅ BitLocker encryption status
- ✅ SmartScreen configuration
- ✅ AutoRun/AutoPlay policies
## Hardening Results Summary

### ✅ Successfully Hardened (Already Optimal)
Based on the latest hardening session (2025-08-24), this system achieved **EXCELLENT** security status:

**Windows Defender - Enterprise Grade:**
- Network Protection: ✅ ENABLED (blocks web threats)
- Real-time Protection: ✅ ENABLED
- Cloud Protection: ✅ ENABLED  
- PUA Protection: ✅ ENABLED
- Controlled Folder Access: ✅ ENABLED
- ASR Rules: ✅ CONFIGURED (5 essential rules active)

**System Security - Hardened:**
- LSA Protection: ✅ ENABLED (prevents credential dumping)
- Firewall: ✅ Domain + Public profiles ENABLED
- RDP: ✅ DISABLED (secure)

**Outcome:** Enterprise-grade security with all major protections enabled.

## Receipt Files Generated
- `receipts/windows-hardening.audit.jsonl` - Audit session logs
- `receipts/windows-hardening.jsonl` - Hardening session logs  
- `receipts/latest-audit-results.json` - Latest complete audit snapshot

## Run (PowerShell, no elevation required)
- One-time, read-only audit:

```powershell
# From repository root
powershell -ExecutionPolicy Bypass -File "iac\windows-hardening\audit-windows-security.ps1"

# Accessibility and personalization switches
# -Quiet       : minimal console output
# -JsonOnly    : suppress console, write JSON only
# -NoColor     : disable color (redundant status words remain)
# -HighContrast: high-contrast color palette
# -Wide        : include detailed per-profile firewall table
powershell -ExecutionPolicy Bypass -File "iac\windows-hardening\audit-windows-security.ps1" -Quiet -NoColor
```

## Hardening (applies security improvements)
```powershell
# Dry run first (recommended) - shows what would change
powershell -ExecutionPolicy Bypass -File "iac\windows-hardening\harden-windows-security.ps1" -DryRun

# Interactive hardening (prompts for confirmation)
powershell -ExecutionPolicy Bypass -File "iac\windows-hardening\harden-windows-security.ps1"

# Force hardening without prompts (automation)
powershell -ExecutionPolicy Bypass -File "iac\windows-hardening\harden-windows-security.ps1" -Force

# Available switches: -DryRun, -Quiet, -JsonOnly, -Force, -NoColor, -HighContrast
```

## Notes
- Some checks may be unavailable on certain editions. The script handles missing modules/features gracefully.
- Enabling features (e.g., CFA, ASR, WDAC/AppLocker) requires separate, human-gated scripts. This module only audits.
- BitLocker/OS encryption changes are out of scope (see VeraCrypt guidance for file-backed vaults).

## Idempotence Contract (for future apply scripts)
- Pattern per control: Get → Test → Plan → Confirm → Set → Verify → Receipt (+ undo)
- Only perform Set when Test indicates drift from the desired state
- Record previous state to support precise undo when feasible
- Emit receipts for every action with: ts, action, inputs, result, path, elevated, undo, notes, hostname, user
- Dry-run mode must show the exact plan without changing state

Example targets (apply scripts to follow):
- Disable RDP if enabled; no-op if already disabled
- Disable SMB1 if present; no-op if already removed
- Enable Defender Network Protection/PUA if off; no-op if already on