# Task 6.3: Create Worker Pool Module

**Source**: `BUILD-FROM-SCRATCH.md` section 6 (Media pipeline & worker thread pool)

**Goal**: Verify the worker pool spawns N concurrent workers based on config.

---

## What to Check

### 6.4: Read src/lib/server/media/workerPool.ts

```powershell
# Read worker pool module:
Get-Content "src\lib\server\media\workerPool.ts"
```

**Verify these properties:**
1. Spawns N concurrent workers based on config (workerCount or cores-1)
2. Manages worker lifecycle (start, shutdown)
3. Distributes workload across all workers
4. Handles worker failures gracefully with retry logic
5. Returns completion status when all tasks finished
6. Configurable concurrency level from lgallery.config.json
7. Uses Promise.all or similar for parallel task distribution
8. Tracks which thumbnails were generated successfully
9. Logs progress during batch thumbnail generation
10. Clean shutdown on server stop

---

## Verification Command

```powershell
# Check worker pool exists:
Test-Path "src\lib\server\media\workerPool.ts"
```

---

## Expected Output

```powershell
# Worker pool should exist:
True
```

---

## Success Criteria

- [ ] `src/lib/server/media/workerPool.ts` exists
- [ ] Spawns N concurrent workers based on config (workerCount or cores-1)
- [ ] Manages worker lifecycle correctly
