# Task 11.1: Create Boot Script

**Source**: `BUILD-FROM-SCRATCH.md` section 11 (Boot script)

**Goal**: Verify the boot script sets UV_THREADPOOL_SIZE in HTML head before importing build/index.js.

---

## What to Check

### 11.2: Create start.mjs

```javascript
// Sets UV_THREADPOOL_SIZE, then imports adapter-node build:
#!/usr/bin/env node
```

**Verify these properties:**
1. Uses `process.env.UV_THREADPOOL_SIZE` for threadpool configuration
2. Sets threadpool size before importing adapter-node build: `import('./build/index.js')`
3. Default threadpool size is 8 threads (or derived from CPU count)
4. Dynamically imports adapter-node build via top-level await
5. Can be run as a Node script directly with `node start.mjs`
6. Production server runs on Node, not Bun (due to better-sqlite3 limitation)
7. Sets appropriate exit code for success/failure
8. Uses proper error handling and logging
9. ESM module format (.mjs) for top-level await
10. Threadpool size formula: max(8, cpuCount * 2) where cpuCount = os.cpus().length

---

## Verification Command

```powershell
# Check start.mjs exists:
Test-Path "start.mjs"
```

---

## Expected Output

```javascript
// Sample code structure:
#!/usr/bin/env node
import { uvSetDefaultThreadPools } from 'uvu';
uvSetDefaultThreadPools(process.env.UV_THREADPOOL_SIZE || 8);
await import('./build/index.js'); // adapter-node build here
```

---

## Success Criteria

- [ ] `start.mjs` exists
- [ ] Sets UV_THREADPOOL_SIZE = max(8, cpuCount * 2) before importing build
- [ ] Dynamically imports adapter-node build: await import('./build/index.js')
