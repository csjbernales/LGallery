# Task 9.7-9.8: Navigation & Routes

**Source**: `BUILD-FROM-SCRATCH.md` section 9 (`src/routes/*.svelte`, `src/lib/client/nav/*.svelte`) 

**Goal**: Verify SvelteKit routes and navigation component structure.

---

## Files to Check

| File | Path | Purpose |
|------|------|--------|
| +page.svelte files | `src/routes/+page.svelte` | Root pages (home, albums, tags) |
| +layout.svelte files | `src/routes/+layout.svelte` | Layout wrappers with sidebar/nav |
| nav/*.svelte | `src/lib/client/nav/*.svelte` | Navigation sidebar component |

---

## Verification Command

```powershell
# List SvelteKit routes:
Get-ChildItem "src\routes" -Recurse -File | Where-Object { $_.Extension -eq '.svelte' } | Select-Object FullName
```

**Run in Node to test navigation module loads:**
```powershell
node -e "
// Test nav component exports:
const nav = require('./src/lib/client/nav');
console.log('navSidebar:', typeof nav.navSidebar);
"
```

---

## Expected Output

### SvelteKit Route Structure (must exist):
- `src/routes/+layout.svelte` — App root layout with sidebar
- `src/routes/albums/+page.svelte` — Albums listing page
- `src/routes/tags/+page.svelte` — Tags listing page
- `src/routes/media/+page.svelte` — Media view (timeline/grid) page
- `src/routes/api/+server.ts` files — API routes under `/api`

### Navigation component exports:
```typescript
export function navSidebar({ media, onNavigate }: NavProps): any;
// Sidebar with timeline navigation, folder tree, album list
```

---

## Success Criteria

- [ ] App root layout exists at `src/routes/+layout.svelte`
- [ ] Albums and tags listing pages exist
- [ ] Media view page exists (timeline/grid)
- [ ] Navigation sidebar component exports navSidebar function
