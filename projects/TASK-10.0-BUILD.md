# Task 10.0: Scripts, Build & Verification

**Source**: `BUILD-FROM-SCRATCH.md` section 10 (`package.json` scripts + Build plan) 

**Goal**: Verify build/run/verification commands and key architectural decisions.

---

## Files to Check

| File | Path | Purpose |
|------|------|--------|
| package.json | `package.json` | All scripts, dependencies, engines | start.mjs | `start.mjs` | Production launcher (sets UV_THREADPOOL_SIZE) |
| docs/10-BUILD-PLAN.md | `docs/10-BUILD-PLAN.md` | Complete build plan with decisions/gotchas catalog |

---

## Verification Command

```powershell
# Verify package.json exists and has required scripts:
Test-Path "package.json"
bun x -y --help > /dev/null 2>&1 && echo "Bun CLI available"
```

**Run in Node to verify start.mjs sets UV_THREADPOOL_SIZE:**
```powershell
node -e "
// Read and parse start.mjs content:
const fs = require('fs');
const content = fs.readFileSync('./start.mjs', 'utf8');
console.log('start.mjs starts with:', content.substring(0, 50));
"
```

---

## Expected Output

### package.json scripts (must match exactly):
```json
{
  "scripts": {
    "dev": "vite dev",
    "build": "vite build",
    "preview": "vite preview",
    "start": "node start.mjs",
    "check": "svelte-kit sync && svelte-check --tsconfig ./tsconfig.json"
  }
}
```

### start.mjs content (must exist):
```javascript
// Sets UV_THREADPOOL_SIZE before importing adapter-node build
const cpus = os.cpus()?.length || 4;
process.env.UV_THREADPOOL_SIZE = Math.max(8, cpus * 2).toString();
await import('./build/index.js');
```

---

## Success Criteria

- [ ] `package.json` has all required scripts (dev, build, start, check)
- [ ] `start.mjs` exists and sets UV_THREADPOOL_SIZE before server import
- [ ] Build plan exists at `docs/10-BUILD-PLAN.md`
