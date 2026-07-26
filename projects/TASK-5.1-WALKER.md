# Task 5.1: Create Walker Module

**Source**: `BUILD-FROM-SCRATCH.md` section 5 (Scan subsystem)

**Goal**: Verify the walker module traverses configured root directories.

---

## What to Check

### 5.2: Read src/lib/server/scan/walker.ts

```powershell
# Read walker module:
Get-Content "src\lib\server\scan\walker.ts"
```

**Verify these properties:**
1. Traverses configured root directories from config
2. Handles Windows path edge cases correctly
3. Recurses through subdirectories
4. Returns files matching image/video extensions from config
5. Applies include/exclude patterns from config
6. Tracks progress per root directory

---

## Verification Command

```powershell
# Check walker module exists:
Test-Path "src\lib\server\scan\walker.ts"
```

---

## Expected Output

```powershell
# Walker module should exist:
True
```

---

## Success Criteria

- [ ] `src/lib/server/scan/walker.ts` exists
- [ ] Recursively traverses root directories
- [ ] Filters files by image/video extensions from config
- [ ] Applies include/exclude patterns correctly
