# Task 4.1: Create Path Safety Module

**Source**: `BUILD-FROM-SCRATCH.md` section 4.1 (src/lib/server/paths.ts)

**Goal**: Verify the path safety module handles traversal guards and Windows 8.3 short name expansion.

---

## What to Check

### 4.2: Read src/lib/server/paths.ts

```powershell
# Read paths module:
Get-Content "src\lib\server\paths.ts"
```

**Verify these properties:**
1. Implements `normalizePath()` with UNC detection and drive-letter lowercasing
2. Uses `fs.realpathSync.native` for Windows 8.3 short name expansion
3. Implements `isWithin(child, parent)` for traversal guards (segment-boundary aware)
4. Uses `fs.promises.realpath` async API for root canonicalization
5. Handles UNC paths specially before resolve to preserve double slashes
6. Drive-letter lower-casing regex runs after slash replacement
7. Trailing-slash strip only when length > 1
8. Has PathError class with code = 'PATH_FORBIDDEN'
9. Uses cmp() for case-insensitive comparison on Windows only

### 4.3: Verify normalizePath logic

```typescript
// Should detect UNC via /^[\/]{2}[^\/]/ before resolve, then restore //
// Drive-letter lower-casing regex should be: ^([a-zA-Z]):$
```

---

## Verification Command

```powershell
# Check paths module exists:
Test-Path "src\lib\server\paths.ts"

# Verify realpathSync.native is imported/used for 8.3 expansion:
Get-Content "src\lib\server\paths.ts" | Select-String -Pattern "realpathSync\.native"
```

---

## Expected Output

```powershell
# Paths module should exist:
True

# Should find realpathSync.native usage for 8.3 expansion:
Get-Content "src\lib\server\paths.ts" | Select-String -Pattern "realpathSync\.native"
```

---

## Success Criteria

- [ ] `src/lib/server/paths.ts` exists
- [ ] Implements normalizePath() with UNC detection and drive-letter lowercasing
- [ ] Uses fs.realpathSync.native for 8.3 short name expansion
- [ ] Implements isWithin(child, parent) traversal guard
- [ ] Uses fs.promises.realpath async API for root canonicalization (not sync)
