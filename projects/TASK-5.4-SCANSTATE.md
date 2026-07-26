# Task 5.4: Create Scan State Module

**Source**: `BUILD-FROM-SCRATCH.md` section 5 (Scan subsystem)

**Goal**: Verify the scan state module tracks progress and manages retry attempts.

---

## What to Check

### 5.5: Read src/lib/server/scan/scanState.ts

```powershell
# Read scan state module:
Get-Content "src\lib\server\scan\scanState.ts"
```

**Verify these properties:**
1. Tracks progress per root directory independently
2. Manages retry attempts for failed files (meta_attempts, thumb_attempts)
3. Stores next_retry_ms for backoff-driven retries
4. Supports resumable scanning after interruption
5. Implements exponential backoff calculation
6. Enforces maxAttempts limit from config (default 3)
7. Handles permanent failures gracefully
8. Uses partial index idx_media_pending for retry queue queries
9. Updates media table via transaction on success/failure
10. Thread-safe state management if running concurrently

---

## Verification Command

```powershell
# Check scan state module exists:
Test-Path "src\lib\server\scan\scanState.ts"
```

---

## Expected Output

```powershell
# Scan state module should exist:
True
```

---

## Success Criteria

- [ ] `src/lib/server/scan/scanState.ts` exists
- [ ] Tracks progress per root directory independently
- [ ] Manages retry attempts for failed files (meta_attempts, thumb_attempts)
- [ ] Stores next_retry_ms for backoff-driven retries
