# Task 4.2: Create Security Module

**Source**: `BUILD-FROM-SCRATCH.md` section 4.2 (src/lib/server/security.ts)

**Goal**: Verify the security module implements proper password hashing and CSRF protection.

---

## What to Check

### 4.3: Read src/lib/server/security.ts

```powershell
# Read security module:
Get-Content "src\lib\server\security.ts"
```

**Verify these properties:**
1. Imports `crypto` and `apiError` from ./http
2. Implements hashPassword() using scrypt with 16-byte random salt, crypto.scryptSync(plain, salt, 64)
3. Uses crypto.timingSafeEqual for password verification (timing-attack safe)
4. Session token generation via deterministic sha256('lg-session:' + passwordHash)
5. Empty-hex reject fix: checks salt.length === 0 || expected.length === 0 before comparison
6. IsSameOrigin() header check with fallback to Origin, missing Origin returns true (same-origin navigation allowed)
7. requireMutation() implements three-layer CSRF defense:
   - Layer 1: isSameOrigin check → 403 if fails
   - Layer 2: Double-submit token comparison via cookie lg_csrf and header x-csrf-token
   - Layer 3: authed flag check → 401 if not authenticated
8. Returns Response object for blocked requests, null to allow

---

## Verification Command

```powershell
# Check security module exists:
Test-Path "src\lib\server\security.ts"

# Verify scrypt hashing is implemented:
Get-Content "src\lib\server\security.ts" | Select-String -Pattern "scrypt|timingSafeEqual"
```

---

## Expected Output

```powershell
# Security module should exist:
True

# Should find scrypt and timing-safe equal patterns:
Get-Content "src\lib\server\security.ts" | Select-String -Pattern "scrypt|timingSafeEqual"
```

---

## Success Criteria

- [ ] `src/lib/server/security.ts` exists
- [ ] Implements hashPassword() using scrypt with 16-byte salt, 64-byte key length
- [ ] Uses crypto.timingSafeEqual for timing-safe comparison
- [ ] Session token is deterministic: sha256('lg-session:' + passwordHash)
- [ ] Empty-hex reject fix prevents all-empty stored keys matching any password
