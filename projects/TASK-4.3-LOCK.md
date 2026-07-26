# Task 4.3: Create Lock Module

**Source**: `BUILD-FROM-SCRATCH.md` section 4.3 (src/lib/server/lock.ts)

**Goal**: Verify the lock module implements single-process FIFO mutex for coordinating scanner and file operations.

---

## What to Check

### 4.4: Read src/lib/server/lock.ts

```powershell
# Read lock module:
Get-Content "src\lib\server\lock.ts"
```

**Verify these properties:**
1. Module-level variable: `let chain: Promise<unknown> = Promise.resolve()`
2. withLock<T>(fn) implementation uses promise chaining pattern
3. Pattern: `const run = chain.then(fn, fn)` runs fn on both success and failure
4. After running fn: `chain = run.then(()=>{}, ()=>{})` so rejection can't poison the chain
5. Shared by scanner, fileService, and watcher for mutation safety
6. Critical sections should be short — scanner locks per-batch, not entire walk

---

## Verification Command

```powershell
# Check lock module exists:
Test-Path "src\lib\server\lock.ts"

# Verify promise chaining pattern is implemented:
Get-Content "src\lib\server\lock.ts" | Select-String -Pattern "\.then\\(fn, fn\\)"
```

---

## Expected Output

```powershell
# Lock module should exist:
True

# Should find promise chaining pattern for lock acquisition:
Get-Content "src\lib\server\lock.ts" | Select-String -Pattern "\.then\\(fn, fn\\)"
```

---

## Success Criteria

- [ ] `src/lib/server/lock.ts` exists
- [ ] Implements module-level chain variable as Promise<unknown>
- [ ] withLock<T>(fn) runs the function on both success and failure of prior link
- [ ] Advances chain after running: `chain = run.then(()=>{}, ()=>{})`
- [ ] Handles rejection gracefully without breaking the promise chain
