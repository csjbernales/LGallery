# Task 4.4: Create Logging Module

**Source**: `BUILD-FROM-SCRATCH.md` section 4.4 (src/lib/server/log.ts)

**Goal**: Verify the logging module implements rotating file logs with proper level filtering.

---

## What to Check

### 4.5: Read src/lib/server/log.ts

```powershell
# Read log module:
Get-Content "src\lib\server\log.ts"
```

**Verify these properties:**
1. Supports debug|info|warn|error levels with minOrder calculation from ORDER constant
2. Default config: `{ level:'info', file:'data/lgallery.log', maxSizeMb:10, maxFiles:5 }`
3. absFile = path.resolve(cwd, file)
4. initLogger(partial) merges partial config, recomputes absFile/minOrder, resets dirReady
5. ensureDir() uses mkdirSync with recursive:true; on failure falls back to console-only (dirReady stays false)
6. rotateIfNeeded() shifts log.(n-1) → log.n dropping oldest when file ≥ maxSizeMb*1024*1024
7. All operations wrapped in try/catch — never crashes on disk errors
8. write(level,msg,meta?) line format: `ISO ts [LEVEL] msg` + serialized meta
9. Console mirror: warn/error always; everything else only when NODE_ENV !== 'production'
10. Exports log = { debug, info, warn, error }

---

## Verification Command

```powershell
# Check log module exists:
Test-Path "src\lib\server\log.ts"

# Verify log level constants and ORDER are defined:
Get-Content "src\lib\server\log.ts" | Select-String -Pattern "ORDER|debug|info|warn|error"
```

---

## Expected Output

```powershell
# Log module should exist:
True

# Should find level constants and ORDER definition:
Get-Content "src\lib\server\log.ts" | Select-String -Pattern "ORDER|debug|info|warn|error"
```

---

## Success Criteria

- [ ] `src/lib/server/log.ts` exists
- [ ] Supports debug/info/warn/error log levels with minOrder = 10,20,30,40
- [ ] Default config writes to data/lgallery.log
- [ ] Rotates logs when exceeding maxSizeMb (default 10MB)
- [ ] Keeps maxFiles (default 5) rotated logs
