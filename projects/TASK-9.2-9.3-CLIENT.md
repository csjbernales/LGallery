# Task 9.2-9.3: Client State & API Layer

**Source**: `BUILD-FROM-SCRATCH.md` section 9 (`src/lib/client/*.{svelte.ts,ts}`)

**Goal**: Verify client-side state management and API integration layer.

---

## Files to Check

| File | Path | Purpose |
|------|------|--------|
| gallery.svelte.ts | `src/lib/client/state/gallery.svelte.ts` | Gallery selection state store |
| settings.svelte.ts | `src/lib/client/state/settings.svelte.ts` | UI preferences store |
| api.ts | `src/lib/client/api.ts` | Fetch wrappers for server routes |

---

## Verification Command

```powershell
# Verify client files exist:
Test-Path "src\lib\client\state\gallery.svelte.ts"
Test-Path "src\lib\client\state\settings.svelte.ts"
Test-Path "src\lib\client\api.ts"
```

**Run in Node to test API wrapper loads:**
```powershell
node -e "
// Test api module exports:
const { getMedia } = require('./src/lib/client/api');
console.log('getMedia:', typeof getMedia);
"
```

---

## Expected Output

### gallery.svelte.ts exports (Svelte 5 runes class):
```typescript
export default class GalleryStore {
  selectedIds: string[];
  // $state properties and methods using Svelte 5 syntax
}
```

### settings.svelte.ts exports:
```typescript
export const theme = $state('light' | 'dark' | 'system');
export const gridDensity = $state<'compact'|'comfortable'|'spacious'>('comfortable');
// etc.
```

### api.ts exports:
```typescript
export async function getMedia(id: string): Promise<Media>;
export async function getTimeline(params: GetTimelineParams): Promise<TimelineResult>;
// ... other API wrappers
```

---

## Success Criteria

- [ ] `src/lib/client/state/gallery.svelte.ts` uses Svelte 5 runes class syntax
- [ ] Settings store has `$state` properties (not legacy reactive)
- [ ] `src/lib/client/api.ts` exports fetch wrappers for API routes
