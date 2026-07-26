# Task 7.4: Implement Config API Endpoint

**Source**: `BUILD-FROM-SCRATCH.md` section 7 (Read queries & HTTP/API surface)

**Goal**: Verify the config API endpoint serves current and default configuration.

---

## What to Check

### 7.5: Create GET /api/config Endpoint

```typescript
// Two endpoints:
GET /api/config              // Returns current loaded config (lgallery.config.json)
GET /api/config/default      // Returns schema defaults from zod
```

**Verify these properties:**
1. GET /api/config returns all values from `lgallery.config.json`
2. GET /api/config/default returns `schema.parse()` results for MINIMAL_CONFIG_HINT fields
3. Returns proper HTTP status codes (200 OK)
4. Uses json() helper from @sveltejs/kit with correct content-type headers
5. Handles missing config file gracefully (returns defaults or 404?)
6. Error handling with ApiErrorBody shape on failure
7. Supports GET /api/config for login page to pre-fill form fields
8. Server renders `app.d.ts` at compile time for type inference in forms
9. Config is read from `$env.staticConfig` or file path stored in db (if migrated)
10. Default values match zod schema defaults from src/lib/shared/config-schema.ts

---

## Verification Command

```powershell
# Check config API endpoint exists:
Test-Path "src\routes\config\+server.ts"
```

---

## Expected Output

```typescript
// Sample response structure (current config):
{
  roots: [
    { path: string, label: string, enabled: boolean }
  ],
  include: string[],
  exclude: string[],
  imageExtensions: string[],
  videoExtensions: string[],
  ...
}

// Default response structure:
{
  roots: [{ path: '', label: 'All media', enabled: true }],
  include: ['**/*'],
  exclude: [...],
  imageExtensions: [...],
  videoExtensions: [...],
  scan: { onStartup: true, rescanOnReload: true, watch: false },
  ...
}
```

---

## Success Criteria

- [ ] `src/routes/config/+server.ts` exists
- [ ] GET /api/config returns all values from lgallery.config.json
- [ ] GET /api/config/default returns zod schema defaults for MINIMAL_CONFIG_HINT fields
