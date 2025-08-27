# PowerShell Security Hardening

A comprehensive PowerShell security assessment and hardening solution for Windows, aligned with Sancta principles (human primacy, least privilege, receipts, reversibility).

## Overview

PowerShell is a powerful administrative tool that can be exploited by attackers for "living-off-the-land" attacks. This module provides security hardening specifically for PowerShell execution environments while preserving the functionality needed for Sancta infrastructure scripts.

## Components

### 1. PowerShell Security Audit (audit-powershell-security.ps1)
- **Read-only assessment** - No changes made to system
- **Comprehensive coverage** - 7 PowerShell security domains analyzed
- **JSONL receipts** - Full transparency and auditability

### 2. PowerShell Security Hardening (harden-powershell-security.ps1) 
- **Idempotent operations** - Safe to run multiple times
- **Interactive confirmation** - Human consent for all changes
- **Sancta-compatible** - Preserves functionality for existing scripts
- **Comprehensive logging** - All actions recorded with undo commands

## Principles
- Human primacy and explicit consent for any change
- Least privilege (minimal elevation required)
- Transparency (console summary + JSON receipts)
- Reversibility (changes include clear undo commands)
- Compatibility (preserves Sancta script functionality)

## Security Coverage

### PowerShell Logging & Monitoring
- ✅ **Script Block Logging** - Records PowerShell script execution
- ✅ **Module Logging** - Tracks PowerShell module usage
- ✅ **Transcription Logging** - Creates session transcripts
- ✅ **Event Log Configuration** - Ensures proper log retention

### Execution Environment Security
- ✅ **Execution Policy Assessment** - All scopes (Process, CurrentUser, LocalMachine)
- ✅ **AMSI (Anti-Malware Scan Interface)** - Validates malware scanning integration
- ✅ **Constrained Language Mode** - Assesses PowerShell language restrictions
- ✅ **JEA (Just Enough Administration)** - Readiness for role-based access

### Code Integrity & Trust
- ✅ **Script Signing Configuration** - Digital signature requirements
- ✅ **Trusted Publishers** - Certificate authority validation
- ✅ **PowerShell Profiles** - Security assessment of profile scripts

## Quick Start

### 1. Security Audit (No elevation required)
```powershell
# Navigate to Sancta directory
cd "c:\Users\User\Documents\Sancta"

# Run PowerShell security audit (read-only)
powershell -ExecutionPolicy Bypass -File "iac\powershell-hardening\audit-powershell-security.ps1"

# Accessibility options
powershell -ExecutionPolicy Bypass -File "iac\powershell-hardening\audit-powershell-security.ps1" -Quiet -NoColor
```

### 2. Security Hardening (Requires elevation)
```powershell
# Dry run hardening to preview changes (recommended first)
powershell -ExecutionPolicy Bypass -File "iac\powershell-hardening\harden-powershell-security.ps1" -DryRun

# Interactive hardening with privacy consent ceremony
powershell -ExecutionPolicy Bypass -File "iac\powershell-hardening\harden-powershell-security.ps1"

# Force hardening without prompts (automation - use with caution)
powershell -ExecutionPolicy Bypass -File "iac\powershell-hardening\harden-powershell-security.ps1" -Force

# Available switches: -DryRun, -Quiet, -JsonOnly, -Force, -NoColor, -HighContrast
```powershell
# From Sancta repository root
powershell -ExecutionPolicy Bypass -File "iac\powershell-hardening\audit-powershell-security.ps1"

# Accessibility options available
powershell -ExecutionPolicy Bypass -File "iac\powershell-hardening\audit-powershell-security.ps1" -Quiet -NoColor
```

### 2. Security Hardening (May require elevation)
```powershell
# Dry run first (recommended)
powershell -ExecutionPolicy Bypass -File "iac\powershell-hardening\harden-powershell-security.ps1" -DryRun

# Interactive hardening (prompts for confirmation)
powershell -ExecutionPolicy Bypass -File "iac\powershell-hardening\harden-powershell-security.ps1"

# Available switches: -DryRun, -Quiet, -JsonOnly, -Force, -NoColor, -HighContrast
```

## Sancta Compliance & Privacy

### Privacy Impact Assessment
**PowerShell logging changes may affect privacy:**
- **Script Block Logging**: Records all PowerShell script execution in Windows Event Log
- **Module Logging**: Tracks usage of specified PowerShell modules  
- **Event Logs**: Stored locally, accessible to administrators

### Consent Ceremony Implementation
Following Sancta Charter "Consent is Ceremony" principle:
- **Clear Privacy Notice**: Explains what data will be logged
- **Interactive Confirmation**: Requires explicit 'yes' to proceed
- **Privacy Details**: Available via 'privacy' command during confirmation
- **Complete Undo**: All changes include documented rollback procedures

### Human Gates & Safeguards
- **Administrator Elevation**: Required for registry modifications
- **Dry-Run Mode**: Preview all changes before execution
- **Force Flag Warning**: Bypasses consent ceremony (use cautiously)
- **Full Reversibility**: Every action includes undo commands

### Sancta Charter Compliance ✅
- ✅ **Human Primacy**: Interactive confirmation, no forced automation
- ✅ **Consent is Ceremony**: Clear privacy notice and explicit agreement
- ✅ **Reversibility**: Complete undo commands for all changes
- ✅ **Transparency**: Human-readable receipts and clear explanations
- ✅ **Proportionality**: Conservative security measures for actual threats

### IaC Pledge Compliance ✅
- ✅ **Rollback Required**: All changes documented with undo procedures
- ✅ **No Click-ops Drift**: PowerShell security via code, not manual configuration
- ✅ **Access Expires**: No persistent elevated access, session-based only
- ✅ **Minimal Tracking**: Only security-relevant data, no behavioral profiling

## Receipt Files Generated
- `receipts/powershell-hardening.audit.jsonl` - Audit session logs
- `receipts/powershell-hardening.jsonl` - Hardening session logs  

### Receipt Location Behavior
- **Primary location:** `c:\Users\User\Documents\Sancta\receipts\`
- **Human gate:** If receipt folder missing, user is prompted to continue with temp storage
- **Fallback location:** `%TEMP%\` (e.g., `C:\Users\[Username]\AppData\Local\Temp\`)
- **Full transparency:** Exact fallback path shown to user before proceeding
- **User choice:** Can abort if preferred receipt location unavailable

## Conservative Hardening Goals

This module implements **conservative** PowerShell security improvements:

1. **Enable Script Block Logging** - Critical for attack detection
2. **Configure Module Logging** - Track suspicious module usage  
3. **Validate AMSI Integration** - Ensure anti-malware scanning works
4. **Assess Execution Policies** - Document current configuration
5. **Log Transcription Setup** - Optional session recording

## Compatibility Promise

- ✅ **Sancta Scripts Preserved** - All existing scripts continue to work
- ✅ **Execution Policy Maintained** - No changes to current policy unless explicitly approved
- ✅ **Performance Impact Minimal** - Logging overhead is negligible
- ✅ **Enterprise Compatible** - Settings align with corporate security standards

## Future Enhancements

- **Advanced Threat Detection** - Custom PowerShell attack signatures
- **JEA Implementation** - Role-based PowerShell access control
- **Constrained Language Mode** - Restricted PowerShell environments
- **Certificate-based Signing** - Mandatory script signature validation

## Notes
- PowerShell 5.1+ required for full functionality
- Some advanced features require Windows 10/11 or Windows Server 2016+
- Logging generates additional event log entries (managed via retention policies)
- Compatible with existing group policy configurations
