# Task 5.3: Create Differ Module

**Source**: `BUILD-FROM-SCRATCH.md` section 5 (Scan subsystem)

**Goal**: Verify the differ module compares existing DB records with found files to identify changes.

---

## What to Check

### 5.4: Read src/lib/server/scan/differ.ts

```powershell
# Read differ module:
Get-Content "src\lib\server\scan\differ.ts"
```

**Verify these properties:**
1. Compares existing DB records with found files
2. Identifies new files (in filesystem but not in DB)
3. Identifies updated files (changed mtime or size)
4. Identifies deleted files (in DB but not in filesystem)
5. Uses quick_hash/phash for efficient deduplication checks
6. Returns structured diff result with additions, modifications, deletions
7. Supports batch processing for performance
8. Handles edge cases like missing files due to resize/cleanup operations
9. Implements retry logic per file based on config maxAttempts
10. Uses partial indexes for filtered queries (where quick_hash IS NOT NULL)

---

## Verification Command

```powershell
# Check differ module exists:
Test-Path "src\lib\server\scan\differ.ts"
```

---

## Expected Output

```powershell
# Differ module should exist:
True
```

---

## Success Criteria

- [ ] `src/lib/server/scan/differ.ts` exists
- [ ] Identifies new files (filesystem but not in DB)
- [ ] Identifies updated files (changed mtime or size)
- [ ] Identifies deleted files (in DB but not filesystem)
