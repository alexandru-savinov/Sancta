# File Cleanup Proposal

## Files to Remove

The following files were created during development but are no longer needed:

### Test Files (Duplicates/Experimental)
- `windows-app-cleanup-simple.tests.ps1` - Simplified test file, superseded by main test file
- `windows-app-cleanup.unit.tests.ps1` - Duplicate unit tests, consolidated into main test file  
- `validate-implementation.ps1` - Manual validation script with syntax errors, no longer needed

### Reason for Removal
- **Duplication**: Multiple test files testing the same functionality
- **Superseded**: Main test file now contains all necessary unit tests
- **Syntax Issues**: Validation script has parsing errors and is not needed for production

## Final File Structure

After cleanup, the `iac/windows-app-cleanup/` directory should contain:

### Core Files ✅
- `windows-app-cleanup.ps1` - Main cleanup script
- `run-cleanup.ps1` - Quick runner with predefined modes  
- `app-targets.psd1` - Configuration with target app lists

### Documentation ✅
- `README.md` - User guide and examples
- `IMPLEMENTATION-SUMMARY.md` - Technical implementation details

### Testing ✅
- `windows-app-cleanup.tests.ps1` - Consolidated unit tests

## Manual Cleanup Required

The following files should be deleted manually (they may be locked by VS Code):

```powershell
# From iac/windows-app-cleanup/ directory:
Remove-Item "windows-app-cleanup-simple.tests.ps1" -Force
Remove-Item "windows-app-cleanup.unit.tests.ps1" -Force  
Remove-Item "validate-implementation.ps1" -Force
```

## Documentation Updates Applied ✅

1. **Main README** (`/README.md`) - Added section documenting the Windows App Cleanup tool
2. **Module README** (`iac/windows-app-cleanup/README.md`) - Simplified and focused on practical usage
3. **Test File** (`windows-app-cleanup.tests.ps1`) - Consolidated into essential unit tests only

The implementation is now clean, documented, and ready for production use.
