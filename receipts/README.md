# Receipts Directory

This directory contains JSONL receipt files from various Sancta automation scripts.

## Structure

- `windows-app-cleanup.jsonl` - Windows application cleanup receipts
- `veracrypt.jsonl` - VeraCrypt installation and configuration receipts
- Other automation receipts as they are added

## Receipt Format

All receipts follow a standard JSON format with these fields:

```json
{
  "timestamp": "2025-08-23T10:30:00.000Z",
  "action": "winget-uninstall",
  "inputs": {"appId": "Microsoft.BingWeather"},
  "result": "success",
  "path": "",
  "elevated": false,
  "undo": "winget install --id Microsoft.BingWeather -e",
  "notes": "",
  "dryRun": false,
  "hostname": "COMPUTER01",
  "user": "username",
  "validation": {"status": "verified", "publisher": "Microsoft Corporation", "checkedAt": "2025-08-23T10:29:55.000Z"}
}
```

## Security and Privacy

Receipts contain potentially sensitive system information including:
- **Hostnames** - May reveal computer names or organizational patterns
- **Usernames** - Local user account information
- **Timestamps** - Activity patterns and timing information
- **Paths** - Local file system structure
- **Package lists** - Installed software inventory

### Protection Measures

1. **Git Exclusion**: Receipts are excluded from version control by default via `.gitignore`
2. **Selective Inclusion**: Create sanitized versions for sharing:
   ```bash
   # Safe patterns that can be committed:
   receipts/example.sanitized.jsonl
   receipts/template.redacted.jsonl
   ```
3. **Force Include** specific files only when necessary:
   ```bash
   git add -f receipts/specific-safe-file.jsonl
   ```
4. **Review Before Sharing**: Always sanitize hostname/username before sharing receipts externally

### Sanitization Example
```json
{
  "timestamp": "2025-08-23T10:30:00.000Z",
  "hostname": "REDACTED",
  "user": "REDACTED", 
  "action": "winget-uninstall",
  "result": "success"
}
```

## Retention

Receipts are kept indefinitely for audit purposes, but should be managed carefully:

### Archival Strategy
- **Archive old receipts** periodically to maintain performance
- **Compress archived receipts** to save space
- **Use separate archive directories** (automatically excluded from git)
  ```
  receipts/archive/2025/
  receipts/backup/
  ```

### Cleanup Commands
```powershell
# Archive receipts older than 90 days
$archiveDate = (Get-Date).AddDays(-90)
Get-ChildItem receipts/*.jsonl | Where-Object { $_.LastWriteTime -lt $archiveDate } | 
    Move-Item -Destination "receipts/archive/$(Get-Date -Format 'yyyy-MM')/"

# Compress old archives
Compress-Archive -Path "receipts/archive/2024*" -DestinationPath "receipts/2024-archive.zip"
```

### Sensitive Data Lifecycle
1. **Active receipts** (0-30 days) - Keep for immediate rollback needs
2. **Recent receipts** (30-90 days) - Archive but keep accessible  
3. **Historical receipts** (90+ days) - Compress and consider sanitization
4. **Long-term retention** - Keep compressed, sanitized versions for compliance
