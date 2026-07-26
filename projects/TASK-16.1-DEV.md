# Task 16.1: Create Development Setup

**Source**: `BUILD-FROM-SCRATCH.md` section 18 + dev commands

**Goal**: Verify development setup files and commands are correct.

---

## What to Check

### 16.2: Read package.json Dev Dependencies

```powershell
# Check dev dependencies:
Get-Content "package.json" | Select-String -Pattern "^\s+"
```

**Verify these properties:**
1. Dev dependencies match BUILD-FROM-SCRATCH.md section 18 (Dev setup)
2. `@types/node` ^25.9.3 for TypeScript Node type definitions
3. Development dependencies for SvelteKit, TailwindCSS, Vite
4. Test dependencies: vitest for unit testing, playwright for E2E tests
5. TypeScript types and linting tools installed in devDependencies
6. No production dependencies in devDependencies (except test tools)
7. `@types/node` version satisfies @types/node ^25.9.3 requirement
8. All required type definitions are present
9. Development-friendly toolchain is configured
10. Dependencies match BUILD-FROM-SCRATCH.md section 18 exactly

---

## Verification Command

```powershell
# Read dev dependencies from package.json:
Get-Content "package.json" | Select-Object -Skip 2500 | Select-First 30
```

---

## Expected Output

```json
// Sample devDependencies section:
{
  "devDependencies": {
    "@types/node": ">=20.14.0",
    ...
  }
}
```

---

## Success Criteria

- [ ] `package.json` has correct devDependencies matching BUILD-FROM-SCRATCH.md section 18
