# Task 7.3: Implement Timeline API Endpoint

**Source**: `BUILD-FROM-SCRATCH.md` section 7 (Read queries & HTTP/API surface)

**Goal**: Verify the timeline API endpoint returns date-bucketed media grouped by day/week/month.

---

## What to Check

### 7.4: Create GET /api/timeline Endpoint

```typescript
// Should return array of { date, count, items } objects:
GET /api/timeline
```

**Verify these properties:**
1. Returns date-bucketed media grouped by day/week/month
2. Aggregates counts for timeline scrollbar rendering (justified grid)
3. Uses covering index idx_media_day: (is_trashed, is_archived, taken_local_day)
4. Supports filter by enabled roots only
5. Returns `date` as ISO string (`YYYY-MM-DD`) or extended format
6. Includes count per date bucket for scrollbar width calculation
7. Supports optional parameters for grouping level (day/week/month)
8. Implements efficient aggregation using SQL GROUP BY and SUM()
9. Uses partial index for performance on filtered queries
10. Error handling with ApiErrorBody shape on failure

---

## Verification Command

```powershell
# Check timeline API endpoint exists:
Test-Path "src\routes\timeline\+server.ts"
```

---

## Expected Output

```typescript
// Sample response structure:
[
  {
    date: '2026-07-25',
    count: N,
    items: [...] // optional: paginated items for this bucket
  }
]
```

---

## Success Criteria

- [ ] `src/routes/timeline/+server.ts` exists
- [ ] Returns array of { date, count } objects grouped by day/week/month
- [ ] Uses covering index idx_media_day for efficient aggregation
