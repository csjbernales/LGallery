# Task 1.3: Create Project Directory Structure

**Source**: `BUILD-FROM-SCRATCH.md` section 1.6 (Repository layout map)

**Goal**: Create all required directories for LGallery project structure.

---

## What to Create

### Top-level directories:

```
pkg.json, bun.lock          # Manifest + Bun lockfile
svelte.config.js, vite.config.ts, tsconfig.json  # Config files
start.mjs                  # Prod launcher: sets UV_THREADPOOL_SIZE, imports build/index.js
lgallery.config.example.json  # Seed config file (gitignored)
setup-lgallery.cmd/.ps1    # One-shot Windows installer
start-lgallery.cmd/.vbs    # Windows run/autostart launchers
token-usage.html           # Standalone utility at repo root
README.md, docs/           # Human documentation
.clau de/memory/            # Project status + key decisions memory notes
scripts/gen-fixtures.mjs   # Dev helper for sample library + config
```

### src/ internal layout:

| Path | Role |
|------|------|
| app.html, app.d.ts, ambient.d.ts, app.css | App shell, types, Tailwind v4 entry |
| routes/ | SvelteKit pages and API endpoints |
| lib/shared/ ($shared) | Isomorphic code: types, formatting, layout math, blurhash, edits, config schema |
| lib/server/ ($server) | Node-only server logic: db, config, paths, security, scan, media, geo, ai, http, lock, log |
| lib/client/ ($client) | Browser-only code: api wrappers, state stores |
| lib/components/ ($components) | Svelte 5 components: grid, lightbox, navigation, common elements |
```

### Tests live next to subjects as *.test.ts (e.g., layout.test.ts)

---

## Verification Commands

```powershell
# Create all directories at once
New-Item -ItemType Directory -Force -Path ".svelte-kit","data","static","src","docs"
New-Item -ItemType Directory -Force "scripts"

# src/ structure
New-Item -ItemType Directory -Force "src\app.html","src\routes","src\lib\shared"
New-Item -ItemType Directory -Force "src\lib\server","src\lib\client","src\lib\components"
New-Item -ItemType Directory -Force "src\app.d.ts","src\ambient.d.ts","src\hooks.server.ts"

# src/lib/server/ subdirectories
New-Item -ItemType Directory -Force "src\lib\server\db","src\lib\server\config"
New-Item -ItemType Directory -Force "src\lib\server\scan","src\lib\server\media"
New-Item -ItemType Directory -Force "src\lib\server\geo","src\lib\server\ai"

# src/lib/client/ subdirectories
New-Item -ItemType Directory -Force "src\lib\client\api","src\lib\client\state"

# src/routes/ structure
New-Item -ItemType Directory -Force "src\routes\timeline\+page.svelte"
New-Item -ItemType Directory -Force "src\routes\folders\+page.svelte"
New-Item -ItemType Directory -Force "src\routes\albums\+page.svelte"
New-Item -ItemType Directory -Force "src\routes\search\+page.svelte"
New-Item -ItemType Directory -Force "src\routes\map\+page.svelte"
New-Item -ItemType Directory -Force "src\routes\settings\+page.svelte"
New-Item -ItemType Directory -Force "src\routes\login\+page.svelte"
New-Item -ItemType Directory -Force "src\routes\api" (HTTP API routes)

# static/ assets
New-Item -ItemType Directory -Force "static\logo","static\favicon.svg"
New-Item -ItemType Directory -Force "static\manifest.webmanifest"
```

---

## Verification Command

```powershell
# Verify all directories were created
Test-Path ".svelte-kit"
Test-Path "data"
Test-Path "static"
Test-Path "src"
Test-Path "scripts"
Test-Path "src\lib\shared"
Test-Path "src\lib\server"
Test-Path "src\lib\client"
Test-Path "src\lib\components"
Test-Path "src\routes"
```

---

## Expected Output

All directories should exist and return `$true` for `Test-Path`:

```powershell
# Verification output (all true)
True
True
True
...
True
```

---

## Success Criteria

- [ ] All top-level directories created (`svelte-kit`, `data`, `static`, `src`, `docs`) 
- [ ] `scripts` directory exists
- [ ] `src/lib/shared/`, `src/lib/server/`, `src/lib/client/`, `src/lib/components/` exist
- [ ] Route structure directories created (timeline, folders, albums, search, map, settings, login)
- [ ] API routes directory at `src/routes/api/`
- [ ] Static assets directories (`logo`, `favicon.svg`) present
