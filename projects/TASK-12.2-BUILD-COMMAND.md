# Task 12.2: Verify Build Configuration

**Source**: `BUILD-FROM-SCRATCH.md` section 12 + package.json scripts

**Goal**: Verify the build configuration supports adapter-node standalone server generation.

---

## What to Check

### 12.3: Read package.json Scripts Section

```powershell
# Check npm scripts:
Get-Content "package.json" | Select-Object -Skip 900 | Select-First 50
```

**Verify these properties:**
1. `scripts` object exists in root of package.json
2. Contains `build: "bun build --outdir=build ..."` or similar command
3. Build flags include correct output directory and threadpool preservation
4. Supports adapter-node standalone server generation for deployment
5. Includes all necessary build plugins (svelte, vite, tailwindcss)
6. Build process generates `build/index.js` that imports adapter-node
7. Build configuration matches BUILD-FROM-SCRATCH.md section 12
8. Proper error handling and logging throughout
9. Supports production deployment to Node environments
10. Uses bun.build() for building with Bun bundler

---

## Verification Command

```powershell
# Read package.json:
Get-Content "package.json" | Format-HighString -Width 256
```

---

## Expected Output

```json
// Sample scripts section from package.json:
{
  "scripts": {
    "build": "bun build --outdir=build ...",
    ...
  }
}
```

---

## Success Criteria

- [ ] `package.json` has correct build script configuration
- [ ] Build uses bun.build() with adapter-node support flags
- [ ] Output directory is `build/` for adapter-node standalone server
