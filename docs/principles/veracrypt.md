# VeraCrypt: Principles & IaC Guidance (Sancta)

> **Status: dormant reglementation.** Sancta currently operates no Windows host,
> and the executable IaC that implemented this guidance
> (`iac/veracrypt/install-veracrypt.ps1`) has been removed. This document is
> retained as the *rules* any future VeraCrypt vault must satisfy; recover the
> script from git history if a Windows host returns.

## Purpose

Provide a safe, repeatable, least-privilege procedure and IaC template for creating and operating a local VeraCrypt file-backed vault on Windows. This guidance is for local machine vaults meant to hold intimate or sensitive data; it deliberately does not touch OS disk encryption (BitLocker), bootloaders, or other system disks.

## Scope & Non-goals

- Scope: per-user, file-backed VeraCrypt volumes (not system/OS volumes).
- Non-goals: do not modify BitLocker, EFI/boot settings, or other disks. Do not exfiltrate secrets or enable telemetry beyond Windows defaults.

## Core Principles

- Least privilege: elevate only for the narrow tasks that require it (MSI install, drive labeling). Time-box and prompt user for elevation.
- Private by default: passwords are never stored in plaintext. Use SecretManagement/SecretStore, DPAPI, or an enterprise secret vault.
- Human gates: require explicit user confirmation before creating production volumes, enabling auto-mount, or creating external backups.
- Reversible & documented: every action must include an undo instruction and a local human-readable receipt.

## Checklist (automatable, idempotent)

1. Install VeraCrypt (winget preferred) with robust source-check and MSI fallback.
2. Verify CLI tools: `VeraCrypt.exe` and `VeraCrypt Format.exe` present.
3. Create a canary volume (20 MB) to validate automation and mount flow.
4. Create production vault file (size param). Recommended: AES + SHA-512, NTFS, quick format as acceptable default.
5. Mount and test read/write sentinel file.
6. Offer/implement auto-mount:
   - Preferred (IaC): per-user scheduled task that reads password from SecretStore at logon and mounts with VeraCrypt CLI.
   - Fallback (manual): VeraCrypt Favorites → Add Mounted Volume to Favorites → check "Mount at logon" (human-gate).
7. Exclude vault path from Windows Search indexing (manual UI or enterprise policy).
8. Add vault path to Windows Defender Controlled Folder Access (CFA) protected folders; allowlist VeraCrypt if needed (manual UI or enterprise policy).
9. Create external header backup and store on an external/unshared device (USB or backup repository).

## Security & Secrets

- Never embed the vault password in scripts. Use a protected secret store. For local scripts, `Microsoft.PowerShell.SecretManagement` + `SecretStore` is recommended.
- If the user declines password caching, prompt for the password interactively at creation and at each automated mount.

## Idempotence & Verification

- Scripts must check for existing artifacts before creating them: directories, installs, files, scheduled tasks.
- Emit a human-readable receipt after each step. Receipt fields: `ts` (ISO8601), `action`, `inputs`, `result`, `path`, `elevated?`, `undo`.
- Verification commands (examples):
  - Check install: verify presence of `C:\Program Files\VeraCrypt\VeraCrypt.exe` and `VeraCrypt Format.exe`.
  - Check mount: `Test-Path V:\` or `Get-PSDrive V`.
  - Check header backup: confirm `.hdr` file exists in the user-specified backup directory.

## Undo & Recovery

- Unmount: `VeraCrypt.exe /dismount <letter>`
- Delete file-backed vault: `Remove-Item '<path>' -Force` (destructive; document before action)
- Uninstall VeraCrypt (MSI): `msiexec /x {ProductCode}` or `winget uninstall --id IDRIX.VeraCrypt -e`

## Operational Notes

- Canary first: always validate automation using a small canary volume before creating production volumes.
- Pin installer hashes: if falling back to MSI/EXE downloads, pin and verify SHA256.
- Defender and Indexing UI actions often require manual confirmation; document UI steps in the runbook and require user acknowledgement.
- For enterprise deployment, convert UI steps into Intune/MDM policies (CFA, indexing exclusions, allowed apps).

## Files & Locations (recommended)

- Vault file pattern: `%USERPROFILE%\\LocalVault\\<machine>-vault.hc` (example: `study-nb-prd-01-vault.hc`).
- Header backups: dedicated external path (example `D:\Sancta\Vaults\Backups\`), use date-stamped filenames.
- IaC script: _removed_ — the idempotent template/runbook formerly at
  `iac/veracrypt/install-veracrypt.ps1` was retired with the rest of the Windows
  IaC; restore it from git history if a Windows host returns.

## References

- VeraCrypt CLI and format options — official VeraCrypt documentation.
- Windows indexing and Defender Controlled Folder Access — Microsoft Support.

## Appendix: Minimal receipts format (JSON-line example)

`{"ts":"2025-08-22T11:26:52Z","action":"create-vault","path":"C:\\Users\\User\\LocalVault\\study-nb-prd-01-vault.hc","size":"20G","elevated":false,"undo":"Remove-Item 'C:\\Users\\User\\LocalVault\\study-nb-prd-01-vault.hc' -Force"}`
