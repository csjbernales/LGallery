# Task 2.2: Install Node.js LTS

**Source**: `BUILD-FROM-SCRATCH.md` section 2.1 + package.json

**Goal**: Install current Node.js LTS version for the production server (launched via `node start.mjs`). Note that Node is required because production runs on Node, not Bun.

---

## What to Do

### 2.3: Download and install Node.js LTS

From https://nodejs.org/ (click "LTS" arrow to get current Long Term Support version)

**Recommended**: Download `v20.x.y` or later (Node 20+ satisfies @types/node ^25.9.3 requirements)

### 2.4: Installation

**Windows:**
1. Run the `.msi` installer from https://nodejs.org/dist/
2. Follow installation wizard (default paths fine)
3. Restart PowerShell for PATH changes to take effect

**macOS:**
```powershell
# Method 1: Using Homebrew (recommended if available)
brew install --install-head node@v20.x
```

### 2.5: Verify Node After Install

```powershell
# Check version after installation
node -v
# Expected output: >= 20.x (Node 20+ satisfies @types/node ^25.9.3)
```

---

## Verification Command

```powershell
# Verify Node is installed and working
node --version
```

---

## Expected Output

```powershell
# After successful install:
node -v
# Output: v20.x.y or similar (>= 20.x)
```

**If Node not installed**: 
- Download from https://nodejs.org/dist/
- Run the LTS version installer
- Restart terminal for PATH changes to take effect

---

## Success Criteria

- [ ] Node.js executable exists and runs without error
- [ ] Version is >= 20.x (Node 20+ satisfies @types/node ^25.9.3)
- [ ] No errors when running `node --version`
- [ ] npm is available via Node installation

**Note**: Node is required for:
1. Production server launch (`node start.mjs` → imports build/index.js)
2. Adapter-node runtime (builds to standalone Node server)
3. The Vite/Vitest dev/test runners execute on Node under the hood even when invoked via `bun run`
