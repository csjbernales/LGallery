# Task 4.9: Justified Row Layout Math

**Source**: `BUILD-FROM-SCRATCH.md` section 4.9 (`src/lib/shared/layout.ts`)

**Goal**: Verify layout utilities for the timeline view's justified grid that handles responsive widths and varying item sizes.

---

## What to Check

### Read: src/lib/shared/layout.ts

```typescript
// Key exports from layout.ts:
// - Grid configuration (tileWidth, gap)
// - calculateColumnWidth() — core math for justified rows
// - splitMediaIntoJustifiedRows() — media distribution algorithm
// - renderGridHtml() — DOM generation helper
```

**Verify these properties:**
1. Defines `GRID_CONFIG = { tileWidth: 264, gap: 12 }` (or similar values)
2. Exports `calculateColumnWidth(containerWidth)` — computes justified column width based on container size and media dimensions
3. Uses `(Math.ceil(dim / (tileWidth + gap))) - 1` formula for max items per row
4. Implements full justification algorithm: sorts by width, distributes extra space to longer columns first
5. Exports `splitMediaIntoJustifiedRows(media, config)` — returns array of rows with media assignments and column widths
6. Uses binary search or similar efficient distribution (not linear scan for each cell)
7. Exports `renderGridHtml(rows, containerWidth, density)` — generates <div class="grid-row"> wrappers with correct spans
8. Supports grid density levels (`compact`, `comfortable`, `spacious`) via config parameter
9. All exports from module at `src/lib/shared/layout.ts`
10. No external layout libraries imported (pure JS math)

---

## Verification Command

```powershell
# Check layout.ts exists:
Test-Path "src\lib\shared\layout.ts"
```

**Run in Node to test justified row calculation:**
```powershell
node -e "
const { GRID_CONFIG, calculateColumnWidth } = require('./src/lib/shared/layout.ts');

console.log('Grid config:', JSON.stringify(GRID_CONFIG));

// Test with 10 items of different widths (in pixels)
const media = [
  { width: 80 }, { width: 40 }, { width: 60 }, { width: 25 }, 
  { width: 90 }, { width: 35 }, { width: 70 }, { width: 50 },
  { width: 30 }, { width: 85 }
];
const columnWidth = calculateColumnWidth(1024); // full-width container
console.log('Column width (full):', columnWidth);

// Test responsive widths
const colWide = calculateColumnWidth(1920);    // desktop
const colNarrow = calculateColumnWidth(768);   // mobile
console.log('Col width (1920px):', colWide);
console.log('Col width (768px):', colNarrow);
"
```

---

## Expected Output

```typescript
// Sample from layout.ts:
export const GRID_CONFIG = {
  tileWidth: 264,
  gap: 12,
};

export function calculateColumnWidth(containerWidth: number): number {
  // Items per row based on container size (responsive)
  const itemsPerRow = Math.max(
    5, 
    Math.min(8, Math.floor((containerWidth - GRID_CONFIG.tileWidth) / GRID_CONFIG.gap))
  );
  
  // Max media height in this row
  const maxHeight = media.reduce(
    (max, m) => Math.max(max, m.height || GRID_CONFIG.tileWidth), 
    GRID_CONFIG.tileWidth
  );
  
  return (
    itemsPerRow * GRID_CONFIG.gap + 
    GridConfig.tileWidth + 
    ((itemsPerRow - 1) * max(0, Math.ceil(maxHeight / (GRID_CONFIG.tileWidth + GRID_CONFIG.gap))) - 1)
  );
}

// renderGridHtml generates <div class="grid-row grid-item">
```

---

## Success Criteria

- [ ] `src/lib/shared/layout.ts` exports justified row calculation functions
- [ ] Column width formula is correct for given container size
- [ ] Responsive behavior: narrower containers → fewer columns
- [ ] Full justification distributes space correctly (longer rows first)
