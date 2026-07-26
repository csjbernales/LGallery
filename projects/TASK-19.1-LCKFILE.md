# Task 19.1: Restore bun.lock File

**Source**: `BUILD-FROM-SCRATCH.md` appendix A + package.json

**Goal**: Verify and restore the committed bun.lock file for exact dependency tree.

---

## What to Check

### 19.2: Read bun.lock File Header

```powershell
# Check lockfile version:
Get-Content "bun.lock" | Select-First 5
```

**Verify these properties:**
1. `lockfileVersion: 1` (not 2 or higher) - matches package.json
2. Bun version pinned to exactly `1.3.14` in header comments
3. All top-level dependencies are locked with exact versions:
   - `@sveltejs/adapter-node`
   - `better-sqlite3`
   - `sharp`
   - `ffmpeg.wasm`
   - `osrm`
   - `uvu` (for thread pool)
4. All transitive dependencies are locked
5. No floating versions or wildcard ranges in bun.lock
6. Lock file is committed to git for reproducible builds
7. Location: `bun.lock` at project root
8. Lockfile matches BUILD-FROM-SCRATCH.md appendix A exactly
9. Uses exact version numbers (not ^ or ~)
10. All pinned dependencies match package.json + bun.lock together

---

## Verification Command

```powershell
# Verify lockfile exists and has correct header:
Get-Content "bun.lock" | Select-First 3
```

---

## Expected Output

```
lockfileVersion: 1
# Bun version pinned to exactly 1.3.14
# ...
bun.lock.yaml
```

---

## Success Criteria

- [ ] `bun.lock` exists with lockfileVersion: 1
- [ ] Bun version is pinned to exactly 1.3.14 in header comments
