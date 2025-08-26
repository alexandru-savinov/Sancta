# Work Connectivity

Sancta-compliant work connectivity solution with network isolation and audit trail.

## Overview

This module provides secure work connectivity while maintaining Sancta principles:
- **Human primacy**: Explicit consent for all installations and network changes
- **Least privilege**: Minimal elevation, only for software installation
- **Receipts**: Complete audit trail with undo instructions
- **Reversibility**: All changes can be undone

## Features

- **Cisco AnyConnect Installation**: Automated with Microsoft Store, winget and manual fallbacks
- **Network Isolation**: Work traffic separated via Windows network profiles
- **Security Preservation**: Validates existing hardening remains intact
- **Complete Audit Trail**: JSONL receipts for all operations

## Quick Start

```powershell
# Navigate to Sancta directory
cd "c:\Users\User\Documents\Sancta"

# Run work connectivity setup (interactive)
powershell -ExecutionPolicy Bypass -File "iac\work-connectivity\install-cisco-anyconnect.ps1"
```

## What It Does

1. **Checks for existing AnyConnect installation**
2. **Installs Cisco Secure Client** (Microsoft Store preferred, winget fallback)
3. **Creates work network profile** for traffic isolation
4. **Validates security hardening** is preserved
5. **Generates audit receipts** with undo instructions

## Security Features

- Preserves existing Windows Defender settings
- Maintains firewall configurations
- Isolates work traffic via network profiles
- No persistent backdoors or monitoring

## Launch AnyConnect

The installed app appears in Start Menu as:
- **"Cisco Secure Client"** (not "AnyConnect")

Or launch directly: `Start-Process "shell:AppsFolder\CiscoSystems.AnyConnect_edjcgkw48dhxt!App"`

## Next Steps After Installation

1. Launch Cisco Secure Client from Start Menu
2. Enter your organization's VPN server address
3. Set Windows network to 'Work' profile when connecting
4. Authenticate with your work credentials

## Files

- `install-cisco-anyconnect.ps1` - Main installation script
- `README.md` - This documentation

## Receipts

Audit receipts are written to: `V:\Study\Reciepts\work-connectivity.jsonl`

## Undo/Removal

All operations include undo instructions in receipts. Common reversals:

```powershell
# Uninstall Cisco Secure Client via winget
winget uninstall --id 9WZDNCRDJ8LH -s msstore

# Or via Start Menu: Right-click "Cisco Secure Client" → Uninstall
```

## Compliance

- ✅ Sancta Charter aligned
- ✅ Human oversight required
- ✅ Complete auditability  
- ✅ Reversible operations
- ✅ Security preservation
- ✅ Network isolation ready
