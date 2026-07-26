# Task 7.2: Implement Media API Endpoint

**Source**: `BUILD-FROM-SCRATCH.md` section 7 (Read queries & HTTP/API surface)

**Goal**: Verify the media API endpoint returns media list with pagination support.

---

## What to Check

### 7.3: Create GET /api/media Endpoint

```typescript
// Should return JSON array of media objects:
GET /api/media
```

**Verify these properties:**
1. Returns fields relevant to UI rendering (path, size, mtime, type)
2. Supports pagination with keyset (cursor) for large datasets
3. Returns `total` count alongside paginated results
4. Implements filtering by root, type, tags
5. Uses SQL queries optimized for common filter combinations
6. Supports query parameters: rootId, type, tagIds
7. Keyset cursor format for efficient pagination across 200k+ items
8. Returns proper HTTP status codes (200 OK)
9. Error handling with ApiErrorBody shape on failure
10. Uses partial indexes where applicable (WHERE is_trashed IS NOT NULL)

---

## Verification Command

```powershell
# Check media API endpoint exists:
Test-Path "src\routes\api\media\+server.ts"
```

---

## Expected Output

```typescript
// Sample response structure:
{
  items: [
    {
      id: number,
      path: string,
      filename: string,
      sizeBytes: number,
      mtimeMs: number,
      type: 'image' | 'video',
      ...
    }
  ],
  total: number,
}
```

---

## Success Criteria

- [ ] `src/routes/api/media/+server.ts` exists
- [ ] Returns JSON array of media objects with relevant fields
- [ ] Supports keyset (cursor) pagination for large datasets
