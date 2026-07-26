# Task 9.4-9.6: Blurhash, Grid Components & Lightbox

**Source**: `BUILD-FROM-SCRATCH.md` section 9 (`src/lib/client/*.{ts,svelte}`)

**Goal**: Verify blurhash placeholder generation and UI components for timeline/grid views.

---

## Files to Check

| File | Path | Purpose |
|------|------|--------|
| blurhash-img.ts | `src/lib/client/blurhash-img.ts` | Client-side blurhash rendering |
| grid/*.svelte | `src/lib/components/grid/*.svelte` | TimelineGrid, MediaGridView components |
| lightbox/*.svelte | `src/lib/components/lightbox/*.svelte` | Lightbox modal, edit overlay |

---

## Verification Command

```powershell
# Verify client files exist:
Test-Path "src\lib\client\blurhash-img.ts"
Get-ChildItem "src\lib\components\grid" -File | Select-Object Name
Get-ChildItem "src\lib\components\lightbox" -File | Select-Object Name
```

**Run in Node to test blurhash calculation:**
```powershell
node -e "
// Test blurhash module exports:
const { computeBlurhash } = require('./src/lib/client/blurhash-img');
console.log('computeBlurhash:', typeof computeBlurhash);

// Generate sample
const hash = computeBlurhash(320, 240, '#4a9', 70);
console.log('Sample blurhash:', hash);
"
```

---

## Expected Output

### blurhash-img.ts exports:
```typescript
export function computeBlurhash(width: number, height: number, color: string, quality?: number): string;
// Client-side Canvas API usage for average-color placeholder
```

### TimelineGrid component (skeleton):
```typescript
// src/lib/components/grid/TimelineGrid.svelte
div class="timeline-grid" {
  // Justified rows with varying column spans
}
```

### Lightbox component (skeleton):
```typescript
// src/lib/components/lightbox/Lightbox.svelte
div class="lightbox modal" { media?.path ?? '' }
```

---

## Success Criteria

- [ ] `src/lib/client/blurhash-img.ts` exports blurhash calculation function
- [ ] TimelineGrid component exists and renders justified grid rows
- [ ] Lightbox component exists with proper modal behavior
