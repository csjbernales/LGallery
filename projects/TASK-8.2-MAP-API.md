# Task 8.2: Create Map API Endpoint

**Source**: `BUILD-FROM-SCRATCH.md` section 8 (Search & map)

**Goal**: Verify the map API endpoint serves map tiles for OpenStreetMap integration.

---

## What to Check

### 8.3: Create GET /api/map Endpoint

```typescript
// Returns image data for OpenStreetMap tiles:
GET /api/map?x=Z&y=W&zoom=N
```

**Verify these properties:**
1. Returns base64-encoded JPEG tile data (no external dependencies)
2. Uses `osrm` library to fetch map tiles from OpenStreetMap servers
3. Implements proper HTTP header handling for tile requests
4. Supports configurable zoom levels and tile dimensions
5. Handles errors gracefully with fallback response
6. Memory-efficient tile fetching (streaming if possible)
7. Returns proper Content-Type: image/jpeg header or base64 data
8. Error handling with ApiErrorBody shape on failure
9. Uses `osrm` library as specified in package.json dependencies
10. Supports optional caching headers for repeated requests to same tile

---

## Verification Command

```powershell
# Check map API endpoint exists:
Test-Path "src\routes\api\map\+server.ts"
```

---

## Expected Output

```typescript
// Sample response structure (base64 image data):
base64-encoded-JPEG-data

// Or error response:
{
  error: { code: string, message: string }
}
```

---

## Success Criteria

- [ ] `src/routes/api/map/+server.ts` exists
- [ ] Returns base64-encoded JPEG tile data using osrm library
- [ ] Uses OpenStreetMap servers via osrm package
