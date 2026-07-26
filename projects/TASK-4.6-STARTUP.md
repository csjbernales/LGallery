# Task 4.6: Create Startup Module

**Source**: `BUILD-FROM-SCRATCH.md` section 4.6 (src/lib/server/startup.ts)

**Goal**: Verify the startup module implements idempotent bootstrap that sets UV_THREADPOOL_SIZE before importing the Node server.

---

## What to Check

### 4.7: Read src/lib/server/startup.ts

```powershell
# Read startup module:
Get-Content "src\lib\server\startup.ts"
```

**Verify these properties:**
1. Idempotent bootstrap that can run on first request (fires in handle hook)
2. Sets UV_THREADPOOL_SIZE before importing build/index.js
3. Dynamically imports adapter-node build: `await import('./build/index.js')`
4. Threadpool size formula: max(8, cpuCount * 2) where cpuCount = os.cpus().length
5. Errors logged inside handle hook (retry on first request)
6. Ensures libuv threadpool is sized before any sharp/ffmpeg operations run
7. Thin launcher start.mjs calls import('./build/index.js') after setting UV_THREADPOOL_SIZE
8. Production should NOT be started with plain `node build/index.js` — use `bun run start`

---

## Verification Command

```powershell
# Check startup module exists:
Test-Path "src\lib\server\startup.ts"

# Verify UV_THREADPOOL_SIZE is set in startup:
Get-Content "src\lib\server\startup.ts" | Select-String -Pattern "UV_THREADPOOL_SIZE|os\.cpus"
```

---

## Expected Output

```powershell
# Startup module should exist:
True

# Should find UV_THREADPOOL_SIZE and os.cpuses references:
Get-Content "src\lib\server\startup.ts" | Select-String -Pattern "UV_THREADPOOL_SIZE|os\.cpus"
```

---

## Success Criteria

- [ ] `src/lib/server/startup.ts` exists
- [ ] Sets UV_THREADPOOL_SIZE = max(8, cpuCount * 2) before importing build
- [ ] Dynamically imports adapter-node build: await import('./build/index.js')
- [ ] Can be run idempotently on first request via handle hook
