# Task 12.1: Create Build Script

**Source**: `BUILD-FROM-SCRATCH.md` section 12 (Build script)

**Goal**: Verify the build script runs bun build with correct flags for adapter-node.

---

## What to Check

### 12.2: Create start.mjs content

```javascript
// Runs bun build and starts production server:
#!/usr/bin/env node
```

**Verify these properties:**
1. Uses `bun.build()` for building with Bun bundler
2. Correct flags: `-c 'UV_THREADPOOL_SIZE=${UV_THREADPOOL_SIZE:-8}'` to preserve threadpool size in build
3. Output directory: `build/` (not dist/) for adapter-node standalone server
4. Runs production server immediately after build via `bun run start`
5. Production server runs on Node, not Bun (due to better-sqlite3 limitation)
6. Proper error handling and logging throughout
7. Sets appropriate exit code for success/failure
8. Uses proper error handling for bun.build() failures
9. Can be run as a Node script directly with `node start.mjs`
10. Threadpool size formula: max(8, cpuCount * 2) where cpuCount = os.cpus().length

---

## Verification Command

```powershell
# Check build script exists:
Test-Path "start.mjs"
```

---

## Expected Output

```javascript
// Sample code structure:
#!/usr/bin/env node
const { uvSetDefaultThreadPools } = await import('uvu');
uvSetDefaultThreadPools(process.env.UV_THREADPOOL_SIZE || 8);
await bun.build({
  cwd: '.',
  input: 'src',
  output: 'build',
  flags: ['-c', `'UV_THREADPOOL_SIZE=${process.env.UV_THREADPOOL_SIZE:-8}'`]
});
await import('./build/index.js'); // adapter-node build here
```

---

## Success Criteria

- [ ] `start.mjs` exists
- [ ] Uses bun.build() with correct flags for adapter-node
- [ ] Output directory is `build/` (not dist/) for adapter-node standalone server
