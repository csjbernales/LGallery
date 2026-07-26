# Task 1.2: Verify Environment Requirements

**Source**: `BUILD-FROM-SCRATCH.md` section 1.4

**Goal**: Verify that the environment meets LGallery's requirements before starting build.

---

## What to Check

### 1.3: Check Bun version - must be >= 1.3.0 (pin to 1.3.14)

```powershell
# Check current Bun version
bun -v
```

**Expected output**: `1.3.14` or higher

**If Bun not installed**: 
- Download: `https://github.com/oven-sh/bun/releases/download/v1.3.14/bun-windows-x64-1.3.14.exe`
- Install with: `--quiet` flag
- Add to PATH (usually auto-configured)

### 1.4: Check Node.js LTS is installed (required for production server)

```powershell
# Check Node version
node -v
```

**Expected output**: `>= 20.x` (Node 20+ satisfies @types/node ^25.9.3)

### 1.5: Verify npm is available

```powershell
npm --version
```

### 1.6: Confirm OS target

**Primary target**: Windows Server 2025 / Windows 10/11 with first-class Windows extras
- `setup-lgallery.cmd` / `.ps1` one-shot installer (winget + official fallbacks)
- `start-lgallery.cmd`, and `start-lgallery-hidden.vbs` autostart launchers
- Settings → "Start on Windows login"

**Also runnable**: macOS/Linux — nothing in app code is Windows-only except convenience launchers and 8.3 short-name handling (harmless no-op elsewhere)

---

## Verification Commands

```powershell
# Complete environment check
bun -v          # Should be >= 1.3.0, ideally 1.3.14
node -v         # Should be >= 20.x
npm --version   # Just to verify npm works
```

---

## Expected Output

```powershell
bun -v
# Output: 1.3.14 (or >= 1.3.0)

node -v
# Output: v20.x.y or similar (>= 20.x)
```

---

## Success Criteria

- [ ] Bun version >= 1.3.0 (ideally exactly 1.3.14 for lockfile match)
- [ ] Node LTS installed with version >= 20.x
- [ ] npm available and working
- [ ] Running on Windows Server 2025 / Windows 10/11 OR macOS/Linux

**If any requirement fails**: Document what's missing and install before proceeding.
