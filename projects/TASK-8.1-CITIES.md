# Task 8.1: Cities Dataset & Geolocation Math

**Source**: `BUILD-FROM-SCRATCH.md` section 8.1

**Goal**: Verify cities.ts provides bundled offline city data with haversine distance calculations.

---

## What to Check

### 8.2: Read src/lib/server/geo/cities.ts

```typescript
// Key exports from cities.ts:
- type City { name, lat, lon }
- const CITIES_OFFLINE: readonly City[] // bundled dataset
- function haversine(lat1: number, lon1: number, lat2: number, lon2: number): number // km
```

**Verify these properties:**
1. Exports `CITIES_OFFLINE` as a read-only array of cities with name/lat/lng
2. Cities are pre-loaded at module load time (no API calls)
3. Haversine formula calculates distance between two coordinates in kilometers
4. Includes helper functions: degreesToRadians, radiansToDegrees
5. Has constants for EARTH_RADIUS_M = 6371000
6. Located at `src/lib/server/geo/cities.ts`
7. Cities cover major global locations (not just one region)
8. Latitude range [-90, 90], Longitude range [-180, 180]
9. Array is frozen or immutable (readonly type)

---

## Verification Command

```powershell
# Check cities.ts exists:
Test-Path "src\lib\server\geo\cities.ts"
```

**Run in Node to test haversine formula:**
```powershell
# Verify haversine returns correct distance between London and Paris (approx 340km)
node -e "
const { haversine, degreesToRadians } = require('./src/lib/server/geo/cities.ts');
const lon1 = -0.1278;
const lat1 = 51.5074; // London
const lon2 = 2.3522;
const lat2 = 48.8566; // Paris
const result = haversine(lat1, lon1, lat2, lon2);
console.log('London-Paris:', result.toFixed(2) + ' km');
"```

**Expected output:** `London-Paris: ~340 km` (tolerant ±5%)

---

## Expected Output

```typescript
// Sample from cities.ts:
const EARTH_RADIUS_M = 6371000;
const degreesToRadians = d => d * Math.PI / 180;

export type City = { name: string; lat: number; lon: number };

export const CITIES_OFFLINE: readonly City[] = [
  { name: 'London', lat: 51.5074, lon: -0.1278 },
  // ...
];
```

---

## Success Criteria

- [ ] `src/lib/server/geo/cities.ts` exists with cities array
- [ ] Haversine formula returns correct distance (~340km London-Paris)
