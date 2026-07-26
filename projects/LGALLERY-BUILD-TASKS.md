# LGallery Build Tasks

**Source**: `BUILD-FROM-SCRATCH.md` at `C:\Users\Clark\.config\opencode\projects\BUILD-FROM-SCRATCH.md`

**Goal**: Reproduce the LGallery app byte-exact from repository commit `f32f74b`. SvelteKit + Bun tooling with Node server runtime.

---

## 1. Overview, Goal, Environment & Golden Rules

### Task 1.1: Understand Requirements and Golden Rules
- [ ] Read BUILD-FROM-SCRATCH.md sections 1.1-1.5 completely
- [ ] Note the golden rules that must be followed for exact reproduction:
  - Bun builds, Node serves (production runs on Node due to better-sqlite3 native module)
  - `zod` pinned to v3 — upgrading breaks config schema defaults
  - DB migrations are append-only, never edit shipped ones
  - Privacy invariant: only OpenStreetMap tiles, optional AI model download, and Nominatim reverse-geocoding use network
  - Canonical root paths via `fs.realpathSync.native` for Windows 8.3 short name expansion

### Task 1.2: Verify Environment Requirements
- [ ] Check Bun version: must be >= 1.3.0 (pin to 1.3.14 for lockfile match)
  ```powershell
  bun -v
  ```
- [ ] Check Node.js LTS is installed (required for production server via `node start.mjs`)
  ```powershell
  node -v
  npm --version
  ```
- [ ] Confirm running OS: primarily Windows Server 2025 / Windows 10/11 with first-class Windows extras

### Task 1.3: Create Project Directory Structure
- [ ] Create `lgallery` project root directory
- [ ] Verify all directories from Appendix A layout map exist:
  ```powershell
  # Top-level structure
  New-Item -ItemType Directory -Force -Path "package.json","bun.lock","svelte.config.js"
  New-Item -ItemType Directory -Force -Path ".svelte-kit" "data" "static" "src" "docs"
  New-Item -ItemType Directory -Force -Path "scripts"

  # src/ structure
  New-Item -ItemType Directory -Force -Path "src\app.html","src\routes","src\lib\shared"
  New-Item -ItemType Directory -Force -Path "src\lib\server","src\lib\client","src\lib\components"
  New-Item -ItemType Directory -Force -Path "src\app.d.ts","src\ambient.d.ts","src\hooks.server.ts"

  # src/lib/server/ subdirectories
  New-Item -ItemType Directory -Force -Path "src\lib\server\db","src\lib\server\config"
  New-Item -ItemType Directory -Force -Path "src\lib\server\scan","src\lib\server\media"
  New-Item -ItemType Directory -Force -Path "src\lib\server\geo","src\lib\server\ai"

  # src/lib/client/ subdirectories
  New-Item -ItemType Directory -Force -Path "src\lib\client\api","src\lib\client\state"

  # src/routes/ structure
  New-Item -ItemType Directory -Force -Path "src\routes\timeline\+page.svelte"
  New-Item -ItemType Directory -Force -Path "src\routes\folders\+page.svelte"
  New-Item -ItemType Directory -Force -Path "src\routes\albums\+page.svelte"
  New-Item -ItemType Directory -Force -Path "src\routes\search\+page.svelte"
  New-Item -ItemType Directory -Force -Path "src\routes\map\+page.svelte"
  New-Item -ItemType Directory -Force -Path "src\routes\settings\+page.svelte"
  New-Item -ItemType Directory -Force -Path "src\routes\login\+page.svelte"
  New-Item -ItemType Directory -Force -Path "src\routes\api" (HTTP API routes)

  # static/ assets
  New-Item -ItemType Directory -Force -Path "static\logo","static\favicon.svg"
  New-Item -ItemType Directory -Force -Path "static\manifest.webmanifest"
  ```

---

## 2. Toolchain, Scaffold & Project Configuration

### Task 2.1: Install Bun (Exact Version 1.3.14)
- [ ] Download Bun installer for current OS architecture:
  - Windows x64: `bun-windows-x64-1.3.14.exe`
  - macOS x64: `bun-darwin-x64-1.3.14.tar.gz` or `.zip`
  - Linux x64: `bun-linux-x64-1.3.14.tar.xz`
- [ ] Install Bun to default path (no need to create custom PATH entry)
  ```powershell
  # Windows installation example
  $installerPath = "C:\Users\Clark\Downloads\bun-windows-x64-1.3.14.exe"
  Start-Process -FilePath $installerPath -ArgumentList "--quiet" -Wait
  ```
- [ ] Verify Bun version after install
  ```powershell
  bun -v
  # Expected output: 1.3.14 (or >= 1.3.0)
  ```

### Task 2.2: Install Node.js LTS
- [ ] Download and install current Node.js LTS from https://nodejs.org
- [ ] Verify Node and npm versions:
  ```powershell
  node -v
  # Expected: >= 20.x (Node 20+ satisfies @types/node ^25.9.3)
  ```
- [ ] Verify npm works:
  ```powershell
  npm --version
  ```

### Task 2.3: Create Root Configuration Files
- [ ] Copy `lgallery.config.example.json` to `lgallery.config.json`
  ```powershell
  Copy-Item "lgallery.config.example.json" -Destination ".\lgallery.config.json"
  ```
- [ ] Verify the copied config has correct indentation (2-space indent)
- [ ] Read `package.json` and verify all top-level fields match exactly:
  ```powershell
  # Should show: name=lgallery, version=0.1.0, private=true, type="module"
  Get-Content ".\package.json" | Format-HighString -Width 256
  ```
- [ ] Verify `svelte.config.js` has correct adapter-node with precompress:
  ```powershell
  # Key values to verify:
  # kit.adapter = { type: "node", precompress: true }
  Get-Content ".\svelte.config.js"
  ```
- [ ] Verify `vite.config.ts` has correct plugins order (tailwindcss before sveltekit):
  ```powershell
  # Should show: plugins: [tailwindcss(), sveltekit()]
  Get-Content ".\vite.config.ts"
  ```
- [ ] Verify `tsconfig.json` extends `.svelte-kit/tsconfig.json`:
  ```powershell
  # compilerOptions should include:
  # "allowJs": true, "checkJs": true
  Get-Content ".\tsconfig.json"
  ```
- [ ] Verify `.gitignore` includes proper exclusions for `data/` and `lgallery.config.json`
  ```powershell
  Get-Content ".\gitignore" | Select-String -Pattern "^data|^lgallery\.config"
  ```

### Task 2.4: Install Dependencies with Bun (Lockfile Version 1)
- [ ] Run `bun install` to resolve dependencies against committed `bun.lock`
  ```powershell
  cd .
  bun install
  ```
- [ ] Verify lockfile was created/updated:
  ```powershell
  Get-Item "bun.lock" | Select-Object -ExpandProperty Length
  # Should exist with content (lockfileVersion: 1)
  ```
- [ ] Run `svelte-kit sync` to generate `.svelte-kit/tsconfig.json`
  ```powershell
  bun run svelte-kit sync
  ```

---

## 3. Configuration & Data Model

### Task 3.1: Verify Zod Schema Configuration
- [ ] Read `src/lib/shared/config-schema.ts` and verify:
  - No node imports (isomorphic config validator)
  - Uses zod v3 idioms (`.default({})`, `.safeParse`, `.error.issues`)
  - Contains correct default values matching BUILD-FROM-SCRATCH.md
  ```powershell
  Get-Content "src\lib\shared\config-schema.ts"
  ```
- [ ] Verify `extensions()` helper lowercases and strips leading dot:
  ```typescript
  // Should transform: ".JPG" → "jpg", "jpg" → "jpg"
  const extensions = (def) => z.array(z.string()).default(def)
    .transform((arr) => [...new Set(arr.map(e => e.toLowerCase().replace(/^\./, '')))]);
  ```

### Task 3.2: Create Database Schema Migrations
- [ ] Read `src/lib/server/db/schema.ts` and verify migration array:
  - Contains MIGRATIONS array with TARGET_SCHEMA_VERSION = 6
  - v1 core-schema includes all base tables (media, roots, albums, etc.)
  - v2 adds idx_media_day index
  - v3 adds retry-attempts columns
  - v4 adds organize fields and recreates FTS5 triggers
  ```powershell
  Get-Content "src\lib\server\db\schema.ts"
  ```
- [ ] Verify migration version tracking via `app_state.schema_version` column
- [ ] Check that migrations use transactions for atomic updates

### Task 3.3: Create Database Instance File
- [ ] Read/verify `src/lib/server/db/index.ts`: 
  - DB_PATH = cwd/data/lgallery.db
  - Uses WAL journal mode
  - Sets PRAGMA cache_size = -65536 (~64MB)
  - Applies all migration functions in order
  ```powershell
  Get-Content "src\lib\server\db\index.ts"
  ```
- [ ] Verify database gets created at `data/lgallery.db` on first run
- [ ] Run migrations by initializing the database:
  ```powershell
  # Will create data/ directory and lgallery.db file
  bun run build
  ```

---

## 4. Server Foundation & Shared Libraries

### Task 4.1: Create Path Safety Module
- [ ] Read `src/lib/server/paths.ts` and verify:
  - Implements `normalizePath()` with UNC detection and drive-letter lowercasing
  - Implements `isWithin(child, parent)` for traversal guards
  - Uses `fs.realpathSync.native` for Windows 8.3 short name expansion
  ```powershell
  Get-Content "src\lib\server\paths.ts"
  ```
- [ ] Verify UNC path handling preserves double slashes before resolve
- [ ] Test normalizePath function manually:
  ```powershell
  # PowerShell test for normalizePath logic:
  $path = "C:\Users\Clark\Documents\Photos"
  # Should return: c:/users/clark/documents/photos
  ```

### Task 4.2: Create Security Module
- [ ] Read `src/lib/server/security.ts` and verify:
  - Implements `hashPassword()` using scrypt with 16-byte random salt
  - Uses `crypto.timingSafeEqual` for password verification
  - Implements session token generation via deterministic hash
  ```powershell
  Get-Content "src\lib\server\security.ts"
  ```
- [ ] Verify password storage uses format: `scrypt$<saltHex>$<hashHex>`
- [ ] Test hash/verify round-trip:
  ```powershell
  # Manual test (requires node environment)
  bun -e "import('./src/lib/server/security').then(m => { const p = 'test123'; console.log(m.hashPassword(p)); })"
  ```

### Task 4.3: Create Lock Module
- [ ] Read `src/lib/server/lock.ts` and verify:
  - Implements single-process FIFO mutex via `let chain`
  - Uses promise chaining for non-blocking acquisition
  - Handles rejection gracefully without breaking the chain
  ```powershell
  Get-Content "src\lib\server\lock.ts"
  ```
- [ ] Verify lock pattern: `chain.then(fn, fn)` runs function on both success and failure

### Task 4.4: Create Logging Module
- [ ] Read `src/lib/server/log.ts` and verify:
  - Supports debug/info/warn/error levels with minOrder calculation
  - Rotates log files when exceeding maxSizeMb (default 10MB)
  - Writes to `data/lgallery.log`
  ```powershell
  Get-Content "src\lib\server\log.ts"
  ```
- [ ] Verify maxFiles = 5 limit for rotated logs

### Task 4.5: Create HTTP Helpers Module
- [ ] Read `src/lib/server/http.ts` and verify:
  - `initialGridWidth()` reads viewport width cookie
  - `apiError(status, code, message)` returns consistent error envelope
  ```powershell
  Get-Content "src\lib\server\http.ts"
  ```
- [ ] Verify error response matches `App.Error` shape: `{ code?: string; message: string }`

### Task 4.6: Create Startup Module
- [ ] Read `src/lib/server/startup.ts` and verify:
  - Idempotent bootstrap that can run on first request
  - Sets UV_THREADPOOL_SIZE before importing build
  - Dynamically imports adapter-node build
  ```powershell
  Get-Content "src\lib\server\startup.ts"
  ```
- [ ] Verify startup sets `UV_THREADPOOL_SIZE = max(8, cpuCount * 2)`

---

## 5. Scan Subsystem

### Task 5.1: Create Walker Module
- [ ] Read walker implementation and verify:
  - Traverses configured root directories
  - Handles Windows path edge cases correctly
  ```powershell
  Get-Content "src\lib\server\scan/walker.ts"
  ```

### Task 5.2: Create Scanner Module
- [ ] Read scanner implementation and verify:
  - Filters files by extensions (image/video)
  - Applies include/exclude patterns from config
  ```powershell
  Get-Content "src\lib\server\scan/scanner.ts"
  ```

### Task 5.3: Create Differ Module
- [ ] Read differ implementation and verify:
  - Compares existing DB records with found files
  - Identifies new/updated/deleted files for rescan
  ```powershell
  Get-Content "src\lib\server\scan/differ.ts"
  ```

### Task 5.4: Create Scan State Module
- [ ] Read scan state implementation and verify:
  - Tracks progress per root directory
  - Manages retry attempts for failed files
  ```powershell
  Get-Content "src\lib\server\scan/scanState.ts"
  ```

### Task 5.5: Create Watcher Module
- [ ] Read watcher implementation and verify:
  - Uses chokidar for filesystem watching
  - Triggers rescan on config changes or file modifications
  ```powershell
  Get-Content "src\lib\server\scan/watcher.ts"
  ```

---

## 6. Media Pipeline & Worker Thread Pool

### Task 6.1: Create Thumbnail Worker Module
- [ ] Read `thumb-worker.mjs` and verify:
  - Uses libuv thread pool for parallel thumbnail generation
  - Processes WebP output format
  ```powershell
  Get-Content "src\lib\server\media\thumb-worker.mjs"
  ```
- [ ] Verify worker uses sharp library with correct parameters

### Task 6.2: Create Render Core Module
- [ ] Read `render-core.mjs` and verify:
  - Handles both images and video rendering
  - Supports storyboarding (video frames at configurable intervals)
  ```powershell
  Get-Content "src\lib\server\media\render-core.mjs"
  ```

### Task 6.3: Create Worker Pool Module
- [ ] Read worker pool implementation and verify:
  - Spawns N concurrent workers based on config (`workerCount` or cores-1)
  - Manages worker lifecycle (start, shutdown)
  ```powershell
  Get-Content "src\lib\server\media\workerPool.ts"
  ```

### Task 6.4: Create Thumbnail Service Module
- [ ] Read thumbnail service implementation and verify:
  - Generates grid thumbnails at `longEdge` resolution with quality setting
  - Generates preview thumbnails at `1600px` long edge
- [ ] Verify default values match schema defaults

---

## 7. Read Queries & HTTP/API Surface

### Task 7.1: Create API Routes Directory Structure
- [ ] Set up route structure:
  ```powershell
  New-Item -ItemType Directory -Force "src\routes\api\media\+server.ts"
  New-Item -ItemType Directory -Force "src\routes\api\timeline\+server.ts"
  New-Item -ItemType Directory -Force "src\routes\api\config\+server.ts"
  ```

### Task 7.2: Implement Media API Endpoint
- [ ] Create `GET /api/media` endpoint that returns media list:
  - Supports pagination with keyset (cursor) for large datasets
  - Returns fields relevant to UI rendering
  ```powershell
  # Should return JSON array of media objects
  ```
- [ ] Implement filtering by root, type, tags
- [ ] Add search endpoint: `GET /api/media/search`

### Task 7.3: Implement Timeline API Endpoint
- [ ] Create `GET /api/timeline` endpoint:
  - Returns date-bucketed media grouped by day/week/month
  - Aggregates counts for scrollbar rendering
  ```powershell
  # Should return array of { date: "2026-07-25", count: N, items: [...] }
  ```

### Task 7.4: Implement Config API Endpoint
- [ ] Create `GET /api/config` endpoint:
  - Returns client-safe config (strips server.password)
  - Uses `clientConfig()` method from configService
  ```powershell
  # Should return redacted config object without password fields
  ```

---

## 8. Places/Geocoding & Optional AI

### Task 8.1: Create Offline Cities Module
- [ ] Read offline cities implementation and verify:
  - Stores city names by latitude/longitude for reverse geocoding
  - Used when map is open but no network available
  ```powershell
  Get-Content "src\lib\server\geo/offlineCities.ts"
  ```

### Task 8.2: Create Geocode Service Module
- [ ] Read geocode service implementation and verify:
  - Supports both offline mode and Nominatim API
  - Implements throttling for Nominatim (≤1 req/s)
  ```powershell
  Get-Content "src\lib\server\geo/geocodeService.ts"
  ```

### Task 8.3: Create Optional AI Import Helper
- [ ] Read `optional.ts` in `ai/` directory and verify:
  - Uses dynamic import() to conditionally load AI modules
  - Handles missing @huggingface/transformers gracefully
  - Marks packages as ssr.external in vite.config.ts
  ```powershell
  Get-Content "src\lib\server\ai\optional.ts"
  ```

---

## 9. Client State, Components & Design System

### Task 9.1: Create API Client Module
- [ ] Read `src/lib/client/api.ts` and verify:
  - Wraps fetch calls to `/api/*` endpoints
  - Handles authentication via cookies
  ```powershell
  Get-Content "src\lib\client\api.ts"
  ```

### Task 9.2: Create Client State Stores
- [ ] Read state stores in `src/lib/client/state/` and verify:
  - Gallery store with `$state` runes
  - Selection store for lightbox
  - Settings store for user preferences
  ```powershell
  Get-Content "src\lib\client\state\gallery.svelte.ts"
  ```

### Task 9.3: Create Grid Components
- [ ] Read timeline grid component and verify:
  - Uses justified grid layout (TimelineGrid)
  - Renders media tiles with blurhash placeholders
  ```powershell
  Get-Content "src\lib\components\grid\TimelineGrid.svelte"
  ```

### Task 9.4: Create Lightbox Component
- [ ] Read lightbox component and verify:
  - Shows fullscreen image/video
  - Supports zoom/pan for images
  - Supports slideshow mode
  - Non-destructive editing overlay
  ```powershell
  Get-Content "src\lib\components\lightbox\Lightbox.svelte"
  ```

---

## 10. Scripts, Build, Run, Verification & Tests

### Task 10.1: Create Test Files for Server Modules
- [ ] Add test file for paths module:
  ```powershell
  New-Item -ItemType File "src\lib\server\paths.test.ts"
  # Test normalizePath, isWithin functions
  ```
- [ ] Add test file for security module:
  ```powershell
  New-Item -ItemType File "src\lib\server\security.test.ts"
  # Test hashPassword, verifyPassword functions
  ```
- [ ] Add test file for configService:
  ```powershell
  New-Item -ItemType File "src\lib\server\config\configService.test.ts"
  ```

### Task 10.2: Create Build Script Verification
- [ ] Run `bun run build` and verify output exists:
  ```powershell
  bun run build
  # Should create build/ directory with index.js and precompressed files
  Test-Path "build\index.js"
  ```
- [ ] Verify adapter-node created standalone Node server files
- [ ] Verify precompress emitted `.br` and `.gz` variants

### Task 10.3: Run Development Server
- [ ] Start dev server:
  ```powershell
  bun run dev
  # Should start on http://localhost:5173
  ```
- [ ] Verify server starts without errors
- [ ] Access browser and verify UI renders correctly
- [ ] Test login flow (password required or open if no password set)

### Task 10.4: Run Production Server
- [ ] Build the app first:
  ```powershell
  bun run build
  ```
- [ ] Start production server with threadpool size set:
  ```powershell
  # Note: start.mjs already sets UV_THREADPOOL_SIZE internally
  bun run start
  # Should start on http://127.0.0.1:4173 or PORT environment variable value
  ```
- [ ] Verify server is responding via curl:
  ```powershell
  curl http://localhost:4173
  # Should return HTML with lgallery branding
  ```
- [ ] Test config endpoint returns correct data structure

### Task 10.5: Run Full Test Suite
- [ ] Run all tests:
  ```powershell
  bun run test
  # Should pass all 98 → 128 tests
  ```
- [ ] Verify no test failures with red exit code
- [ ] Generate coverage report if needed:
  ```powershell
  bun run test:cov
  ```

### Task 10.6: Verify Type Checking
- [ ] Run type checker:
  ```powershell
  bun run check
  # Should find no errors (exit code 0)
  ```
- [ ] Verify `.svelte-kit/tsconfig.json` was generated by svelte-kit sync

### Task 10.7: Final Verification Checklist
- [ ] App builds successfully with `bun run build`
- [ ] Production server starts via `bun run start`
- [ ] Login works (password required unless explicitly disabled)
- [ ] Timeline view renders correctly
- [ ] Search functionality works
- [ ] Lightbox displays images/videos
- [ ] Config endpoint returns expected structure

---

## Appendix A: File Verification Commands Reference

Use these commands to verify specific files exist:

```powershell
# Core configuration files
Test-Path ".\package.json"
Test-Path ".\bun.lock"
Test-Path ".\svelte.config.js"
Test-Path "src\app.html"
Test-Path "start.mjs"

# Server modules
Test-Path "src\lib\server\paths.ts"
Test-Path "src\lib\server\security.ts"
Test-Path "src\lib\server\startup.ts"
Test-Path "src\lib\server\db\index.ts"

# Shared libraries
Test-Path "src\lib\shared\config-schema.ts"
Test-Path "src\lib\shared\types.ts"

# Client modules
Test-Path "src\lib\client\api.ts"
```

---

## Notes for Verification

1. **Golden Rule 1**: Production always runs `node start.mjs` NOT `bun build/index.js` due to better-sqlite3 native module incompatibility with Bun runtime.

2. **UV_THREADPOOL_SIZE** MUST be set before importing the Node server (done by `start.mjs`), as libuv reads this value once at initialization.

3. **Zod v3** is required — upgrading to zod 4 breaks config schema defaults pattern (`z.object({...}).default({})`).

4. **Database migrations are append-only** — never edit shipped migrations, only create new versions.

5. **Path canonicalization via `fs.realpathSync.native`** is critical for Windows 8.3 short name handling.
