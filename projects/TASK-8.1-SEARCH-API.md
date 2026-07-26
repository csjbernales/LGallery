# Task 8.1: Create Search API Endpoint

**Source**: `BUILD-FROM-SCRATCH.md` section 8 (Search & map)

**Goal**: Verify the search API endpoint handles text and image similarity queries.

---

## What to Check

### 8.2: Create GET /api/search Endpoint

```typescript
// Should return paginated results for:
GET /api/search?q=QUERY&rootId=N&limit=M
```

**Verify these properties:**
1. Supports text search using caption + filename (FTS5 full-text index)
2. Supports image similarity search via embedding comparison
3. Uses `text_search` table with FTS5 indexes for caption-based queries
4. Implements keyword proximity scoring for text search results
5. Supports filter by enabled roots only
6. Returns paginated results with offset/limit and total count
7. Uses appropriate SQL operators: LIKE, CONTAINS, MATCHES (for FTS5)
8. Image similarity uses embedding distance calculations
9. Supports sorting by relevance score descending
10. Error handling with ApiErrorBody shape on failure

---

## Verification Command

```powershell
# Check search API endpoint exists:
Test-Path "src\routes\api\search\+server.ts"
```

---

## Expected Output

```typescript
// Sample response structure:
{
  results: [
    {
      id: number,
      path: string,
      score: number, // relevance or similarity score
      ...
    }
  ],
  total: number,
}
```

---

## Success Criteria

- [ ] `src/routes/api/search/+server.ts` exists
- [ ] Supports text search using caption + filename (FTS5 full-text index)
- [ ] Supports image similarity search via embedding comparison
