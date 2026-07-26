# Task 9.9-10.0: Design System, Service Worker & Verification

**Source**: `BUILD-FROM-SCRATCH.md` section 9 (`src/app.css`, manifest, service worker) and section 10 (build/run/verification scripts)

**Goal**: Verify design system entry point, PWA configuration, and build/run commands.

---

## Files to Check

| File | Path | Purpose |
|------|------|--------|
| app.css | `src/app.css` | Tailwind v4 design tokens + theme entry |
| manifest.webmanifest | `static/manifest.webmanifest` | PWA manifest file |
| service-worker.js | `static/service-worker.js` | Service worker for offline support |

---

## Verification Command

```powershell
# Verify app files exist:
Test-Path "src\app.css"
Test-Path "static\manifest.webmanifest"
Test-Path "static\service-worker.js"
```

**Run in Node to test Tailwind config:**
```powershell
node -e "
// Check if app.css has @theme declaration (Tailwind v4)
const fs = require('fs');
const cssContent = fs.readFileSync('./src/app.css', 'utf8');
if (cssContent.includes('@theme')) {
  console.log('✓ Tailwind v4 @theme found in app.css');
} else {
  console.log('✗ No @theme declaration found');
}
"
```

---

## Expected Output

### app.css (Tailwind v4 entry):
```css
@import 'tailwindcss';
@theme {
  --color-primary: #1a1c23;
  --color-accent: #6366f1;
  /* ... theme tokens */
}
```

### manifest.webmanifest exports:
```json
{
  "name": "LGallery",
  "short_name": "Gallery",
  "start_url": "/",
  "display_mode": "standalone",
  // ... PWA metadata
}
```

---

## Success Criteria

- [ ] `src/app.css` has Tailwind v4 @theme declaration
- [ ] manifest.webmanifest exists with proper PWA fields
- [ ] service-worker.js exists and is served at `/sw.js`
