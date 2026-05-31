# Windows App Cleanup: Principles & Technical Approach

> **Status: dormant reglementation.** Sancta currently operates no Windows host,
> and the executable IaC that implemented this guidance (`iac/windows-app-cleanup/`)
> has been removed. This document is retained as the *rules* any future Windows
> app-cleanup must satisfy; recover the scripts from git history if a Windows
> host returns.

## Purpose

Provide a safe, repeatable, least-privilege procedure for removing unwanted Windows applications while following Sancta principles of dignity, consent, and reversibility.

## Scope & Non-goals

**Scope:**
- Propse a list of applications to remove
- Remove user-specified applications using standard Windows tools
- Prevent unwanted apps from returning for new user profiles
- Maintain comprehensive audit trails of all changes
- Preserve system stability and core Windows functionality
- Validate winget package IDs for all winget-managed targets before any removal action

**Non-goals:**
- Modify Windows system components or registry outside of standard app management
- Remove applications critical to Windows operation
- Bypass Windows security or elevation requirements
- Make irreversible changes without clear approval and documentation

## Core Principles

### 1. Human Primacy & Consent
- **Explicit confirmation required** for all destructive operations
- Users must type "YES" to proceed with removals
- Dry run mode available for safe exploration
- Clear abort mechanisms at each phase

### 2. Least Privilege & Minimal Surface Area
- Only targets explicitly specified applications
- Uses standard Windows tools (`winget`, `Remove-AppxPackage`)
- No broad system modifications or registry hacking
- Operates with standard user privileges where possible

### 3. Reversibility & Documentation
- Every removal action includes documented undo instructions
- Clear distinction between user packages and provisioned packages (with short explanation before)
- Receipt files provide complete audit trail
- Rollback procedures tested and documented

### 4. Transparency & Receipts
- Human-readable logs in structured JSON format
- Timestamps, inputs, outputs, and error conditions captured
- Clear progress indicators during execution
- Post-operation verification and reporting

### 5. Quiet by Default
- Minimal console output during normal operation
- Clear color coding for status indicators
- Batch operations rather than per-app prompts
- Non-disruptive to user workflow

## Technical Approach

### Two-Phase Removal Strategy

#### Phase 1: Winget-Managed Apps
**Target:** Standard Win32 and Store applications that winget can track
**Method:** `winget uninstall --id <AppId> -e --silent`
**Examples:** OneDrive, Teams, third-party software

Pre-validate Winget IDs (from the start)
- Before any uninstall is attempted, confirm the user-supplied identifier maps to a winget package ID that is installed or known to winget.
- Use these example commands during the discovery/validation phase:
  - winget list --id <AppId>           # check currently installed package(s)
  - winget search --id <AppId>         # verify package metadata exists in manifests
  - winget show --id <AppId>           # inspect publisher and exact id
- Validation criteria:
  - Exact ID match (case-insensitive) with expected publisher
  - If multiple matches appear, require disambiguation by publisher or full ID
  - If not found, mark as "invalid-id" and prompt user to confirm a corrective mapping or skip

**Why this works:**
- Winget maintains a registry of installed applications
- Handles both MSI/EXE and many Store packages
- Provides clean uninstallation with dependency management
- Fast and reliable for apps it recognizes

#### Phase 2: Provisioned App Deprovisioning
**Target:** Inbox/MSIX packages pre-staged by Windows
**Method:** `Remove-AppxPackage` + `Remove-AppxProvisionedPackage`
**Examples:** Bing News, Weather, Xbox components, Clipchamp

**Why additional steps are needed:**
- `winget uninstall` only removes from current user account
- Provisioned packages will reinstall for new users
- Some packages return after Windows updates
- Deprovisioning prevents future installation

### Discovery Before Action

Before making any changes:
1. **Inventory current state** - Check what's actually installed
2. **Validate targets** - Confirm specified apps exist on the system
   - Validate Winget IDs from the start for any winget-managed targets (see Phase 1). Resolve mismatches before continuing.
   - Example flow:
     1. Take user input (friendly name or tentative ID)
     2. Run winget search/show/list to obtain canonical ID and publisher
     3. Present canonical ID and publisher to user for confirmation
     4. Proceed only after explicit confirmation (type "YES")
3. **Report findings** - Show user what will be changed
4. **Get explicit consent** - Require confirmation before proceeding

### Error Handling & Safety

- **Graceful degradation** - Continue processing other apps if one fails
- **Non-fatal errors** - Warn about issues but don't abort entire operation
- **Detailed logging** - Capture error conditions with context
- **Verification phase** - Check results after changes

## Receipt Format

Each operation is logged with structured data:

```json
{
  "timestamp": "2025-08-22T15:30:45.123Z",
  "action": "winget-uninstall",
  "inputs": {"appId": "Microsoft.OneDrive"},
  "result": "success",
  "path": "",
  "elevated": false,
  "undo": "winget install --id Microsoft.OneDrive -e",
  "notes": "",
  "dryRun": false,
  "hostname": "MACHINE-NAME",
  "user": "username"
}
```

Recommended additions to receipts for validation provenance:
- "validatedAppId": canonical winget id discovered (if different from input)
- "validation": {"status":"verified"|"invalid-id"|"ambiguous", "publisher":"...", "checkedAt":"2025-08-22T15:30:44Z"}

Example (extended):
```json
{
  "timestamp":"2025-08-22T15:30:45.123Z",
  "action":"winget-uninstall",
  "inputs":{"requested":"OneDrive","appId":"Microsoft.OneDrive"},
  "validatedAppId":"Microsoft.OneDrive",
  "validation":{"status":"verified","publisher":"Microsoft","checkedAt":"2025-08-22T15:30:44Z"},
  "result":"success",
  "undo":"winget install --id Microsoft.OneDrive -e",
  "dryRun":false
}
```

## Security Considerations

### Elevation Requirements
- Most operations run with standard user privileges
- Deprovisioning may require elevation (system will prompt)
- No hardcoded administrator requirements
- Clear indicators when elevation is needed

### Data Protection
- No sensitive information logged in receipts
- App identifiers and package names only
- No user data or personal information captured
- Receipt files stored in user's document directory

### System Integrity
- Only uses supported Windows APIs and tools
- No direct registry manipulation
- No modification of system-critical components
- Preserves Windows update and security functionality

## Integration with Sancta Ecosystem

### Naming Conventions
- Module: `windows-app-cleanup` (follows `<purpose>-<scope>` pattern)
- Files: descriptive names with clear purpose
- Receipts: timestamped for easy chronological sorting

### IaC Pledge Compliance
- **Changes via code**: All modifications documented in scripts
- **Human-readable receipts**: JSON logs with clear undo instructions
- **Reviewer requirements**: Code changes follow PR review process
- **Rollback documentation**: Every action has documented reversal

### Charter Alignment
- **Dignity over data**: Removes extractive/surveillance applications
- **Consent is ceremony**: Explicit user confirmation required
- **Non-extraction**: Eliminates apps designed for data collection
- **Human primacy**: User can abort or customize at any point

## Operational Notes

### Dependencies
- **PowerShell 5.1+** (Windows default)
- **Winget** (Windows Package Manager)
- **Standard user account** with ability to elevate when needed

### Testing Strategy
- **Dry run mode** for safe exploration
- **Canary testing** on non-critical applications first
  - Include Winget ID validation in canary checks to ensure mappings and publisher expectations are correct
- **Verification phase** to confirm changes
- **Rollback testing** to ensure reversal procedures work

### Maintenance
- **App list updates** as new unwanted software appears
- **Winget ID validation** for correct package identification
  - Periodically refresh winget manifests and re-run ID validation for maintained app lists (e.g., nightly CI or weekly cron)
- **Compatibility testing** with Windows updates
- **Receipt format evolution** as logging needs change

---

This approach balances automation efficiency with human oversight, ensuring that Windows app cleanup remains safe, auditable, and aligned with Sancta's core values of user agency and transparent operation.
