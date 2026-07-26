# Task 8.1-8.7: Places, Geocoding & AI Features

**Source**: `BUILD-FROM-SCRATCH.md` section 8 (`src/lib/server/geo/*.{ts,mjs}`, `src/lib/server/ai/*.ts`) 

**Goal**: Verify geolocation services and AI feature scaffolding (both OFF by default per golden rule).

---

## Files to Check

| File | Path | Purpose |
|------|------|--------|
| cities.ts | `src/lib/server/geo/cities.ts` | Bundled offline city data + haversine math |
| geocodeService.ts | `src/lib/server/geo/geocodeService.ts` | Nominatim reverse-geocoding service |
| ai/*.ts | `src/lib/server/ai/*.ts` | AI feature scaffold (CLIP, faces) |

---

## Verification Command

```powershell
# Verify geo and ai files exist:
Test-Path "src\lib\server\geo\cities.ts"
Test-Path "src\lib\server\geo\geocodeService.ts"
Get-ChildItem "src\lib\server\ai" -File | Select-Object Name
```

**Run in Node to test geocoding service loads:**
```powershell
node -e "
// Test cities module (no async on load)
const { haversine } = require('./src/lib/server/geo/cities.ts');

// Test geocodeService exports:
const geocode = require('./src/lib/server/geo/geocodeService.ts');
console.log('geocodeEnabled:', geocode.geocode.enabled);
"
```

---

## Expected Output

```typescript
// cities.ts exports:
export type City = { name: string; lat: number; lon: number };
export const CITIES_OFFLINE: readonly City[] = [...]; // global dataset
export function haversine(lat1: number, lon1: number, lat2: number, lon2: number): number; // km

// geocodeService.ts exports:
const geo = {
  enabled: false,      // OFF by default (golden rule)
  provider: 'offline', // default provider
};
export async function resolve(latitude: number, longitude: number): Promise<{ name?: string; locality?: string; country?: string } | null>;
```

---

## Success Criteria

- [ ] `src/lib/server/geo/cities.ts` exists with offline city dataset and haversine formula
- [ ] `src/lib/server/geo/geocodeService.ts` exists (OFF by default)
- [ ] AI module files exist under `src/lib/server/ai/*.ts`
- [ ] Geocoding service is disabled by default (`enabled: false`) 
