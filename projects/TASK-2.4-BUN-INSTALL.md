# Task 2.4: Install Dependencies with Bun (Lockfile Version 1)

**Source**: `BUILD-FROM-SCRATCH.md` section 2.2 + package.json

**Goal**: Install dependencies using Bun as the package manager, resolving against committed bun.lock file.

---

## What to Do

### 2.5: Run bun install (Lockfile Version 1)

```powershell
# Resolve dependencies against committed bun.lock (lockfileVersion: 1)
cd .
bun install
```

**Note**: This uses the exact versions in bun.lock, not npm registry.

### 2.6: Verify lockfile was created/updated

```powershell
# Check lockfile exists and has content:
Get-Item "bun.lock" | Select-Object -ExpandProperty Length
```

---

## Verification Command

```powershell
# Run install then verify
bun install
# Verify lockfile was updated
Test-Path ".\bun.lock"
```

---

## Expected Output

```powershell
# bun install output:
$0
> lgallery@0.1.0
> bun install

... (dependency resolution and installation messages) ...
bun install v1.3.14 (linux x64)
```

---

## Success Criteria

- [ ] `bun.lock` file exists with content (lockfileVersion: 1)
- [ ] All dependencies installed in node_modules/
- [ ] No errors during installation
- [ ] bun install exits with status code 0

**Note**: The lockfile pins exact transitive versions and MUST be present (committed) — it is reproduced in Appendix A. Install with the lockfile to get the identical tree.
