# Task 4.5: Create HTTP Helpers Module

**Source**: `BUILD-FROM-SCRATCH.md` section 4.5 (src/lib/server/http.ts)

**Goal**: Verify the HTTP helpers module provides grid width calculation and consistent error responses.

---

## What to Check

### 4.6: Read src/lib/server/http.ts

```powershell
# Read http helpers module:
Get-Content "src\lib\server\http.ts"
```

**Verify these properties:**
1. Imports `json`, `type Cookies` from @sveltejs/kit, and ApiErrorBody from $shared/types
2. initialGridWidth(cookies) reads viewport width cookie lg_w (set by boot script in app.html)
3. Subtracts sidebar (64 when w<=700, else 216) and pad = 24 (12px each side of TimelineGrid)
4. Formula: Math.max(280, round(w - sidebar - pad))
5. Falls back to 1200 when cookie absent/invalid
6. apiError(status, code, message) returns json({ error: { code, message } }) with status code
7. Error response matches ApiErrorBody shape: `{ error: { code?: string; message: string } }
8. parseIds(input): number[] accepts only arrays, maps to Number, keeps positive integers
9. Non-array input → returns []

---

## Verification Command

```powershell
# Check http helpers module exists:
Test-Path "src\lib\server\http.ts"

# Verify initialGridWidth function is implemented:
Get-Content "src\lib\server\http.ts" | Select-String -Pattern "initialGridWidth|lg_w"
```

---

## Expected Output

```powershell
# HTTP helpers module should exist:
True

# Should find initialGridWidth and lg_w cookie references:
Get-Content "src\lib\server\http.ts" | Select-String -Pattern "initialGridWidth|lg_w"
```

---

## Success Criteria

- [ ] `src/lib/server/http.ts` exists
- [ ] initialGridWidth() reads viewport width cookie lg_w and calculates correct grid width
- [ ] apiError(status, code, message) returns consistent ApiErrorBody shape
- [ ] parseIds(input): number[] implementation correctly filters non-positive integers
