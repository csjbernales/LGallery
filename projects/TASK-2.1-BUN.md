# Task 2.1: Install Bun (Exact Version 1.3.14)

**Source**: `BUILD-FROM-SCRATCH.md` section 2.1 + package.json

**Goal**: Install Bun version exactly as pinned in `package.json`. The lockfile is committed with `lockfileVersion: 1`, so use the exact same Bun version.

---

## What to Do

### 2.2: Download Bun installer for current OS architecture

**Windows x64**: `bun-windows-x64-1.3.14.exe`
**macOS x64**: `bun-darwin-x64-1.3.14.tar.gz` or `.zip`
**Linux x64**: `bun-linux-x64-1.3.14.tar.xz`

### 2.3: Installation Commands

**Windows PowerShell:**
```powershell
# Method 1: Use official installer (recommended for Windows)
$installerPath = "C:\Users\Clark\Downloads\bun-windows-x64-1.3.14.exe"
Start-Process -FilePath $installerPath -ArgumentList "--quiet" -Wait
```

**macOS:**
```powershell
# Download and extract tarball
cd /tmp
curl -fsSL https://bun.sh/install | bash
```

**Linux:**
```powershell
# Download tarball to temp folder
cd /tmp
curl -fsSL https://bun.sh/install | bash
```

### 2.4: Verify Bun After Install

```powershell
# Check version after installation
bun -v
# Expected output: 1.3.14 (or >= 1.3.0)
```

---

## Verification Command

```powershell
# Verify Bun is installed and working
bun --version
```

---

## Expected Output

```powershell
# After successful install:
bun -v
# Output: 1.3.14 (or any version >= 1.3.0)
```

**If Bun not installed**: 
- Download from official releases at https://github.com/oven-sh/bun/releases
- Install to default path (no custom PATH entry needed for basic usage)

---

## Success Criteria

- [ ] Bun executable exists and runs without error
- [ ] Version is >= 1.3.0 (ideally exactly 1.3.14 for lockfile match)
- [ ] No errors when running `bun -v`

**Note**: Bun is the package manager, script runner, and bundler driver, but production server runs on Node (`node start.mjs`) due to better-sqlite3 native module incompatibility with Bun runtime.
