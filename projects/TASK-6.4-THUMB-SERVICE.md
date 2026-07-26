# Task 6.4: Create Thumbnail Service Module

**Source**: `BUILD-FROM-SCRATCH.md` section 6 (Media pipeline & worker thread pool)

**Goal**: Verify the thumbnail service generates grid and preview thumbnails at correct resolutions.

---

## What to Check

### 6.5: Read src/lib/server/media/thumbnailService.ts

```powershell
# Read thumbnail service module:
Get-Content "src\lib\server\media\thumbnailService.ts"
```

**Verify these properties:**
1. Generates grid thumbnails at `longEdge` resolution with quality setting (default 320px, 70% quality)
2. Generates preview thumbnails at `1600px` long edge (default 80% quality)
3. Uses thumbnail format from config (webp only valid per schema)
4. Supports video storyboard generation at videoFrameAtPercent intervals
5. Default values match schema defaults:
   - grid: longEdge int>0 default 320, quality int 1..100 default 70
   - preview: longEdge default 1600, quality default 80
   - videoStoryboardFrames int>=0 default 5
6. Handles edge cases (small images, invalid aspect ratios)
7. Uses worker pool for parallel thumbnail generation
8. Returns thumbnail path for storage tracking
9. Implements caching to avoid regenerating existing thumbnails
10. Error handling with retry logic per-thumbnail

---

## Verification Command

```powershell
# Check thumbnail service exists:
Test-Path "src\lib\server\media\thumbnailService.ts"
```

---

## Expected Output

```powershell
# Thumbnail service should exist:
True
```

---

## Success Criteria

- [ ] `src/lib/server/media/thumbnailService.ts` exists
- [ ] Generates grid thumbnails at longEdge resolution with quality setting (default 320px, 70%)
- [ ] Generates preview thumbnails at 1600px long edge (default 80% quality)
