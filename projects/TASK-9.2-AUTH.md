# Task 9.2: Create Auth Check Middleware

**Source**: `BUILD-FROM-SCRATCH.md` section 9 (Authentication)

**Goal**: Verify the auth check middleware verifies session tokens and returns appropriate responses.

---

## What to Check

### 9.3: Create /auth/endpoint

```typescript
// GET /auth/endpoint with lg_token cookie:
GET /auth/endpoint?token=BASE64-ENCODED-TOKEN
```

**Verify these properties:**
1. Extracts and decodes base64 token from query parameter
2. Validates token format (length check)
3. Computes expected token using deterministic sha256 hash of stored password hash
4. Compares tokens for equality using timing-safe comparison
5. Returns Response object with status code and body:
   - Status 200 OK on valid token: `{ success: true, token: string }`
   - Status 401 Unauthorized on invalid/missing token: ApiErrorBody
6. Uses `apiError(401, 'UNAUTHORIZED', ...)` helper from http.ts
7. Error handling with proper logging via log module
8. Does NOT expose password hash in error responses (minimal info leak)
9. Returns Response object (not just string) for SvelteKit compatibility
10. Supports optional `lg_token` cookie header as alternative to query param

---

## Verification Command

```powershell
# Check auth endpoint exists:
Test-Path "src\routes\auth\endpoint.svelte"
```

---

## Expected Output

```typescript
// Sample response structure (valid token):
{
  success: true,
  token: string
}

// Invalid/missing token:
{
  error: { code: 'UNAUTHORIZED', message: 'Invalid or missing auth token' }
}
```

---

## Success Criteria

- [ ] `src/routes/auth/endpoint.svelte` exists
- [ ] GET /auth/endpoint validates session tokens correctly
- [ ] Returns Response object (not just string) for SvelteKit compatibility
