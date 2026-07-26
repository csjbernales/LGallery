# Task 5.2: Create Scanner Module

**Source**: `BUILD-FROM-SCRATCH.md` section 5 (Scan subsystem)

**Goal**: Verify the scanner module filters and processes files from configured roots.

---

## What to Check

### 5.3: Read src/lib/server/scan/scanner.ts

```powershell
# Read scanner module:
Get-Content "src\lib\server\scan\scanner.ts"
```

**Verify these properties:**
1. Filters files by extensions (image/video) from config
2. Applies include/exclude patterns from config
3. Handles recursive directory traversal
4. Tracks scan state per root directory
5. Supports rescan on startup and reloads
6. Configurable concurrency level
7. Uses workers for parallel scanning when enabled
8. Handles Windows path edge cases correctly
9. Returns list of found files with metadata (path, size, mtime)
10. Implements diff against existing DB records to identify new/updated/deleted

---

## Verification Command

```powershell
# Check scanner module exists:
Test-Path "src\lib\server\scan\scanner.ts"
```

---

## Expected Output

```powershell
# Scanner module should exist:
True
```

---

## Success Criteria

- [ ] `src/lib/server/scan/scanner.ts` exists
- [ ] Filters files by image/video extensions from config
- [ ] Applies include/exclude patterns correctly
- [ ] Supports rescan on startup and reloads
