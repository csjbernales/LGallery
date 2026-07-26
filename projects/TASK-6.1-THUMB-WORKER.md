# Task 6.1: Create Thumbnail Worker Module

**Source**: `BUILD-FROM-SCRATCH.md` section 6 (Media pipeline & worker thread pool)

**Goal**: Verify the thumbnail worker uses libuv thread pool for parallel thumbnail generation.

---

## What to Check

### 6.2: Read thumb-worker.mjs

```powershell
# Read thumbnail worker module:
Get-Content "src\lib\server\media\thumb-worker.mjs"
```

**Verify these properties:**
1. Uses libuv thread pool for parallel thumbnail generation (not Node workers)
2. Processes WebP output format (always webp)
3. Sharp library integration with correct parameters
4. Handles both images and video frames at configurable intervals
5. Memory-efficient streaming when possible
6. Error handling per-thumbnail without crashing worker
7. Returns thumbnail path for storage tracking
8. Uses thumbnail size from config (longEdge default 320px, quality default 70)
9. Supports storyboarding: generates ${id}_sb.webp for video frames at videoFrameAtPercent intervals (default 10%)
10. ESM module format (.mjs) for top-level await

---

## Verification Command

```powershell
# Check thumbnail worker exists:
Test-Path "src\lib\server\media\thumb-worker.mjs"
```

---

## Expected Output

```powershell
# Thumbnail worker should exist:
True
```

---

## Success Criteria

- [ ] `src/lib/server/media/thumb-worker.mjs` exists
- [ ] Uses libuv thread pool for parallel processing
- [ ] Outputs WebP format thumbnails
- [ ] Supports storyboarding with ${id}_sb.webp
