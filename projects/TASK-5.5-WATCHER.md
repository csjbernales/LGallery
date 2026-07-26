# Task 5.5: Create Watcher Module

**Source**: `BUILD-FROM-SCRATCH.md` section 5 (Scan subsystem)

**Goal**: Verify the watcher module uses chokidar for filesystem watching and triggers rescan on changes.

---

## What to Check

### 5.6: Read src/lib/server/scan/watcher.ts

```powershell
# Read watcher module:
Get-Content "src\lib\server\scan\watcher.ts"
```

**Verify these properties:**
1. Uses chokidar for filesystem watching (not native Node API)
2. Watches configured root directories from config
3. Triggers rescan on config changes or file modifications
4. Supports recursive directory watching
5. Handles Windows path edge cases correctly
6. Configurable watch options (useFsEvents, poll, interval)
7. Graceful shutdown/cleanup on server stop
8. Debounces consecutive events to avoid excessive rescans
9. Logs watched paths for debugging
10. Uses Promise.race or async/await for non-blocking event handling

---

## Verification Command

```powershell
# Check watcher module exists:
Test-Path "src\lib\server\scan\watcher.ts"
```

---

## Expected Output

```powershell
# Watcher module should exist:
True
```

---

## Success Criteria

- [ ] `src/lib/server/scan/watcher.ts` exists
- [ ] Uses chokidar for filesystem watching
- [ ] Triggers rescan on config changes or file modifications
