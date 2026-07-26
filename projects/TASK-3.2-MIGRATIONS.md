# Task 3.2: Create Database Schema Migrations

**Source**: `BUILD-FROM-SCRATCH.md` section 3.6 (The migration set)

**Goal**: Ensure migration files exist with correct schema versions v1 through v6.

---

## What to Check

### 3.3: Read migration array from src/lib/server/db/schema.ts

```powershell
# Read the migrations file:
Get-Content "src\lib\server\db\schema.ts"
```

**Verify these properties:**
1. MIGRATIONS array exists with TARGET_SCHEMA_VERSION = 6
2. v1 core-schema includes all base tables (media, roots, albums, etc.)
3. v2 adds idx_media_day index for timeline scrollbar
4. v3 adds retry-attempts columns and partial indexes
5. v4 adds organize fields and recreates FTS5 triggers with caption
6. v5 adds places fields (place_name, place_locality, geocode_status)
7. v6 adds edits fields (edit_ops, edited_ms)

---

## Verification Command

```powershell
# Check migration file exists:
Test-Path "src\lib\server\db\schema.ts"

# Verify TARGET_SCHEMA_VERSION = 6 is set:
Get-Content "src\lib\server\db\schema.ts" | Select-String -Pattern "TARGET_SCHEMA_VERSION"
```

---

## Expected Output

```powershell
# Migration file should exist:
True

# Should find TARGET_SCHEMA_VERSION = 6:
Get-Content "src\lib\server\db\schema.ts" | Select-String -Pattern "TARGET_SCHEMA_VERSION"
```

---

## Success Criteria

- [ ] `src/lib/server/db/schema.ts` exists
- [ ] MIGRATIONS array with TARGET_SCHEMA_VERSION = 6 is defined
- [ ] v1 core-schema table definition includes media, roots, albums tables
- [ ] v2 adds idx_media_day index covering (is_trashed, is_archived, taken_local_day)
- [ ] v3 adds meta_attempts, thumb_attempts columns and retry indexes
- [ ] v4 adds caption, rating, pick fields and recreates FTS5 triggers
