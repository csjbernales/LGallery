# Task 7.1: Read Queries & Row Mappers

**Source**: `BUILD-FROM-SCRATCH.md` section 7.1 (`src/lib/server/db/queries.ts`)

**Goal**: Verify database read queries with proper pagination, indexing usage, and row mappers.

---

## What to Check

### Read: src/lib/server/db/queries.ts

```typescript
// Key exports from queries.ts:
// - Timeline query (primary read path)
// - Media query helpers (by dir/type/status etc.)
// - Album/tag/trash queries
// - Row mappers for all major types
```

**Verify these properties:**
1. Exports `findTimeline(params)` — paginated timeline with cursor/keyset pagination, sorted by `(is_trashed, is_archived, taken_ms DESC, id DESC)` using idx_media_timeline index
2. Uses keyset pagination: `WHERE id > ? ORDER BY id ASC` for next page (fast forward), `WHERE id < ? ORDER BY id DESC` for prev page (fast backward)
3. Exports query helpers: `findMediaByDir()`, `findMediaByType()`, `findPending()` for pipeline backfill
4. Row mappers: `mapMediaRow(row)` — converts DB row to Media interface with null handling for optional fields
5. Uses `.then()` (not Promise.fromEntries) per row (correct ES module pattern)
6. Limits are configured (default ~100 rows, configurable via params)
7. All exports from module at `src/lib/server/db/queries.ts`
8. No external query libraries imported (pure SQL + mapping logic)

---

## Verification Command

```powershell
# Check queries.ts exists:
Test-Path "src\lib\server\db\queries.ts"
```

**Run in Node to test row mapper:**
```powershell
node -e "
const { mapMediaRow } = require('./src/lib/server/db/queries.ts');

// Simulate a DB row with all fields populated
const mediaRow = {
  'id': 'abc123',
  'path': '/photos/image.jpg',
  'relPath': 'image.jpg',
  'dir': null,
  'filename': 'image.jpg',
  'ext': 'jpg',
  'type': 'image',
  'size_bytes': 2048576,
  'mtime_ms': 1719999999999, // recent ms
  'width': 3840,
  'height': 2160,
  'duration_ms': null,
  'taken_ms': 1719999900000,
  'taken_local_day': '2024-07-25',
  'camera_make': 'Sony',
  'camera_model': 'A7IV',
  'orientation': 6,
  'has_gps': 1,
  'gps_lat': 37.7749,
  'gps_lon': -122.4194,
  'live_partner_id': null,
  'is_favorite': 0,
  'is_archived': 0,
  'is_trashed': 0,
  'meta_status': 0,
  'thumb_status': 0,
  'error': null
};

const media = mapMediaRow(mediaRow);
console.log('Media type:', media.type);
console.log('Dimensions:', media.width + 'x' + media.height);
console.log('GPS lat:', media.gps_lat);
"
```

---

## Expected Output

```typescript
// Sample from queries.ts:
export function mapMediaRow(row: Row): Media {
  return {
    id: row.id,
    path: row.path,
    relPath: row.rel_path ?? null,
    dir: row.dir ?? null,
    filename: row.filename ?? null,
    ext: row.ext ?? null, // lowercased
    type: row.type as 'image' | 'video',
    size_bytes: Number(row.size_bytes),
    mtime_ms: Number(row.mtime_ms),
    width: row.width ? Number(row.width) : undefined,
    height: row.height ? Number(row.height) : undefined,
    duration_ms: row.duration_ms ? Number(row.duration_ms) : undefined,
    taken_ms: Number(row.taken_ms),
    taken_local_day: row.taken_local_day ?? null, // string like '2024-07-25'
    camera_make: row.camera_make ?? null,
    camera_model: row.camera_model ?? null,
    lens: row.lens ? String(row.lens) : undefined,
    orientation: Number(row.orientation),
    codec: row.codec ? String(row.codec) : undefined,
    has_gps: row.has_gps === 1 || row.has_gps === true ? true : false,
    gps_lat: row.gps_lat ? Number(row.gps_lat) : undefined,
    gps_lon: row.gps_lon ? Number(row.gps_lon) : undefined,
    quick_hash: row.quick_hash ?? null,
    phash: row.phash ?? null,
    blurhash: row.blurhash ?? null,
    live_partner_id: row.live_partner_id ?? null,
    is_favorite: row.is_favorite === 1 || row.is_favorite === true ? true : false,
    is_archived: row.is_archived === 1 || row.is_archived === true ? true : false,
    is_trashed: row.is_trashed === 1 || row.is_trashed === true ? true : false,
    meta_status: Number(row.meta_status),
    thumb_status: Number(row.thumb_status),
    error: row.error ?? undefined,
    scan_id: row.scan_id ?? null
  };
}
```

---

## Success Criteria

- [ ] `src/lib/server/db/queries.ts` exports timeline query function
- [ ] Timeline uses keyset pagination (WHERE id > ? / WHERE id < ?)
- [ ] Row mapper handles null fields correctly with optional chaining
