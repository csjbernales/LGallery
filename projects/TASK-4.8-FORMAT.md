# Task 4.8: Date Policy & Formatters

**Source**: `BUILD-FROM-SCRATCH.md` section 4.8 (`src/lib/shared/format.ts`)

**Goal**: Verify shared format utilities for consistent date/time handling across the app.

---

## What to Check

### Read: src/lib/shared/format.ts

```typescript
// Key exports from format.ts:
// - Date policy constants (local vs UTC)
// - Formatters: formatDate, formatDateMs, formatDuration,
// - Display helpers: mediaDisplayPath, mediaTypeLabel
```

**Verify these properties:**
1. Defines `DATE_POLICY` = `'local' | 'utc'` with default `'local'`
2. Uses `Intl.DateTimeFormat` for locale-aware formatting
3. Exports `formatDate(ms)` — formats milliseconds to human readable string
4. Exports `formatDateMs(ms)` — always uses UTC regardless of DATE_POLICY
5. Exports `formatDuration(durationMs)` — seconds/minutes/hours format
6. Exports `mediaDisplayPath(path, rootNormalized)` — strips root prefix for display
7. Exports `mediaTypeLabel(ext)` — maps extension to type string (`image`/`video`)
8. All exports are from module at `src/lib/shared/format.ts`
9. Uses `Date.fromMillis()` or equivalent (not `new Date(milliseconds)`)
10. No external date libraries imported

---

## Verification Command

```powershell
# Check format.ts exists:
Test-Path "src\lib\shared\format.ts"
```

**Run in Node to test formatters:**
```powershell
node -e "
const { formatDate, formatDateMs, formatDuration } = require('./src/lib/shared/format.ts');

// Test current date formatting
console.log('Current:', formatDate(Date.now()));
console.log('UTC mode:', formatDateMs(Date.now()));

// Test duration formatting
console.log('100ms:', formatDuration(100));           // ~100 ms
console.log('2s:', formatDuration(2000));            // 2 s
console.log('3min:', formatDuration(180000));        // 3 min
console.log('90min:', formatDuration(5400000));     // 90 min
console.log('2hr:', formatDuration(7200000));        // 2 h

// Test path formatting (example)
console.log('Display path:', 
  require('./src/lib/shared/format.ts').mediaDisplayPath('/photos/my photos/image.jpg', '/photos'));
"
```

---

## Expected Output

```typescript
// Sample from format.ts:
export const DATE_POLICY = 'local' as const; // or 'utc'

export function formatDate(ms: number): string {
  return new Intl.DateTimeFormat('en-US', {
    year: 'numeric', month: 'short', day: 'numeric',
    hour: '2-digit', minute: '2-digit' 
  }).format(Date.fromMillis(ms));
}

export function formatDateMs(ms: number): string {
  return new Intl.DateTimeFormat('en-US', {
    year: 'numeric', month: 'short', day: 'numeric',
    hour: '2-digit', minute: '2-digit', second: '2-digit' 
  }).format(Date.fromMillis(ms));
}

export function formatDuration(durationMs: number): string {
  if (durationMs < 1000) return `${Math.round(durationMs / 10)} ms`;
  if (durationMs < 60000) return Math.round(durationMs / 1000) + ' s';
  if (durationMs < 3600000) return Math.round(durationMs / 60000) + ' min';
  return Math.round(durationMs / 3600000) + ' h';
}
```

---

## Success Criteria

- [ ] `src/lib/shared/format.ts` exports all required formatters
- [ ] formatDate uses DATE_POLICY (defaults to local)
- [ ] formatDateMs always outputs UTC regardless of policy
- [ ] Duration formatting rounds correctly at 100ms/1s boundaries
