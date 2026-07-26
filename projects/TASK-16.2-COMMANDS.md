# Task 16.2: Verify Dev Commands

**Source**: `BUILD-FROM-SCRATCH.md` section 18 + package.json scripts

**Goal**: Verify development command patterns match BUILD-FROM-SCRATCH.md.

---

## What to Check

### 16.3: Read package.json Scripts Section

```powershell
# Check npm scripts:
Get-Content "package.json" | Select-Object -Skip 900 | Select-First 50
```

**Verify these properties:**
1. `scripts` object exists in root of package.json
2. Contains dev commands matching BUILD-FROM-SCRATCH.md section 18:
   - `dev: "vite"` or similar for development server
   - `lint: "eslint ..."`
   - `test: "vitest"`
3. Commands use Bun when available (`bun run dev`, etc.)
4. Vite dev server runs from root (not src/) per BUILD-FROM-SCRATCH.md
5. ESLint configuration for TypeScript and JavaScript files
6. Vitest configuration matching section 18 of BUILD-FROM-SCRATCH.md
7. Playwright E2E test commands included in scripts
8. All dev commands follow conventions from BUILD-FROM-SCRATCH.md
9. Proper error handling and logging throughout
10. Commands match BUILD-FROM-SCRATCH.md section 18 exactly

---

## Verification Command

```powershell
# Read scripts from package.json:
Get-Content "package.json" | Select-Object -Skip 2500 | Select-First 30
```

---

## Expected Output

```json
// Sample scripts section:
{
  "scripts": {
    "build": "bun build --outdir=build ...",
    "dev": "vite", ...
  }
}
```

---

## Success Criteria

- [ ] `package.json` has correct dev commands matching BUILD-FROM-SCRATCH.md section 18
