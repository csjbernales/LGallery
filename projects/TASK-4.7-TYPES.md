# Task 4.7: Isomorphic Domain Types

**Source**: `BUILD-FROM-SCRATCH.md` section 4.7 (`src/lib/shared/types.ts`)

**Goal**: Verify shared types file exports isomorphic domain types (no node imports, for bundling into client).

---

## What to Check

### Read: src/lib/shared/types.ts

```typescript
// Key exports from types.ts:
// - Media type with all columns from schema v1-v6
// - Root/Scan/Album/Trash types
// - ApiErrorBody shape for /api endpoints
```

**Verify these properties:**
1. Exports `Media` interface matching all 47+ media columns (from v1-v6 migrations)
2. Includes optional fields from later migrations (caption, rating, pick, place_name, geocode_status, edit_ops, edited_ms)
3. Exports `Root`, `Scan`, `Album`, `AlbumItem`, `Tag`, `Trash` types
4. Defines `ApiErrorBody = { error: { code?: string; message: string } }`
5. Contains zero node built-in imports (no `node:fs`, `node:path`, etc.)
6. Uses Zod-compatible type annotations where applicable
7. Type aliases for common shapes (`MediaId`, `TagId`)
8. Located at `src/lib/shared/types.ts`
9. Exports all types as default exports from module
10. Media interface has nullable fields with optional chaining patterns (?.)

---

## Verification Command

```powershell
# Check types.ts exists:
Test-Path "src\lib\shared\types.ts"

# Verify no node imports in the file:
grep -E 'require\s*\(\s*["\']node:' "src/lib/shared/types.ts"
```

**Run TypeScript compiler to verify types are valid:**
```powershell
bun run check  # Runs svelte-kit sync + typecheck
```

---

## Expected Output

```typescript
// Sample from types.ts:
export interface Media {
  id: string;
  path: string; // original file path
  relPath: string | null; // relative to root
  dir: string | null;
  filename: string | null;
  ext: string | null; // lowercased, no leading dot
  type: 'image' | 'video';
  size_bytes: number;
  mtime_ms: number;
  width?: number; // may be null before thumbnailing
  height?: number;
  duration_ms?: number; // only for videos (null before scan)
  taken_ms: number;
  taken_local_day: string | null; // YYYY-MM-DD, null if unknown
  taken_source: 'file' | 'scan';
  camera_make: string | null;
  camera_model: string | null;
  lens?: string | null;
  orientation: number; // EXIF orientation value
  codec: string | null;
  has_gps: boolean; // was INTEGER NOT NULL DEFAULT 0 in schema
  gps_lat?: number; // may be null (no GPS)
  gps_lon?: number;
  quick_hash: string | null; // 16-char hash, may be null
  phash: string | null; // 8-char color hash for dedupe
  blurhash: string | null; // placeholder, may be null
  live_partner_id: string | null; // links to paired media (null if none)
  is_favorite: boolean; // INTEGER NOT NULL DEFAULT 0 → boolean
  is_archived: boolean;
  is_trashed: boolean;
  meta_status: number; // INTEGER NOT NULL DEFAULT 0 (retry logic v3+)
  thumb_status: number; // retry status for thumbnails (v3+)
  error?: string | null;
  scan_id: string | null; // which scan created this entry
  caption?: string | null; // from organize feature (v4)
  rating: number; // INTEGER NOT NULL DEFAULT 0 (v4)
  pick: number; // INTEGER NOT NULL DEFAULT 0 (v4)
  place_name?: string | null; // reverse geocode result (v5)
  place_locality?: string | null;
  place_country?: string | null;
  geocode_status: number; // INTEGER NOT NULL DEFAULT 0 (v5)
  edit_ops?: any[] | null; // JSON op list, NULL = unedited (v6)
  edited_ms: number; // INTEGER as double in schema → number
}
```

---

## Success Criteria

- [ ] `src/lib/shared/types.ts` exports all required domain types
- [ ] Media interface has all optional fields from v4-v6 migrations
- [ ] No node/built-in imports present
- [ ] TypeScript compilation passes without errors
