# Task 6.2: Create Render Core Module

**Source**: `BUILD-FROM-SCRATCH.md` section 6 (Media pipeline & worker thread pool)

**Goal**: Verify the render core handles both images and video rendering with storyboarding.

---

## What to Check

### 6.3: Read render-core.mjs

```powershell
# Read render core module:
Get-Content "src\lib\server\media\render-core.mjs"
```

**Verify these properties:**
1. Handles both images and video rendering
2. Supports storyboarding (video frames at configurable intervals)
3. Configurable frame interval via videoStoryboardFrames default 5
4. Uses sharp for image processing with correct parameters
5. Manages memory efficiently during large render operations
6. Returns thumbnail path for storage tracking
7. Handles error cases gracefully without crashing
8. Supports preview rendering at higher resolution (1600px long edge)
9. ESM module format (.mjs) for top-level await
10. Optimized for batch processing of multiple files

---

## Verification Command

```powershell
# Check render core exists:
Test-Path "src\lib\server\media\render-core.mjs"
```

---

## Expected Output

```powershell
# Render core should exist:
True
```

---

## Success Criteria

- [ ] `src/lib/server/media/render-core.mjs` exists
- [ ] Handles both images and video rendering
- [ ] Supports storyboarding with configurable intervals
