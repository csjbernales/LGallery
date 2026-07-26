# Task 7.2-7.3: HTTP Helpers & API Endpoint Surface

**Source**: `BUILD-FROM-SCRATCH.md` sections 7.2, 7.3 (`src/lib/server/http.ts`, `src/routes/api/**/+server.ts`)

**Goal**: Verify HTTP utility helpers and complete list of API endpoints.

---

## Files to Check

| File | Path | Purpose |
|------|------|--------|
| http.ts | `src/lib/server/http.ts` | Shared HTTP helpers (apiError, parseIds) |
| +server.ts files | `src/routes/api/**/+server.ts` | Complete API endpoint surface |

---

## Verification Command

```powershell
# List all API route directories:
Get-ChildItem "src\routes\api" -Directory | Select-Object Name
```

**Run in Node to test HTTP helpers:**
```powershell
node -e "
const { apiError, parseIds } = require('./src/lib/server/http.ts');

// Test apiError
console.log(apiError(401, 'AUTH', 'Login required'));

// Test parseIds
console.log(parseIds('1,2,3'));    // [1, 2, 3]
console.log(parseIds(['1', '2'])); // [1, 2]
console.log(parseIds('not array')); // []
"
```

---

## Expected Output

### http.ts exports:
```typescript
export function apiError(status: number, code: string, message: string): Response;
export function parseIds(input: string | number[] | ArrayLike<number>): number[];
```

### API Endpoint List (must verify via route inspection):

| Route | Method | Purpose |
|-------|--------|---------|
| `/api/media` | GET | Timeline media (paginated) |
| `/api/media/{id}` | GET | Single media by id |
| `/api/media/dir/{dirName}` | GET | Media in directory |
| `/api/media/type/{type}` | GET | Filtered media (image/video) |
| `/api/albums` | GET | Albums list |
| `/api/tags` | GET | Tags list |
| `/api/scan` | GET | Scan status + SSE events |
| `/api/config` | PUT | Update config (requires auth) |
| `/login` | POST | Authentication |

---

## Success Criteria

- [ ] `src/lib/server/http.ts` exports apiError and parseIds functions
- [ ] At least 8 API routes exist under `src/routes/api/`
- [ ] Timeline endpoint uses keyset pagination
- [ ] Auth endpoints return proper HTTP status codes (401, 303)
