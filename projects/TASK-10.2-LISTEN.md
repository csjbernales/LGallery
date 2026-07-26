# Task 10.2: Create Login Page

**Source**: `BUILD-FROM-SCRATCH.md` section 10 (Settings UI)

**Goal**: Verify the login page handles authentication with proper form validation and error messages.

---

## What to Check

### 10.3: Create /login Page

```svelte
<!-- Should show username/password inputs for authentication -->
<svelte:options tag="page" />
<script>
  // Form state, login button handler calling /login endpoint
</script>
```

**Verify these properties:**
1. Uses `app.d.ts` type declaration for server-rendered input types in forms
2. Form fields map to username and password
3. Handles login success redirect (to timeline or dashboard)
4. Shows validation errors inline for invalid inputs
5. Provides clear instructions and field descriptions
6. Handles loading state while submitting (indeterminate progress indicator)
7. Uses `apiError` helper from http.ts for error responses
8. Error handling with proper logging via log module
9. Prevents double-submission on button click (disabled during submit)
10. Redirects to timeline page after successful login

---

## Verification Command

```powershell
# Check login page exists:
Test-Path "src\routes\login\+page.svelte"
```

---

## Expected Output

```svelte
<!-- Sample form structure: -->
<form>
  <label>Username</label>
  <input type="text" name="username" />
  
  <label>Password</label>
  <input type="password" name="password" />
  
  <button type="submit">Login</button>
</form>
```

---

## Success Criteria

- [ ] `src/routes/login/+page.svelte` exists
- [ ] Form validates against zod schema before submit
- [ ] Uses Zod error handling with .error.issues from zod v3
- [ ] Redirects to timeline page after successful login
