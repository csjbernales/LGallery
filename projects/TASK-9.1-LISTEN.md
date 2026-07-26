# Task 9.1: Create Login Route

**Source**: `BUILD-FROM-SCRATCH.md` section 9 (Authentication)

**Goal**: Verify the login route handles password hashing and session creation.

---

## What to Check

### 9.2: Create /login Endpoint

```typescript
// POST /login with username/password returns:
POST /login
```

**Verify these properties:**
1. Validates credentials against stored passwords using security module
2. Uses timing-safe password comparison from src/lib/server/security.ts
3. Hashes new passwords using scrypt (same as login)
4. Creates session token via deterministic sha256 hash
5. Sets session cookie with secure flags (HttpOnly, SameSite) when running on https
6. Returns success response on valid credentials
7. Returns ApiErrorBody shape for invalid credentials (status 401)
8. Uses `apiError(401, 'INVALID_CREDENTIALS', ...)` helper from http.ts
9. Error handling with proper logging via log module
10. Does NOT store plain-text passwords in database

---

## Verification Command

```powershell
# Check login route exists:
Test-Path "src\routes\login\+page.svelte"
```

---

## Expected Output

```typescript
// Sample response structure (valid credentials):
{
  success: true,
  token: string // session cookie set automatically by SvelteKit
}

// Invalid credentials:
{
  error: { code: 'INVALID_CREDENTIALS', message: 'Invalid username or password' }
}
```

---

## Success Criteria

- [ ] `src/routes/login/+page.svelte` exists
- [ ] POST /login validates credentials and creates session
- [ ] Uses timing-safe password comparison (scrypt + timingSafeEqual)
- [ ] Creates deterministic session token via sha256 hash
