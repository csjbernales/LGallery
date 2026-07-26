# Task 13.1: Create App HTML Template

**Source**: `BUILD-FROM-SCRATCH.md` section 13 (App shell)

**Goal**: Verify app.html sets UV_THREADPOOL_SIZE in head before importing build/index.js.

---

## What to Check

### 13.2: Create src/app.html

```html
<!-- Should set UV_THREADPOOL_SIZE, then import adapter-node build -->
<svelte:options tag="page" />
```

**Verify these properties:**
1. Uses `<svelte:options tag="page">` for server rendering in SvelteKit
2. Sets `process.env.UV_THREADPOOL_SIZE` before importing adapter-node build
3. Dynamically imports adapter-node build via top-level await
4. Includes proper meta tags (viewport, description)
5. Tailwind CSS v4 directives: `<script>import ... from "tailwindcss"; tailwind.config = { corePlugins: { preflight: false } }; </script>`
6. No external CDN dependencies except OpenStreetMap tiles
7. Handles errors gracefully without crashing server
8. Uses proper error handling and logging via log module
9. Server renders `app.d.ts` at compile time for type inference in forms
10. Tailwind v4 configuration with preflight disabled and custom colors/fonts

---

## Verification Command

```powershell
# Check app.html exists:
Test-Path "src\app.html"
```

---

## Expected Output

```html
<!-- Sample code structure: -->
<svelte:options tag="page" />
<script>
  const uv = await import('uvu');
  uv.uvSetDefaultThreadPools(process.env.UV_THREADPOOL_SIZE || 8);
  await import('./build/index.js'); // adapter-node build here
</script>
<!doctype html> ... <html lang="en"> ... </html>
```

---

## Success Criteria

- [ ] `src/app.html` exists
- [ ] Sets UV_THREADPOOL_SIZE = max(8, cpuCount * 2) before importing build
- [ ] Dynamically imports adapter-node build: await import('./build/index.js')
