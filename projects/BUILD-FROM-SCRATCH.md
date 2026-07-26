# LGallery — Build From Scratch

> Single-file, end-to-end recipe to reproduce the **LGallery** app **exactly** (from repository commit `f32f74b`).
> LGallery is a fully local, private, "Google-Photos"-style photo/video gallery (SvelteKit + Bun tooling, Node server).
>
> **How this document is organized**
> - **Part 1 — Build instructions** (§1–§10): the ordered recipe — environment, scaffold, data model, every subsystem, build/run/verify, and the decisions & gotchas you must honor.
> - **Appendix A — Verbatim source**: the byte-exact contents of all **188** tracked files. This is the ground truth — create each file at its heading path with the block beneath it.
> - **Appendix B — Coverage & review notes**: an automated completeness check of this guide against the file list.
>
> **Fastest faithful reproduction:** materialize every file from **Appendix A** at its path, then follow **§2** (install Bun + Node, `bun install`, `bun run build`) and **§10** (verify). The §1.5 *golden rules* are load-bearing — skipping any yields an app that builds but behaves differently.

## Table of contents

- [1. Overview, goal, environment & golden rules](#1-overview-goal-environment--golden-rules)
- [2. Toolchain, scaffold & project configuration](#2-toolchain-scaffold--project-configuration)
- [3. Configuration & data model](#3-configuration--data-model)
- [4. Server foundation & shared libraries](#4-server-foundation--shared-libraries)
- [5. Scan subsystem](#5-scan-subsystem)
- [6. Media pipeline, worker-thread pool & media services](#6-media-pipeline-worker-thread-pool--media-services)
- [7. Read queries & the complete HTTP/API surface](#7-read-queries--the-complete-httpapi-surface)
- [8. Places/geocoding, optional on-device AI & map](#8-placesgeocoding-optional-on-device-ai--map)
- [9. Client state, components, pages & design system](#9-client-state-components-pages--design-system)
- [10. Scripts, build, run, verification, tests & decisions/gotchas catalog](#10-scripts-build-run-verification-tests--decisionsgotchas-catalog)
- [Appendix A — Verbatim source of all files](#appendix-a--verbatim-source-of-all-files)
- [Appendix B — Coverage & review notes](#appendix-b--coverage--review-notes)

## 1. Overview, goal, environment & golden rules

### 1.1 What LGallery is

LGallery is a **local, self-hosted, "Google Photos"-style media gallery** that runs entirely on the owner's own machine. It indexes the images and videos found in one or more folders ("roots") that the user chooses, and presents them as a fast, responsive, private gallery: a date **timeline** (justified grid), **albums**, **folder** browser, full-text **search** with filters, a Leaflet **map** of geotagged media, a fullscreen **lightbox** (zoom/pan, video, slideshow, non-destructive editing), **favorites/archive/trash**, **memories** ("On this day"), **duplicate** detection, Live/Motion photo pairing, **places** (offline or opt-in reverse-geocoding), and optional **on-device AI** (CLIP semantic search + face grouping).

The defining product constraint is **privacy**: there is no account, no upload, no cloud backend, no CDN, no analytics, and no telemetry. Media files never leave the machine. The app is built to scale to **50,000–200,000+** items via a SQLite index, an on-disk thumbnail cache, background/resumable scanning and thumbnailing, keyset (cursor) pagination, and custom dependency-free virtualized scrolling.

`package.json` describes it exactly: *"A local, self-hosted Google-Photos-style gallery built with SvelteKit + Bun. Fully private, no cloud, no telemetry."* Implemented status is phases **P0–P9** of `docs/10-BUILD-PLAN.md` plus three enhancement passes (Bun/UX, 200k-scale, organize/places/editing). AI (P8) is scaffolded but **OFF by default** and requires two optional packages.

### 1.2 Goal of this document

The single goal of **BUILD-FROM-SCRATCH.md** is: *following it reproduces the LGallery app EXACTLY.* It is the authoritative, ordered, end-to-end build recipe. It tells a rebuilder the precise **build order**, each file's **responsibility**, the key **signatures / SQL / config values / algorithms**, the **exact dependency versions and commands**, and — most importantly — the **non-obvious decisions and gotchas** that must be honored to get *this* exact app (not merely "a gallery"). It deliberately does **not** paste whole files; the byte-exact contents of all 188 tracked files live in a separate **Appendix A — Verbatim Source**.

### 1.3 How to use this document (two tracks)

- **Track (a) — human or agent follows the phased instructions.** Read this master file top-to-bottom. At each phase, create the files in the stated order, and for each file paste its byte-exact contents from **Appendix A — Verbatim Source** rather than retyping. Use the prose here to understand *why* each file is shaped the way it is, to run the exact commands, and to verify at each phase boundary (`bun run check`, `bun run test`, production build).
- **Track (b) — hand the whole file to a coding agent.** The entire master file (this section through the appendix) is self-contained: an agent can be given the file and asked to materialize the repository. Because the build order, dependency versions, commands, and gotchas are all explicit, and Appendix A carries verbatim source, an agent does not need network access to the original repo to reproduce it.

In both tracks the **golden rules** in §1.5 are load-bearing: skipping any of them yields an app that builds but does not behave identically.

### 1.4 Exact environment & toolchain

Read from `package.json`:

- **`"type": "module"`** — the whole project is ESM. `.mjs` files (e.g. `start.mjs`, `thumb-worker.mjs`, `render-core.mjs`, `scripts/gen-fixtures.mjs`) are plain ES modules; there is no CommonJS.
- **`"packageManager": "bun@1.3.14"`** — Bun 1.3.14 is the pinned package manager / script runner / build driver. Lockfile is `bun.lock` (Bun's text lockfile).
- **`"engines": { "bun": ">=1.3.0" }"`** — requires Bun ≥ 1.3.0.
- **`"private": true`**, name `lgallery`, version `0.1.0`.
- **`"overrides": { "cookie": "^0.7.2" }"`** — forces a non-vulnerable `cookie` to clear a SvelteKit advisory; keep this override.

**OS target:** primarily **Windows** (Windows Server 2025 / Windows 10/11), with first-class Windows extras — `setup-lgallery.cmd`/`.ps1` one-shot installer (winget + official fallbacks for Git/Bun/Node), `start-lgallery.cmd`, and `start-lgallery-hidden.vbs` autostart launchers, and Settings → "Start on Windows login". It is also **runnable on POSIX** (macOS/Linux) — nothing in the app code is Windows-only except the convenience launchers and the 8.3-short-name handling (which is a harmless no-op elsewhere).

**Runtime split (critical, see Golden Rule 1):** development uses `vite dev`, build uses `vite build`, tests use `vitest` — all of which execute on **Node under the hood** even when invoked via `bun run`. The **production server runs on Node**, launched as `node start.mjs` (which sets `UV_THREADPOOL_SIZE` then `import('./build/index.js')`), or directly `node build`.

**Scripts (`package.json`):**

| script | command |
|---|---|
| `dev` | `vite dev` (http://localhost:5173) |
| `build` | `vite build` (adapter-node → `build/`) |
| `preview` | `vite preview` |
| `start` | `node start.mjs` (prod; honors `PORT`/`HOST`, default 4173/127.0.0.1) |
| `check` | `svelte-kit sync && svelte-check --tsconfig ./tsconfig.json` |
| `check:watch` | same, `--watch` |
| `test` | `vitest run` (98 → 128 tests) |
| `test:cov` | `vitest run --coverage` (v8) |
| `test:watch` | `vitest` |

**Exact dependency versions** (do not float these — they were chosen as the latest non-vulnerable set and some are pinned for correctness):

*dependencies:* `archiver ^8.0.0` (ESM `ZipArchive` class — v8 dropped the vending fn), `better-sqlite3 ^12.11.1`, `blurhash ^2.0.5`, `chokidar ^5.0.0`, `exifr ^7.1.3`, `ffmpeg-static ^5.3.0`, `ffprobe-static ^3.1.0`, `fluent-ffmpeg ^2.1.3`, `leaflet ^1.9.4`, `leaflet.markercluster ^1.5.3`, `sharp ^0.35.1`, **`zod ^3.25.76`** (see Golden Rule 2).

*devDependencies:* `@lucide/svelte ^1.20.0`, `@sveltejs/adapter-node ^5.5.4`, `@sveltejs/kit ^2.65.2`, `@sveltejs/vite-plugin-svelte ^7.1.2`, `@tailwindcss/vite ^4.3.1`, `@types/archiver ^8.0.0`, `@types/better-sqlite3 ^7.6.13`, `@types/fluent-ffmpeg ^2.1.28`, `@types/leaflet ^1.9.21`, `@types/leaflet.markercluster ^1.5.6`, `@types/node ^25.9.3`, `@vitest/coverage-v8 ^4.1.9`, `svelte ^5.56.3`, `svelte-check ^4.6.0`, `tailwindcss ^4.3.1`, `typescript ^6.0.3`, `vite ^8.0.16`, `vitest ^4.1.9`.

*optional (AI, NOT installed by default):* `@huggingface/transformers`, `sqlite-vec` — added only via `bun add @huggingface/transformers sqlite-vec` when AI is enabled. The build stays green without them because the code uses an `optionalImport` helper (`src/lib/server/ai/optional.ts`).

**SvelteKit config (`svelte.config.js`):**
- `preprocess: vitePreprocess()`.
- Adapter: `@sveltejs/adapter-node` with **`precompress: true`** (serves prebuilt `.br`/`.gz` for the app shell + static files).
- Path aliases: **`$shared` → `src/lib/shared`**, **`$server` → `src/lib/server`**, **`$client` → `src/lib/client`**, **`$components` → `src/lib/components`**.
- `compilerOptions.runes: true` — **Svelte 5 runes mode is mandatory** (`$state`/`$derived`/`$props`, no legacy reactivity).

### 1.5 GOLDEN RULES (honor these or the app won't match)

1. **Bun builds, Node serves.** Bun is the package manager, script runner, and bundler driver, but the **server process must run on Node** (`node start.mjs` → `import('./build/index.js')`, equivalently `node build`). Reason: **`better-sqlite3` (a native module) is unsupported in the Bun runtime** (Bun #4290). `bun run dev|build|test` work only because Vite/Vitest themselves execute on Node. Never try to `bun build/index.js` the production server. `start.mjs` additionally sets `UV_THREADPOOL_SIZE = max(8, cpuCount*2)` **before** importing the build, because sharp/ffmpeg dispatch to the libuv threadpool whose size is read once at first init — setting it later is a no-op, which is the entire reason the thin launcher exists.

2. **`zod` is pinned to v3** (`^3.25.76`). **Do not upgrade to zod 4** — zod 4 breaks the `.object({...}).default({})` typing pattern that the config schema (`src/lib/shared/config-schema.ts`) relies on for nested defaults. The whole config-defaulting design assumes zod 3 semantics.

3. **DB migrations are append-only, v1 → v6.** Each schema version is a shipped, immutable migration step (v1 base; v2 `idx_media_day` + buckets cache; v3 retry columns `meta_attempts`/`thumb_attempts`/`next_retry_ms` + `idx_media_retry`; v4 organize `caption`/`rating`/`pick` + FTS recreated with `caption`; v5 places `place_*`/`geocode_status`; v6 editing `edit_ops`/`edited_ms`). **Never edit a migration that has already shipped** — only append a new version. Real installs migrate forward in place (with a DB backup), so altering a past migration corrupts upgrade paths.

4. **Privacy invariant — only three things may touch the network, all opt-in/scoped:** (a) **OpenStreetMap map tiles** when the map view is open; (b) a **one-time AI model download** when AI is turned on (or air-gapped via local model files in `data/models` with `ai.modelSource="local"`); (c) **Nominatim reverse-geocoding** only when `geocode.enabled` with `provider:"nominatim"` (throttled ≤1 req/s). Everything else — fonts, icons, all assets — is **self-hosted and local**. No telemetry, no CDNs, no outbound calls beyond these. Any new code that fetches over the network violates the product and must not be added.

5. **Canonical root paths via `fs.realpathSync.native`.** All configured roots are canonicalized using `fs.realpathSync.native` (NOT plain `fs.realpathSync`) so that **Windows 8.3 short names are expanded** to their long form. This keeps the scanner, the chokidar watcher, and the path allow-list / traversal guard consistent, and fixes a libuv fs-event crash. (Note the asymmetry that drove this: `fs.promises.realpath` expands 8.3 names but synchronous `fs.realpathSync` does not — `.native` does.) The config service also tolerates a UTF-8 **BOM** in `lgallery.config.json`.

### 1.6 Repository layout map

Top-level (repo root):

| Path | Contents |
|---|---|
| `package.json`, `bun.lock` | Manifest + Bun lockfile (versions/scripts per §1.4) |
| `svelte.config.js`, `vite.config.ts`, `tsconfig.json` | SvelteKit/Vite/TS config (aliases, runes, adapter-node + precompress) |
| `start.mjs` | Prod launcher: sets `UV_THREADPOOL_SIZE`, then imports `build/index.js` |
| `lgallery.config.example.json` | Example config (copied to `lgallery.config.json`, gitignored runtime config) |
| `setup-lgallery.cmd` / `setup-lgallery.ps1` | One-shot Windows installer (Git/Bun/Node, install, build, config, autostart) |
| `start-lgallery.cmd` / `start-lgallery-hidden.vbs` | Windows run/autostart launchers (set `UV_THREADPOOL_SIZE`, build-on-first-run, serve, open browser) |
| `token-usage.html` | Standalone token calculator (repo-root utility, unrelated to app runtime) |
| `README.md`, `docs/` | Human docs `01-ARCHITECTURE` … `12-ROADMAP` (architecture, data model, config, features, perf, privacy, security, data-safety, API, build plan, testing, roadmap) |
| `.claude/memory/` | Project status + key-decision + feedback memory notes |
| `scripts/gen-fixtures.mjs` | Dev helper: generates a sample library + matching config |
| `data/` | Runtime data dir (SQLite DB, thumbnail cache, trash, optional `models/`); ships with `.gitkeep` |
| `static/` | Self-hosted assets (logo/favicon, fonts, PWA manifest, service worker) |
| `src/` | Application source (below) |

`src/` internal layout (aliases in parentheses):

| Path | Role |
|---|---|
| `src/app.html`, `src/app.d.ts`, `src/ambient.d.ts`, `src/app.css` | App shell, SvelteKit/app type augmentation, ambient decls, Tailwind v4 entry + `@theme` tokens |
| `src/routes/` | SvelteKit routes: pages (`+page.svelte`/`+layout`), server loads (`+layout.server.ts`), and the HTTP API under `src/routes/api/**/+server.ts` (scan, timeline, media, tags, config, etc.) |
| `src/lib/shared/` (**`$shared`**) | Isomorphic code: `types.ts`, `format.ts`, `layout.ts` (justified-grid math), `blurhash.ts`, `edits.ts` (edit-op model + `cssFilterFor`), `config-schema.ts` (zod v3 schema) |
| `src/lib/server/` (**`$server`**) | Node-only server logic: `db/` (schema, migrate v1→v6, queries, index), `config/configService.ts`, `paths.ts` + `security.ts` (allow-list/traversal guard, realpath), `scan/` (walker, scanner, differ, scanState, watcher, pairing), `media/` (pipeline, workerPool + `thumb-worker.mjs` + `render-core.mjs`, thumbnail/video/exif/hash/file/edit services, streamService), `geo/` (cities offline NN + geocodeService), `ai/` (optional CLIP/faces, vectorIndex, aiState, optional import shim), `http.ts`, `lock.ts`, `log.ts`, `startup.ts` |
| `src/lib/client/` (**`$client`**) | Browser-only code: `api.ts` (fetch wrappers), `blurhash-img.ts`, `state/*.svelte.ts` (runes stores: gallery, selection, settings, scanStatus) |
| `src/lib/components/` (**`$components`**) | Svelte 5 components: `grid/` (TimelineGrid, MediaGridView, GridTile), `lightbox/` (Lightbox, InfoPanel, EditOverlay), `nav/` (Sidebar), `common/` (PageHeader, EmptyState, Skeleton, ScanChip, SelectionBar, DensityToggle, CommandPalette, Logo) |

Tests live next to their subjects as `*.test.ts` (e.g. `layout.test.ts`, `configService.test.ts`, `paths.test.ts`, `render-core.test.ts`, `edits.test.ts`) and run under Vitest with v8 coverage.

## 2. Toolchain, scaffold & project configuration

This section reproduces the build host, the exact dependency manifest, and every root-level config file. The app is a SvelteKit (Svelte 5 runes) + Bun project that builds to a standalone Node server via `adapter-node`. Follow the ordering below; the bootstrap commands at the end assume all files in this section already exist on disk.

### 2.1 Toolchain prerequisites (install first)

- **Bun**: install the EXACT version pinned in `package.json` → `"packageManager": "bun@1.3.14"`. The `"engines"` field enforces `"bun": ">=1.3.0"`, but reproduce with `1.3.14` so the resolved `bun.lock` transitive tree matches Appendix A byte-for-byte. On Linux/macOS: `curl -fsSL https://bun.sh/install | bash` then `bun upgrade --to 1.3.14` (or use the versioned installer). On Windows: `powershell -c "irm bun.sh/install.ps1 | iex"`.
- **Node**: a current Node LTS (Node 20+ satisfies `@types/node` `^25.9.3` and the `node:` built-ins used by `start.mjs`/server code). Node is required because production is launched with `node start.mjs` (NOT `bun`), and the runtime build is `@sveltejs/adapter-node`. Bun is used only as the package manager and dev/test runner.
- There is **no** `.nvmrc` or `.npmrc` in the repo; Node version is not pinned by a file.

### 2.2 `package.json` (exact contents)

Top-level fields, all required verbatim:

- `"name": "lgallery"`, `"version": "0.1.0"`, `"private": true`
- `"type": "module"` — the whole project is ESM (hence `start.mjs`, `svelte.config.js` using `import`).
- `"description"`: "A local, self-hosted Google-Photos-style gallery built with SvelteKit + Bun. Fully private, no cloud, no telemetry."
- `"packageManager": "bun@1.3.14"`
- `"engines": { "bun": ">=1.3.0" }`
- `"overrides": { "cookie": "^0.7.2" }` — forces the transitive `cookie` dep (pulled in by SvelteKit) up to a patched version across the whole tree. This is a security/correctness pin; do not drop it or the resolved `bun.lock` cookie version diverges.

**`scripts`** (exact):

| script | command |
|---|---|
| `dev` | `vite dev` |
| `build` | `vite build` |
| `preview` | `vite preview` |
| `start` | `node start.mjs` |
| `check` | `svelte-kit sync && svelte-check --tsconfig ./tsconfig.json` |
| `check:watch` | `svelte-kit sync && svelte-check --tsconfig ./tsconfig.json --watch` |
| `test` | `vitest run` |
| `test:cov` | `vitest run --coverage` |
| `test:watch` | `vitest` |

**`dependencies`** (runtime — exact ranges):

| package | version |
|---|---|
| `archiver` | `^8.0.0` |
| `better-sqlite3` | `^12.11.1` |
| `blurhash` | `^2.0.5` |
| `chokidar` | `^5.0.0` |
| `exifr` | `^7.1.3` |
| `ffmpeg-static` | `^5.3.0` |
| `ffprobe-static` | `^3.1.0` |
| `fluent-ffmpeg` | `^2.1.3` |
| `leaflet` | `^1.9.4` |
| `leaflet.markercluster` | `^1.5.3` |
| `sharp` | `^0.35.1` |
| `zod` | `^3.25.76` |

**`devDependencies`** (exact ranges):

| package | version |
|---|---|
| `@lucide/svelte` | `^1.20.0` |
| `@sveltejs/adapter-node` | `^5.5.4` |
| `@sveltejs/kit` | `^2.65.2` |
| `@sveltejs/vite-plugin-svelte` | `^7.1.2` |
| `@tailwindcss/vite` | `^4.3.1` |
| `@types/archiver` | `^8.0.0` |
| `@types/better-sqlite3` | `^7.6.13` |
| `@types/fluent-ffmpeg` | `^2.1.28` |
| `@types/leaflet` | `^1.9.21` |
| `@types/leaflet.markercluster` | `^1.5.6` |
| `@types/node` | `^25.9.3` |
| `@vitest/coverage-v8` | `^4.1.9` |
| `svelte` | `^5.56.3` |
| `svelte-check` | `^4.6.0` |
| `tailwindcss` | `^4.3.1` |
| `typescript` | `^6.0.3` |
| `vite` | `^8.0.16` |
| `vitest` | `^4.1.9` |

GOTCHAS:
- `@huggingface/transformers` and `sqlite-vec` are **NOT** in `package.json` — they are optional AI deps imported via guarded `import()` at runtime and only marked `ssr.external` in `vite.config.ts` so the build won't try to resolve them when absent. Do not add them to deps.
- Tailwind is v4 and integrated as a **Vite plugin** (`@tailwindcss/vite`), not via a `tailwind.config.js`/PostCSS chain.
- `bun.lock` (lockfileVersion 1, configVersion 1) pins the exact transitive versions and MUST be present (committed) — it is reproduced in Appendix A. Install with the lockfile to get the identical tree.

### 2.3 `svelte.config.js`

ESM module exporting the SvelteKit config. Key contents (verbatim semantics):

- `preprocess: vitePreprocess()` (from `@sveltejs/vite-plugin-svelte`).
- `kit.adapter: adapter({ precompress: true })` — `@sveltejs/adapter-node` with **precompress on**, so the build emits `.br`/`.gz` variants of the app shell and static files served directly.
- `kit.alias` (these four aliases are used pervasively across the codebase; reproduce exactly):
  - `$shared` → `src/lib/shared`
  - `$server` → `src/lib/server`
  - `$client` → `src/lib/client`
  - `$components` → `src/lib/components`
- `compilerOptions.runes: true` — Svelte 5 **runes mode is forced on globally** (all components use `$state`/`$derived`/`$props` etc., not legacy reactive syntax).

### 2.4 `vite.config.ts`

Starts with `/// <reference types="vitest/config" />` and uses `defineConfig` imported from `vitest/config` (not `vite`) so the `test` block is typed.

- `plugins: [tailwindcss(), sveltekit()]` — **Tailwind plugin must come before SvelteKit.**
- `ssr.external` (must NOT be bundled into the SSR build):
  - Native/binary modules: `better-sqlite3`, `sharp`, `fluent-ffmpeg`, `ffmpeg-static`, `ffprobe-static`, `archiver`
  - Optional AI modules (may be absent at build time): `@huggingface/transformers`, `sqlite-vec`
  
  Rationale (from the file's comments): native modules can't be bundled; the AI packages are optional and the runtime `import()` is guarded and degrades gracefully when uninstalled.
- `test` (Vitest):
  - `include: ['src/**/*.{test,spec}.{js,ts}']`
  - `environment: 'node'` (component tests opt into jsdom per-file)
  - `coverage`: `provider: 'v8'`, `reporter: ['text', 'html']`, `include: ['src/lib/server/**', 'src/lib/shared/**']`, `exclude: ['**/*.test.ts', '**/*.spec.ts', '**/*.svelte', 'src/lib/server/ai/**']`. Only server + shared logic is in the coverage denominator; client/components/AI are excluded (exercised via runtime smokes).

### 2.5 `tsconfig.json`

Extends the generated `./.svelte-kit/tsconfig.json` (so `svelte-kit sync` must run before `svelte-check`/typecheck — the `check` script does this). `compilerOptions`:

- `"allowJs": true`, `"checkJs": true` — JS files (e.g. `svelte.config.js`) are type-checked.
- `"esModuleInterop": true`, `"forceConsistentCasingInFileNames": true`, `"resolveJsonModule": true`, `"skipLibCheck": true`, `"sourceMap": true`
- `"strict": true`
- `"moduleResolution": "bundler"`

### 2.6 `.gitignore` and `.gitattributes`

`.gitignore` (notable, beyond standard `node_modules/`):
- `data/` is ignored **except** `!data/.gitkeep` — the app-managed data dir (personal media, SQLite DB, thumbnails, logs) is never committed.
- `lgallery.config.json` is ignored (contains local filesystem paths; it is generated/personal).
- Build output: `.svelte-kit/`, `build/`, `dist/`. Coverage: `coverage/`.
- Logs: `npm-install.log`, `*.log`, plus `.DS_Store`, `Thumbs.db`.
- Editor: `.vscode/*` except `!.vscode/extensions.json`; `.idea/`.
- Env: `.env`, `.env.*` except `!.env.example`.

`.gitattributes`:
- `* text=auto eol=lf` — repo normalizes to **LF**, checkout native on Windows.
- Binary: `*.png`, `*.jpg`, `*.webp`, `*.mp4`. `*.svg` is treated as `text`.

### 2.7 `src/app.html`

The SvelteKit shell. `<html lang="en">`, body has `data-sveltekit-preload-data="hover"` and wraps `%sveltekit.body%` in a `<div style="display: contents">`. Head includes favicon (`favicon.svg`), `manifest.webmanifest`, viewport with `viewport-fit=cover`, `theme-color #111827`, and `<meta name="referrer" content="no-referrer">` (privacy). Two inline boot scripts (run before first paint, all wrapped in `try/catch`):

1. **No-FOUC theme**: reads `localStorage.getItem('lg.theme') || 'system'`; if `dark`, or `system` and `prefers-color-scheme: dark` matches, adds `dark` class to `<html>`.
2. **`lg_w` width cookie boot script**: defines `setW()` that writes `document.cookie = 'lg_w=' + window.innerWidth + ';path=/;max-age=31536000;samesite=lax'`, calls it immediately, and on `resize` re-runs it debounced by 300ms (`setTimeout`). This cookie lets the **server read the viewport width during SSR** to lay out the timeline grid and avoid a blank-then-pop first paint. Reproduce the cookie name (`lg_w`), 1-year max-age, and 300ms debounce exactly — server layout code reads this.

### 2.8 `src/app.d.ts` and `src/ambient.d.ts`

`app.d.ts` declares the `App` namespace:
- `App.Error`: `{ code?: string; message: string }` (custom error shape returned by `handleError`).
- `App.Locals`: `{ authed: boolean; csrfToken: string }` — set per request by hooks.
- Empty `PageData`, `PageState`, `Platform`.

`ambient.d.ts` provides the one missing type:
```ts
declare module 'ffprobe-static' {
	const ffprobe: { path: string };
	export default ffprobe;
}
```
(`ffprobe-static` ships no types; `@types/fluent-ffmpeg` and the other `@types/*` cover the rest.)

### 2.9 `src/hooks.server.ts`

The server entry hook. On module load it fires `ensureStarted().catch(() => {})` (errors are logged inside; the `handle` hook retries on first request). Key responsibilities:

- **Bootstrap**: `await ensureStarted()` at the top of every request's `handle` (idempotent app startup from `$server/startup`).
- **CSRF cookie seed**: reads `lg_csrf`; if missing, sets it to `randomUUID()` (from `node:crypto`) with `{ path: '/', httpOnly: false, sameSite: 'lax', secure: false }` — deliberately **readable by JS** (`httpOnly: false`) for the double-submit pattern. Stores it in `event.locals.csrfToken`.
- **Auth gating**: gets `passwordHash()` from `$server/config/configService`. If no hash configured → `event.locals.authed = true` (open). Otherwise compares `lg_session` cookie against `sessionTokenFor(hash)` using `timingSafeStrEqual` (both from `$server/security`). On failure for a non-auth route (route is exempt when `path === '/login'` or `path.startsWith('/api/auth/')`):
  - `/api*` paths → JSON `{ error: { code: 'AUTH', message: 'Authentication required.' } }` with **HTTP 401**, `content-type: application/json`.
  - all other paths → empty body with **HTTP 303** and `location: /login`.
- **`handleError`** (`HandleServerError`): logs via `log.error(...)` (`$server/log`) and returns `{ code: 'INTERNAL', message: 'An internal error occurred.' }` (matching `App.Error`).

### 2.10 `start.mjs` (production launcher)

Thin ESM launcher invoked by `bun run start` / `node start.mjs`. Before importing the adapter-node build it sets `UV_THREADPOOL_SIZE` (if not already set) to `Math.max(8, (os.cpus()?.length ?? 4) * 2)`, then `await import('./build/index.js')`. This MUST be done before the first libuv threadpool task runs (sharp/ffmpeg dispatch there), because libuv reads the threadpool size once at init — hence the separate launcher in front of `build/index.js`. Do not start production with plain `node build/index.js`; you'd lose the threadpool sizing during large thumbnail backfills.

### 2.11 Bootstrap commands (exact, in order)

```sh
bun install        # resolves against committed bun.lock (lockfileVersion 1)
bun run build      # vite build → adapter-node output in build/, precompressed
bun run start      # node start.mjs → sets UV_THREADPOOL_SIZE, imports build/index.js
```

For development use `bun run dev` (`vite dev`); typecheck with `bun run check` (runs `svelte-kit sync` first to generate `.svelte-kit/tsconfig.json`); tests with `bun run test` / `bun run test:cov`.

## 3. Configuration & data model

LGallery has two persistence layers a rebuilder must get byte-exact: the **config file** (`lgallery.config.json`, validated by a zod schema) and the **SQLite database** (`data/lgallery.db`, built by an ordered migration set). Build these modules in this order: `src/lib/shared/config-schema.ts` → `lgallery.config.example.json` → `src/lib/server/db/schema.ts` → `src/lib/server/db/migrate.ts` → `src/lib/server/db/index.ts` → `src/lib/server/config/configService.ts` (config depends on `../paths` `normalizePath`, `../security` `hashPassword`, and `../log`).

Pinned versions (from `package.json`): `zod ^3.25.76`, `better-sqlite3 ^12.11.1`. The schema uses zod v3 idioms (`z.object().default({})`, `.safeParse`, `error.issues`) — do not port to zod v4 semantics.

### 3.1 `src/lib/shared/config-schema.ts` — the zod config shape

Isomorphic on purpose: zod only, **no node imports**, so the same validator runs at startup, on `PUT /api/config`, and could run client-side. File IO and hashing live in the server `configService`, never here.

Key building block — `extensions(def)` helper:
```ts
const extensions = (def: string[]) =>
  z.array(z.string()).default(def)
   .transform((arr) => [...new Set(arr.map((e) => e.toLowerCase().replace(/^\./, '')))]);
```
GOTCHA: this lowercases, strips a single leading dot, and de-dupes via `Set`. So `".JPG"`, `"jpg"`, `"JPG"` all canonicalize to `jpg`. Extensions are stored WITHOUT the dot everywhere downstream — honor this when matching files.

`rootSchema = z.object({ path: string().min(1), label: string().default(''), enabled: boolean().default(true) })`.

`configSchema` fields (every default is load-bearing — defaults are what land in the DB-driving canonical hash):

- **`roots`**: `array(rootSchema).min(1, 'at least one root folder is required')` — the one required field; everything else defaults.
- **`include`**: `default(['**/*'])`.
- **`exclude`**: `default(['**/.*', '**/@eaDir/**', '**/#recycle/**', '**/Thumbs.db'])` — note Synology (`@eaDir`, `#recycle`) and Windows (`Thumbs.db`) noise.
- **`imageExtensions`**: defaults to the 19-entry list `jpg, jpeg, png, gif, webp, avif, bmp, tiff, tif, heic, heif, cr2, cr3, nef, arw, dng, raf, orf, rw2` (RAW + HEIC included).
- **`videoExtensions`**: defaults to `mp4, mov, m4v, webm, mkv, avi, wmv, mts, m2ts, 3gp`.
- **`scan`** `.default({})`: `onStartup true`, `rescanOnReload true`, `watch false`, `concurrency int().min(0).default(0)` (0 = derive), `useWorkers true`, `workerCount int().min(0).default(0)` (0 = derive from concurrency or cores-1), `maxAttempts int().min(1).default(3)`, `removeMissing true`, `followSymlinks false`.
- **`thumbnails`** `.default({})`: `dir 'data/thumbnails'`, `format z.literal('webp').default('webp')` (ONLY webp is valid), `grid {longEdge int>0 default 320, quality int 1..100 default 70}`, `preview {longEdge default 1600, quality default 80}`, `eagerPreview false` (lazy 1600px preview on first lightbox open — halves scan-time pixels), `videoFrameAtPercent number 0..100 default 10`, `videoStoryboardFrames int>=0 default 5`.
- **`trash`** `.default({})`: `dir 'data/trash'`, `perRoot false`, `autoPurgeDays int>=0 default 30`.
- **`server`** `.default({})`: `host` constrained by regex `^(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}|localhost)$` default `'127.0.0.1'`; `port int 1..65535 default 4173`; `password string().nullable().default(null)`; `passwordHash string().nullable().default(null)`; `sessionTtlHours int>0 default 168` (7 days).
- **`map`** `.default({})`: `enabled true`, `tileUrl 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'`, `attribution '© OpenStreetMap contributors'`, `reverseGeocode false`.
- **`geocode`** `.default({})`: `enabled false`, `provider enum(['offline','nominatim']).default('offline')`, `email string().default('')` (used in Nominatim User-Agent per OSM policy). OFF by default; only `nominatim` makes network calls.
- **`ai`** `.default({})`: `semanticSearch false`, `faceGrouping false`, `modelsDir 'data/models'`, `modelSource enum(['huggingface','local']).default('huggingface')`, `device enum(['cpu','auto']).default('cpu')`.
- **`ui`** `.default({})`: `theme enum(['light','dark','system']).default('system')`, `gridDensity enum(['compact','comfortable','spacious']).default('comfortable')`, `startView enum(['timeline','folders','albums']).default('timeline')`.
- **`logging`** `.default({})`: `level enum(['debug','info','warn','error']).default('info')`, `file 'data/lgallery.log'`, `maxSizeMb number>0 default 10`, `maxFiles int>0 default 5`.

Exports: `type LGalleryConfig = z.infer<typeof configSchema>`, `type RootConfig`, and `MINIMAL_CONFIG_HINT = { roots: [{ path: 'D:/Photos', label: 'Main', enabled: true }] }`.

### 3.2 `lgallery.config.example.json`

Seed file copied to `lgallery.config.json` on first run. It mirrors all defaults but deliberately **omits** `useWorkers/workerCount/maxAttempts` from `scan`, `eagerPreview` from `thumbnails`, `passwordHash` from `server`, and the entire `geocode` block — those come from schema defaults. The example's `server.password` is `null`. `roots` is the single `{ "path": "D:/Photos", "label": "Main", "enabled": true }` placeholder a user is expected to edit. Reproduce this file exactly (2-space indent) — `readRaw()` copies it verbatim.

### 3.3 `src/lib/server/config/configService.ts`

Module-level singletons `current: LGalleryConfig | null` and `currentHash = ''`. Paths resolved once: `CONFIG_FILE = cwd/lgallery.config.json`, `EXAMPLE_FILE = cwd/lgallery.config.example.json`.

- **`readRaw()`**: if `CONFIG_FILE` missing, copy `EXAMPLE_FILE` → `CONFIG_FILE` (log a warn) or throw if no example. Then read utf8 and **strip a leading UTF-8 BOM** with `.replace(/^\uFEFF/, '')` before `JSON.parse` (Notepad-saved configs). 
- **`parseConfig(raw)`**: `configSchema.safeParse`; on failure builds a multi-line message `  • <path or (root)>: <message>` from `parsed.error.issues`. On success, **canonicalizes every root path** via `canonicalRoot`.
- **`canonicalRoot(p)`**: `normalizePath(fs.realpathSync.native(normalizePath(p)))`, falling back to lexical `normalizePath(p)` if the path doesn't exist. GOTCHA (Windows): `realpathSync.native` expands 8.3 short names (`CLARK~1.BER` → `clark.bernales`); without it the scanner, the chokidar watcher (libuv fs-events asserts on 8.3 paths), and the path allow-list disagree. This is non-optional on Windows.
- **`canonicalHash(c)`** — the rescan trigger. Hashes ONLY source-relevant fields so UI/logging/server edits never force a rescan. Builds:
  ```ts
  { roots: roots.filter? no — maps ALL roots to {path: normalizePath(path), enabled} sorted by path,
    include: [...].sort(), exclude: [...].sort(),
    imageExtensions: [...].sort(), videoExtensions: [...].sort() }
  ```
  then `sha256(JSON.stringify(src)).hex`. Note roots keep `enabled` (toggling a root IS a source change) but drop `label`; arrays are sorted so reordering is a no-op. Matching this byte-for-byte matters: a different serialization changes the hash and spuriously triggers full rescans.
- **`loadConfig()`**: parse+hash, set singletons, async `import('../log').initLogger(...)` from `cfg.logging`, then `checkRoots` (warn-only on missing/non-dir enabled roots — never throws; offline roots retain their index).
- **`reloadIfChanged()`**: re-read + re-hash; returns `{ changed: hash !== currentHash, config, hash }` and updates singletons. Drives reload-time incremental rescan.
- **`saveConfig(raw)`**: parse → `hashPlaintextPassword` → atomic write (`CONFIG_FILE + '.tmp'` then `renameSync`) of `JSON.stringify(cfg, null, 2) + '\n'` → update singletons → return `{config, hash, changed}`. GOTCHA: it writes the **normalized, password-hashed** config, so cleartext never lands on disk and root paths are persisted canonicalized.
- **`hashPlaintextPassword(cfg)`**: if `server.password` set, `server.passwordHash = hashPassword(password)` and `server.password = null`.
- **`migratePasswordIfNeeded()`**: startup hook; if on-disk has `password` but no `passwordHash`, re-save (hashes at rest).
- **`clientConfig(cfg)`**: redaction view sent to the browser — strips the whole `server` object and re-adds only `{host, port, sessionTtlHours, passwordSet: Boolean(password || passwordHash)}`. Never leaks `password`/`passwordHash`.
- Helpers: `getEnabledRoots()` (normalized enabled root paths — the path-safety allow-list basis), `getAllRoots()`, `getTrashDir()` (`normalizePath(resolve(cwd, trash.dir))` — added to allow-list so restores work), `getConfig()` (throws if not loaded), `getConfigHash()`, `passwordHash()`.

### 3.4 `src/lib/server/db/index.ts` — connection

`DB_PATH = cwd/data/lgallery.db`. Singleton `db: DB | null`. `getDb()`: `mkdirSync(dirname, {recursive})`, `new Database(DB_PATH)`, apply PRAGMAS, `runMigrations(conn, DB_PATH)`, cache, log.

PRAGMAS list (verbatim, applied in order via `conn.pragma(p.replace(/^PRAGMA\s+/i,''))`):
```
PRAGMA journal_mode = WAL
PRAGMA synchronous = NORMAL
PRAGMA foreign_keys = ON
PRAGMA temp_store = MEMORY
PRAGMA cache_size = -65536      -- ~64 MB (negative = KiB of memory, not pages)
PRAGMA mmap_size = 268435456    -- 256 MB
PRAGMA busy_timeout = 5000      -- 5 s
```
`openTestDb(file=':memory:')`: `new Database(file)`; for non-memory files set `journal_mode=WAL` (no-op for `:memory:`); always `foreign_keys=ON`; run migrations. `closeDb()`: `wal_checkpoint(TRUNCATE)` (guarded) then `close()`, reset singleton.

### 3.5 `src/lib/server/db/migrate.ts` — runner

DDL is hand-written (FTS5 / vec0 / triggers can't be generated by drizzle-kit). Versioned via `app_state.schema_version` (string value). 
- `getSchemaVersion`: 0 if no `app_state` table, else `Number(value)`.
- `runMigrations(db, dbPath)`: if `current >= TARGET_SCHEMA_VERSION` (= 6), return. **Backup-before-migrate**: if `current > 0`, path isn't `:memory:`, and file exists → `wal_checkpoint(TRUNCATE)` (fold WAL into main file) then `copyFileSync` to `${dbPath}.bak-${current}` (warn-and-proceed on failure). Then apply every `MIGRATIONS[m]` with `m.version > current`, **each in its own `db.transaction`** doing `db.exec(m.sql); setSchemaVersion(m.version)`.
- GOTCHA: migrations are applied strictly where `version > current`; never edit a shipped migration (you'd skip it on upgraded DBs). Append only.

### 3.6 The migration set (`schema.ts`)

`MIGRATIONS` array, `TARGET_SCHEMA_VERSION = 6`:

**v1 `core-schema` (`SCHEMA_V1`)** — full base schema.

Tables:
- `roots(id PK, path TEXT UNIQUE NOT NULL, label TEXT, enabled INTEGER NOT NULL DEFAULT 1, online INTEGER NOT NULL DEFAULT 1)`.
- `media(id PK, path TEXT UNIQUE NOT NULL, root_id NOT NULL REFERENCES roots(id) ON DELETE CASCADE, rel_path, dir, filename, ext, type NOT NULL, size_bytes NOT NULL, mtime_ms NOT NULL, width, height, duration_ms, taken_ms, taken_local_day TEXT, taken_source TEXT, camera_make, camera_model, lens, orientation INTEGER, codec, has_gps INTEGER NOT NULL DEFAULT 0, gps_lat REAL, gps_lon REAL, quick_hash, phash, blurhash, live_partner_id REFERENCES media(id) ON DELETE SET NULL, is_favorite/is_archived/is_trashed INTEGER NOT NULL DEFAULT 0, meta_status/thumb_status INTEGER NOT NULL DEFAULT 0, error, scan_id, created_at NOT NULL, updated_at NOT NULL)`. `meta_status`/`thumb_status` use 0=pending…3=failed convention (retry in v3). `taken_local_day` is a `YYYY-MM-DD` string for day bucketing.
- `albums(id, name NOT NULL, cover_media_id REFERENCES media ON DELETE SET NULL, created_at, sort_order DEFAULT 0)`; `album_items(album_id→albums CASCADE, media_id→media CASCADE, added_at, position, PRIMARY KEY(album_id, media_id))`.
- `tags(id, name UNIQUE)`; `media_tags(media_id→media CASCADE, tag_id→tags CASCADE, PK(media_id, tag_id))` — present in v1 but UI arrives in v4.
- `trash(id, media_id REFERENCES media ON DELETE SET NULL, original_path NOT NULL, trash_path NOT NULL, size_bytes NOT NULL, trashed_at NOT NULL)`.
- `scans(id, started_at NOT NULL, finished_at, status NOT NULL, files_seen/added/updated/removed DEFAULT 0, error)`.
- `app_state(key PK, value)`.

Indexes (why): `idx_media_timeline (is_trashed, is_archived, taken_ms DESC, id DESC)` — primary timeline query; `idx_media_dir (root_id, dir, filename)` — folders view; `idx_media_type (type, taken_ms DESC)`; partial `idx_media_fav`/`idx_media_arch`/`idx_media_gps` (`WHERE flag=1`); partial `idx_media_hash`/`idx_media_phash` (`WHERE … IS NOT NULL`) for dedupe; `idx_media_scan (scan_id)`; `idx_media_pending (meta_status, thumb_status)` — pipeline backfill queue.

FTS: `media_fts` is an **external-content FTS5** table (`content='media', content_rowid='id'`) over `filename, camera_model, rel_path`, kept in sync by three triggers `media_fts_ai/ad/au`. The delete/update triggers use the special `INSERT INTO media_fts(media_fts, rowid, …) VALUES('delete', …)` form required by external-content FTS5.

Separately exported (NOT in MIGRATIONS — created on demand when AI features turn on): `FACES_SQL` (`face_clusters`, `faces` with `embedding BLOB`, indexes) and `EMBEDDINGS_SQL` (`CREATE VIRTUAL TABLE … USING vec0(media_id INTEGER PRIMARY KEY, embedding FLOAT[512])` — needs sqlite-vec loaded first).

**v2 `day-index` (`SCHEMA_V2`)**: `CREATE INDEX idx_media_day ON media (is_trashed, is_archived, taken_local_day)` — covering index for the timeline scrollbar's day-bucket aggregate.

**v3 `retry-attempts` (`SCHEMA_V3`)**: `ALTER TABLE media ADD meta_attempts INTEGER NOT NULL DEFAULT 0`, `thumb_attempts INTEGER NOT NULL DEFAULT 0`, `next_retry_ms INTEGER`; partial `idx_media_retry (next_retry_ms) WHERE next_retry_ms IS NOT NULL`. Turns permanent failures into bounded, backoff-driven retries (capped by `scan.maxAttempts`).

**v4 `organize` (`SCHEMA_V4`)**: adds `caption TEXT`, `rating INTEGER NOT NULL DEFAULT 0`, `pick INTEGER NOT NULL DEFAULT 0`. Then **drops the 3 FTS triggers + `media_fts` table** and recreates `media_fts` with an extra `caption` column, runs `INSERT INTO media_fts(media_fts) VALUES('rebuild')` to reindex existing content, and recreates the three triggers all carrying `caption`. Adds partial `idx_media_rating (rating) WHERE rating > 0` and `idx_media_pick (pick) WHERE pick != 0`. GOTCHA: the v4 trigger set is the FINAL one — if rebuilding from empty you still apply v1's triggers first, then v4 replaces them; don't shortcut by writing only the caption triggers in v1.

**v5 `places` (`SCHEMA_V5`)**: adds `place_name TEXT`, `place_locality TEXT`, `place_country TEXT`, `geocode_status INTEGER NOT NULL DEFAULT 0` (0 none, 1 done, 2 fail); partial `idx_media_place (place_locality) WHERE place_locality IS NOT NULL`.

**v6 `edits` (`SCHEMA_V6`)**: adds `edit_ops TEXT` (JSON op list applied to the original at render time — source file never mutated; NULL = unedited) and `edited_ms INTEGER` (doubles as derivative cache-buster).

All of v3–v6 are additive `ALTER TABLE` (instant even on 200k rows). After all migrations the `media` table has the v1 columns plus `meta_attempts, thumb_attempts, next_retry_ms, caption, rating, pick, place_name, place_locality, place_country, geocode_status, edit_ops, edited_ms`.

## 4. Server foundation & shared libraries

This section covers the lowest layer the rest of the app stands on: the path-safety boundary, request-auth/CSRF guards, the global mutex, logging, HTTP helpers, the bootstrap sequence, and the pure isomorphic libraries (types, formatting, layout math, blurhash, edits). Build these before any DB/service/route code — almost everything imports from here.

Import aliases used throughout: `$shared/*` → `src/lib/shared/*`, and server code imports siblings by relative path. The `$shared` types file must contain **no `node:` imports** (it is bundled into the client). The same rule applies to every file under `src/lib/shared/`.

Build order within this layer: `shared/*` first (no deps), then `server/log.ts`, `server/http.ts`, `server/paths.ts`, `server/security.ts`, `server/lock.ts`, and finally `server/startup.ts` (depends on config/db/scan/media modules that come in later sections — wire its dynamic imports last).

### 4.1 `src/lib/server/paths.ts` — path-safety boundary + thumb sharding

Primary traversal/symlink guard. Uses `node:path` + `node:fs` but holds no app state except a realpath cache.

- `class PathError extends Error` — carries `code = 'PATH_FORBIDDEN'`, `name = 'PathError'`. Thrown by every reject path.
- `normalizePath(input): string` — canonical comparable form: absolute, forward-slashes, **lower-cased leading drive letter** (`C:/x` → `c:/x`), no trailing slash except a bare root, UNC `//server/share` preserved. Rejects `null`/empty/`\0`. Gotchas a rebuilder must honor exactly:
  - Detect UNC via `/^[\\/]{2}[^\\/]/` **before** `path.resolve`, because `path.resolve` may collapse the `//` to a single `/`; restore it afterward with `'/' + resolved.replace(/^\/+/, '/')`.
  - Drive-letter lower-casing regex `^([a-zA-Z]):\/` runs after the `\\`→`/` replace.
  - Trailing-slash strip only when `length > 1`.
- `isWithin(child, parent): boolean` — **segment-boundary aware** and **case-insensitive only on Windows** (`cmp()` lower-cases when `process.platform === 'win32'`, otherwise identity — do NOT lower-case on POSIX). Equal paths return true; otherwise `child` must start with `parent + '/'`. This prevents `/photos-secret` matching root `/photos`.
- `assertWithinRoots(candidate, roots, extra=[])` — lexical allow-list; returns the normalized candidate or throws `PathError`. `roots`/`extra` may be un-normalized (it normalizes internally via `isWithin`). `extra` is for dirs like `data/trash`.
- `realPathWithinRoots(candidate, roots, extra=[]): Promise<string>` — async. Does the cheap lexical `assertWithinRoots` first, then `await fs.promises.realpath(candidate)`. **If realpath throws (file not yet created, e.g. a thumb about to be written) it falls back to the normalized lexical path** — does NOT reject. On success it re-checks the *real* path against *realpath-canonicalized* roots.
  - **8.3 / realpath gotcha (critical):** roots are canonicalized through `realRootCanon` which uses **`fs.promises.realpath` (async)**. On Windows the async realpath expands 8.3 short names to long form; `fs.realpathSync` does NOT. Both candidate and roots must use the async API or the check silently breaks (false rejections from 8.3 names/junctions, while a real symlink escape is still caught). `realRootCanon` memoizes into module-level `rootRealCache` (Map keyed by normalized root); offline/missing roots fall back to the lexical normalized form.
- `thumbShard(id): string` — `(id & 0xff).toString(16).padStart(2,'0')` → two-hex shard `id % 256`, so no thumbnail dir holds 50k flat files.
- `type ThumbSize = 'grid' | 'grid2x' | 'preview'`.
- `thumbPath(thumbnailsDir, id, size)` → `path.join(path.resolve(cwd, thumbnailsDir), shard, `${id}_${size}.webp`)`. WebP always.
- `storyboardPath(thumbnailsDir, id)` → same dir, filename `${id}_sb.webp`.
- `splitPath(rootNormalized, fileNormalized)` → `{ relPath, dir, filename, ext }`. `relPath` is the slice after `rootNormalized + '/'` (else the full file path). `ext` is the **lower-cased** substring after the last `.`, or `''` if none.

### 4.2 `src/lib/server/security.ts` — auth, CSRF, mutation guard

Imports `crypto` and `apiError` from `./http`. Read endpoints never call `requireMutation`.

- `hashPassword(plain): string` — `scrypt$<saltHex>$<hashHex>`, 16-byte random salt, `crypto.scryptSync(plain, salt, 64)` (64-byte key).
- `verifyPassword(plain, stored): boolean` — splits on `$`, requires exactly 3 parts and `parts[0] === 'scrypt'`. **Empty-hex reject fix (must keep):** after building `salt`/`expected` Buffers, `if (salt.length === 0 || expected.length === 0) return false;` — an all-empty stored key would otherwise match any password because scrypt with keylen 0 yields an empty buffer that `timingSafeEqual`-matches an empty expected. Recomputes `scryptSync(plain, salt, expected.length)` and compares with `crypto.timingSafeEqual` after a length check.
- `sessionTokenFor(passwordHash): string` — deterministic, no server-side session store: `sha256('lg-session:' + passwordHash)` hex. Rotating the password invalidates all sessions automatically.
- `timingSafeStrEqual(a, b): boolean` — length-compared first (length not secret here), then `timingSafeEqual`; returns false on any throw.
- `isSameOrigin(event): boolean` — prefers `Sec-Fetch-Site` header (`same-origin`/`none` allowed). Falls back to `Origin` header vs `event.url.origin`; **a missing Origin returns true** (non-browser client / same-origin navigation).
- `requireMutation(event): Response | null` — three layered defenses, returns a 4xx `Response` to block or `null` to allow:
  1. `!isSameOrigin` → 403 `CSRF`.
  2. CSRF double-submit: cookie `lg_csrf` must exist, header `x-csrf-token` must exist, and `timingSafeStrEqual(cookie, header)`. **A missing header must fail, not pass.** Cookie is seeded in hooks on first request.
  3. `!event.locals.authed` → 401 `AUTH`.

### 4.3 `src/lib/server/lock.ts` — single-process FIFO mutex

Module-level `let chain: Promise<unknown> = Promise.resolve()`. `withLock<T>(fn)` does `const run = chain.then(fn, fn)` (runs `fn` whether the prior link resolved or rejected), then advances `chain = run.then(()=>{}, ()=>{})` so a rejection can't poison the chain, and returns `run`. Shared by scanner, fileService, and watcher so user mutations never interleave with scanner DB writes/sweep. **Gotcha:** critical sections must be short — the scanner locks per-batch and around the sweep, NOT for the whole walk, so mutations aren't starved during long scans.

### 4.4 `src/lib/server/log.ts` — rotating local file logger

Local-only; nothing is ever transmitted. Levels `debug|info|warn|error` with `ORDER` `{10,20,30,40}`. Default config: `{ level:'info', file:'data/lgallery.log', maxSizeMb:10, maxFiles:5 }`, `absFile = path.resolve(cwd, file)`.

- `initLogger(partial)` — merges partial config, recomputes `absFile`/`minOrder`, resets `dirReady`, `ensureDir()`.
- `ensureDir()` — `mkdirSync(dirname, {recursive:true})`; on failure falls back to console-only (`dirReady` stays false).
- `rotateIfNeeded()` — when file ≥ `maxSizeMb*1024*1024`, shifts `log.(n-1)→log.n` dropping the oldest (`absFile`, `absFile.1`, … `absFile.{maxFiles-1}`). All wrapped in try/catch.
- `write(level,msg,meta?)` — skips below `minOrder`; line is `ISO ts [LEVEL] msg` plus serialized meta (Error → `stack ?? message`, else `JSON.stringify`). Appends with `appendFileSync`; **never crashes on disk errors**. Console mirror: warn/error always; everything else only when `NODE_ENV !== 'production'`.
- Export `log` = `{ debug, info, warn, error }`.

### 4.5 `src/lib/server/http.ts` — tiny HTTP helpers

Imports `json`, `type Cookies` from `@sveltejs/kit`, and `ApiErrorBody` from `$shared/types`.

- `initialGridWidth(cookies): number` — reads viewport width cookie `lg_w` (set by the boot script in `app.html`) to lay the grid out during SSR. Subtracts sidebar (`64` when `w<=700`, else `216`) and `pad = 24` (12px each side of TimelineGrid). `Math.max(280, round(w - sidebar - pad))`. Falls back to `1200` when the cookie is absent/invalid.
- `apiError(status, code, message): Response` — `json({ error: { code, message } } satisfies ApiErrorBody, { status })`. This is the canonical error envelope used everywhere.
- `parseIds(input): number[]` — only accepts an array; maps to `Number` and keeps positive integers. Non-array → `[]`.

### 4.6 `src/lib/server/startup.ts` — idempotent bootstrap

Invoked from `hooks.server.ts` on every request; heavy work runs once. Imports config service, `getDb/closeDb`, `log`. Uses dynamic `import()` for scanner/media so early bring-up never hard-fails.

- Module state `started`, `startPromise`.
- `doStart()` sequence (order matters):
  1. `loadConfig()` → `{ config, hash }`; `getDb()` (opens DB + runs migrations).
  2. **UV_THREADPOOL advisory:** if `process.env.UV_THREADPOOL_SIZE` is unset, `log.warn` — sharp dispatches resizes to the libuv threadpool (default 4) read once at process init, so the env var **must be set on the launch command** (start scripts/setup set it to 16), not here.
  3. `migratePasswordIfNeeded()` (dynamic import) — hashes any plaintext `server.password` at rest before serving; failure is warn-only.
  4. `reconcileRoots(db)` (dynamic import from `./scan/scanner`) — upserts configured roots, drops de-configured roots + their media.
  5. Persist `config_hash` into `app_state` via upsert (`INSERT … ON CONFLICT(key) DO UPDATE SET value=excluded.value`) — baseline for reload-time rescan detection.
  6. `log.info` the root count.
  7. `bootScan()` (dynamic import) — kicks the background scanner; wrapped in try/catch (`log.debug` on failure) so a missing scanner module never blocks startup.
  8. `registerShutdown()`.
- `ensureStarted(): Promise<void>` — returns resolved promise if `started`; else memoizes `startPromise`. **On failure it nulls `startPromise` so the next request retries**, logs, and rethrows.
- `registerShutdown()` — guarded by `shutdownRegistered`. On `SIGINT`/`SIGTERM` (`process.once` each): dynamic-import `./media/workerPool` and call `shutdownPool()` (best-effort so threads don't linger), then in `finally` `closeDb()` then `process.exit(0)`.

### 4.7 `src/lib/shared/types.ts` — isomorphic domain types

No `node:` imports. Key exports:

- `MediaType='photo'|'video'`, `TakenSource='exif'|'mtime'`, `GridDensity='compact'|'comfortable'|'spacious'`, `Theme='light'|'dark'|'system'`.
- `Status` const object `{ None:0, InProgress:1, Ready:2, Fail:3 }` and `StatusCode` union — shared by `meta_status`/`thumb_status` DB columns.
- `TimelineItem` — the lightweight hot-query row: `id, type, width|null, height|null, takenMs, takenLocalDay('YYYY-MM-DD'), durationMs|null, blurhash|null, isFavorite, livePartnerId|null, thumbStatus`.
- `Cursor { curMs, curId }`, `TimelinePage { items, nextCursor|null }`, `DayBucket { day, n }`.
- `MediaDetail extends TimelineItem` — adds `path, relPath, dir, filename, ext, sizeBytes, mtimeMs, takenSource|null, cameraMake, cameraModel, lens, codec, orientation|null, hasGps, gpsLat|null, gpsLon|null, isArchived, isTrashed, error|null, albums[]`, plus the editorial fields: `caption|null`, `rating` (0 unrated, 1–5), `pick` (1 pick / -1 reject / 0 none), `tags[{id,name}]`, `placeName|null`, `placeLocality|null`, `placeCountry|null`, and `editOps: import('./edits').EditOps | null` (inline type import keeps the dep direction clean).
- `Tag { id, name, count }`, `PlaceGroup { locality, country|null, count, sampleId }`, `Album { id, name, coverMediaId|null, count, createdAt, sortOrder }`.
- `ScanStatus='idle'|'running'|'done'|'error'` and `ScanState` — progress fields incl. `throughputPerSec` (rolling thumbnails/sec over ~30s, 0 when idle) and `etaMs|null` (ms to drain thumbnail backlog).
- `MapPoint`, `MapCluster { …, sampleId }`, `TrashItem`, `DuplicateGroup { hash, kind:'exact'|'near', items }`.
- `ApiErrorBody { error:{code,message} }` (used by `http.ts`), `BulkResult { ok:number[], failed:{id,error}[] }`.

### 4.8 `src/lib/shared/format.ts` — date policy + formatters

**Date policy (must honor):** `taken_ms` stores the capture instant as *wall-clock-interpreted-as-UTC*, so the "local day" is just the UTC calendar day — no runtime timezone math. All formatters here read UTC components.

- `wallClockToMs(y, m1to12, d, h=0, min=0, sec=0, ms=0)` → `Date.UTC(...)` (storage form; producers must build timestamps this way).
- `localDayFromMs(ms)` → `'YYYY-MM-DD'` from UTC parts.
- `monthKeyFromDay(day)` → `day.slice(0,7)`.
- `dayHeaderLabel(day)` → e.g. "Monday, June 16, 2026"; `monthHeaderLabel('YYYY-MM')` → "June 2026"; `floatingDateLabel(day)` → "Jun 2026".
- `formatBytes(bytes)` → `'—'` for non-finite/negative; `B` under 1024, else KB/MB/GB/TB with one decimal when `<10` else rounded.
- `formatDuration(ms)` → `''` for falsy/≤0; `m:ss` or `h:mm:ss`.
- `formatDateTime(ms)` → `'—'` for null; UTC-based `Mon D, YYYY · h:mm AM/PM`.
- Internal `MONTHS`/`WEEKDAYS` arrays and `pad2`.

### 4.9 `src/lib/shared/layout.ts` — justified-row layout math

Pure, no DOM/node; unit-tested and reused in SSR. Imports `monthKeyFromDay`.

- Interfaces: `LayoutInput {id, width|null, height|null, takenLocalDay}`, `LayoutTile {id,index,x,y,w,h}`, `LayoutRow {type:'header'|'tiles', y, h, day?, isMonthStart?, tiles?}`, `Layout {rows, totalHeight, width}`, `LayoutOptions {containerWidth, targetRowHeight, gap, dayHeaderHeight, monthHeaderHeight, sectionGap}`.
- `DEFAULT_ASPECT = 1` (square placeholder before dims arrive).
- `densityOptions(density, containerWidth)` — exact constants: target row height `compact 140 / comfortable 200 / spacious 280`; gap `compact 3 / comfortable 4 / spacious 6`; always `dayHeaderHeight 40`, `monthHeaderHeight 64`, `sectionGap 16`.
- `aspectOf(it)` — `width/height` **clamped to [0.3, 4]** so a panorama can't dominate a row; default 1 if dims missing.
- `computeLayout(items, opts)` — greedy justified algorithm. Walks items in order; per distinct `takenLocalDay` pushes a header row (`monthHeaderHeight` when the month changed since `lastMonth`, else `dayHeaderHeight`), then fills tile rows: accumulate `sumAspect` until natural width `sumAspect*target + gap*(count-1) >= W` (overflow), then row height `h = overflow ? (W - gap*(count-1))/sumAspect : target` (trailing partial row keeps target height). Tile widths `aspectOf*h`, x advances by `w+gap`; **x/y/w/h are rounded**, `y` advances by `round(h)+gap`, then `+sectionGap` after each day. `totalHeight = Math.ceil(y)`. **Items must be pre-sorted by day** (it groups by contiguous equal `takenLocalDay`).
- `findRowRange(rows, top, bottom)` — two binary searches over rows sorted by `y` (non-overlapping), returns `[start, end)` intersecting the viewport. O(log n). First search: first row whose `y+h > top`. Second: first row whose `y >= bottom`.
- `estimateHeightFromBuckets(buckets, opts, itemsPerRow)` — pre-dimension height estimate from day-count buckets; `rowsForDay = max(1, ceil(n/max(1,itemsPerRow)))`, accumulates header + `rowsForDay*(targetRowHeight+gap)+sectionGap`. **Must use the same math as `computeLayout`/`monthMarksFromBuckets`** or scrollbar/scrubber drift.
- `monthMarksFromBuckets(...)` → `MonthMark {key:'YYYY-MM', y}[]` — cumulative content-y of each month boundary for the date-jump scrubber, using identical accumulation. Buckets are newest-first (top=newest → bottom=oldest).

### 4.10 `src/lib/shared/blurhash.ts` — average-color placeholder

Avoids full canvas decode at 50k tiles; extracts only the DC term.

- `DIGITS` = the 83-char base-83 alphabet (`0-9A-Za-z#$%*+,-.:;=?@[]^_{|}~`).
- `decode83(str)` — base-83 accumulate; returns early on an unknown char.
- `blurhashAverageColor(hash|null|undefined): string` — returns `'rgb(229,231,235)'` (neutral gray-200) when hash is missing or shorter than 6; else decodes `hash.slice(2,6)` and unpacks `(dc>>16)&255, (dc>>8)&255, dc&255` into `rgb(r,g,b)`.

### 4.11 `src/lib/shared/edits.ts` — non-destructive edit model

Isomorphic so the client renders a live CSS preview while the server applies the same intent with sharp. Edits stored as JSON on the row; the source file is never modified.

- `CropRect {x,y,w,h}` (all normalized 0..1 against the rotated image).
- `EditOps {rotate, flipH, flipV, crop:CropRect|null, brightness, contrast, saturation, vibrance, warmth, filter}`. Multipliers center on 1.0; `vibrance`/`warmth` are -1..1 (0 none); `rotate` ∈ {0,90,180,270}.
- `FilterId = 'none'|'auto'|'vivid'|'warm'|'cool'|'fade'|'mono'|'sepia'|'noir'`; `FILTERS` array in that order.
- `DEFAULT_EDITS` — rotate 0, flips false, crop null, brightness/contrast/saturation 1, vibrance/warmth 0, filter 'none'.
- `normalizeEdits(input): EditOps` — used server-side before persisting. Clamps: rotate snapped to nearest 90 then mod-360 normalized; crop validated (all four finite), `x,y` clamped 0..1, `w` clamped `[0.01, 1-x]`, `h` `[0.01, 1-y]`, and **a full-frame crop (x=y=0, w≥0.999, h≥0.999) collapses to `null`**; brightness/contrast `[0.2,2]→1`, saturation `[0,2]→1`, vibrance/warmth `[-1,1]→0`; unknown filter → 'none'.
- `isEdited(o)` — true if any field deviates from `DEFAULT_EDITS`.
- `cssFilterFor(o)` — approximate CSS `filter` string for the live client preview (geometry handled separately by the editor's transform/overlay; sharp render is source of truth on save). Builds `brightness/contrast/saturate` (saturate = `saturation*(1+vibrance*0.5)`) then folds presets: vivid (saturate×1.3, contrast×1.08), warm (sepia 0.25, saturate×1.05), cool (hue-rotate −12, saturate×1.02), fade (contrast×0.85, brightness×1.05, saturate×0.85), mono (grayscale 1), sepia (sepia 0.6), noir (grayscale 1, contrast×1.2), auto (contrast×1.05). Warmth: `>0` adds `min(1, sepia + warmth*0.3)`, `<0` adds `warmth*12` to hue-rotate. Numbers fixed to 3 decimals (hue-rotate to 1); grayscale/sepia/hue-rotate parts only appended when non-zero.

## 5. Scan subsystem

The scan subsystem discovers media on disk, reconciles it into the SQLite `media`/`roots` tables, and hands pending work to the media pipeline (Section on media/pipeline). All five files live in `src/lib/server/scan/`. Build them in dependency order: `scanState.ts` (no deps) → `pairing.ts` (deps: `db`) → `walker.ts` (deps: `$shared/types`) → `watcher.ts` (deps: walker-adjacent helpers, `scanState`, `pairing`, lazy `media/pipeline`) → `scanner.ts` (orchestrator; depends on all of the above plus `config`, `db`, `lock`, `paths`, lazy `media/pipeline` + `geo/geocodeService`).

Cross-cutting decisions a rebuilder MUST honor:

- **Path storage format is canonical and load-bearing.** Every path stored in the DB is forward-slash separated with a lower-cased Windows drive letter (e.g. `c:/photos/a.jpg`). The walker's `toStored()` and `paths.normalizePath()` must produce byte-identical output or the incremental diff (`getByPath`), the `ON CONFLICT(path)` upsert, and the watcher's `findByPath` all silently break.
- **All DB writes that can race with user mutations go through `withLock` (Section: lock).** The scanner batch-flush, the stale-sweep delete, and the watcher flush all run their transaction inside `withLock(...)`. The lazy-`import()` pattern (`await import('../media/pipeline')`) is deliberate: it lets the scan subsystem boot before the pipeline module exists and keeps pipeline failures non-fatal to scanning.
- **Offline-root protection is the central safety invariant.** A drive being unplugged or a NAS being offline must NEVER cause media rows, favorites, albums, or metadata to be deleted. This shapes `reconcileRoots`, the per-root `rootReachable` gate, and the stale-sweep's `fileGone`/`is_trashed` filters.

### 5.1 scanState.ts — in-memory progress + SSE fan-out

A single module-level `state: ScanState` object lives in the long-lived server process. Exposed via `GET /api/scan/status` (poll) and pushed over `GET /api/scan/stream` (SSE).

Initial state: `status:'idle'`, `scanId:null`, all counters `0` (`filesSeen/added/updated/removed/metaPending/thumbsPending/throughputPerSec`), `etaMs:null`, `startedAt/finishedAt/error/currentRoot` all `null`.

Exports:

- `getScanState(): ScanState` — returns a **shallow copy** (`{ ...state }`) so callers can't mutate internal state.
- `subscribeScan(fn): () => void` — adds listener to a `Set<Listener>`, immediately calls `fn(getScanState())` once, returns an unsubscribe closure.
- `patchScan(p: Partial<ScanState>)` — `Object.assign(state, p)` then `notify()`.
- `bumpScan(field, by=1)` — increments one of `'filesSeen'|'added'|'updated'|'removed'` then `notify()`.
- `setPending(metaPending, thumbsPending)` — sets both counts, calls `recomputeEta()`, `notify()`.
- `recordProcessed(n=1)` — feeds the rolling throughput window then `recomputeEta()`, `notify()`.

**Notify coalescing (gotcha):** `notify()` uses a `notifyScheduled` boolean + `queueMicrotask` so a burst of `bumpScan` calls within one tick emits exactly **one** snapshot to listeners. Each listener call is wrapped in `try/catch` so one dead SSE connection cannot break the others.

**Rolling throughput / ETA algorithm (exact):**
- `RATE_WINDOW_MS = 30_000`.
- `rate = { samples: {t,total}[], total: number }`. `recordProcessed(n)`: `rate.total += n`; push `{t:now, total:rate.total}`; then `while (samples.length > 1 && now - samples[0].t > 30000) samples.shift()` (always keeps at least one sample).
- `recomputeEta()`: if no samples → `throughputPerSec=0, etaMs=null`. Else `dt=(now-first.t)/1000`, `dn=rate.total-first.total`, `throughputPerSec = dt>0 ? dn/dt : 0`. `etaMs` = `round(thumbsPending/throughputPerSec*1000)` when rate>0 and `thumbsPending>0`; `0` when `thumbsPending===0`; otherwise `null`.

### 5.2 pairing.ts — Live/Motion photo pairing

`pairLivePhotos(db): number` runs ONE bulk `UPDATE media SET live_partner_id = (correlated subquery)` over all `is_trashed = 0` rows. The subquery picks the lowest-`id` partner row `m2` such that: same `dir`, different `id`, different `type` (so a photo pairs only with a video and vice-versa), `m2.is_trashed = 0`, and **case-insensitive basename match**: `lower(substr(filename, 1, length(filename) - length(ext) - 1))` equal on both rows. The `ext` column stores the extension **without** the leading dot, so the basename length subtracts `length(ext) + 1` (the `+1` is the dot). Returns `info.changes`. Called after every scan and after every watcher flush.

### 5.3 walker.ts — iterative streaming directory walk

`walkRoot(rootNormalized, opts, onError?)` is an `async function*` yielding `WalkEntry { path, mtimeMs, sizeBytes, ext, type }`. It uses an explicit `stack: string[]` (LIFO) seeded with the root, popping dirs and streaming entries via `fs.promises.opendir(cur)` — bounded memory on huge trees. A failed `opendir` (permission denied / vanished) is reported via `onError?.(cur, err)` and skipped (`continue`), never fatal; same for the per-entry `stat` and symlink-`stat` failures.

`WalkOptions`: `include: string[]`, `exclude: string[]`, `imageExtensions: Set<string>`, `videoExtensions: Set<string>`, `followSymlinks: boolean`, `skipDirs?: string[]`.

Per-entry logic (order matters):
1. Build `full = toStored(path.join(cur, ent.name))` and `rel` (path relative to root, or just `ent.name` if it doesn't start with `rootNormalized + '/'`).
2. Determine `isDir`/`isFile`. If `ent.isSymbolicLink()`: skip entirely unless `followSymlinks`; otherwise `fs.promises.stat(full)` (follows link) to resolve dir/file, error→`onError`+skip.
3. **Directory skipping:** skip if `ent.name.startsWith('.')` (dotdirs) OR `JUNK_DIRS.has(lower)` OR `skip.has(full.toLowerCase())`. Otherwise push onto stack.
4. Non-files are skipped.
5. **Extension/type gate:** `ext` = substring after last `.`, lower-cased (`''` if none). `type = imageExtensions.has(ext) ? 'photo' : videoExtensions.has(ext) ? 'video' : null`; skip if `null`.
6. **Glob gate:** skip unless `matchesAny(includeRes, rel)`; skip if `matchesAny(excludeRes, rel)`.
7. `stat(full)` → yield `{ path: full, mtimeMs: Math.round(st.mtimeMs), sizeBytes: st.size, ext, type }`. Note `mtimeMs` is **rounded** to an integer — this must match the watcher's `Math.round(st.mtimeMs)` or every watched file would falsely diff as "changed".

`JUNK_DIRS` (exact, lower-cased Set): `@eadir`, `#recycle`, `$recycle.bin`, `system volume information`, `node_modules`, `.git`.

`toStored(abs)`: `.replace(/\\/g,'/')` then `.replace(/^([a-zA-Z]):\//, d => d.toLowerCase()+':/')`.

**Glob engine (`globToRegExp`) — hand-rolled, must reproduce exactly:**
- `**/` → `(?:.*/)?` (zero or more leading dirs), advance `i += 2`.
- `**` (not followed by `/`) → `.*` (matches across slashes), advance `i += 1`.
- `*` → `[^/]*` (no slash).
- `?` → `[^/]`.
- Regex specials in `.+^${}()|[]\` are backslash-escaped (slash stays literal).
- Final regex: `^...$`, with the **`i` (case-insensitive) flag on Windows only** (`isWin = process.platform === 'win32'`).
- `compileGlobs` maps the array; `walkRoot` defaults `include` to `['**/*']` when empty; `matchesAny` short-circuits.

### 5.4 scanner.ts — orchestrator

Module constant `BATCH = 1000`. Module state: `running` (boolean lock), `rescanQueued: null | {reason, full}`, `backstopTimer: interval | null`.

**`reconcileRoots(db)`** — align `roots` table with config; called at startup and on config save:
- Upsert each configured root: `INSERT INTO roots(path,label,enabled,online) VALUES(...,1) ON CONFLICT(path) DO UPDATE SET label=excluded.label, enabled=excluded.enabled`. (Note: `online` is set to `1` only on first insert; conflict-update does NOT touch `online`.)
- Find `staleRows` = roots whose `path NOT IN (configured paths)` (or ALL roots if config has none).
- **Purge-vs-disable decision (critical safety):** for each stale root, if `rootReachable(path)` (i.e. `fs.statSync(path).isDirectory()`) → mark for **deletion** (`stale.push`). If unreachable → `UPDATE roots SET enabled=0, online=0` and **keep the index** (log a warning). Rationale: a momentarily-offline drive/NAS or a path-normalization drift at config-save time must not nuke a root's media/favorites/albums.
- Collect `staleMedia` ids before deletion, run a transaction that upserts all configured roots and `DELETE FROM roots WHERE id=?` for each truly-stale root (FK **cascade** removes the media rows). After the tx, call `deleteThumbs(id)` for each removed media id (filesystem cleanup outside the tx). Then `bustBucketsCache()`.

**`walkOptions()`** — pulls `include/exclude/imageExtensions/videoExtensions/scan.followSymlinks` from config and sets `skipDirs: [resolve(cwd,'data') normalized+lower]` so the app's own `data/` (DB, thumbs, trash) is never indexed.

**Helpers:** `getRootRows(db)` = `SELECT id,path FROM roots WHERE enabled=1`. `setRootOnline(db,id,bool)`. `rootReachable(p)` = `fs.statSync(p).isDirectory()` in try/catch→false. `deleteThumbs(id)` rmSync (force) of `grid`, `grid2x`, `preview` thumbs + storyboard. `fileGone(p)` = stat in try/catch; returns `false` if stat succeeds, and `true` ONLY when the caught error's `.code === 'ENOENT'` — a temporarily-inaccessible file (EACCES, EBUSY, offline) returns `false` and is NOT swept. `updatePendingCounts(db)` counts `is_trashed=0 AND meta_status IN (0,1)` and `... thumb_status IN (0,1)`, then `setPending`.

**`runScan(full)`** — the core pass:
1. `INSERT INTO scans(started_at,status) VALUES(?,'running')`; capture `scanId = lastInsertRowid`.
2. `patchScan({status:'running', scanId, counters reset, startedAt, ...})`.
3. Prepare statements: `getByPath` (`SELECT id,mtime_ms,size_bytes FROM media WHERE path=?`), `insertMedia` (full INSERT with `taken_source='mtime', meta_status=0, thumb_status=0, scan_id=@scan_id`), `updateChanged` (resets `meta_status=0, thumb_status=0`, restamps `taken_ms=@mtime_ms`/`taken_local_day`/`taken_source='mtime'`, sets `scan_id`), and `stampScan` (`UPDATE media SET scan_id=@scan_id WHERE id=@id` — touches nothing else).
4. **Early pipeline kick:** before the walk, `kickPipeline = (await import('../media/pipeline')).processPending` (try/catch). A `pipelineKicked` flag ensures it fires exactly once — right after the FIRST batch flush — so thumbnailing overlaps the (possibly long) walk rather than waiting for full enumeration.
5. For each enabled root (`getRootRows`): if `!rootReachable` → `setRootOnline(false)`, log, `continue` (offline roots retain their index and are excluded from the sweep). Else `setRootOnline(true)`, push id to `onlineRootIds`, `patchScan({currentRoot})`.
6. Walk with `walkRoot(root.path, opts, onError=log.warn)`. For each entry: `existing = getByPath.get(path)`, push `{row: toRow(entry), existing}` to `buffer`. When `buffer.length >= BATCH`, `await flush()` then `await new Promise(r => setImmediate(r))` to yield the event loop.
7. **`flush()`** swaps the buffer, captures `now=Date.now()`, runs `withLock(() => db.transaction(...))`. Per item the **incremental diff** is: no `existing` → `insertMedia` + `bumpScan('added')`; `existing.mtime_ms !== row.mtime_ms || existing.size_bytes !== row.size_bytes` → `updateChanged` + `bumpScan('updated')`; otherwise → `stampScan` only (just stamps `scan_id`, leaving status/metadata intact). Always `bumpScan('filesSeen')`. The `.then()` after the lock performs the one-time early pipeline kick. (Note: `full` is NOT used to force a re-thumbnail — the diff is purely path+mtime+size; `full` only affects which queued pass runs, see `requestRescan`.)
8. `toRow(e)` derives `dir`/`filename` from the last `/`, computes `rel_path` (relative to `root.path + '/'` or bare filename), sets `taken_ms=mtimeMs`, `taken_local_day=localDayFromMs(mtimeMs)`.
9. **Stale-sweep** (only if `getConfig().scan.removeMissing && onlineRootIds.length`): select rows `WHERE (scan_id IS NULL OR scan_id != ?) AND is_trashed=0 AND root_id IN (online ids)`. Filter to `missing = stale.filter(r => fileGone(r.path))`. Delete those under `withLock` in a transaction, `deleteThumbs` each, `patchScan({removed})`. Rows that are unmatched-but-still-on-disk (e.g. newly excluded by a filter change) are KEPT and logged; trashed rows and offline-root rows are never touched.
10. **Pairing:** lazy `import('./pairing').pairLivePhotos(db)` in try/catch.
11. Finalize: `UPDATE scans SET finished_at,status('done'|'error'),files_seen,added,updated,removed,error` from current `getScanState()`; `patchScan({status,finishedAt,error,currentRoot:null})`; `updatePendingCounts`; `bustBucketsCache`; log.
12. Post-scan kicks (lazy, non-fatal): `media/pipeline.processPending()` and `geo/geocodeService.geocodePending()`.

**`requestRescan({reason, full?})`** — coalescing queue. If `running`, set `rescanQueued = {reason, full: full || prior.full}` (full is **sticky** — once any queued pass wants full, it stays full) and return. Otherwise set `running=true` and run an async IIFE: `await runScan(full)`, then drain `while (rescanQueued)` running each queued pass, `finally running=false`. `isScanning()` returns `running`.

**`bootScan()`** (once at startup):
1. `count = SELECT COUNT(*) FROM media`; `updatePendingCounts(db)`.
2. Lazy import `media/pipeline`: call `resetStuckProcessing(db)` first (reclaims rows a prior crash left in `status=1` / mid-flight by resetting them to pending), then `processPending()`.
3. **Back-stop interval:** if `!backstopTimer`, `setInterval` every `5*60_000` ms that checks `SELECT 1 FROM media WHERE is_trashed=0 AND (meta_status IN (0,1) OR thumb_status IN (0,1)) LIMIT 1` and calls `processPending()` if any pending — guards against a worker crash stranding the backlog. `backstopTimer.unref?.()` so it doesn't keep the process alive.
4. If `getConfig().scan.onStartup || count === 0` → `requestRescan({reason: count===0 ? 'empty-index' : 'startup'})`.
5. Lazy `geocodePending()` (no-op unless geocoding enabled).
6. Lazy `startWatcher()` (try/catch, non-fatal).

### 5.5 watcher.ts — optional chokidar live indexer

Gated by `scan.watch`. Module state: `watcher: FSWatcher|null`, `pending = Map<string,'upsert'|'remove'>`, `flushTimer`.

**`startWatcher()`**: `stopWatcher()` first (idempotent restart). Return early if `!cfg.scan.watch`. `roots = getEnabledRoots()` filtered to those that `fs.statSync(r).isDirectory()`; return if none. `chokidar.watch(roots, { ignoreInitial:true, persistent:true, followSymlinks: cfg.scan.followSymlinks, awaitWriteFinish:{ stabilityThreshold:800, pollInterval:100 }, ignored: p => /[\\/](\.|@eaDir|#recycle|\$RECYCLE\.BIN|node_modules)/i.test(p) })`. Wire `add`→`queue(p,'upsert')`, `change`→`queue(p,'upsert')`, `unlink`→`queue(p,'remove')`, `error`→`log.warn`. **`awaitWriteFinish`** is essential so partially-copied files aren't indexed mid-write. `stopWatcher()`: close watcher, null it, `clearTimeout(flushTimer)`.

**`queue(abs, kind)`**: cheap ext gate — for `'upsert'`, drop immediately if `!mediaType(extOf(abs))`. `pending.set(abs, kind)` (later event for a path overwrites earlier), then `scheduleFlush()`.

**`scheduleFlush()`**: debounce — `clearTimeout` then `setTimeout(flush, 600)` (600 ms).

**`flush()`** (under `withLock`):
- Snapshot+clear `pending`.
- Upsert SQL: `INSERT INTO media(...) VALUES(...,scan_id=NULL,...) ON CONFLICT(path) DO UPDATE SET size_bytes,mtime_ms,meta_status=0,thumb_status=0,taken_ms=@mtime,taken_local_day,taken_source='mtime',updated_at`. Note watcher-inserted rows have `scan_id = NULL`.
- For `'remove'`: `findByPath = SELECT id,is_trashed FROM media WHERE path=?`. Skip (continue) if: not indexed; `row.is_trashed` (the file was moved to `data/trash` by `trash()` — the row must stay restorable); or **`fs.existsSync(abs)` still true** (guards against spurious/atomic-rename unlink events where the file is immediately re-created). Otherwise `del.run(id)` + `deleteWatchThumbs(id)`.
- For `'upsert'`: `rootFor(db,norm)` (first enabled root where `isWithin(norm, r.path)`); skip if none. `fs.statSync` → skip if not a file. Re-derive `ext`/`type` (skip non-media), `splitPath(root.path,norm)`, run upsert with `mtime: Math.round(st.mtimeMs)`. Per-file errors are `log.debug` and swallowed.
- After the lock: `bustBucketsCache()`; lazy `pairLivePhotos(db)`; lazy `processPending()`; then `patchScan({metaPending, thumbsPending})` (recount via the same two COUNT queries) to nudge the UI progress chip; `log.info`.

`deleteWatchThumbs(id)` is identical to scanner's `deleteThumbs` (grid/grid2x/preview + storyboard, rmSync force). `mediaType(ext)` consults `config.imageExtensions`/`videoExtensions`. `extOf` = substring after last `.`, lower-cased.

### 5.6 Gotchas summary

- `mtimeMs` is rounded (`Math.round`) in BOTH walker and watcher; the diff compares the rounded value against the stored `mtime_ms`. Don't store raw float mtimes.
- The early pipeline kick fires exactly once (after first batch) via the `pipelineKicked` flag; the post-scan `processPending()` is a separate, additional call.
- The sweep deletes ONLY `ENOENT`-confirmed files in online roots, never trashed rows, never offline-root rows, never merely-filtered rows. `scan.removeMissing` must be enabled for any deletion.
- `reconcileRoots` purges a de-configured root's media only when the folder is currently reachable; otherwise it disables and keeps the index.
- All path normalization (forward slash + lower-cased drive) must be byte-consistent between `walker.toStored` and `paths.normalizePath`, or incremental diffs and `ON CONFLICT(path)` break.
- Watcher rows carry `scan_id = NULL`; a subsequent full/incremental scan will re-stamp them (the `scan_id IS NULL` clause in the sweep means an un-stamped watcher row is only ever removed if its file is genuinely gone).

```markdown
## 6. Media pipeline, worker-thread pool & media services

This is the performance-critical core that scales to ~200k-item libraries. The governing
principle is a strict division of labor: **the main thread owns every `better-sqlite3` write**
(it is single-threaded), metadata extraction (exif/ffprobe + quick-hash) runs on the main thread,
and the **CPU-heavy image resize + blurhash is fanned out to a `worker_threads` pool** so all
cores decode in parallel. If the pool can't start, the same render code runs in-process as a
transparent fallback. There must be exactly **one** image-render implementation shared by the
worker, the in-process fallback, and vitest — hence the `.mjs` render core.

Build these files in dependency order: `render-core.mjs` → `thumb-worker.mjs` → `thumbnailService.ts`
→ `workerPool.ts`, then the standalone services (`exifService.ts`, `hashService.ts`,
`videoService.ts`) plus `editService.ts` (non-destructive edits — exports `renderEditedThumbs`/`exportEditedCopy`, dynamically imported by `pipeline.ts` and the `/edit` endpoints), then `pipeline.ts` (which wires them together), and finally `fileService.ts`
and `streamService.ts`. `paths.ts` (sharding) and `config-schema.ts` (defaults) are prerequisites
from earlier sections.

Exact runtime dependency versions (from `package.json`, all SSR-external):
`sharp ^0.35.1`, `blurhash ^2.0.5`, `exifr ^7.1.3`, `fluent-ffmpeg ^2.1.3`,
`ffmpeg-static ^5.3.0`, `ffprobe-static ^3.1.0`, `better-sqlite3 ^12.11.1`.

### 6.1 Thumbnail sizing & status model (config + paths)

These constants are load-bearing across the whole pipeline. From `config-schema.ts`
(`thumbnails` block, all Zod `.default(...)`):

- `dir = 'data/thumbnails'`, `format = 'webp'` (literal).
- `grid.longEdge = 320`, `grid.quality = 70`.
- `preview.longEdge = 1600`, `preview.quality = 80`.
- `eagerPreview = false` — the 1600px preview is **deferred** (lazy) for photos by default.
- `videoFrameAtPercent = 10`, `videoStoryboardFrames = 5`.

`scan` block defaults relevant here: `concurrency = 0` (auto), `useWorkers = true`,
`workerCount = 0` (derive), `maxAttempts = 3`.

The `grid2x` size is **not** a config field — it is derived in `render-core.mjs` as
`gridLongEdge * 2` (640) at `quality = max(60, gridQuality - 5)` (= 65). It exists for
retina/4K grids.

**Status integers** (used throughout `media.meta_status` / `media.thumb_status`):
`0` = pending, `1` = processing (transient/in-flight), `2` = done, `3` = failed.
The retry columns are `meta_attempts` / `thumb_attempts` and a shared `next_retry_ms`
(schema v3). GOTCHA: there is one `next_retry_ms` column shared by both stages; the metaFail
and thumbFail updates both write it.

**Cache layout (sharding)** from `paths.ts` / mirrored in `render-core.mjs`:
`thumbShard(id) = (id & 0xff).toString(16).padStart(2,'0')` (256 shards), and
`thumbPath = <resolve(cwd, dir)>/<shard>/<id>_<size>.webp`. The shard derivation MUST be
byte-identical between `paths.ts` (`thumbShard`/`thumbPath`) and `render-core.mjs`
(`thumbShard`/`thumbPathFor`) or the worker writes to a different file than the server reads.

### 6.2 `src/lib/server/media/render-core.mjs` — the single shared render core

**WHY a plain `.mjs`** (this is the central design decision, do not "TypeScript-ify" it):
this module is imported **raw by the worker thread** under Node (no Vite/TS transform at worker
load time), **bundled into the SSR server build** for the in-process/fallback path, AND imported
by vitest. Authoring it as plain ESM with `// @ts-check` JSDoc types and importing **only**
`node:fs`, `node:path`, `sharp`, and `blurhash` (no app/TS-only imports) guarantees one
implementation that the worker and the fallback can never drift apart on. Metadata extraction
(exif/ffprobe) deliberately stays out of here — it lives in the TS services on the main thread.

Exports (signatures matter — `workerPool`, `thumbnailService`, and tests all bind to them):

- `thumbShard(id)` → 2-hex string (mirrors `paths.ts`).
- `thumbPathFor(dir, id, size)` → absolute `.webp` path.
- `renderSizesFromPipeline(base, id, cfg, sizes)` → `Promise<string|null>` (blurhash). Builds a
  `targets` map for `grid`/`grid2x`/`preview`, does **one** `mkdir(recursive)` on the shared shard
  dir, then for each requested size `base.clone().resize(edge, edge, { fit:'inside',
  withoutEnlargement:true }).webp({ quality }).toFile(file)`. Exported so the non-destructive
  editor can render derivatives from an already-transformed pipeline.
- `renderImageThumbs(srcPath, id, cfg, sizes)` → `{width,height,blurhash}`. Opens
  `sharp(srcPath, { failOn:'none', animated:false }).rotate()` (auto-orient FIRST), reads
  `metadata()` separately, renders sizes, then **swaps width/height when
  `meta.orientation >= 5`** (EXIF 5–8 = 90°/270°) to report post-rotation display dimensions.
- `renderThumbsFromBuffer(buffer, id, cfg, sizes)` → for video poster frames (no orientation swap).
- `renderOneSize(srcPath, id, size, cfg)` → renders a single size with no DB write (deferred
  preview generate-on-miss path).

`computeBlurhash(img)` (internal): `resize(32,32,{fit:'inside'}).raw().ensureAlpha()
.toBuffer({resolveWithObject:true})` then `blurhashEncode(..., 4, 3)` (4×3 components). Returns
`null` on any failure (never throws).

GOTCHA: `RenderCfg` here is a **plain structural** shape (`dir, gridLongEdge, gridQuality,
previewLongEdge, previewQuality`) — NOT the nested app config. `thumbnailService.renderCfg()`
flattens the app config into this shape; the worker receives it via `workerData`.

### 6.3 `src/lib/server/media/thumb-worker.mjs` — worker_threads entry

Self-contained worker entry. Imports only `node:worker_threads`, `sharp`, and
`./render-core.mjs` (so it loads identically under `vite dev` and `node build`). Critical line:
`sharp.concurrency(1)` — one libvips thread per worker, so N workers × 1 = N parallel decodes
with **no libuv threadpool oversubscription**.

Reads `cfg = workerData?.renderCfg` once at startup. Message protocol:
- parent posts `{ taskId, id, srcPath, sizes }`
- replies `{ taskId, ok:true, width, height, blurhash }` on success
- replies `{ taskId, ok:false, error }` on a **decode failure** (a bad file — NOT an infra crash;
  the distinction drives the pool's requeue logic).

It calls `renderImageThumbs(task.srcPath, task.id, cfg, task.sizes)` and never touches the DB.

### 6.4 `src/lib/server/media/thumbnailService.ts` — main-thread / fallback wrapper

Thin TS wrapper over `render-core.mjs` for the main thread. Exports:

- `ALL_SIZES = ['grid','grid2x','preview']`, `EAGER_SIZES = ['grid','grid2x']` (render order;
  `preview` is the deferred one). These two arrays gate the eager/lazy split in the pipeline.
- `renderCfg()` — flattens `getConfig().thumbnails` into the plain `RenderCfg`.
- `makeImageThumbs(srcPath, id, sizes=ALL_SIZES)` → `renderImageThumbs(...)`.
- `makeThumbsFromBuffer(buffer, id, sizes)` → `renderThumbsFromBuffer(...)` (videos).
- `ensureImageSize(srcPath, id, size)` → `renderOneSize(...)` (one deferred size, no DB write).
- `thumbExists(id, size)` → `fs.existsSync(thumbPath(...))`.

GOTCHA: RAW/HEIC that libvips can't decode throw here and are recorded as a thumb failure
(status 3, retried with backoff).

### 6.5 `src/lib/server/media/workerPool.ts` — hand-rolled worker pool

A ~120-line single-task-type pool (deliberately not a generic library — keeps deps lean and
sidesteps adapter-node bundling fragility). Module-level state: `workers: Worker[]|null`,
`available=true`, `seq` (taskId counter), `idle: Worker[]`, `busy: Map<Worker,Job>`,
`queue: Job[]`. `MAX_REQUEUE = 3`.

- **`resolveWorkerPath()`** — try candidates **in order**: (1) `resolve(cwd,
  'src/lib/server/media/thumb-worker.mjs')` FIRST (this app's run-from-source deploy has `src/`
  at cwd), then (2) `fileURLToPath(new URL('./thumb-worker.mjs', import.meta.url))` (sibling).
  Returns `null` if neither exists → pool permanently disabled, in-process fallback used.
- **`desiredCount()`** — `scan.workerCount` if > 0, else `scan.concurrency` if > 0, else
  `max(1, cores - 1)`.
- **`spawn(workerPath, cfg)`** — `new Worker(workerPath, { workerData: { renderCfg: cfg } })`.
  On `message`: pull the `Job` off `busy`, push worker back to `idle`, resolve the job with the
  reply, `dispatch()`. On **death** (`error`, or `exit` with non-zero code) via `onDeath(why)`:
  remove worker from `busy`/`idle`/`workers`; if a job was in flight it is an **infra failure**,
  so **re-queue** it (`job.attempts++`, `queue.unshift(job)`) unless `attempts >= MAX_REQUEUE`
  (then resolve `{ok:false, error:'thumb worker repeatedly failed: ...'}`); then **respawn** a
  replacement to keep the pool full (unless shutting down). If respawn itself throws → `disablePool()`.
  This re-queue-vs-resolve split is the decode-failure (`{ok:false}` reply, surfaced to caller) vs
  worker-crash (re-queued) distinction — honor it.
- **`ensurePool()`** — lazy init: if `workers` exists return true; if `!available` return false;
  resolve path (disable if missing); spawn `desiredCount()` workers into `workers`+`idle`; logs
  `Thumbnail worker pool started (N workers).`.
- **`dispatch()`** — while there's an idle worker and a queued job, pair them, set `busy`, and
  `postMessage({ taskId: seq++, id, srcPath, sizes })`.
- **`poolAvailable()`** → `available && ensurePool()`. Pipeline calls this **once per row**.
- **`runThumbTask(task)`** → if not available, resolves `{ok:false, error:'pool unavailable'}`
  (the **"C4 fallback" sentinel** the pipeline keys on); otherwise pushes a `Job{task,resolve,
  attempts:0}` and dispatches.
- **`disablePool()`** / **`shutdownPool()`** — both set `available=false`, null `workers`, clear
  `idle`/`busy`, terminate workers; `shutdownPool` awaits termination (graceful shutdown).

### 6.6 Metadata services (main thread)

**`exifService.ts`** — `extractImageMeta(filePath, mtimeMs)` via `exifr.parse` with options
`{ gps:true, translateValues:false, reviveValues:true, pick:[DateTimeOriginal, CreateDate,
ImageWidth, ImageHeight, ExifImageWidth, ExifImageHeight, Make, Model, LensModel, Orientation,
latitude, longitude] }`. **`translateValues:false` is critical** — it keeps `Orientation`
numeric (1–8), not a translated string. Date policy: `DateTimeOriginal` (fallback `CreateDate`)
is read as a `Date` whose **local** components are the original wall-clock, then re-anchored to
UTC ms via `wallClockToMs(...)` (no timezone shift) — so day grouping needs zero runtime tz math;
`taken_source='exif'`. If no EXIF date, fall back to `mtimeMs` with `taken_source='mtime'`.
Orientation 5–8 → swap width/height (display dims for the justified grid). GPS recorded only when
both lat/lon are numbers and not `(0,0)`. Camera make/model/lens trimmed, empty → null. Never
throws (catches to `EMPTY`).

**`hashService.ts`** — `quickHash(filePath, size)`: SHA-1 of the head (first 64KiB) plus, when
`size > 64KiB`, the **tail** (last up-to-64KiB), prefixed with size →
`"<size>-<sha1hex>"`. `CHUNK = 65536`. Cheap exact-duplicate candidate key; the dedupe UI groups
by it for user review, never auto-deletes.

**`videoService.ts`** — uses `fluent-ffmpeg` with the bundled static binaries (no system ffmpeg).
`ensureConfigured()` (idempotent, run once) sets `ffmpeg.setFfmpegPath(ffmpegStatic)` and
`ffmpeg.setFfprobePath(ffprobeStatic.path)`. `probeVideo(srcPath)` → `{width,height,durationMs,
codec}` from the first `codec_type==='video'` stream; `durationMs = round(format.duration*1000)`;
**never rejects** (resolves all-null on error). `makeVideoThumbs(srcPath, id, durationMs,
sizes=ALL_SIZES)`: seek to `(durationMs/1000) * videoFrameAtPercent/100` (0 if unknown), extract
**1 frame** (`-q:v 2`) to `os.tmpdir()/lg_poster_<id>_<pid>.png`, render all sizes off that single
buffer via `makeThumbsFromBuffer`, then `rm` the temp in `finally`. GOTCHA: videos are **not**
subject to the photo defer-preview split — one ffmpeg extract dominates the cost, so all sizes
are always rendered.

### 6.7 `src/lib/server/media/pipeline.ts` — drain loop & orchestration

Module state: `priority: Set<number>` (visible-range hints), `inFlight: Map<number,Promise>`
(per-id guard), `inFlightSize: Map<string,Promise>` (per-`id:size` guard), `draining` flag,
`lastPendingUpdate`. Prepared statements are cached per-DB in a `WeakMap` (`getStmts`).

**`setVisiblePriority(ids)`** — replaces the `priority` set and kicks `processPending()`. The
client reports its visible range to jump the queue.

**`retryBackoffMs(attempts)`** = `min(30*60_000, 30_000 * 2 ** max(0, attempts-1))` — capped
exponential: 30s, 60s, 120s, … capped at **30 minutes**. Exported for unit tests.

**`concurrency()`** — `scan.concurrency` if > 0; else with workers `max(2, cores)` (heavy decode
is off-thread, so keep more rows in flight to overlap metadata), without workers `max(1, cores-2)`
(leave HTTP headroom).

**`pendPredicateFor(max, now)`** (exported, parameterized for tests) — the SQL pend predicate:
```
(meta_status IN (0,1) OR thumb_status IN (0,1)
 OR (meta_status  = 3 AND meta_attempts  < <max> AND (next_retry_ms IS NULL OR next_retry_ms <= <now>))
 OR (thumb_status = 3 AND thumb_attempts < <max> AND (next_retry_ms IS NULL OR next_retry_ms <= <now>)))
```
GOTCHA: `max` and `now` are **string-inlined** (not bound), deliberately — they are safe computed
ints, and inlining avoids mixing named/positional binds with the `id IN (...)` lists.

**`selectPending(db, limit)`** — two queries unioned in JS:
1. The **priority slice** `[...priority].slice(0, 400)` (cap bound-vars well under SQLite's limit
   even if a huge visible range was reported): `WHERE id IN (...) AND is_trashed=0 AND <pend>
   ORDER BY taken_ms DESC, id DESC LIMIT ?`.
2. If still under `limit`, the general backfill: same predicate, `AND id NOT IN (<already seen>)`,
   `ORDER BY taken_ms DESC, id DESC` (**newest-first**), filling the remainder.
Finally filters out any row already in `inFlight` so the drain and a concurrent `ensureThumb`
can't double-process.

**`doProcessRow(db, row)`** — runs both stages at most once:
- If `meta_status !== 2`: compute `quickHash` (swallow errors → null), then `extractImageMeta`
  (photo) or `probeVideo` (video), run the corresponding `photoMeta`/`videoMeta` UPDATE (sets
  `meta_status=2`), and update the in-memory `row` dims. On throw → `metaFail` UPDATE
  (`meta_status=3`, `meta_attempts+1`, `next_retry_ms = now + retryBackoffMs(meta_attempts+1)`).
- If `thumb_status !== 2`: `await makeThumbs(db, row)`.

**`makeThumbs(db, row)`** — the key branch. `eager = thumbnails.eagerPreview`;
`sizes = eager ? ALL_SIZES : EAGER_SIZES`.
- **Photo + has `edit_ops`**: render edits **on the MAIN thread** via dynamic
  `import('./editService').renderEditedThumbs(id, path, normalizeEdits(JSON.parse(edit_ops)),
  sizes)` (the worker only handles plain source images; editing is rare so this isn't a throughput
  concern). Then `thumbDone`.
- **Plain photo + `poolAvailable()`**: `runThumbTask({id, srcPath, sizes})`. If `r.ok` →
  `thumbDone`. If `r.error === 'pool unavailable'` → fall back to in-process
  `makeImageThumbs(path, id, sizes)` then `thumbDone`. Otherwise (a real decode failure) →
  `thumbFailed(r.error)`.
- **Plain photo, no pool**: in-process `makeImageThumbs` then `thumbDone`.
- **Video**: `makeVideoThumbs(path, id, duration_ms)` then `thumbDone`.
Any throw → `thumbFailed`.

`thumbDone(s,row,w,h,bh)` runs `thumbOk` (sets `blurhash`, `width=COALESCE(width,@width)`,
`height=COALESCE(height,@height)`, `thumb_status=2`) and **`recordProcessed(1)`** (scan-state
progress counter). `thumbFailed` runs `thumbFail` (status 3, attempts+1, backoff `next_retry_ms`).
`errMsg` truncates to 500 chars.

**`processRow(db,row)`** — wraps `doProcessRow` with the `inFlight` guard: returns the existing
promise if one is in flight, else stores `doProcessRow(...).finally(() => inFlight.delete(id))`.

**`runPool(db, rows, n)`** — N concurrent JS "workers" each pulling from the `rows` array via a
shared index, calling `processRow`.

**`processPending()`** — idempotent drain (no-op if `draining`). Loop: `selectPending(db, 64)`
(batch of 64), break when empty, `runPool(db, rows, concurrency())`, `updatePending(db)`. On
finally: `updatePending(db, true)`, clear `draining`, and **re-kick** if a late visible-range hint
queued more (`selectPending(db,1).length`).

**`updatePending(db, force=false)`** — throttled to **~1s** (`now - lastPendingUpdate < 1000`
short-circuits unless `force`). Counts `meta_status IN (0,1)` and `thumb_status IN (0,1)` (trashed
excluded), calls `setPending(meta, thumb)`, and `bustBucketsCache()` (metadata writes can change
`taken_local_day` → invalidate cached day buckets).

**`resetStuckProcessing(db)`** — called once at startup before the first drain: resets any
`meta_status=1`/`thumb_status=1` (stranded by a prior crash) back to `0`.

**Lazy generate-on-miss** (`ensureThumb` / `ensureSizeGuarded`):
- `ensureThumb(id, size='grid')` — loads the row; if `thumb_status !== 2` runs `processRow`
  (joins the background drain via the `inFlight` guard); then if `!thumbExists(id, size)` calls
  `ensureSizeGuarded(row, size)`. This is how the **deferred 1600px preview** is rendered on first
  lightbox open.
- `ensureSizeGuarded(row, size)` — per-`id:size` guard via `inFlightSize`: renders just that one
  size (`ensureImageSize` for photos, `makeVideoThumbs([size])` for videos) with **no status
  change**, swallowing errors to debug log.

### 6.8 `src/lib/server/media/fileService.ts` — file mutations

All real-file mutations (trash / restore / permanent-delete / move / rename) funnel through a
single in-process **mutex** (`withLock`, see lock section) so user actions never race the scanner
or each other; the DB row is updated in the **same logical step** as the FS change.

- **`moveFile(src,dest)`** — `mkdir -p` dest dir, try atomic `rename`. On **`EXDEV`** (cross-volume):
  copy to a temp `${dest}.lgpart-<pid>-<perf>` with `COPYFILE_EXCL`, atomic `rename` into place,
  then `unlink` the source last — so a crash mid-copy leaves at most a stray `.lgpart` temp
  (ignored by the scanner), never a half-written file or a lost source.
- **`uniquePath(target)`** — appends ` (n)` before the extension (n=1..999, then a timestamp).
- **`bulk(ids, op)`** — under `withLock`: per-id try/catch into `{ok[], failed[]}` (`BulkResult`);
  `bustBucketsCache()` if any succeeded.
- **`trash(ids)`** — `assertWithinRoots`, move to `<resolve(cwd, trash.dir)>/<id>__<filename>`,
  in a transaction INSERT a `trash` row (`media_id, original_path, trash_path, size_bytes,
  trashed_at`) and set `media.is_trashed=1`.
- **`restore(ids)`** — newest trash record per `media_id`, `uniquePath(original_path)`, move back,
  re-split the path against the owning root, transaction: UPDATE media (`is_trashed=0`, path/dir/
  filename/rel_path) + DELETE trash row.
- **`permanentDelete(ids)`** — `assertWithinRoots(..., [], [trashDir])`, `rm` trash files
  (best-effort), transaction DELETE trash + DELETE media, then **`deleteThumbFiles(id)`**.
- **`move(ids, destDir)`** — **`realPathWithinRoots(destDir)`** first (a symlink/junction inside a
  root can't redirect the write out), then per id move + re-derive `root_id` from the owning root.
- **`rename(id, newName)`** — rejects names containing `\` `/` `\0`, `''`, `.`, `..`; moves within
  the same dir; updates filename/rel_path/**ext**.
- **`deleteThumbFiles(id)`** — `rmSync(force)` on `grid`, **`grid2x`**, `preview`, and the
  `storyboardPath` (`<id>_sb.webp`). GOTCHA: must include `grid2x` or retina thumbs leak.
- **`autoPurgeTrash()`** — if `trash.autoPurgeDays` (default 30; 0 = never): permanentDelete trash
  older than the cutoff, plus reclaim orphaned trash rows (`media_id` NULL) keyed by `trash.id`.
- **`orphanThumbnailGc()`** — scan shard dirs, parse `^(\d+)_` from filenames, `rm` any whose
  media row no longer exists (crash cleanup).

### 6.9 `src/lib/server/media/streamService.ts` — range-aware original serving

`serveOriginal(db, id, request)` maps `id` → `media.path`, then **`realPathWithinRoots`**
(symlink-checked against the allow-list, with `getTrashDir()` as an extra allowed dir) before any
read — 403 on failure, 404 if the row or file is gone. Sets `etag = "o<id>-<mtimeMs>-<size>"`,
`accept-ranges: bytes`, `cache-control: private, max-age=86400`, `content-disposition: inline`.
Honors `if-none-match` → 304 (only when no Range). HTTP **Range → 206**: parses
`bytes=(\d*)-(\d*)`, supports suffix ranges `bytes=-N` (last N bytes, RFC 7233), clamps
start/end, returns **416** with `content-range: bytes */<size>` when unsatisfiable; otherwise a
`fs.createReadStream({start,end})` converted via `Readable.toWeb`. The 206 path is what makes
`<video>` seek instantly. MIME is looked up from a fixed extension map (images + common video
containers), default `application/octet-stream`.

### 6.10 libuv threadpool sizing (must be set before the server boots)

`sharp` and `ffmpeg` dispatch to the libuv threadpool, whose size is read **once** when libuv
first initializes — so `UV_THREADPOOL_SIZE` MUST be set before any threadpool task runs.

- **`start.mjs`** (production entry, `node start.mjs` / `bun run start`): a thin launcher that, if
  `UV_THREADPOOL_SIZE` is unset, sets it to `max(8, cores*2)` **before** `await
  import('./build/index.js')` (which boots adapter-node). Setting it after a threadpool task ran
  would be a no-op — hence the launcher sits in front of `build/index.js`.
- **`start-lgallery.cmd`** (Windows launcher): sets `UV_THREADPOOL_SIZE=16` (if unset), `PORT=4173`,
  `HOST=127.0.0.1`, `NODE_ENV=production`; builds on first run if `build\index.js` is missing
  (`bun run build`); opens the browser ~2s later; runs `node start.mjs`. Keep `PORT`/`HOST` in sync
  with `server.port`/`server.host` in the config.
```

```markdown
## 7. Read queries & the complete HTTP/API surface

This section documents the two halves of LGallery's data-serving layer: the read-query module (`src/lib/server/db/queries.ts`) that every GET endpoint funnels through, and the full set of `+server.ts` route handlers under `src/routes/api`. Build the query module first — many endpoints import directly from it — then the HTTP helpers, then the routes.

### 7.1 `src/lib/server/db/queries.ts` — read queries & row mappers

Responsibility: all SELECT-side data access plus the shared row mappers. The hot timeline path uses **prepared statements memoized per connection** (a `WeakMap<DB, Prepared>`), never `OFFSET` — pagination is **keyset** (seek) on `(taken_ms DESC, id DESC)`. Imports `DB` from `./index` and types from `$shared/types`.

Module-level constants & helpers a rebuilder must reproduce exactly:

- `const MAX_MS = Number.MAX_SAFE_INTEGER;` — the default cursor "start from the top" sentinel.
- `escapeLike(s)` — `s.replace(/[\\%_]/g, (c) => '\\' + c)`. Escapes SQLite LIKE metacharacters; always paired with `ESCAPE '\'` in the SQL. Used by `searchMedia` (camera) and `getFolder`.
- `const cache = new WeakMap<DB, Prepared>();` and `prep(db)` which lazily builds and memoizes the `Prepared` struct: `{ timeline, buckets, total, detail, detailAlbums, detailTags, pathById }`.
- `TIMELINE_COLS` (exported as a const string, reused verbatim across timeline/memories/duplicates/folder/person queries):
  ```
  id, type, width, height, taken_ms, taken_local_day, duration_ms, blurhash, is_favorite, live_partner_id, thumb_status
  ```
- `ALBUM_COLS` — the same 11 columns but **`m.`-prefixed** for the album/search joins.

#### Row mapper — `mapTimelineRow(r): TimelineItem` (exported)

Maps snake_case DB columns to camelCase `TimelineItem`. Key coercions a rebuilder must match exactly:
- `takenMs: r.taken_ms ?? 0` (defaults to 0, not null)
- `takenLocalDay: r.taken_local_day ?? ''` (empty string default)
- `isFavorite: !!r.is_favorite`, `thumbStatus: (r.thumb_status ?? 0) as StatusCode`
- `width/height/durationMs/blurhash/livePartnerId` default to `null`.

#### Keyset timeline — `getTimelinePage(db, opts)` (exported)

- `limit = Math.min(Math.max(opts.limit ?? 200, 1), 1000)` — clamped 1..1000, default 200. This clamp is repeated identically in `getAlbumPage` and `searchMedia`.
- `curMs = opts.curMs ?? MAX_MS; curId = opts.curId ?? MAX_MS`.
- SQL (prepared once): `WHERE is_trashed = 0 AND is_archived = 0 AND (taken_ms < @curMs OR (taken_ms = @curMs AND id < @curId)) ORDER BY taken_ms DESC, id DESC LIMIT @limit`.
- `nextCursor` is `{ curMs: last.takenMs, curId: last.id }` **only when `items.length === limit`** (full page); otherwise `null`. This is the universal "more pages exist" signal across all paginated queries.

#### Buckets + total cache — `META_TTL_MS` / `bustBucketsCache`

- Module-level `metaCache: { buckets, total, at } | null` with `const META_TTL_MS = 10_000` (10s).
- `bustBucketsCache()` (exported) sets `metaCache = null`. **GOTCHA:** callers must invoke this on any event that changes the timeline set — the bulk-archive PATCH does (`media/+server.ts`), and scanner/pipeline/fileService are expected to. The 10s TTL is only a backstop.
- `timelineMeta(db)` returns the cache if `now - at < META_TTL_MS`, else recomputes both:
  - `buckets` SQL: `SELECT taken_local_day AS day, COUNT(*) AS n FROM media WHERE is_trashed = 0 AND is_archived = 0 AND taken_local_day IS NOT NULL GROUP BY taken_local_day ORDER BY day DESC`. (This `GROUP BY taken_local_day` is the index-driven aggregate.)
  - `total` SQL: `SELECT COUNT(*) AS n FROM media WHERE is_trashed = 0 AND is_archived = 0`.
- Exposed via `getBuckets(db)` and `getTotalCount(db)`.

#### `getMediaDetail(db, id): MediaDetail | null`

- `prep.detail` = `SELECT * FROM media WHERE id = ?`; returns `null` if not found.
- Then runs `detailAlbums` (`SELECT a.id, a.name FROM albums a JOIN album_items ai ON ai.album_id = a.id WHERE ai.media_id = ? ORDER BY a.name`) and `detailTags` (`SELECT t.id, t.name FROM tags t JOIN media_tags mt ON mt.tag_id = t.id WHERE mt.media_id = ? ORDER BY t.name`).
- Spreads `mapTimelineRow(r)` then adds: `path, relPath (rel_path), dir, filename, ext, sizeBytes, mtimeMs, takenSource, cameraMake, cameraModel, lens, codec, orientation, hasGps (!!), gpsLat, gpsLon, isArchived (!!), isTrashed (!!), error, albums, caption, rating (?? 0), pick (?? 0), tags, placeName, placeLocality, placeCountry, editOps`.
- `editOps` via `parseEditOps(r.edit_ops)`: returns `null` if not a string; `JSON.parse` wrapped in try/catch returning `null` on failure. Typed as `$shared/edits` `EditOps`.

#### `getTags(db): Tag[]`

Counts exclude trashed media via a correlated subquery: `SELECT t.id, t.name, (SELECT COUNT(*) FROM media_tags mt JOIN media m ON m.id = mt.media_id WHERE mt.tag_id = t.id AND m.is_trashed = 0) AS count FROM tags t ORDER BY count DESC, t.name`. (Note: count excludes trashed but NOT archived.)

#### `getPlaces(db): PlaceGroup[]`

Geotagged media grouped by reverse-geocoded locality: `SELECT place_locality AS locality, place_country AS country, COUNT(*) AS count, MAX(id) AS sampleId FROM media WHERE is_trashed = 0 AND is_archived = 0 AND place_locality IS NOT NULL GROUP BY place_locality, place_country ORDER BY count DESC, locality`.

#### `searchMedia(db, f: SearchFilters): TimelinePage` — dynamic WHERE builder

`SearchFilters` fields: `q, from, to, type ('photo'|'video'), fav, archived, camera, hasGps, album, tag, rating, pick, place, curMs, curId, limit`.

Build algorithm (order matters for the generated SQL but not semantics):
1. `where = ['m.is_trashed = 0']`; `params = { curMs: f.curMs ?? MAX_MS, curId: f.curId ?? MAX_MS, limit }`; `join = ''`.
2. **FTS (`q`)**: if `f.q.trim()`, tokenize on `\s+`, strip `["*^]` from each token, drop empties, wrap each as `"token"*` (quoted prefix match), join with spaces. If any tokens survive: `join += ' JOIN media_fts ON media_fts.rowid = m.id'`, push `media_fts MATCH @q`, `params.q = match`.
3. `from` → `m.taken_ms >= @from`; `to` → `m.taken_ms <= @to`.
4. `type` → `m.type = @type`.
5. `fav` (truthy) → `m.is_favorite = 1`.
6. **archived is always constrained**: `where.push(f.archived === true ? 'm.is_archived = 1' : 'm.is_archived = 0')`. GOTCHA: search defaults to **excluding** archived unless explicitly `archived=true`.
7. `camera` → `m.camera_model LIKE @camera ESCAPE '\'` with `params.camera = '%' + escapeLike(f.camera) + '%'`.
8. `hasGps` → `m.has_gps = 1`.
9. `album` → `join += ' JOIN album_items ai ON ai.media_id = m.id'`, `ai.album_id = @album`.
10. `tag` → `join += ' JOIN media_tags mt ON mt.media_id = m.id'`, `mt.tag_id = @tag`.
11. `rating` (only if `> 0`) → `m.rating >= @rating`.
12. `pick` (only if `!== 0`) → `m.pick = @pick`.
13. `place` → `m.place_locality = @place` (exact match).
14. Finally push the keyset predicate: `(m.taken_ms < @curMs OR (m.taken_ms = @curMs AND m.id < @curId))`.

Final query: `SELECT ${ALBUM_COLS} FROM media m${join} WHERE ${where.join(' AND ')} ORDER BY m.taken_ms DESC, m.id DESC LIMIT @limit`. Same `nextCursor` rule as the timeline.

#### `getMemories(db, monthDay, year)`

"On this day": `SELECT ${TIMELINE_COLS} FROM media WHERE is_trashed=0 AND is_archived=0 AND taken_local_day IS NOT NULL AND substr(taken_local_day, 6, 5) = @md AND substr(taken_local_day, 1, 4) != @yr ORDER BY taken_local_day DESC, id DESC LIMIT 500`. Then groups rows into a `Map<year, items[]>` (year = `takenLocalDay.slice(0,4)`) and returns `[{ year, items }]`. `monthDay` is `MM-DD`; `year` passed as `String(year)`.

#### `getDuplicates(db)`

Two-phase. First: `SELECT quick_hash FROM media WHERE quick_hash IS NOT NULL AND is_trashed=0 GROUP BY quick_hash HAVING COUNT(*) > 1 LIMIT 500`. Then for each hash a reused prepared statement `SELECT ${TIMELINE_COLS} FROM media WHERE quick_hash = ? AND is_trashed=0 ORDER BY id`. Returns `[{ hash, kind: 'exact', items }]`.

#### `getMapClusters(db, bbox, zoom)`

- Base WHERE: `['has_gps=1','is_trashed=0','gps_lat IS NOT NULL','gps_lon IS NOT NULL']`. If `bbox` given, adds `gps_lat BETWEEN @minLat AND @maxLat AND gps_lon BETWEEN @minLon AND @maxLon`.
- Fetch up to `LIMIT 20000` points `(id, gps_lat AS lat, gps_lon AS lon)`.
- **Grid cluster algorithm**: `cell = 360 / Math.pow(2, Math.min(20, Math.max(1, zoom))) / 2`. Key = `` `${Math.floor(p.lon / cell)}:${Math.floor(p.lat / cell)}` ``. Accumulate summed lat/lon + count per cell; first point's id becomes `sampleId`. Emit `{ lat: sumLat/count, lon: sumLon/count, count, sampleId }`.

#### `getFolder(db, dir)` — one-level folder browser

- Always loads enabled roots: `SELECT id, path, label FROM roots WHERE enabled=1`.
- If `dir` is falsy: returns `{ dir: null, roots, subfolders: [], page: { items: [], nextCursor: null } }`.
- Subfolders (immediate children only) via `DISTINCT` + `instr/substr` to extract the next path segment after `dir + '/'`: filter `dir LIKE @like ESCAPE '\'` with `@like = escapeLike(dir) + '/%'`, `dir != @dir`, `name != ''`, `ORDER BY name`. Result deduped again in JS via `new Set(...)`.
- Media directly in `dir`: `SELECT ${TIMELINE_COLS} FROM media WHERE is_trashed=0 AND dir=@dir ORDER BY taken_ms DESC, id DESC LIMIT 500` → `page` with `nextCursor: null` (no pagination here).

#### `getAlbums(db)` / `getAlbumPage(db, albumId, opts)`

- `getAlbums`: `SELECT a.id, a.name, a.cover_media_id AS coverMediaId, a.created_at AS createdAt, a.sort_order AS sortOrder, (SELECT COUNT(*) FROM album_items ai WHERE ai.album_id = a.id) AS count FROM albums a ORDER BY a.sort_order, a.created_at DESC`.
- `getAlbumPage`: same clamp/cursor logic as timeline; `SELECT ${ALBUM_COLS} FROM media m JOIN album_items ai ON ai.media_id = m.id WHERE ai.album_id = @album AND m.is_trashed = 0 AND <keyset> ORDER BY m.taken_ms DESC, m.id DESC LIMIT @limit`. (Archived items ARE included in albums — only trashed excluded.)

#### `getTrash(db)`

`SELECT t.id, t.media_id AS mediaId, t.original_path AS originalPath, t.size_bytes AS sizeBytes, t.trashed_at AS trashedAt, m.filename FROM trash t LEFT JOIN media m ON m.id = t.media_id ORDER BY t.trashed_at DESC`. JS post-map: `filename ?? originalPath.split('/').pop() ?? 'file'`.

#### `getMediaPath(db, id)` (internal byte-serving helper)

`prep.pathById` = `SELECT path, type FROM media WHERE id = ?`; returns `{ path, type } | null`. Used by thumb/original/stream/export/edit-export endpoints.

### 7.2 `src/lib/server/http.ts` — shared HTTP helpers

- `initialGridWidth(cookies)`: reads the `lg_w` viewport cookie (set by the app.html boot script for SSR grid layout). Falls back to `1200` if absent/invalid. Subtracts sidebar (`64` if `w<=700`, else `216`) and `24` padding; clamps to `>= 280`.
- `apiError(status, code, message)`: returns `json({ error: { code, message } } satisfies ApiErrorBody, { status })`. The universal error envelope — `{ error: { code, message } }`.
- `parseIds(input)`: if `Array.isArray`, maps to `Number` and keeps only positive integers (`Number.isInteger(n) && n > 0`); otherwise returns `[]`.

### 7.3 Complete API endpoint surface (`src/routes/api/**/+server.ts`)

Auth model: mutations call `requireMutation(event)` from `$server/security`, which returns a `Response` (the guard) when rejected — the handler does `const guard = requireMutation(event); if (guard) return guard;`. Read (GET) endpoints are **public** unless noted. Login/logout additionally enforce `isSameOrigin(event)` (CSRF). All errors use `apiError`. Bad/missing ids return `BAD_ID`; empty id lists return `NO_IDS`.

| Method | Path | Auth | Behavior |
|---|---|---|---|
| GET | `/api/timeline` | public | `getTimelinePage` from `curMs`/`curId`/`limit` (limit default 200). Empty string params → `null`. |
| GET | `/api/timeline/buckets` | public | `{ buckets: getBuckets(db), total: getTotalCount(db) }` (cached). |
| POST | `/api/timeline/visible` | public | Body `{ ids }` → `setVisiblePriority(parseIds(ids))` (pipeline prioritizes visible thumbs). Returns `{ ok: true }`. No mutation guard. |
| PATCH | `/api/media` | requireMutation | Bulk update. Body `{ ids, favorite?, archived?, rating?, pick? }`. Builds `SET` from present fields: `is_favorite` (bool→1/0), `is_archived`, `rating` (`clamp 0..5, round`), `pick` (`>0→1, <0→-1, else 0`). Runs per-id in a transaction collecting `ok[]`/`failed[]` (`BulkResult`). Always sets `updated_at=@now`. If `archived` was set, calls `bustBucketsCache()`. Errors: `NO_IDS`, `NO_FIELDS`. |
| GET | `/api/media/[id]` | public | `getMediaDetail`; `404 NOT_FOUND` if missing. |
| PATCH | `/api/media/[id]` | requireMutation | Single update. Body `{ caption?, rating?, pick? }`. `caption` sliced to 2000 chars (null allowed); rating clamp 0..5; pick normalized as above. Verifies row exists (`404 NOT_FOUND`). Returns refreshed `getMediaDetail`. Errors: `NO_FIELDS`. |
| GET | `/api/media/[id]/thumb` | public | Serves WebP thumb. `?size=` → `preview`\|`grid2x`\|`grid` (default `grid`). Reads `mtime_ms, thumb_status, edited_ms`; `404 NOT_FOUND`. **etag** = `"t{id}-{mtime_ms}-{edited_ms||0}-{size}"`. **cache-control**: if `edited_ms` set → `public, max-age=0, must-revalidate`; else `public, max-age=31536000, immutable`. Honors `if-none-match` → `304`. Generate-on-miss via `ensureThumb(id, size)`; `404 NO_THUMB` if still absent. Content-type `image/webp`, sets `content-length`. |
| GET | `/api/media/[id]/original` | public | Delegates to `serveOriginal(db, id, request)` (Range-aware byte server). |
| GET | `/api/media/[id]/stream` | public | Same `serveOriginal` — `<video>` Range requests reuse the original server. |
| POST | `/api/media/[id]/tags` | requireMutation | Add tag by `tagId` or `name` (created on demand via `INSERT ... ON CONFLICT(name) DO NOTHING`). Links via `INSERT INTO media_tags ... ON CONFLICT DO NOTHING`. Verifies media exists (`404 NOT_FOUND`). Returns `{ tags }` (sorted by name). Errors: `NO_TAG`. |
| DELETE | `/api/media/[id]/tags` | requireMutation | Body `{ tagId }` (required, else `NO_TAG`). `DELETE FROM media_tags WHERE media_id=? AND tag_id=?`. Returns `{ tags }`. |
| PUT | `/api/media/[id]/edit` | requireMutation | Apply non-destructive edits. `404 NOT_FOUND`; `400 NOT_PHOTO` if not a photo. `normalizeEdits(body)`; if `isEdited(ops)` → `renderEditedThumbs(id,path,ops,ALL_SIZES)` then `UPDATE ... edit_ops=@ops, edited_ms=@ms, blurhash, width, height, thumb_status=2`. If all-default → `makeImageThumbs` + `UPDATE ... edit_ops=NULL, edited_ms=NULL, thumb_status=2`. `500 EDIT_FAILED` on throw. Returns refreshed detail. |
| DELETE | `/api/media/[id]/edit` | requireMutation | Revert to original: `makeImageThumbs(path,id,ALL_SIZES)` + clear `edit_ops`/`edited_ms`, `thumb_status=2`. `500 EDIT_FAILED`. Returns detail. |
| POST | `/api/media/[id]/edit` | requireMutation | Export full-res edited copy beside original. `404 NOT_FOUND`; `400 NOT_PHOTO`. Dest = `{base}-edited{ext}`, then `-edited-2`, `-3`… until a non-existing name; `assertWithinRoots(dest, enabledRoots)`; `exportEditedCopy(path,ops,dest)`. `500 EXPORT_FAILED`. Returns `{ ok: true, path: dest }`. |
| POST | `/api/media/trash` | requireMutation | Body `{ ids }` → `trash(ids)` (fileService, soft delete to trash dir). |
| POST | `/api/media/move` | requireMutation | Body `{ ids, destDir }` → `move(ids, destDir)`. `400 NO_DEST` if missing. `PathError` → `403 FORBIDDEN` (outside roots); else `500 MOVE_FAILED`. |
| POST | `/api/media/rename` | requireMutation | Body `{ id, newName }` → `rename(id, newName)`. `400 BAD_ID`/`NO_NAME`; failure → `400 RENAME_FAILED`. |
| GET | `/api/tags` | public | `{ tags: getTags(db) }`. |
| POST | `/api/tags` | requireMutation | Create tag (idempotent on name). `name` trimmed; `NO_NAME` if empty; `TOO_LONG` if >80. Returns `{ id, name, count: 0 }`. |
| DELETE | `/api/tags/[id]` | requireMutation | `DELETE FROM tags WHERE id=?` (media_tags cascade). Returns `{ ok: true }`. |
| GET | `/api/search` | public | If `semantic=1`/`true` AND `q` present AND `config.ai.semanticSearch` → `semanticSearch(q)` → `{ items, nextCursor: null }`. Otherwise builds `SearchFilters` from query params (`q, from, to, type, fav, archived, camera, hasGps, album, tag, rating, pick, place, curMs, curId, limit`) → `searchMedia`. Bools accept `1`/`true`. |
| GET | `/api/places` | public | `{ enabled: config.geocode.enabled, places: getPlaces(db) }`. |
| GET | `/api/albums` | public | `{ albums: getAlbums(db) }`. |
| POST | `/api/albums` | requireMutation | Create album. `name` trimmed, `NO_NAME` if empty. `INSERT INTO albums(name, created_at, sort_order) VALUES(?,?,0)`. Returns `{ id, name, coverMediaId: null, count: 0, createdAt, sortOrder: 0 }`. |
| GET | `/api/albums/[id]` | public | Album row (+count subquery) + `getAlbumPage` (`curMs/curId/limit`). `404 NOT_FOUND`. Returns `{ album, page }`. |
| PATCH | `/api/albums/[id]` | requireMutation | Body `{ name?, coverMediaId? }`. Updates name (if non-empty trimmed) and/or `cover_media_id` (if integer). Returns `{ ok: true }`. |
| DELETE | `/api/albums/[id]` | requireMutation | `DELETE FROM albums WHERE id=?` (album_items cascade). `{ ok: true }`. |
| POST | `/api/albums/[id]/items` | requireMutation | Add media. Per-id `INSERT INTO album_items(album_id, media_id, added_at, position) VALUES(@album,@media,@now, (SELECT COALESCE(MAX(position),-1)+1 ...)) ON CONFLICT(album_id, media_id) DO NOTHING` in a transaction. Then auto-sets cover to `ids[0]` if album has no cover. Returns `BulkResult`. |
| DELETE | `/api/albums/[id]/items` | requireMutation | Body `{ ids }` → `DELETE FROM album_items WHERE album_id=? AND media_id=?` per id in transaction. Returns `{ ok: ids, failed: [] }`. |
| GET | `/api/folders` | public | `getFolder(db, url.dir)` (dir param nullable). |
| GET | `/api/memories` | public | Computes today's `MM-DD` from `new Date()`. Returns `{ today: md, groups: getMemories(db, md, year) }`. |
| GET | `/api/duplicates` | public | `{ groups: getDuplicates(db) }`. |
| GET | `/api/map/points` | public | Params `zoom` (default 3) + `bbox` (`minLon,minLat,maxLon,maxLat`, only used if all four `Number.isFinite`). Returns `{ clusters: getMapClusters(...) }`. |
| GET | `/api/export` | public | **Zip download** of originals. `ids` from comma-joined `?ids=`. Uses `archiver` v8 `ZipArchive` (`{ zlib: { level: 6 } }`). Each id → `getMediaPath` → `realPathWithinRoots(path, roots, [trashDir])` (allow-list; skips failures). Dedupes filenames (`{id}-{name}` on collision). `404 EMPTY` if nothing added. Streams `Readable.toWeb(archive)`; headers `application/zip`, `attachment; filename="lgallery-export.zip"`, `cache-control: no-store`. |
| GET | `/api/backup` | public | **JSON export** (DB-only metadata): `{ version: 1, exportedAt, favorites:[{path,quickHash}], albums:[{name, items:[{path,quickHash}]}], tags:[{name,path}] }`, `content-disposition: attachment; filename="lgallery-export.json"`. |
| POST | `/api/backup` | requireMutation | On-disk DB backup: `pragma('wal_checkpoint(TRUNCATE)')`, then `copyFile` `data/lgallery.db` → `data/lgallery.backup-{ISO-stamp}.db` (stamp from request `date` header or now, `:`/`.`→`-`). Returns `{ ok: true, file }`. |
| GET | `/api/config` | public | `clientConfig()` (sanitized, no secrets). |
| PUT | `/api/config` | requireMutation | Merges incoming over `getConfig()`. Extracts `newPassword`/`clearPassword`/`server`; sets `server.password = newPassword \|\| null`, `server.passwordHash = clearPassword ? null : current.server.passwordHash`. `saveConfig(merged)` (`INVALID_CONFIG` on throw; `BAD_BODY` if null body). Then `reconcileRoots(db)`, persists `config_hash` into `app_state`, and if `result.changed` enqueues `requestRescan({reason:'config-saved'})`. Restarts the watcher (best-effort). Returns `{ ok: true, config: clientConfig(), rescan: result.changed }`. |
| POST | `/api/auth/login` | same-origin | CSRF: `isSameOrigin` else `403 CSRF`. If no `passwordHash` configured → `{ ok: true }`. Per-IP rate limit (in-memory `Map`, `MAX=5`): lockout returns `429 RATE_LIMIT` with seconds remaining; on too many failures sets `lockedUntil = now + min(15min, 1000 * 2^(count-MAX))` exponential backoff. On `verifyPassword` success: clears attempts, sets cookie `lg_session = sessionTokenFor(hash)` (`path:/, httpOnly, sameSite:lax, secure` when https, `maxAge = sessionTtlHours*3600`). Failure → `401 BAD_PASSWORD`. |
| POST | `/api/auth/logout` | same-origin | `isSameOrigin` else `403 CSRF`. `cookies.delete('lg_session', {path:'/'})`. `{ ok: true }`. |
| POST | `/api/scan` | requireMutation | Body `{ full? }` → `requestRescan({ reason: 'manual', full: !!full })`. `{ ok: true }`. |
| GET | `/api/scan/status` | public | `getScanState()`. |
| GET | `/api/scan/stream` | public | **SSE** progress stream. `text/event-stream`, `cache-control: no-cache, no-transform`, `connection: keep-alive`. `subscribeScan` pushes `event: scan\ndata: {json}\n\n`; 15s heartbeat `: ping\n\n`; unsubscribes + clears interval on `cancel`. |
| GET | `/api/ai/status` | public | `aiStatus()`. |
| POST | `/api/ai/index` | requireMutation | Body `{ action?: 'start'\|'stop', kind?: 'semantic'\|'faces' }` (kind defaults `semantic`). `stop` → `stopIndex(kind)`. For `start`: `400 AI_OFF` if the corresponding config flag (`ai.semanticSearch` / `ai.faceGrouping`) is disabled; else `startSemanticIndex()` / `startFaceIndex()`. `{ ok: true }`. |
| GET | `/api/people` | public | `{ people: getPeople(db) }`. |
| GET | `/api/people/[id]` | public | Media for a face `cluster_id`: `SELECT DISTINCT <11 cols> FROM media m JOIN faces f ON f.media_id=m.id WHERE f.cluster_id=? AND m.is_trashed=0 ORDER BY m.taken_ms DESC, m.id DESC LIMIT 500`. **GOTCHA:** wrapped in try/catch returning `{ items: [], nextCursor: null }` when the `faces` table doesn't exist yet. |
| GET | `/api/trash` | public | `{ items: getTrash(db) }`. |
| DELETE | `/api/trash` | requireMutation | Body `{ ids }` → `permanentDelete(ids)` (explicitly confirmed client-side). |
| POST | `/api/trash/restore` | requireMutation | Body `{ ids }` → `restore(ids)`. |

### 7.4 Cross-cutting decisions & gotchas

- **Public reads, guarded writes**: every GET is unauthenticated; mutating verbs (POST/PUT/PATCH/DELETE) start with the `requireMutation` guard pattern — except `POST /api/timeline/visible` (a benign priority hint, deliberately unguarded) and login/logout (which use `isSameOrigin` instead).
- **Body parsing is always defensive**: `await event.request.json().catch(() => ({}))` everywhere, so malformed bodies degrade to validation errors, not 500s.
- **`pick` normalization is universal**: `>0 → 1`, `<0 → -1`, `0` otherwise — duplicated in both `media` PATCH handlers.
- **`rating` clamp**: `Math.max(0, Math.min(5, Math.round(...)))` in both PATCH handlers.
- **Cache busting**: only bulk-archive busts the buckets cache directly; everything else relies on the 10s TTL or the scanner/pipeline busting it.
- **Thumb caching duality**: unedited originals are `immutable`/1-year; edited derivatives reuse the same id+mtime so they must be `must-revalidate` with `edited_ms` folded into the etag — get this wrong and edits won't visibly refresh.
- **Path safety**: export and edit-export both confine output to enabled roots (`realPathWithinRoots` / `assertWithinRoots`), excluding the trash dir.
```

Confirmed: FACES/EMBEDDINGS tables are never created by migrations — only on-demand. I now have everything.

## 8. Places/geocoding, optional on-device AI & map

This section covers three deliberately *off-by-default*, privacy-sensitive subsystems: reverse-geocoding (Places), on-device AI (CLIP semantic search + face plumbing), and the Leaflet map view. The AI deps are **OPTIONAL** — they are intentionally NOT in `package.json` and the whole feature degrades to clean no-ops when absent. Build these last; they depend on the DB layer (Section on db/schema/queries), config (`config-schema.ts` + `configService.clientConfig()`), the scanner, and the timeline mapping helpers.

### 8.0 Config surface (all OFF/safe by default)

These live in `src/lib/shared/config-schema.ts` (Zod, all defaulted so an empty `lgallery.config.json` is valid). Reproduce exactly:

- `map`: `{ enabled: boolean=true, tileUrl: string='https://tile.openstreetmap.org/{z}/{x}/{y}.png', attribution: string='© OpenStreetMap contributors', reverseGeocode: boolean=false }`. NOTE: `map.enabled` defaults to **true** (the only one of these that's on), but it makes no network call until the map route is actually opened.
- `geocode`: `{ enabled: boolean=false, provider: 'offline'|'nominatim'='offline', email: string='' }`.
- `ai`: `{ semanticSearch: boolean=false, faceGrouping: boolean=false, modelsDir: string='data/models', modelSource: 'huggingface'|'local'='huggingface', device: 'cpu'|'auto'='cpu' }`.

GOTCHA: there are two reverse-geocode-ish flags. `map.reverseGeocode` exists in the map block but the actual background geocoder is gated solely on the top-level `geocode.enabled`/`geocode.provider`. Don't confuse them.

`clientConfig()` in `configService.ts` strips only the `server` secrets (returns `{ host, port, sessionTtlHours, passwordSet }`) and **spreads the rest verbatim** — so `map`, `geocode`, and `ai` blocks are sent to the browser. The map and people routes read them from the `+layout.server.ts` load (`return { config: clientConfig() }`). The `email` in `geocode` does reach the client; that is accepted (it's a contact email, not a secret).

### 8.1 `src/lib/server/geo/cities.ts` — bundled offline city dataset + haversine

Pure data + math, **zero imports**, no network. Build first within geo.

- `export type City = readonly [number, number, string, string]` — tuple `[latitude, longitude, city, country]`, city-centre coords at ~2-decimal precision.
- `export const CITIES: City[]` — exactly **107 major world cities** grouped by region comments (North America, South America, Europe, Africa, Middle East, South & Central Asia, East & Southeast Asia, Oceania). This is a deliberately coarse grouping; the list is part of the app's behavior — reproduce it byte-exact from Appendix A (do not regenerate from another gazetteer or the offline labels will shift).
- `const R_KM = 6371` and `haversineKm(aLat,aLon,bLat,bLon)` — standard haversine, returns great-circle km, clamps `Math.min(1, sqrt(h))` before `asin` to avoid NaN at antipodes.
- `export interface NearestCity { city; country; distanceKm }`.
- `export function nearestCity(lat, lon, maxKm = 200): NearestCity | null` — linear scan over all cities, returns the closest within `maxKm` or `null`. DECISION: the 200 km default threshold means a remote shot far from any listed city is left unlabelled rather than mislabelled as a distant metro.

### 8.2 `src/lib/server/geo/geocodeService.ts` — resolve, throttle, background drain

Depends on: `db/index` (`getDb`/`DB`), `config/configService` (`getConfig`), `./cities` (`nearestCity`), `db/queries` (`bustBucketsCache`), `./log`.

- `export interface Place { name; locality; country }` (all `string | null`).
- Module-level `let running = false` — single-flight guard.
- `offlinePlace(lat, lon)`: `nearestCity(lat, lon)`; if null returns `{ name:null, locality:null, country:null }` (resolved, nothing close — still counts as done); else `{ name: \`near ${c.city}\`, locality: c.city, country: c.country }`. NOTE the literal `"near "` prefix on `name`.
- `nominatimPlace(lat, lon, email)`: GETs `https://nominatim.openstreetmap.org/reverse?format=jsonv2&zoom=12&lat=${lat}&lon=${lon}` with headers `User-Agent: 'LGallery/0.1 (' + (email || 'local user') + ')'` and `Accept: application/json`. Throws on non-`ok`. Locality fallback chain: `city || town || village || municipality || county || state || null`; `country = address.country || null`; `name = data.name || locality || country || null`. This `fetch` to OSM is the **only outbound network call** this feature ever makes.
- `resolve(lat, lon)`: if `getConfig().geocode.provider === 'nominatim'` → `nominatimPlace(..., g.email)`; otherwise `offlinePlace(...)`.
- `pending(db, limit)`: `SELECT id, gps_lat, gps_lon FROM media WHERE is_trashed=0 AND has_gps=1 AND gps_lat IS NOT NULL AND gps_lon IS NOT NULL AND geocode_status=0 ORDER BY taken_ms DESC LIMIT ?`.
- `export function geocodePending(): void` — the background pass:
  - No-op if `running` already true, or if `!getConfig().geocode.enabled`.
  - Sets `running = true`, then `void (async () => …)()`. Loops draining `pending(db, 50)` batches until empty.
  - On success: `UPDATE media SET place_name=@name, place_locality=@locality, place_country=@country, geocode_status=1, updated_at=@now WHERE id=@id`.
  - On failure (per-row try/catch, logged at `debug`): `UPDATE media SET geocode_status=2, updated_at=@now WHERE id=@id`.
  - THROTTLE: `if (cfg.provider === 'nominatim') await sleep(1100)` after each row — honoring OSM's ≤1 req/s policy (1100 ms, not 1000, for margin). Offline provider has no sleep.
  - `finally`: clears `running`; if any rows processed, calls `bustBucketsCache()` (Places buckets are cached) and logs `Geocoded N location(s) via <provider>`.
- `geocode_status` semantics: **0 = none/pending, 1 = done, 2 = fail**.

GOTCHA — kicked from the scanner, never by HTTP: `geocodePending` is invoked from `scanner.ts` in two places (~lines 349 and 416) via dynamic `import('../geo/geocodeService')` wrapped in try/catch (non-fatal). There is no `/api/geocode` endpoint. It runs at the tail of a scan pass and self-no-ops unless enabled. The dynamic import keeps geo off the scanner's critical path.

### 8.3 AI scaffold (OFF by default; deps OPTIONAL)

CRITICAL DECISION: `@huggingface/transformers` and `sqlite-vec` are **NOT listed in `package.json`** (verified: deps are archiver, better-sqlite3, blurhash, chokidar, exifr, ffmpeg-static, ffprobe-static, fluent-ffmpeg, leaflet, leaflet.markercluster, sharp, zod). They are installed manually only to enable AI: `npm i @huggingface/transformers sqlite-vec` (or bun equivalent). Everything below must build, typecheck, and run green with them absent.

#### `src/lib/server/ai/optional.ts` — the build-green guard
```ts
export function optionalImport(name: string): Promise<any> {
  return import(/* @vite-ignore */ name);
}
```
The specifier is a **runtime parameter**, not a literal, so Vite/TS can't statically resolve (or fail on) it. Missing packages throw at call time and are caught by callers. The `@vite-ignore` comment is load-bearing — without it the bundler tries to analyze the dynamic import. This single indirection is what keeps the optional deps optional.

#### `src/lib/server/ai/aiState.ts` — in-memory progress
- `export type AiKind = 'semantic' | 'faces'`.
- `export type AiPhase = 'idle' | 'loading-model' | 'indexing' | 'done' | 'error' | 'unavailable'`.
- `export interface AiKindState { phase; done; total; error }`.
- Module-private `state: Record<AiKind, AiKindState>`, both seeded `{ phase:'idle', done:0, total:0, error:null }`.
- `getAiState()` returns shallow **clones** of each kind (so callers can't mutate internal state). `patchAi(kind, partial)` does `Object.assign`. State is process-global and resets on restart (not persisted) — by design.

#### `src/lib/server/ai/vectorIndex.ts` — sqlite-vec KNN (optional)
Depends on `db/index` (`DB`), `db/schema` (`EMBEDDINGS_SQL`), `./optional`, `./log`.
- `EMBEDDINGS_SQL` (from schema.ts): `CREATE VIRTUAL TABLE IF NOT EXISTS embeddings USING vec0(media_id INTEGER PRIMARY KEY, embedding FLOAT[512]);` — **512-dim** vectors (matches CLIP-ViT-base output). Created on demand, never by migrations.
- `const ready = new WeakSet<DB>()` — per-connection idempotency.
- `ensureVectorTable(db): Promise<boolean>` — returns true if already ready; else `optionalImport('sqlite-vec')`, resolves `load = mod.load ?? mod.default?.load`, calls `load(db)` to register the extension on the better-sqlite3 handle, runs `EMBEDDINGS_SQL`, marks ready. On any throw: `log.warn('sqlite-vec is not available…')` and returns **false** (no crash).
- `upsertEmbedding(db, mediaId, vec)`: wraps the `Float32Array` as a `Buffer` (`Buffer.from(vec.buffer, vec.byteOffset, vec.byteLength)`) and `INSERT OR REPLACE INTO embeddings(media_id, embedding) VALUES(?, ?)`.
- `searchEmbeddings(db, vec, k)`: `SELECT media_id, distance FROM embeddings WHERE embedding MATCH ? ORDER BY distance LIMIT ?` (sqlite-vec KNN syntax), buffer-encoded query vector.
- `hasEmbedding(db, mediaId)`: `SELECT 1 FROM embeddings WHERE media_id=?`, try/catch → false if the vtable doesn't exist.

#### `src/lib/server/ai/aiService.ts` — CLIP semantic search + face plumbing
Depends on `db/index`, `config/configService`, `./vectorIndex`, `./aiState`, `db/queries` (`mapTimelineRow`), `db/schema` (`FACES_SQL`), `./optional`, `./log`, `$shared/types` (`TimelineItem`).
- Module state: `let clip` (cached `{model, processor, tokenizer, RawImage}`), `stopRequested` and `running` records keyed by `AiKind`. `const CLIP_ID = 'Xenova/clip-vit-base-patch32'`.
- `aiAvailable()`: tries `optionalImport('@huggingface/transformers')`, returns boolean.
- `loadClip()`: lazy-loads transformers; sets `t.env.allowRemoteModels = cfg.modelSource !== 'local'`, `t.env.localModelPath = cfg.modelsDir`, `t.env.cacheDir = cfg.modelsDir`; `Promise.all` of `CLIPModel/AutoProcessor/AutoTokenizer.from_pretrained(CLIP_ID)`. DECISION: with `modelSource='local'` remote downloads are disabled and models must be pre-placed in `data/models`; otherwise a one-time HF download occurs.
- `normalize(v)`: L2-normalize a Float32Array (guards divide-by-zero with `|| 1`). Both image and text embeddings are normalized so cosine ≈ L2 distance.
- `embedImage(path)`: `RawImage.read(path)` → processor → `model.get_image_features` → normalize. `embedText(text)` (exported): tokenizer `[text]` with `{padding:true, truncation:true}` → `get_text_features` → normalize.
- `startSemanticIndex()`: single-flight via `running.semantic`. If `!aiAvailable()` → `patchAi('semantic', { phase:'unavailable', error:'Install @huggingface/transformers + sqlite-vec to enable.' })` and return. Otherwise background async: `phase:'loading-model'`; `ensureVectorTable` (if false → `unavailable`, 'sqlite-vec not installed.'); `loadClip()`; selects `SELECT id, path FROM media WHERE type='photo' AND is_trashed=0 AND meta_status=2 ORDER BY taken_ms DESC` (only fully-processed photos); `phase:'indexing'` with `total`; per photo (respecting `stopRequested`), skip if `hasEmbedding`, else `embedImage`+`upsertEmbedding` (per-item failures logged at debug, indexing continues); bumps `done`. Final phase `done` (or `idle` if stopped). Resumable + newest-first.
- `startFaceIndex()`: **scaffold only** — `db.exec(FACES_SQL)` to create tables, then `patchAi('faces', { phase:'unavailable', error:'Face detection model not yet wired (see aiService.ts). Tables are ready.' })`. The detector/embedder is the explicit remaining integration point.
- `FACES_SQL` (schema.ts): `face_clusters(id PK, label TEXT, cover_face_id INTEGER)` and `faces(id PK, media_id→media ON DELETE CASCADE, bbox TEXT, embedding BLOB, cluster_id→face_clusters ON DELETE SET NULL)` + indexes on `media_id` and `cluster_id`. Created on demand only.
- `stopIndex(kind)` sets `stopRequested[kind]=true`. `aiStatus()` returns `getAiState()`.
- `semanticSearch(query, k=200): Promise<TimelineItem[]>`: `ensureVectorTable` (false → `[]`); `embedText`; `searchEmbeddings`; rebuild order via `byId` map; fetch matching rows (`SELECT … FROM media WHERE id IN (?,?,…) AND is_trashed=0`) and `mapTimelineRow`, then **re-sort by the KNN rank** (`byId.get(a.id) - byId.get(b.id)`) since `IN` loses order.
- `getPeople(db)`: `SELECT fc.id, fc.label, fc.cover_face_id AS coverFaceId, (SELECT COUNT(*) FROM faces f WHERE f.cluster_id=fc.id) AS count FROM face_clusters fc ORDER BY count DESC` wrapped in try/catch → `[]` if the faces tables don't exist. This is why `/api/people` returns an empty list cleanly when faces were never enabled.

### 8.4 AI / People / Map API endpoints

- `GET /api/ai/status` (`api/ai/status/+server.ts`): `json(aiStatus())` — trivial, no auth gate (read-only progress).
- `POST /api/ai/index` (`api/ai/index/+server.ts`): mutation-guarded via `requireMutation(event)` (returns guard response if it fails). Body `{ action?: 'start'|'stop', kind?: 'semantic'|'faces' }`, parsed with `.catch(()=>({}))`. `kind` defaults to `'semantic'` (only `'faces'` selects faces). `action:'stop'` → `stopIndex(kind)`, `{ok:true}`. For start: gate on config — semantic requires `ai.semanticSearch`, faces requires `ai.faceGrouping`; if off → `apiError(400, 'AI_OFF', 'Enable … in Settings first.')`. Then `startSemanticIndex()` / `startFaceIndex()`, `{ok:true}`. So there are **two gates**: config flag here, plus dep availability inside the service.
- `GET /api/people` (`api/people/+server.ts`): `json({ people: getPeople(getDb()) })`.
- `GET /api/people/[id]` (`api/people/[id]/+server.ts`): validate `id` integer > 0 (`apiError(400,'BAD_ID',…)`). Query: `SELECT DISTINCT m.<timeline cols> FROM media m JOIN faces f ON f.media_id=m.id WHERE f.cluster_id=? AND m.is_trashed=0 ORDER BY m.taken_ms DESC, m.id DESC LIMIT 500`, mapped via `mapTimelineRow`, `{ items, nextCursor:null }`. try/catch → `{ items:[], nextCursor:null }` when faces tables are absent.
- `GET /api/map/points` (`api/map/points/+server.ts`): reads `zoom` (default 3) and optional `bbox=minLon,minLat,maxLon,maxLat` (parsed, only used if all four are `Number.isFinite`). Returns `json({ clusters: getMapClusters(getDb(), bbox, zoom) })`.

`getMapClusters(db, bbox, zoom)` (in `db/queries.ts`): selects up to **20000** points `WHERE has_gps=1 AND is_trashed=0 AND gps_lat/lon IS NOT NULL` (+ optional bbox `BETWEEN` filter). Grid-clusters with `cell = 360 / 2^clamp(zoom,1,20) / 2`; bucket key `\`${floor(lon/cell)}:${floor(lat/cell)}\``; accumulates summed lat/lon + count, keeps first id as `sampleId`; returns `{ lat: sum/count, lon: sum/count, count, sampleId }[]` (centroid per cell). No database-side spatial index — pure JS aggregation, capped at 20k rows.

### 8.5 Map route — client-only Leaflet, tiles only when open

- `src/routes/map/+page.ts`: a single line — `export const ssr = false;`. DECISION: Leaflet touches `window` and is large, so the route is rendered client-only; its JS chunk + CSS never enter the SSR/critical path.
- `src/routes/map/+page.svelte`:
  - Reads `data.config.map` (from layout load). Imports `'leaflet/dist/leaflet.css'` statically but **dynamically `import('leaflet')`** inside `onMount` (handling both `mod.default` and `mod`).
  - If `!mapCfg?.enabled`: renders a message ("The map is disabled in `lgallery.config.json` (`map.enabled = false`)") and **does not load Leaflet or fetch tiles** — i.e. tiles are the one expected outbound call and only while the view is open with map enabled.
  - On mount (enabled only): `L.map(el, { worldCopyJump:true }).setView([20,0], 2)`; `L.tileLayer(mapCfg.tileUrl, { attribution: mapCfg.attribution, maxZoom:19 })`; an `L.layerGroup()` for markers. `moveend` handler debounces `refresh` by 200 ms. Cleanup destroys the map and clears the timer (`destroyed` flag prevents init races).
  - `refresh()`: computes `bbox` from `map.getBounds()` (`West,South,East,North`) + `zoom`, calls `api.mapPoints(bbox, zoom)`, clears the layer, and draws one `L.circleMarker` per cluster: `radius = Math.min(28, 9 + Math.log(count+1)*5)`, white 2px stroke, fill `#2563eb` at 0.85 opacity, with a permanent center tooltip showing the count (class `cl-label`). Click: if `count>1` zoom in (`setView(center, min(18, zoom+3))`); if a single item, fetch `api.detail(sampleId)`, seed the gallery store with that one item (`gallery.setSource` returning empty + `gallery.seed`) and open the `Lightbox` at that id. All API calls are try/catch silent.
  - GOTCHA: although `leaflet.markercluster` is a dependency, this view does **not** use it — clustering is done server-side in `getMapClusters` and rendered as plain circle markers. The `:global(.leaflet-container)` background is `#aadaff` (ocean blue) so empty/loading tiles look intentional.

### 8.6 People route — informational placeholder

`src/routes/people/+page.svelte`: reads `data.config.ai.faceGrouping`. Renders an `EmptyState` (icon `Users` from `@lucide/svelte`, title "People"). If enabled: "Face grouping is enabled. Clusters appear here as the background AI pass runs." (cluster grid is a TODO comment referencing `GET /api/people`). If disabled (default): copy stating face grouping is optional, on-device, **off by default**, with a link to `/settings → AI`, and "Nothing is uploaded — all detection runs locally." `a { color: var(--lg-accent) }`.

### 8.7 Build order & graceful-degradation summary

1. `geo/cities.ts` (no deps) → `geo/geocodeService.ts` (db, config, queries). Wire its dynamic import into `scanner.ts` (two call sites, both try/catch non-fatal).
2. Ensure `schema.ts` exports `FACES_SQL` and `EMBEDDINGS_SQL` (512-dim `vec0`), and that **migrations never create them** — confirmed: `migrate.ts` has no reference; both are created lazily by `startFaceIndex`/`ensureVectorTable`.
3. `ai/optional.ts` → `ai/aiState.ts` → `ai/vectorIndex.ts` → `ai/aiService.ts`.
4. API: `api/ai/status`, `api/ai/index`, `api/people`, `api/people/[id]`, `api/map/points`.
5. Routes: `map/+page.ts` (`ssr=false`), `map/+page.svelte`, `people/+page.svelte`.

Degradation invariants a rebuilder MUST preserve: with `geocode.enabled=false` (default) the geocoder is a no-op; with `ai.*` false the index endpoint returns `AI_OFF`; with the optional npm deps absent `aiAvailable()`/`ensureVectorTable()` return false and surface `phase:'unavailable'` instead of throwing; `getPeople`/`/api/people/[id]` return empty arrays when faces tables don't exist; and the map fetches OSM tiles only when `map.enabled` and the route is open. Do not add the two AI packages to `package.json` — their absence is the default shipped state.

Relevant files (absolute): `C:/Users/clark.bernales/source/repos/LGallery/src/lib/server/geo/cities.ts`, `.../geo/geocodeService.ts`, `.../ai/optional.ts`, `.../ai/aiState.ts`, `.../ai/vectorIndex.ts`, `.../ai/aiService.ts`, `.../db/schema.ts`, `.../db/queries.ts` (`getMapClusters`), `.../config/configService.ts` (`clientConfig`), `.../shared/config-schema.ts`, `.../scan/scanner.ts` (geocode kick), `src/routes/api/{ai/status,ai/index,people,people/[id],map/points}/+server.ts`, `src/routes/map/+page.{ts,svelte}`, `src/routes/people/+page.svelte`.

## 9. Client state, components, pages & design system

This section covers everything the browser runs: the four runes-based stores, the `api` wrapper and `blurhash-img` helper, every Svelte component (grid, lightbox, nav, common), the routes/pages with their server loaders, and the design system (`app.css`, service worker, manifest, favicon). Build these AFTER `$shared/*` (types, format, layout, edits, blurhash) and the server API routes exist — the client depends on shared types and calls the real endpoints. Import aliases used throughout: `$client` → `src/lib/client`, `$components` → `src/lib/components`, `$shared` → `src/lib/shared`, `$server` → `src/lib/server`.

### 9.1 Build order within this section

1. `src/app.css` (design tokens + component classes; nothing else renders correctly without it).
2. `src/lib/client/api.ts` (every store/component imports `api`).
3. `src/lib/client/blurhash-img.ts`.
4. State stores: `settings.svelte.ts`, `selection.svelte.ts`, `scanStatus.svelte.ts`, `gallery.svelte.ts`.
5. Common components: `Logo`, `Skeleton`, `EmptyState`, `PageHeader`, `DensityToggle`, `ScanChip`, `CommandPalette`, `SelectionBar`.
6. Grid: `GridTile` → `TimelineGrid` → `MediaGridView`.
7. Lightbox: `InfoPanel`, `EditOverlay` → `Lightbox`.
8. `nav/Sidebar.svelte`.
9. Routes: `+layout.server.ts`, `+layout.svelte`, `+page.server.ts`, `+page.svelte`, then the view pages.
10. `src/service-worker.ts`, `static/manifest.webmanifest`, `static/favicon.svg`.

### 9.2 Client state (Svelte 5 runes class stores)

All four are class instances exported as singletons. They use runes (`$state`, `$derived`) directly in class fields, so they must be `.svelte.ts` files. A single shared instance per store is deliberate (single-user local app).

#### `src/lib/client/state/gallery.svelte.ts` — `MediaList` (exported as `gallery`)

The active view's media list + keyset pagination. One shared instance backs whichever view is on screen (timeline/album/folder/search); the lightbox and selection bar operate on it.

- Reactive fields: `items: TimelineItem[]`, `cursor: Cursor | null`, `loading`, `done`, `error`, `total`. Private `#fetcher` (defaults to `(c) => api.timeline(c)`) and `#lastErrorAt = 0`.
- `setSource(fetcher)` — swaps the data source and resets `items=[]`, `cursor=null`, `done=false`, `error=null`, `total=0`. Each page calls this with the appropriate `api.*` fetcher.
- `seed(page, total=0)` — sets items/cursor/`done = !page.nextCursor`; only overwrites `total` when truthy.
- `loadMore()` — guards on `loading || done`. **Backoff gotcha:** if `error` is set and `Date.now() - #lastErrorAt < 5000`, it returns early so a scroll handler cannot hammer a failing endpoint. On success it **dedupes by id** via `new Set(items.map(i=>i.id))` before appending (keyset pages can overlap), updates cursor/`done`, clears `error`. On failure it stores the message and stamps `#lastErrorAt`.
- `indexOf(id)` → `findIndex`. `patchFlags(ids|Set, patch)` — maps items, spreading `patch` into matched ids (used for fav/archive/rating optimistic updates). `patchDims(id, w, h)` — updates one item's `width/height` (used after a crop changes aspect). `remove(ids|Set)` — filters out matched ids.

#### `src/lib/client/state/selection.svelte.ts` — `SelectionStore` (exported as `selection`)

Multi-select for bulk actions. Fields: `selecting` (bool), `ids: Set<number>`, `anchorId: number|null`. `get count` → `ids.size`.

- `toggle(id)` — clones the Set (immutable update so runes react), add/delete, sets `anchorId = id`, `selecting = true`.
- `selectRange(orderedIds, toId)` — shift-range: `from = anchorId ?? toId`; finds indices `a`,`b` in `orderedIds`; if either is `-1` falls back to `toggle`; otherwise adds every id in `[lo,hi]`.
- `selectAll(ids)` — replaces the Set; anchors `anchorId` to the **last** id so the next shift-range continues from the end (used by rubber-band).
- `clear()` resets all three; `has(id)` membership.

#### `src/lib/client/state/settings.svelte.ts` — `SettingsStore` (exported as `settings`)

Client UI prefs, persisted to localStorage. Fields `theme: Theme` (`'system'` default), `density: GridDensity` (`'comfortable'` default).

- Constructor (browser only): reads `lg.theme` / `lg.density`, validates against the literal unions, calls `apply()`, and registers a `matchMedia('(prefers-color-scheme: dark)')` `change` listener that re-applies.
- `setTheme(t)` persists `lg.theme` + applies. `cycleTheme()` order is **light → dark → system → light**. `setDensity(d)` persists `lg.density` (no apply needed; grid reads it reactively).
- `apply()` toggles `.dark` on `document.documentElement` when theme is `dark`, or `system` and the OS prefers dark. **This `.dark` class — not the OS media query — is authoritative** (see `@custom-variant dark` in app.css).

#### `src/lib/client/state/scanStatus.svelte.ts` — `ScanStatusStore` (exported as `scanStatus`)

Subscribes to the scan SSE stream. Field `state: ScanState` initialized from a frozen-ish `INITIAL` (status `'idle'`, all counters 0, `etaMs/startedAt/finishedAt/error/currentRoot` null). Private `#es: EventSource|null`.

- `start()` — browser-only, idempotent (`if (#es) return`); opens `new EventSource('/api/scan/stream')`, listens for the named `'scan'` event, `JSON.parse`s `e.data` into `state` (swallows malformed frames), and a no-op `onerror` (EventSource auto-reconnects).
- `stop()` closes/nulls. `get active` → `status==='running' || metaPending>0 || thumbsPending>0`.
- Lifecycle: started/stopped in `+layout.svelte` `onMount`.

### 9.3 `src/lib/client/api.ts`

Thin fetch wrapper. **CSRF double-submit:** `csrfToken()` reads the readable `lg_csrf` cookie via regex `/(?:^|;\s*)lg_csrf=([^;]+)/` (returns `''` on the server). `getJSON<T>(url)` does a plain GET, throws `Request failed (${status})` on non-OK. `send<T>(method,url,body?)` sets headers `content-type: application/json` + `x-csrf-token: csrfToken()`, JSON-stringifies body (or `undefined`), on failure tries to parse `e.error.message` from the server's error envelope (else default), and returns `undefined` on 204 else `r.json()`.

`export const api` methods (signatures matter — components call them by these exact names):
- `timeline(cursor?, limit=200)` → GET `/api/timeline?curMs&curId&limit`.
- `buckets()` → GET `/api/timeline/buckets` → `{buckets, total}`.
- `detail(id)` → GET `/api/media/{id}`.
- `reportVisible(ids)` → POST `/api/timeline/visible` `{ids}`.
- `rescan(full=false)` → POST `/api/scan` `{full}`.
- `setFlags(ids, {favorite?,archived?,rating?,pick?})` → PATCH `/api/media` `{ids, ...patch}` → `BulkResult`.
- `updateMedia(id, {caption?,rating?,pick?})` → PATCH `/api/media/{id}` → refreshed `MediaDetail`.
- `editMedia(id, ops)` → **PUT** `/api/media/{id}/edit`; `revertEdits(id)` → **DELETE** same; `exportEdited(id, ops)` → **POST** same → `{ok, path}`. (PUT applies, DELETE reverts, POST exports a copy.)
- Tags: `tags()` GET; `createTag(name)` POST; `deleteTag(id)` DELETE; `addMediaTag(id,{tagId?|name?})` POST `/api/media/{id}/tags`; `removeMediaTag(id, tagId)` DELETE same with `{tagId}` body.
- Trash/move/rename: `trash(ids)` POST `/api/media/trash`; `restore(ids)` POST `/api/trash/restore`; `permanentDelete(ids)` DELETE `/api/trash`; `listTrash()` GET; `move(ids, destDir)` POST `/api/media/move`; `rename(id, newName)` POST `/api/media/rename`.
- Albums: `albums()`, `album(id, cursor?)` GET `/api/albums/{id}?curMs&curId`, `createAlbum(name)`, `updateAlbum(id,{name?,coverMediaId?})` PATCH, `deleteAlbum(id)` DELETE, `addToAlbum(id, ids)` POST `/api/albums/{id}/items`, `removeFromAlbum(id, ids)` DELETE same.
- `search(filters={})` — GET `/api/search`; sets params only when present: `q,type,fav('1'),archived('1'),hasGps('1'),from,to,camera,tag,rating,pick,place,curMs,curId`. Returns `TimelinePage` (keyset-paginated like timeline).
- `places()` → `{enabled, places: PlaceGroup[]}`; `memories()` → `{today, groups:[{year, items}]}`; `mapPoints(bbox, zoom)` → `/api/map/points?bbox=&zoom=` → `{clusters}`; `duplicates()` → `{groups}`.
- `exportZipUrl(ids)` — returns the string URL `/api/export?ids=1,2,3` (used as a direct `window.location` navigation, not fetch).
- Config/backup/auth: `getConfig()` GET, `saveConfig(cfg)` PUT → `{ok, rescan}`, `backupDb()` POST `/api/backup`, `logout()` POST `/api/auth/logout`.

### 9.4 `src/lib/client/blurhash-img.ts`

`blurhashDataURL(hash)` decodes a blurhash to a tiny `image/webp` (quality 0.5) data-URL for real blur-up LQIP. Browser-only (returns `null` on SSR or `hash.length < 6`). Memoized in a module `Map`; **cache is cleared wholesale when `size > 2000`** to bound a long scroll. Constants `W = H = 32`. Falls back to `null` on any failure (callers then use the blurhash average colour from `$shared/blurhash`).

### 9.5 Grid components

#### `grid/GridTile.svelte`
Absolutely-positioned tile. Props: `item, x, y, w, h, priority=false, selecting=false, selected=false, onOpen, onToggleSelect?`. Positions via `transform: translate3d(x,y,0)` with `width/height`; `contain: strict; will-change: transform`. Background is the blurhash **average colour** (`blurhashAverageColor`) plus, when available, the decoded `lqip` data-URL as `background-image` (cover/center) for blur-up.
- `<img>` `src=/api/media/{id}/thumb?size=grid`, **srcset** `grid 1x, grid2x 2x`, `loading={priority?'eager':'lazy'}`, `fetchpriority={priority?'high':'auto'}`, `decoding="async"`; fades in via `.loaded` on `onload`. `priority` is set by TimelineGrid for `tile.index < 16`.
- Hover-play: `isLive = livePartnerId != null`; `hoverVideoId` = the video's own id (if `type==='video'`) or the Live partner id. On `pointerenter`, renders a muted/autoplay/loop `<video src=/api/media/{hoverVideoId}/stream preload="none">`.
- Badges: duration (Play icon + `formatDuration`) for video, else `LIVE` badge; favorite ★ (`--lg-fav`); selection check circle (filled `✓` + `.on` when selected).
- `click(ev)`: if `selecting || shift/ctrl/meta` → `onToggleSelect`, else `onOpen`. Selected state scales the img down (0.86) with rounded corners; hover scales up 1.045.

#### `grid/TimelineGrid.svelte` (the core virtualized grid)
Props: `items, density='comfortable', buckets=[], initialWidth=0, selecting, selectedIds, onLoadMore, onVisibleChange, onOpen, onToggleSelect, onRubberBand`. `PAD = 12`.
- **SSR seeding gotcha:** `containerWidth = $state(untrack(() => initialWidth))` and `viewportH` is seeded to `800` when `initialWidth>0`, so `computeLayout` runs during SSR/before measurement (no blank-then-pop). `onMount`'s `ResizeObserver` calls `measure()` → `containerWidth = clientWidth - PAD*2`, `viewportH = clientHeight`.
- Derived: `opts = densityOptions(density, containerWidth)`; `layout = computeLayout(items, opts)` (justified rows + day/month header rows); `itemsPerRow ≈ round(containerWidth/(targetRowHeight+gap))`; `estimatedTotalHeight = estimateHeightFromBuckets(...)`; `spacerHeight = max(layout.totalHeight, estimatedTotalHeight)` (bucket estimate inflates the scroll height so the native scrollbar is correctly sized before all pages load).
- **Virtualization:** `overscan = max(300, viewportH)`; `range = findRowRange(layout.rows, scrollTop-overscan, scrollTop+viewportH+overscan)`; only `visibleRows = layout.rows.slice(...)` are rendered.
- **Floating date label:** anchored to the viewport **top** (a separate `findRowRange(scrollTop, scrollTop+1)`, then walks backward to the nearest header row) so the overscan window doesn't show the previous day. Uses `floatingDateLabel`. Shows for 900 ms after each scroll (`labelTimer`).
- Headers: month-start rows render `monthHeaderLabel(monthKeyFromDay(day))` (1.35rem/700), day rows render `dayHeaderLabel(day)`.
- **Date-jump scrubber:** built on `monthMarksFromBuckets` → reduced to one label per **year** (`yearMarks` with `frac = m.y/spacerHeight`). `scrubEnabled = monthMarks.length>1 && spacerHeight > viewportH*1.2`. Right-edge 30px rail (`.scrubber`, `touch-action:none`); pointer down/move maps `clientY` → fraction → `scrollEl.scrollTop = frac*scrollRange` (`scrollRange = max(1, spacerHeight - viewportH)`); thumb at `thumbFrac*100%`; year chips are buttons that `jumpToMark`. Subtle until `.grid-root:hover` or `.active`.
- **Rubber-band drag select:** `rbDown` on `pointerdown` over empty grid (button 0, target not `.tile`); records start coords relative to `spacerEl`, captures the pointer on `scrollEl`. `rbMove` ignores moves < 4px, computes the drag rect, runs `findRowRange` over the y-band, collects every tile whose box intersects the rect, calls `onRubberBand(ids)`. Draws `.rubber` (accent border + `--lg-accent-weak`).
- **Pagination gotcha:** `maybeLoadMore()` triggers against the **real** `layout.totalHeight` (not the inflated bucket-estimate spacer): `if (scrollTop + viewportH > layout.totalHeight - viewportH*1.5) onLoadMore()`. Also re-checked in an `$effect` on `items.length`/`containerWidth`.
- `reportVisible()` (180 ms debounce) collects visible tile ids → `onVisibleChange`; initial report 200 ms after mount.
- **Native scrollbar by design** — `.scroll { overflow-y:auto }`, no custom scroll thumb.

#### `grid/MediaGridView.svelte`
Glue between the `gallery`/`settings`/`selection` stores and `TimelineGrid`, plus the `Lightbox` and `SelectionBar`. Props `buckets=[], initialWidth=0`. Holds `lightboxId`. `onVisible` debounces 60 ms then `api.reportVisible(ids).catch(()=>{})`. `onToggleSelect`: shift → `selection.selectRange(gallery.items.map(i=>i.id), id)`, else `selection.toggle(id)`. Wires `onLoadMore → gallery.loadMore()`, `onOpen → lightboxId`, `onRubberBand → selection.selectAll`. Renders `<SelectionBar>` when `selection.count>0` and `<Lightbox startId={lightboxId}>` when open.

### 9.6 Lightbox components

#### `lightbox/Lightbox.svelte`
Props `startId, onClose`. Operates on the shared `gallery.items` by `index` (`onMount` sets `index = max(0, gallery.indexOf(startId))`). `current = gallery.items[index]`.
- **Zoom/pan:** `scale/tx/ty`. `zoomAt(cx,cy,factor)` zooms toward a point, clamped `[1,8]`; resets `tx/ty` at scale 1. Wheel zooms (1.15 / 1/1.15). Double-click toggles 2.2× / reset.
- **Pointer gestures:** `pointers` Map; two pointers → pinch (`pinchStartDist/Scale`, `Math.hypot`); one pointer at scale>1 → pan; at scale 1 → horizontal swipe (>60px triggers `go(±1)`). `pointerMoved` (>6px) distinguishes a swipe/drag from background click-to-close.
- **Navigation:** `go(delta)` clamps, auto-`loadMore()` near the end (prefetch when `index >= length-4 && !done`), resets zoom/`originalLoaded`/`motionOn`/`detail`.
- **Stage rendering** (keyed by `current.id`): video → `<video controls autoplay preload="metadata">` with `?size=preview` poster; **Live motion toggle** (`motionOn`, Aperture button, only when `livePartnerId!=null`) plays the partner clip looped; photo → a blurred **preview** img (`?size=preview`) under a full **original** img (`/api/media/{id}/original`) that fades in on load. **Edit cache-bust:** `bustSuffix` appends `?v=`/`&v=` to preview & original URLs when `editBust.id === current.id` so a just-saved edit reloads.
- **Codec banner:** `PLAYABLE = ['h264','avc','vp8','vp9','av1','av01','theora']`; `unplayable` shows a red banner + download link when a video's `detail.codec` isn't in that list. Video detail is auto-loaded via an `$effect`.
- **Click-outside-to-close:** stage `onclick` closes only when `e.target===e.currentTarget && !pointerMoved`.
- **Keyboard** (`window keydown`): while `editing`, only Escape (closes editor) is honored. Otherwise: `Esc` close; `←/→` nav; `f` favorite (optimistic `patchFlags` with revert on failure); `i` info; `Delete` trash; `+/=` and `-` zoom; `Space` play/pause video else slideshow; **`0–5` set rating**; **`P` pick=1, `X` pick=-1** (toggle off if already set) via `api.updateMedia`. Pencil button / `openEdit` loads detail then opens `EditOverlay`. `onEdited` updates `detail`, sets `editBust`, and `gallery.patchDims` to reflect crop aspect changes. Slideshow interval `SLIDE_MS=4000`. `onMount` sets `body.overflow='hidden'`, focuses the dialog, restores on unmount.

#### `lightbox/InfoPanel.svelte`
Right drawer (bottom sheet < 640px). Props `detail, onClose, onUpdate`. Always-dark (uses `--lg-overlay-*` tokens). Editable: **caption** textarea (saves on blur / Ctrl+Enter via `api.updateMedia({caption: text||null})`, kept in sync via `$effect`); **stars** 1–5 (hover preview, click current to clear → rating 0); **pick/reject** flags (toggle off if already set); **tag chips** (add via `api.addMediaTag({name})` with a `<datalist id="lg-all-tags">` of all tags loaded on mount; remove via `api.removeMediaTag`). Read-only metadata `<dl>`: File (+type/duration), Taken (`formatDateTime` + EXIF/file-date source), Dimensions, Size (`formatBytes`), Camera/lens, **place line** (`placeLocality, placeCountry` linking to `/places`, gps coords to 5dp, "View on map" → `/map?lat=&lon=`), Albums, Path (`<code>`).

#### `lightbox/EditOverlay.svelte`
Props `id, src, initial: EditOps|null, onClose, onSaved`. `ops = {...DEFAULT_EDITS, ...(initial??{})}` (from `$shared/edits`).
- **Live preview:** `cssFilter = cssFilterFor(ops)` applied to the preview img; `geom = rotate(...)deg scaleX(±1) scaleY(±1)` applied unless in crop mode.
- Orient: rotate ±90 (mod 360), flipH/flipV toggles, crop toggle.
- **Sliders** (`SLIDERS`): brightness 0.5–1.5, contrast 0.5–1.5, saturation 0–2, vibrance −1–1, warmth −1–1 (step 0.01).
- **Filter strip** from `FILTERS` (capitalized chips), active highlighted.
- **Crop overlay:** aspect presets `Free / 1:1 / 4:3 / 3:2 / 16:9` (`setAspect` computes normalized w/h from `imgEl.naturalWidth/Height`), plus Clear. `.crop-box` with 4 corner handles `nw/ne/sw/se` + move; drag math normalized to `wrapEl` rect, `MIN=0.05`; mask via `box-shadow: 0 0 0 9999px rgba(0,0,0,.5)`.
- Footer: **Reset** (local `DEFAULT_EDITS`), **Revert** (`confirm` → `api.revertEdits`), **Copy** (`api.exportEdited` → "Saved a copy: …"), **Save** (`api.editMedia(id, ops)` → `onSaved(d, …)` → close). Errors shown in `.msg`.

### 9.7 Nav & common components

- **`nav/Sidebar.svelte`** — fixed 216px (64px < 700px, labels hidden). `links` array (order matters): Photos `/`, Favorites, Albums, Folders, Search, Map, **Places `/globe` icon**, People, **Tags**, Memories, Duplicates, Archive, Trash. Active via `page.url.pathname` (`startsWith`, exact for `/`); active gets `--lg-accent-weak` bg + a 3px left indicator bar. Footer: theme cycle button (icon = Sun/Moon/MonitorSmartphone per `settings.theme`, label shows the theme) + Settings link. Brand uses `<Logo size={26}>`.
- **`common/CommandPalette.svelte`** — global `keydown`: **Ctrl/⌘+K** toggles; **`?`** (when not typing/open) opens the help view; Escape closes. `commands` are nav `goto`s + actions (Rescan, Toggle theme, Keyboard shortcuts). Filtered fuzzy by label/hint; always appends a `Search for "<q>"` escape hatch → `/search?q=`. Arrow/Enter selection (`sel` resets on query change). Help view lists `SHORTCUTS` (⌘/Ctrl+K, ?, ←/→, Space, F, I, 0–5, P/X, +/−, Del, Esc, Shift+click) — these must match Lightbox/grid bindings.
- **`common/SelectionBar.svelte`** — fixed bottom-center toolbar shown when `selection.count>0`. Buttons: clear (X + count), **Favorite** (optimistic `patchFlags` then clear), **Rate** popover (1–5 stars, Clear rating=0, Pick, Reject via `api.setFlags`), **Archive** (`setFlags{archived:true}` + `gallery.remove` — archived leave the timeline), **Album** popover (lists `api.albums()` with counts; create-and-add via `api.createAlbum`+`addToAlbum`), **Export** (`window.location = api.exportZipUrl(ids)`), **Trash** (confirm → `api.trash` + remove). `run()` wrapper sets `busy` and `alert`s errors.
- **`common/ScanChip.svelte`** — fixed bottom-center chip, visible when scan running / meta or thumbs pending / error. Text derived from `scanStatus.state`: running → "Scanning — N seen"; thumbs pending → "Processing N thumbnail(s)" + ` · {round(throughputPerSec)}/s` + ` · {eta}` (`fmtEta`: ~Ns/~Nm/~N.Nh left); meta pending → "Reading N file(s)". Manual Rescan button (`api.rescan(false)`, spinner). Error variant uses `--lg-danger`.
- **`common/PageHeader.svelte`** — `.lg-bar` header with optional `icon`, `title`/`children` snippet, optional `count` (`toLocaleString`), and an `actions` snippet slot.
- **`common/EmptyState.svelte`** — centered icon tile + title + description + optional `action`/`children` snippets.
- **`common/Skeleton.svelte`** — single `.lg-skeleton` div with `width/height/radius` props.
- **`common/DensityToggle.svelte`** — segmented control (compact/comfortable/spacious) bound to `settings.density`.
- **`common/Logo.svelte`** — inline SVG mark (blue→violet gradient rounded square, sun, mountains, video play badge); `id` derived from `size` to keep the gradient id unique.

### 9.8 Routes & pages

- **`+layout.server.ts`** — on every load, if `config.scan.rescanOnReload`, calls `reloadIfChanged()`; when changed, upserts `app_state.config_hash` and dynamically imports `$server/scan/scanner` to `requestRescan({reason:'config-changed'})`. Returns `{config: clientConfig()}`. Wrapped in try/catch (logs debug on failure).
- **`+layout.svelte`** — imports `../app.css`, renders `<Sidebar>` + `<main>{children}</main>`, plus global `<ScanChip>` and `<CommandPalette>`. `onMount` → `scanStatus.start()` / cleanup `stop()`. Sets `<title>LGallery</title>`. App is `display:flex; height:100vh; overflow:hidden`.
- **`+page.server.ts`** (timeline) — `PAGE=200`; loads `getTimelinePage(db,{limit})`, `getBuckets(db)`, `getTotalCount(db)`, and **`initialWidth: initialGridWidth(cookies)`**. `initialGridWidth` (in `$server/http`): reads cookie `lg_w`; default 1200; subtracts sidebar (64 if ≤700 else 216) + 24px grid padding; floored at 280. **This is the SSR seed that lets the grid lay out server-side.**
- **`+page.svelte`** (timeline) — `untrack`s `gallery.setSource((c)=>api.timeline(c))` + `gallery.seed(initialPage, total)` during render (incl. SSR) so the grid is in the first HTML. Shows `EmptyState` when `total===0`, else `<MediaGridView buckets initialWidth>`.
- **View pages** (all share the column layout `.page` + `.grid-wrap` and reuse `MediaGridView`):
  - `favorites/`, `archive/` — client `onMount` seed via `api.search({fav:true,...})` / `{archived:true,...}`.
  - `search/` — full filter bar (q, photo/video type, fav, hasGps, min-rating cycling 0→5, pick/reject tri-state). Prefills `q` from `?q=`. Debounced 250 ms `run()` re-seeds `gallery` on any filter change via `$effect`.
  - `albums/+page.server.ts` + `albums/[id]/{+page.server.ts,+page.svelte}` — `[id]` loader validates id, fetches album row (with `count` subquery) or `error(404)`, plus `getAlbumPage(db,id,{limit:200})`; page seeds with `api.album(id, cursor)` fetcher.
  - `folders/+page.server.ts` — `getFolder(db, url.searchParams.get('dir'))`.
  - `trash/+page.server.ts` — `getTrash(db)`; page uses restore/permanent-delete.
  - `map/+page.ts` — **`export const ssr = false`** (Leaflet touches `window`); `map/+page.svelte` uses `api.mapPoints`.
  - `places/`, `people/`, `tags/`, `memories/`, `duplicates/` — call their respective `api.*`.
  - `settings/+page.server.ts` — returns `{config: clientConfig(), appDir: process.cwd()}` (the **`appDir`** is shown so the user knows where `lgallery.config.json`/DB live).
  - `login/+page.svelte` — standalone full-screen card; posts to `/api/auth/login` with its own inline CSRF cookie read (same regex as `api.ts`); on success `window.location='/'`.

### 9.9 Design system — `src/app.css`

- `@import 'tailwindcss';` then **`@custom-variant dark (&:where(.dark, .dark *))`** — dark mode is driven by the `.dark` class (set by `settings.apply()`), NOT the OS query, so the in-app toggle wins.
- `@theme { --font-sans: … }` — self-hosted/system font stack only (no web-font CDN, privacy).
- **Tokens on `:root`** (light) and overridden on `:where(.dark)`: accent (`--lg-accent #2563eb`, `-hi #3b82f6`, `-weak`, `-text #fff`), `--lg-danger #dc2626`, `--lg-fav #facc15`; surfaces (`--lg-bg`, `--lg-surface`, `--lg-surface-2`, `--lg-surface-hover`, `--lg-border`, `--lg-text`, `--lg-text-muted`); **overlay tokens** (`--lg-overlay-bg/text/muted/hover/border`) intentionally dark/translucent in BOTH themes (photo-viewer convention, used by lightbox/toasts/floating bars); radii `--lg-r-sm 6 / -md 10 / -lg 14 / -xl 20`; shadows `--lg-shadow-1/2/3`; motion `--lg-dur-fast 120ms / -base 220ms`, `--lg-ease cubic-bezier(0.2,0,0,1)`. Dark overrides bg `#0a0a0a`, surface `#161616`/`#202020`, stronger shadows.
- Globals: `html,body{height:100%}`; `body` uses tokens + `overscroll-behavior-y:none`; thin native scrollbars styled via `scrollbar-width/-color` and `::-webkit-scrollbar*` (12px, rounded, padding-box border).
- `@layer components`: **`.lg-bar`** (frosted header, `color-mix(in srgb, var(--lg-bg) 78%, transparent)` + `backdrop-filter: blur(10px)`), **`.btn`** (+ `.btn-primary`/`.btn-ghost`/`.btn-danger`, active `translateY(1px)`, disabled 0.55), **`.lg-card`**, **`.lg-input`** (focus ring `0 0 0 3px var(--lg-accent-weak)`), **`.lg-ring:focus-visible`** (double ring `0 0 0 2px bg, 0 0 0 4px accent`), **`.lg-skeleton`** (shimmer `::after` via `lg-shimmer` keyframes + `color-mix`). `prefers-reduced-motion` kills animations/transitions/scroll-behavior and hides the shimmer.

### 9.10 Service worker, manifest, favicon

- **`src/service-worker.ts`** — imports `build, files, version` from `$service-worker`. `APP_CACHE = lg-app-${version}`, `THUMB_CACHE = lg-thumbs`, `ASSETS=[...build,...files]`. `install` precaches ASSETS + `skipWaiting()`. `activate` deletes any cache not in `{APP_CACHE, THUMB_CACHE}` + `clients.claim()`. `fetch` only handles same-origin GET (never intercepts cross-origin, e.g. map tiles): ASSETS → cache-first; `/api/media/.../thumb` → **stale-while-revalidate** (serve cached instantly, refetch in background, `cache.put` + `trimThumbCache` on ok) so an edited photo (same URL, new mtime) propagates within one load; everything else (API data, originals, video) → network. **`THUMB_CACHE_MAX = 1500`**, FIFO trim of oldest keys.
- **`static/manifest.webmanifest`** — name/short_name "LGallery", `display: standalone`, `background_color #0a0a0a`, `theme_color #111827`, single SVG icon `/favicon.svg` (`sizes:"any"`, purpose `any`).
- **`static/favicon.svg`** — static SVG matching the `Logo` mark (verify byte-for-byte against Appendix A).

### 9.11 Cross-cutting decisions & gotchas a rebuilder must honor

- Stores are **module singletons** intentionally; pages seed the shared `gallery` during render (often inside `untrack`) so SSR HTML already contains the grid. Don't refactor to per-component instances.
- The grid's correct first paint depends on the **`lg_w` cookie → `initialGridWidth` → `initialWidth` prop → seeded `containerWidth`** chain. Without it the grid renders blank until the ResizeObserver fires.
- Pagination must compare against `layout.totalHeight`, not `spacerHeight`; the spacer is deliberately inflated by the bucket estimate to size the native scrollbar.
- `loadMore` dedupes by id and backs off 5 s after errors — both are required to avoid duplicate tiles and request storms.
- CSRF token is read from the **readable** `lg_csrf` cookie and sent as `x-csrf-token` on all mutations; the login page duplicates this read inline.
- Lightbox keyboard handling must mirror the CommandPalette help list (0–5/P/X/F/I/Space/Del/±/←→/Esc) and must let the EditOverlay own the keyboard while editing (only Esc passes).
- Dark mode is class-based (`.dark` on `<html>`), overlay tokens stay dark in both themes, and `prefers-reduced-motion` is fully honored — keep all three.

## 10. Scripts, build, run, verification, tests & decisions/gotchas catalog

This section documents the non-application tooling, the exact commands to build/run/verify, the test inventory (≈128 cases), and the hard-won decisions a rebuilder MUST reproduce to get *this* app rather than a plausible lookalike. All paths are relative to the repo root `C:/Users/clark.bernales/source/repos/LGallery`. The byte-exact contents of every file named here live in **Appendix A — Verbatim Source**; do not retype from memory, copy from the appendix.

### 10.1 Helper scripts

#### `scripts/gen-fixtures.mjs` — synthetic media for testing
Plain ESM, run as `node scripts/gen-fixtures.mjs [targetDir] [port]`. Responsibility: produce a small, varied library plus a matching `lgallery.config.json` for manual/smoke verification. Key behaviors a rebuilder must preserve:
- Default target `os.tmpdir()/lgallery-fixtures`, default port `4188`. Creates `target/` and `target/trip/`.
- Deterministic timeline: `base = Date.parse('2026-01-15T12:00:00Z')`; each file's mtime is set via `fs.utimesSync` to `base − daysAgo*DAY` so day-bucketing/timeline tests are reproducible.
- Generates with `sharp`: `landscape.jpg` (1600×1000), `portrait.jpg` (1000×1600, written with **EXIF orientation 6** via `withMetadata({ orientation })` to exercise the rotate path), `trip/beach.jpg`, `trip/sunset.jpg`, `trip/forest.jpg`; a 4-channel PNG `graphic.png` (1200×1200, alpha). JPEGs at `quality: 80`.
- Generates `clip.mp4` via `fluent-ffmpeg` using the `lavfi` `testsrc` source (`testsrc=duration=2:size=320x240:rate=10`, `-pix_fmt yuv420p`), pointing ffmpeg at `ffmpeg-static`. Video generation is wrapped in try/catch — if ffmpeg is unavailable it logs `! video generation skipped` and continues (GOTCHA: do not make the script fail when ffmpeg is missing).
- Writes `lgallery.config.json` with the root path **forward-slashed** (`.replace(/\\/g,'/')`), `logging.level: 'debug'`, and the supplied port.

#### `setup-lgallery.cmd` + `setup-lgallery.ps1` — one-shot prerequisite installer
`setup-lgallery.cmd` is a 14-line `@echo off` wrapper that `cd /d "%~dp0"` then launches `powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup-lgallery.ps1"` and `pause`s. All real work is in the `.ps1`, which **targets Windows PowerShell 5.1** and must therefore be **ASCII-only** (see GOTCHA 10.6). Responsibilities, in order, idempotent:
1. Helpers: `Write-Step/Ok/Warn2` colored output; `Test-Cmd` via `Get-Command`; `Update-SessionPath` which rebuilds `$env:Path` from Machine+User plus `%USERPROFILE%\.bun\bin`, `%ProgramFiles%\nodejs`, `%ProgramFiles%\Git\cmd` so freshly installed tools are visible without a new shell.
2. **Git** (optional, for updates): `winget install --id Git.Git`. Failure is non-fatal.
3. **Bun** (package manager + build): `winget install --id Oven-sh.Bun`, falling back to the official installer `Invoke-RestMethod https://bun.sh/install.ps1 | Invoke-Expression`.
4. **Node** (runs the server — *because better-sqlite3 is unsupported under the Bun runtime*, see GOTCHA 10.6.1): `winget install --id OpenJS.NodeJS.LTS`, falling back to downloading the latest LTS MSI from `https://nodejs.org/dist/index.json` (selects first `.lts`, picks `x64`/`x86`) and `msiexec /i ... /qn /norestart`. Missing Node increments `$failures`.
5. Dependency install + build: picks `$pm = bun` (else `npm`), runs `& $pm install` then `& $pm run build`, checking `$LASTEXITCODE` each time.
6. **Config**: if `lgallery.config.json` is absent, prompts for a photos folder (default `%USERPROFILE%\Pictures`), forward-slashes it, and writes an ordered config `{ roots:[{path,label:'Pictures',enabled:true}], scan:{watch:true}, server:{host:'127.0.0.1',port:4173} }` via `ConvertTo-Json -Depth 6 | Set-Content -Encoding utf8`. Existing config is left untouched.
7. **Autostart**: optionally creates `%Startup%\LGallery.lnk` (a `WScript.Shell` shortcut) whose target is `wscript.exe` with argument `"…\start-lgallery-hidden.vbs"`, `WorkingDirectory = $PSScriptRoot`.
8. Summary prints the resolved port (re-read from config) and exits `0`/`1` on `$failures`.

#### `start-lgallery.cmd` + `start-lgallery-hidden.vbs` — Windows autostart
`start-lgallery.cmd` (`@echo off`, self-locating via `cd /d "%~dp0"`): sets the runtime environment **only if unset** — `PORT=4173`, `HOST=127.0.0.1`, `NODE_ENV=production`, and `UV_THREADPOOL_SIZE=16` (must be set before Node starts; see 10.6 threadpool). If `build\index.js` is missing it runs `bun run build` first. It opens the browser ~2s later via a detached `timeout /t 2 >nul & start http://%HOST%:%PORT%/`, then launches the server with **`node start.mjs`** (not `bun`). `start-lgallery-hidden.vbs` runs `cmd /c start-lgallery.cmd` with window style `0` (hidden) and `bWaitOnReturn=False`, after setting its CWD to the script's parent folder — used as the Startup shortcut target for a console-less autostart.

#### `start.mjs` — production entry
Tiny launcher in front of the adapter-node bundle. It sets `process.env.UV_THREADPOOL_SIZE = max(8, cpuCount*2)` **only if not already set**, *before* `await import('./build/index.js')`. Rationale (must be honored): libuv reads the threadpool size once at first initialization, so setting it after any sharp/ffmpeg task has run is a no-op; the thin launcher exists solely to guarantee the env var is in place before the server (and thus before any threadpool work) starts. `bun run start` / `npm run start` both map to `node start.mjs`.

#### `token-usage.html` — standalone local utility
A fully self-contained single-file HTML calculator (no external fonts/scripts/styles, `meta referrer no-referrer`): input/output token fields → total, with an optional cost estimate (`$/1M tokens`). All logic is an inline IIFE (`render()` recomputes on input, Reset clears). It is unrelated to the server runtime — reproduce verbatim from Appendix A; it embodies the project's "local-only, no network/storage/telemetry" stance.

### 10.2 RUN + VERIFY commands

Exact dependency manager/runtime: `packageManager: bun@1.3.14`, `engines.bun >= 1.3.0`, `type: module`. Install with `bun install`. Then:

- **Type/Svelte check** — `bun run check` → `svelte-kit sync && svelte-check --tsconfig ./tsconfig.json`. Must report **0 errors / 0 warnings**. (`svelte-kit sync` is mandatory first; it generates `.svelte-kit/` types.)
- **Tests** — `bun run test` → `vitest run`. Expect ~**128** passing cases (inventory in 10.3).
- **Coverage** — `bun run test:cov` → `vitest run --coverage` (v8 provider, `@vitest/coverage-v8`). Coverage denominator is restricted to `src/lib/server/**` and `src/lib/shared/**`; it excludes `*.test.ts`, `*.spec.ts`, `*.svelte`, and `src/lib/server/ai/**`. Client code is verified by runtime smokes, not vitest.
- **Build** — `bun run build` → `vite build` with `@sveltejs/adapter-node`. Produces `build/index.js` plus **precompressed** assets (adapter-node `precompress` enabled). Output is a Node server bundle.
- **Runtime smoke** — `node start.mjs` (or `bun run start`). On a fresh DB this runs **migrations v1→v6** (with a pre-migration DB backup), then the server is exercised by hitting `/api/timeline`, `/api/places`, `/api/tags`, an SSR fetch of `/`, and one thumbnail URL to confirm the render pipeline. Use `scripts/gen-fixtures.mjs` to seed a library and config first.

### 10.3 Test inventory (~128 cases, vitest under `environment: 'node'`)

Vitest config lives inside **`vite.config.ts`** (no separate `vitest.config.*`): `test.include = ['src/**/*.{test,spec}.{js,ts}']`, `environment: 'node'`. Per-suite counts (sum = **128**):

| Suite | Cases | Covers |
|---|---|---|
| `src/lib/server/paths.test.ts` | 16 | path normalization, root containment / allow-list, `..` traversal rejection, Windows separators |
| `src/lib/shared/format.test.ts` | 9 | human-readable size/date/duration formatting |
| `src/lib/shared/blurhash.test.ts` | 3 | blurhash encode/decode round-trip |
| `src/lib/shared/layout.test.ts` | 12 | justified-row gallery layout math |
| `src/lib/server/config/configService.test.ts` | 7 | config load/validate, zod schema, BOM stripping, defaults |
| `src/lib/server/db/queries.test.ts` | 22 | FTS search, filters, places, tags queries |
| `src/lib/server/security.test.ts` | 11 | `verifyPassword`, `timingSafeStrEqual` (incl. empty-string + malformed-hash cases) |
| `src/lib/server/http.test.ts` | 7 | HTTP helpers / header/range handling |
| `src/lib/server/scan/scanState.test.ts` | 3 | scan state machine transitions |
| `src/lib/server/scan/pairing.test.ts` | 3 | live-photo / sidecar pairing |
| `src/lib/server/scan/walker.test.ts` | 5 | filesystem walker, ignores, root enumeration |
| `src/lib/server/db/db.test.ts` | 4 | migrations to `TARGET_SCHEMA_VERSION`; core tables/indexes/FTS exist; **v3 retry columns** (`meta_attempts`, `thumb_attempts`, `next_retry_ms` default 0/0/NULL); FTS triggers stay in sync |
| `src/lib/server/media/hashService.test.ts` | 4 | content hashing |
| `src/lib/server/media/exifService.test.ts` | 2 | EXIF extraction (orientation, GPS) |
| `src/lib/server/media/pipeline.test.ts` | 5 | media pipeline with **retry + backoff** |
| `src/lib/server/media/render-core.test.ts` | 3 | shared render core, **deferred preview sizes** |
| `src/lib/shared/edits.test.ts` | 5 | edit model (crop/rotate/adjust serialization) |
| `src/lib/server/media/editService.test.ts` | 3 | sharp-based edit render |
| `src/lib/server/geo/cities.test.ts` | 4 | `nearestCity` reverse-geocode |

The DB tests use an in-memory `openTestDb(':memory:')` helper and assert presence of `idx_media_timeline`, `idx_media_day` (v2), `idx_media_retry` (v3), and tables `media, albums, album_items, trash, scans, roots, media_fts`.

### 10.4 Exact dependency versions (load-bearing)

`archiver ^8.0.0`, `better-sqlite3 ^12.11.1`, `blurhash ^2.0.5`, `chokidar ^5.0.0`, `exifr ^7.1.3`, `ffmpeg-static ^5.3.0`, `ffprobe-static ^3.1.0`, `fluent-ffmpeg ^2.1.3`, `leaflet ^1.9.4`, `leaflet.markercluster ^1.5.3`, `sharp ^0.35.1`, `zod ^3.25.76` (**pinned to v3 line**). Dev: `@sveltejs/adapter-node ^5.5.4`, `@sveltejs/kit ^2.65.2`, `@sveltejs/vite-plugin-svelte ^7.1.2`, `svelte ^5.56.3`, `svelte-check ^4.6.0`, `vite ^8.0.16`, `vitest ^4.1.9`, `@vitest/coverage-v8 ^4.1.9`, `typescript ^6.0.3`, `tailwindcss ^4.3.1` + `@tailwindcss/vite ^4.3.1`, `@lucide/svelte ^1.20.0`. **`overrides.cookie: ^0.7.2`** (forced override — see GOTCHA).

### 10.5 Reference docs (authoritative design)

`docs/01-ARCHITECTURE.md` … `docs/12-ROADMAP.md` (01-ARCHITECTURE, 02-DATA-MODEL, 03-CONFIG, 04-FEATURES, 05-PERFORMANCE, 06-PRIVACY-AND-NETWORK, 07-SECURITY, 08-DATA-SAFETY, 09-API, 10-BUILD-PLAN, 11-TESTING, 12-ROADMAP) and the entire `.claude/memory/*` are reproduced **verbatim in Appendix A** and are the authoritative design references — consult them when this section is silent on a design rationale.

### 10.6 Gotchas & decisions catalog (symptom → fix — MUST apply)

1. **Bun is the package manager/builder, but the server runs under Node.** Symptom: `better-sqlite3` (a native N-API addon) fails/segfaults or won't load in the Bun runtime. Fix: install & build with Bun, but **start the server with `node start.mjs`**; setup installs Node specifically for this. Never change `start` to run under `bun`.

2. **`zod` pinned to v3 (`^3.25.76`).** Symptom: a v4 bump changes error shapes/APIs and breaks `configService` schema parsing + 7 config tests. Fix: keep the `^3` range.

3. **`cookie` override `^0.7.2`.** Symptom: a transitive `cookie` version pulled by SvelteKit triggers a vulnerability / parsing-behavior change. Fix: keep the top-level `overrides.cookie: ^0.7.2`.

4. **exifr `translateValues: false` for orientation.** Symptom: with value translation on, EXIF orientation comes back as a human string instead of the numeric 1–8 the rotate logic expects, so portrait images (the fixture's orientation-6 `portrait.jpg`) render rotated wrong. Fix: read EXIF with `translateValues: false` and treat orientation as the raw integer.

5. **Windows realpath / 8.3 short names + chokidar libuv crash.** Symptom: async vs sync `realpath` and Windows 8.3 short-name aliases make the path allow-list reject valid files, and chokidar can crash libuv on certain Windows paths. Fix: resolve a single **`canonicalRoot`** once (consistent realpath) and base both the allow-list containment check and the chokidar watch on it, avoiding per-call divergence.

6. **archiver v8 is ESM with a `ZipArchive` class.** Symptom: CommonJS-style usage / old import shape fails to build under archiver `^8`. Fix: use the v8 ESM `ZipArchive` API.

7. **vitest ↔ vite version coupling.** Symptom: mismatched `vite`/`vitest` majors fail to resolve the shared config or crash the runner. Fix: keep `vite ^8` with `vitest ^4.1.9` and `@vitest/coverage-v8 ^4.1.9` together.

8. **PowerShell `Set-Content -Encoding utf8` writes a UTF-8 BOM (PS 5.1).** Symptom: the BOM at the start of `lgallery.config.json` breaks JSON parse on load. Fix: the config loader **strips a leading BOM** before `JSON.parse`, and `setup-lgallery.ps1` is kept **ASCII-only** so PS 5.1 doesn't mangle non-ASCII output. (configService tests cover the BOM-strip path.)

9. **`verifyPassword` with an empty/invalid hex matched any password.** Symptom: a malformed or empty stored hash made comparison succeed, accepting any password. Fix: `verifyPassword` returns `false` for non-hash / malformed inputs (`'not-a-real-hash'`, `'scrypt$zz$zz'`), and `timingSafeStrEqual` length-checks before constant-time compare. Covered by security.test.ts.

10. **Worker bundling drift.** Symptom: bundling the render worker via the SvelteKit/Vite graph produced a divergent/duplicated render implementation and load failures. Fix: ship the worker as a **plain `.mjs` loaded by an absolute cwd path** (not bundled), and share the rendering logic through a single **`render-core`** module used by both the worker and the in-process path so the two can't drift.

11. **Deferred-preview cache correctness.** Symptom: stale edited previews served from cache after an edit. Fix: include `edited_ms` in the **ETag** and send **`must-revalidate`** cache headers for deferred/edited previews. (render-core's deferred-sizes test guards the size logic.)

12. **SSR grid needs the client viewport width.** Symptom: server-rendered justified grid guesses the wrong row layout, causing a layout flash on hydration. Fix: read the **`lg_w` cookie** during SSR to seed the layout width.

13. **In-process worker fallback.** Symptom: on environments where spawning the worker thread fails, rendering would stop. Fix: fall back to running the render-core in-process (shared module guarantees identical output).

14. **Append-only migrations.** Symptom: editing an existing migration corrupts already-migrated user databases. Fix: migrations are **append-only**; advance `TARGET_SCHEMA_VERSION` and add a new step. Existing libraries upgrade lazily (e.g. v3 retry columns default 0/0/NULL on existing rows). The runtime smoke confirms a clean v1→v6 path with a backup taken before migrating.

15. **libuv threadpool sizing must precede any sharp/ffmpeg work.** Symptom: thumbnail backfill stays single-/quad-threaded despite many cores. Fix: set `UV_THREADPOOL_SIZE` before the server import — done in `start.mjs` (`max(8, cpus*2)`) and `start-lgallery.cmd` (`16`); never set it after the first threadpool task.

# Appendix A — Verbatim source of all files

The byte-exact contents of every one of the 188 tracked files. Create each file at the
path in its heading with the contents of the block below it. This appendix is the ground truth:
the narrative sections above explain the *why* and the build order; these blocks are the *what*.
(Fences are sized per file so any embedded ``` is preserved — copy the inner content only.)

## File manifest

- `.claude/memory/feedback-bun-tooling.md`
- `.claude/memory/feedback-memory-location.md`
- `.claude/memory/feedback-native-scrollbar.md`
- `.claude/memory/feedback-no-tanstack.md`
- `.claude/memory/feedback-privacy-local-only.md`
- `.claude/memory/MEMORY.md`
- `.claude/memory/project-key-decisions.md`
- `.claude/memory/project-overview.md`
- `.claude/memory/project-status.md`
- `.claude/memory/reference-docs.md`
- `.gitattributes`
- `.gitignore`
- `bun.lock`
- `docs/01-ARCHITECTURE.md`
- `docs/02-DATA-MODEL.md`
- `docs/03-CONFIG.md`
- `docs/04-FEATURES.md`
- `docs/05-PERFORMANCE.md`
- `docs/06-PRIVACY-AND-NETWORK.md`
- `docs/07-SECURITY.md`
- `docs/08-DATA-SAFETY.md`
- `docs/09-API.md`
- `docs/10-BUILD-PLAN.md`
- `docs/11-TESTING.md`
- `docs/12-ROADMAP.md`
- `lgallery.config.example.json`
- `package.json`
- `README.md`
- `scripts/gen-fixtures.mjs`
- `setup-lgallery.cmd`
- `setup-lgallery.ps1`
- `src/ambient.d.ts`
- `src/app.css`
- `src/app.d.ts`
- `src/app.html`
- `src/hooks.server.ts`
- `src/lib/client/api.ts`
- `src/lib/client/blurhash-img.ts`
- `src/lib/client/state/gallery.svelte.ts`
- `src/lib/client/state/scanStatus.svelte.ts`
- `src/lib/client/state/selection.svelte.ts`
- `src/lib/client/state/settings.svelte.ts`
- `src/lib/components/common/CommandPalette.svelte`
- `src/lib/components/common/DensityToggle.svelte`
- `src/lib/components/common/EmptyState.svelte`
- `src/lib/components/common/Logo.svelte`
- `src/lib/components/common/PageHeader.svelte`
- `src/lib/components/common/ScanChip.svelte`
- `src/lib/components/common/SelectionBar.svelte`
- `src/lib/components/common/Skeleton.svelte`
- `src/lib/components/grid/GridTile.svelte`
- `src/lib/components/grid/MediaGridView.svelte`
- `src/lib/components/grid/TimelineGrid.svelte`
- `src/lib/components/lightbox/EditOverlay.svelte`
- `src/lib/components/lightbox/InfoPanel.svelte`
- `src/lib/components/lightbox/Lightbox.svelte`
- `src/lib/components/nav/Sidebar.svelte`
- `src/lib/server/ai/aiService.ts`
- `src/lib/server/ai/aiState.ts`
- `src/lib/server/ai/optional.ts`
- `src/lib/server/ai/vectorIndex.ts`
- `src/lib/server/config/configService.test.ts`
- `src/lib/server/config/configService.ts`
- `src/lib/server/db/db.test.ts`
- `src/lib/server/db/index.ts`
- `src/lib/server/db/migrate.ts`
- `src/lib/server/db/queries.test.ts`
- `src/lib/server/db/queries.ts`
- `src/lib/server/db/schema.ts`
- `src/lib/server/geo/cities.test.ts`
- `src/lib/server/geo/cities.ts`
- `src/lib/server/geo/geocodeService.ts`
- `src/lib/server/http.test.ts`
- `src/lib/server/http.ts`
- `src/lib/server/lock.ts`
- `src/lib/server/log.ts`
- `src/lib/server/media/editService.test.ts`
- `src/lib/server/media/editService.ts`
- `src/lib/server/media/exifService.test.ts`
- `src/lib/server/media/exifService.ts`
- `src/lib/server/media/fileService.ts`
- `src/lib/server/media/hashService.test.ts`
- `src/lib/server/media/hashService.ts`
- `src/lib/server/media/pipeline.test.ts`
- `src/lib/server/media/pipeline.ts`
- `src/lib/server/media/render-core.mjs`
- `src/lib/server/media/render-core.test.ts`
- `src/lib/server/media/streamService.ts`
- `src/lib/server/media/thumbnailService.ts`
- `src/lib/server/media/thumb-worker.mjs`
- `src/lib/server/media/videoService.ts`
- `src/lib/server/media/workerPool.ts`
- `src/lib/server/paths.test.ts`
- `src/lib/server/paths.ts`
- `src/lib/server/scan/pairing.test.ts`
- `src/lib/server/scan/pairing.ts`
- `src/lib/server/scan/scanner.ts`
- `src/lib/server/scan/scanState.test.ts`
- `src/lib/server/scan/scanState.ts`
- `src/lib/server/scan/walker.test.ts`
- `src/lib/server/scan/walker.ts`
- `src/lib/server/scan/watcher.ts`
- `src/lib/server/security.test.ts`
- `src/lib/server/security.ts`
- `src/lib/server/startup.ts`
- `src/lib/shared/blurhash.test.ts`
- `src/lib/shared/blurhash.ts`
- `src/lib/shared/config-schema.ts`
- `src/lib/shared/edits.test.ts`
- `src/lib/shared/edits.ts`
- `src/lib/shared/format.test.ts`
- `src/lib/shared/format.ts`
- `src/lib/shared/layout.test.ts`
- `src/lib/shared/layout.ts`
- `src/lib/shared/types.ts`
- `src/routes/+layout.server.ts`
- `src/routes/+layout.svelte`
- `src/routes/+page.server.ts`
- `src/routes/+page.svelte`
- `src/routes/albums/[id]/+page.server.ts`
- `src/routes/albums/[id]/+page.svelte`
- `src/routes/albums/+page.server.ts`
- `src/routes/albums/+page.svelte`
- `src/routes/api/ai/index/+server.ts`
- `src/routes/api/ai/status/+server.ts`
- `src/routes/api/albums/[id]/+server.ts`
- `src/routes/api/albums/[id]/items/+server.ts`
- `src/routes/api/albums/+server.ts`
- `src/routes/api/auth/login/+server.ts`
- `src/routes/api/auth/logout/+server.ts`
- `src/routes/api/backup/+server.ts`
- `src/routes/api/config/+server.ts`
- `src/routes/api/duplicates/+server.ts`
- `src/routes/api/export/+server.ts`
- `src/routes/api/folders/+server.ts`
- `src/routes/api/map/points/+server.ts`
- `src/routes/api/media/[id]/+server.ts`
- `src/routes/api/media/[id]/edit/+server.ts`
- `src/routes/api/media/[id]/original/+server.ts`
- `src/routes/api/media/[id]/stream/+server.ts`
- `src/routes/api/media/[id]/tags/+server.ts`
- `src/routes/api/media/[id]/thumb/+server.ts`
- `src/routes/api/media/+server.ts`
- `src/routes/api/media/move/+server.ts`
- `src/routes/api/media/rename/+server.ts`
- `src/routes/api/media/trash/+server.ts`
- `src/routes/api/memories/+server.ts`
- `src/routes/api/people/[id]/+server.ts`
- `src/routes/api/people/+server.ts`
- `src/routes/api/places/+server.ts`
- `src/routes/api/scan/+server.ts`
- `src/routes/api/scan/status/+server.ts`
- `src/routes/api/scan/stream/+server.ts`
- `src/routes/api/search/+server.ts`
- `src/routes/api/tags/[id]/+server.ts`
- `src/routes/api/tags/+server.ts`
- `src/routes/api/timeline/+server.ts`
- `src/routes/api/timeline/buckets/+server.ts`
- `src/routes/api/timeline/visible/+server.ts`
- `src/routes/api/trash/+server.ts`
- `src/routes/api/trash/restore/+server.ts`
- `src/routes/archive/+page.svelte`
- `src/routes/duplicates/+page.svelte`
- `src/routes/favorites/+page.svelte`
- `src/routes/folders/+page.server.ts`
- `src/routes/folders/+page.svelte`
- `src/routes/login/+page.svelte`
- `src/routes/map/+page.svelte`
- `src/routes/map/+page.ts`
- `src/routes/memories/+page.svelte`
- `src/routes/people/+page.svelte`
- `src/routes/places/+page.svelte`
- `src/routes/search/+page.svelte`
- `src/routes/settings/+page.server.ts`
- `src/routes/settings/+page.svelte`
- `src/routes/tags/+page.svelte`
- `src/routes/trash/+page.server.ts`
- `src/routes/trash/+page.svelte`
- `src/service-worker.ts`
- `start.mjs`
- `start-lgallery.cmd`
- `start-lgallery-hidden.vbs`
- `static/favicon.svg`
- `static/manifest.webmanifest`
- `svelte.config.js`
- `token-usage.html`
- `tsconfig.json`
- `vite.config.ts`

### `.claude/memory/feedback-bun-tooling.md`

```markdown
---
name: feedback-bun-tooling
description: LGallery uses Bun for tooling (PM/scripts/build) but Node to run the server; user prefers Bun + latest non-vulnerable deps
metadata:
  type: feedback
---

For LGallery the user wants **Bun** used for everything package/script related (`bun install`, `bun run dev|build|test|test:cov|check`; lockfile `bun.lock`; `packageManager: bun@1.3.14`). They also want dependencies kept at the **latest non-vulnerable** versions ("fastest/most-optimized"), verified with `bun audit`.

**Why:** explicit user instruction ("convert all to bun latest and all bun related", "update all packages to latest that are not vulnerable").

**How to apply:**
- The **server runtime stays Node** (`node build`): `better-sqlite3` is unsupported in the Bun runtime (Bun issue #4290). `bun run dev/build/test` are fine because Vite/Vitest run on Node via their bins. Do not try to run the production server under `bun build/index.js`.
- **zod is intentionally pinned to v3** (3.25, latest non-vulnerable v3): zod 4 broke `z.object().default({})` typing with no security benefit. A `cookie` override (`^0.7.2`) clears a transitive kit advisory. Re-run `bun audit` after any dep change; pin back any major that breaks `bun run check`/`build`/`test`.
- The user also asked for: a live **file watcher** (`scan.watch`, no manual rescan), **lightbox click-outside-to-close**, a **Windows autostart** script, and an app **logo**. Treat these as standing expectations. See [[project-status]] and [[project-key-decisions]].
```

### `.claude/memory/feedback-memory-location.md`

```markdown
---
name: feedback-memory-location
description: Keep LGallery's project memory co-located inside repos/LGallery/.claude/memory
metadata:
  type: feedback
---

For the LGallery project, store project memory **inside the project folder** at `C:\Users\clark.bernales\source\repos\LGallery\.claude\memory\` (mirroring how the user's CasewareMapping project keeps `.claude/memory/`), rather than only in the global per-project memory directory.

**Why:** the user explicitly asked to "retain all memory in the same folder as the project in repos/LGallery" so the project's context travels with the project and is visible alongside the code/docs.
**How to apply:** when recording or updating memory about LGallery, write the files here and keep `MEMORY.md` in this folder updated as the index. Use the standard frontmatter + one-fact-per-file format.
```

### `.claude/memory/feedback-native-scrollbar.md`

```markdown
---
name: feedback-native-scrollbar
description: LGallery must use the native browser scrollbar, not Google Photos' custom draggable scrubber
metadata:
  type: feedback
---

In LGallery's timeline, use the **native browser scrollbar** on the right as the scroll control. Do **not** build Google Photos' custom draggable date-scrubber (the user finds it "clunky" and dislikes that it has no real slider). A lightweight floating date label that appears while scrolling is fine, but the scrollbar itself must be the standard one.

**Why:** explicit user preference — they want a normal, real slider scrollbar instead of Google's custom widget.
**How to apply:** the virtualized grid uses a single tall scroll container at the full estimated content height so the browser's own scrollbar reflects position naturally; windowed rows are positioned within it. No custom scrollbar/scrubber component. See [[reference-docs]] (docs/05-PERFORMANCE.md).
```

### `.claude/memory/feedback-no-tanstack.md`

```markdown
---
name: feedback-no-tanstack
description: Avoid @tanstack/svelte-virtual in LGallery; use a custom dependency-free virtualization engine
metadata:
  type: feedback
---

Do **not** use `@tanstack/svelte-virtual` (or other TanStack virtual packages) in LGallery. The user flagged TanStack as compromised and asked to use a different approach. Implement a **custom, dependency-free** virtualization engine for the justified timeline grid.

**Why:** user instruction ("i think tanstack is compromised so use a different one"); also a justified/variable-height row layout is better served by hand-rolled windowing anyway.
**How to apply:** put the pure justified-row layout math in `lib/shared/layout.ts` (unit-tested) and do windowing via binary search on row offsets in `TimelineGrid.svelte`. No third-party virtualization dependency. If a helper lib is ever reconsidered, it must not be TanStack. See [[reference-docs]].
```

### `.claude/memory/feedback-privacy-local-only.md`

```markdown
---
name: feedback-privacy-local-only
description: LGallery must be fully local with zero telemetry; only OSM map tiles and a one-time AI model download may touch the internet
metadata:
  type: feedback
---

LGallery must be **fully local and private**: no telemetry, no analytics, no crash reporting, no external fonts/CDNs, no "check for updates" pings. Errors go to a local log file only.

The **only** permitted runtime outbound connections, all optional/scoped:
1. **OpenStreetMap map tiles** — only while the Map view is open (can be disabled in config).
2. **AI model weights** — a one-time download from Hugging Face, only when the user enables AI features; no personal data/images are sent; can be pre-placed locally for fully offline (`ai.modelSource: "local"`).
3. **Reverse geocoding (Nominatim)** — OFF by default.

**Why:** explicit user requirement to keep everything local and not send personal data/telemetry; they specifically asked to be told what needs internet.
**How to apply:** never add SDKs/CDNs/fonts that phone home; self-host fonts; bundle all assets with Vite; keep map/AI/geocoding behind explicit toggles; if any new feature needs the network, surface it and make it opt-in. See [[reference-docs]] (docs/06-PRIVACY-AND-NETWORK.md).
```

### `.claude/memory/MEMORY.md`

```markdown
# LGallery — Project Memory Index

Project-local memory for **LGallery**, a local Google-Photos-style gallery (SvelteKit). Co-located with the project per the user's preference. One line per memory below.

- [Project Overview](project-overview.md) — what LGallery is and the goal
- [Key Decisions](project-key-decisions.md) — locked architecture/scope decisions
- [Project Status](project-status.md) — planning + docs done, not yet scaffolded
- [Memory Location](feedback-memory-location.md) — keep this project's memory inside repos/LGallery/.claude/memory
- [Native Scrollbar](feedback-native-scrollbar.md) — use native browser scrollbar, not Google's scrubber
- [No TanStack Virtual](feedback-no-tanstack.md) — avoid @tanstack/svelte-virtual; custom virtualization
- [Local-Only Privacy](feedback-privacy-local-only.md) — fully local, zero telemetry; only OSM tiles + 1-time AI model download
- [Bun Tooling](feedback-bun-tooling.md) — Bun for PM/scripts/build, Node runs the server (better-sqlite3); latest non-vulnerable deps (zod pinned v3)
- [Docs Pointer](reference-docs.md) — where the design docs live
```

### `.claude/memory/project-key-decisions.md`

```markdown
---
name: project-key-decisions
description: Locked architecture and scope decisions for LGallery (stack, source, scale, features, AI, network)
metadata:
  type: project
---

Locked decisions for LGallery (confirmed with the user during planning):

- **Source**: one or more root folders listed in a config file `lgallery.config.json`, re-read on server startup AND on page reload (config-hash check → incremental rescan); also editable in a Settings UI.
- **Scale**: 50,000+ files → persistent SQLite index, incremental background scan, on-disk thumbnail cache, virtualized grid, keyset pagination.
- **File mutation**: delete / move / rename real files from the UI; deletes go to a recoverable trash (`data/trash`) with restore + permanent-delete + auto-purge.
- **Features**: timeline-by-date, folder + user albums, search & metadata filters, map view (Leaflet/OSM), fullscreen lightbox (zoom/pan, video via HTTP Range, keyboard, slideshow), favorites, archive, multi-select bulk actions, info/EXIF panel, grid-density toggle, dark mode, Memories/"On this day", duplicate detection, Live/Motion-photo pairing.
- **AI (semantic search via CLIP + face grouping)**: included but **toggleable in Settings, OFF by default**, runs locally; models cached in `data/models/` (or local-only for offline).
- **Stack**: SvelteKit 2 + Svelte 5 runes + TypeScript + Tailwind v4 + adapter-node; `better-sqlite3` + Drizzle; `sharp` + `exifr` + `fluent-ffmpeg`/`ffmpeg-static`; `sqlite-vec` + `@huggingface/transformers` for AI.

Related: [[feedback-native-scrollbar]], [[feedback-no-tanstack]], [[feedback-privacy-local-only]], [[project-overview]]. Full detail in [[reference-docs]].

**Why:** these were explicitly chosen by the user (some overriding sensible defaults), so they should not be re-litigated.
**How to apply:** treat these as fixed inputs when implementing or proposing changes; if a tradeoff forces deviating, flag it rather than silently changing.
```

### `.claude/memory/project-overview.md`

```markdown
---
name: project-overview
description: What LGallery is — a local, private Google-Photos-style gallery built with SvelteKit
metadata:
  type: project
---

**LGallery** is a local, self-hosted "Google Photos"-style web app built with SvelteKit, located at `C:\Users\clark.bernales\source\repos\LGallery`. It indexes images and videos from local folders (configured in `lgallery.config.json`) and presents them like Google Photos: date timeline, albums, search, map, fullscreen lightbox, organize/trash, and optional on-device AI search.

**Goal:** a fast, responsive, fully private gallery the user runs on their own PC (optionally reachable from their phone over the LAN), with no telemetry and no cloud.

Defining constraints: 50,000+ media files (so it must be indexed + virtualized + aggressively optimized), real-file mutation allowed (delete/move/rename with a recoverable trash), and local-only privacy.

See [[project-key-decisions]] for the locked decisions and [[reference-docs]] for the full design docs.
```

### `.claude/memory/project-status.md`

```markdown
---
name: project-status
description: Current LGallery status — P0–P9 + three enhancement passes (Bun, polish, 200k-scale/organize/places/editing); AI off by default
metadata:
  type: project
---

As of 2026-06-17: **the app is built, polished, and on Bun tooling.** Phases **P0–P9** of `docs/10-BUILD-PLAN.md` are implemented and verified, plus two enhancement passes.

**Tooling/runtime (important):** package manager + scripts + bundler driver = **Bun** (`bun install`, `bun run dev|build|test|test:cov|check`, lockfile `bun.lock`). The **server runs on Node** (`node build`) because `better-sqlite3` is unsupported in the Bun runtime (Bun #4290); `bun run dev/build/test` work because Vite/Vitest execute on Node. See [[feedback-bun-tooling]].

**Bun/UX pass (2026-06-17):** converted to Bun; updated all deps to latest non-vulnerable (vite 8, vitest 4, kit 2.65, svelte 5.56, tailwind 4.3, ts 6, sharp 0.35, chokidar 5; **zod pinned v3** — zod 4 broke `.default({})` typing; `cookie` override clears a kit advisory; `bun audit` = 0 vulns). Added: app **logo** (favicon + sidebar); **chokidar live watcher** behind `scan.watch` (auto-index, Settings toggle); lightbox **click-outside-to-close**; Windows **autostart** (`start-lgallery.cmd` / `start-lgallery-hidden.vbs`) + Settings → Startup panel; **canonical root paths** via `fs.realpathSync.native` (expands Windows 8.3 short names — fixes scanner/watcher/allow-list consistency + a libuv fs-event crash) + config BOM tolerance; settings page tokenized. **Vitest 4 + v8 coverage** (`bun run test:cov`), 98 tests; a failure-path test caught + fixed a real `verifyPassword` edge bug (empty-hex hash matched any password).

Done:
- Requirements + docs (see [[project-key-decisions]]).
- **P0** scaffold (SvelteKit 2 / Svelte 5 runes / TS strict / Tailwind v4 / adapter-node), SQLite (WAL pragmas + versioned DDL migrations + FTS5), configService (zod + canonical hash), paths allow-list + realpath guard, logger. Native modules verified on Windows (better-sqlite3, sharp, ffmpeg/ffprobe-static, blurhash).
- **P1** scanner: iterative opendir walker, incremental differ, scan_id sweep, offline-root protection, SSE progress.
- **P2** media pipeline: bounded **in-process** pool (NOT worker_threads — documented deviation in `media/pipeline.ts`; sharp/ffmpeg already offload), sharp grid+preview WebP + blurhash, exifr metadata, ffmpeg poster/probe, generate-on-miss thumb endpoint.
- **P3** timeline grid: pure justified-layout math (`shared/layout.ts`, unit-tested) + custom virtualization with the **native scrollbar**, day/month headers, floating label, bucket height estimate.
- **P4** lightbox + Range serving (206), zoom/pan, video, keyboard, slideshow, EXIF panel.
- **P5** organization: favorites/archive, multi-select bar, albums CRUD, folder browser, zip export.
- **P6** mutations: mutex `fileService` (trash/restore/permanent/move/rename, EXDEV fallback), auto-purge, orphan GC, /trash page.
- **P7** discovery: FTS5 search + filters, quick_hash duplicates, Live/Motion pairing, memories, Leaflet map with server-side clustering.
- **P8** AI **scaffold, OFF by default**: CLIP semantic search + sqlite-vec + face-grouping plumbing via lazy/optional imports (`@huggingface/transformers`, `sqlite-vec` not installed — `optionalImport` keeps the build green). Face *detector* model wiring is the one remaining integration point.
- **P9** polish: Settings UI + `/api/config`, password (scrypt) + session + CSRF + LAN guide, backup/JSON export, service worker + PWA manifest, theme/density.

Verified: production build (adapter-node) + 47 unit tests + svelte-check clean; end-to-end smoke against generated fixtures (scan, thumbnails, timeline/buckets/detail, Range serving, favorite/album/trash/restore/export, search/duplicates/pairing, password auth round-trip).

Git: local commits per phase boundary (P0-P2, P3-P4, P5-P6, P7, P8-P9) + a review-fixes commit. No remote/push.

A final adversarial code-review pass (multi-agent, per-finding verified) caught 17 real issues; 15 were fixed and re-verified (notably: scanner↔fileService now share one mutex; the stale-sweep no longer deletes trashed rows or filter-excluded-but-present files; CSRF double-submit now actually required; load-more no longer stalls past page 1; atomic EXDEV move; per-id pipeline in-flight guard; LIKE escaping; suffix byte-ranges; constant-time session compare). Two low-severity items left as documented TODOs: permanentDelete deletes the DB row even if the FS unlink fails (disk-space leak only), and Live-pair tie-break is arbitrary when >1 same-basename sibling exists (live_partner_id not yet consumed by UI).

Real-world bugs found + fixed during verification: exifr `translateValues` stringified Orientation (broke portrait dims); Windows `fs.promises.realpath` expands 8.3 short names but `fs.realpathSync` doesn't (broke the allow-list); archiver v8 went ESM (`ZipArchive` class, no vending fn); vitest 2 pulled a duplicate Vite (bumped to v3).

Post-build enhancement pass (2026-06-17, plan `~/.claude/plans/for-your-perspective-as-hidden-clock.md`):
- **A — design system:** Tailwind `@theme` design tokens (color/surface/overlay/radius/shadow/motion, light+dark) + `@layer` classes (`.lg-bar`, `.btn*`, `.lg-card`, `.lg-input`, `.lg-ring`, `.lg-skeleton`); shared `PageHeader`/`EmptyState`/`Skeleton`; all ~10 pages + chrome (Sidebar/SelectionBar/ScanChip/DensityToggle/InfoPanel) tokenized; micro-interactions; InfoPanel mobile bottom-sheet.
- **B — load-fast:** @2x HiDPI thumbnails (grid2x + srcset + fetchpriority); **SSR grid layout** via `lg_w` cookie (no blank-then-pop — verified tiles in first HTML); buckets cache + `idx_media_day` (migration v2); blurhash LQIP; map `ssr:false`; adapter precompress.
- **C — video:** preload=metadata; unplayable-codec banner (codec in MediaDetail); **Live/Motion photos wired** (`live_partner_id`): grid LIVE badge + hover-play, lightbox motion toggle.
- **D — features:** command palette (⌘/Ctrl+K) + shortcuts (`?`); Favorites + Archive views; rubber-band drag-select; **reconcileRoots** drops de-configured roots' media (fixes the stale-root leak).

All verified: svelte-check 0/0, 47 tests, production build; runtime smokes for grid2x/SSR/favorites/archive/reconcile. Committed in workstream commits (polish+perf+video, then features+architecture).

**Scale + features pass (2026-06-17, plan `~/.claude/plans/for-your-perspective-as-hidden-clock.md`, commits Workstream A-F):** answered the user's 200k question (thumbnailing IS live/background/resumable; nothing skipped — the one gap was no retry) and shipped:
- **A — 200k thumbnail scale-up:** **worker_threads pool** (`media/workerPool.ts` + `media/thumb-worker.mjs`) for image thumbnailing — all cores, blurhash + DB off the main thread; main thread owns all DB writes. Shared `media/render-core.mjs` is used identically by the worker, the in-process **fallback** (auto if workers can't spawn / `scan.useWorkers:false`), and tests → no drift. **Defer the 1600px preview** (`thumbnails.eagerPreview` default false): backfill renders grid+grid2x only, preview is lazy generate-on-miss (`ensureThumb(id,size)`). **`UV_THREADPOOL_SIZE`** set on the launch path (`start.mjs` launcher + `start-lgallery.cmd`; `package.json start` = `node start.mjs`); startup advises if unset. **Bounded retry** (migration **v3**: `meta_attempts`/`thumb_attempts`/`next_retry_ms` + `idx_media_retry`) with capped exp backoff (`retryBackoffMs`); `pendPredicateFor` selects retriable status-3 rows. Discovery overlap (pipeline kicked after first scan batch), boot reset of crash-stranded status-1 rows, ~5-min back-stop drain, BATCH 500→1000. ETA/throughput in `ScanState` + ScanChip.
- **B — organize (migration v4):** `caption`/`rating`(0-5)/`pick`(±1) columns; FTS recreated with a `caption` column (searchable). API `/api/tags`(+`[id]`), `/api/media/[id]/tags`, `/api/media/[id]` PATCH, bulk PATCH rating/pick. Editable **InfoPanel** (stars/pick/caption/tag-chips), Lightbox keys 0-5/P/X, SelectionBar bulk Rate popover, `/tags` view, search rating/pick filters.
- **C — date-jump scrubber:** `layout.monthMarksFromBuckets` + a draggable year rail on the right edge of TimelineGrid (jump any month; reuses buckets + the floating-date bubble).
- **D — Places (migration v5, OFF by default):** `place_*`/`geocode_status` columns; `config.geocode {enabled, provider: offline|nominatim, email}`. `geo/cities.ts` bundled-city nearest-neighbour for OFFLINE (no network); `geo/geocodeService.ts` background pass, nominatim throttled ≤1 req/s (only opt-in outbound call). `/places` grouped view, `getPlaces`, search `place` filter, InfoPanel place line, Settings section.
- **E — non-destructive editing (migration v6):** `edit_ops`(JSON)+`edited_ms`. `shared/edits.ts` isomorphic op model (rotate/flip/crop + brightness/contrast/saturation/vibrance/warmth + filter presets) with `cssFilterFor` live preview; `media/editService.ts` applies via sharp (exif→crop→flip→rotate→colour) reusing `renderSizesFromPipeline`. `/api/media/[id]/edit` PUT/DELETE/POST(export copy). Thumb endpoint folds `edited_ms` into etag + serves edited derivatives must-revalidate. Edited photos render on the main thread (worker = plain images only). `EditOverlay.svelte` (crop handles, sliders, filter strip) in the Lightbox (Pencil button).
- **F — one-shot setup:** `setup-lgallery.cmd`→`setup-lgallery.ps1` installs Git/Bun/Node (winget + official fallbacks), `bun install` + build, creates config, offers autostart. ASCII-only for PS 5.1.

Verified: svelte-check 0/0, **128 tests** (added retry/backoff, migration-v3 columns, deferred-size render, edits model + sharp render, nearestCity, getPlaces/tags/place+caption-FTS filters, monthMarks), production build OK, runtime smoke (real DB migrated v2→v6 with backup, SSR + APIs + thumbnails serve, places reports geocode-off). Migrations are append-only v1→v6.

Next (optional): wire the AI face detector; offline map tiles; HEIC/RAW decode; XMP sidecars; video transcoding (HEVC/MKV); burst/stack grouping; calendar view; Playwright E2E; multi-root parallel walk; live worker-pool resize on config change. See [[reference-docs]] docs/12-ROADMAP.md.
```

### `.claude/memory/reference-docs.md`

```markdown
---
name: reference-docs
description: Where LGallery's design documentation lives (README + docs/01..12)
metadata:
  type: reference
---

LGallery's full design documentation lives in the project folder:

- `LGallery/README.md` — overview, decisions table, quick start, privacy summary
- `LGallery/docs/01-ARCHITECTURE.md` — stack, folder layout, scan, pipeline, virtualization, serving
- `LGallery/docs/02-DATA-MODEL.md` — SQLite schema, indexes, hot queries, pragmas
- `LGallery/docs/03-CONFIG.md` — full `lgallery.config.json` spec + when it's read
- `LGallery/docs/04-FEATURES.md` — full feature list (core + Google Photos parity + AI)
- `LGallery/docs/05-PERFORMANCE.md` — startup, scanner, thumbnails, video, virtualized grid, DB tuning
- `LGallery/docs/06-PRIVACY-AND-NETWORK.md` — exactly what touches the internet
- `LGallery/docs/07-SECURITY.md` — traversal guard, CSRF, LAN access + password
- `LGallery/docs/08-DATA-SAFETY.md` — DB backup/export, XMP sidecars, trash, resilience, GC
- `LGallery/docs/09-API.md` — endpoint surface
- `LGallery/docs/10-BUILD-PLAN.md` — phased build order (P0..P9)
- `LGallery/docs/11-TESTING.md` — test strategy
- `LGallery/docs/12-ROADMAP.md` — deferred/future work

The approved plan also lives at `C:\Users\clark.bernales\.claude\plans\create-a-local-gallery-hidden-cocoa.md`.

Related: [[project-overview]], [[project-key-decisions]], [[project-status]].
```

### `.gitattributes`

```text
# Normalize line endings to LF in the repo; checkout native on Windows.
* text=auto eol=lf
*.png binary
*.jpg binary
*.webp binary
*.svg text
*.mp4 binary
```

### `.gitignore`

```text
# Dependencies
node_modules/

# App-managed data — never commit personal media, DB, thumbnails, logs
data/
!data/.gitkeep

# Personal config (contains local filesystem paths)
lgallery.config.json

# Build output
.svelte-kit/
build/
dist/

# Test coverage report (generated)
coverage/

# Logs / misc
npm-install.log
*.log
.DS_Store
Thumbs.db

# Editor
.vscode/*
!.vscode/extensions.json
.idea/

# Env
.env
.env.*
!.env.example
```

### `bun.lock`

```text
{
  "lockfileVersion": 1,
  "configVersion": 1,
  "workspaces": {
    "": {
      "name": "lgallery",
      "dependencies": {
        "archiver": "^8.0.0",
        "better-sqlite3": "^12.11.1",
        "blurhash": "^2.0.5",
        "chokidar": "^5.0.0",
        "exifr": "^7.1.3",
        "ffmpeg-static": "^5.3.0",
        "ffprobe-static": "^3.1.0",
        "fluent-ffmpeg": "^2.1.3",
        "leaflet": "^1.9.4",
        "leaflet.markercluster": "^1.5.3",
        "sharp": "^0.35.1",
        "zod": "^3.25.76",
      },
      "devDependencies": {
        "@lucide/svelte": "^1.20.0",
        "@sveltejs/adapter-node": "^5.5.4",
        "@sveltejs/kit": "^2.65.2",
        "@sveltejs/vite-plugin-svelte": "^7.1.2",
        "@tailwindcss/vite": "^4.3.1",
        "@types/archiver": "^8.0.0",
        "@types/better-sqlite3": "^7.6.13",
        "@types/fluent-ffmpeg": "^2.1.28",
        "@types/leaflet": "^1.9.21",
        "@types/leaflet.markercluster": "^1.5.6",
        "@types/node": "^25.9.3",
        "@vitest/coverage-v8": "^4.1.9",
        "svelte": "^5.56.3",
        "svelte-check": "^4.6.0",
        "tailwindcss": "^4.3.1",
        "typescript": "^6.0.3",
        "vite": "^8.0.16",
        "vitest": "^4.1.9",
      },
    },
  },
  "overrides": {
    "cookie": "^0.7.2",
  },
  "packages": {
    "@babel/helper-string-parser": ["@babel/helper-string-parser@7.29.7", "", {}, "sha512-Pb5ijPrZ89GDH8223L4UP8i6QApWxs04RbPQJTeWDV0/keR2E36MeKnyr6LYmUUvqRRI+Iv87SuF1W6ErINzYw=="],

    "@babel/helper-validator-identifier": ["@babel/helper-validator-identifier@7.29.7", "", {}, "sha512-qehxGkRj55h/ff8EMaJ+cYhyaKlHIxqYDn682wQD7RNp9UujOQsHog2uS0r2vzr4pW+sXf90NeeayjcNaX3fFg=="],

    "@babel/parser": ["@babel/parser@7.29.7", "", { "dependencies": { "@babel/types": "^7.29.7" }, "bin": "./bin/babel-parser.js" }, "sha512-hnORnjP/1P/zFEndoeX+n+t1RwWRJiJpM/jO7FW32Kn9r5+sJB2JWOdYo4L6k78j15eCwY3Gm/7364B1EMwtNg=="],

    "@babel/types": ["@babel/types@7.29.7", "", { "dependencies": { "@babel/helper-string-parser": "^7.29.7", "@babel/helper-validator-identifier": "^7.29.7" } }, "sha512-4zBIxpPzowiZpusoFkyGVwakdRJUyuH5PxQ/PrqghfdFWWasvnCdPfQXHrenDai+gyLARulZjZowCOj6fjT4pA=="],

    "@bcoe/v8-coverage": ["@bcoe/v8-coverage@1.0.2", "", {}, "sha512-6zABk/ECA/QYSCQ1NGiVwwbQerUCZ+TQbp64Q3AgmfNvurHH0j8TtXa1qbShXA6qqkpAj4V5W8pP6mLe1mcMqA=="],

    "@derhuerst/http-basic": ["@derhuerst/http-basic@8.2.4", "", { "dependencies": { "caseless": "^0.12.0", "concat-stream": "^2.0.0", "http-response-object": "^3.0.1", "parse-cache-control": "^1.0.1" } }, "sha512-F9rL9k9Xjf5blCz8HsJRO4diy111cayL2vkY2XE4r4t3n0yPXVYy3KD3nJ1qbrSn9743UWSXH4IwuCa/HWlGFw=="],

    "@emnapi/core": ["@emnapi/core@1.10.0", "", { "dependencies": { "@emnapi/wasi-threads": "1.2.1", "tslib": "^2.4.0" } }, "sha512-yq6OkJ4p82CAfPl0u9mQebQHKPJkY7WrIuk205cTYnYe+k2Z8YBh11FrbRG/H6ihirqcacOgl2BIO8oyMQLeXw=="],

    "@emnapi/runtime": ["@emnapi/runtime@1.10.0", "", { "dependencies": { "tslib": "^2.4.0" } }, "sha512-ewvYlk86xUoGI0zQRNq/mC+16R1QeDlKQy21Ki3oSYXNgLb45GV1P6A0M+/s6nyCuNDqe5VpaY84BzXGwVbwFA=="],

    "@emnapi/wasi-threads": ["@emnapi/wasi-threads@1.2.1", "", { "dependencies": { "tslib": "^2.4.0" } }, "sha512-uTII7OYF+/Mes/MrcIOYp5yOtSMLBWSIoLPpcgwipoiKbli6k322tcoFsxoIIxPDqW01SQGAgko4EzZi2BNv2w=="],

    "@img/colour": ["@img/colour@1.1.0", "", {}, "sha512-Td76q7j57o/tLVdgS746cYARfSyxk8iEfRxewL9h4OMzYhbW4TAcppl0mT4eyqXddh6L/jwoM75mo7ixa/pCeQ=="],

    "@img/sharp-darwin-arm64": ["@img/sharp-darwin-arm64@0.35.1", "", { "optionalDependencies": { "@img/sharp-libvips-darwin-arm64": "1.3.0" }, "os": "darwin", "cpu": "arm64" }, "sha512-T15JRWOubQ3f5+GxnWeIvo47u5qV0M9HBgJhT+f2gE1e9e6OhR6K73Re52Hm80qWcu1DNb3GweKmpr/MnuP2Ow=="],

    "@img/sharp-darwin-x64": ["@img/sharp-darwin-x64@0.35.1", "", { "optionalDependencies": { "@img/sharp-libvips-darwin-x64": "1.3.0" }, "os": "darwin", "cpu": "x64" }, "sha512-t1CPD0cr7XCHjwUj6tQ5MC0pCi866I+gUW6zbUX4aFPnKd1DFBtk0M+gWcjX8VeEzgfCNiSiNTVFZ6b7kvdbnQ=="],

    "@img/sharp-freebsd-wasm32": ["@img/sharp-freebsd-wasm32@0.35.1", "", { "dependencies": { "@img/sharp-wasm32": "0.35.1" }, "os": "freebsd" }, "sha512-MBSQXqNPThW9EcZ905H6N4sEdX5EwZEYzGx5EBq9ncDCGJALMiY1xPFJxNdzuB1iBjLOpIfxajM6YxdvwmQSLA=="],

    "@img/sharp-libvips-darwin-arm64": ["@img/sharp-libvips-darwin-arm64@1.3.0", "", { "os": "darwin", "cpu": "arm64" }, "sha512-EKbmBKtyTH+GPFDRw2TgK2oV6hyxxlJVIar4hoTYSNmIwipgMFdxPQqR392GmfdsPGWga0mCFN1cCKjRb9cljw=="],

    "@img/sharp-libvips-darwin-x64": ["@img/sharp-libvips-darwin-x64@1.3.0", "", { "os": "darwin", "cpu": "x64" }, "sha512-Pl2OmOvrJ42adUllESxBsG54PfXLo1OYg9i3c5/5Ln/qJ0gZuTM9YMhQJPIbXqwidLRc/c2zuHt4RsrymmNv7A=="],

    "@img/sharp-libvips-linux-arm": ["@img/sharp-libvips-linux-arm@1.3.0", "", { "os": "linux", "cpu": "arm" }, "sha512-A8UpHoUDW4DwnXoV6+q3C1s7QLRAHtPDEjWuNZjwHMyoCNZnm0GeNN8ls9f/bsEYTRQRW96C/n34XJQHJ2fT7A=="],

    "@img/sharp-libvips-linux-arm64": ["@img/sharp-libvips-linux-arm64@1.3.0", "", { "os": "linux", "cpu": "arm64" }, "sha512-C0SqjoFKnszqa44EQ7xoaT48nnO0lOyXEULfXMWi8krrjOPGYkeK30Okzla6ATbBYsyZ0ySinK0FVkpv3DwzfQ=="],

    "@img/sharp-libvips-linux-ppc64": ["@img/sharp-libvips-linux-ppc64@1.3.0", "", { "os": "linux", "cpu": "ppc64" }, "sha512-WOpkVxAjFd369iaIzEgNRreFD+gWdUMIGD5zplhNKNeqS6mm5dac3q2AFyCBmzYoAdouzZvRBgxy4z8QHZb4/A=="],

    "@img/sharp-libvips-linux-riscv64": ["@img/sharp-libvips-linux-riscv64@1.3.0", "", { "os": "linux", "cpu": "none" }, "sha512-DRWw0mOHusrCCuw2rqP87oLg6PGlkomVDFqw2hIwsSfwWpu4k3XLcBPaKKl6ct/GtL/cwNkgwjV/tc0Mqht3VA=="],

    "@img/sharp-libvips-linux-s390x": ["@img/sharp-libvips-linux-s390x@1.3.0", "", { "os": "linux", "cpu": "s390x" }, "sha512-9APy+nFWhHS+kzLgWZfLcyrUd7YqnAQVa4BPOo4xkoHpdoktOAPG4cEr9+Jpl0TtqfVmcMJimNL5qNTyyOHZNA=="],

    "@img/sharp-libvips-linux-x64": ["@img/sharp-libvips-linux-x64@1.3.0", "", { "os": "linux", "cpu": "x64" }, "sha512-y9RNUYDe2A1UAdhLyfeOodGRszQdaEoe4nfOpp/sNVPl2CWIcUyFaDoCh4vPLPxu19803j2naLqZup2WxDXCLA=="],

    "@img/sharp-libvips-linuxmusl-arm64": ["@img/sharp-libvips-linuxmusl-arm64@1.3.0", "", { "os": "linux", "cpu": "arm64" }, "sha512-cC1wkC0Mlucd0KSiGrLkJnB/ZqPvZCntc/Lk7ZnYO5ZSbF2euNek4Xvxafojq+wN1q/W0eprdpUIjUr/EV2PBg=="],

    "@img/sharp-libvips-linuxmusl-x64": ["@img/sharp-libvips-linuxmusl-x64@1.3.0", "", { "os": "linux", "cpu": "x64" }, "sha512-LiYMhUZicB1QG//+RvmYZpXJO8fYRENfp+MZUCnG9aw+AKvGAy9gPaCnuwsPcBFs8EV66M0NNxj9VHcNklE8zw=="],

    "@img/sharp-linux-arm": ["@img/sharp-linux-arm@0.35.1", "", { "optionalDependencies": { "@img/sharp-libvips-linux-arm": "1.3.0" }, "os": "linux", "cpu": "arm" }, "sha512-jygmR02PpCYypt7xB7nst1vqjZp/BpRA/Kf9nK7qRponJ/KrLPaZWEG4G15z1d2FZ6XqI+T0350ha3RSnKx24A=="],

    "@img/sharp-linux-arm64": ["@img/sharp-linux-arm64@0.35.1", "", { "optionalDependencies": { "@img/sharp-libvips-linux-arm64": "1.3.0" }, "os": "linux", "cpu": "arm64" }, "sha512-ErCRyGU7LeoaFBZ0xW8hhLlXzhAg80sc4vxePB86qvtEvW1jEhhmbiNBP4oEzZfPMnu6HwHXfzD2W2kBU+RnCw=="],

    "@img/sharp-linux-ppc64": ["@img/sharp-linux-ppc64@0.35.1", "", { "optionalDependencies": { "@img/sharp-libvips-linux-ppc64": "1.3.0" }, "os": "linux", "cpu": "ppc64" }, "sha512-LUWZ2+r2UoLCd8j0RLCwQ4gL6w47+Y7igxtVnPIDXOOEjV86LpBkAHq5VpJeg+GHbw0KN/JWlPJOdZjyZnFqFQ=="],

    "@img/sharp-linux-riscv64": ["@img/sharp-linux-riscv64@0.35.1", "", { "optionalDependencies": { "@img/sharp-libvips-linux-riscv64": "1.3.0" }, "os": "linux", "cpu": "none" }, "sha512-i7x6J3mwF4JgT0sM4V4WlAWdJ0bucPtA9rzO1bTji1n5qgBq/W5nn87RvOQPleuuxahNoLdTngByD8/vDDLArw=="],

    "@img/sharp-linux-s390x": ["@img/sharp-linux-s390x@0.35.1", "", { "optionalDependencies": { "@img/sharp-libvips-linux-s390x": "1.3.0" }, "os": "linux", "cpu": "s390x" }, "sha512-0zSaTUjTF0kIWTSYxD4EG/nvCU4jez53+3RdURtoY3HvbXtIQ98W90JnrGz/oLRFuEnfIy9+7xeq883euc0ZWw=="],

    "@img/sharp-linux-x64": ["@img/sharp-linux-x64@0.35.1", "", { "optionalDependencies": { "@img/sharp-libvips-linux-x64": "1.3.0" }, "os": "linux", "cpu": "x64" }, "sha512-NbJD4mWdeyrNQKluO/tR/wBDOelcowSVGNBWxI0e3ZtlXc6F/UOVKDj1MLD4zl3oHTuvKW3s+MA9N54YTldAYw=="],

    "@img/sharp-linuxmusl-arm64": ["@img/sharp-linuxmusl-arm64@0.35.1", "", { "optionalDependencies": { "@img/sharp-libvips-linuxmusl-arm64": "1.3.0" }, "os": "linux", "cpu": "arm64" }, "sha512-VoW2sQCWI+0YIKQEmWJ8vzaQjTg9wIyfkFpvEfAS2h43X6iHu7GTk1hhOgB4IpSzCHe8UwQZIcx7b81VTaOrJA=="],

    "@img/sharp-linuxmusl-x64": ["@img/sharp-linuxmusl-x64@0.35.1", "", { "optionalDependencies": { "@img/sharp-libvips-linuxmusl-x64": "1.3.0" }, "os": "linux", "cpu": "x64" }, "sha512-LjBoSd/c5JU0/K5MwzDMlgsSRP2bPn98JQGFFQAOLQ0bU/1z4ekxUdSKY9BmlwSh/cA+OrvpgsWqfZyYfVHBRw=="],

    "@img/sharp-wasm32": ["@img/sharp-wasm32@0.35.1", "", { "dependencies": { "@emnapi/runtime": "^1.11.0" } }, "sha512-PCQUoQdZyE8tp3HpbevuihfUmgSP4qWI0FGEPWoeXqaS+cUrFfemabHQiebUmUmlUhCuNnQMxGrQ+CPqK4hnxg=="],

    "@img/sharp-webcontainers-wasm32": ["@img/sharp-webcontainers-wasm32@0.35.1", "", { "dependencies": { "@img/sharp-wasm32": "0.35.1" }, "cpu": "none" }, "sha512-xU2ml2bU2OPxYVvW2A6ae4M1g5QKyhKG06P4FAt+YEaFQQO0919Qx+XxIZEUuWTMoDViLpMws2/dQwoe/VcA6A=="],

    "@img/sharp-win32-arm64": ["@img/sharp-win32-arm64@0.35.1", "", { "os": "win32", "cpu": "arm64" }, "sha512-IkmHwuFhYpd3bTsN5SAahjwhiAcyXPooBt8vEUgxY3T0IP70sSJ0nU1xiPzZY8AH/OB1XpV3j8aZSVSOSfTbdA=="],

    "@img/sharp-win32-ia32": ["@img/sharp-win32-ia32@0.35.1", "", { "os": "win32", "cpu": "ia32" }, "sha512-wQahqCi9MD8Yxzg4gVM4fNrZxh+r6vD55PyIg+WJPaM5ZRUyF35iQpwJCuma3r6viU9/8Pxlc+XHV+woVa6nCQ=="],

    "@img/sharp-win32-x64": ["@img/sharp-win32-x64@0.35.1", "", { "os": "win32", "cpu": "x64" }, "sha512-WzBtkYtZHATLPe8XRharxZXxQ9cdLrQWHiwxt+BJ5rBsisQrKeeV86ErxPSVhcG6xCEuNhs0SqLpWr7XDa2k6w=="],

    "@jridgewell/gen-mapping": ["@jridgewell/gen-mapping@0.3.13", "", { "dependencies": { "@jridgewell/sourcemap-codec": "^1.5.0", "@jridgewell/trace-mapping": "^0.3.24" } }, "sha512-2kkt/7niJ6MgEPxF0bYdQ6etZaA+fQvDcLKckhy1yIQOzaoKjBBjSj63/aLVjYE3qhRt5dvM+uUyfCg6UKCBbA=="],

    "@jridgewell/remapping": ["@jridgewell/remapping@2.3.5", "", { "dependencies": { "@jridgewell/gen-mapping": "^0.3.5", "@jridgewell/trace-mapping": "^0.3.24" } }, "sha512-LI9u/+laYG4Ds1TDKSJW2YPrIlcVYOwi2fUC6xB43lueCjgxV4lffOCZCtYFiH6TNOX+tQKXx97T4IKHbhyHEQ=="],

    "@jridgewell/resolve-uri": ["@jridgewell/resolve-uri@3.1.2", "", {}, "sha512-bRISgCIjP20/tbWSPWMEi54QVPRZExkuD9lJL+UIxUKtwVJA8wW1Trb1jMs1RFXo1CBTNZ/5hpC9QvmKWdopKw=="],

    "@jridgewell/sourcemap-codec": ["@jridgewell/sourcemap-codec@1.5.5", "", {}, "sha512-cYQ9310grqxueWbl+WuIUIaiUaDcj7WOq5fVhEljNVgRfOUhY9fy2zTvfoqWsnebh8Sl70VScFbICvJnLKB0Og=="],

    "@jridgewell/trace-mapping": ["@jridgewell/trace-mapping@0.3.31", "", { "dependencies": { "@jridgewell/resolve-uri": "^3.1.0", "@jridgewell/sourcemap-codec": "^1.4.14" } }, "sha512-zzNR+SdQSDJzc8joaeP8QQoCQr8NuYx2dIIytl1QeBEZHJ9uW6hebsrYgbz8hJwUQao3TWCMtmfV8Nu1twOLAw=="],

    "@lucide/svelte": ["@lucide/svelte@1.20.0", "", { "peerDependencies": { "svelte": "^5" } }, "sha512-s7TKCHEtFEfflOUDPRC0WBZEjoNJHtj/aUmuWxopFe3AKecEoKvMmCaO0sBDkflok8nR0BCFsm44QF+S6/gc+w=="],

    "@napi-rs/wasm-runtime": ["@napi-rs/wasm-runtime@1.1.5", "", { "dependencies": { "@tybys/wasm-util": "^0.10.2" }, "peerDependencies": { "@emnapi/core": "^1.7.1", "@emnapi/runtime": "^1.7.1" } }, "sha512-AWPoBRJ9tsnVhor4sjO7rkni+7p+2IAEFj6cx06UgP10jkQHqay/36uRV/bFkgrh18D9vb4cr8Q0Pthskgzy+Q=="],

    "@oxc-project/types": ["@oxc-project/types@0.133.0", "", {}, "sha512-KzkdCd6Uxqnf6l3HOw1xfatAlUURA0g14cvBYFyJ5SaNOQbOUvBr9PKArcPcrNIeRsBdgcUzOGrhKveVpvOIGA=="],

    "@polka/url": ["@polka/url@1.0.0-next.29", "", {}, "sha512-wwQAWhWSuHaag8c4q/KN/vCoeOJYshAIvMQwD4GpSb3OiZklFfvAgmj0VCBBImRpuF/aFgIRzllXlVX93Jevww=="],

    "@rolldown/binding-android-arm64": ["@rolldown/binding-android-arm64@1.0.3", "", { "os": "android", "cpu": "arm64" }, "sha512-454rs7jHngixp/NMxd5srYD57OnzSlZ/eFTETjORQHLwJG1lRtmNOJcBerZlfu4GjKqeq8aCCIQrMdHyhI51Hw=="],

    "@rolldown/binding-darwin-arm64": ["@rolldown/binding-darwin-arm64@1.0.3", "", { "os": "darwin", "cpu": "arm64" }, "sha512-PcAhP+ynjURNyy8SKGl5DQP94aGuB/7JrXJb/t7P+hanXvQVMWzUvRRhBAcg/lNRadBhoUPqSoP4xw5tR/KBEA=="],

    "@rolldown/binding-darwin-x64": ["@rolldown/binding-darwin-x64@1.0.3", "", { "os": "darwin", "cpu": "x64" }, "sha512-9YpfeUvSE2RS7wysJ81uOZkXJz7f7Q55H2Gvp3VEw/EsahqDtrphrZ0EwDLK5vvKOzaCrBsjF8JmnMLcUt78Gg=="],

    "@rolldown/binding-freebsd-x64": ["@rolldown/binding-freebsd-x64@1.0.3", "", { "os": "freebsd", "cpu": "x64" }, "sha512-yB1IlAsSNHncV6SCTL27/MVGR5htvQsoGxIv5KMGXALp+Ll1wYsn+x98M9MW7qa+NdSbvrrY7ANI4wLJ0n1e6g=="],

    "@rolldown/binding-linux-arm-gnueabihf": ["@rolldown/binding-linux-arm-gnueabihf@1.0.3", "", { "os": "linux", "cpu": "arm" }, "sha512-Yi30IVAAfLUCy2MseFjbB1jAMDl1VMCAas5StnYp8da9+CKvMd2H2cbEjWcw5NPaPqzvYkVIaF1nNUG+b7u/sw=="],

    "@rolldown/binding-linux-arm64-gnu": ["@rolldown/binding-linux-arm64-gnu@1.0.3", "", { "os": "linux", "cpu": "arm64" }, "sha512-jsO7R8To+AdlYgUmN5sHSCZbfhtMBkO0WUx8iORQnPcMMdgr7qM2DQmMwgabs3GhNztdmoKkMKQFHD6DTMCIQw=="],

    "@rolldown/binding-linux-arm64-musl": ["@rolldown/binding-linux-arm64-musl@1.0.3", "", { "os": "linux", "cpu": "arm64" }, "sha512-VWkUHwWriDciit80wleYwKILoR/KMvxh/IdwS/paX+ZgpuRpCrKLUdadJbc0NpBEiyhpYawsJ73j9aCvOH+f7Q=="],

    "@rolldown/binding-linux-ppc64-gnu": ["@rolldown/binding-linux-ppc64-gnu@1.0.3", "", { "os": "linux", "cpu": "ppc64" }, "sha512-5f1laC0SlIR0yDbFCd8acUhvJIag6N3zC5P7oUPN6wX0aOma+uKJ0wBDH5aq7I1PVI2ttTlhJwzwRIBnLiSGEg=="],

    "@rolldown/binding-linux-s390x-gnu": ["@rolldown/binding-linux-s390x-gnu@1.0.3", "", { "os": "linux", "cpu": "s390x" }, "sha512-Iq4ko0r4XsgbrF/LunNgHtAGLRRVE2kXonAXQ/MV0mC6jQpMOhW1SvtZja2EhC/kd05++bP78dsqBeIQyYJ6Yg=="],

    "@rolldown/binding-linux-x64-gnu": ["@rolldown/binding-linux-x64-gnu@1.0.3", "", { "os": "linux", "cpu": "x64" }, "sha512-B8m6tD5+/N5FeNQFbKlLA/2yVq9ycQP1SeedyEYYKWBNR3ZQbkvIUcNnDNM03lO1l5F2roiiFJGgvoLLyZXtSg=="],

    "@rolldown/binding-linux-x64-musl": ["@rolldown/binding-linux-x64-musl@1.0.3", "", { "os": "linux", "cpu": "x64" }, "sha512-pSdpdUJHkuCxun9LE7jvgUB9qsRgaiyNNCX7m/AvHTcq67AiT/Yhoxvw5zPfhrM8k/BfP8ce/hMOpthKDpEUow=="],

    "@rolldown/binding-openharmony-arm64": ["@rolldown/binding-openharmony-arm64@1.0.3", "", { "os": "none", "cpu": "arm64" }, "sha512-OXXS3RKJgX2uLwM+gYyuH5omcH8fL1LJs96pZGgtetVCahON57+d4SJHzTgZiOjxgGkSnpXpOsWuPDGAKAigEg=="],

    "@rolldown/binding-wasm32-wasi": ["@rolldown/binding-wasm32-wasi@1.0.3", "", { "dependencies": { "@emnapi/core": "1.10.0", "@emnapi/runtime": "1.10.0", "@napi-rs/wasm-runtime": "^1.1.4" }, "cpu": "none" }, "sha512-JTtb8BWFynicNSoPrehsCzBtOKjZ6jhMiPFEmOiuXg1Fl8dn2KHQob+GuPSGR0dryQa1PQJbzjF3dqO/whhjLg=="],

    "@rolldown/binding-win32-arm64-msvc": ["@rolldown/binding-win32-arm64-msvc@1.0.3", "", { "os": "win32", "cpu": "arm64" }, "sha512-gEdFFEN70A/jxb2svrWsN3aDL7OUtmvlOy+6fa2jxG8K0wQ1ZbdeLGnidov6Yu5/733dI5ySfzFlQ/cb0bSz1g=="],

    "@rolldown/binding-win32-x64-msvc": ["@rolldown/binding-win32-x64-msvc@1.0.3", "", { "os": "win32", "cpu": "x64" }, "sha512-eXB7CHuaQdqmJcc3koCNtNPmT/bj2gc999kUFgBxG8Ac0NdgXc4rkCHhqrgrhN3zddvvvrgzj1e90SuSfmyIXA=="],

    "@rolldown/pluginutils": ["@rolldown/pluginutils@1.0.1", "", {}, "sha512-2j9bGt5Jh8hj+vPtgzPtl72j0yRxHAyumoo6TNfAjsLB04UtpSvPbPcDcBMxz7n+9CYB0c1GxQFxYRg2jimqGw=="],

    "@rollup/plugin-commonjs": ["@rollup/plugin-commonjs@29.0.3", "", { "dependencies": { "@rollup/pluginutils": "^5.0.1", "commondir": "^1.0.1", "estree-walker": "^2.0.2", "fdir": "^6.2.0", "is-reference": "1.2.1", "magic-string": "^0.30.3", "picomatch": "^4.0.2" }, "peerDependencies": { "rollup": "^2.68.0||^3.0.0||^4.0.0" }, "optionalPeers": ["rollup"] }, "sha512-ZaOxZceP7SOUW7Lqw5IRVweSQYWaeIPnXIGLiB690EBA3FGJTO40EEr2L5yZplJWsgTCogILRSpcAe7+U0Otdg=="],

    "@rollup/plugin-json": ["@rollup/plugin-json@6.1.0", "", { "dependencies": { "@rollup/pluginutils": "^5.1.0" }, "peerDependencies": { "rollup": "^1.20.0||^2.0.0||^3.0.0||^4.0.0" }, "optionalPeers": ["rollup"] }, "sha512-EGI2te5ENk1coGeADSIwZ7G2Q8CJS2sF120T7jLw4xFw9n7wIOXHo+kIYRAoVpJAN+kmqZSoO3Fp4JtoNF4ReA=="],

    "@rollup/plugin-node-resolve": ["@rollup/plugin-node-resolve@16.0.3", "", { "dependencies": { "@rollup/pluginutils": "^5.0.1", "@types/resolve": "1.20.2", "deepmerge": "^4.2.2", "is-module": "^1.0.0", "resolve": "^1.22.1" }, "peerDependencies": { "rollup": "^2.78.0||^3.0.0||^4.0.0" }, "optionalPeers": ["rollup"] }, "sha512-lUYM3UBGuM93CnMPG1YocWu7X802BrNF3jW2zny5gQyLQgRFJhV1Sq0Zi74+dh/6NBx1DxFC4b4GXg9wUCG5Qg=="],

    "@rollup/pluginutils": ["@rollup/pluginutils@5.4.0", "", { "dependencies": { "@types/estree": "^1.0.0", "estree-walker": "^2.0.2", "picomatch": "^4.0.2" }, "peerDependencies": { "rollup": "^1.20.0||^2.0.0||^3.0.0||^4.0.0" }, "optionalPeers": ["rollup"] }, "sha512-MfPp06CjRLfXQ3wY0R8vJDYBy/MvVcc9OulEfR0B8Iv9ko+GCNaRZ+EpJYFl27LhKsZK0o420sYCRHCjfCgeUg=="],

    "@rollup/rollup-android-arm-eabi": ["@rollup/rollup-android-arm-eabi@4.62.0", "", { "os": "android", "cpu": "arm" }, "sha512-IPIQ55ythEHkfEd9jMEi32OQ7SxURsGA43JI22lj01OLZNt2NUbJX8YUHxkVWyQ6daHPNn0truF5nSj3DQp6YQ=="],

    "@rollup/rollup-android-arm64": ["@rollup/rollup-android-arm64@4.62.0", "", { "os": "android", "cpu": "arm64" }, "sha512-M6s9cr10MibETyo8JsOkq+Lo1+lU6hcvb1MApnUql5qte/5hMEgzlN8/ReIKNfRV8rrqX50W1BX9zoUhC192RA=="],

    "@rollup/rollup-darwin-arm64": ["@rollup/rollup-darwin-arm64@4.62.0", "", { "os": "darwin", "cpu": "arm64" }, "sha512-BqCoMoIbn0keKys+dEAdBa70EtOwV1bEsQCUgU9FdiZmmMge/Zk7LlkYGqbrdHR+Frnt0E1FOanly+rlwvvQzw=="],

    "@rollup/rollup-darwin-x64": ["@rollup/rollup-darwin-x64@4.62.0", "", { "os": "darwin", "cpu": "x64" }, "sha512-SIMzST3VFNXDAbeIWDWiFCNM5qncUBDWaEV7NfE7oZbDt2mgfW4MvbKdbYiGOLoM32gbTv608UMd0XktEYSD7w=="],

    "@rollup/rollup-freebsd-arm64": ["@rollup/rollup-freebsd-arm64@4.62.0", "", { "os": "freebsd", "cpu": "arm64" }, "sha512-ezjfSQMP7ArdUsbBwbQIfwAlhE84I2iVnzQNCFSveqV42q+BmKlzVpf7mxv5EchLcoWU4y6/heFzVg1F+hodUQ=="],

    "@rollup/rollup-freebsd-x64": ["@rollup/rollup-freebsd-x64@4.62.0", "", { "os": "freebsd", "cpu": "x64" }, "sha512-9+qTWGW9AZRhnUgwtTwzNwcPlL87ngkeN0LA+q1bADvmY9aNvWaF2TFW8BZgnQPYxpDI7+rMVLivcd4V737TAQ=="],

    "@rollup/rollup-linux-arm-gnueabihf": ["@rollup/rollup-linux-arm-gnueabihf@4.62.0", "", { "os": "linux", "cpu": "arm" }, "sha512-T1dMEQhXA/jkJ/jyMIw9IovK8bSUq7A8kLIlvZTb/6YIVsp2zLavr4F3oyllHWo7eIVJRyE5n3tUjQJEbE1IuQ=="],

    "@rollup/rollup-linux-arm-musleabihf": ["@rollup/rollup-linux-arm-musleabihf@4.62.0", "", { "os": "linux", "cpu": "arm" }, "sha512-2as0LgT7qQpyceQq6VUJYnumUMUrgGQCWIiDIN9DE0/tglsk6o66uCB4f3djRawAltvfCNLyZZrsqbPA6inCsA=="],

    "@rollup/rollup-linux-arm64-gnu": ["@rollup/rollup-linux-arm64-gnu@4.62.0", "", { "os": "linux", "cpu": "arm64" }, "sha512-bVURMg+6eNN9C/yc0aVjooZcwTTtYF4YW3xta5pP0//r3o1V8gXEHXWCndj47w/HhwsFroZrFhR+6uQP5T0n0g=="],

    "@rollup/rollup-linux-arm64-musl": ["@rollup/rollup-linux-arm64-musl@4.62.0", "", { "os": "linux", "cpu": "arm64" }, "sha512-Ful8pM/2yYI83PViWdFdpZhdI8HJ5qsXANe5atypbHDf+KIBBDsZsbyy8hbXnULVvW9NsTh5DHwbcBftyLTfiw=="],

    "@rollup/rollup-linux-loong64-gnu": ["@rollup/rollup-linux-loong64-gnu@4.62.0", "", { "os": "linux", "cpu": "none" }, "sha512-9Gp/DgrkzfUBmNPVTyPTvay+4xEP7M/clXpj3efXBcm6uTIVIgDg4rqUpqKXvLEuFRVuEpSAOkhgNeecvaZ4Cg=="],

    "@rollup/rollup-linux-loong64-musl": ["@rollup/rollup-linux-loong64-musl@4.62.0", "", { "os": "linux", "cpu": "none" }, "sha512-m9tsJz54LUXkSYM8+8PG81B9IKK5r+2T0clMq4QrS16xFosufU7firBDAZEsDheDs7wTlP7h3++S7lMsU955HA=="],

    "@rollup/rollup-linux-ppc64-gnu": ["@rollup/rollup-linux-ppc64-gnu@4.62.0", "", { "os": "linux", "cpu": "ppc64" }, "sha512-3UvJ5PNVU16aJf6M3tFI24pWzAl2/ynfbyRN3ICyQajK1lSkrnVYNnLz3v04J32qKa0FczJc22zeToc0lr2A3w=="],

    "@rollup/rollup-linux-ppc64-musl": ["@rollup/rollup-linux-ppc64-musl@4.62.0", "", { "os": "linux", "cpu": "ppc64" }, "sha512-vRWUAbYLGHBZS6Q8Msb2sfnf1fvJf+47t8l/TwOerM2qArzy+IeNMTHrYLHXh95h8MoatPHI5hhSZNs+mGXKPg=="],

    "@rollup/rollup-linux-riscv64-gnu": ["@rollup/rollup-linux-riscv64-gnu@4.62.0", "", { "os": "linux", "cpu": "none" }, "sha512-c00T5SYENHAt86cfW47URaP3Us5vLC/4QO7GYud1G5VNRffCwwCuBspwqYrriuJB+5m0WFzClCn9wed0FBjKvg=="],

    "@rollup/rollup-linux-riscv64-musl": ["@rollup/rollup-linux-riscv64-musl@4.62.0", "", { "os": "linux", "cpu": "none" }, "sha512-krrCDilhXOwFkSkO3Wm9I/f9H0L92XHHwy2fwxjukxIbh0dem8gZqOW5Y8BsHrpJv5qwlRBV+Wl4ZFyRWhUpwg=="],

    "@rollup/rollup-linux-s390x-gnu": ["@rollup/rollup-linux-s390x-gnu@4.62.0", "", { "os": "linux", "cpu": "s390x" }, "sha512-7pfYFSTc4/rUC/FtAI0Qp6QthDBCIi6/AuP1xYqFk5vanI6KnL5dWKP60OM/05LOsbwTmIcvr6eXC4CJuJ75IA=="],

    "@rollup/rollup-linux-x64-gnu": ["@rollup/rollup-linux-x64-gnu@4.62.0", "", { "os": "linux", "cpu": "x64" }, "sha512-7SDIalKeIpG0Ifogbbdn58HmSotYMlf23K3dCJEmiVd9Fg36Vmni82iPQec27N3wY4Bvbxftkxz6vSx9OcouTg=="],

    "@rollup/rollup-linux-x64-musl": ["@rollup/rollup-linux-x64-musl@4.62.0", "", { "os": "linux", "cpu": "x64" }, "sha512-eRZevouTH2i1HeAVLqJuLnt256krQkGY0TN6WsTmsIhuzbh457HuWDMakKwmi0Cjadux983CoSr8Lim2QhUIFw=="],

    "@rollup/rollup-openbsd-x64": ["@rollup/rollup-openbsd-x64@4.62.0", "", { "os": "openbsd", "cpu": "x64" }, "sha512-3oVS7FLGa4U1qcvao9ylGxrjXZyUQqR8UwxEcnUEyPX53O/C/mKDZegNXTdHCP+h3e6ta/f1EN38Yif1mmZHYg=="],

    "@rollup/rollup-openharmony-arm64": ["@rollup/rollup-openharmony-arm64@4.62.0", "", { "os": "none", "cpu": "arm64" }, "sha512-yTB9TgfWj5wHe5QgktAgXTLLot1gvEjl1NiPPAUiCs4oPrIWFl5V4nC3GrkNdj9LaAU4s94nVrGbGOCqUpyWsg=="],

    "@rollup/rollup-win32-arm64-msvc": ["@rollup/rollup-win32-arm64-msvc@4.62.0", "", { "os": "win32", "cpu": "arm64" }, "sha512-5LOhoaesY3doG1c+ac/2JtgREpKoJr5bUHH8tKY0V8di7+uSV6BwLs2PlR0/yzefGOkR+wE7ZolZphHCsyG5Rw=="],

    "@rollup/rollup-win32-ia32-msvc": ["@rollup/rollup-win32-ia32-msvc@4.62.0", "", { "os": "win32", "cpu": "ia32" }, "sha512-yYkWHhmbhRTWTnWos5HC4GcPQfjlzzCNbM9e/+GXrLuaBXYA3qSDR9f0Vgufd5S8yX81U8jPKp7ZnAjZFMtRnw=="],

    "@rollup/rollup-win32-x64-gnu": ["@rollup/rollup-win32-x64-gnu@4.62.0", "", { "os": "win32", "cpu": "x64" }, "sha512-SoTb6lPg25xZlA2ibwQ++ahCCnH+FP0qmEuafMJ4gznZKOlXioKEAeJLgCrqjM98ACziXM9V1amFjICVL4IFoA=="],

    "@rollup/rollup-win32-x64-msvc": ["@rollup/rollup-win32-x64-msvc@4.62.0", "", { "os": "win32", "cpu": "x64" }, "sha512-5L+T1fMX4RIEBoZzT0+sQ0PhTS36NULFmMXtl1TZo44TMAROIMHbZufSOjVWt/Y622BtxgxtaNOokbTDvfsrZA=="],

    "@standard-schema/spec": ["@standard-schema/spec@1.1.0", "", {}, "sha512-l2aFy5jALhniG5HgqrD6jXLi/rUWrKvqN/qJx6yoJsgKhblVd+iqqU4RCXavm/jPityDo5TCvKMnpjKnOriy0w=="],

    "@sveltejs/acorn-typescript": ["@sveltejs/acorn-typescript@1.0.10", "", { "peerDependencies": { "acorn": "^8.9.0" } }, "sha512-4WfKk68eTih+MiJD4fSbxN7E8kVBmTMPWHUPYjvl2N0rMs53YLTT8/YjKU5Dtnz5LqDjl7LEw4U7lXR2W3J5WA=="],

    "@sveltejs/adapter-node": ["@sveltejs/adapter-node@5.5.4", "", { "dependencies": { "@rollup/plugin-commonjs": "^29.0.0", "@rollup/plugin-json": "^6.1.0", "@rollup/plugin-node-resolve": "^16.0.0", "rollup": "^4.59.0" }, "peerDependencies": { "@sveltejs/kit": "^2.4.0" } }, "sha512-45X92CXW+2J8ZUzPv3eLlKWEzINKiiGeFWTjyER4ZN4sGgNoaoeSkCY/QYNxHpPXy71QPsctwccBo9jJs0ySPQ=="],

    "@sveltejs/kit": ["@sveltejs/kit@2.65.2", "", { "dependencies": { "@standard-schema/spec": "^1.0.0", "@sveltejs/acorn-typescript": "^1.0.9", "@types/cookie": "^0.6.0", "acorn": "^8.16.0", "cookie": "^0.6.0", "devalue": "^5.8.1", "esm-env": "^1.2.2", "kleur": "^4.1.5", "magic-string": "^0.30.5", "mrmime": "^2.0.0", "set-cookie-parser": "^3.0.0", "sirv": "^3.0.0" }, "peerDependencies": { "@opentelemetry/api": "^1.0.0", "@sveltejs/vite-plugin-svelte": "^3.0.0 || ^4.0.0-next.1 || ^5.0.0 || ^6.0.0-next.0 || ^7.0.0", "svelte": "^4.0.0 || ^5.0.0-next.0", "typescript": "^5.3.3 || ^6.0.0", "vite": "^5.0.3 || ^6.0.0 || ^7.0.0-beta.0 || ^8.0.0" }, "optionalPeers": ["@opentelemetry/api", "typescript"], "bin": { "svelte-kit": "svelte-kit.js" } }, "sha512-ZIkyEmxT1gcq50Opn1ZIIx6vc/yt2zNN0rF5hS6op95gqHtNw8QMKDhjJI+RyjMcbvECRw+FzEeAoBe/MOz9AA=="],

    "@sveltejs/load-config": ["@sveltejs/load-config@0.1.1", "", {}, "sha512-BXXm+VOH/9X4N7Dd1iZ2MqA1h7M+9i2noI8QYuLDY8QcN2WHYn7D/VK/+IJNfcAmRw7ACNJ538UT9GXIhnBTiA=="],

    "@sveltejs/vite-plugin-svelte": ["@sveltejs/vite-plugin-svelte@7.1.2", "", { "dependencies": { "deepmerge": "^4.3.1", "magic-string": "^0.30.21", "obug": "^2.1.0", "vitefu": "^1.1.2" }, "peerDependencies": { "svelte": "^5.46.4", "vite": "^8.0.0-beta.7 || ^8.0.0" } }, "sha512-DrUBA2UXRfDmUX/ZTiEopd3X40yavsJF1FX2RygcuIScHL7o5YX1fMvoYnDhjeJQC4weCOklirpNWlcb2NiSeA=="],

    "@tailwindcss/node": ["@tailwindcss/node@4.3.1", "", { "dependencies": { "@jridgewell/remapping": "^2.3.5", "enhanced-resolve": "5.21.6", "jiti": "^2.7.0", "lightningcss": "1.32.0", "magic-string": "^0.30.21", "source-map-js": "^1.2.1", "tailwindcss": "4.3.1" } }, "sha512-6NDaqRoAMSXD1mr/RXu0HBvNE9a2n5tHPsxu9XHLws8o4Twes5rBM2205SUUiJ9goAtadrN6xTGX0UDEwp/N4A=="],

    "@tailwindcss/oxide": ["@tailwindcss/oxide@4.3.1", "", { "optionalDependencies": { "@tailwindcss/oxide-android-arm64": "4.3.1", "@tailwindcss/oxide-darwin-arm64": "4.3.1", "@tailwindcss/oxide-darwin-x64": "4.3.1", "@tailwindcss/oxide-freebsd-x64": "4.3.1", "@tailwindcss/oxide-linux-arm-gnueabihf": "4.3.1", "@tailwindcss/oxide-linux-arm64-gnu": "4.3.1", "@tailwindcss/oxide-linux-arm64-musl": "4.3.1", "@tailwindcss/oxide-linux-x64-gnu": "4.3.1", "@tailwindcss/oxide-linux-x64-musl": "4.3.1", "@tailwindcss/oxide-wasm32-wasi": "4.3.1", "@tailwindcss/oxide-win32-arm64-msvc": "4.3.1", "@tailwindcss/oxide-win32-x64-msvc": "4.3.1" } }, "sha512-yVPyo8RNkabVr3O2EhHEE0Rewu7YKzc1DhIqfL46LKveFrmu9XbDazNOJY7/GRuvw1h6u3utWnR29H/p5JPlgA=="],

    "@tailwindcss/oxide-android-arm64": ["@tailwindcss/oxide-android-arm64@4.3.1", "", { "os": "android", "cpu": "arm64" }, "sha512-SVlyf61g374l5cHyg8x9kf5xmLcOaxvOTsbsqDnSsDJaKOEFZ7GCvi84VAVGpxojYOs1+3K6M0UjXfqPU8vmOQ=="],

    "@tailwindcss/oxide-darwin-arm64": ["@tailwindcss/oxide-darwin-arm64@4.3.1", "", { "os": "darwin", "cpu": "arm64" }, "sha512-hVnWLwv+e/l7c4WKyVtHVrIPvYdqWHjRB3MDIqARynzFtnQg85kmQEFCbV9Ja0VVx4xXTIiDWY60Y7iz/iNoDA=="],

    "@tailwindcss/oxide-darwin-x64": ["@tailwindcss/oxide-darwin-x64@4.3.1", "", { "os": "darwin", "cpu": "x64" }, "sha512-Cf7abu0WVgbhU7ANgPUnSAvm7nCvMweusHb8FnaHlLfv/Caq4GYaEZg7ZImzzmjx4lIAfuS8q+eLIS7A7IzxIg=="],

    "@tailwindcss/oxide-freebsd-x64": ["@tailwindcss/oxide-freebsd-x64@4.3.1", "", { "os": "freebsd", "cpu": "x64" }, "sha512-ZZqzX2Y+GXtXXfqSfpJhDm60OoZfvLHLCgm+J7NVqgHHJjG/m9ugZI77RwTsVd4fnBJuCFP6Ae6kTJb71UdS8g=="],

    "@tailwindcss/oxide-linux-arm-gnueabihf": ["@tailwindcss/oxide-linux-arm-gnueabihf@4.3.1", "", { "os": "linux", "cpu": "arm" }, "sha512-/Ah/xik0LaMYfv9DZ0S/t4pBlBNYOcqtRwusjgovHkvT8ixueWCLyJjsaF5kQIckjb4IT8Q6K6p/iPmZMixYgg=="],

    "@tailwindcss/oxide-linux-arm64-gnu": ["@tailwindcss/oxide-linux-arm64-gnu@4.3.1", "", { "os": "linux", "cpu": "arm64" }, "sha512-gqdFoVJlw444GvpnheZLHmvTzSxI/cOUUh2KSNejQjTcYkW062SVD+En0rUgD+QV91bz1XGIGtt1HJd48xUGbQ=="],

    "@tailwindcss/oxide-linux-arm64-musl": ["@tailwindcss/oxide-linux-arm64-musl@4.3.1", "", { "os": "linux", "cpu": "arm64" }, "sha512-Bwv9KwOvE0VKa86xPFif9b9c3Y1NxOV1P0gLti/IYaWEsQYZXDlxfGEtA8mdDZ7SG3wyNXAWYT5SIn3giL57oA=="],

    "@tailwindcss/oxide-linux-x64-gnu": ["@tailwindcss/oxide-linux-x64-gnu@4.3.1", "", { "os": "linux", "cpu": "x64" }, "sha512-Ymi8O8T15HYQdOUWUtTI6ldN0neHP85FC+Qz32xTcZ7iJXtem/x8ITev0o1e9e5rkqj4lONZfTRLvkmin1+tKg=="],

    "@tailwindcss/oxide-linux-x64-musl": ["@tailwindcss/oxide-linux-x64-musl@4.3.1", "", { "os": "linux", "cpu": "x64" }, "sha512-M+P/91qJ6uILLw4k2G93GMDRAXj61SMvFQYt39AqvUqYgExXpLL5aepfns7sj4HiAQeolirQF9E0lzRvdf4zPQ=="],

    "@tailwindcss/oxide-wasm32-wasi": ["@tailwindcss/oxide-wasm32-wasi@4.3.1", "", { "dependencies": { "@emnapi/core": "^1.10.0", "@emnapi/runtime": "^1.10.0", "@emnapi/wasi-threads": "^1.2.1", "@napi-rs/wasm-runtime": "^1.1.4", "@tybys/wasm-util": "^0.10.2", "tslib": "^2.8.1" }, "cpu": "none" }, "sha512-zsM8uOeqvVGHsAXsJxsT28ttosFahLJKCLOTUBqRAtKnVgGSRitds9T432QiT8b77Yga7JIBkulIRRlJPtYhRA=="],

    "@tailwindcss/oxide-win32-arm64-msvc": ["@tailwindcss/oxide-win32-arm64-msvc@4.3.1", "", { "os": "win32", "cpu": "arm64" }, "sha512-aiNvSq9BsVk8V513lDKlrCFAgf8qBMPZTpgEhInL+NwQqs97mYmupVMrPrgBBSL8Pv/0zXu9MrMF9rMun1ZeNg=="],

    "@tailwindcss/oxide-win32-x64-msvc": ["@tailwindcss/oxide-win32-x64-msvc@4.3.1", "", { "os": "win32", "cpu": "x64" }, "sha512-xDEyu1rg290472FEGaKHnzyDyh5QH+AlWvsU5hMoMtPpzmKlRI0jaYKCgSHDYtaQWZOYbMaduSyCwFwY4n1HmA=="],

    "@tailwindcss/vite": ["@tailwindcss/vite@4.3.1", "", { "dependencies": { "@tailwindcss/node": "4.3.1", "@tailwindcss/oxide": "4.3.1", "tailwindcss": "4.3.1" }, "peerDependencies": { "vite": "^5.2.0 || ^6 || ^7 || ^8" } }, "sha512-hItDHuIIlEV61R+faXu66s1K36aTurO/Qw0e45Vskz57gXl9pWOT6eg3zmcEui6CZXddbN7zd41bwmvag4JGwQ=="],

    "@tybys/wasm-util": ["@tybys/wasm-util@0.10.2", "", { "dependencies": { "tslib": "^2.4.0" } }, "sha512-RoBvJ2X0wuKlWFIjrwffGw1IqZHKQqzIchKaadZZfnNpsAYp2mM0h36JtPCjNDAHGgYez/15uMBpfGwchhiMgg=="],

    "@types/archiver": ["@types/archiver@8.0.0", "", { "dependencies": { "@types/node": "*", "@types/readdir-glob": "*" } }, "sha512-YpXPbEuv9+eUIPPQWUPahj3cvs9isWRuF+J4z+KbdYVDO3rWorWQFxUVHnwPu2AgKwvgpki5F2VMX0Xx+mX45A=="],

    "@types/better-sqlite3": ["@types/better-sqlite3@7.6.13", "", { "dependencies": { "@types/node": "*" } }, "sha512-NMv9ASNARoKksWtsq/SHakpYAYnhBrQgGD8zkLYk/jaK8jUGn08CfEdTRgYhMypUQAfzSP8W6gNLe0q19/t4VA=="],

    "@types/chai": ["@types/chai@5.2.3", "", { "dependencies": { "@types/deep-eql": "*", "assertion-error": "^2.0.1" } }, "sha512-Mw558oeA9fFbv65/y4mHtXDs9bPnFMZAL/jxdPFUpOHHIXX91mcgEHbS5Lahr+pwZFR8A7GQleRWeI6cGFC2UA=="],

    "@types/cookie": ["@types/cookie@0.6.0", "", {}, "sha512-4Kh9a6B2bQciAhf7FSuMRRkUWecJgJu9nPnx3yzpsfXX/c50REIqpHY4C82bXP90qrLtXtkDxTZosYO3UpOwlA=="],

    "@types/deep-eql": ["@types/deep-eql@4.0.2", "", {}, "sha512-c9h9dVVMigMPc4bwTvC5dxqtqJZwQPePsWjPlpSOnojbor6pGqdk541lfA7AqFQr5pB1BRdq0juY9db81BwyFw=="],

    "@types/estree": ["@types/estree@1.0.9", "", {}, "sha512-GhdPgy1el4/ImP05X05Uw4cw2/M93BCUmnEvWZNStlCzEKME4Fkk+YpoA5OiHNQmoS7Cafb8Xa3Pya8m1Qrzeg=="],

    "@types/fluent-ffmpeg": ["@types/fluent-ffmpeg@2.1.28", "", { "dependencies": { "@types/node": "*" } }, "sha512-5ovxsDwBcPfJ+eYs1I/ZpcYCnkce7pvH9AHSvrZllAp1ZPpTRDZAFjF3TRFbukxSgIYTTNYePbS0rKUmaxVbXw=="],

    "@types/geojson": ["@types/geojson@7946.0.16", "", {}, "sha512-6C8nqWur3j98U6+lXDfTUWIfgvZU+EumvpHKcYjujKH7woYyLj2sUmff0tRhrqM7BohUw7Pz3ZB1jj2gW9Fvmg=="],

    "@types/leaflet": ["@types/leaflet@1.9.21", "", { "dependencies": { "@types/geojson": "*" } }, "sha512-TbAd9DaPGSnzp6QvtYngntMZgcRk+igFELwR2N99XZn7RXUdKgsXMR+28bUO0rPsWp8MIu/f47luLIQuSLYv/w=="],

    "@types/leaflet.markercluster": ["@types/leaflet.markercluster@1.5.6", "", { "dependencies": { "@types/leaflet": "^1.9" } }, "sha512-I7hZjO2+isVXGYWzKxBp8PsCzAYCJBc29qBdFpquOCkS7zFDqUsUvkEOyQHedsk/Cy5tocQzf+Ndorm5W9YKTQ=="],

    "@types/node": ["@types/node@25.9.3", "", { "dependencies": { "undici-types": ">=7.24.0 <7.24.7" } }, "sha512-603BddQMv3pUcr4U2dhujk83N2tTDVr/34wII2B6bJy6g+8WD6yUb11jszNs0gdi4PesVWl7ABt8nYMVpnLUcg=="],

    "@types/readdir-glob": ["@types/readdir-glob@1.1.5", "", { "dependencies": { "@types/node": "*" } }, "sha512-raiuEPUYqXu+nvtY2Pe8s8FEmZ3x5yAH4VkLdihcPdalvsHltomrRC9BzuStrJ9yk06470hS0Crw0f1pXqD+Hg=="],

    "@types/resolve": ["@types/resolve@1.20.2", "", {}, "sha512-60BCwRFOZCQhDncwQdxxeOEEkbc5dIMccYLwbxsS4TUNeVECQ/pBJ0j09mrHOl/JJvpRPGwO9SvE4nR2Nb/a4Q=="],

    "@types/trusted-types": ["@types/trusted-types@2.0.7", "", {}, "sha512-ScaPdn1dQczgbl0QFTeTOmVHFULt394XJgOQNoyVhZ6r2vLnMLJfBPd53SB52T/3G36VI1/g2MZaX0cwDuXsfw=="],

    "@vitest/coverage-v8": ["@vitest/coverage-v8@4.1.9", "", { "dependencies": { "@bcoe/v8-coverage": "^1.0.2", "@vitest/utils": "4.1.9", "ast-v8-to-istanbul": "^1.0.0", "istanbul-lib-coverage": "^3.2.2", "istanbul-lib-report": "^3.0.1", "istanbul-reports": "^3.2.0", "magicast": "^0.5.2", "obug": "^2.1.1", "std-env": "^4.0.0-rc.1", "tinyrainbow": "^3.1.0" }, "peerDependencies": { "@vitest/browser": "4.1.9", "vitest": "4.1.9" }, "optionalPeers": ["@vitest/browser"] }, "sha512-G9/lgqibheLVBDRuya45EbsEXTYcWoSG+TLg7i2axuzx0Eq62eXn+aWXyaVdV5vKvFSWd6ywcX8hA7la9Pvu8g=="],

    "@vitest/expect": ["@vitest/expect@4.1.9", "", { "dependencies": { "@standard-schema/spec": "^1.1.0", "@types/chai": "^5.2.2", "@vitest/spy": "4.1.9", "@vitest/utils": "4.1.9", "chai": "^6.2.2", "tinyrainbow": "^3.1.0" } }, "sha512-vl/rYsUKcBr3SnQn166+XR5ZQcgMx3DQhFWdfli/cWpLnLUmbxZvyrJZotLFUryib+LtArYMSTJ5RbQ57ZqrlA=="],

    "@vitest/mocker": ["@vitest/mocker@4.1.9", "", { "dependencies": { "@vitest/spy": "4.1.9", "estree-walker": "^3.0.3", "magic-string": "^0.30.21" }, "peerDependencies": { "msw": "^2.4.9", "vite": "^6.0.0 || ^7.0.0 || ^8.0.0" }, "optionalPeers": ["msw", "vite"] }, "sha512-EVkXzBjrPGM+cK8/ANWgBrkUCfJfb38/EfTSO8h7pWvKkyPkpWxvR7BkD2MyItMF62C97zAEoqdpUixwR/e+Rw=="],

    "@vitest/pretty-format": ["@vitest/pretty-format@4.1.9", "", { "dependencies": { "tinyrainbow": "^3.1.0" } }, "sha512-s0iufns3iIFitdgm+YR7g1whCAaGtXz459VS9/PqyKDEEFgYIhsHOQmXgIgDuYCt7DeQmiZT0Qe2OA2p4ZPu5A=="],

    "@vitest/runner": ["@vitest/runner@4.1.9", "", { "dependencies": { "@vitest/utils": "4.1.9", "pathe": "^2.0.3" } }, "sha512-KXLMDtc7oe70+3mJfGrPUWPesswH+3sTxAMAMl8DG7I8IUQT4XW718dY5ID3vPUcmlu27CcKfY4P3h3I29SLJg=="],

    "@vitest/snapshot": ["@vitest/snapshot@4.1.9", "", { "dependencies": { "@vitest/pretty-format": "4.1.9", "@vitest/utils": "4.1.9", "magic-string": "^0.30.21", "pathe": "^2.0.3" } }, "sha512-Jc7RKGNBo8Z28WYIm0Niej4xdSPByRf6mU58VpHQkd6Zh05rlnA+twjbK5HyeIGHxrzsc3mJgS43uM0CZKzaIA=="],

    "@vitest/spy": ["@vitest/spy@4.1.9", "", {}, "sha512-fHpsS6mIi+PiEW+vcRVOMkX1oSaPKne3VOclSFICPcGOmfKgXPU5iAah+wcNcj2xPrCCmfq99IDGf+EojhhvhA=="],

    "@vitest/utils": ["@vitest/utils@4.1.9", "", { "dependencies": { "@vitest/pretty-format": "4.1.9", "convert-source-map": "^2.0.0", "tinyrainbow": "^3.1.0" } }, "sha512-A51o8ymO5PpqlWNnBP9ZHPXDIpuMtTLlGSjN7la4US+LJzoUMyhwjA5QXlm39JexgwHKW4Xjs8Z2d3dLCXOeuA=="],

    "abort-controller": ["abort-controller@3.0.0", "", { "dependencies": { "event-target-shim": "^5.0.0" } }, "sha512-h8lQ8tacZYnR3vNQTgibj+tODHI5/+l06Au2Pcriv/Gmet0eaj4TwWH41sO9wnHDiQsEj19q0drzdWdeAHtweg=="],

    "acorn": ["acorn@8.17.0", "", { "bin": { "acorn": "bin/acorn" } }, "sha512-xRQbDb9BnwDafYNn6Vwl839DYVjqXYb1XVGtWAZ1kcDc6iwAL4hg3B1dZlRiuENFeO2H53gFG3in621AdERVAg=="],

    "agent-base": ["agent-base@6.0.2", "", { "dependencies": { "debug": "4" } }, "sha512-RZNwNclF7+MS/8bDg70amg32dyeZGZxiDuQmZxKLAlQjr3jGyLx+4Kkk58UO7D2QdgFIQCovuSuZESne6RG6XQ=="],

    "archiver": ["archiver@8.0.0", "", { "dependencies": { "async": "^3.2.4", "buffer-crc32": "^1.0.0", "is-stream": "^4.0.0", "lazystream": "^1.0.0", "normalize-path": "^3.0.0", "readable-stream": "^4.0.0", "readdir-glob": "^3.0.0", "tar-stream": "^3.0.0", "zip-stream": "^7.0.2" } }, "sha512-fV1orZfsnPn9BaSByR/qE67rJCLJEy2Ox5bq7nJh+jquWaNh6Sfec75kJ2T6PtdGUbPQlrVoSVCEOa5SdiTQ1g=="],

    "aria-query": ["aria-query@5.3.1", "", {}, "sha512-Z/ZeOgVl7bcSYZ/u/rh0fOpvEpq//LZmdbkXyc7syVzjPAhfOa9ebsdTSjEBDU4vs5nC98Kfduj1uFo0qyET3g=="],

    "assertion-error": ["assertion-error@2.0.1", "", {}, "sha512-Izi8RQcffqCeNVgFigKli1ssklIbpHnCYc6AknXGYoB6grJqyeby7jv12JUQgmTAnIDnbck1uxksT4dzN3PWBA=="],

    "ast-v8-to-istanbul": ["ast-v8-to-istanbul@1.0.4", "", { "dependencies": { "@jridgewell/trace-mapping": "^0.3.31", "estree-walker": "^3.0.3", "js-tokens": "^10.0.0" } }, "sha512-0bC0/4bTSrnwdhU3IsZDwEdojvuPrSg59OYZfKsLRtJZ0u8VBx9DebfqqG8bRdCC0I7vjgxmPi41P0lpkhJHtA=="],

    "async": ["async@3.2.6", "", {}, "sha512-htCUDlxyyCLMgaM3xXg0C0LW2xqfuQ6p05pCEIsXuyQ+a1koYKTuBMzRNwmybfLgvJDMd0r1LTn4+E0Ti6C2AA=="],

    "axobject-query": ["axobject-query@4.1.0", "", {}, "sha512-qIj0G9wZbMGNLjLmg1PT6v2mE9AH2zlnADJD/2tC6E00hgmhUOfEB6greHPAfLRSufHqROIUTkw6E+M3lH0PTQ=="],

    "b4a": ["b4a@1.8.1", "", { "peerDependencies": { "react-native-b4a": "*" }, "optionalPeers": ["react-native-b4a"] }, "sha512-aiqre1Nr0B/6DgE2N5vwTc+2/oQZ4Wh1t4NznYY4E00y8LCt6NqdRv81so00oo27D8MVKTpUa/MwUUtBLXCoDw=="],

    "balanced-match": ["balanced-match@4.0.4", "", {}, "sha512-BLrgEcRTwX2o6gGxGOCNyMvGSp35YofuYzw9h1IMTRmKqttAZZVU67bdb9Pr2vUHA8+j3i2tJfjO6C6+4myGTA=="],

    "bare-events": ["bare-events@2.9.1", "", { "peerDependencies": { "bare-abort-controller": "*" }, "optionalPeers": ["bare-abort-controller"] }, "sha512-Z0oHEHAFDZkffN8Qc39zNZjQlMDkPJRyyyZieU1VH7u8c5S+qHZ2S8ixdKIAxEjfHO7FJxXmJWgteOghVanIsg=="],

    "bare-fs": ["bare-fs@4.7.2", "", { "dependencies": { "bare-events": "^2.5.4", "bare-path": "^3.0.0", "bare-stream": "^2.6.4", "bare-url": "^2.2.2", "fast-fifo": "^1.3.2" }, "peerDependencies": { "bare-buffer": "*" }, "optionalPeers": ["bare-buffer"] }, "sha512-aTvMFUWkBmjzKtEQMDGGDNF8bkfpD5N1b/FCwt7A3wrU4t1o/e/85Wzkluh6JlODCjqVESYCkQCdTXqZ9G7VFg=="],

    "bare-os": ["bare-os@3.9.1", "", {}, "sha512-6M5XjcnsygQNPMCMPXSK379xrJFiZ/AEMNBmFEmQW8d/789VQATvriyi5r0HYTL9TkQ26rn3kgdTG3aisbrXkQ=="],

    "bare-path": ["bare-path@3.0.1", "", { "dependencies": { "bare-os": "^3.0.1" } }, "sha512-ghj2DSK/2e99a1anTVPCV4m4YIYtrbXhfM7V3D7XZLOTsybnYyaJloymGqssQc8l/or0UoDyRtNQkmkEF/ysgQ=="],

    "bare-stream": ["bare-stream@2.13.3", "", { "dependencies": { "b4a": "^1.8.1", "streamx": "^2.25.0", "teex": "^1.0.1" }, "peerDependencies": { "bare-abort-controller": "*", "bare-buffer": "*", "bare-events": "*" }, "optionalPeers": ["bare-abort-controller", "bare-buffer", "bare-events"] }, "sha512-Kc+brLqvEqGkjyfiwJmImAOqLZL7OsoLKuavx+hJjgVV3nLTOjloJyPMFxjUPerGGHrNH0fLU06jjykMLWrERQ=="],

    "bare-url": ["bare-url@2.4.5", "", { "dependencies": { "bare-path": "^3.0.0" } }, "sha512-K+y9xF1tN+CdPu4qWwr0QiK1Al07eFPGYK5M2pDXcmHdMdgC/tT/bpmMe1hrmRHaidKLkXrC+cRNYf3XVDUhSQ=="],

    "base64-js": ["base64-js@1.5.1", "", {}, "sha512-AKpaYlHn8t4SVbOHCy+b5+KKgvR4vrsD8vbvrbiQJps7fKDTkjkDry6ji0rUJjC0kzbNePLwzxq8iypo41qeWA=="],

    "better-sqlite3": ["better-sqlite3@12.11.1", "", { "dependencies": { "bindings": "^1.5.0", "prebuild-install": "^7.1.1" } }, "sha512-dq9AtApgg5PGFtBzPFSBl3HZQjHok5gaQCM6zh2Yk0aSmDCs1CbnVI8/HgASQkNKsWFpseIO9beg5xxpYhbIfA=="],

    "bindings": ["bindings@1.5.0", "", { "dependencies": { "file-uri-to-path": "1.0.0" } }, "sha512-p2q/t/mhvuOj/UeLlV6566GD/guowlr0hHxClI0W9m7MWYkL1F0hLo+0Aexs9HSPCtR1SXQ0TD3MMKrXZajbiQ=="],

    "bl": ["bl@4.1.0", "", { "dependencies": { "buffer": "^5.5.0", "inherits": "^2.0.4", "readable-stream": "^3.4.0" } }, "sha512-1W07cM9gS6DcLperZfFSj+bWLtaPGSOHWhPiGzXmvVJbRLdG82sH/Kn8EtW1VqWVA54AKf2h5k5BbnIbwF3h6w=="],

    "blurhash": ["blurhash@2.0.5", "", {}, "sha512-cRygWd7kGBQO3VEhPiTgq4Wc43ctsM+o46urrmPOiuAe+07fzlSB9OJVdpgDL0jPqXUVQ9ht7aq7kxOeJHRK+w=="],

    "brace-expansion": ["brace-expansion@5.0.6", "", { "dependencies": { "balanced-match": "^4.0.2" } }, "sha512-kLpxurY4Z4r9sgMsyG0Z9uzsBlgiU/EFKhj/h91/8yHu0edo7XuixOIH3VcJ8kkxs6/jPzoI6U9Vj3WqbMQ94g=="],

    "buffer": ["buffer@6.0.3", "", { "dependencies": { "base64-js": "^1.3.1", "ieee754": "^1.2.1" } }, "sha512-FTiCpNxtwiZZHEZbcbTIcZjERVICn9yq/pDFkTl95/AxzD1naBctN7YO68riM/gLSDY7sdrMby8hofADYuuqOA=="],

    "buffer-crc32": ["buffer-crc32@1.0.0", "", {}, "sha512-Db1SbgBS/fg/392AblrMJk97KggmvYhr4pB5ZIMTWtaivCPMWLkmb7m21cJvpvgK+J3nsU2CmmixNBZx4vFj/w=="],

    "buffer-from": ["buffer-from@1.1.2", "", {}, "sha512-E+XQCRwSbaaiChtv6k6Dwgc+bx+Bs6vuKJHHl5kox/BaKbhiXzqQOwK4cO22yElGp2OCmjwVhT3HmxgyPGnJfQ=="],

    "caseless": ["caseless@0.12.0", "", {}, "sha512-4tYFyifaFfGacoiObjJegolkwSU4xQNGbVgUiNYVUxbQ2x2lUsFvY4hVgVzGiIe6WLOPqycWXA40l+PWsxthUw=="],

    "chai": ["chai@6.2.2", "", {}, "sha512-NUPRluOfOiTKBKvWPtSD4PhFvWCqOi0BGStNWs57X9js7XGTprSmFoz5F0tWhR4WPjNeR9jXqdC7/UpSJTnlRg=="],

    "chokidar": ["chokidar@5.0.0", "", { "dependencies": { "readdirp": "^5.0.0" } }, "sha512-TQMmc3w+5AxjpL8iIiwebF73dRDF4fBIieAqGn9RGCWaEVwQ6Fb2cGe31Yns0RRIzii5goJ1Y7xbMwo1TxMplw=="],

    "chownr": ["chownr@1.1.4", "", {}, "sha512-jJ0bqzaylmJtVnNgzTeSOs8DPavpbYgEr/b0YL8/2GO3xJEhInFmhKMUnEJQjZumK7KXGFhUy89PrsJWlakBVg=="],

    "clsx": ["clsx@2.1.1", "", {}, "sha512-eYm0QWBtUrBWZWG0d386OGAw16Z995PiOVo2B7bjWSbHedGl5e0ZWaq65kOGgUSNesEIDkB9ISbTg/JK9dhCZA=="],

    "commondir": ["commondir@1.0.1", "", {}, "sha512-W9pAhw0ja1Edb5GVdIF1mjZw/ASI0AlShXM83UUGe2DVr5TdAPEA1OA8m/g8zWp9x6On7gqufY+FatDbC3MDQg=="],

    "compress-commons": ["compress-commons@7.0.1", "", { "dependencies": { "crc-32": "^1.2.0", "crc32-stream": "^7.0.1", "is-stream": "^4.0.0", "normalize-path": "^3.0.0", "readable-stream": "^4.0.0" } }, "sha512-g0S8KAD8qf4+V//pr3BfB1aBnARLXNz2Gx+jmHU0LEriUuoQUOPOulVquHKTJ8+EAIIO7fhseNDr9wK5Q9FKBQ=="],

    "concat-stream": ["concat-stream@2.0.0", "", { "dependencies": { "buffer-from": "^1.0.0", "inherits": "^2.0.3", "readable-stream": "^3.0.2", "typedarray": "^0.0.6" } }, "sha512-MWufYdFw53ccGjCA+Ol7XJYpAlW6/prSMzuPOTRnJGcGzuhLn4Scrz7qf6o8bROZ514ltazcIFJZevcfbo0x7A=="],

    "convert-source-map": ["convert-source-map@2.0.0", "", {}, "sha512-Kvp459HrV2FEJ1CAsi1Ku+MY3kasH19TFykTz2xWmMeq6bk2NU3XXvfJ+Q61m0xktWwt+1HSYf3JZsTms3aRJg=="],

    "cookie": ["cookie@0.7.2", "", {}, "sha512-yki5XnKuf750l50uGTllt6kKILY4nQ1eNIQatoXEByZ5dWgnKqbnqmTrBE5B4N7lrMJKQ2ytWMiTO2o0v6Ew/w=="],

    "core-util-is": ["core-util-is@1.0.3", "", {}, "sha512-ZQBvi1DcpJ4GDqanjucZ2Hj3wEO5pZDS89BWbkcrvdxksJorwUDDZamX9ldFkp9aw2lmBDLgkObEA4DWNJ9FYQ=="],

    "crc-32": ["crc-32@1.2.2", "", { "bin": { "crc32": "bin/crc32.njs" } }, "sha512-ROmzCKrTnOwybPcJApAA6WBWij23HVfGVNKqqrZpuyZOHqK2CwHSvpGuyt/UNNvaIjEd8X5IFGp4Mh+Ie1IHJQ=="],

    "crc32-stream": ["crc32-stream@7.0.1", "", { "dependencies": { "crc-32": "^1.2.0", "readable-stream": "^4.0.0" } }, "sha512-IBWsY8xznyQrcHn8h4bC8/4ErNke5elzgG8GcqF4RFPw6aHkWWRc7Tgw6upjaTX/CT/yQgqYENkxYsTYN+hW2g=="],

    "debug": ["debug@4.4.3", "", { "dependencies": { "ms": "^2.1.3" }, "peerDependencies": { "supports-color": "*" }, "optionalPeers": ["supports-color"] }, "sha512-RGwwWnwQvkVfavKVt22FGLw+xYSdzARwm0ru6DhTVA3umU5hZc28V3kO4stgYryrTlLpuvgI9GiijltAjNbcqA=="],

    "decompress-response": ["decompress-response@6.0.0", "", { "dependencies": { "mimic-response": "^3.1.0" } }, "sha512-aW35yZM6Bb/4oJlZncMH2LCoZtJXTRxES17vE3hoRiowU2kWHaJKFkSBDnDR+cm9J+9QhXmREyIfv0pji9ejCQ=="],

    "deep-extend": ["deep-extend@0.6.0", "", {}, "sha512-LOHxIOaPYdHlJRtCQfDIVZtfw/ufM8+rVj649RIHzcm/vGwQRXFt6OPqIFWsm2XEMrNIEtWR64sY1LEKD2vAOA=="],

    "deepmerge": ["deepmerge@4.3.1", "", {}, "sha512-3sUqbMEc77XqpdNO7FRyRog+eW3ph+GYCbj+rK+uYyRMuwsVy0rMiVtPn+QJlKFvWP/1PYpapqYn0Me2knFn+A=="],

    "detect-libc": ["detect-libc@2.1.2", "", {}, "sha512-Btj2BOOO83o3WyH59e8MgXsxEQVcarkUOpEYrubB0urwnN10yQ364rsiByU11nZlqWYZm05i/of7io4mzihBtQ=="],

    "devalue": ["devalue@5.8.1", "", {}, "sha512-4CXDYRBGqN+57wVJkuXBYmpAVUSg3L6JAQa/DFqm238G73E1wuyc/JhGQJzN7vUf/CMphYau2zXbfWzDR5aTEw=="],

    "end-of-stream": ["end-of-stream@1.4.5", "", { "dependencies": { "once": "^1.4.0" } }, "sha512-ooEGc6HP26xXq/N+GCGOT0JKCLDGrq2bQUZrQ7gyrJiZANJ/8YDTxTpQBXGMn+WbIQXNVpyWymm7KYVICQnyOg=="],

    "enhanced-resolve": ["enhanced-resolve@5.21.6", "", { "dependencies": { "graceful-fs": "^4.2.4", "tapable": "^2.3.3" } }, "sha512-aNnGCvbJ/RIyWo1IuhNdVjnNF+EjH9wpzpNHt+ci/m9He9LJvUN8wrCcXjp9cWsGNAuvSpVFTx/vraAFQ8qGjQ=="],

    "env-paths": ["env-paths@2.2.1", "", {}, "sha512-+h1lkLKhZMTYjog1VEpJNG7NZJWcuc2DDk/qsqSTRRCOXiLjeQ1d1/udrUGhqMxUgAlwKNZ0cf2uqan5GLuS2A=="],

    "es-errors": ["es-errors@1.3.0", "", {}, "sha512-Zf5H2Kxt2xjTvbJvP2ZWLEICxA6j+hAmMzIlypy4xcBg1vKVnx89Wy0GbS+kf5cwCVFFzdCFh2XSCFNULS6csw=="],

    "es-module-lexer": ["es-module-lexer@2.1.0", "", {}, "sha512-n27zTYMjYu1aj4MjCWzSP7G9r75utsaoc8m61weK+W8JMBGGQybd43GstCXZ3WNmSFtGT9wi59qQTW6mhTR5LQ=="],

    "esm-env": ["esm-env@1.2.2", "", {}, "sha512-Epxrv+Nr/CaL4ZcFGPJIYLWFom+YeV1DqMLHJoEd9SYRxNbaFruBwfEX/kkHUJf55j2+TUbmDcmuilbP1TmXHA=="],

    "esrap": ["esrap@2.2.11", "", { "dependencies": { "@jridgewell/sourcemap-codec": "^1.4.15" }, "peerDependencies": { "@typescript-eslint/types": "^8.2.0" }, "optionalPeers": ["@typescript-eslint/types"] }, "sha512-gPdx+I+BjYEinNMQaBXFjbaJVyoPMU4ZODg5mE+M4DqVG9VusAVHHjcBX+zqyITlI0DIARwDMMzZwAWj36dRoQ=="],

    "estree-walker": ["estree-walker@2.0.2", "", {}, "sha512-Rfkk/Mp/DL7JVje3u18FxFujQlTNR2q6QfMSMB7AvCBx91NGj/ba3kCfza0f6dVDbw7YlRf/nDrn7pQrCCyQ/w=="],

    "event-target-shim": ["event-target-shim@5.0.1", "", {}, "sha512-i/2XbnSz/uxRCU6+NdVJgKWDTM427+MqYbkQzD321DuCQJUqOuJKIA0IM2+W2xtYHdKOmZ4dR6fExsd4SXL+WQ=="],

    "events": ["events@3.3.0", "", {}, "sha512-mQw+2fkQbALzQ7V0MY0IqdnXNOeTtP4r0lN9z7AAawCXgqea7bDii20AYrIBrFd/Hx0M2Ocz6S111CaFkUcb0Q=="],

    "events-universal": ["events-universal@1.0.1", "", { "dependencies": { "bare-events": "^2.7.0" } }, "sha512-LUd5euvbMLpwOF8m6ivPCbhQeSiYVNb8Vs0fQ8QjXo0JTkEHpz8pxdQf0gStltaPpw0Cca8b39KxvK9cfKRiAw=="],

    "exifr": ["exifr@7.1.3", "", {}, "sha512-g/aje2noHivrRSLbAUtBPWFbxKdKhgj/xr1vATDdUXPOFYJlQ62Ft0oy+72V6XLIpDJfHs6gXLbBLAolqOXYRw=="],

    "expand-template": ["expand-template@2.0.3", "", {}, "sha512-XYfuKMvj4O35f/pOXLObndIRvyQ+/+6AhODh+OKWj9S9498pHHn/IMszH+gt0fBCRWMNfk1ZSp5x3AifmnI2vg=="],

    "expect-type": ["expect-type@1.3.0", "", {}, "sha512-knvyeauYhqjOYvQ66MznSMs83wmHrCycNEN6Ao+2AeYEfxUIkuiVxdEa1qlGEPK+We3n0THiDciYSsCcgW/DoA=="],

    "fast-fifo": ["fast-fifo@1.3.2", "", {}, "sha512-/d9sfos4yxzpwkDkuN7k2SqFKtYNmCTzgfEpz82x34IM9/zc8KGxQoXg1liNC/izpRM/MBdt44Nmx41ZWqk+FQ=="],

    "fdir": ["fdir@6.5.0", "", { "peerDependencies": { "picomatch": "^3 || ^4" }, "optionalPeers": ["picomatch"] }, "sha512-tIbYtZbucOs0BRGqPJkshJUYdL+SDH7dVM8gjy+ERp3WAUjLEFJE+02kanyHtwjWOnwrKYBiwAmM0p4kLJAnXg=="],

    "ffmpeg-static": ["ffmpeg-static@5.3.0", "", { "dependencies": { "@derhuerst/http-basic": "^8.2.0", "env-paths": "^2.2.0", "https-proxy-agent": "^5.0.0", "progress": "^2.0.3" } }, "sha512-H+K6sW6TiIX6VGend0KQwthe+kaceeH/luE8dIZyOP35ik7ahYojDuqlTV1bOrtEwl01sy2HFNGQfi5IDJvotg=="],

    "ffprobe-static": ["ffprobe-static@3.1.0", "", {}, "sha512-Dvpa9uhVMOYivhHKWLGDoa512J751qN1WZAIO+Xw4L/mrUSPxS4DApzSUDbCFE/LUq2+xYnznEahTd63AqBSpA=="],

    "file-uri-to-path": ["file-uri-to-path@1.0.0", "", {}, "sha512-0Zt+s3L7Vf1biwWZ29aARiVYLx7iMGnEUl9x33fbB/j3jR81u/O2LbqK+Bm1CDSNDKVtJ/YjwY7TUd5SkeLQLw=="],

    "fluent-ffmpeg": ["fluent-ffmpeg@2.1.3", "", { "dependencies": { "async": "^0.2.9", "which": "^1.1.1" } }, "sha512-Be3narBNt2s6bsaqP6Jzq91heDgOEaDCJAXcE3qcma/EJBSy5FB4cvO31XBInuAuKBx8Kptf8dkhjK0IOru39Q=="],

    "fs-constants": ["fs-constants@1.0.0", "", {}, "sha512-y6OAwoSIf7FyjMIv94u+b5rdheZEjzR63GTyZJm5qh4Bi+2YgwLCcI/fPFZkL5PSixOt6ZNKm+w+Hfp/Bciwow=="],

    "fsevents": ["fsevents@2.3.3", "", { "os": "darwin" }, "sha512-5xoDfX+fL7faATnagmWPpbFtwh/R77WmMMqqHGS65C3vvB0YHrgF+B1YmZ3441tMj5n63k0212XNoJwzlhffQw=="],

    "function-bind": ["function-bind@1.1.2", "", {}, "sha512-7XHNxH7qX9xG5mIwxkhumTox/MIRNcOgDrxWsMt2pAr23WHp6MrRlN7FBSFpCpr+oVO0F744iUgR82nJMfG2SA=="],

    "github-from-package": ["github-from-package@0.0.0", "", {}, "sha512-SyHy3T1v2NUXn29OsWdxmK6RwHD+vkj3v8en8AOBZ1wBQ/hCAQ5bAQTD02kW4W9tUp/3Qh6J8r9EvntiyCmOOw=="],

    "graceful-fs": ["graceful-fs@4.2.11", "", {}, "sha512-RbJ5/jmFcNNCcDV5o9eTnBLJ/HszWV0P73bc+Ff4nS/rJj+YaS6IGyiOL0VoBYX+l1Wrl3k63h/KrH+nhJ0XvQ=="],

    "has-flag": ["has-flag@4.0.0", "", {}, "sha512-EykJT/Q1KjTWctppgIAgfSO0tKVuZUjhgMr17kqTumMl6Afv3EISleU7qZUzoXDFTAHTDC4NOoG/ZxU3EvlMPQ=="],

    "hasown": ["hasown@2.0.4", "", { "dependencies": { "function-bind": "^1.1.2" } }, "sha512-T2UbfbBEF32wiepXIsMlTW9+dDYC6wMh/t/vYA4tuOMKqWz/n3vr1NFSxQiyP+zk2mXsoMA/i/7qV6LKut1t1A=="],

    "html-escaper": ["html-escaper@2.0.2", "", {}, "sha512-H2iMtd0I4Mt5eYiapRdIDjp+XzelXQ0tFE4JS7YFwFevXXMmOp9myNrUvCg0D6ws8iqkRPBfKHgbwig1SmlLfg=="],

    "http-response-object": ["http-response-object@3.0.2", "", { "dependencies": { "@types/node": "^10.0.3" } }, "sha512-bqX0XTF6fnXSQcEJ2Iuyr75yVakyjIDCqroJQ/aHfSdlM743Cwqoi2nDYMzLGWUcuTWGWy8AAvOKXTfiv6q9RA=="],

    "https-proxy-agent": ["https-proxy-agent@5.0.1", "", { "dependencies": { "agent-base": "6", "debug": "4" } }, "sha512-dFcAjpTQFgoLMzC2VwU+C/CbS7uRL0lWmxDITmqm7C+7F0Odmj6s9l6alZc6AELXhrnggM2CeWSXHGOdX2YtwA=="],

    "ieee754": ["ieee754@1.2.1", "", {}, "sha512-dcyqhDvX1C46lXZcVqCpK+FtMRQVdIMN6/Df5js2zouUsqG7I6sFxitIC+7KYK29KdXOLHdu9zL4sFnoVQnqaA=="],

    "inherits": ["inherits@2.0.4", "", {}, "sha512-k/vGaX4/Yla3WzyMCvTQOXYeIHvqOKtnqBduzTHpzpQZzAskKMhZ2K+EnBiSM9zGSoIFeMpXKxa4dYeZIQqewQ=="],

    "ini": ["ini@1.3.8", "", {}, "sha512-JV/yugV2uzW5iMRSiZAyDtQd+nxtUnjeLt0acNdw98kKLrvuRVyB80tsREOE7yvGVgalhZ6RNXCmEHkUKBKxew=="],

    "is-core-module": ["is-core-module@2.16.2", "", { "dependencies": { "hasown": "^2.0.3" } }, "sha512-evOr8xfXKxE6qSR0hSXL2r3sd7ALj8+7jQEUvPYcm5sgZFdJ+AYzT6yNmJenvIYQBgIGwfwz08sL8zoL7yq2BA=="],

    "is-module": ["is-module@1.0.0", "", {}, "sha512-51ypPSPCoTEIN9dy5Oy+h4pShgJmPCygKfyRCISBI+JoWT/2oJvK8QPxmwv7b/p239jXrm9M1mlQbyKJ5A152g=="],

    "is-reference": ["is-reference@3.0.3", "", { "dependencies": { "@types/estree": "^1.0.6" } }, "sha512-ixkJoqQvAP88E6wLydLGGqCJsrFUnqoH6HnaczB8XmDH1oaWU+xxdptvikTgaEhtZ53Ky6YXiBuUI2WXLMCwjw=="],

    "is-stream": ["is-stream@4.0.1", "", {}, "sha512-Dnz92NInDqYckGEUJv689RbRiTSEHCQ7wOVeALbkOz999YpqT46yMRIGtSNl2iCL1waAZSx40+h59NV/EwzV/A=="],

    "isarray": ["isarray@1.0.0", "", {}, "sha512-VLghIWNM6ELQzo7zwmcg0NmTVyWKYjvIeM83yjp0wRDTmUnrM678fQbcKBo6n2CJEF0szoG//ytg+TKla89ALQ=="],

    "isexe": ["isexe@2.0.0", "", {}, "sha512-RHxMLp9lnKHGHRng9QFhRCMbYAcVpn69smSGcq3f36xjgVVWThj4qqLbTLlq7Ssj8B+fIQ1EuCEGI2lKsyQeIw=="],

    "istanbul-lib-coverage": ["istanbul-lib-coverage@3.2.2", "", {}, "sha512-O8dpsF+r0WV/8MNRKfnmrtCWhuKjxrq2w+jpzBL5UZKTi2LeVWnWOmWRxFlesJONmc+wLAGvKQZEOanko0LFTg=="],

    "istanbul-lib-report": ["istanbul-lib-report@3.0.1", "", { "dependencies": { "istanbul-lib-coverage": "^3.0.0", "make-dir": "^4.0.0", "supports-color": "^7.1.0" } }, "sha512-GCfE1mtsHGOELCU8e/Z7YWzpmybrx/+dSTfLrvY8qRmaY6zXTKWn6WQIjaAFw069icm6GVMNkgu0NzI4iPZUNw=="],

    "istanbul-reports": ["istanbul-reports@3.2.0", "", { "dependencies": { "html-escaper": "^2.0.0", "istanbul-lib-report": "^3.0.0" } }, "sha512-HGYWWS/ehqTV3xN10i23tkPkpH46MLCIMFNCaaKNavAXTF1RkqxawEPtnjnGZ6XKSInBKkiOA5BKS+aZiY3AvA=="],

    "jiti": ["jiti@2.7.0", "", { "bin": { "jiti": "lib/jiti-cli.mjs" } }, "sha512-AC/7JofJvZGrrneWNaEnJeOLUx+JlGt7tNa0wZiRPT4MY1wmfKjt2+6O2p2uz2+skll8OZZmJMNqeke7kKbNgQ=="],

    "js-tokens": ["js-tokens@10.0.0", "", {}, "sha512-lM/UBzQmfJRo9ABXbPWemivdCW8V2G8FHaHdypQaIy523snUjog0W71ayWXTjiR+ixeMyVHN2XcpnTd/liPg/Q=="],

    "kleur": ["kleur@4.1.5", "", {}, "sha512-o+NO+8WrRiQEE4/7nwRJhN1HWpVmJm511pBHUxPLtp0BUISzlBplORYSmTclCnJvQq2tKu/sgl3xVpkc7ZWuQQ=="],

    "lazystream": ["lazystream@1.0.1", "", { "dependencies": { "readable-stream": "^2.0.5" } }, "sha512-b94GiNHQNy6JNTrt5w6zNyffMrNkXZb3KTkCZJb2V1xaEGCk093vkZ2jk3tpaeP33/OiXC+WvK9AxUebnf5nbw=="],

    "leaflet": ["leaflet@1.9.4", "", {}, "sha512-nxS1ynzJOmOlHp+iL3FyWqK89GtNL8U8rvlMOsQdTTssxZwCXh8N2NB3GDQOL+YR3XnWyZAxwQixURb+FA74PA=="],

    "leaflet.markercluster": ["leaflet.markercluster@1.5.3", "", { "peerDependencies": { "leaflet": "^1.3.1" } }, "sha512-vPTw/Bndq7eQHjLBVlWpnGeLa3t+3zGiuM7fJwCkiMFq+nmRuG3RI3f7f4N4TDX7T4NpbAXpR2+NTRSEGfCSeA=="],

    "lightningcss": ["lightningcss@1.32.0", "", { "dependencies": { "detect-libc": "^2.0.3" }, "optionalDependencies": { "lightningcss-android-arm64": "1.32.0", "lightningcss-darwin-arm64": "1.32.0", "lightningcss-darwin-x64": "1.32.0", "lightningcss-freebsd-x64": "1.32.0", "lightningcss-linux-arm-gnueabihf": "1.32.0", "lightningcss-linux-arm64-gnu": "1.32.0", "lightningcss-linux-arm64-musl": "1.32.0", "lightningcss-linux-x64-gnu": "1.32.0", "lightningcss-linux-x64-musl": "1.32.0", "lightningcss-win32-arm64-msvc": "1.32.0", "lightningcss-win32-x64-msvc": "1.32.0" } }, "sha512-NXYBzinNrblfraPGyrbPoD19C1h9lfI/1mzgWYvXUTe414Gz/X1FD2XBZSZM7rRTrMA8JL3OtAaGifrIKhQ5yQ=="],

    "lightningcss-android-arm64": ["lightningcss-android-arm64@1.32.0", "", { "os": "android", "cpu": "arm64" }, "sha512-YK7/ClTt4kAK0vo6w3X+Pnm0D2cf2vPHbhOXdoNti1Ga0al1P4TBZhwjATvjNwLEBCnKvjJc2jQgHXH0NEwlAg=="],

    "lightningcss-darwin-arm64": ["lightningcss-darwin-arm64@1.32.0", "", { "os": "darwin", "cpu": "arm64" }, "sha512-RzeG9Ju5bag2Bv1/lwlVJvBE3q6TtXskdZLLCyfg5pt+HLz9BqlICO7LZM7VHNTTn/5PRhHFBSjk5lc4cmscPQ=="],

    "lightningcss-darwin-x64": ["lightningcss-darwin-x64@1.32.0", "", { "os": "darwin", "cpu": "x64" }, "sha512-U+QsBp2m/s2wqpUYT/6wnlagdZbtZdndSmut/NJqlCcMLTWp5muCrID+K5UJ6jqD2BFshejCYXniPDbNh73V8w=="],

    "lightningcss-freebsd-x64": ["lightningcss-freebsd-x64@1.32.0", "", { "os": "freebsd", "cpu": "x64" }, "sha512-JCTigedEksZk3tHTTthnMdVfGf61Fky8Ji2E4YjUTEQX14xiy/lTzXnu1vwiZe3bYe0q+SpsSH/CTeDXK6WHig=="],

    "lightningcss-linux-arm-gnueabihf": ["lightningcss-linux-arm-gnueabihf@1.32.0", "", { "os": "linux", "cpu": "arm" }, "sha512-x6rnnpRa2GL0zQOkt6rts3YDPzduLpWvwAF6EMhXFVZXD4tPrBkEFqzGowzCsIWsPjqSK+tyNEODUBXeeVHSkw=="],

    "lightningcss-linux-arm64-gnu": ["lightningcss-linux-arm64-gnu@1.32.0", "", { "os": "linux", "cpu": "arm64" }, "sha512-0nnMyoyOLRJXfbMOilaSRcLH3Jw5z9HDNGfT/gwCPgaDjnx0i8w7vBzFLFR1f6CMLKF8gVbebmkUN3fa/kQJpQ=="],

    "lightningcss-linux-arm64-musl": ["lightningcss-linux-arm64-musl@1.32.0", "", { "os": "linux", "cpu": "arm64" }, "sha512-UpQkoenr4UJEzgVIYpI80lDFvRmPVg6oqboNHfoH4CQIfNA+HOrZ7Mo7KZP02dC6LjghPQJeBsvXhJod/wnIBg=="],

    "lightningcss-linux-x64-gnu": ["lightningcss-linux-x64-gnu@1.32.0", "", { "os": "linux", "cpu": "x64" }, "sha512-V7Qr52IhZmdKPVr+Vtw8o+WLsQJYCTd8loIfpDaMRWGUZfBOYEJeyJIkqGIDMZPwPx24pUMfwSxxI8phr/MbOA=="],

    "lightningcss-linux-x64-musl": ["lightningcss-linux-x64-musl@1.32.0", "", { "os": "linux", "cpu": "x64" }, "sha512-bYcLp+Vb0awsiXg/80uCRezCYHNg1/l3mt0gzHnWV9XP1W5sKa5/TCdGWaR/zBM2PeF/HbsQv/j2URNOiVuxWg=="],

    "lightningcss-win32-arm64-msvc": ["lightningcss-win32-arm64-msvc@1.32.0", "", { "os": "win32", "cpu": "arm64" }, "sha512-8SbC8BR40pS6baCM8sbtYDSwEVQd4JlFTOlaD3gWGHfThTcABnNDBda6eTZeqbofalIJhFx0qKzgHJmcPTnGdw=="],

    "lightningcss-win32-x64-msvc": ["lightningcss-win32-x64-msvc@1.32.0", "", { "os": "win32", "cpu": "x64" }, "sha512-Amq9B/SoZYdDi1kFrojnoqPLxYhQ4Wo5XiL8EVJrVsB8ARoC1PWW6VGtT0WKCemjy8aC+louJnjS7U18x3b06Q=="],

    "locate-character": ["locate-character@3.0.0", "", {}, "sha512-SW13ws7BjaeJ6p7Q6CO2nchbYEc3X3J6WrmTTDto7yMPqVSZTUyY5Tjbid+Ab8gLnATtygYtiDIJGQRRn2ZOiA=="],

    "magic-string": ["magic-string@0.30.21", "", { "dependencies": { "@jridgewell/sourcemap-codec": "^1.5.5" } }, "sha512-vd2F4YUyEXKGcLHoq+TEyCjxueSeHnFxyyjNp80yg0XV4vUhnDer/lvvlqM/arB5bXQN5K2/3oinyCRyx8T2CQ=="],

    "magicast": ["magicast@0.5.3", "", { "dependencies": { "@babel/parser": "^7.29.3", "@babel/types": "^7.29.0", "source-map-js": "^1.2.1" } }, "sha512-pVKE4UdSQ7DvHzivsCIFx2BJn1mHG6KsyrFcaxFx6tONdneEuThrDx0Cj3AMg58KyN4pzYT+LHOotxDQDjNvkw=="],

    "make-dir": ["make-dir@4.0.0", "", { "dependencies": { "semver": "^7.5.3" } }, "sha512-hXdUTZYIVOt1Ex//jAQi+wTZZpUpwBj/0QsOzqegb3rGMMeJiSEu5xLHnYfBrRV4RH2+OCSOO95Is/7x1WJ4bw=="],

    "mimic-response": ["mimic-response@3.1.0", "", {}, "sha512-z0yWI+4FDrrweS8Zmt4Ej5HdJmky15+L2e6Wgn3+iK5fWzb6T3fhNFq2+MeTRb064c6Wr4N/wv0DzQTjNzHNGQ=="],

    "minimatch": ["minimatch@10.2.5", "", { "dependencies": { "brace-expansion": "^5.0.5" } }, "sha512-MULkVLfKGYDFYejP07QOurDLLQpcjk7Fw+7jXS2R2czRQzR56yHRveU5NDJEOviH+hETZKSkIk5c+T23GjFUMg=="],

    "minimist": ["minimist@1.2.8", "", {}, "sha512-2yyAR8qBkN3YuheJanUpWC5U3bb5osDywNB8RzDVlDwDHbocAJveqqj1u8+SVD7jkWT4yvsHCpWqqWqAxb0zCA=="],

    "mkdirp-classic": ["mkdirp-classic@0.5.3", "", {}, "sha512-gKLcREMhtuZRwRAfqP3RFW+TK4JqApVBtOIftVgjuABpAtpxhPGaDcfvbhNvD0B8iD1oUr/txX35NjcaY6Ns/A=="],

    "mri": ["mri@1.2.0", "", {}, "sha512-tzzskb3bG8LvYGFF/mDTpq3jpI6Q9wc3LEmBaghu+DdCssd1FakN7Bc0hVNmEyGq1bq3RgfkCb3cmQLpNPOroA=="],

    "mrmime": ["mrmime@2.0.1", "", {}, "sha512-Y3wQdFg2Va6etvQ5I82yUhGdsKrcYox6p7FfL1LbK2J4V01F9TGlepTIhnK24t7koZibmg82KGglhA1XK5IsLQ=="],

    "ms": ["ms@2.1.3", "", {}, "sha512-6FlzubTLZG3J2a/NVCAleEhjzq5oxgHyaCU9yYXvcLsvoVaHJq/s5xXI6/XXP6tz7R9xAOtHnSO/tXtF3WRTlA=="],

    "nanoid": ["nanoid@3.3.12", "", { "bin": { "nanoid": "bin/nanoid.cjs" } }, "sha512-ZB9RH/39qpq5Vu6Y+NmUaFhQR6pp+M2Xt76XBnEwDaGcVAqhlvxrl3B2bKS5D3NH3QR76v3aSrKaF/Kiy7lEtQ=="],

    "napi-build-utils": ["napi-build-utils@2.0.0", "", {}, "sha512-GEbrYkbfF7MoNaoh2iGG84Mnf/WZfB0GdGEsM8wz7Expx/LlWf5U8t9nvJKXSp3qr5IsEbK04cBGhol/KwOsWA=="],

    "node-abi": ["node-abi@3.92.0", "", { "dependencies": { "semver": "^7.3.5" } }, "sha512-KdHvFWZjEKDf0cakgFjebl371GPsISX2oZHcuyKqM7DtogIsHrqKeLTo8wBHxaXRAQlY2PsPlZmfo+9ZCxEREQ=="],

    "normalize-path": ["normalize-path@3.0.0", "", {}, "sha512-6eZs5Ls3WtCisHWp9S2GUy8dqkpGi4BVSz3GaqiE6ezub0512ESztXUwUB6C6IKbQkY2Pnb/mD4WYojCRwcwLA=="],

    "obug": ["obug@2.1.3", "", {}, "sha512-9miFgM2OFba7hB+pRgvtV84pYTBaoTHohvmIgiRt6dRIzbwEOIaNaP+dIlGs2fNFoB0SeISs0Jz5WFVRid6Xyg=="],

    "once": ["once@1.4.0", "", { "dependencies": { "wrappy": "1" } }, "sha512-lNaJgI+2Q5URQBkccEKHTQOPaXdUxnZZElQTZY0MFUAuaEqe1E+Nyvgdz/aIyNi6Z9MzO5dv1H8n58/GELp3+w=="],

    "parse-cache-control": ["parse-cache-control@1.0.1", "", {}, "sha512-60zvsJReQPX5/QP0Kzfd/VrpjScIQ7SHBW6bFCYfEP+fp0Eppr1SHhIO5nd1PjZtvclzSzES9D/p5nFJurwfWg=="],

    "path-parse": ["path-parse@1.0.7", "", {}, "sha512-LDJzPVEEEPR+y48z93A0Ed0yXb8pAByGWo/k5YYdYgpY2/2EsOsksJrq7lOHxryrVOn1ejG6oAp8ahvOIQD8sw=="],

    "pathe": ["pathe@2.0.3", "", {}, "sha512-WUjGcAqP1gQacoQe+OBJsFA7Ld4DyXuUIjZ5cc75cLHvJ7dtNsTugphxIADwspS+AraAUePCKrSVtPLFj/F88w=="],

    "picocolors": ["picocolors@1.1.1", "", {}, "sha512-xceH2snhtb5M9liqDsmEw56le376mTZkEX/jEb/RxNFyegNul7eNslCXP9FDj/Lcu0X8KEyMceP2ntpaHrDEVA=="],

    "picomatch": ["picomatch@4.0.4", "", {}, "sha512-QP88BAKvMam/3NxH6vj2o21R6MjxZUAd6nlwAS/pnGvN9IVLocLHxGYIzFhg6fUQ+5th6P4dv4eW9jX3DSIj7A=="],

    "postcss": ["postcss@8.5.15", "", { "dependencies": { "nanoid": "^3.3.12", "picocolors": "^1.1.1", "source-map-js": "^1.2.1" } }, "sha512-FfR8sjd4em2T6fb3I2MwAJU7HWVMr9zba+enmQeeWFfCbm+UOC/0X4DS8XtpUTMwWMGbjKYP7xjfNekzyGmB3A=="],

    "prebuild-install": ["prebuild-install@7.1.3", "", { "dependencies": { "detect-libc": "^2.0.0", "expand-template": "^2.0.3", "github-from-package": "0.0.0", "minimist": "^1.2.3", "mkdirp-classic": "^0.5.3", "napi-build-utils": "^2.0.0", "node-abi": "^3.3.0", "pump": "^3.0.0", "rc": "^1.2.7", "simple-get": "^4.0.0", "tar-fs": "^2.0.0", "tunnel-agent": "^0.6.0" }, "bin": { "prebuild-install": "bin.js" } }, "sha512-8Mf2cbV7x1cXPUILADGI3wuhfqWvtiLA1iclTDbFRZkgRQS0NqsPZphna9V+HyTEadheuPmjaJMsbzKQFOzLug=="],

    "process": ["process@0.11.10", "", {}, "sha512-cdGef/drWFoydD1JsMzuFf8100nZl+GT+yacc2bEced5f9Rjk4z+WtFUTBu9PhOi9j/jfmBPu0mMEY4wIdAF8A=="],

    "process-nextick-args": ["process-nextick-args@2.0.1", "", {}, "sha512-3ouUOpQhtgrbOa17J7+uxOTpITYWaGP7/AhoR3+A+/1e9skrzelGi/dXzEYyvbxubEF6Wn2ypscTKiKJFFn1ag=="],

    "progress": ["progress@2.0.3", "", {}, "sha512-7PiHtLll5LdnKIMw100I+8xJXR5gW2QwWYkT6iJva0bXitZKa/XMrSbdmg3r2Xnaidz9Qumd0VPaMrZlF9V9sA=="],

    "pump": ["pump@3.0.4", "", { "dependencies": { "end-of-stream": "^1.1.0", "once": "^1.3.1" } }, "sha512-VS7sjc6KR7e1ukRFhQSY5LM2uBWAUPiOPa/A3mkKmiMwSmRFUITt0xuj+/lesgnCv+dPIEYlkzrcyXgquIHMcA=="],

    "rc": ["rc@1.2.8", "", { "dependencies": { "deep-extend": "^0.6.0", "ini": "~1.3.0", "minimist": "^1.2.0", "strip-json-comments": "~2.0.1" }, "bin": { "rc": "./cli.js" } }, "sha512-y3bGgqKj3QBdxLbLkomlohkvsA8gdAiUQlSBJnBhfn+BPxg4bc62d8TcBW15wavDfgexCgccckhcZvywyQYPOw=="],

    "readable-stream": ["readable-stream@4.7.0", "", { "dependencies": { "abort-controller": "^3.0.0", "buffer": "^6.0.3", "events": "^3.3.0", "process": "^0.11.10", "string_decoder": "^1.3.0" } }, "sha512-oIGGmcpTLwPga8Bn6/Z75SVaH1z5dUut2ibSyAMVhmUggWpmDn2dapB0n7f8nwaSiRtepAsfJyfXIO5DCVAODg=="],

    "readdir-glob": ["readdir-glob@3.0.0", "", { "dependencies": { "minimatch": "^10.2.2" } }, "sha512-AhNB2KgKeVJr16nK9LLZbJNWnYoT23ZrumNKFDebHBdkC8KHSqWo871JAUhoWC/RtjEVdqNMFpM6qrwRbaUqpw=="],

    "readdirp": ["readdirp@5.0.0", "", {}, "sha512-9u/XQ1pvrQtYyMpZe7DXKv2p5CNvyVwzUB6uhLAnQwHMSgKMBR62lc7AHljaeteeHXn11XTAaLLUVZYVZyuRBQ=="],

    "resolve": ["resolve@1.22.12", "", { "dependencies": { "es-errors": "^1.3.0", "is-core-module": "^2.16.1", "path-parse": "^1.0.7", "supports-preserve-symlinks-flag": "^1.0.0" }, "bin": { "resolve": "bin/resolve" } }, "sha512-TyeJ1zif53BPfHootBGwPRYT1RUt6oGWsaQr8UyZW/eAm9bKoijtvruSDEmZHm92CwS9nj7/fWttqPCgzep8CA=="],

    "rolldown": ["rolldown@1.0.3", "", { "dependencies": { "@oxc-project/types": "=0.133.0", "@rolldown/pluginutils": "^1.0.0" }, "optionalDependencies": { "@rolldown/binding-android-arm64": "1.0.3", "@rolldown/binding-darwin-arm64": "1.0.3", "@rolldown/binding-darwin-x64": "1.0.3", "@rolldown/binding-freebsd-x64": "1.0.3", "@rolldown/binding-linux-arm-gnueabihf": "1.0.3", "@rolldown/binding-linux-arm64-gnu": "1.0.3", "@rolldown/binding-linux-arm64-musl": "1.0.3", "@rolldown/binding-linux-ppc64-gnu": "1.0.3", "@rolldown/binding-linux-s390x-gnu": "1.0.3", "@rolldown/binding-linux-x64-gnu": "1.0.3", "@rolldown/binding-linux-x64-musl": "1.0.3", "@rolldown/binding-openharmony-arm64": "1.0.3", "@rolldown/binding-wasm32-wasi": "1.0.3", "@rolldown/binding-win32-arm64-msvc": "1.0.3", "@rolldown/binding-win32-x64-msvc": "1.0.3" }, "bin": { "rolldown": "./bin/cli.mjs" } }, "sha512-i00lAJ2ks1BYr7rjNjKC7BcqAS7nVfiT3QX1SI5aY+AFHblCmaUf9OE9dbdzDvW6dJxbi2ZCZiy9v3CcwOiX3g=="],

    "rollup": ["rollup@4.62.0", "", { "dependencies": { "@types/estree": "1.0.9" }, "optionalDependencies": { "@rollup/rollup-android-arm-eabi": "4.62.0", "@rollup/rollup-android-arm64": "4.62.0", "@rollup/rollup-darwin-arm64": "4.62.0", "@rollup/rollup-darwin-x64": "4.62.0", "@rollup/rollup-freebsd-arm64": "4.62.0", "@rollup/rollup-freebsd-x64": "4.62.0", "@rollup/rollup-linux-arm-gnueabihf": "4.62.0", "@rollup/rollup-linux-arm-musleabihf": "4.62.0", "@rollup/rollup-linux-arm64-gnu": "4.62.0", "@rollup/rollup-linux-arm64-musl": "4.62.0", "@rollup/rollup-linux-loong64-gnu": "4.62.0", "@rollup/rollup-linux-loong64-musl": "4.62.0", "@rollup/rollup-linux-ppc64-gnu": "4.62.0", "@rollup/rollup-linux-ppc64-musl": "4.62.0", "@rollup/rollup-linux-riscv64-gnu": "4.62.0", "@rollup/rollup-linux-riscv64-musl": "4.62.0", "@rollup/rollup-linux-s390x-gnu": "4.62.0", "@rollup/rollup-linux-x64-gnu": "4.62.0", "@rollup/rollup-linux-x64-musl": "4.62.0", "@rollup/rollup-openbsd-x64": "4.62.0", "@rollup/rollup-openharmony-arm64": "4.62.0", "@rollup/rollup-win32-arm64-msvc": "4.62.0", "@rollup/rollup-win32-ia32-msvc": "4.62.0", "@rollup/rollup-win32-x64-gnu": "4.62.0", "@rollup/rollup-win32-x64-msvc": "4.62.0", "fsevents": "~2.3.2" }, "bin": { "rollup": "dist/bin/rollup" } }, "sha512-nc72Wgq62I7rtDV4izT5/aaS0zxy3kttkinf9586ApknY3jZO9NYsmtc24fUckA0X7Q2v+ML4a15pdUlV5V/jA=="],

    "sade": ["sade@1.8.1", "", { "dependencies": { "mri": "^1.1.0" } }, "sha512-xal3CZX1Xlo/k4ApwCFrHVACi9fBqJ7V+mwhBsuf/1IOKbBy098Fex+Wa/5QMubw09pSZ/u8EY8PWgevJsXp1A=="],

    "safe-buffer": ["safe-buffer@5.1.2", "", {}, "sha512-Gd2UZBJDkXlY7GbJxfsE8/nvKkUEU1G38c1siN6QP6a9PT9MmHB8GnpscSmMJSoF8LOIrt8ud/wPtojys4G6+g=="],

    "semver": ["semver@7.8.4", "", { "bin": { "semver": "bin/semver.js" } }, "sha512-rUCObTnP32Q08R2uuIrt7r9PlEonuTmtuXYcW6s5kjdlj3xbnwe+21yXptAUYcMAABLkYYTtnmzb3w3EDZfueA=="],

    "set-cookie-parser": ["set-cookie-parser@3.1.0", "", {}, "sha512-kjnC1DXBHcxaOaOXBHBeRtltsDG2nUiUni+jP92M9gYdW12rsmx92UsfpH7o5tDRs7I1ZZPSQJQGv3UaRfCiuw=="],

    "sharp": ["sharp@0.35.1", "", { "dependencies": { "@img/colour": "^1.1.0", "detect-libc": "^2.1.2", "semver": "^7.8.4" }, "optionalDependencies": { "@img/sharp-darwin-arm64": "0.35.1", "@img/sharp-darwin-x64": "0.35.1", "@img/sharp-freebsd-wasm32": "0.35.1", "@img/sharp-libvips-darwin-arm64": "1.3.0", "@img/sharp-libvips-darwin-x64": "1.3.0", "@img/sharp-libvips-linux-arm": "1.3.0", "@img/sharp-libvips-linux-arm64": "1.3.0", "@img/sharp-libvips-linux-ppc64": "1.3.0", "@img/sharp-libvips-linux-riscv64": "1.3.0", "@img/sharp-libvips-linux-s390x": "1.3.0", "@img/sharp-libvips-linux-x64": "1.3.0", "@img/sharp-libvips-linuxmusl-arm64": "1.3.0", "@img/sharp-libvips-linuxmusl-x64": "1.3.0", "@img/sharp-linux-arm": "0.35.1", "@img/sharp-linux-arm64": "0.35.1", "@img/sharp-linux-ppc64": "0.35.1", "@img/sharp-linux-riscv64": "0.35.1", "@img/sharp-linux-s390x": "0.35.1", "@img/sharp-linux-x64": "0.35.1", "@img/sharp-linuxmusl-arm64": "0.35.1", "@img/sharp-linuxmusl-x64": "0.35.1", "@img/sharp-webcontainers-wasm32": "0.35.1", "@img/sharp-win32-arm64": "0.35.1", "@img/sharp-win32-ia32": "0.35.1", "@img/sharp-win32-x64": "0.35.1" } }, "sha512-lW979AMi+ESidzMv/Lnv+F9bknzLyxLqFI05Sm433vOeRcltgxQmXpnfOOFIAlKtwXU/ksupm2srQoFCkR214g=="],

    "siginfo": ["siginfo@2.0.0", "", {}, "sha512-ybx0WO1/8bSBLEWXZvEd7gMW3Sn3JFlW3TvX1nREbDLRNQNaeNN8WK0meBwPdAaOI7TtRRRJn/Es1zhrrCHu7g=="],

    "simple-concat": ["simple-concat@1.0.1", "", {}, "sha512-cSFtAPtRhljv69IK0hTVZQ+OfE9nePi/rtJmw5UjHeVyVroEqJXP1sFztKUy1qU+xvz3u/sfYJLa947b7nAN2Q=="],

    "simple-get": ["simple-get@4.0.1", "", { "dependencies": { "decompress-response": "^6.0.0", "once": "^1.3.1", "simple-concat": "^1.0.0" } }, "sha512-brv7p5WgH0jmQJr1ZDDfKDOSeWWg+OVypG99A/5vYGPqJ6pxiaHLy8nxtFjBA7oMa01ebA9gfh1uMCFqOuXxvA=="],

    "sirv": ["sirv@3.0.2", "", { "dependencies": { "@polka/url": "^1.0.0-next.24", "mrmime": "^2.0.0", "totalist": "^3.0.0" } }, "sha512-2wcC/oGxHis/BoHkkPwldgiPSYcpZK3JU28WoMVv55yHJgcZ8rlXvuG9iZggz+sU1d4bRgIGASwyWqjxu3FM0g=="],

    "source-map-js": ["source-map-js@1.2.1", "", {}, "sha512-UXWMKhLOwVKb728IUtQPXxfYU+usdybtUrK/8uGE8CQMvrhOpwvzDBwj0QhSL7MQc7vIsISBG8VQ8+IDQxpfQA=="],

    "stackback": ["stackback@0.0.2", "", {}, "sha512-1XMJE5fQo1jGH6Y/7ebnwPOBEkIEnT4QF32d5R1+VXdXveM0IBMJt8zfaxX1P3QhVwrYe+576+jkANtSS2mBbw=="],

    "std-env": ["std-env@4.1.0", "", {}, "sha512-Rq7ybcX2RuC55r9oaPVEW7/xu3tj8u4GeBYHBWCychFtzMIr86A7e3PPEBPT37sHStKX3+TiX/Fr/ACmJLVlLQ=="],

    "streamx": ["streamx@2.28.0", "", { "dependencies": { "events-universal": "^1.0.0", "fast-fifo": "^1.3.2", "text-decoder": "^1.1.0" } }, "sha512-1Yowhzjf0ivGMrTIkY9hav5TxobO9qIVqUE41fiCGMGgc3CLlf4MY+9AHmZqBWgDTue0fY9zWjYFVyf6Diuobw=="],

    "string_decoder": ["string_decoder@1.3.0", "", { "dependencies": { "safe-buffer": "~5.2.0" } }, "sha512-hkRX8U1WjJFd8LsDJ2yQ/wWWxaopEsABU1XfkM8A+j0+85JAGppt16cr1Whg6KIbb4okU6Mql6BOj+uup/wKeA=="],

    "strip-json-comments": ["strip-json-comments@2.0.1", "", {}, "sha512-4gB8na07fecVVkOI6Rs4e7T6NOTki5EmL7TUduTs6bu3EdnSycntVJ4re8kgZA+wx9IueI2Y11bfbgwtzuE0KQ=="],

    "supports-color": ["supports-color@7.2.0", "", { "dependencies": { "has-flag": "^4.0.0" } }, "sha512-qpCAvRl9stuOHveKsn7HncJRvv501qIacKzQlO/+Lwxc9+0q2wLyv4Dfvt80/DPn2pqOBsJdDiogXGR9+OvwRw=="],

    "supports-preserve-symlinks-flag": ["supports-preserve-symlinks-flag@1.0.0", "", {}, "sha512-ot0WnXS9fgdkgIcePe6RHNk1WA8+muPa6cSjeR3V8K27q9BB1rTE3R1p7Hv0z1ZyAc8s6Vvv8DIyWf681MAt0w=="],

    "svelte": ["svelte@5.56.3", "", { "dependencies": { "@jridgewell/remapping": "^2.3.4", "@jridgewell/sourcemap-codec": "^1.5.0", "@sveltejs/acorn-typescript": "^1.0.10", "@types/estree": "^1.0.5", "@types/trusted-types": "^2.0.7", "acorn": "^8.12.1", "aria-query": "5.3.1", "axobject-query": "^4.1.0", "clsx": "^2.1.1", "devalue": "^5.8.1", "esm-env": "^1.2.1", "esrap": "^2.2.11", "is-reference": "^3.0.3", "locate-character": "^3.0.0", "magic-string": "^0.30.11", "zimmerframe": "^1.1.2" } }, "sha512-w7JvrM5IFl5cmfbY0TLik9o7mjRUJmRMhOR51tBPu708Gr/MjbGs7VnJnr/B0CaXeI4vtnOh7RKxDr0cwhMdDA=="],

    "svelte-check": ["svelte-check@4.6.0", "", { "dependencies": { "@jridgewell/trace-mapping": "^0.3.25", "@sveltejs/load-config": "0.1.1", "chokidar": "^4.0.1", "fdir": "^6.2.0", "picocolors": "^1.0.0", "sade": "^1.7.4" }, "peerDependencies": { "svelte": "^4.0.0 || ^5.0.0-next.0", "typescript": ">=5.0.0" }, "bin": { "svelte-check": "bin/svelte-check" } }, "sha512-KhVnDFDSid57mmZtHz8gfW8AAGylOZ0vPnOIzVmAL+urzwK8sBYXRss953gD8T0OdgAQ11mdWhE6uadmtOz8TQ=="],

    "tailwindcss": ["tailwindcss@4.3.1", "", {}, "sha512-hk+TB1m+K8CYNrP6rjQaq/Y+4Zylwpa87mLYBKCunwnnQ9p+fHb7kmSfGqyEJoxF/O6CDyABWVFEafNSYKll+Q=="],

    "tapable": ["tapable@2.3.3", "", {}, "sha512-uxc/zpqFg6x7C8vOE7lh6Lbda8eEL9zmVm/PLeTPBRhh1xCgdWaQ+J1CUieGpIfm2HdtsUpRv+HshiasBMcc6A=="],

    "tar-fs": ["tar-fs@2.1.4", "", { "dependencies": { "chownr": "^1.1.1", "mkdirp-classic": "^0.5.2", "pump": "^3.0.0", "tar-stream": "^2.1.4" } }, "sha512-mDAjwmZdh7LTT6pNleZ05Yt65HC3E+NiQzl672vQG38jIrehtJk/J3mNwIg+vShQPcLF/LV7CMnDW6vjj6sfYQ=="],

    "tar-stream": ["tar-stream@3.2.0", "", { "dependencies": { "b4a": "^1.6.4", "bare-fs": "^4.5.5", "fast-fifo": "^1.2.0", "streamx": "^2.15.0" } }, "sha512-ojzvCvVaNp6aOTFmG7jaRD0meowIAuPc3cMMhSgKiVWws1GyHbGd/xvnyuRKcKlMpt3qvxx6r0hreCNITP9hIg=="],

    "teex": ["teex@1.0.1", "", { "dependencies": { "streamx": "^2.12.5" } }, "sha512-eYE6iEI62Ni1H8oIa7KlDU6uQBtqr4Eajni3wX7rpfXD8ysFx8z0+dri+KWEPWpBsxXfxu58x/0jvTVT1ekOSg=="],

    "text-decoder": ["text-decoder@1.2.7", "", { "dependencies": { "b4a": "^1.6.4" } }, "sha512-vlLytXkeP4xvEq2otHeJfSQIRyWxo/oZGEbXrtEEF9Hnmrdly59sUbzZ/QgyWuLYHctCHxFF4tRQZNQ9k60ExQ=="],

    "tinybench": ["tinybench@2.9.0", "", {}, "sha512-0+DUvqWMValLmha6lr4kD8iAMK1HzV0/aKnCtWb9v9641TnP/MFb7Pc2bxoxQjTXAErryXVgUOfv2YqNllqGeg=="],

    "tinyexec": ["tinyexec@1.2.4", "", {}, "sha512-SHf/r48b7vOrjve9PxJo3MN5v5yuyjHvdUcrQffT3WXMUfnGmHDVbC4k3sHJaJTgZCwpUplIaAo5ANtMyp3YHg=="],

    "tinyglobby": ["tinyglobby@0.2.17", "", { "dependencies": { "fdir": "^6.5.0", "picomatch": "^4.0.4" } }, "sha512-wXR/dYpcqKmfWpEdZjiKJOwCNFndD0DMnrW/cYjVGttEkBfVgcLFHoNrlj47mjOVic9yyNu65alsgF4NQyTa2g=="],

    "tinyrainbow": ["tinyrainbow@3.1.0", "", {}, "sha512-Bf+ILmBgretUrdJxzXM0SgXLZ3XfiaUuOj/IKQHuTXip+05Xn+uyEYdVg0kYDipTBcLrCVyUzAPz7QmArb0mmw=="],

    "totalist": ["totalist@3.0.1", "", {}, "sha512-sf4i37nQ2LBx4m3wB74y+ubopq6W/dIzXg0FDGjsYnZHVa1Da8FH853wlL2gtUhg+xJXjfk3kUZS3BRoQeoQBQ=="],

    "tslib": ["tslib@2.8.1", "", {}, "sha512-oJFu94HQb+KVduSUQL7wnpmqnfmLsOA/nAh6b6EH0wCEoK0/mPeXU6c3wKDV83MkOuHPRHtSXKKU99IBazS/2w=="],

    "tunnel-agent": ["tunnel-agent@0.6.0", "", { "dependencies": { "safe-buffer": "^5.0.1" } }, "sha512-McnNiV1l8RYeY8tBgEpuodCC1mLUdbSN+CYBL7kJsJNInOP8UjDDEwdk6Mw60vdLLrr5NHKZhMAOSrR2NZuQ+w=="],

    "typedarray": ["typedarray@0.0.6", "", {}, "sha512-/aCDEGatGvZ2BIk+HmLf4ifCJFwvKFNb9/JeZPMulfgFracn9QFcAf5GO8B/mweUjSoblS5In0cWhqpfs/5PQA=="],

    "typescript": ["typescript@6.0.3", "", { "bin": { "tsc": "bin/tsc", "tsserver": "bin/tsserver" } }, "sha512-y2TvuxSZPDyQakkFRPZHKFm+KKVqIisdg9/CZwm9ftvKXLP8NRWj38/ODjNbr43SsoXqNuAisEf1GdCxqWcdBw=="],

    "undici-types": ["undici-types@7.24.6", "", {}, "sha512-WRNW+sJgj5OBN4/0JpHFqtqzhpbnV0GuB+OozA9gCL7a993SmU+1JBZCzLNxYsbMfIeDL+lTsphD5jN5N+n0zg=="],

    "util-deprecate": ["util-deprecate@1.0.2", "", {}, "sha512-EPD5q1uXyFxJpCrLnCc1nHnq3gOa6DZBocAIiI2TaSCA7VCJ1UJDMagCzIkXNsUYfD1daK//LTEQ8xiIbrHtcw=="],

    "vite": ["vite@8.0.16", "", { "dependencies": { "lightningcss": "^1.32.0", "picomatch": "^4.0.4", "postcss": "^8.5.15", "rolldown": "1.0.3", "tinyglobby": "^0.2.17" }, "optionalDependencies": { "fsevents": "~2.3.3" }, "peerDependencies": { "@types/node": "^20.19.0 || >=22.12.0", "@vitejs/devtools": "^0.1.18", "esbuild": "^0.27.0 || ^0.28.0", "jiti": ">=1.21.0", "less": "^4.0.0", "sass": "^1.70.0", "sass-embedded": "^1.70.0", "stylus": ">=0.54.8", "sugarss": "^5.0.0", "terser": "^5.16.0", "tsx": "^4.8.1", "yaml": "^2.4.2" }, "optionalPeers": ["@types/node", "@vitejs/devtools", "esbuild", "jiti", "less", "sass", "sass-embedded", "stylus", "sugarss", "terser", "tsx", "yaml"], "bin": { "vite": "bin/vite.js" } }, "sha512-h9bXPmJichP5fLmVQo3PyaGSDE2n3aPuomeAlVRm0JLmt4rY6zmPKd59HYI4LNW8oTK7tlTsuC7l/m7awx9Jcw=="],

    "vitefu": ["vitefu@1.1.3", "", { "peerDependencies": { "vite": "^3.0.0 || ^4.0.0 || ^5.0.0 || ^6.0.0 || ^7.0.0 || ^8.0.0" }, "optionalPeers": ["vite"] }, "sha512-ub4okH7Z5KLjb6hDyjqrGXqWtWvoYdU3IGm/NorpgHncKoLTCfRIbvlhBm7r0YstIaQRYlp4yEbFqDcKSzXSSg=="],

    "vitest": ["vitest@4.1.9", "", { "dependencies": { "@vitest/expect": "4.1.9", "@vitest/mocker": "4.1.9", "@vitest/pretty-format": "4.1.9", "@vitest/runner": "4.1.9", "@vitest/snapshot": "4.1.9", "@vitest/spy": "4.1.9", "@vitest/utils": "4.1.9", "es-module-lexer": "^2.0.0", "expect-type": "^1.3.0", "magic-string": "^0.30.21", "obug": "^2.1.1", "pathe": "^2.0.3", "picomatch": "^4.0.3", "std-env": "^4.0.0-rc.1", "tinybench": "^2.9.0", "tinyexec": "^1.0.2", "tinyglobby": "^0.2.15", "tinyrainbow": "^3.1.0", "vite": "^6.0.0 || ^7.0.0 || ^8.0.0", "why-is-node-running": "^2.3.0" }, "peerDependencies": { "@edge-runtime/vm": "*", "@opentelemetry/api": "^1.9.0", "@types/node": "^20.0.0 || ^22.0.0 || >=24.0.0", "@vitest/browser-playwright": "4.1.9", "@vitest/browser-preview": "4.1.9", "@vitest/browser-webdriverio": "4.1.9", "@vitest/coverage-istanbul": "4.1.9", "@vitest/coverage-v8": "4.1.9", "@vitest/ui": "4.1.9", "happy-dom": "*", "jsdom": "*" }, "optionalPeers": ["@edge-runtime/vm", "@opentelemetry/api", "@types/node", "@vitest/browser-playwright", "@vitest/browser-preview", "@vitest/browser-webdriverio", "@vitest/coverage-istanbul", "@vitest/coverage-v8", "@vitest/ui", "happy-dom", "jsdom"], "bin": { "vitest": "./vitest.mjs" } }, "sha512-nE3/LEyc0z87uHYLZebqCUOaJr2hdtuPp7BQ4BosVFnfltxgAvMG08NyrSGlPpOUWvR27c5flSmYFTNr78L9GQ=="],

    "which": ["which@1.3.1", "", { "dependencies": { "isexe": "^2.0.0" }, "bin": { "which": "./bin/which" } }, "sha512-HxJdYWq1MTIQbJ3nw0cqssHoTNU267KlrDuGZ1WYlxDStUtKUhOaJmh112/TZmHxxUfuJqPXSOm7tDyas0OSIQ=="],

    "why-is-node-running": ["why-is-node-running@2.3.0", "", { "dependencies": { "siginfo": "^2.0.0", "stackback": "0.0.2" }, "bin": { "why-is-node-running": "cli.js" } }, "sha512-hUrmaWBdVDcxvYqnyh09zunKzROWjbZTiNy8dBEjkS7ehEDQibXJ7XvlmtbwuTclUiIyN+CyXQD4Vmko8fNm8w=="],

    "wrappy": ["wrappy@1.0.2", "", {}, "sha512-l4Sp/DRseor9wL6EvV2+TuQn63dMkPjZ/sp9XkghTEbV9KlPS1xUsZ3u7/IQO4wxtcFB4bgpQPRcR3QCvezPcQ=="],

    "zimmerframe": ["zimmerframe@1.1.4", "", {}, "sha512-B58NGBEoc8Y9MWWCQGl/gq9xBCe4IiKM0a2x7GZdQKOW5Exr8S1W24J6OgM1njK8xCRGvAJIL/MxXHf6SkmQKQ=="],

    "zip-stream": ["zip-stream@7.0.5", "", { "dependencies": { "compress-commons": "^7.0.0", "normalize-path": "^3.0.0", "readable-stream": "^4.0.0" } }, "sha512-dSvYKdvLsAHCDqPOhIwk/q5CvuWtTB3Dgpoe0uVEFjTzIOAmsQpprX25InCvrvJsirEbu1OHyy67n/kAj1Sw/w=="],

    "zod": ["zod@3.25.76", "", {}, "sha512-gzUt/qt81nXsFGKIFcC3YnfEAx5NkunCfnDlvuBSSFS02bcXu4Lmea0AFIUwbLWxWPx3d9p8S5QoaujKcNQxcQ=="],

    "@img/sharp-wasm32/@emnapi/runtime": ["@emnapi/runtime@1.11.1", "", { "dependencies": { "tslib": "^2.4.0" } }, "sha512-vgj7R3y3Wgx24IQaGPA/R6YFXLHVMOZ0uVEyIQPaWs+rd1AzfEMXlAC22FYwO1XkKR6NPsq7mUandH8oIRdZFw=="],

    "@rollup/plugin-commonjs/is-reference": ["is-reference@1.2.1", "", { "dependencies": { "@types/estree": "*" } }, "sha512-U82MsXXiFIrjCK4otLT+o2NA2Cd2g5MLoOVXUZjIOhLurrRxpEXzI8O0KZHr3IjLvlAH1kTPYSuqer5T9ZVBKQ=="],

    "@tailwindcss/oxide-wasm32-wasi/@emnapi/core": ["@emnapi/core@1.11.1", "", { "dependencies": { "@emnapi/wasi-threads": "1.2.2", "tslib": "^2.4.0" }, "bundled": true }, "sha512-RSvbQmHzdKzNsLYa/wHrbc3KN4sYLKAdPZxqiM2HATqv/SBk2/ENSHpvXGaLOMcsAyz0poEGqkmmKYG3OWiJEQ=="],

    "@tailwindcss/oxide-wasm32-wasi/@emnapi/runtime": ["@emnapi/runtime@1.11.1", "", { "dependencies": { "tslib": "^2.4.0" }, "bundled": true }, "sha512-vgj7R3y3Wgx24IQaGPA/R6YFXLHVMOZ0uVEyIQPaWs+rd1AzfEMXlAC22FYwO1XkKR6NPsq7mUandH8oIRdZFw=="],

    "@tailwindcss/oxide-wasm32-wasi/@emnapi/wasi-threads": ["@emnapi/wasi-threads@1.2.2", "", { "dependencies": { "tslib": "^2.4.0" }, "bundled": true }, "sha512-c95qOXkHdydNKhscBTebqEC1CVAZpyqOfVfBzQ1qgzyl3gfeldUjIggDbIZgDKsHLgnsM+igH7TJ/eAasaVuMA=="],

    "@tailwindcss/oxide-wasm32-wasi/@napi-rs/wasm-runtime": ["@napi-rs/wasm-runtime@1.1.5", "", { "dependencies": { "@tybys/wasm-util": "^0.10.2" }, "peerDependencies": { "@emnapi/core": "^1.7.1", "@emnapi/runtime": "^1.7.1" }, "bundled": true }, "sha512-AWPoBRJ9tsnVhor4sjO7rkni+7p+2IAEFj6cx06UgP10jkQHqay/36uRV/bFkgrh18D9vb4cr8Q0Pthskgzy+Q=="],

    "@tailwindcss/oxide-wasm32-wasi/@tybys/wasm-util": ["@tybys/wasm-util@0.10.2", "", { "dependencies": { "tslib": "^2.4.0" }, "bundled": true }, "sha512-RoBvJ2X0wuKlWFIjrwffGw1IqZHKQqzIchKaadZZfnNpsAYp2mM0h36JtPCjNDAHGgYez/15uMBpfGwchhiMgg=="],

    "@tailwindcss/oxide-wasm32-wasi/tslib": ["tslib@2.8.1", "", { "bundled": true }, "sha512-oJFu94HQb+KVduSUQL7wnpmqnfmLsOA/nAh6b6EH0wCEoK0/mPeXU6c3wKDV83MkOuHPRHtSXKKU99IBazS/2w=="],

    "@types/archiver/@types/node": ["@types/node@22.19.21", "", { "dependencies": { "undici-types": "~6.21.0" } }, "sha512-VMeFBSCKQKmm2swI2kW51SFusDqekC6q9trBCvJ/JliDchFSuoYYKN7yVNjPthP1HKZcx3U1gI/wTcEBjEFKTA=="],

    "@types/better-sqlite3/@types/node": ["@types/node@22.19.21", "", { "dependencies": { "undici-types": "~6.21.0" } }, "sha512-VMeFBSCKQKmm2swI2kW51SFusDqekC6q9trBCvJ/JliDchFSuoYYKN7yVNjPthP1HKZcx3U1gI/wTcEBjEFKTA=="],

    "@types/fluent-ffmpeg/@types/node": ["@types/node@22.19.21", "", { "dependencies": { "undici-types": "~6.21.0" } }, "sha512-VMeFBSCKQKmm2swI2kW51SFusDqekC6q9trBCvJ/JliDchFSuoYYKN7yVNjPthP1HKZcx3U1gI/wTcEBjEFKTA=="],

    "@types/readdir-glob/@types/node": ["@types/node@22.19.21", "", { "dependencies": { "undici-types": "~6.21.0" } }, "sha512-VMeFBSCKQKmm2swI2kW51SFusDqekC6q9trBCvJ/JliDchFSuoYYKN7yVNjPthP1HKZcx3U1gI/wTcEBjEFKTA=="],

    "@vitest/mocker/estree-walker": ["estree-walker@3.0.3", "", { "dependencies": { "@types/estree": "^1.0.0" } }, "sha512-7RUKfXgSMMkzt6ZuXmqapOurLGPPfgj6l9uRZ7lRGolvk0y2yocc35LdcxKC5PQZdn2DMqioAQ2NoWcrTKmm6g=="],

    "ast-v8-to-istanbul/estree-walker": ["estree-walker@3.0.3", "", { "dependencies": { "@types/estree": "^1.0.0" } }, "sha512-7RUKfXgSMMkzt6ZuXmqapOurLGPPfgj6l9uRZ7lRGolvk0y2yocc35LdcxKC5PQZdn2DMqioAQ2NoWcrTKmm6g=="],

    "bl/buffer": ["buffer@5.7.1", "", { "dependencies": { "base64-js": "^1.3.1", "ieee754": "^1.1.13" } }, "sha512-EHcyIPBQ4BSGlvjB16k5KgAJ27CIsHY/2JBmCRReo48y9rQ3MaUzWX3KVlBa4U7MyX02HdVj0K7C3WaB3ju7FQ=="],

    "bl/readable-stream": ["readable-stream@3.6.2", "", { "dependencies": { "inherits": "^2.0.3", "string_decoder": "^1.1.1", "util-deprecate": "^1.0.1" } }, "sha512-9u/sniCrY3D5WdsERHzHE4G2YCXqoG5FTHUiCC4SIbr6XcLZBY05ya9EKjYek9O5xOAwjGq+1JdGBAS7Q9ScoA=="],

    "concat-stream/readable-stream": ["readable-stream@3.6.2", "", { "dependencies": { "inherits": "^2.0.3", "string_decoder": "^1.1.1", "util-deprecate": "^1.0.1" } }, "sha512-9u/sniCrY3D5WdsERHzHE4G2YCXqoG5FTHUiCC4SIbr6XcLZBY05ya9EKjYek9O5xOAwjGq+1JdGBAS7Q9ScoA=="],

    "fluent-ffmpeg/async": ["async@0.2.10", "", {}, "sha512-eAkdoKxU6/LkKDBzLpT+t6Ff5EtfSF4wx1WfJiPEEV7WNLnDaRXk0oVysiEPm262roaachGexwUv94WhSgN5TQ=="],

    "http-response-object/@types/node": ["@types/node@10.17.60", "", {}, "sha512-F0KIgDJfy2nA3zMLmWGKxcH2ZVEtCZXHHdOQs2gSaQ27+lNeEfGxzkIw90aXswATX7AZ33tahPbzy6KAfUreVw=="],

    "lazystream/readable-stream": ["readable-stream@2.3.8", "", { "dependencies": { "core-util-is": "~1.0.0", "inherits": "~2.0.3", "isarray": "~1.0.0", "process-nextick-args": "~2.0.0", "safe-buffer": "~5.1.1", "string_decoder": "~1.1.1", "util-deprecate": "~1.0.1" } }, "sha512-8p0AUk4XODgIewSi0l8Epjs+EVnWiK7NoDIEGU0HhE7+ZyY8D1IMY7odu5lRrFXGg71L15KG8QrPmum45RTtdA=="],

    "string_decoder/safe-buffer": ["safe-buffer@5.2.1", "", {}, "sha512-rp3So07KcdmmKbGvgaNxQSJr7bGVSVk5S9Eq1F+ppbRo70+YeaDxkw5Dd8NPN+GD6bjnYm2VuPuCXmpuYvmCXQ=="],

    "svelte-check/chokidar": ["chokidar@4.0.3", "", { "dependencies": { "readdirp": "^4.0.1" } }, "sha512-Qgzu8kfBvo+cA4962jnP1KkS6Dop5NS6g7R5LFYJr4b8Ub94PPQXUksCw9PvXoeXPRRddRNC5C1JQUR2SMGtnA=="],

    "tar-fs/tar-stream": ["tar-stream@2.2.0", "", { "dependencies": { "bl": "^4.0.3", "end-of-stream": "^1.4.1", "fs-constants": "^1.0.0", "inherits": "^2.0.3", "readable-stream": "^3.1.1" } }, "sha512-ujeqbceABgwMZxEJnk2HDY2DlnUZ+9oEcb1KzTVfYHio0UE6dG71n60d8D2I4qNvleWrrXpmjpt7vZeF1LnMZQ=="],

    "tunnel-agent/safe-buffer": ["safe-buffer@5.2.1", "", {}, "sha512-rp3So07KcdmmKbGvgaNxQSJr7bGVSVk5S9Eq1F+ppbRo70+YeaDxkw5Dd8NPN+GD6bjnYm2VuPuCXmpuYvmCXQ=="],

    "@types/archiver/@types/node/undici-types": ["undici-types@6.21.0", "", {}, "sha512-iwDZqg0QAGrg9Rav5H4n0M64c3mkR59cJ6wQp+7C4nI0gsmExaedaYLNO44eT4AtBBwjbTiGPMlt2Md0T9H9JQ=="],

    "@types/better-sqlite3/@types/node/undici-types": ["undici-types@6.21.0", "", {}, "sha512-iwDZqg0QAGrg9Rav5H4n0M64c3mkR59cJ6wQp+7C4nI0gsmExaedaYLNO44eT4AtBBwjbTiGPMlt2Md0T9H9JQ=="],

    "@types/fluent-ffmpeg/@types/node/undici-types": ["undici-types@6.21.0", "", {}, "sha512-iwDZqg0QAGrg9Rav5H4n0M64c3mkR59cJ6wQp+7C4nI0gsmExaedaYLNO44eT4AtBBwjbTiGPMlt2Md0T9H9JQ=="],

    "@types/readdir-glob/@types/node/undici-types": ["undici-types@6.21.0", "", {}, "sha512-iwDZqg0QAGrg9Rav5H4n0M64c3mkR59cJ6wQp+7C4nI0gsmExaedaYLNO44eT4AtBBwjbTiGPMlt2Md0T9H9JQ=="],

    "lazystream/readable-stream/string_decoder": ["string_decoder@1.1.1", "", { "dependencies": { "safe-buffer": "~5.1.0" } }, "sha512-n/ShnvDi6FHbbVfviro+WojiFzv+s8MPMHBczVePfUpDJLwoLT0ht1l4YwBCbi8pJAveEEdnkHyPyTP/mzRfwg=="],

    "svelte-check/chokidar/readdirp": ["readdirp@4.1.2", "", {}, "sha512-GDhwkLfywWL2s6vEjyhri+eXmfH6j1L7JE27WhqLeYzoh/A3DBaYGEj2H/HFZCn/kMfim73FXxEJTw06WtxQwg=="],

    "tar-fs/tar-stream/readable-stream": ["readable-stream@3.6.2", "", { "dependencies": { "inherits": "^2.0.3", "string_decoder": "^1.1.1", "util-deprecate": "^1.0.1" } }, "sha512-9u/sniCrY3D5WdsERHzHE4G2YCXqoG5FTHUiCC4SIbr6XcLZBY05ya9EKjYek9O5xOAwjGq+1JdGBAS7Q9ScoA=="],
  }
}
```

### `docs/01-ARCHITECTURE.md`

````markdown
# 01 — Architecture

## Overview

LGallery is a single long-lived **Node** process (SvelteKit + `@sveltejs/adapter-node`) that reads the local filesystem directly, indexes media into **SQLite**, generates cached thumbnails, and serves a Svelte 5 SPA-like frontend with SSR for the first paint. There is no external service of any kind.

> **Pipeline & subsystems update (2026-06-17).** The media pipeline's earlier in-process pool is now a **worker_threads pool** for image thumbnailing (`server/media/workerPool.ts` driving `server/media/thumb-worker.mjs`); the worker and the in-process fallback share one implementation in `server/media/render-core.mjs` (plain ESM so it loads raw in a worker *and* bundles for SSR). The **main thread owns all `better-sqlite3` writes**; workers only decode/resize/write thumb files. Resilience: bounded retry columns (schema v3) + a boot reset of crash-stranded rows + a periodic back-stop drain. New subsystems: `server/geo/` (offline city dataset + Nominatim reverse geocoding for Places), `server/media/editService.ts` (non-destructive edits via sharp; edited photos render on the main thread), and `shared/edits.ts` (isomorphic edit-op model + CSS preview). Schema is append-only through **v6** (`server/db/schema.ts`). Production is launched via `start.mjs` (sets `UV_THREADPOOL_SIZE` before adapter-node boots).

```
 ┌──────────────────────────────────────────────────────────────┐
 │  Browser (Svelte 5 runes UI)                                   │
 │   timeline grid · lightbox · albums · search · map · settings  │
 └───────────────▲───────────────────────────▲──────────────────┘
                 │ HTTP (SSR + /api + byte streams + SSE)         
 ┌───────────────┴───────────────────────────┴──────────────────┐
 │  SvelteKit server (adapter-node, single process)               │
 │  hooks.server.ts → config + DB + scanner bootstrap             │
 │  ┌───────────┐  ┌────────────┐  ┌───────────────────────────┐ │
 │  │ scanner   │  │ media      │  │ worker_threads pool         │ │
 │  │ walk+diff │→ │ pipeline   │→ │ sharp · exifr · ffmpeg · AI │ │
 │  └─────┬─────┘  └─────┬──────┘  └───────────────────────────┘ │
 │        ▼              ▼                                         │
 │   ┌─────────────────────────────┐    data/thumbnails (WebP)    │
 │   │ SQLite (better-sqlite3, WAL)│    data/trash                │
 │   │ media · albums · faces · …  │    data/models (AI, opt.)    │
 │   └─────────────────────────────┘                              │
 └────────────────────────────────────────────────────────────────┘
        ▲ reads (never writes unless user organizes)
 ┌──────┴──────────────────────────────────────────┐
 │  User media roots (from lgallery.config.json)     │
 └───────────────────────────────────────────────────┘
```

## Tech stack & rationale

| Layer | Choice | Why |
|---|---|---|
| Framework | **SvelteKit 2 + Svelte 5 (runes)** | Fast, small, SSR + endpoints in one app; runes for ergonomic reactive state |
| Adapter | **`@sveltejs/adapter-node`** | Long-lived process needed for filesystem access, native modules, background scanner |
| Language | **TypeScript (strict)** | Safety across server/client boundary |
| Styling | **Tailwind CSS v4** (`@tailwindcss/vite`) | Utility-first, dark mode via `class`; no config file in v4 |
| UI primitives | **bits-ui** (Svelte 5 native) + **lucide-svelte** | Accessible dialogs/menus/popovers + icons |
| DB | **`better-sqlite3`** + **drizzle-orm** / drizzle-kit | Synchronous, extremely fast, single file; typed schema + migrations |
| Images | **`sharp`** | libvips-backed, EXIF-orientation aware, WebP thumbnails |
| Metadata | **`exifr`** | Fast EXIF/GPS/date + embedded-thumbnail extraction |
| Video | **`fluent-ffmpeg`** + **`ffmpeg-static`** + **`ffprobe-static`** | Poster frames + duration without a system ffmpeg |
| Map | **Leaflet** + **`leaflet.markercluster`** + OSM tiles | Mature, offline-capable design, marker clustering for many points |
| AI (optional) | **`@huggingface/transformers`** on **`onnxruntime-node`** + **`sqlite-vec`** | Local CLIP embeddings + face embeddings + vector search |
| Validation | **`zod`** (pinned v3) | Config + API body validation; zod 4 broke `.object().default({})` typing with no security upside, so v3 is deliberate |
| Placeholders | **`blurhash`** | Tiny instant placeholders for progressive grid loading |
| Virtualization | **hand-rolled** (no library) | Justified variable-height rows; full control; avoids `@tanstack/svelte-virtual` |
| File watcher (optional) | **`chokidar`** | Live incremental re-index, gated by `scan.watch`; runs under the Bun runtime |
| Tooling | **Bun** (`bun@1.3.14`) | Package manager + script runner + lockfile (`bun.lock`); orchestrates install/dev/build/test |
| Server runtime | **Node** (`node build`) | The running server stays on Node — `better-sqlite3` is unsupported in the Bun runtime ([oven-sh/bun#4290](https://github.com/oven-sh/bun/issues/4290)) |

## Tooling & runtime

**Bun** is the package manager and script runner (`bun install`, `bun run dev`, `bun run build`, `bun run test`, `bun run test:cov`, `bun run check`); the lockfile is `bun.lock` and `packageManager` is `bun@1.3.14`. The **running server is still Node** (`node build`) because `better-sqlite3` is not supported in the Bun runtime ([oven-sh/bun#4290](https://github.com/oven-sh/bun/issues/4290)); vite/vitest/svelte-check also execute via their bins under Node. So the split is **Bun for install/scripts/build orchestration, Node for the live server**. `sharp`, `ffmpeg`, and `chokidar` all run fine under Bun. Dependencies are kept at the latest non-vulnerable versions (0 advisories via `bun audit`) — vite 8, vitest 4, `@sveltejs/kit` 2.65, svelte 5.56, tailwindcss 4.3, typescript 6, sharp 0.35, chokidar 5 — with `zod` pinned to v3 (3.25) and a `cookie` override (`^0.7.2`) clearing a transitive low-severity kit advisory.

## Folder layout

```
LGallery/
  lgallery.config.json / .example.json   # media roots + settings (git-ignored)
  data/                                   # app-managed (git-ignored)
    lgallery.db                           # SQLite index
    thumbnails/                           # sharded WebP cache
    trash/                                # recoverable soft-deletes
    models/                               # AI model weights (optional)
    lgallery.log                          # local rotating log (no telemetry)
  src/
    hooks.server.ts                       # startup bootstrap (config, DB, migrate, scanner)
    app.css  app.html
    lib/
      server/                             # SERVER ONLY (never imported client-side)
        db/{index,schema,migrate,queries}.ts
        config/configService.ts
        scan/{scanner,walker,differ,scanState,queue,watcher}.ts
        media/{thumbnailService,videoService,exifService,hashService,fileService,streamService}.ts
        ai/{embedService,faceService,vectorIndex}.ts   # lazy, toggle-gated
        paths.ts                          # root allow-list + traversal guard + thumb sharding
        log.ts
      shared/{types,layout,format}.ts     # PURE, no node deps (usable client + server)
      client/state/{gallery,selection,scanStatus,settings}.svelte.ts
      client/api.ts
      components/{grid,lightbox,panels,map,common,nav}/...
    routes/
      +layout.svelte  +layout.server.ts   # layout load re-checks config hash → rescan
      +page.svelte    +page.server.ts      # timeline (SSR first keyset page)
      folders/ albums/ search/ map/ people/ memories/ trash/ duplicates/ settings/
      api/...                              # +server.ts endpoints
```

**Hard boundary rules**
- Nothing under `lib/server/**` may be imported by client code (SvelteKit enforces this; it also keeps native modules off the client bundle).
- `lib/shared/**` is the **only** dual-world code — pure functions, no `node:` imports. The justified-layout math lives here so it is unit-testable and reusable in SSR.

## Request/data flow

1. **Startup** (`hooks.server.ts`, runs once): read + validate config, open DB (apply pragmas), run migrations, reconcile `roots`, enqueue a scan if the config hash changed or the DB is empty.
2. **Every page load** (`+layout.server.ts`): cheaply re-hash the config file; on mismatch, update roots and enqueue a non-blocking incremental rescan. This satisfies "re-read on startup **and** on reload".
3. **Timeline** (`+page.server.ts`): SSR the first keyset page directly from SQLite so first paint is instant; the client then paginates via `/api/timeline`.
4. **Thumbnails/originals**: served by `/api/media/[id]/...` endpoints (generate-on-miss for thumbs; HTTP Range for originals/video).
5. **Background work**: the scanner and a bounded `worker_threads` pool generate metadata → thumbnails → (optional) AI embeddings, prioritized by what's on screen.

## The seven tricky parts (cross-references)

| Concern | Where designed |
|---|---|
| Config + rescan trigger | this doc + [`03-CONFIG.md`](03-CONFIG.md) |
| Scan / incremental index | [`05-PERFORMANCE.md`](05-PERFORMANCE.md) (scan section) |
| Thumbnail + metadata pipeline | this doc + [`05-PERFORMANCE.md`](05-PERFORMANCE.md) |
| Serving originals + video (Range, path safety) | [`07-SECURITY.md`](07-SECURITY.md) + [`09-API.md`](09-API.md) |
| Virtualized timeline grid | [`05-PERFORMANCE.md`](05-PERFORMANCE.md) |
| DB schema | [`02-DATA-MODEL.md`](02-DATA-MODEL.md) |
| API surface | [`09-API.md`](09-API.md) |

## Scanner & pipeline (summary)

- **Walk**: iterative (explicit stack) `fs.promises.opendir` streaming traversal; normalizes paths; skips hidden/system dirs and `data/`.
- **Diff**: per-file lookup by normalized `path`; classify new / changed (`mtime`+`size`) / unchanged; stamp `scan_id`; post-walk sweep removes rows whose `scan_id` is stale (deleted on disk).
- **Date-first pass**: extract EXIF `taken_ms` early (cheap) so timeline order is correct immediately and items don't reshuffle. Priority order in the queue: **metadata → thumbnails → AI**.
- **Pipeline**: bounded `worker_threads` pool runs `sharp` (image thumbs, orientation-corrected), `ffmpeg`/`ffprobe` (video poster + duration), `exifr` (full EXIF). Status tracked per row (`meta_status`, `thumb_status`) so work is **resumable** after a restart.
- **Progress**: in-memory `scanState` exposed via `GET /api/scan/status` (poll) and `GET /api/scan/stream` (SSE) for a live progress chip.
- **Live watcher** (`scan/watcher.ts`, gated by `scan.watch`): a `chokidar` watcher started in `bootScan` (and restarted on config save) feeds debounced, batched add/change/unlink events straight into the DB + media pipeline, so changes index incrementally with no manual rescan.
- **Canonical roots**: config root paths are canonicalized at load via `fs.realpathSync.native`, which on Windows expands 8.3 short names (e.g. `CLARK~1.BER` → `clark.bernales`). This keeps the scanner, watcher (libuv fs-events assert on 8.3 paths), and the path allow-list mutually consistent.

## State management (client)

Svelte 5 **runes in `.svelte.ts` reactive-class modules** (the current idiom, replacing legacy stores):
- `gallery.svelte.ts` — loaded pages, layout cache, current view/filter
- `selection.svelte.ts` — multi-select set + bulk-action state
- `scanStatus.svelte.ts` — SSE subscription + progress
- `settings.svelte.ts` — theme, grid density, AI/LAN toggles

## UI layer (design tokens)

`app.css` defines a **design-token system** — CSS variables for color/surface/overlay/radius/shadow/motion plus reusable `.lg-bar` / `.btn` / `.lg-card` / `.lg-input` classes — consumed by shared `PageHeader` / `EmptyState` / `Skeleton` components for a consistent look across views.
````

### `docs/02-DATA-MODEL.md`

````markdown
# 02 — Data Model (SQLite)

SQLite via `better-sqlite3`, schema + migrations managed by **drizzle-orm / drizzle-kit**. The hot timeline query uses raw prepared SQL for maximum speed.

## Pragmas (applied on open)

```sql
PRAGMA journal_mode = WAL;        -- concurrent reads while writing
PRAGMA synchronous  = NORMAL;     -- safe with WAL, much faster
PRAGMA foreign_keys = ON;
PRAGMA temp_store   = MEMORY;
PRAGMA cache_size   = -65536;     -- ~64 MB page cache
PRAGMA mmap_size    = 268435456;  -- 256 MB memory-mapped I/O
PRAGMA busy_timeout = 5000;       -- wait instead of erroring under contention
```
On graceful shutdown: `PRAGMA wal_checkpoint(TRUNCATE)` then close.

## Conventions

- **Dates** are `INTEGER` unix-ms **UTC**. `taken_local_day` (`TEXT` `YYYY-MM-DD`) is precomputed so day/month grouping needs no query-time timezone math. See timezone policy in [`05-PERFORMANCE.md`](05-PERFORMANCE.md) / [`04-FEATURES.md`](04-FEATURES.md).
- **Paths** are stored normalized: forward-slashes, lower-cased drive letter (Windows), absolute. The same normalization feeds the traversal allow-list — see [`07-SECURITY.md`](07-SECURITY.md).
- Clients reference media by **integer `id`** only; raw paths never cross the wire.

## Core tables

```sql
CREATE TABLE roots (
  id INTEGER PRIMARY KEY,
  path TEXT NOT NULL UNIQUE,          -- normalized absolute
  label TEXT,
  enabled INTEGER NOT NULL DEFAULT 1
);

CREATE TABLE media (
  id INTEGER PRIMARY KEY,
  path TEXT NOT NULL UNIQUE,          -- normalized absolute
  root_id INTEGER NOT NULL REFERENCES roots(id) ON DELETE CASCADE,
  rel_path TEXT NOT NULL, dir TEXT NOT NULL, filename TEXT NOT NULL, ext TEXT NOT NULL,
  type TEXT NOT NULL,                 -- 'photo' | 'video'
  size_bytes INTEGER NOT NULL,
  mtime_ms INTEGER NOT NULL,          -- incremental-diff key (with size_bytes)
  width INTEGER, height INTEGER, duration_ms INTEGER,
  taken_ms INTEGER,                   -- EXIF DateTimeOriginal, fallback mtime
  taken_local_day TEXT,              -- 'YYYY-MM-DD' precomputed for grouping
  taken_source TEXT,                 -- 'exif' | 'mtime' (so ordering is explainable)
  camera_make TEXT, camera_model TEXT, lens TEXT, orientation INTEGER,
  has_gps INTEGER NOT NULL DEFAULT 0, gps_lat REAL, gps_lon REAL,
  quick_hash TEXT,                   -- size + partial content hash (exact-dup)
  phash TEXT,                        -- perceptual hash (near-dup), optional
  blurhash TEXT,
  live_partner_id INTEGER REFERENCES media(id) ON DELETE SET NULL,  -- Live/Motion photo pairing
  is_favorite INTEGER NOT NULL DEFAULT 0,
  is_archived INTEGER NOT NULL DEFAULT 0,
  is_trashed  INTEGER NOT NULL DEFAULT 0,
  meta_status  INTEGER NOT NULL DEFAULT 0,  -- 0 none, 1 in-progress, 2 ready, 3 fail
  thumb_status INTEGER NOT NULL DEFAULT 0,  -- "
  error TEXT,                        -- per-file failure detail (locked/corrupt/denied)
  scan_id INTEGER,                   -- last scan that saw this file
  created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL
);

CREATE TABLE albums (
  id INTEGER PRIMARY KEY, name TEXT NOT NULL,
  cover_media_id INTEGER REFERENCES media(id) ON DELETE SET NULL,
  created_at INTEGER NOT NULL, sort_order INTEGER NOT NULL DEFAULT 0
);
CREATE TABLE album_items (
  album_id INTEGER NOT NULL REFERENCES albums(id) ON DELETE CASCADE,
  media_id INTEGER NOT NULL REFERENCES media(id) ON DELETE CASCADE,
  added_at INTEGER NOT NULL, position INTEGER,
  PRIMARY KEY (album_id, media_id)
);

CREATE TABLE tags (id INTEGER PRIMARY KEY, name TEXT NOT NULL UNIQUE);
CREATE TABLE media_tags (
  media_id INTEGER NOT NULL REFERENCES media(id) ON DELETE CASCADE,
  tag_id   INTEGER NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
  PRIMARY KEY (media_id, tag_id)
);

CREATE TABLE trash (
  id INTEGER PRIMARY KEY,
  media_id INTEGER REFERENCES media(id) ON DELETE SET NULL,
  original_path TEXT NOT NULL, trash_path TEXT NOT NULL,
  size_bytes INTEGER NOT NULL, trashed_at INTEGER NOT NULL
);

CREATE TABLE scans (
  id INTEGER PRIMARY KEY, started_at INTEGER NOT NULL, finished_at INTEGER,
  status TEXT NOT NULL,             -- 'running' | 'done' | 'error'
  files_seen INTEGER DEFAULT 0, added INTEGER DEFAULT 0,
  updated INTEGER DEFAULT 0, removed INTEGER DEFAULT 0, error TEXT
);

CREATE TABLE app_state (key TEXT PRIMARY KEY, value TEXT);  -- config_hash, schema_version, etc.
```

## AI tables (created only when AI is enabled)

```sql
-- semantic search (CLIP image embeddings), via sqlite-vec virtual table
CREATE VIRTUAL TABLE embeddings USING vec0(media_id INTEGER PRIMARY KEY, embedding FLOAT[512]);

CREATE TABLE faces (
  id INTEGER PRIMARY KEY,
  media_id INTEGER NOT NULL REFERENCES media(id) ON DELETE CASCADE,
  bbox TEXT NOT NULL,               -- JSON [x,y,w,h]
  embedding BLOB NOT NULL,          -- float32
  cluster_id INTEGER REFERENCES face_clusters(id) ON DELETE SET NULL
);
CREATE TABLE face_clusters (
  id INTEGER PRIMARY KEY, label TEXT,
  cover_face_id INTEGER REFERENCES faces(id) ON DELETE SET NULL
);
```

## Full-text search

```sql
CREATE VIRTUAL TABLE media_fts USING fts5(
  filename, camera_model, rel_path,
  content='media', content_rowid='id'
);
-- kept in sync by triggers on media insert/update/delete
```

## Indexes

```sql
-- hot keyset path for the timeline
CREATE INDEX idx_media_timeline ON media (is_trashed, is_archived, taken_ms DESC, id DESC);
CREATE INDEX idx_media_dir   ON media (root_id, dir, filename);
CREATE INDEX idx_media_type  ON media (type, taken_ms DESC);
CREATE INDEX idx_media_fav   ON media (is_favorite, taken_ms DESC) WHERE is_favorite = 1;
CREATE INDEX idx_media_arch  ON media (is_archived, taken_ms DESC) WHERE is_archived = 1;
CREATE INDEX idx_media_gps   ON media (has_gps, taken_ms DESC)     WHERE has_gps = 1;
CREATE INDEX idx_media_hash  ON media (quick_hash)                 WHERE quick_hash IS NOT NULL;
CREATE INDEX idx_media_phash ON media (phash)                      WHERE phash IS NOT NULL;
CREATE INDEX idx_media_scan  ON media (scan_id);
CREATE INDEX idx_media_pending ON media (meta_status, thumb_status); -- resume queue
```

## Hot timeline query (keyset, never OFFSET)

```sql
SELECT id, type, width, height, taken_ms, taken_local_day, duration_ms, blurhash,
       is_favorite, live_partner_id
FROM media
WHERE is_trashed = 0 AND is_archived = 0
  AND (taken_ms < :curMs OR (taken_ms = :curMs AND id < :curId))
ORDER BY taken_ms DESC, id DESC
LIMIT :limit;
```

Scrubber/label data (cheap aggregate, computed once per view):

```sql
SELECT taken_local_day AS day, COUNT(*) AS n
FROM media WHERE is_trashed = 0 AND is_archived = 0
GROUP BY taken_local_day ORDER BY day DESC;
```

## Migrations & versioning

- Schema versioned in `app_state.schema_version`; drizzle-kit generates SQL migrations applied on startup before the scanner runs.
- Backup-before-migrate: copy `lgallery.db` to `lgallery.db.bak-<schema_version>` prior to applying a new migration (see [`08-DATA-SAFETY.md`](08-DATA-SAFETY.md)).
````

### `docs/03-CONFIG.md`

````markdown
# 03 — Configuration

LGallery is driven by a single JSON file at the project root: **`lgallery.config.json`**. It is **git-ignored** (it contains personal paths). A committed **`lgallery.config.example.json`** documents the shape.

## When it is read

- **On server startup** (`hooks.server.ts`): parsed, validated (`zod`), and hashed.
- **On every page reload** (`+layout.server.ts`): the file is re-hashed; if the hash differs from `app_state.config_hash`, roots are reconciled and a **non-blocking incremental rescan** is enqueued.
- **From the Settings UI**: `PUT /api/config` validates and writes the file, then triggers the same rescan path.

This gives you three ways to change sources — edit the file and restart, edit the file and reload the page, or use Settings — all converging on the same validated write + rescan.

## Full schema

```jsonc
{
  // REQUIRED: one or more folders to scan recursively for media.
  "roots": [
    { "path": "D:/Photos",            "label": "Main",    "enabled": true },
    { "path": "//NAS/media/family",   "label": "NAS",     "enabled": true }
  ],

  // File matching
  "include": ["**/*"],                 // glob(s) relative to each root
  "exclude": ["**/.*", "**/@eaDir/**", "**/#recycle/**", "**/Thumbs.db"],
  "imageExtensions": ["jpg","jpeg","png","gif","webp","avif","bmp","tiff","heic","heif",
                       "cr2","cr3","nef","arw","dng","raf","orf","rw2"],
  "videoExtensions": ["mp4","mov","m4v","webm","mkv","avi","wmv","mts","m2ts","3gp"],

  // Scanning / performance
  "scan": {
    "onStartup": true,
    "rescanOnReload": true,            // config-hash check on each page load
    "watch": false,                    // optional chokidar live-watch (implemented) — see below
    "concurrency": 0,                  // 0 = auto (CPU cores - 2), bounded worker pool
    "removeMissing": true,             // drop DB rows for files deleted on disk
    "followSymlinks": false
  },

  // Thumbnails
  "thumbnails": {
    "dir": "data/thumbnails",
    "format": "webp",
    "grid":    { "longEdge": 320,  "quality": 70 },
    "preview": { "longEdge": 1600, "quality": 80 },
    "videoFrameAtPercent": 10,         // poster frame position
    "videoStoryboardFrames": 5         // hover-scrub sprite frames (0 to disable)
  },

  // Files & trash
  "trash": {
    "dir": "data/trash",               // must share a volume with roots for atomic rename
    "perRoot": false,                  // set true to keep a trash beside each root
    "autoPurgeDays": 30                // 0 = never auto-purge
  },

  // Server / network  (see docs/06 + docs/07)
  "server": {
    "host": "127.0.0.1",               // "0.0.0.0" exposes on the LAN
    "port": 4173,
    "password": null,                  // set a string to require login (hashed at rest)
    "sessionTtlHours": 168
  },

  // Map  (see docs/06)
  "map": {
    "enabled": true,
    "tileUrl": "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
    "attribution": "© OpenStreetMap contributors",
    "reverseGeocode": false            // OFF by default (privacy)
  },

  // AI — OFF by default  (see docs/06)
  "ai": {
    "semanticSearch": false,
    "faceGrouping": false,
    "modelsDir": "data/models",
    "modelSource": "huggingface",      // "local" to use only pre-placed weights
    "device": "cpu"                    // "auto" may use WebGPU/onnx providers if available
  },

  // UI defaults (user-overridable in Settings, persisted in app_state)
  "ui": {
    "theme": "system",                 // "light" | "dark" | "system"
    "gridDensity": "comfortable",      // "compact" | "comfortable" | "spacious"
    "startView": "timeline"            // "timeline" | "folders" | "albums"
  },

  "logging": { "level": "info", "file": "data/lgallery.log", "maxSizeMb": 10, "maxFiles": 5 }
}
```

## Validation rules (zod)

- `roots` must be a non-empty array; each `path` must exist and be a directory at startup (a missing/disconnected root is **warned, not fatal** — it's marked offline and retried, see resilience in [`08-DATA-SAFETY.md`](08-DATA-SAFETY.md)).
- Extensions are lower-cased and de-duplicated; unknown extensions are ignored during the walk.
- `server.host` ∈ {`127.0.0.1`, `0.0.0.0`, a specific interface IP}. Changing it requires a restart (the UI surfaces this).
- `server.password` is never stored in plaintext at runtime state — it is hashed (argon2/scrypt) the first time it is applied; the config field is the source you type, and the Settings UI offers to migrate it to a hashed `passwordHash` form.
- Enabling `ai.*` or `map.reverseGeocode` is the **only** way those network paths activate (see [`06-PRIVACY-AND-NETWORK.md`](06-PRIVACY-AND-NETWORK.md)).

## Live watch (`scan.watch`)

When `scan.watch` is `true`, a `chokidar` watcher (`lib/server/scan/watcher.ts`) runs over the enabled roots and indexes changes incrementally — no manual rescan needed. File add/change/unlink events are **debounced and batched**, then applied straight to the DB and media pipeline. It is started in `bootScan` and restarted whenever the config is saved, and can be toggled from Settings. Default `false`.

## Config hashing

The hash is computed over a **canonicalized** (sorted-key) JSON of the source-relevant fields (`roots`, `include`, `exclude`, extensions). UI-only fields (`ui`, `logging`) do **not** trigger a rescan when changed. Stored in `app_state.config_hash`.

## Path normalization

Every `path` (roots, and any path entered in Settings) is normalized to: absolute, forward-slashes, lower-cased drive letter on Windows, no trailing slash. UNC paths (`//server/share`) are supported. This normalized form is what's stored in `roots`/`media.path` and what the traversal allow-list checks against — see [`07-SECURITY.md`](07-SECURITY.md).

Additionally, root paths are **canonicalized** at load via `fs.realpathSync.native`. On Windows this expands 8.3 short names (e.g. `CLARK~1.BER` → `clark.bernales`), keeping the scanner, the live watcher (libuv fs-events assert on 8.3 paths), and the allow-list consistent. The config reader also tolerates and **strips a leading UTF-8 BOM** before parsing.
````

### `docs/04-FEATURES.md`

```markdown
# 04 — Features

Legend: ✅ planned core · ⭐ Google-Photos-parity extra · 🧪 optional/toggle · 🔮 deferred (see [`12-ROADMAP.md`](12-ROADMAP.md)).

> **Added 2026-06-17 (scale & features pass):**
> - ⭐ **Tags, captions & ratings** — tag chips (with autocomplete) + a searchable caption + 1-5 star rating + **pick/reject** culling flags, all editable in the lightbox Info panel; keyboard `0-5` rate, `P` pick, `X` reject; bulk Rate on the selection bar; a **/tags** view; search filters for rating/pick/tag.
> - ⭐ **Photo editing** (non-destructive) — crop (with aspect presets), rotate/flip, brightness/contrast/saturation/vibrance/warmth, and filter presets (auto/vivid/warm/cool/fade/mono/sepia/noir); Save regenerates derivatives, **Revert** restores the original, **Export copy** writes a new file. The source is never modified.
> - ⭐ **Places** 🧪 — geotagged photos grouped by location name (**/places**); OFF by default, offline bundled-city provider or opt-in OpenStreetMap Nominatim (`config.geocode`).
> - ⭐ **Date-jump scrubber** — a draggable year rail on the timeline's right edge to jump across a huge library instantly (the native scrollbar stays).
> - ✅ **Faster huge libraries** — worker-thread thumbnailing + deferred preview + retry + an ETA in the scan chip (see [`05-PERFORMANCE.md`](05-PERFORMANCE.md)).
> - ✅ **One-click Windows setup** — `setup-lgallery.cmd` installs prerequisites, builds, and offers autostart.

## Browsing & navigation

- ✅ **Timeline by date** — justified row grid (Flickr/Google-style), grouped by day with month separators, infinite (keyset) scroll.
- ✅ **Native scrollbar** — the browser's own right-side scrollbar is the scroll control (per user preference; **not** Google's custom draggable scrubber). A lightweight **floating date label** appears while scrolling to show where you are.
- ✅ **Folder view** — browse by the real on-disk folder structure as albums.
- ⭐ **User albums** — create/rename/delete albums, add/remove media, auto or manual cover, manual ordering.
- ✅ **Grid density toggle** — compact / comfortable / spacious (changes target row height).
- ⭐ **Dark mode** — light / dark / follow-system.
- ⭐ **Responsive layout** — works on phone/tablet over the LAN (see [`07-SECURITY.md`](07-SECURITY.md) for enabling LAN access).

## Viewing (lightbox)

- ✅ **Fullscreen lightbox** with **image zoom & pan**.
- ✅ **Video playback** via HTTP Range streaming (instant start + seeking).
- ✅ **Keyboard navigation** — arrows (prev/next), space (play/pause), `f` (favorite), `i` (info), `Esc` (close), `+`/`-` (zoom), `Del` (trash).
- ✅ **Slideshow** — auto-advance with configurable interval.
- ⭐ **Info / EXIF panel** — camera make/model, lens, dimensions, file size, date taken (+ source: EXIF vs mtime), GPS, full path.
- ⭐ **Touch gestures** — pinch-zoom, swipe to next/prev, double-tap zoom.
- ⭐ **Live / Motion photos** — iPhone HEIC+MOV pairs and Google motion JPEGs detected, badged, and played on hover/long-press.

## Organizing (mutates real files — with safety)

- ✅ **Favorites / starred**.
- ⭐ **Archive** — hide from the main timeline without deleting.
- ⭐ **Multi-select mode** — range/shift select, select-all-in-day, with a floating action bar.
- ✅ **Bulk actions** — favorite, archive, add-to-album, **move**, **download/export (zip)**, **trash**.
- ✅ **Recoverable trash** — delete moves files to `data/trash` + a DB record; **restore** or **permanently delete**; configurable auto-purge after N days. See [`08-DATA-SAFETY.md`](08-DATA-SAFETY.md).
- ✅ **Move / rename** real files from the UI (serialized through a file-service mutex to avoid scanner races).
- ⭐ All destructive actions are **confirmed**; nothing is deleted from disk without going through trash.

## Search & discovery

- ✅ **Search & filters** — filename (FTS5), date range, media type (photo/video), favorites, archived, camera model, has-GPS, folder/album scope.
- ⭐ **Map view** — geotagged photos plotted on a Leaflet/OpenStreetMap map with marker clustering; click a cluster to drill in. (Map tiles are the one expected network call — see [`06-PRIVACY-AND-NETWORK.md`](06-PRIVACY-AND-NETWORK.md).)
- ⭐ **"On this day" / Memories** — resurfaces media from the same calendar day in prior years.
- ⭐ **Duplicate detection** — exact dupes via `quick_hash`; optional near-dupes via perceptual hash (`phash`); grouped UI to pick keepers and trash the rest.

## On-device AI (🧪 toggle in Settings, OFF by default)

- 🧪 **Semantic search** — natural-language / object search ("beach", "dog", "birthday cake") via local **CLIP** image embeddings + `sqlite-vec` nearest-neighbor. No filenames needed.
- 🧪 **Face grouping ("People")** — local face detection + embeddings + clustering; name a cluster once and browse everyone. Names are user-editable.
- Indexing runs as a **resumable background job** in a bounded worker pool, prioritized after metadata/thumbnails, with a progress UI. Models are downloaded once to `data/models/` (or pre-placed for offline). Toggling off stops indexing and hides the views; data can be cleared. See cost notes in [`12-ROADMAP.md`](12-ROADMAP.md).

## System & settings

- ✅ **Settings UI** — edit roots/config, thumbnail sizes, grid density, theme, AI toggles, **LAN-access toggle + in-app guide**, optional access password.
- ✅ **Scan status** — live progress chip (SSE) showing files seen / added / thumbnailing remaining; manual "Rescan" button.
- ⭐ **DB backup / export** — export favorites/albums/face-names to JSON; optional **XMP sidecars** so metadata survives DB loss and travels with files. See [`08-DATA-SAFETY.md`](08-DATA-SAFETY.md).
- ⭐ **PWA installability** — installable as a desktop/mobile app; Service Worker caches the shell + thumbnails for instant repeat loads.
- ⭐ **Accessibility** — ARIA roles, focus-trapped lightbox, full keyboard support, `prefers-reduced-motion` respected.

## Explicitly deferred (🔮 — see roadmap)

- 🔮 In-app **photo editing** (crop/rotate/filters).
- 🔮 **On-the-fly transcoding** of unsupported codecs (HEVC/H.265, some MKV) — detection + graceful messaging ships first; transcode fallback later.
- 🔮 Advanced ML (scene/landmark classification, OCR text-in-image search).
- 🔮 Sharing links / collaborative albums (this is a single-user local app).
```

### `docs/05-PERFORMANCE.md`

```markdown
# 05 — Performance

The brief: **fast startup, fast thumbnails, fast video, smooth at 50k+**. This doc covers the scanner, the media pipeline, the virtualized grid, serving, and DB tuning.

> **200k-scale update (2026-06-17).** First paint already scales (SSR keyset + virtualized grid + blurhash). The work was the **backfill**: thumbnailing now runs in a **worker_threads pool** (`media/workerPool.ts` + `thumb-worker.mjs`) so all cores decode in parallel with blurhash off the main JS thread — the main thread keeps serving HTTP and owns every `better-sqlite3` write. Sized by `scan.workerCount` (0 = derive); falls back to the in-process pool if workers can't spawn (`scan.useWorkers:false` to force). The CPU-heaviest **1600px `preview` is deferred** to first lightbox open (`thumbnails.eagerPreview:false`), so a cold backfill renders ~half the pixels and reaches a full grid sooner. **`UV_THREADPOOL_SIZE`** is raised on the launch path (`start.mjs` / `start-lgallery.cmd`) so sharp's libuv pool isn't capped at 4. Failed rows get **bounded retries with backoff** (schema v3) instead of becoming permanent holes. Discovery overlaps thumbnailing (pipeline starts after the first scan batch), a boot reset reclaims crash-stranded rows, and the scan chip shows **throughput + ETA**. Target on a typical box: ~25-40 files/sec → 200k in ~1.5-2.5 h (vs ~9 h before), all background and non-blocking.

## Startup (cold → first paint)

- Opening SQLite is instant; **scanning and thumbnailing run in the background** and never block first paint.
- The timeline's first page is **SSR'd directly from the keyset query**, so the page is interactive immediately.
- Heavy/optional modules (`ffmpeg`, AI runtime) are **lazy-imported** only when first needed.
- Prepared statements are created once and reused.

## Scanner / incremental index

**Walk.** Iterative (explicit stack, never recursion) using `fs.promises.opendir`, which streams directory entries — low, bounded memory even on huge folders. Hidden/system dirs, `data/`, and non-media extensions are skipped during the walk.

**Diff (incremental).** Open a `scans` row → `scan_id`. For each file:
- not in DB → **new**: insert a stat-only row, enqueue metadata + thumbnail jobs.
- in DB, `(mtime_ms, size_bytes)` changed → **changed**: update fs fields, reset `meta_status`/`thumb_status`, re-enqueue.
- in DB, unchanged → just stamp `scan_id`.

After the walk, rows with a stale `scan_id` (in enabled, reachable roots) were **deleted on disk** → remove the row + its cached thumbnails (`scan.removeMissing`, default on). A 50k **stat-only** walk completes in seconds.

**Non-blocking.** Writes are batched in ~500-row transactions (better-sqlite3 is extremely fast), with `await new Promise(setImmediate)` between batches so the event loop stays responsive to requests.

**Date-first ordering.** EXIF date is extracted in an early, cheap pass so `taken_ms` is correct before thumbnails exist — items appear in the right place and **do not reshuffle** later. Queue priority: **metadata → thumbnails → AI**.

**Resumable.** Because pending work is recorded in `meta_status`/`thumb_status`, a restart mid-scan resumes from where it left off, **newest-first** (most-recently-taken media thumbnailed first — what you'll look at first).

**Progress.** An in-memory `scanState` (`{status, filesSeen, added, updated, removed, thumbsPending}`) is exposed via `GET /api/scan/status` (poll) and pushed over `GET /api/scan/stream` (**SSE**) to a small progress chip.

## Thumbnail + metadata pipeline

**On-demand-first + background fill.** Stat-only rows let the grid paint immediately with **blurhash** placeholders. A bounded **`worker_threads` pool** (auto-sized to CPU cores − 2) fills metadata then thumbnails. The thumbnail endpoint also **generates on miss**, prioritized to the grid's current visible range (the client posts visible-range hints), so scrolling ahead is instant even before the background fill catches up.

- **Images** (`sharp`): `.rotate()` (auto-orient from EXIF) **before** resize. Two WebP sizes: `grid` (~320px long edge, q70) and `preview` (~1600px, q80). Originals stream for full-resolution zoom.
- **Video** (`fluent-ffmpeg` + `ffmpeg-static`/`ffprobe-static`): `ffprobe` for duration + dimensions; one poster frame at ~10% of duration (skips black intros) piped into `sharp` for the same WebP sizes; optional storyboard sprite frames for hover-scrub.
- **EXIF** (`exifr`): date, GPS, make/model/lens, orientation, dimensions; uses embedded-thumbnail extraction as a fast path/fallback for formats `sharp` can't decode.

**Cache layout.** `data/thumbnails/<id % 256 as 2-hex>/<id>_<size>.webp` — sharded so no directory holds 50k flat files (Windows struggles with that). Changed files overwrite; trashed/removed media delete their shard files.

## Virtualized timeline grid (native scrollbar)

- **Pure layout math** in `lib/shared/layout.ts` (unit-tested): greedy justified rows — accumulate items until summed aspect-width exceeds container width, then scale the row to fit exactly. Insert fixed-height day/month **header rows**. Output: rows with absolute `y` and per-item `{x,y,w,h}`.
- **Windowing** (`TimelineGrid.svelte`): one tall scroll container at `totalContentHeight` so the **browser's native scrollbar** is the slider. Only rows intersecting `[scrollTop − overscan, scrollTop + viewportH + overscan]` are rendered, found by **binary search** on row `y` (O(log n)). 50k items → a few thousand rows; trivially fast. Tiles keyed by id for DOM reuse; positioned with `transform: translate3d(...)`.
- **Total-height estimate** before all dimensions load: from the `GROUP BY taken_local_day` count aggregate, estimate rows/heights; refine as real `width/height` stream in. Keeps the scrollbar proportion sane without loading 50k rows up front.
- **Floating date label**: derived from the top-most visible row's `taken_local_day`; shows briefly while scrolling.
- Re-layout is debounced via `ResizeObserver`; layout is memoized per `(containerWidth, density)`.

## Serving originals & video

- Range-aware endpoints (`/api/media/[id]/original`, `/stream`): on a `Range` header, respond `206` with `Content-Range`, `Accept-Ranges: bytes`, correct `Content-Length`, streaming `fs.createReadStream(path, {start, end})`. This is what makes `<video>` seek and start instantly.
- Thumbnails carry long-lived **immutable** `Cache-Control` keyed by `id` + `mtime` (changed files bust the cache automatically).
- `<img>` uses `decoding="async"`; the lightbox warms the `preview` size before the original.

## Video specifics

- Native-codec files (MP4 / H.264 / AAC) play instantly. `preload="metadata"` + poster from the grid thumbnail.
- Unsupported codecs (HEVC/H.265, some MKV/MOV) are **detected** (via `ffprobe` codec info stored at index time) and surfaced clearly; an on-the-fly **ffmpeg transcode fallback** is a roadmap item ([`12-ROADMAP.md`](12-ROADMAP.md)).

## Database tuning

- WAL + `synchronous=NORMAL`, `mmap_size` 256 MB, `cache_size` ~64 MB, `temp_store=MEMORY`, `busy_timeout` 5 s (see [`02-DATA-MODEL.md`](02-DATA-MODEL.md)).
- **Keyset pagination** everywhere (never `OFFSET`). Never select 50k rows to the client.
- Bulk writes in transactions; heavy/long writes happen off the request path (in the scanner / worker context).
- `wal_checkpoint(TRUNCATE)` on graceful shutdown to keep the WAL from growing unbounded.

## Client caching / PWA

- A **Service Worker** caches the app shell and thumbnail responses, giving instant repeat loads and offline browsing of already-seen thumbnails.
- The app is installable (PWA manifest).

## Timezone / date policy

- `taken_ms` comes from EXIF `DateTimeOriginal` when present (interpreted as local-at-capture; stored as UTC ms using the offset if available, else treated as wall-clock → UTC with no shift). Videos generally carry UTC metadata.
- `taken_local_day` is precomputed from `taken_ms` so grouping/headers need no runtime TZ math.
- When EXIF has no date (screenshots, downloads), fall back to file `mtime` and record `taken_source = 'mtime'` so ordering is explainable in the info panel.

## Targets (validate on the real library)

- First paint (SSR timeline) < ~300 ms after server ready.
- 50k stat-only scan: seconds. Full thumbnailing: background, resumable.
- Scroll: 60 fps with only windowed rows in the DOM; bounded memory during the initial scan.
```

### `docs/06-PRIVACY-AND-NETWORK.md`

```markdown
# 06 — Privacy & Network

**LGallery is local-first. By default, nothing leaves your machine.** No telemetry, no analytics, no crash reporting, no usage pings, no external fonts, no CDNs. This document lists **every** way the running app could touch the internet, so there are no surprises.

## The complete list of possible outbound connections

| # | What | When | Required? | Data sent |
|---|------|------|-----------|-----------|
| 1 | **OpenStreetMap map tiles** | Only when you open **Map view** | Only if you use the map | Tile coordinates (z/x/y) of the area you're viewing. No photos, no personal data. |
| 2 | **AI model weights** (Hugging Face) | **One-time**, only when you first **enable** AI features in Settings | Only if you enable AI | An HTTP GET for model files. **No personal data, no images.** Cached in `data/models/`. |
| 3 | **Reverse geocoding** (OSM Nominatim) | Only if you turn on `map.reverseGeocode` | **OFF by default** | GPS coordinates of a photo, to fetch a place name. |

Everything else is **100% local**:

- Scanning your folders, reading EXIF, computing hashes — local.
- Generating/serving thumbnails and originals — local.
- The SQLite index, search (FTS + semantic), face grouping inference — local.
- Video playback (HTTP Range streaming) — local, from your own server.

`npm install` needs the internet **once** at setup (normal for any Node project). At **runtime**, only the three items above can ever reach out.

## How each is controlled

**1. Map tiles.** The map is the only feature with an expected, ongoing external call, and only while it's on screen.
- Disable entirely: set `map.enabled = false` in `lgallery.config.json` → the Map view disappears.
- Self-host for full offline: point `map.tileUrl` at a local tile server / MBTiles. (Roadmap convenience; manual today.)
- We set a proper `User-Agent`/`Referer` and avoid hammering tile servers (clustering + caching).

**2. AI model weights.** Downloaded once when you flip the toggle, then cached locally and reused offline.
- Fully air-gapped: set `ai.modelSource = "local"` and place the model files in `data/models/` yourself → no download ever occurs.
- The download is model files only — your photos are **never** uploaded; all inference is on-device.

**3. Reverse geocoding.** Off by default; never sends anything unless you explicitly enable it. Even then it sends only coordinates, never images.

## What we deliberately do NOT do

- ❌ No telemetry / analytics / metrics of any kind.
- ❌ No error/crash reporting to any server (errors go to a **local** rotating log file, `data/lgallery.log`).
- ❌ No Google Fonts or any web-font CDN — **fonts are self-hosted/bundled**.
- ❌ No third-party JS/CSS from CDNs — all dependencies are bundled by Vite.
- ❌ No "check for updates" pings.
- ❌ No account, login-to-cloud, or sync.

## Verifying it yourself

1. Close the Map view and keep AI toggles **off**.
2. Open your browser dev-tools **Network** tab (or a tool like a local firewall/`netstat`).
3. Browse the timeline, open photos, play a video, search, organize.
4. You should see **only** requests to your own LGallery origin (`localhost`/your LAN IP). No external domains.
5. Open Map view → you'll then see requests to the OSM tile host (expected).

## Network exposure (who can reach the app)

By default the server binds to `127.0.0.1` — reachable only from the same PC. You can opt into LAN access (e.g. to view from your phone). That's a separate concern from outbound privacy and is covered, with hardening, in [`07-SECURITY.md`](07-SECURITY.md).
```

### `docs/07-SECURITY.md`

```markdown
# 07 — Security

LGallery reads and (on request) modifies real files, and can optionally be exposed on your LAN. This doc covers the protections.

## Threat model

- Single trusted user on a trusted machine is the default (localhost-only).
- When LAN access is enabled, anyone who can reach the port is, by default, as powerful as the user — including **delete**. Hence the optional password and the hardening below.
- The server must never read or write files **outside** the configured roots (and its own `data/`), regardless of crafted input.

## Path traversal prevention (primary defense)

- **Clients never send raw filesystem paths.** All media is addressed by integer `id`; the server looks up `media.path` from the DB.
- **Allow-list enforcement** (`paths.ts → assertWithinRoots`): even for internal callers, the resolved absolute path is checked to be a prefix of an enabled root (or `data/trash`), using the same normalization (forward-slash, lower-cased drive) used for storage. Anything else → `403`.
- **Symlink escape guard**: resolve `fs.realpath` and re-check the allow-list, so a symlink inside a root cannot point outside it.
- Reject UNC/drive changes, `..` segments, and null bytes defensively before resolution.

## File-mutation safety

- All move/rename/delete operations go through a single `fileService` guarded by an **in-process mutex**, so user actions can't race the scanner or each other.
- The DB row is updated in the **same logical operation** as the filesystem change; the path is re-stat'd afterward to confirm.
- **Deletes are soft** by default — files move to `data/trash` with a `trash` record; permanent deletion is a separate, explicitly-confirmed action. See [`08-DATA-SAFETY.md`](08-DATA-SAFETY.md).
- Destructive bulk actions require confirmation and show counts.

## LAN access (opt-in) + optional password

Default bind is `127.0.0.1` (this PC only). To view from your phone/other devices, enable LAN access — a Settings toggle that sets `server.host = "0.0.0.0"`. Because there's otherwise no auth, the in-app guide strongly recommends setting an **access password** at the same time.

**In-app "Enable LAN access" guide will cover:**
1. Toggle LAN access on (sets host to `0.0.0.0`) and **restart** the server.
2. Find this PC's LAN IP (`ipconfig` → IPv4) and open `http://<ip>:<port>` from your phone on the same Wi-Fi.
3. Allow the app's port through **Windows Defender Firewall** (Private networks only).
4. Set an **access password** in Settings (strongly recommended).

**Password handling:**
- Stored **hashed** at rest (argon2id or scrypt) — never plaintext.
- Login establishes a signed, `HttpOnly`, `SameSite=Lax` session cookie with a configurable TTL.
- **Rate-limiting** on the login endpoint (exponential backoff / lockout) to deter brute force.

## CSRF protection (matters once on LAN)

- All **mutating** endpoints (trash, move, rename, album edits, favorite, config/settings writes, AI/scan control) require either:
  - a same-origin check (`Origin`/`Sec-Fetch-Site`), **and**
  - a per-session CSRF token (double-submit cookie) for state-changing requests.
- GET endpoints are side-effect-free.

## Hardening details

- `data/` (DB, thumbnails, trash, models, logs) lives under the project dir and is **git-ignored** — never commit personal data.
- Originals are served with `Content-Disposition: inline` and a correct `Content-Type`; no directory listing endpoints exist.
- The DB file is opened with WAL; backups before migrations (see [`08-DATA-SAFETY.md`](08-DATA-SAFETY.md)).
- Errors are logged **locally** only (`data/lgallery.log`); no error is sent anywhere (see [`06-PRIVACY-AND-NETWORK.md`](06-PRIVACY-AND-NETWORK.md)).
- Consider OS-level scoping: run the process under a user account that only has access to the media roots if you expose it on the LAN.

## Non-goals

- This is not multi-tenant. There are no per-user permissions, roles, or sharing ACLs — a single optional password gates the whole app.
- HTTPS is out of scope for the local/LAN use case; if you must, terminate TLS with a local reverse proxy (e.g. Caddy) in front of the Node server.
```

### `docs/08-DATA-SAFETY.md`

```markdown
# 08 — Data Safety & Resilience

Some valuable data lives **only** in LGallery's database, not in your original files: favorites, archive flags, albums, tags, and face-cluster names. This doc covers protecting that data, the recoverable trash, and graceful handling of filesystem problems.

## What's at risk if the DB is lost

| Data | Lives in originals? | Recoverable from a rescan? |
|---|---|---|
| The photos/videos themselves | ✅ yes | ✅ always (LGallery never owns them) |
| Thumbnails | ❌ (derived) | ✅ regenerated automatically |
| EXIF-derived metadata (date, GPS, camera) | ✅ in the files | ✅ re-extracted on rescan |
| **Favorites / archive / albums / tags / face names** | ❌ **only in DB** | ❌ **lost unless backed up** |

So the DB is the thing worth protecting.

## Protecting DB-only data

1. **Backup-before-migrate** — before applying any schema migration, copy `lgallery.db` → `lgallery.db.bak-<schema_version>`.
2. **Manual / scheduled backup** — Settings offers "Backup database now" (copies the DB while checkpointing WAL). A simple file copy of `data/lgallery.db` while the app is stopped is also valid.
3. **JSON export / import** — export favorites, albums, tags, and face-cluster names to a portable JSON file (keyed by file path + `quick_hash` so it can be re-applied even after re-indexing on another machine).
4. **Optional XMP sidecars** — when enabled, LGallery writes favorites/tags to per-file `.xmp` sidecars next to the originals (standard, app-portable, survives DB loss). This is the most durable option and is **off by default** (it writes files next to your media).

> Recommendation: enable periodic JSON export at minimum; enable XMP sidecars if you want metadata to travel with the files and survive a full DB loss.

## Recoverable trash

- **Soft delete**: deleting media moves the file to `data/trash/<id>__<filename>` and records `{media_id, original_path, trash_path, size, trashed_at}` in the `trash` table; the media row is flagged `is_trashed = 1` (hidden from timeline/search).
- **Restore**: moves the file back to `original_path` (or a safe alternative if the original location is occupied) and clears the flag.
- **Permanent delete**: removes the file from `data/trash` and the rows; explicitly confirmed, separate action.
- **Auto-purge**: items older than `trash.autoPurgeDays` (default 30; `0` = never) are permanently removed on a periodic sweep.
- **Same-volume requirement**: `data/trash` should be on the **same drive/volume** as your roots so the move is an atomic `rename`. If a root is on a different volume, enable `trash.perRoot` (a trash beside each root) or LGallery falls back to copy-then-delete with partial-failure handling.

## Thumbnail & orphan GC

- When media rows are removed (deleted on disk, or permanently trashed), their cached thumbnail shard files are deleted too.
- A periodic **orphan GC** sweeps `data/thumbnails/` for files with no corresponding media row (e.g. after a crash mid-delete) and removes them.

## Filesystem resilience (scanner & pipeline)

The scanner must never crash a whole run because of one bad file or a flaky drive:

- **Locked / in-use files** (common on Windows): caught, recorded as `media.error`, retried on the next scan; not fatal.
- **Permission denied** (folder or file): logged, skipped, surfaced in Settings; the rest of the scan proceeds.
- **Corrupt / undecodable media**: `meta_status`/`thumb_status` set to `3` (fail) with an `error` note; the item still appears (with a generic placeholder) and can be retried.
- **Disconnected network drive / unplugged USB**: the affected `root` is marked **offline** (not "all files deleted"). Its media are retained and `removeMissing` is suppressed for that root until it's reachable again — so a temporarily-offline NAS never wipes your index.
- **Unicode / emoji / long (>260-char) paths**: handled via consistent UTF-8 + Windows long-path support; never assume ASCII.

## Logging (local only)

- A rotating log at `data/lgallery.log` (`logging.level`, `maxSizeMb`, `maxFiles`) records scans, errors, and mutations for debugging.
- Logs stay on disk; nothing is transmitted anywhere (see [`06-PRIVACY-AND-NETWORK.md`](06-PRIVACY-AND-NETWORK.md)).

## Graceful shutdown

On `SIGINT`/`SIGTERM`: stop accepting new jobs, finish/abort in-flight transactions cleanly, `PRAGMA wal_checkpoint(TRUNCATE)`, persist queue state (it's already in the DB via `*_status`), then exit. A restart resumes pending metadata/thumbnail/AI work automatically.
```

### `docs/09-API.md`

```markdown
# 09 — API Surface

All endpoints are SvelteKit `+server.ts` routes under `src/routes/api/`. Mutating endpoints require same-origin + CSRF token (and a session when a password is set) — see [`07-SECURITY.md`](07-SECURITY.md). Media is always addressed by integer `id`; raw paths never cross the wire.

## Read / browse (GET)

| Endpoint | Purpose | Notes |
|---|---|---|
| `GET /api/timeline` | Timeline page | Keyset: `?curMs=&curId=&limit=`. Returns items + next cursor. |
| `GET /api/timeline/buckets` | Day/month counts | For total-height estimate + floating date label. |
| `GET /api/folders` | Folder browser | `?dir=` (normalized); returns subfolders + media page. |
| `GET /api/albums` | List albums | With covers + counts. |
| `GET /api/albums/[id]` | Album contents | Keyset paginated. |
| `GET /api/search` | Search & filters | `?q=&from=&to=&type=&fav=&archived=&camera=&hasGps=&album=&semantic=` (FTS + optional semantic). |
| `GET /api/map/points` | Geotagged points | `?bbox=&zoom=` server-side clustered. |
| `GET /api/people` | Face clusters | When AI faces enabled. |
| `GET /api/people/[id]` | One person's media | Keyset paginated. |
| `GET /api/media/[id]` | Media detail | Full EXIF, dimensions, album membership, live-partner. |
| `GET /api/memories` | "On this day" | Same calendar day, prior years. |
| `GET /api/duplicates` | Duplicate groups | Exact (`quick_hash`) + optional near (`phash`). |

## Byte streams (GET)

| Endpoint | Purpose | Notes |
|---|---|---|
| `GET /api/media/[id]/thumb?size=grid\|preview` | Thumbnail | **Generate-on-miss**; immutable `Cache-Control` keyed by id+mtime. |
| `GET /api/media/[id]/storyboard` | Hover-scrub sprites | Optional; only if generated. |
| `GET /api/media/[id]/original` | Full-resolution file | **HTTP Range** (206) supported. |
| `GET /api/media/[id]/stream` | Video stream | **HTTP Range** required; what `<video>` uses. |

## Mutations (POST/PATCH/DELETE)

| Endpoint | Purpose |
|---|---|
| `POST /api/albums` · `PATCH /api/albums/[id]` · `DELETE /api/albums/[id]` | Album CRUD |
| `POST /api/albums/[id]/items` · `DELETE /api/albums/[id]/items` | Add/remove media (bulk id arrays) |
| `PATCH /api/media` | Bulk set favorite / archive `{ ids:[], favorite?, archived? }` |
| `POST /api/media/trash` | Soft-delete to trash `{ ids:[] }` |
| `POST /api/trash/restore` | Restore `{ ids:[] }` |
| `DELETE /api/trash` | Permanent delete `{ ids:[] }` (confirmed) |
| `POST /api/media/move` | Move files `{ ids:[], destDir }` |
| `POST /api/media/rename` | Rename `{ id, newName }` |
| `POST /api/export` | Zip selected `{ ids:[] }` → download stream |

## System (GET/PUT/POST)

| Endpoint | Purpose |
|---|---|
| `GET /api/scan/status` | Current scan progress (poll) |
| `GET /api/scan/stream` | **SSE** live scan progress |
| `POST /api/scan` | Trigger a (re)scan `{ full?: boolean }` |
| `GET /api/config` · `PUT /api/config` | Read / write `lgallery.config.json` (zod-validated; write triggers rescan) |
| `GET /api/settings` · `PUT /api/settings` | UI-only settings (theme, density, toggles) |
| `POST /api/ai/index` | Start/stop AI indexing `{ action, kind:'semantic'\|'faces' }` |
| `GET /api/ai/status` | AI index progress |
| `POST /api/backup` | Backup DB / export JSON |
| `POST /api/auth/login` · `POST /api/auth/logout` | Session (only when password set; rate-limited) |

## Conventions

- **Pagination**: keyset (`curMs`/`curId` cursors), never `OFFSET`.
- **Errors**: JSON `{ error: { code, message } }` with appropriate status; never leak filesystem paths in errors exposed to the client.
- **Bulk ops** accept `ids: number[]` and return per-id results so partial failures are visible.
- **SSE** (`/api/scan/stream`, AI status) is preferred over WebSockets for one-way progress and works cleanly with adapter-node.
```

### `docs/10-BUILD-PLAN.md`

```markdown
# 10 — Build Plan

Phased so each phase is independently runnable and the riskiest core (50k+ virtualized scroll) is proven early. Audit improvements are folded into the phase where they belong.

## P0 — Foundations
- Scaffold SvelteKit 2 + Svelte 5 + TypeScript (strict) + Tailwind v4 + `@sveltejs/adapter-node`.
- `better-sqlite3` + drizzle-orm/kit; schema + migrations; apply pragmas (WAL, mmap, cache, temp_store, busy_timeout).
- `configService` (read/validate with zod, canonical hash); `lgallery.config.example.json`.
- `paths.ts` (normalization + `assertWithinRoots` + realpath guard + thumb sharding).
- Local rotating logger; `.gitignore` for `data/`, config, `node_modules`.
- **Verify**: `better-sqlite3`, `sharp`, `ffmpeg-static`/`ffprobe-static` install/run on Windows.

## P1 — Scan / index
- `walker` (iterative `opendir`), `differ` (new/changed/unchanged + scan-id sweep), `scans` rows.
- Startup scan in `hooks.server.ts`; config-hash recheck + incremental rescan in `+layout.server.ts`.
- **Date-first pass** (extract `taken_ms` early); resilience (locked/denied/corrupt/offline-root handling).
- `GET /api/scan/status` + `GET /api/scan/stream` (SSE) + progress chip.
- **Verify**: 50k stat-only scan completes in seconds; offline NAS doesn't wipe the index.

## P2 — Media pipeline
- `worker_threads` pool (auto-sized); persistent resumable queue via `meta_status`/`thumb_status`, newest-first.
- `sharp` thumbs (orientation, grid+preview WebP, sharded cache); `exifr` metadata; `ffmpeg` poster + duration (+ optional storyboard).
- `blurhash` placeholders; generate-on-miss thumb endpoint with visible-range priority.
- **Verify**: thumbnails fill in background; scrolling ahead generates on demand instantly.

## P3 — Timeline grid (core deliverable)
- Pure justified-layout math in `lib/shared/layout.ts` + **unit tests**.
- Custom virtualization (`TimelineGrid.svelte`): tall scroll container, **native scrollbar**, binary-search windowing, translate3d, DOM reuse, debounced ResizeObserver.
- Day/month headers; total-height estimate from buckets; floating date label; keyset pagination.
- **Verify**: 60 fps scroll at 50k+; correct ordering with no reshuffle as metadata arrives.

## P4 — Lightbox & serving
- Range endpoints (`original`, `stream`); image zoom/pan; video playback; keyboard nav; slideshow.
- Info/EXIF panel; touch gestures (pinch/swipe); accessibility (focus trap, ARIA, reduced-motion).
- **Verify**: video seeks instantly; lightbox keyboard + touch complete.

## P5 — Organization
- Favorites, archive; multi-select mode + floating action bar.
- Albums CRUD + add/remove + cover; folder browser; bulk favorite/archive/add-to-album/export-zip.
- **Verify**: bulk ops correct; albums persist.

## P6 — Mutations & trash
- `fileService` (mutex-serialized) move/rename; soft-delete → `data/trash`; restore; permanent delete; auto-purge.
- Confirmations; same-volume/atomic-rename handling; orphan-thumbnail GC.
- **Verify**: delete→restore→permanent flow; move/rename reflected in DB + next scan; no scanner race.

## P7 — Discovery
- Search + filters (FTS5 + metadata); Map view (Leaflet + markercluster, lazy `onMount`); Memories; duplicate detection (quick_hash + optional phash).
- Live/Motion photo pairing + badges.
- **Verify**: search filters combine; map clusters; dupes grouped.

## P8 — AI (toggle-gated, OFF by default)
- `@huggingface/transformers` on `onnxruntime-node`; CLIP image/text embeddings → `sqlite-vec`; face detection + embeddings + clustering → People.
- Background, resumable, progress UI; models cached in `data/models/` (or local-only).
- **Verify**: semantic query returns sensible results; people cluster; toggling off stops/cleans cleanly; no network with `modelSource:"local"`.

## P9 — Polish & PWA
- Dark mode; grid density; full responsive/mobile; LAN toggle + in-app guide + optional password + CSRF + rate-limit.
- Settings UI (config editor, backup/export, XMP sidecars toggle); Service Worker + PWA manifest.
- **Verify**: full privacy check (no outbound with map closed + AI off); LAN access from phone with password works.

## Cross-cutting (every phase)
- Keep `lib/server/**` off the client bundle; pure code in `lib/shared/**`.
- Tests alongside features (see [`11-TESTING.md`](11-TESTING.md)).
- Update `.claude/memory/project-status.md` as phases complete.

## Suggested first commit boundaries
1. P0 scaffold + DB + config (runnable empty app).
2. P1 scanner (index populates, progress visible).
3. P2+P3 pipeline + grid (the gallery actually looks/scrolls like Google Photos).
4. Then P4→P9 incrementally.

## Post-build enhancement passes (done)

P0–P9 are complete. Two follow-up passes landed on top of the original plan:

**Polish / perf / feature pass.** Design-token system in `app.css` (CSS vars for color/surface/overlay/radius/shadow/motion + reusable `.lg-bar`/`.btn`/`.lg-card`/`.lg-input`) with shared `PageHeader`/`EmptyState`/`Skeleton` components; an app logo (favicon + sidebar) reflecting photos+video; **@2x HiDPI thumbnails** (`grid2x` `srcset`); **SSR'd grid layout** (`lg_w` cookie) to kill the blank-then-pop; a **buckets aggregate cache** + `idx_media_day` index (migration v2); **Live/Motion photo** playback + hover-preview; a **command palette** (Cmd/Ctrl+K) + shortcuts; **Favorites/Archive** views; **rubber-band select**; lightbox **click-outside-to-close**; **reconcileRoots** (removing a root from config deletes its media).

**Bun / watcher / canonical-roots pass.** Migrated tooling to **Bun** (`bun@1.3.14`, `bun.lock`; install/scripts/build/test orchestration) while keeping the **server runtime on Node** (`node build`; `better-sqlite3` is unsupported in the Bun runtime, [oven-sh/bun#4290](https://github.com/oven-sh/bun/issues/4290)). Dependencies bumped to latest non-vulnerable (0 advisories via `bun audit`): vite 8, vitest 4, kit 2.65, svelte 5.56, tailwindcss 4.3, typescript 6, sharp 0.35, chokidar 5 — with `zod` pinned to v3 (3.25) and a `cookie` override. Implemented the **live file watcher** (`scan/watcher.ts`, gated by `scan.watch`; debounced/batched incremental indexing); **canonical root paths** (`fs.realpathSync.native`, 8.3 expansion on Windows) + BOM-tolerant config reader; and **Windows autostart** via `start-lgallery.cmd` / `start-lgallery-hidden.vbs` plus a Settings → Startup panel.
```

### `docs/11-TESTING.md`

```markdown
# 11 — Testing Strategy

Goal: confidence in the parts most likely to break or silently corrupt — path handling, the scanner diff, the layout math, and the file-mutation flows — without over-testing UI chrome.

## Tooling

- **Vitest 4** — unit + integration (runs server modules directly). Invoke via **Bun**: `bun run test`, and `bun run test:cov` for **v8 coverage** (configured in `vite.config.ts`). The suite itself runs under Node via the vitest bin.
- **Playwright** — a small set of end-to-end smoke flows in a real browser.

There are **98 unit/integration tests**. Coverage focuses on the logic-heavy server + shared code; the **native / FS / serving layers** (`sharp`, `ffmpeg`, streaming, scanner, pipeline, `fileService`) are validated by end-to-end runtime smoke tests rather than unit tests — their singleton design and native deps make them impractical to unit-test.
- A **fixtures** folder of small, varied sample media: a normal JPEG, a portrait JPEG (EXIF orientation 6), a PNG, a geotagged JPEG, an iPhone **HEIC** (+ its Live `.mov` partner), a **RAW** (e.g. DNG), an MP4 (H.264), an HEVC MP4, and a screenshot with **no EXIF date**.

## Unit tests (highest value)

- **Path normalization** (`paths.ts`): Windows drive-letter casing, mixed `\`/`/`, trailing slashes, UNC (`//server/share`), `..` rejection, null-byte rejection, long paths. Round-trip: normalized form is stable and idempotent.
- **`assertWithinRoots`**: paths inside roots pass; sibling/parent escapes, symlink-out targets (realpath), and `data/`-only paths behave correctly.
- **Justified layout math** (`lib/shared/layout.ts`): rows fill to container width then scale to fit; last-row handling; header-row insertion on day/month change; deterministic output for a given `(width, density, items)`; binary-search row lookup returns the right window for arbitrary `scrollTop`.
- **Date policy** (`format`/exif mapping): EXIF date → `taken_ms` + `taken_local_day`; missing EXIF → mtime fallback with `taken_source='mtime'`; day boundaries.
- **Config validation** (zod): rejects empty `roots`, coerces/dedupes extensions, host enum, hash is canonical (key-order-independent).

## Integration tests (server, against a temp DB + fixtures)

- **Scanner diff**: seed a temp root → scan → assert inserts; add/modify/delete files → rescan → assert added/changed/removed counts and `scan_id` sweep; **offline root** is not swept; locked/corrupt file is recorded as error, not fatal.
- **Resumability**: interrupt after metadata but before thumbnails → restart → pending thumbnails complete; no duplicate work.
- **Thumbnail pipeline**: image orientation respected; video poster + duration extracted; sharded cache path correct; cache busts on mtime change.
- **Range serving**: `Range: bytes=...` returns 206 with correct `Content-Range`/length; no-range returns 200; traversal attempts return 403.
- **Mutations**: trash → row flagged + file in `data/trash`; restore → file back + flag cleared; permanent delete → gone; move/rename updates row in same op; mutex serializes concurrent ops.
- **Keyset pagination**: stable ordering, no gaps/dupes across pages at tie `taken_ms` values.
- **FTS search**: filename/camera matches; filters combine correctly.

## Implemented test areas

The 98 tests cover, beyond the items above:

- **Pure modules**: `paths`, `format`, `layout`, `blurhash`, `config`.
- **Server logic**: queries (incl. FTS / LIKE-escape / keyset / aggregate cache), security & auth, HTTP helpers, `scanState`, Live/Motion pairing, DB migrations, the walker, `hashService`, and `exifService` (incl. the mtime fallback).

Native/FS/serving (`sharp`, `ffmpeg`, streaming, scanner, pipeline, `fileService`) are intentionally left to runtime smoke tests (see Tooling note above).

## End-to-end (Playwright smoke)

1. Start app against a fixtures config → timeline renders; progress chip completes.
2. Scroll the grid (native scrollbar) → windowed rows update; floating date label shows.
3. Open lightbox → image zoom, video plays/seeks, keyboard next/prev, Esc closes.
4. Multi-select → favorite + add-to-album; verify persisted after reload.
5. Trash an item → it leaves timeline; restore from Trash → it returns.
6. Edit config (add a fixtures subfolder) → reload → new media appears (incremental rescan).
7. **Privacy assertion**: with map closed + AI off, intercept network → only same-origin requests.

## Performance checks (manual / scripted, against the real 50k+ library)

- 50k stat-only scan time; memory ceiling during initial scan.
- First-paint (SSR timeline) latency.
- Sustained scroll FPS; thumbnail generate-on-miss latency.

## CI note (local-first project)

CI is optional for a personal app, but the unit + integration suites are fast and deterministic (temp DB + tiny fixtures) and should run before each meaningful commit (`bun run test` / `bun run test:cov`). Native modules (`better-sqlite3`, `sharp`) and ffmpeg statics must be installable in the CI image if CI is used; note the server runs under Node even though Bun drives install/scripts.
```

### `docs/12-ROADMAP.md`

```markdown
# 12 — Roadmap (Deferred / Future)

Things intentionally **not** in the initial build, with the reasoning and a sketch of how they'd be added. The core gallery ships first; these are opt-in enhancements.

## ✅ Shipped since the initial roadmap (2026-06-17 scale & features pass)

- **In-app photo editing** — non-destructive (crop/rotate/flip + brightness/contrast/saturation/vibrance/warmth + filter presets), stored as `edit_ops` JSON, applied via sharp, with "export edited copy". See `01-ARCHITECTURE.md` / `editService`.
- **Reverse-geocoded place names** — the `/places` view, OFF by default, offline bundled-city provider or opt-in Nominatim (`config.geocode`).
- **Keyboard command palette** (⌘/Ctrl+K), **watch mode** (`scan.watch`), and a **date-jump scrubber** for huge libraries.
- **Tags / captions / ratings & culling** UI (the `tags`/`media_tags` tables now have a UI; `caption`/`rating`/`pick` added).
- **200k-scale thumbnailing** — worker_threads pool, deferred preview, bounded retry, ETA (see `05-PERFORMANCE.md`).

Still deferred below: video transcoding, advanced ML, offline map tiles, HEIC/RAW decode, comparison view, burst grouping, localization.

## On-the-fly video transcoding

**Why deferred:** most consumer video plays natively in the browser (MP4/H.264/AAC). Transcoding is CPU-heavy and complicated to do well live.
**Plan:** at index time, `ffprobe` already records the codec. The UI ships with **detection + clear messaging** for unplayable codecs (HEVC/H.265, some MKV/MOV). Later, add an on-demand `ffmpeg` transcode endpoint (segment/HLS or progressive MP4) with a small disk cache of transcoded outputs, throttled by the same worker pool. Possibly pre-transcode favorites only.

## In-app photo editing

**Why deferred:** editing mutates originals (or needs a non-destructive edit store) and is a large feature on its own.
**Plan:** non-destructive edits stored as a sidecar/DB record (crop, rotate, exposure, filters) applied via `sharp` for preview and on export; "save a copy" to write a new file. Rotate-lossless for JPEG as a quick early win.

## Advanced ML

The basic AI (CLIP semantic search + face grouping) is in P8 behind a toggle. Beyond that:
- **Scene/landmark classification**, **OCR** (search text inside images), **auto-albums** (events by time+location clustering).
- **Why deferred:** larger models, more per-image compute across 50k+, more storage. CPU inference is slow; GPU is ideal but not assumed.
- **Plan:** same pattern as P8 — opt-in, batched, resumable background jobs; embeddings/labels in SQLite; results surfaced as extra search facets.

### AI cost notes (for when these are enabled)
- CLIP embedding of 50k images on CPU can take hours (minutes-to-low-hours on GPU). It's a **one-time** background pass, resumable, newest-first; the gallery stays fully usable meanwhile.
- Face detection + embedding is heavier than CLIP (detect → align → embed → cluster). Clustering (DBSCAN/HDBSCAN over embeddings) is re-runnable as new faces arrive.
- Model weights download once (hundreds of MB) unless pre-placed for offline (`ai.modelSource: "local"`). All inference is on-device — **no images ever leave the machine** ([`06-PRIVACY-AND-NETWORK.md`](06-PRIVACY-AND-NETWORK.md)).

## Offline / self-hosted map tiles

**Why deferred:** OSM tiles work out of the box; offline tiles need setup.
**Plan:** support pointing `map.tileUrl` at a local tile server or bundled MBTiles for 100% offline map use; document a simple local tile-server recipe.

## HEIC / RAW decoding improvements

**Why deferred:** prebuilt `sharp`/libvips lacks HEIC; many RAW formats aren't decodable by libvips.
**Plan (initial):** HEIC thumbs via `heic-convert` fallback (background-queued) + EXIF via `exifr`; RAW thumbs from the embedded preview JPEG (`exifr`). **Plan (later):** ship a custom libvips built with libheif for native HEIC, and integrate a RAW developer (e.g. libraw) for true RAW rendering.

## Nice-to-haves

- **Watch mode** (`chokidar`) for instant pickup of new files without a reload (config flag already reserved: `scan.watch`).
- **Keyboard-driven command palette** (quick jump to album/date/person).
- **Comparison view** (side-by-side, for culling near-dupes).
- **Stacked/grouped bursts** (collapse rapid-fire shots).
- **Localization** of UI strings.
- **Reverse-geocoded place names** as a search facet (already a config flag, OFF by default for privacy).

## Explicit non-goals

- Cloud sync, accounts, sharing links, collaborative albums — LGallery is a **single-user, local** app by design.
- Telemetry/analytics of any kind — see [`06-PRIVACY-AND-NETWORK.md`](06-PRIVACY-AND-NETWORK.md).
```

### `lgallery.config.example.json`

```json
{
  "roots": [
    { "path": "D:/Photos", "label": "Main", "enabled": true }
  ],
  "include": ["**/*"],
  "exclude": ["**/.*", "**/@eaDir/**", "**/#recycle/**", "**/Thumbs.db"],
  "imageExtensions": [
    "jpg", "jpeg", "png", "gif", "webp", "avif", "bmp", "tiff", "tif",
    "heic", "heif", "cr2", "cr3", "nef", "arw", "dng", "raf", "orf", "rw2"
  ],
  "videoExtensions": [
    "mp4", "mov", "m4v", "webm", "mkv", "avi", "wmv", "mts", "m2ts", "3gp"
  ],
  "scan": {
    "onStartup": true,
    "rescanOnReload": true,
    "watch": false,
    "concurrency": 0,
    "removeMissing": true,
    "followSymlinks": false
  },
  "thumbnails": {
    "dir": "data/thumbnails",
    "format": "webp",
    "grid": { "longEdge": 320, "quality": 70 },
    "preview": { "longEdge": 1600, "quality": 80 },
    "videoFrameAtPercent": 10,
    "videoStoryboardFrames": 5
  },
  "trash": {
    "dir": "data/trash",
    "perRoot": false,
    "autoPurgeDays": 30
  },
  "server": {
    "host": "127.0.0.1",
    "port": 4173,
    "password": null,
    "sessionTtlHours": 168
  },
  "map": {
    "enabled": true,
    "tileUrl": "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
    "attribution": "© OpenStreetMap contributors",
    "reverseGeocode": false
  },
  "ai": {
    "semanticSearch": false,
    "faceGrouping": false,
    "modelsDir": "data/models",
    "modelSource": "huggingface",
    "device": "cpu"
  },
  "ui": {
    "theme": "system",
    "gridDensity": "comfortable",
    "startView": "timeline"
  },
  "logging": {
    "level": "info",
    "file": "data/lgallery.log",
    "maxSizeMb": 10,
    "maxFiles": 5
  }
}
```

### `package.json`

```json
{
  "name": "lgallery",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "description": "A local, self-hosted Google-Photos-style gallery built with SvelteKit + Bun. Fully private, no cloud, no telemetry.",
  "packageManager": "bun@1.3.14",
  "engines": {
    "bun": ">=1.3.0"
  },
  "overrides": {
    "cookie": "^0.7.2"
  },
  "scripts": {
    "dev": "vite dev",
    "build": "vite build",
    "preview": "vite preview",
    "start": "node start.mjs",
    "check": "svelte-kit sync && svelte-check --tsconfig ./tsconfig.json",
    "check:watch": "svelte-kit sync && svelte-check --tsconfig ./tsconfig.json --watch",
    "test": "vitest run",
    "test:cov": "vitest run --coverage",
    "test:watch": "vitest"
  },
  "dependencies": {
    "archiver": "^8.0.0",
    "better-sqlite3": "^12.11.1",
    "blurhash": "^2.0.5",
    "chokidar": "^5.0.0",
    "exifr": "^7.1.3",
    "ffmpeg-static": "^5.3.0",
    "ffprobe-static": "^3.1.0",
    "fluent-ffmpeg": "^2.1.3",
    "leaflet": "^1.9.4",
    "leaflet.markercluster": "^1.5.3",
    "sharp": "^0.35.1",
    "zod": "^3.25.76"
  },
  "devDependencies": {
    "@lucide/svelte": "^1.20.0",
    "@sveltejs/adapter-node": "^5.5.4",
    "@sveltejs/kit": "^2.65.2",
    "@sveltejs/vite-plugin-svelte": "^7.1.2",
    "@tailwindcss/vite": "^4.3.1",
    "@types/archiver": "^8.0.0",
    "@types/better-sqlite3": "^7.6.13",
    "@types/fluent-ffmpeg": "^2.1.28",
    "@types/leaflet": "^1.9.21",
    "@types/leaflet.markercluster": "^1.5.6",
    "@types/node": "^25.9.3",
    "@vitest/coverage-v8": "^4.1.9",
    "svelte": "^5.56.3",
    "svelte-check": "^4.6.0",
    "tailwindcss": "^4.3.1",
    "typescript": "^6.0.3",
    "vite": "^8.0.16",
    "vitest": "^4.1.9"
  }
}
```

### `README.md`

````markdown
# LGallery

A **local, self-hosted "Google Photos"-style gallery** for your own machine, built with **SvelteKit**. It indexes the images and videos in folders you choose, and gives you a fast, responsive, private gallery — timeline, albums, search, map, lightbox, organize/trash, and optional on-device AI search — with **no telemetry and no cloud**.

> **Status:** Implemented — phases **P0–P9** of [`docs/10-BUILD-PLAN.md`](docs/10-BUILD-PLAN.md) are built and verified (timeline, lightbox, albums, folders, search, map, memories, duplicates, organize/trash, settings, LAN/password, PWA). On-device **AI (P8) is scaffolded and OFF by default** — semantic search + face grouping are wired but require the optional heavy deps (see below). See [`.claude/memory/project-status.md`](.claude/memory/project-status.md).

---

## Why LGallery

- **Your files stay yours.** Everything runs on your PC. No account, no upload, no analytics.
- **Built for big libraries.** Designed for **50,000+** photos and videos: SQLite index, on-disk thumbnail cache, virtualized scrolling, keyset pagination.
- **Real Google Photos feel.** Date timeline, justified grid, fullscreen lightbox with zoom/pan and video, favorites, albums, multi-select bulk actions, "On this day".
- **You own the files.** Delete / move / rename real files from the UI — with a **recoverable trash**.
- **Private by default.** The only optional internet use is OpenStreetMap map tiles and a one-time AI-model download (both off until you use them). See [`docs/06-PRIVACY-AND-NETWORK.md`](docs/06-PRIVACY-AND-NETWORK.md).

## Key decisions (locked)

| Topic | Decision |
|---|---|
| Source of media | One or more root folders listed in `lgallery.config.json`, re-read on startup **and** page reload |
| Scale | 50,000+ files → SQLite index + background scan + cached thumbnails + virtualized grid |
| File mutation | Delete / move / rename allowed; deletes go to a **recoverable trash** |
| Scrollbar | **Native** browser scrollbar (no Google-style custom scrubber); optional floating date label |
| Virtualization | **Custom, dependency-free** (no `@tanstack/svelte-virtual`) |
| AI (semantic search + faces) | **Toggleable in Settings, OFF by default**, runs locally |
| Network access | **Localhost-only** by default; LAN access is a Settings toggle + guide |
| Privacy | No telemetry, no CDNs, self-hosted fonts |

## Tech stack

**Bun** (package manager + scripts + build) · SvelteKit 2 + Svelte 5 (runes) · TypeScript · Tailwind CSS v4 · `@sveltejs/adapter-node` (server runs on **Node** — `better-sqlite3` isn't supported in the Bun runtime) · `better-sqlite3` (raw prepared SQL) · `sharp` · `exifr` · `fluent-ffmpeg` + `ffmpeg-static` · `chokidar` (optional live watcher) · Leaflet (map) · optional `@huggingface/transformers` + `sqlite-vec` (AI). Full rationale in [`docs/01-ARCHITECTURE.md`](docs/01-ARCHITECTURE.md).

## Documentation

| Doc | What's inside |
|---|---|
| [`docs/01-ARCHITECTURE.md`](docs/01-ARCHITECTURE.md) | Stack, folder layout, scan, media pipeline, virtualization, serving |
| [`docs/02-DATA-MODEL.md`](docs/02-DATA-MODEL.md) | SQLite schema, indexes, hot queries |
| [`docs/03-CONFIG.md`](docs/03-CONFIG.md) | Full `lgallery.config.json` spec |
| [`docs/04-FEATURES.md`](docs/04-FEATURES.md) | Complete feature list + Google Photos parity |
| [`docs/05-PERFORMANCE.md`](docs/05-PERFORMANCE.md) | Startup, thumbnails, video, scroll, DB tuning |
| [`docs/06-PRIVACY-AND-NETWORK.md`](docs/06-PRIVACY-AND-NETWORK.md) | Exactly what touches the internet |
| [`docs/07-SECURITY.md`](docs/07-SECURITY.md) | Path traversal, CSRF, LAN password, symlink guard |
| [`docs/08-DATA-SAFETY.md`](docs/08-DATA-SAFETY.md) | DB backup/export, XMP sidecars, trash & GC |
| [`docs/09-API.md`](docs/09-API.md) | HTTP endpoint surface |
| [`docs/10-BUILD-PLAN.md`](docs/10-BUILD-PLAN.md) | Phased build order |
| [`docs/11-TESTING.md`](docs/11-TESTING.md) | Test strategy |
| [`docs/12-ROADMAP.md`](docs/12-ROADMAP.md) | Deferred / future ideas |

## Quick start

**Windows, from scratch:** double-click **`setup-lgallery.cmd`**. It installs anything missing
(Git, Bun, and Node — which hosts the server), runs `bun install`, builds the app, creates
`lgallery.config.json` pointing at your Pictures folder, and offers to start LGallery on login.
Safe to re-run. (ffmpeg is bundled, so nothing else is needed.) Then `bun run start`.

### Manual (Bun)

```bash
# 1. Install dependencies (one-time internet use) — needs Bun (https://bun.sh)
bun install

# 2. Point LGallery at your folders
cp lgallery.config.example.json lgallery.config.json
#   edit "roots" to list your photo/video folders (or use Settings → Media folders)

# 3. Run
bun run dev                    # http://localhost:5173 (Vite dev runs on Node under the hood)
# or production:
bun run build && bun run start # node start.mjs — sets UV_THREADPOOL_SIZE then runs adapter-node
#                                (honours PORT/HOST env; default 4173/127.0.0.1)

# Tests + coverage + type-check
bun run test
bun run test:cov
bun run check
```

> **Why Node runs the server:** Bun is the package manager + task runner + bundler driver, but
> `better-sqlite3` isn't supported in the Bun *runtime* yet, so the production server is launched
> with `node build`. `bun run dev/build/test` work because Vite/Vitest execute on Node.

The first launch starts a background scan; the timeline appears immediately (SSR-rendered) and fills in as thumbnails generate. With **`scan.watch`** on (Settings → Scanning), new/changed/removed files are indexed live — no manual rescan. See [`docs/05-PERFORMANCE.md`](docs/05-PERFORMANCE.md).

### Autostart on Windows login

A launcher ships with the app: **`start-lgallery.cmd`** (builds on first run, serves, opens your browser) and **`start-lgallery-hidden.vbs`** (no console window). Press <kbd>Win</kbd>+<kbd>R</kbd> → `shell:startup` → drop the file (or a shortcut) in. Details + your exact path are in **Settings → Start on Windows login**.

### Optional: on-device AI (off by default)

Semantic search and face grouping are wired but require two extra packages and a one-time model download:

```bash
bun add @huggingface/transformers sqlite-vec
#   then enable in Settings → AI (or set ai.semanticSearch / ai.faceGrouping in the config).
#   Air-gapped: place model files in data/models and set ai.modelSource = "local".
```

No images ever leave your machine — all inference is local.

> **Dev helper:** `bun scripts/gen-fixtures.mjs` generates a tiny sample library + a matching `lgallery.config.json` for trying the app out. There is also a standalone `token-usage.html` token calculator at the repo root.

## License / privacy stance

Personal, local-first software. No data leaves your machine except the clearly-scoped, optional cases in [`docs/06-PRIVACY-AND-NETWORK.md`](docs/06-PRIVACY-AND-NETWORK.md).
````

### `scripts/gen-fixtures.mjs`

```js
/**
 * Dev/test helper: generate a small, varied fixtures library (images + a video) and write
 * an lgallery.config.json pointing at it. Used for manual/smoke verification.
 *
 *   node scripts/gen-fixtures.mjs [targetDir] [port]
 */
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import sharp from 'sharp';
import ffmpeg from 'fluent-ffmpeg';
import ffmpegStatic from 'ffmpeg-static';

const target = process.argv[2] || path.join(os.tmpdir(), 'lgallery-fixtures');
const port = Number(process.argv[3] || 4188);
fs.mkdirSync(target, { recursive: true });
fs.mkdirSync(path.join(target, 'trip'), { recursive: true });

const DAY = 24 * 3600 * 1000;
const base = Date.parse('2026-01-15T12:00:00Z');

async function img(file, w, h, color, orientation, daysAgo) {
	const full = path.join(target, file);
	let s = sharp({ create: { width: w, height: h, channels: 3, background: color } });
	if (orientation) s = s.withMetadata({ orientation });
	await s.jpeg({ quality: 80 }).toFile(full);
	const t = new Date(base - daysAgo * DAY);
	fs.utimesSync(full, t, t);
}

async function png(file, w, h, color, daysAgo) {
	const full = path.join(target, file);
	await sharp({ create: { width: w, height: h, channels: 4, background: color } })
		.png()
		.toFile(full);
	const t = new Date(base - daysAgo * DAY);
	fs.utimesSync(full, t, t);
}

function video(file) {
	return new Promise((resolve, reject) => {
		if (ffmpegStatic) ffmpeg.setFfmpegPath(ffmpegStatic);
		ffmpeg()
			.input('testsrc=duration=2:size=320x240:rate=10')
			.inputFormat('lavfi')
			.outputOptions('-pix_fmt', 'yuv420p')
			.on('end', () => resolve())
			.on('error', reject)
			.save(path.join(target, file));
	});
}

console.log('Generating fixtures in', target);
await img('landscape.jpg', 1600, 1000, { r: 60, g: 120, b: 200 }, 1, 0);
await img('portrait.jpg', 1000, 1600, { r: 200, g: 90, b: 90 }, 6, 1); // EXIF orientation 6
await png('graphic.png', 1200, 1200, { r: 40, g: 180, b: 120, alpha: 1 }, 2);
await img('trip/beach.jpg', 1800, 1200, { r: 250, g: 220, b: 120 }, 1, 10);
await img('trip/sunset.jpg', 1500, 1500, { r: 240, g: 120, b: 40 }, 1, 10);
await img('trip/forest.jpg', 1200, 1800, { r: 30, g: 90, b: 50 }, 8, 30);
try {
	await video('clip.mp4');
	console.log('  + clip.mp4');
} catch (e) {
	console.log('  ! video generation skipped:', e.message);
}

const config = {
	roots: [{ path: target.replace(/\\/g, '/'), label: 'Fixtures', enabled: true }],
	server: { host: '127.0.0.1', port },
	logging: { level: 'debug', file: 'data/lgallery.log', maxSizeMb: 10, maxFiles: 5 }
};
fs.writeFileSync('lgallery.config.json', JSON.stringify(config, null, 2));
console.log('Wrote lgallery.config.json → roots:', config.roots[0].path, 'port:', port);
```

### `setup-lgallery.cmd`

```bat
@echo off
REM ============================================================================
REM  LGallery one-shot setup. Double-click to run.
REM  Installs the prerequisites it can't find (Git, Bun, Node), then installs
REM  dependencies, builds the app, creates a config if you don't have one, and
REM  offers to start it on Windows login. Safe to re-run.
REM
REM  All the real work is in setup-lgallery.ps1 (PowerShell). This wrapper just
REM  launches it with an execution policy that allows it to run.
REM ============================================================================
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup-lgallery.ps1"
echo.
pause
```

### `setup-lgallery.ps1`

```powershell
<#
  LGallery one-shot setup (Windows PowerShell 5.1+).

  1. Detects + installs missing prerequisites:
       - Git  (winget Git.Git)              - optional, for updating the app
       - Bun  (winget Oven-sh.Bun, else the official bun.sh installer) - package mgr + build
       - Node (winget OpenJS.NodeJS.LTS, else the official LTS MSI)     - runs the server
                (better-sqlite3 is unsupported in the Bun runtime, so Node hosts the server)
  2. Installs dependencies + builds the production bundle.
  3. Creates lgallery.config.json from the example if you don't have one (points at your Pictures).
  4. Offers to register autostart (a shortcut to start-lgallery-hidden.vbs in your Startup folder).

  Idempotent: re-running only does what's still needed. ffmpeg is bundled (ffmpeg-static) - nothing
  else is required to run LGallery.
#>

$ErrorActionPreference = 'Stop'
Set-Location -Path $PSScriptRoot
$failures = 0

function Write-Step($m) { Write-Host "`n==> $m" -ForegroundColor Cyan }
function Write-Ok($m)   { Write-Host "    [ok] $m" -ForegroundColor Green }
function Write-Warn2($m) { Write-Host "    [!] $m" -ForegroundColor Yellow }
function Test-Cmd($n)   { [bool](Get-Command $n -ErrorAction SilentlyContinue) }
function Update-SessionPath {
    $machine = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $user = [Environment]::GetEnvironmentVariable('Path', 'User')
    $extra = @("$env:USERPROFILE\.bun\bin", "$env:ProgramFiles\nodejs", "$env:ProgramFiles\Git\cmd")
    $env:Path = (@($machine, $user) + $extra | Where-Object { $_ }) -join ';'
}

function Install-Winget($id) {
    if (-not (Test-Cmd winget)) { return $false }
    try {
        winget install --id $id -e --source winget --accept-package-agreements --accept-source-agreements --silent
        Update-SessionPath
        return $true
    } catch {
        return $false
    }
}

Write-Host "LGallery setup" -ForegroundColor White
Write-Host "Working folder: $PSScriptRoot"
$hasWinget = Test-Cmd winget
if (-not $hasWinget) { Write-Warn2 "winget (App Installer) not found - will use official installers where possible." }

# --- Git (optional) ---------------------------------------------------------
Write-Step "Checking Git"
if (Test-Cmd git) {
    Write-Ok "Git present ($(git --version))"
} else {
    Write-Warn2 "Git not found; installing..."
    if (-not (Install-Winget 'Git.Git')) {
        Write-Warn2 "Couldn't auto-install Git. It's optional (only needed to update the app). Get it at https://git-scm.com/download/win"
    }
    if (Test-Cmd git) { Write-Ok "Git installed" }
}

# --- Bun (package manager + build) ------------------------------------------
Write-Step "Checking Bun"
if (Test-Cmd bun) {
    Write-Ok "Bun present ($(bun --version))"
} else {
    Write-Warn2 "Bun not found; installing..."
    $ok = Install-Winget 'Oven-sh.Bun'
    if (-not (Test-Cmd bun)) {
        Write-Warn2 "Falling back to the official Bun installer (bun.sh)..."
        try {
            Invoke-RestMethod -Uri 'https://bun.sh/install.ps1' | Invoke-Expression
            Update-SessionPath
        } catch {
            Write-Warn2 "Bun install failed: $($_.Exception.Message)"
        }
    }
    if (Test-Cmd bun) { Write-Ok "Bun installed ($(bun --version))" } else { Write-Warn2 "Bun is still missing." }
}

# --- Node (runs the server) -------------------------------------------------
Write-Step "Checking Node.js"
if (Test-Cmd node) {
    Write-Ok "Node present ($(node --version))"
} else {
    Write-Warn2 "Node not found; installing LTS..."
    $ok = Install-Winget 'OpenJS.NodeJS.LTS'
    if (-not (Test-Cmd node)) {
        Write-Warn2 "Falling back to the official Node LTS MSI..."
        try {
            $index = Invoke-RestMethod -Uri 'https://nodejs.org/dist/index.json'
            $lts = ($index | Where-Object { $_.lts } | Select-Object -First 1).version
            $arch = if ([Environment]::Is64BitOperatingSystem) { 'x64' } else { 'x86' }
            $msi = "node-$lts-$arch.msi"
            $url = "https://nodejs.org/dist/$lts/$msi"
            $dest = Join-Path $env:TEMP $msi
            Write-Host "    downloading $url"
            Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing
            Start-Process msiexec.exe -ArgumentList "/i `"$dest`" /qn /norestart" -Wait
            Update-SessionPath
        } catch {
            Write-Warn2 "Node install failed: $($_.Exception.Message). Get it at https://nodejs.org/"
        }
    }
    if (Test-Cmd node) { Write-Ok "Node installed ($(node --version))" } else { Write-Warn2 "Node is still missing." }
}

if (-not (Test-Cmd node)) {
    Write-Warn2 "Node is required to run the server. Install it and re-run this script."
    $failures++
}

# --- Install dependencies + build -------------------------------------------
$pm = if (Test-Cmd bun) { 'bun' } elseif (Test-Cmd npm) { 'npm' } else { $null }
if (-not $pm) {
    Write-Warn2 "Neither Bun nor npm is available - cannot install dependencies. Install Bun and re-run."
    $failures++
} else {
    Write-Step "Installing dependencies with $pm"
    try {
        & $pm install
        if ($LASTEXITCODE -ne 0) { throw "$pm install exited $LASTEXITCODE" }
        Write-Ok "Dependencies installed"
    } catch {
        Write-Warn2 "Dependency install failed: $($_.Exception.Message)"
        $failures++
    }

    Write-Step "Building the production bundle ($pm run build)"
    try {
        & $pm run build
        if ($LASTEXITCODE -ne 0) { throw "$pm run build exited $LASTEXITCODE" }
        Write-Ok "Build complete (build\index.js)"
    } catch {
        Write-Warn2 "Build failed: $($_.Exception.Message)"
        $failures++
    }
}

# --- Config -----------------------------------------------------------------
Write-Step "Checking configuration"
$cfgPath = Join-Path $PSScriptRoot 'lgallery.config.json'
if (Test-Path $cfgPath) {
    Write-Ok "lgallery.config.json already exists (left untouched)"
} else {
    $defaultPics = Join-Path $env:USERPROFILE 'Pictures'
    $answer = Read-Host "Path to your photos folder [$defaultPics]"
    if ([string]::IsNullOrWhiteSpace($answer)) { $answer = $defaultPics }
    $root = ($answer -replace '\\', '/')
    $cfg = [ordered]@{
        roots   = @(@{ path = $root; label = 'Pictures'; enabled = $true })
        scan    = @{ watch = $true }
        server  = @{ host = '127.0.0.1'; port = 4173 }
    }
    ($cfg | ConvertTo-Json -Depth 6) | Set-Content -Path $cfgPath -Encoding utf8
    Write-Ok "Wrote lgallery.config.json pointing at $root"
}

# --- Autostart --------------------------------------------------------------
Write-Step "Start on Windows login"
$vbs = Join-Path $PSScriptRoot 'start-lgallery-hidden.vbs'
if (Test-Path $vbs) {
    $ans = Read-Host "Start LGallery automatically when you log in? (y/N)"
    if ($ans -match '^(y|yes)$') {
        try {
            $startup = [Environment]::GetFolderPath('Startup')
            $lnk = Join-Path $startup 'LGallery.lnk'
            $ws = New-Object -ComObject WScript.Shell
            $sc = $ws.CreateShortcut($lnk)
            $sc.TargetPath = (Get-Command wscript.exe).Source
            $sc.Arguments = "`"$vbs`""
            $sc.WorkingDirectory = $PSScriptRoot
            $sc.Description = 'Start LGallery (hidden)'
            $sc.Save()
            Write-Ok "Autostart registered: $lnk"
        } catch {
            Write-Warn2 "Couldn't register autostart: $($_.Exception.Message)"
        }
    } else {
        Write-Host "    Skipped. You can add start-lgallery-hidden.vbs to shell:startup later."
    }
}

# --- Summary ----------------------------------------------------------------
$port = 4173
try { $port = (Get-Content $cfgPath -Raw | ConvertFrom-Json).server.port } catch {}
Write-Host ""
if ($failures -eq 0) {
    Write-Host "All set. Start LGallery with:  bun run start   (or double-click start-lgallery.cmd)" -ForegroundColor Green
    Write-Host "Then open:  http://127.0.0.1:$port/" -ForegroundColor Green
    exit 0
} else {
    Write-Host "Setup finished with $failures problem(s) above - resolve them and re-run." -ForegroundColor Yellow
    exit 1
}
```

### `src/ambient.d.ts`

```ts
// Ambient declarations for untyped dependencies.

declare module 'ffprobe-static' {
	const ffprobe: { path: string };
	export default ffprobe;
}
```

### `src/app.css`

```css
@import 'tailwindcss';

/* Dark mode driven by a `.dark` class on <html> (set by the settings store),
   not the OS media query, so the in-app theme toggle is authoritative. */
@custom-variant dark (&:where(.dark, .dark *));

@theme {
	/* Self-hosted / system font stack only — no web-font CDN (privacy). */
	--font-sans:
		ui-sans-serif, system-ui, -apple-system, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif,
		'Apple Color Emoji', 'Segoe UI Emoji';
}

/* ---------------------------------------------------------------------------
   Design tokens. Components read these via var(--lg-*) so colour/spacing/radius/
   shadow/motion live in one place and adapt to the theme.
   --------------------------------------------------------------------------- */
:root {
	color-scheme: light dark;

	--lg-accent: #2563eb;
	--lg-accent-hi: #3b82f6;
	--lg-accent-weak: rgb(37 99 235 / 0.1);
	--lg-accent-text: #ffffff;
	--lg-danger: #dc2626;
	--lg-fav: #facc15;

	--lg-bg: #ffffff;
	--lg-surface: #ffffff;
	--lg-surface-2: #f3f4f6;
	--lg-surface-hover: rgb(0 0 0 / 0.05);
	--lg-border: rgb(0 0 0 / 0.1);
	--lg-text: #111827;
	--lg-text-muted: #6b7280;

	/* Dark, translucent overlay surface used by floating toasts/bars + the lightbox,
	   in BOTH themes (an intentional photo-viewer convention). */
	--lg-overlay-bg: rgb(20 22 28 / 0.92);
	--lg-overlay-text: #f3f4f6;
	--lg-overlay-muted: #9ca3af;
	--lg-overlay-hover: rgb(255 255 255 / 0.14);
	--lg-overlay-border: rgb(255 255 255 / 0.1);

	--lg-r-sm: 6px;
	--lg-r-md: 10px;
	--lg-r-lg: 14px;
	--lg-r-xl: 20px;

	--lg-shadow-1: 0 1px 2px rgb(0 0 0 / 0.06), 0 1px 3px rgb(0 0 0 / 0.08);
	--lg-shadow-2: 0 6px 18px rgb(0 0 0 / 0.12);
	--lg-shadow-3: 0 16px 40px rgb(0 0 0 / 0.22);

	--lg-dur-fast: 120ms;
	--lg-dur-base: 220ms;
	--lg-ease: cubic-bezier(0.2, 0, 0, 1);
}

:where(.dark) {
	--lg-accent-weak: rgb(59 130 246 / 0.18);
	--lg-bg: #0a0a0a;
	--lg-surface: #161616;
	--lg-surface-2: #202020;
	--lg-surface-hover: rgb(255 255 255 / 0.07);
	--lg-border: rgb(255 255 255 / 0.12);
	--lg-text: #f5f5f5;
	--lg-text-muted: #9ca3af;
	--lg-shadow-1: 0 1px 2px rgb(0 0 0 / 0.4);
	--lg-shadow-2: 0 6px 18px rgb(0 0 0 / 0.5);
	--lg-shadow-3: 0 16px 40px rgb(0 0 0 / 0.6);
}

html,
body {
	height: 100%;
}

body {
	background: var(--lg-bg);
	color: var(--lg-text);
	-webkit-font-smoothing: antialiased;
	font-family: var(--font-sans);
	overscroll-behavior-y: none;
}

/* Native, but unobtrusive, scrollbars (the timeline keeps the native scrollbar by design). */
* {
	scrollbar-width: thin;
	scrollbar-color: var(--lg-border) transparent;
}
*::-webkit-scrollbar {
	width: 12px;
	height: 12px;
}
*::-webkit-scrollbar-thumb {
	background: var(--lg-border);
	border-radius: 9999px;
	border: 3px solid transparent;
	background-clip: padding-box;
}
*::-webkit-scrollbar-thumb:hover {
	background: var(--lg-text-muted);
	background-clip: padding-box;
}

/* ---------------------------------------------------------------------------
   Reusable component classes (DRY the chrome across pages).
   --------------------------------------------------------------------------- */
@layer components {
	/* Frosted page-header bar */
	.lg-bar {
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: 12px;
		padding: 12px 18px;
		flex-shrink: 0;
		border-bottom: 1px solid var(--lg-border);
		background: color-mix(in srgb, var(--lg-bg) 78%, transparent);
		backdrop-filter: blur(10px);
		-webkit-backdrop-filter: blur(10px);
	}

	.btn {
		display: inline-flex;
		align-items: center;
		gap: 6px;
		padding: 8px 12px;
		border-radius: var(--lg-r-md);
		border: 1px solid var(--lg-border);
		background: transparent;
		color: var(--lg-text);
		cursor: pointer;
		font-size: 0.88rem;
		font-weight: 500;
		text-decoration: none;
		transition:
			background var(--lg-dur-fast) var(--lg-ease),
			border-color var(--lg-dur-fast) var(--lg-ease),
			transform var(--lg-dur-fast) var(--lg-ease),
			filter var(--lg-dur-fast) var(--lg-ease);
	}
	.btn:hover {
		background: var(--lg-surface-hover);
	}
	.btn:active {
		transform: translateY(1px);
	}
	.btn:disabled {
		opacity: 0.55;
		cursor: default;
		transform: none;
	}
	.btn-primary {
		background: var(--lg-accent);
		border-color: var(--lg-accent);
		color: var(--lg-accent-text);
	}
	.btn-primary:hover {
		background: var(--lg-accent);
		filter: brightness(1.08);
	}
	.btn-ghost {
		border-color: transparent;
	}
	.btn-danger:hover {
		background: var(--lg-danger);
		border-color: var(--lg-danger);
		color: #fff;
	}

	.lg-card {
		background: var(--lg-surface);
		border: 1px solid var(--lg-border);
		border-radius: var(--lg-r-lg);
	}

	.lg-input {
		padding: 8px 11px;
		border-radius: var(--lg-r-md);
		border: 1px solid var(--lg-border);
		background: var(--lg-bg);
		color: var(--lg-text);
		font-size: 0.9rem;
	}
	.lg-input:focus-visible {
		outline: none;
		border-color: var(--lg-accent);
		box-shadow: 0 0 0 3px var(--lg-accent-weak);
	}

	/* Consistent keyboard focus ring */
	.lg-ring:focus-visible {
		outline: none;
		box-shadow:
			0 0 0 2px var(--lg-bg),
			0 0 0 4px var(--lg-accent);
	}

	/* Shimmer skeleton */
	.lg-skeleton {
		position: relative;
		overflow: hidden;
		background: var(--lg-surface-2);
	}
	.lg-skeleton::after {
		content: '';
		position: absolute;
		inset: 0;
		transform: translateX(-100%);
		background: linear-gradient(
			90deg,
			transparent,
			color-mix(in srgb, var(--lg-text) 8%, transparent),
			transparent
		);
		animation: lg-shimmer 1.3s infinite;
	}
}

@keyframes lg-shimmer {
	100% {
		transform: translateX(100%);
	}
}

@media (prefers-reduced-motion: reduce) {
	*,
	*::before,
	*::after {
		animation-duration: 0.001ms !important;
		animation-iteration-count: 1 !important;
		transition-duration: 0.001ms !important;
		scroll-behavior: auto !important;
	}
	.lg-skeleton::after {
		display: none;
	}
}
```

### `src/app.d.ts`

```ts
// See https://svelte.dev/docs/kit/types#app.d.ts

declare global {
	namespace App {
		interface Error {
			code?: string;
			message: string;
		}
		interface Locals {
			/** Set by hooks when a password is configured and the session is valid. */
			authed: boolean;
			/** Per-session CSRF token (double-submit cookie). */
			csrfToken: string;
		}
		interface PageData {}
		interface PageState {}
		interface Platform {}
	}
}

export {};
```

### `src/app.html`

```html
<!doctype html>
<html lang="en">
	<head>
		<meta charset="utf-8" />
		<link rel="icon" href="%sveltekit.assets%/favicon.svg" />
		<link rel="manifest" href="%sveltekit.assets%/manifest.webmanifest" />
		<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover" />
		<meta name="theme-color" content="#111827" />
		<meta name="referrer" content="no-referrer" />
		<script>
			// No-FOUC theme: apply the saved/system theme before first paint. Local-only.
			try {
				var t = localStorage.getItem('lg.theme') || 'system';
				var dark =
					t === 'dark' ||
					(t === 'system' && window.matchMedia('(prefers-color-scheme: dark)').matches);
				if (dark) document.documentElement.classList.add('dark');
			} catch (e) {}
			// Record the viewport width so the server can lay out the timeline grid during SSR
			// (avoids the blank-then-pop first paint). Refreshed on resize.
			try {
				var setW = function () {
					document.cookie = 'lg_w=' + window.innerWidth + ';path=/;max-age=31536000;samesite=lax';
				};
				setW();
				var wt;
				addEventListener('resize', function () {
					clearTimeout(wt);
					wt = setTimeout(setW, 300);
				});
			} catch (e) {}
		</script>
		%sveltekit.head%
	</head>
	<body data-sveltekit-preload-data="hover">
		<div style="display: contents">%sveltekit.body%</div>
	</body>
</html>
```

### `src/hooks.server.ts`

```ts
import type { Handle, HandleServerError } from '@sveltejs/kit';
import { randomUUID } from 'node:crypto';
import { ensureStarted } from '$server/startup';
import { passwordHash } from '$server/config/configService';
import { sessionTokenFor, timingSafeStrEqual } from '$server/security';
import { log } from '$server/log';

ensureStarted().catch(() => {
	/* logged inside ensureStarted; the handle hook retries on the first request */
});

export const handle: Handle = async ({ event, resolve }) => {
	await ensureStarted();

	// CSRF double-submit token (readable cookie so the client can echo it back).
	let csrf = event.cookies.get('lg_csrf');
	if (!csrf) {
		csrf = randomUUID();
		event.cookies.set('lg_csrf', csrf, { path: '/', httpOnly: false, sameSite: 'lax', secure: false });
	}
	event.locals.csrfToken = csrf;

	// Auth: when a password is configured, gate the whole app behind a session cookie.
	const hash = passwordHash();
	if (!hash) {
		event.locals.authed = true;
	} else {
		event.locals.authed = timingSafeStrEqual(event.cookies.get('lg_session') ?? '', sessionTokenFor(hash));
		if (!event.locals.authed) {
			const path = event.url.pathname;
			const isAuthRoute = path === '/login' || path.startsWith('/api/auth/');
			if (!isAuthRoute) {
				if (path.startsWith('/api')) {
					return new Response(JSON.stringify({ error: { code: 'AUTH', message: 'Authentication required.' } }), {
						status: 401,
						headers: { 'content-type': 'application/json' }
					});
				}
				return new Response(null, { status: 303, headers: { location: '/login' } });
			}
		}
	}

	return resolve(event);
};

export const handleError: HandleServerError = ({ error, event }) => {
	log.error(`Unhandled error on ${event.url.pathname}`, error);
	return { code: 'INTERNAL', message: 'An internal error occurred.' };
};
```

### `src/lib/client/api.ts`

```ts
/**
 * Thin client API wrapper. GETs are plain; mutations attach the CSRF double-submit token
 * (read from the readable `lg_csrf` cookie). Errors surface the server's JSON message.
 */
import type {
	TimelinePage,
	DayBucket,
	MediaDetail,
	Cursor,
	Album,
	TrashItem,
	MapCluster,
	DuplicateGroup,
	BulkResult,
	Tag,
	PlaceGroup
} from '$shared/types';

function csrfToken(): string {
	if (typeof document === 'undefined') return '';
	const m = document.cookie.match(/(?:^|;\s*)lg_csrf=([^;]+)/);
	return m ? decodeURIComponent(m[1]) : '';
}

async function getJSON<T>(url: string): Promise<T> {
	const r = await fetch(url);
	if (!r.ok) throw new Error(`Request failed (${r.status})`);
	return r.json() as Promise<T>;
}

async function send<T>(method: string, url: string, body?: unknown): Promise<T> {
	const r = await fetch(url, {
		method,
		headers: { 'content-type': 'application/json', 'x-csrf-token': csrfToken() },
		body: body === undefined ? undefined : JSON.stringify(body)
	});
	if (!r.ok) {
		let msg = `Request failed (${r.status})`;
		try {
			const e = await r.json();
			if (e?.error?.message) msg = e.error.message;
		} catch {
			/* keep default */
		}
		throw new Error(msg);
	}
	return (r.status === 204 ? undefined : await r.json()) as T;
}

export const api = {
	timeline(cursor?: Cursor | null, limit = 200): Promise<TimelinePage> {
		const p = new URLSearchParams();
		if (cursor) {
			p.set('curMs', String(cursor.curMs));
			p.set('curId', String(cursor.curId));
		}
		p.set('limit', String(limit));
		return getJSON(`/api/timeline?${p.toString()}`);
	},
	buckets(): Promise<{ buckets: DayBucket[]; total: number }> {
		return getJSON('/api/timeline/buckets');
	},
	detail(id: number): Promise<MediaDetail> {
		return getJSON(`/api/media/${id}`);
	},
	reportVisible(ids: number[]): Promise<void> {
		return send('POST', '/api/timeline/visible', { ids });
	},
	rescan(full = false): Promise<{ ok: boolean }> {
		return send('POST', '/api/scan', { full });
	},

	// Organization / mutations
	setFlags(
		ids: number[],
		patch: { favorite?: boolean; archived?: boolean; rating?: number; pick?: number }
	): Promise<BulkResult> {
		return send('PATCH', '/api/media', { ids, ...patch });
	},

	// Caption / rating / pick (single item) — returns the refreshed detail.
	updateMedia(id: number, patch: { caption?: string | null; rating?: number; pick?: number }): Promise<MediaDetail> {
		return send('PATCH', `/api/media/${id}`, patch);
	},

	// Non-destructive edits (photos). PUT applies, DELETE reverts, POST exports a full-res copy.
	editMedia(id: number, ops: Partial<import('$shared/edits').EditOps>): Promise<MediaDetail> {
		return send('PUT', `/api/media/${id}/edit`, ops);
	},
	revertEdits(id: number): Promise<MediaDetail> {
		return send('DELETE', `/api/media/${id}/edit`);
	},
	exportEdited(id: number, ops: Partial<import('$shared/edits').EditOps>): Promise<{ ok: boolean; path: string }> {
		return send('POST', `/api/media/${id}/edit`, ops);
	},

	// Tags
	tags(): Promise<{ tags: Tag[] }> {
		return getJSON('/api/tags');
	},
	createTag(name: string): Promise<Tag> {
		return send('POST', '/api/tags', { name });
	},
	deleteTag(id: number): Promise<{ ok: boolean }> {
		return send('DELETE', `/api/tags/${id}`);
	},
	addMediaTag(id: number, tag: { tagId?: number; name?: string }): Promise<{ tags: { id: number; name: string }[] }> {
		return send('POST', `/api/media/${id}/tags`, tag);
	},
	removeMediaTag(id: number, tagId: number): Promise<{ tags: { id: number; name: string }[] }> {
		return send('DELETE', `/api/media/${id}/tags`, { tagId });
	},
	trash(ids: number[]): Promise<BulkResult> {
		return send('POST', '/api/media/trash', { ids });
	},
	restore(ids: number[]): Promise<BulkResult> {
		return send('POST', '/api/trash/restore', { ids });
	},
	permanentDelete(ids: number[]): Promise<BulkResult> {
		return send('DELETE', '/api/trash', { ids });
	},
	listTrash(): Promise<{ items: TrashItem[] }> {
		return getJSON('/api/trash');
	},
	move(ids: number[], destDir: string): Promise<BulkResult> {
		return send('POST', '/api/media/move', { ids, destDir });
	},
	rename(id: number, newName: string): Promise<{ ok: boolean }> {
		return send('POST', '/api/media/rename', { id, newName });
	},

	// Albums
	albums(): Promise<{ albums: Album[] }> {
		return getJSON('/api/albums');
	},
	album(id: number, cursor?: Cursor | null): Promise<{ album: Album; page: TimelinePage }> {
		const p = new URLSearchParams();
		if (cursor) {
			p.set('curMs', String(cursor.curMs));
			p.set('curId', String(cursor.curId));
		}
		return getJSON(`/api/albums/${id}?${p.toString()}`);
	},
	createAlbum(name: string): Promise<Album> {
		return send('POST', '/api/albums', { name });
	},
	updateAlbum(id: number, patch: { name?: string; coverMediaId?: number }): Promise<{ ok: boolean }> {
		return send('PATCH', `/api/albums/${id}`, patch);
	},
	deleteAlbum(id: number): Promise<{ ok: boolean }> {
		return send('DELETE', `/api/albums/${id}`);
	},
	addToAlbum(id: number, ids: number[]): Promise<BulkResult> {
		return send('POST', `/api/albums/${id}/items`, { ids });
	},
	removeFromAlbum(id: number, ids: number[]): Promise<BulkResult> {
		return send('DELETE', `/api/albums/${id}/items`, { ids });
	},

	// Discovery
	search(
		filters: {
			q?: string;
			type?: string;
			fav?: boolean;
			archived?: boolean;
			hasGps?: boolean;
			from?: number;
			to?: number;
			camera?: string;
			tag?: number;
			rating?: number;
			pick?: number;
			place?: string;
			curMs?: number | null;
			curId?: number | null;
		} = {}
	): Promise<TimelinePage> {
		const p = new URLSearchParams();
		if (filters.q) p.set('q', filters.q);
		if (filters.type) p.set('type', filters.type);
		if (filters.fav) p.set('fav', '1');
		if (filters.archived) p.set('archived', '1');
		if (filters.hasGps) p.set('hasGps', '1');
		if (filters.from != null) p.set('from', String(filters.from));
		if (filters.to != null) p.set('to', String(filters.to));
		if (filters.camera) p.set('camera', filters.camera);
		if (filters.tag != null) p.set('tag', String(filters.tag));
		if (filters.rating != null) p.set('rating', String(filters.rating));
		if (filters.pick != null) p.set('pick', String(filters.pick));
		if (filters.place) p.set('place', filters.place);
		if (filters.curMs != null) p.set('curMs', String(filters.curMs));
		if (filters.curId != null) p.set('curId', String(filters.curId));
		return getJSON(`/api/search?${p.toString()}`);
	},
	places(): Promise<{ enabled: boolean; places: PlaceGroup[] }> {
		return getJSON('/api/places');
	},
	memories(): Promise<{ today: string; groups: { year: string; items: import('$shared/types').TimelineItem[] }[] }> {
		return getJSON('/api/memories');
	},
	mapPoints(bbox: string, zoom: number): Promise<{ clusters: MapCluster[] }> {
		return getJSON(`/api/map/points?bbox=${encodeURIComponent(bbox)}&zoom=${zoom}`);
	},
	duplicates(): Promise<{ groups: DuplicateGroup[] }> {
		return getJSON('/api/duplicates');
	},

	exportZipUrl(ids: number[]): string {
		return `/api/export?ids=${ids.join(',')}`;
	},

	// Config / settings / backup
	getConfig(): Promise<Record<string, unknown>> {
		return getJSON('/api/config');
	},
	saveConfig(cfg: Record<string, unknown>): Promise<{ ok: boolean; rescan: boolean }> {
		return send('PUT', '/api/config', cfg);
	},
	backupDb(): Promise<{ ok: boolean; file: string }> {
		return send('POST', '/api/backup', {});
	},
	logout(): Promise<{ ok: boolean }> {
		return send('POST', '/api/auth/logout');
	}
};
```

### `src/lib/client/blurhash-img.ts`

```ts
/**
 * Decode a blurhash to a tiny data-URL for a real blur-up placeholder (browser-only; memoized).
 * Falls back to null on the server or on any failure (callers use the average colour then).
 */
import { decode } from 'blurhash';
import { browser } from '$app/environment';

const cache = new Map<string, string | null>();
const W = 32;
const H = 32;

export function blurhashDataURL(hash: string | null | undefined): string | null {
	if (!browser || !hash || hash.length < 6) return null;
	const hit = cache.get(hash);
	if (hit !== undefined) return hit;
	let url: string | null = null;
	try {
		const pixels = decode(hash, W, H);
		const canvas = document.createElement('canvas');
		canvas.width = W;
		canvas.height = H;
		const ctx = canvas.getContext('2d');
		if (ctx) {
			const img = ctx.createImageData(W, H);
			img.data.set(pixels);
			ctx.putImageData(img, 0, 0);
			url = canvas.toDataURL('image/webp', 0.5);
		}
	} catch {
		url = null;
	}
	// Bound the cache so a huge scroll session can't grow it without limit.
	if (cache.size > 2000) cache.clear();
	cache.set(hash, url);
	return url;
}
```

### `src/lib/client/state/gallery.svelte.ts`

```ts
/**
 * The active view's media list + keyset pagination. A single shared instance backs whichever
 * view is on screen (timeline / album / folder / search); each page calls `setSource()` with the
 * appropriate fetcher and seeds the first page. Shared so the lightbox + selection bar operate
 * on the current list.
 */
import type { TimelineItem, TimelinePage, Cursor } from '$shared/types';
import { api } from '../api';

type Fetcher = (cursor: Cursor | null) => Promise<TimelinePage>;

class MediaList {
	items = $state<TimelineItem[]>([]);
	cursor = $state<Cursor | null>(null);
	loading = $state(false);
	done = $state(false);
	error = $state<string | null>(null);
	total = $state(0);
	#fetcher: Fetcher = (c) => api.timeline(c);
	#lastErrorAt = 0;

	/** Switch the data source (timeline / album / folder / search) and reset state. */
	setSource(fetcher: Fetcher) {
		this.#fetcher = fetcher;
		this.items = [];
		this.cursor = null;
		this.done = false;
		this.error = null;
		this.total = 0;
	}

	seed(page: TimelinePage, total = 0) {
		this.items = page.items;
		this.cursor = page.nextCursor;
		this.done = !page.nextCursor;
		if (total) this.total = total;
	}

	async loadMore(): Promise<void> {
		if (this.loading || this.done) return;
		// Back off after a failure so a scroll handler can't hammer a failing endpoint forever.
		if (this.error && Date.now() - this.#lastErrorAt < 5000) return;
		this.loading = true;
		try {
			const page = await this.#fetcher(this.cursor);
			const seen = new Set(this.items.map((i) => i.id));
			this.items = [...this.items, ...page.items.filter((i) => !seen.has(i.id))];
			this.cursor = page.nextCursor;
			this.done = !page.nextCursor;
			this.error = null;
		} catch (e) {
			this.error = e instanceof Error ? e.message : 'Failed to load more';
			this.#lastErrorAt = Date.now();
		} finally {
			this.loading = false;
		}
	}

	indexOf(id: number): number {
		return this.items.findIndex((i) => i.id === id);
	}

	patchFlags(ids: number[] | Set<number>, patch: Partial<TimelineItem>) {
		const set = ids instanceof Set ? ids : new Set(ids);
		this.items = this.items.map((it) => (set.has(it.id) ? { ...it, ...patch } : it));
	}

	/** Update a single item's dimensions (e.g. after a crop changes its aspect ratio). */
	patchDims(id: number, width: number | null, height: number | null) {
		this.items = this.items.map((it) => (it.id === id ? { ...it, width, height } : it));
	}

	remove(ids: number[] | Set<number>) {
		const set = ids instanceof Set ? ids : new Set(ids);
		this.items = this.items.filter((it) => !set.has(it.id));
	}
}

export const gallery = new MediaList();
```

### `src/lib/client/state/scanStatus.svelte.ts`

```ts
/** Subscribes to the scan-progress SSE stream and exposes a reactive ScanState. */
import { browser } from '$app/environment';
import type { ScanState } from '$shared/types';

const INITIAL: ScanState = {
	status: 'idle',
	scanId: null,
	filesSeen: 0,
	added: 0,
	updated: 0,
	removed: 0,
	metaPending: 0,
	thumbsPending: 0,
	throughputPerSec: 0,
	etaMs: null,
	startedAt: null,
	finishedAt: null,
	error: null,
	currentRoot: null
};

class ScanStatusStore {
	state = $state<ScanState>({ ...INITIAL });
	#es: EventSource | null = null;

	start() {
		if (!browser || this.#es) return;
		this.#es = new EventSource('/api/scan/stream');
		this.#es.addEventListener('scan', (e) => {
			try {
				this.state = JSON.parse((e as MessageEvent).data) as ScanState;
			} catch {
				/* ignore malformed frame */
			}
		});
		this.#es.onerror = () => {
			// EventSource auto-reconnects; nothing to do.
		};
	}

	stop() {
		this.#es?.close();
		this.#es = null;
	}

	get active(): boolean {
		const s = this.state;
		return s.status === 'running' || s.metaPending > 0 || s.thumbsPending > 0;
	}
}

export const scanStatus = new ScanStatusStore();
```

### `src/lib/client/state/selection.svelte.ts`

```ts
/** Multi-select state for bulk actions (favorite/archive/album/move/trash/export). */
class SelectionStore {
	selecting = $state(false);
	ids = $state<Set<number>>(new Set());
	/** Anchor for shift-range selection (an index into the ordered id list). */
	anchorId = $state<number | null>(null);

	get count(): number {
		return this.ids.size;
	}

	enter() {
		this.selecting = true;
	}

	toggle(id: number) {
		const s = new Set(this.ids);
		if (s.has(id)) s.delete(id);
		else s.add(id);
		this.ids = s;
		this.anchorId = id;
		this.selecting = true;
	}

	/** Shift-select a contiguous range within the given ordered id list. */
	selectRange(orderedIds: number[], toId: number) {
		const from = this.anchorId ?? toId;
		const a = orderedIds.indexOf(from);
		const b = orderedIds.indexOf(toId);
		if (a === -1 || b === -1) {
			this.toggle(toId);
			return;
		}
		const [lo, hi] = a <= b ? [a, b] : [b, a];
		const s = new Set(this.ids);
		for (let i = lo; i <= hi; i++) s.add(orderedIds[i]);
		this.ids = s;
		this.selecting = true;
	}

	selectAll(ids: number[]) {
		this.ids = new Set(ids);
		this.selecting = ids.length > 0;
		// Anchor the next shift-range to the end of this set, not a stale earlier toggle.
		this.anchorId = ids.length ? ids[ids.length - 1] : null;
	}

	clear() {
		this.ids = new Set();
		this.selecting = false;
		this.anchorId = null;
	}

	has(id: number): boolean {
		return this.ids.has(id);
	}
}

export const selection = new SelectionStore();
```

### `src/lib/client/state/settings.svelte.ts`

```ts
/** Client UI settings (theme, grid density) — runes-based, persisted to localStorage. */
import { browser } from '$app/environment';
import type { Theme, GridDensity } from '$shared/types';

class SettingsStore {
	theme = $state<Theme>('system');
	density = $state<GridDensity>('comfortable');

	constructor() {
		if (!browser) return;
		const t = localStorage.getItem('lg.theme') as Theme | null;
		const d = localStorage.getItem('lg.density') as GridDensity | null;
		if (t === 'light' || t === 'dark' || t === 'system') this.theme = t;
		if (d === 'compact' || d === 'comfortable' || d === 'spacious') this.density = d;
		this.apply();
		window
			.matchMedia('(prefers-color-scheme: dark)')
			.addEventListener('change', () => this.apply());
	}

	setTheme(t: Theme) {
		this.theme = t;
		if (browser) {
			localStorage.setItem('lg.theme', t);
			this.apply();
		}
	}

	cycleTheme() {
		this.setTheme(this.theme === 'light' ? 'dark' : this.theme === 'dark' ? 'system' : 'light');
	}

	setDensity(d: GridDensity) {
		this.density = d;
		if (browser) localStorage.setItem('lg.density', d);
	}

	apply() {
		if (!browser) return;
		const dark =
			this.theme === 'dark' ||
			(this.theme === 'system' && window.matchMedia('(prefers-color-scheme: dark)').matches);
		document.documentElement.classList.toggle('dark', dark);
	}
}

export const settings = new SettingsStore();
```

### `src/lib/components/common/CommandPalette.svelte`

```svelte
<script lang="ts">
	import { onMount, tick } from 'svelte';
	import { goto } from '$app/navigation';
	import { settings } from '$client/state/settings.svelte';
	import { api } from '$client/api';
	import type { Component } from 'svelte';
	import {
		Images,
		Star,
		BookImage,
		FolderOpen,
		Search,
		MapPin,
		Users,
		Tag,
		CalendarHeart,
		CopyCheck,
		Archive,
		Trash2,
		Settings,
		RefreshCw,
		SunMoon,
		Keyboard,
		CornerDownLeft
	} from '@lucide/svelte';

	type Cmd = { label: string; hint?: string; icon: Component<any>; run: () => void };

	let open = $state(false);
	let help = $state(false);
	let query = $state('');
	let sel = $state(0);
	let inputEl = $state<HTMLInputElement>();

	const commands: Cmd[] = [
		{ label: 'Photos', hint: 'timeline', icon: Images, run: () => goto('/') },
		{ label: 'Favorites', icon: Star, run: () => goto('/favorites') },
		{ label: 'Albums', icon: BookImage, run: () => goto('/albums') },
		{ label: 'Folders', icon: FolderOpen, run: () => goto('/folders') },
		{ label: 'Search', icon: Search, run: () => goto('/search') },
		{ label: 'Map', icon: MapPin, run: () => goto('/map') },
		{ label: 'Places', hint: 'locations', icon: MapPin, run: () => goto('/places') },
		{ label: 'People', icon: Users, run: () => goto('/people') },
		{ label: 'Tags', icon: Tag, run: () => goto('/tags') },
		{ label: 'Memories', hint: 'on this day', icon: CalendarHeart, run: () => goto('/memories') },
		{ label: 'Duplicates', icon: CopyCheck, run: () => goto('/duplicates') },
		{ label: 'Archive', icon: Archive, run: () => goto('/archive') },
		{ label: 'Trash', icon: Trash2, run: () => goto('/trash') },
		{ label: 'Settings', icon: Settings, run: () => goto('/settings') },
		{ label: 'Rescan library', hint: 'action', icon: RefreshCw, run: () => api.rescan(false) },
		{ label: 'Toggle theme', hint: 'action', icon: SunMoon, run: () => settings.cycleTheme() },
		{ label: 'Keyboard shortcuts', hint: '?', icon: Keyboard, run: () => (help = true) }
	];

	const filtered = $derived.by(() => {
		const q = query.trim().toLowerCase();
		const base = q
			? commands.filter((c) => c.label.toLowerCase().includes(q) || c.hint?.toLowerCase().includes(q))
			: commands;
		// Always offer a "search for …" escape hatch when typing.
		if (q && !commands.some((c) => c.label.toLowerCase() === q)) {
			return [
				...base,
				{
					label: `Search for “${query.trim()}”`,
					icon: Search,
					run: () => goto(`/search?q=${encodeURIComponent(query.trim())}`)
				} as Cmd
			];
		}
		return base;
	});

	async function show() {
		open = true;
		help = false;
		query = '';
		sel = 0;
		await tick();
		inputEl?.focus();
	}
	function close() {
		open = false;
		help = false;
	}
	function runIndex(i: number) {
		const cmd = filtered[i];
		if (!cmd) return;
		close();
		cmd.run();
	}

	function onGlobalKey(e: KeyboardEvent) {
		const tag = (e.target as HTMLElement)?.tagName;
		const typing = tag === 'INPUT' || tag === 'TEXTAREA' || (e.target as HTMLElement)?.isContentEditable;
		if ((e.key === 'k' || e.key === 'K') && (e.metaKey || e.ctrlKey)) {
			e.preventDefault();
			open ? close() : show();
		} else if (e.key === '?' && !typing && !open) {
			e.preventDefault();
			open = true;
			help = true;
		} else if (e.key === 'Escape' && open) {
			// Global Escape closes even the '?' help view, which isn't focused.
			e.preventDefault();
			close();
		}
	}

	function onPaletteKey(e: KeyboardEvent) {
		if (e.key === 'Escape') {
			e.preventDefault();
			close();
		} else if (e.key === 'ArrowDown') {
			e.preventDefault();
			sel = Math.min(sel + 1, filtered.length - 1);
		} else if (e.key === 'ArrowUp') {
			e.preventDefault();
			sel = Math.max(sel - 1, 0);
		} else if (e.key === 'Enter') {
			e.preventDefault();
			runIndex(sel);
		}
	}

	$effect(() => {
		void query;
		sel = 0;
	});

	onMount(() => {
		window.addEventListener('keydown', onGlobalKey);
		return () => window.removeEventListener('keydown', onGlobalKey);
	});

	const SHORTCUTS = [
		{ k: '⌘/Ctrl + K', d: 'Open this command palette' },
		{ k: '?', d: 'Show keyboard shortcuts' },
		{ k: '← / →', d: 'Lightbox: previous / next' },
		{ k: 'Space', d: 'Lightbox: play/pause video · slideshow' },
		{ k: 'F', d: 'Lightbox: favorite' },
		{ k: 'I', d: 'Lightbox: info panel' },
		{ k: '0 – 5', d: 'Lightbox: set star rating' },
		{ k: 'P / X', d: 'Lightbox: pick / reject' },
		{ k: '+ / −', d: 'Lightbox: zoom in / out' },
		{ k: 'Del', d: 'Lightbox: move to trash' },
		{ k: 'Esc', d: 'Close lightbox / this dialog' },
		{ k: 'Shift + click', d: 'Grid: range-select' }
	];
</script>

{#if open}
	<div class="scrim" role="presentation" onclick={close}></div>
	<div
		class="palette lg-card"
		role="dialog"
		aria-modal="true"
		aria-label="Command palette"
		tabindex="-1"
		onkeydown={onPaletteKey}
	>
		{#if help}
			<div class="help">
				<div class="help-head">Keyboard shortcuts</div>
				<ul>
					{#each SHORTCUTS as s (s.k)}
						<li><kbd>{s.k}</kbd><span>{s.d}</span></li>
					{/each}
				</ul>
			</div>
		{:else}
			<div class="search">
				<Search size={18} />
				<input
					bind:this={inputEl}
					bind:value={query}
					placeholder="Jump to… (type a view or search)"
					spellcheck="false"
				/>
			</div>
			<ul class="list">
				{#each filtered as cmd, i (cmd.label)}
					<li>
						<button
							class="item"
							class:active={i === sel}
							onpointermove={() => (sel = i)}
							onclick={() => runIndex(i)}
						>
							<cmd.icon size={17} />
							<span class="label">{cmd.label}</span>
							{#if cmd.hint}<span class="hint">{cmd.hint}</span>{/if}
							{#if i === sel}<CornerDownLeft size={14} class="enter" />{/if}
						</button>
					</li>
				{/each}
			</ul>
		{/if}
	</div>
{/if}

<style>
	.scrim {
		position: fixed;
		inset: 0;
		z-index: 120;
		background: rgb(0 0 0 / 0.4);
		backdrop-filter: blur(2px);
	}
	.palette {
		position: fixed;
		z-index: 121;
		top: 14vh;
		left: 50%;
		transform: translateX(-50%);
		width: 560px;
		max-width: 92vw;
		max-height: 70vh;
		overflow: hidden;
		display: flex;
		flex-direction: column;
		box-shadow: var(--lg-shadow-3);
		animation: pal-in var(--lg-dur-base) var(--lg-ease);
	}
	@keyframes pal-in {
		from {
			opacity: 0;
			transform: translate(-50%, -8px);
		}
	}
	.search {
		display: flex;
		align-items: center;
		gap: 10px;
		padding: 14px 16px;
		border-bottom: 1px solid var(--lg-border);
		color: var(--lg-text-muted);
	}
	.search input {
		flex: 1;
		border: none;
		background: transparent;
		color: var(--lg-text);
		font-size: 1rem;
		outline: none;
	}
	.list {
		list-style: none;
		margin: 0;
		padding: 6px;
		overflow-y: auto;
	}
	.item {
		display: flex;
		align-items: center;
		gap: 11px;
		width: 100%;
		padding: 9px 11px;
		border: none;
		background: transparent;
		color: var(--lg-text);
		border-radius: var(--lg-r-md);
		cursor: pointer;
		text-align: left;
		font-size: 0.92rem;
	}
	.item.active {
		background: var(--lg-accent-weak);
		color: var(--lg-accent);
	}
	.label {
		flex: 1;
	}
	.hint {
		font-size: 0.72rem;
		color: var(--lg-text-muted);
		text-transform: uppercase;
		letter-spacing: 0.04em;
	}
	:global(.palette .item .enter) {
		opacity: 0.6;
	}
	.help {
		padding: 16px 18px;
		overflow-y: auto;
	}
	.help-head {
		font-weight: 700;
		margin-bottom: 10px;
	}
	.help ul {
		list-style: none;
		margin: 0;
		padding: 0;
	}
	.help li {
		display: flex;
		align-items: center;
		gap: 14px;
		padding: 6px 0;
		font-size: 0.9rem;
	}
	.help kbd {
		flex-shrink: 0;
		min-width: 96px;
		font-family: inherit;
		font-size: 0.78rem;
		background: var(--lg-surface-2);
		border: 1px solid var(--lg-border);
		border-radius: var(--lg-r-sm);
		padding: 3px 7px;
		text-align: center;
	}
	.help span {
		color: var(--lg-text-muted);
	}
</style>
```

### `src/lib/components/common/DensityToggle.svelte`

```svelte
<script lang="ts">
	import { settings } from '$client/state/settings.svelte';
	import { LayoutGrid, Grid2x2, Grid3x3 } from '@lucide/svelte';
	import type { GridDensity } from '$shared/types';

	const options: { value: GridDensity; icon: typeof LayoutGrid; label: string }[] = [
		{ value: 'compact', icon: Grid3x3, label: 'Compact' },
		{ value: 'comfortable', icon: Grid2x2, label: 'Comfortable' },
		{ value: 'spacious', icon: LayoutGrid, label: 'Spacious' }
	];
</script>

<div class="seg" role="group" aria-label="Grid density">
	{#each options as o (o.value)}
		<button
			type="button"
			class:active={settings.density === o.value}
			title={o.label}
			aria-pressed={settings.density === o.value}
			onclick={() => settings.setDensity(o.value)}
		>
			<o.icon size={17} />
		</button>
	{/each}
</div>

<style>
	.seg {
		display: inline-flex;
		border: 1px solid var(--lg-border);
		border-radius: var(--lg-r-md);
		overflow: hidden;
	}
	button {
		display: flex;
		align-items: center;
		justify-content: center;
		padding: 6px 9px;
		border: none;
		background: transparent;
		color: var(--lg-text-muted);
		cursor: pointer;
		transition: background var(--lg-dur-fast) var(--lg-ease);
	}
	button:hover {
		background: var(--lg-accent-weak);
	}
	button.active {
		background: var(--lg-accent);
		color: var(--lg-accent-text);
	}
</style>
```

### `src/lib/components/common/EmptyState.svelte`

```svelte
<script lang="ts">
	import type { Snippet, Component } from 'svelte';

	let {
		icon = null,
		title,
		description = '',
		action,
		children
	}: {
		// eslint-disable-next-line @typescript-eslint/no-explicit-any
		icon?: Component<any> | null;
		title: string;
		description?: string;
		action?: Snippet;
		children?: Snippet;
	} = $props();
</script>

<div class="empty">
	{#if icon}
		{@const Icon = icon}
		<div class="ic"><Icon size={36} /></div>
	{/if}
	<p class="title">{title}</p>
	{#if description}<p class="desc">{description}</p>{/if}
	{#if children}<div class="extra">{@render children()}</div>{/if}
	{#if action}<div class="act">{@render action()}</div>{/if}
</div>

<style>
	.empty {
		max-width: 30rem;
		margin: 12vh auto 0;
		padding: 0 1.5rem;
		text-align: center;
		color: var(--lg-text-muted);
	}
	.ic {
		display: inline-flex;
		align-items: center;
		justify-content: center;
		width: 64px;
		height: 64px;
		border-radius: var(--lg-r-xl);
		background: var(--lg-surface-2);
		color: var(--lg-text-muted);
		margin-bottom: 14px;
	}
	.title {
		font-size: 1.1rem;
		font-weight: 600;
		color: var(--lg-text);
	}
	.desc {
		margin-top: 0.5rem;
		font-size: 0.9rem;
		line-height: 1.5;
	}
	.extra,
	.act {
		margin-top: 1rem;
		display: flex;
		justify-content: center;
		gap: 8px;
	}
	:global(.empty code) {
		background: var(--lg-surface-2);
		padding: 1px 6px;
		border-radius: var(--lg-r-sm);
		color: var(--lg-text);
	}
</style>
```

### `src/lib/components/common/Logo.svelte`

```svelte
<script lang="ts">
	// The LGallery mark — a photo scene (sun + mountains) with a video play badge.
	let { size = 26 }: { size?: number } = $props();
	const id = $derived(`lg-bg-${Math.round(size)}`);
</script>

<svg
	width={size}
	height={size}
	viewBox="0 0 64 64"
	role="img"
	aria-label="LGallery"
	xmlns="http://www.w3.org/2000/svg"
>
	<defs>
		<linearGradient {id} x1="0" y1="0" x2="1" y2="1">
			<stop offset="0" stop-color="#3b82f6" />
			<stop offset="1" stop-color="#7c3aed" />
		</linearGradient>
	</defs>
	<rect width="64" height="64" rx="15" fill="url(#{id})" />
	<circle cx="21" cy="24" r="6" fill="#fde047" />
	<path d="M8 52 L24 31 L34 43 L41 35 L56 52 Z" fill="#ffffff" fill-opacity="0.96" />
	<circle cx="46" cy="19" r="10" fill="#ffffff" />
	<path d="M42.5 13.5 L53 19 L42.5 24.5 Z" fill="#2563eb" />
</svg>
```

### `src/lib/components/common/PageHeader.svelte`

```svelte
<script lang="ts">
	import type { Snippet, Component } from 'svelte';

	let {
		title = '',
		count = null,
		icon = null,
		actions,
		children
	}: {
		title?: string;
		count?: number | string | null;
		// eslint-disable-next-line @typescript-eslint/no-explicit-any
		icon?: Component<any> | null;
		actions?: Snippet;
		children?: Snippet;
	} = $props();
</script>

<header class="lg-bar">
	<div class="title">
		{#if icon}
			{@const Icon = icon}
			<Icon size={22} />
		{/if}
		{#if children}{@render children()}{:else}<h1>{title}</h1>{/if}
		{#if count != null}
			<span class="count">{typeof count === 'number' ? count.toLocaleString() : count}</span>
		{/if}
	</div>
	{#if actions}<div class="actions">{@render actions()}</div>{/if}
</header>

<style>
	.title {
		display: flex;
		align-items: center;
		gap: 10px;
		min-width: 0;
	}
	h1 {
		font-size: 1.4rem;
		font-weight: 700;
		letter-spacing: -0.01em;
		white-space: nowrap;
	}
	.count {
		font-size: 0.85rem;
		color: var(--lg-text-muted);
		font-variant-numeric: tabular-nums;
	}
	.actions {
		display: flex;
		align-items: center;
		gap: 8px;
		flex-shrink: 0;
	}
</style>
```

### `src/lib/components/common/ScanChip.svelte`

```svelte
<script lang="ts">
	import { scanStatus } from '$client/state/scanStatus.svelte';
	import { Loader, RefreshCw } from '@lucide/svelte';
	import { api } from '$client/api';

	const s = $derived(scanStatus.state);
	const visible = $derived(
		s.status === 'running' || s.metaPending > 0 || s.thumbsPending > 0 || s.status === 'error'
	);

	let rescanning = $state(false);
	async function rescan() {
		rescanning = true;
		try {
			await api.rescan(false);
		} finally {
			setTimeout(() => (rescanning = false), 800);
		}
	}

	/** "~3m left" / "~45s left" from an ms estimate. */
	function fmtEta(ms: number): string {
		if (ms <= 0) return '';
		const s = Math.round(ms / 1000);
		if (s < 60) return `~${s}s left`;
		const m = Math.round(s / 60);
		if (m < 60) return `~${m}m left`;
		return `~${(m / 60).toFixed(1)}h left`;
	}

	const text = $derived.by(() => {
		if (s.status === 'error') return 'Scan error';
		if (s.status === 'running') return `Scanning — ${s.filesSeen.toLocaleString()} seen`;
		if (s.thumbsPending > 0) {
			let t = `Processing ${s.thumbsPending.toLocaleString()} thumbnail(s)`;
			const eta = s.etaMs ? fmtEta(s.etaMs) : '';
			if (s.throughputPerSec >= 1) t += ` · ${Math.round(s.throughputPerSec)}/s`;
			if (eta) t += ` · ${eta}`;
			return t;
		}
		if (s.metaPending > 0) return `Reading ${s.metaPending.toLocaleString()} file(s)`;
		return 'Idle';
	});
</script>

{#if visible}
	<div class="chip" class:err={s.status === 'error'} role="status" aria-live="polite">
		<span class="spin"><Loader size={15} /></span>
		<span class="txt">{text}</span>
		<button type="button" onclick={rescan} title="Rescan now" disabled={rescanning}>
			<span class:spinning={rescanning}><RefreshCw size={14} /></span>
		</button>
	</div>
{/if}

<style>
	.chip {
		position: fixed;
		left: 50%;
		bottom: 18px;
		transform: translateX(-50%);
		display: flex;
		align-items: center;
		gap: 9px;
		padding: 8px 12px;
		border-radius: 999px;
		background: var(--lg-overlay-bg);
		color: var(--lg-overlay-text);
		font-size: 0.82rem;
		font-weight: 500;
		box-shadow: var(--lg-shadow-2);
		backdrop-filter: blur(8px);
		z-index: 30;
	}
	.chip.err {
		background: var(--lg-danger);
	}
	.spin :global(svg) {
		animation: spin 1.1s linear infinite;
	}
	button {
		display: flex;
		border: none;
		background: var(--lg-overlay-hover);
		color: var(--lg-overlay-text);
		border-radius: 50%;
		padding: 5px;
		cursor: pointer;
	}
	button:hover {
		background: rgb(255 255 255 / 0.28);
	}
	.spinning :global(svg) {
		animation: spin 0.8s linear infinite;
	}
	@keyframes spin {
		to {
			transform: rotate(360deg);
		}
	}
</style>
```

### `src/lib/components/common/SelectionBar.svelte`

```svelte
<script lang="ts">
	import { selection } from '$client/state/selection.svelte';
	import { gallery } from '$client/state/gallery.svelte';
	import { api } from '$client/api';
	import type { Album } from '$shared/types';
	import { Star, Archive, FolderPlus, Download, Trash2, X, Plus, Flag, Ban } from '@lucide/svelte';

	let busy = $state(false);
	let showAlbums = $state(false);
	let showRate = $state(false);
	let albums = $state<Album[]>([]);
	let newAlbumName = $state('');

	const ids = $derived([...selection.ids]);

	async function favorite() {
		await run(() => api.setFlags(ids, { favorite: true }));
		gallery.patchFlags(ids, { isFavorite: true });
		selection.clear();
	}
	async function archive() {
		await run(() => api.setFlags(ids, { archived: true }));
		gallery.remove(ids); // archived items leave the main timeline
		selection.clear();
	}
	async function trash() {
		if (!confirm(`Move ${ids.length} item(s) to trash? You can restore them later.`)) return;
		await run(() => api.trash(ids));
		gallery.remove(ids);
		selection.clear();
	}
	function exportZip() {
		window.location.href = api.exportZipUrl(ids);
	}
	async function rate(r: number) {
		await run(() => api.setFlags(ids, { rating: r }));
		showRate = false;
		selection.clear();
	}
	async function pickFlag(p: number) {
		await run(() => api.setFlags(ids, { pick: p }));
		showRate = false;
		selection.clear();
	}
	async function openAlbums() {
		showAlbums = !showAlbums;
		if (showAlbums && albums.length === 0) {
			try {
				albums = (await api.albums()).albums;
			} catch {
				albums = [];
			}
		}
	}
	async function addTo(albumId: number) {
		await run(() => api.addToAlbum(albumId, ids));
		showAlbums = false;
		selection.clear();
	}
	async function createAndAdd() {
		const name = newAlbumName.trim();
		if (!name) return;
		const album = await api.createAlbum(name);
		await api.addToAlbum(album.id, ids);
		newAlbumName = '';
		showAlbums = false;
		selection.clear();
	}

	async function run(fn: () => Promise<unknown>) {
		busy = true;
		try {
			await fn();
		} catch (e) {
			alert(e instanceof Error ? e.message : 'Action failed');
		} finally {
			busy = false;
		}
	}
</script>

<div class="bar" class:busy role="toolbar" aria-label="Selection actions">
	<button class="count" onclick={() => selection.clear()} title="Clear selection">
		<X size={18} /> <strong>{selection.count}</strong> selected
	</button>
	<div class="sep"></div>
	<button onclick={favorite} disabled={busy}><Star size={18} /> Favorite</button>
	<div class="albums">
		<button onclick={() => (showRate = !showRate)} disabled={busy}><Star size={18} /> Rate</button>
		{#if showRate}
			<div class="pop rate">
				<div class="stars">
					{#each [1, 2, 3, 4, 5] as n (n)}
						<button class="star" onclick={() => rate(n)} aria-label={`Rate ${n}`}><Star size={18} /></button>
					{/each}
				</div>
				<button class="row-btn" onclick={() => rate(0)}>Clear rating</button>
				<button class="row-btn" onclick={() => pickFlag(1)}><Flag size={15} /> Pick</button>
				<button class="row-btn" onclick={() => pickFlag(-1)}><Ban size={15} /> Reject</button>
			</div>
		{/if}
	</div>
	<button onclick={archive} disabled={busy}><Archive size={18} /> Archive</button>
	<div class="albums">
		<button onclick={openAlbums} disabled={busy}><FolderPlus size={18} /> Album</button>
		{#if showAlbums}
			<div class="pop">
				<div class="new">
					<input placeholder="New album…" bind:value={newAlbumName} onkeydown={(e) => e.key === 'Enter' && createAndAdd()} />
					<button class="add" onclick={createAndAdd} aria-label="Create album"><Plus size={16} /></button>
				</div>
				{#if albums.length}
					<ul>
						{#each albums as a (a.id)}
							<li><button onclick={() => addTo(a.id)}>{a.name}<span>{a.count}</span></button></li>
						{/each}
					</ul>
				{:else}
					<p class="none">No albums yet</p>
				{/if}
			</div>
		{/if}
	</div>
	<button onclick={exportZip} disabled={busy}><Download size={18} /> Export</button>
	<button class="danger" onclick={trash} disabled={busy}><Trash2 size={18} /> Trash</button>
</div>

<style>
	.bar {
		position: fixed;
		bottom: 22px;
		left: 50%;
		transform: translateX(-50%);
		display: flex;
		align-items: center;
		gap: 4px;
		padding: 7px 10px;
		border-radius: var(--lg-r-lg);
		background: var(--lg-surface);
		color: var(--lg-text);
		border: 1px solid var(--lg-border);
		box-shadow: var(--lg-shadow-3);
		z-index: 40;
	}
	.bar.busy {
		opacity: 0.7;
		pointer-events: none;
	}
	button {
		display: flex;
		align-items: center;
		gap: 6px;
		padding: 8px 11px;
		border: none;
		background: transparent;
		color: inherit;
		border-radius: 9px;
		cursor: pointer;
		font-size: 0.85rem;
		font-weight: 500;
	}
	button:hover {
		background: var(--lg-surface-hover);
	}
	.count strong {
		font-weight: 700;
	}
	.sep {
		width: 1px;
		height: 24px;
		background: var(--lg-border);
		margin: 0 4px;
	}
	.danger:hover {
		background: var(--lg-danger);
		color: #fff;
	}
	.albums {
		position: relative;
	}
	.pop {
		position: absolute;
		bottom: calc(100% + 8px);
		left: 0;
		width: 230px;
		background: var(--lg-surface);
		border: 1px solid var(--lg-border);
		border-radius: var(--lg-r-md);
		padding: 8px;
		max-height: 320px;
		overflow-y: auto;
		box-shadow: var(--lg-shadow-2);
	}
	.new {
		display: flex;
		gap: 6px;
		margin-bottom: 6px;
	}
	.new input {
		flex: 1;
		padding: 6px 8px;
		border-radius: var(--lg-r-sm);
		border: 1px solid var(--lg-border);
		background: var(--lg-bg);
		color: var(--lg-text);
		font-size: 0.85rem;
	}
	.new .add {
		padding: 6px;
		background: var(--lg-accent);
		color: var(--lg-accent-text);
	}
	.pop ul {
		list-style: none;
		margin: 0;
		padding: 0;
	}
	.pop li button {
		width: 100%;
		justify-content: space-between;
		font-weight: 400;
	}
	.pop li button span {
		color: var(--lg-text-muted);
		font-size: 0.78rem;
	}
	.none {
		color: var(--lg-text-muted);
		font-size: 0.82rem;
		padding: 6px;
	}
	.pop.rate {
		width: auto;
		min-width: 180px;
	}
	.pop.rate .stars {
		display: flex;
		gap: 2px;
		margin-bottom: 6px;
	}
	.pop.rate .star {
		padding: 5px;
		color: #eab308;
	}
	.pop.rate .star:hover {
		background: var(--lg-surface-hover);
	}
	.pop.rate .row-btn {
		width: 100%;
		justify-content: flex-start;
		font-weight: 400;
	}
</style>
```

### `src/lib/components/common/Skeleton.svelte`

```svelte
<script lang="ts">
	let {
		width = '100%',
		height = '100%',
		radius = 'var(--lg-r-md)'
	}: { width?: string; height?: string; radius?: string } = $props();
</script>

<div class="lg-skeleton" style="width:{width};height:{height};border-radius:{radius}"></div>
```

### `src/lib/components/grid/GridTile.svelte`

```svelte
<script lang="ts">
	import type { TimelineItem } from '$shared/types';
	import { blurhashAverageColor } from '$shared/blurhash';
	import { blurhashDataURL } from '$client/blurhash-img';
	import { formatDuration } from '$shared/format';
	import { Play } from '@lucide/svelte';

	let {
		item,
		x,
		y,
		w,
		h,
		priority = false,
		selecting = false,
		selected = false,
		onOpen,
		onToggleSelect
	}: {
		item: TimelineItem;
		x: number;
		y: number;
		w: number;
		h: number;
		priority?: boolean;
		selecting?: boolean;
		selected?: boolean;
		onOpen: (id: number, ev: MouseEvent) => void;
		onToggleSelect?: (id: number, ev: MouseEvent) => void;
	} = $props();

	let loaded = $state(false);
	let hovering = $state(false);
	const avg = $derived(blurhashAverageColor(item.blurhash));
	const lqip = $derived(blurhashDataURL(item.blurhash));
	const isLive = $derived(item.livePartnerId != null);
	// On hover, play: a video's own stream, or a Live photo's partner clip.
	const hoverVideoId = $derived(item.type === 'video' ? item.id : (item.livePartnerId ?? null));

	function click(ev: MouseEvent) {
		if (selecting || ev.shiftKey || ev.ctrlKey || ev.metaKey) onToggleSelect?.(item.id, ev);
		else onOpen(item.id, ev);
	}
</script>

<button
	type="button"
	class="tile lg-ring"
	class:selected
	style="transform: translate3d({x}px, {y}px, 0); width: {w}px; height: {h}px; background-color: {avg};
	       {lqip ? `background-image:url(${lqip});background-size:cover;background-position:center;` : ''}"
	onclick={click}
	onpointerenter={() => (hovering = true)}
	onpointerleave={() => (hovering = false)}
	aria-label={item.type === 'video' ? 'Open video' : 'Open photo'}
	aria-pressed={selecting ? selected : undefined}
>
	<img
		src="/api/media/{item.id}/thumb?size=grid"
		srcset="/api/media/{item.id}/thumb?size=grid 1x, /api/media/{item.id}/thumb?size=grid2x 2x"
		alt=""
		width={w}
		height={h}
		loading={priority ? 'eager' : 'lazy'}
		fetchpriority={priority ? 'high' : 'auto'}
		decoding="async"
		class:loaded
		onload={() => (loaded = true)}
	/>

	{#if hovering && hoverVideoId != null}
		<!-- svelte-ignore a11y_media_has_caption -->
		<video
			class="hovervid"
			src="/api/media/{hoverVideoId}/stream"
			muted
			autoplay
			loop
			playsinline
			preload="none"
		></video>
	{/if}

	{#if item.type === 'video' && item.durationMs}
		<span class="badge dur"><Play size={11} fill="currentColor" /> {formatDuration(item.durationMs)}</span>
	{:else if isLive}
		<span class="badge live">LIVE</span>
	{/if}
	{#if item.isFavorite}
		<span class="badge fav" aria-hidden="true">★</span>
	{/if}
	{#if selecting}
		<span class="check" class:on={selected} aria-hidden="true">{selected ? '✓' : ''}</span>
	{/if}
</button>

<style>
	.tile {
		position: absolute;
		top: 0;
		left: 0;
		padding: 0;
		margin: 0;
		border: none;
		overflow: hidden;
		border-radius: var(--lg-r-sm);
		cursor: pointer;
		outline: none;
		contain: strict;
		will-change: transform;
	}
	.tile.selected {
		box-shadow: 0 0 0 3px var(--lg-accent);
	}
	img,
	.hovervid {
		width: 100%;
		height: 100%;
		object-fit: cover;
		display: block;
		position: absolute;
		inset: 0;
	}
	img {
		opacity: 0;
		transition:
			opacity var(--lg-dur-base) var(--lg-ease),
			transform var(--lg-dur-base) var(--lg-ease);
	}
	img.loaded {
		opacity: 1;
	}
	.tile:hover img {
		transform: scale(1.045);
	}
	.tile.selected img {
		transform: scale(0.86);
		border-radius: var(--lg-r-md);
	}
	.hovervid {
		z-index: 1;
		object-fit: cover;
	}
	.badge {
		position: absolute;
		z-index: 2;
		font-size: 11px;
		line-height: 1;
		color: #fff;
		text-shadow: 0 1px 2px rgb(0 0 0 / 0.7);
		pointer-events: none;
	}
	.badge.dur {
		display: inline-flex;
		align-items: center;
		gap: 3px;
		right: 6px;
		bottom: 6px;
		font-weight: 600;
	}
	.badge.live {
		left: 6px;
		top: 6px;
		font-size: 9px;
		font-weight: 800;
		letter-spacing: 0.06em;
		background: rgb(0 0 0 / 0.45);
		padding: 2px 5px;
		border-radius: 999px;
		backdrop-filter: blur(2px);
	}
	.badge.fav {
		left: 6px;
		bottom: 6px;
		font-size: 14px;
		color: var(--lg-fav);
	}
	.check {
		position: absolute;
		z-index: 2;
		top: 6px;
		left: 6px;
		width: 20px;
		height: 20px;
		border-radius: 50%;
		border: 2px solid #fff;
		background: rgb(0 0 0 / 0.35);
		color: #fff;
		font-size: 13px;
		display: flex;
		align-items: center;
		justify-content: center;
		transition: transform var(--lg-dur-fast) var(--lg-ease);
	}
	.check.on {
		background: var(--lg-accent);
		border-color: var(--lg-accent);
		transform: scale(1.12);
	}
</style>
```

### `src/lib/components/grid/MediaGridView.svelte`

```svelte
<script lang="ts">
	import { onDestroy } from 'svelte';
	import type { DayBucket } from '$shared/types';
	import TimelineGrid from './TimelineGrid.svelte';
	import Lightbox from '$components/lightbox/Lightbox.svelte';
	import SelectionBar from '$components/common/SelectionBar.svelte';
	import { gallery } from '$client/state/gallery.svelte';
	import { settings } from '$client/state/settings.svelte';
	import { selection } from '$client/state/selection.svelte';
	import { api } from '$client/api';

	let { buckets = [], initialWidth = 0 }: { buckets?: DayBucket[]; initialWidth?: number } = $props();

	let lightboxId = $state<number | null>(null);
	let visibleTimer: ReturnType<typeof setTimeout> | undefined;
	onDestroy(() => clearTimeout(visibleTimer));

	function onVisible(ids: number[]) {
		clearTimeout(visibleTimer);
		visibleTimer = setTimeout(() => api.reportVisible(ids).catch(() => {}), 60);
	}
	function onToggleSelect(id: number, ev: MouseEvent) {
		if (ev.shiftKey) selection.selectRange(gallery.items.map((i) => i.id), id);
		else selection.toggle(id);
	}
</script>

<div class="wrap">
	<TimelineGrid
		items={gallery.items}
		density={settings.density}
		{buckets}
		{initialWidth}
		selecting={selection.selecting}
		selectedIds={selection.ids}
		onLoadMore={() => gallery.loadMore()}
		onVisibleChange={onVisible}
		onOpen={(id) => (lightboxId = id)}
		{onToggleSelect}
		onRubberBand={(ids) => selection.selectAll(ids)}
	/>
</div>

{#if selection.count > 0}
	<SelectionBar />
{/if}

{#if lightboxId !== null}
	<Lightbox startId={lightboxId} onClose={() => (lightboxId = null)} />
{/if}

<style>
	.wrap {
		height: 100%;
		min-height: 0;
	}
</style>
```

### `src/lib/components/grid/TimelineGrid.svelte`

```svelte
<script lang="ts">
	import { onMount, untrack } from 'svelte';
	import type { TimelineItem, GridDensity, DayBucket } from '$shared/types';
	import {
		computeLayout,
		densityOptions,
		findRowRange,
		estimateHeightFromBuckets,
		monthMarksFromBuckets
	} from '$shared/layout';
	import { dayHeaderLabel, monthHeaderLabel, floatingDateLabel, monthKeyFromDay } from '$shared/format';
	import GridTile from './GridTile.svelte';

	let {
		items,
		density = 'comfortable',
		buckets = [],
		initialWidth = 0,
		selecting = false,
		selectedIds = new Set<number>(),
		onLoadMore,
		onVisibleChange,
		onOpen,
		onToggleSelect,
		onRubberBand
	}: {
		items: TimelineItem[];
		density?: GridDensity;
		buckets?: DayBucket[];
		initialWidth?: number;
		selecting?: boolean;
		selectedIds?: Set<number>;
		onLoadMore?: () => void;
		onVisibleChange?: (ids: number[]) => void;
		onOpen?: (id: number) => void;
		onToggleSelect?: (id: number, ev: MouseEvent) => void;
		onRubberBand?: (ids: number[]) => void;
	} = $props();

	const PAD = 12;
	let scrollEl: HTMLDivElement;
	// Seed from the server-provided width so layout runs during SSR / before measurement,
	// then onMount's ResizeObserver corrects it.
	let containerWidth = $state(untrack(() => initialWidth));
	let viewportH = $state(untrack(() => (initialWidth > 0 ? 800 : 0)));
	let scrollTop = $state(0);
	let showLabel = $state(false);

	const opts = $derived(densityOptions(density, containerWidth));
	const layout = $derived(
		containerWidth > 0 ? computeLayout(items, opts) : { rows: [], totalHeight: 0, width: 0 }
	);
	const itemsPerRow = $derived(
		containerWidth > 0 ? Math.max(1, Math.round(containerWidth / (opts.targetRowHeight + opts.gap))) : 5
	);
	const estimatedTotalHeight = $derived(
		buckets.length ? estimateHeightFromBuckets(buckets, opts, itemsPerRow) : 0
	);
	const spacerHeight = $derived(Math.max(layout.totalHeight, estimatedTotalHeight));
	const overscan = $derived(Math.max(300, viewportH));
	const range = $derived(
		findRowRange(layout.rows, scrollTop - overscan, scrollTop + viewportH + overscan)
	);
	const visibleRows = $derived(layout.rows.slice(range[0], range[1]));

	// Anchor the floating label to the viewport TOP (not the overscanned window, which can start
	// a screen above and show the previous day/month).
	const floatingLabel = $derived.by(() => {
		const [s] = findRowRange(layout.rows, scrollTop, scrollTop + 1);
		for (let i = Math.min(s, layout.rows.length - 1); i >= 0; i--) {
			const r = layout.rows[i];
			if (r?.type === 'header' && r.day) return floatingDateLabel(r.day);
		}
		return '';
	});

	let labelTimer: ReturnType<typeof setTimeout> | undefined;
	let visibleTimer: ReturnType<typeof setTimeout> | undefined;

	// Date-jump scrubber: year labels positioned along the right edge; drag/click to jump. Maps the
	// content-y of each month boundary (same estimate as the spacer height) onto the viewport track.
	let scrubbing = $state(false);
	const scrollRange = $derived(Math.max(1, spacerHeight - viewportH));
	const monthMarks = $derived(
		buckets.length && containerWidth > 0 ? monthMarksFromBuckets(buckets, opts, itemsPerRow) : []
	);
	// Reduce month marks to one label per year for the scrubber rail (avoids clutter on huge libraries).
	const yearMarks = $derived.by(() => {
		const out: { year: string; frac: number }[] = [];
		let lastYear = '';
		for (const m of monthMarks) {
			const yr = m.key.slice(0, 4);
			if (yr !== lastYear) {
				lastYear = yr;
				out.push({ year: yr, frac: spacerHeight > 0 ? Math.min(1, m.y / spacerHeight) : 0 });
			}
		}
		return out;
	});
	const scrubEnabled = $derived(monthMarks.length > 1 && spacerHeight > viewportH * 1.2);
	const thumbFrac = $derived(Math.min(1, scrollTop / scrollRange));

	function scrubToClientY(clientY: number) {
		if (!scrollEl) return;
		const r = scrollEl.getBoundingClientRect();
		const frac = Math.min(1, Math.max(0, (clientY - r.top) / Math.max(1, r.height)));
		scrollEl.scrollTop = frac * scrollRange; // onScroll updates the floating label + visible range
	}
	function scrubDown(e: PointerEvent) {
		scrubbing = true;
		(e.currentTarget as HTMLElement).setPointerCapture?.(e.pointerId);
		scrubToClientY(e.clientY);
	}
	function scrubMove(e: PointerEvent) {
		if (scrubbing) scrubToClientY(e.clientY);
	}
	function scrubUp() {
		scrubbing = false;
	}
	function jumpToMark(frac: number) {
		if (scrollEl) scrollEl.scrollTop = frac * scrollRange;
	}

	// Rubber-band drag-select (desktop): drag over empty grid space to select intersecting tiles.
	let spacerEl = $state<HTMLDivElement>();
	let drag = $state<{ x0: number; y0: number; x1: number; y1: number } | null>(null);
	const dragRect = $derived(
		drag
			? {
					x: Math.min(drag.x0, drag.x1),
					y: Math.min(drag.y0, drag.y1),
					w: Math.abs(drag.x1 - drag.x0),
					h: Math.abs(drag.y1 - drag.y0)
				}
			: null
	);

	function rbDown(e: PointerEvent) {
		if (e.button !== 0 || !onRubberBand || !spacerEl) return;
		if ((e.target as HTMLElement).closest('.tile')) return; // tiles handle their own clicks
		const r = spacerEl.getBoundingClientRect();
		const x = e.clientX - r.left;
		const y = e.clientY - r.top;
		drag = { x0: x, y0: y, x1: x, y1: y };
		scrollEl.setPointerCapture?.(e.pointerId);
	}
	function rbMove(e: PointerEvent) {
		if (!drag || !spacerEl) return;
		const r = spacerEl.getBoundingClientRect();
		drag = { ...drag, x1: e.clientX - r.left, y1: e.clientY - r.top };
		if (Math.abs(drag.x1 - drag.x0) < 4 && Math.abs(drag.y1 - drag.y0) < 4) return;
		const rx0 = Math.min(drag.x0, drag.x1);
		const rx1 = Math.max(drag.x0, drag.x1);
		const ry0 = Math.min(drag.y0, drag.y1);
		const ry1 = Math.max(drag.y0, drag.y1);
		const [s, en] = findRowRange(layout.rows, ry0, ry1);
		const ids: number[] = [];
		for (let i = s; i < en; i++) {
			const row = layout.rows[i];
			if (row.type !== 'tiles' || !row.tiles) continue;
			for (const t of row.tiles) {
				if (rx0 < t.x + t.w && rx1 > t.x && ry0 < t.y + t.h && ry1 > t.y) ids.push(t.id);
			}
		}
		onRubberBand?.(ids);
	}
	function rbUp(e: PointerEvent) {
		if (drag) {
			try {
				scrollEl.releasePointerCapture?.(e.pointerId);
			} catch {
				/* ignore */
			}
		}
		drag = null;
	}

	function measure() {
		if (!scrollEl) return;
		containerWidth = Math.max(0, scrollEl.clientWidth - PAD * 2);
		viewportH = scrollEl.clientHeight;
	}

	function reportVisible() {
		if (!onVisibleChange) return;
		const top = scrollTop;
		const bottom = scrollTop + viewportH;
		const [s, e] = findRowRange(layout.rows, top, bottom);
		const ids: number[] = [];
		for (let i = s; i < e; i++) {
			const r = layout.rows[i];
			if (r.type === 'tiles' && r.tiles) for (const t of r.tiles) ids.push(t.id);
		}
		if (ids.length) onVisibleChange(ids);
	}

	function maybeLoadMore() {
		if (!onLoadMore) return;
		// Trigger against the REAL laid-out content height, not the (inflated) bucket-estimate
		// spacer — otherwise pagination never fires past the first page.
		if (scrollTop + viewportH > layout.totalHeight - viewportH * 1.5) onLoadMore();
	}

	function onScroll() {
		scrollTop = scrollEl.scrollTop;
		showLabel = true;
		clearTimeout(labelTimer);
		labelTimer = setTimeout(() => (showLabel = false), 900);
		clearTimeout(visibleTimer);
		visibleTimer = setTimeout(reportVisible, 180);
		maybeLoadMore();
	}

	onMount(() => {
		measure();
		const ro = new ResizeObserver(() => measure());
		ro.observe(scrollEl);
		// initial visible report once measured
		const t = setTimeout(reportVisible, 200);
		return () => {
			ro.disconnect();
			clearTimeout(t);
			clearTimeout(labelTimer);
			clearTimeout(visibleTimer);
		};
	});

	// When the loaded set grows or layout changes, re-evaluate load-more & visible.
	$effect(() => {
		void items.length;
		void containerWidth;
		maybeLoadMore();
	});
</script>

<!-- svelte-ignore a11y_no_static_element_interactions -->
<div class="grid-root">
<div
	class="scroll"
	bind:this={scrollEl}
	onscroll={onScroll}
	onpointerdown={rbDown}
	onpointermove={rbMove}
	onpointerup={rbUp}
	onpointercancel={rbUp}
>
	<div class="spacer" bind:this={spacerEl} style="height: {spacerHeight}px; width: {containerWidth}px;">
		{#if dragRect}
			<div
				class="rubber"
				style="left:{dragRect.x}px;top:{dragRect.y}px;width:{dragRect.w}px;height:{dragRect.h}px;"
			></div>
		{/if}
		{#each visibleRows as row (row.type + '-' + row.y)}
			{#if row.type === 'header'}
				<div
					class="header"
					class:month={row.isMonthStart}
					style="top: {row.y}px; height: {row.h}px; width: {containerWidth}px;"
				>
					{#if row.isMonthStart}
						<span class="month-label">{monthHeaderLabel(monthKeyFromDay(row.day ?? ''))}</span>
					{:else}
						<span class="day-label">{dayHeaderLabel(row.day ?? '')}</span>
					{/if}
				</div>
			{:else if row.tiles}
				{#each row.tiles as tile (tile.id)}
					{@const item = items[tile.index]}
					{#if item}
						<GridTile
							{item}
							x={tile.x}
							y={tile.y}
							w={tile.w}
							h={tile.h}
							priority={tile.index < 16}
							{selecting}
							selected={selectedIds.has(tile.id)}
							onOpen={(id) => onOpen?.(id)}
							{onToggleSelect}
						/>
					{/if}
				{/each}
			{/if}
		{/each}
	</div>

	<div class="floating" class:show={showLabel} aria-hidden="true">{floatingLabel}</div>
</div>

	{#if scrubEnabled}
		<!-- svelte-ignore a11y_no_static_element_interactions -->
		<div
			class="scrubber"
			class:active={scrubbing}
			onpointerdown={scrubDown}
			onpointermove={scrubMove}
			onpointerup={scrubUp}
			onpointercancel={scrubUp}
			role="slider"
			aria-label="Jump to date"
			aria-valuemin={0}
			aria-valuemax={100}
			aria-valuenow={Math.round(thumbFrac * 100)}
			tabindex="-1"
		>
			<div class="thumb" style="top: {thumbFrac * 100}%"></div>
			{#each yearMarks as ym (ym.year)}
				<button
					class="year"
					style="top: {ym.frac * 100}%"
					onpointerdown={(e) => e.stopPropagation()}
					onclick={() => jumpToMark(ym.frac)}
					title={`Jump to ${ym.year}`}
				>
					{ym.year}
				</button>
			{/each}
		</div>
	{/if}
</div>

<style>
	.grid-root {
		position: relative;
		height: 100%;
		width: 100%;
	}
	.scroll {
		position: relative;
		height: 100%;
		width: 100%;
		overflow-y: auto;
		overflow-x: hidden;
		padding: 0 12px 12px;
		/* Native browser scrollbar is the scroll control (per design). */
	}
	.spacer {
		position: relative;
		margin: 0 auto;
	}
	.rubber {
		position: absolute;
		z-index: 3;
		border: 1px solid var(--lg-accent);
		background: var(--lg-accent-weak);
		border-radius: 2px;
		pointer-events: none;
	}
	.header {
		position: absolute;
		left: 0;
		display: flex;
		align-items: flex-end;
		padding-bottom: 6px;
	}
	.month-label {
		font-size: 1.35rem;
		font-weight: 700;
		letter-spacing: -0.01em;
		color: var(--lg-text);
	}
	.day-label {
		font-size: 0.9rem;
		font-weight: 600;
		color: var(--lg-text-muted);
	}
	.floating {
		position: fixed;
		right: 22px;
		bottom: 18px;
		padding: 6px 13px;
		border-radius: 999px;
		background: var(--lg-overlay-bg);
		color: var(--lg-overlay-text);
		font-size: 0.8rem;
		font-weight: 600;
		pointer-events: none;
		opacity: 0;
		transform: translateY(4px);
		transition:
			opacity var(--lg-dur-base) var(--lg-ease),
			transform var(--lg-dur-base) var(--lg-ease);
		z-index: 20;
		box-shadow: var(--lg-shadow-2);
		backdrop-filter: blur(8px);
	}
	.floating.show {
		opacity: 1;
		transform: translateY(0);
	}

	/* Date-jump scrubber: overlays the right edge; drag to scrub, click a year to jump.
	   Subtle until the grid is hovered (or actively scrubbing). */
	.scrubber {
		position: absolute;
		top: 0;
		right: 0;
		bottom: 0;
		width: 30px;
		z-index: 15;
		cursor: ns-resize;
		touch-action: none;
	}
	.scrubber .thumb {
		position: absolute;
		right: 4px;
		width: 4px;
		height: 36px;
		margin-top: -18px;
		border-radius: 999px;
		background: var(--lg-text-muted);
		opacity: 0.3;
		transition: opacity var(--lg-dur-fast) var(--lg-ease), background var(--lg-dur-fast) var(--lg-ease);
	}
	.grid-root:hover .scrubber .thumb,
	.scrubber.active .thumb {
		opacity: 0.75;
		background: var(--lg-accent);
	}
	.scrubber .year {
		position: absolute;
		right: 10px;
		transform: translateY(-50%);
		font-size: 0.68rem;
		font-weight: 700;
		color: var(--lg-text-muted);
		background: var(--lg-surface);
		border: 1px solid var(--lg-border);
		border-radius: var(--lg-r-sm);
		padding: 1px 5px;
		cursor: pointer;
		opacity: 0;
		pointer-events: none;
		transition: opacity var(--lg-dur-fast) var(--lg-ease);
		white-space: nowrap;
	}
	.grid-root:hover .scrubber .year,
	.scrubber.active .year {
		opacity: 1;
		pointer-events: auto;
	}
	.scrubber .year:hover {
		color: var(--lg-accent);
		border-color: var(--lg-accent);
	}
	@media (prefers-reduced-motion: reduce) {
		.scrubber .thumb,
		.scrubber .year {
			transition: none;
		}
	}
</style>
```

### `src/lib/components/lightbox/EditOverlay.svelte`

```svelte
<script lang="ts">
	import { untrack } from 'svelte';
	import type { MediaDetail } from '$shared/types';
	import { DEFAULT_EDITS, cssFilterFor, type EditOps, type FilterId, FILTERS } from '$shared/edits';
	import { api } from '$client/api';
	import {
		X,
		RotateCcw,
		RotateCw,
		FlipHorizontal,
		FlipVertical,
		Crop as CropIcon,
		Check,
		Undo2,
		Save,
		Download
	} from '@lucide/svelte';

	let {
		id,
		src,
		initial,
		onClose,
		onSaved
	}: {
		id: number;
		src: string;
		initial: EditOps | null;
		onClose: () => void;
		onSaved: (d: MediaDetail, editedMs: number) => void;
	} = $props();

	let ops = $state<EditOps>(untrack(() => ({ ...DEFAULT_EDITS, ...(initial ?? {}) })));
	let cropMode = $state(false);
	let busy = $state(false);
	let msg = $state('');
	let imgEl = $state<HTMLImageElement>();
	let wrapEl = $state<HTMLDivElement>();

	const cssFilter = $derived(cssFilterFor(ops));
	const geom = $derived(
		`rotate(${ops.rotate}deg) scaleX(${ops.flipH ? -1 : 1}) scaleY(${ops.flipV ? -1 : 1})`
	);

	type NumKey = 'brightness' | 'contrast' | 'saturation' | 'vibrance' | 'warmth';
	const SLIDERS: { key: NumKey; label: string; min: number; max: number; step: number }[] = [
		{ key: 'brightness', label: 'Brightness', min: 0.5, max: 1.5, step: 0.01 },
		{ key: 'contrast', label: 'Contrast', min: 0.5, max: 1.5, step: 0.01 },
		{ key: 'saturation', label: 'Saturation', min: 0, max: 2, step: 0.01 },
		{ key: 'vibrance', label: 'Vibrance', min: -1, max: 1, step: 0.01 },
		{ key: 'warmth', label: 'Warmth', min: -1, max: 1, step: 0.01 }
	];
	const ASPECTS: { label: string; r: number | null }[] = [
		{ label: 'Free', r: null },
		{ label: '1:1', r: 1 },
		{ label: '4:3', r: 4 / 3 },
		{ label: '3:2', r: 3 / 2 },
		{ label: '16:9', r: 16 / 9 }
	];

	function rotate(delta: number) {
		ops.rotate = (((ops.rotate + delta) % 360) + 360) % 360;
	}
	function setSlider(key: NumKey, v: number) {
		ops[key] = v;
	}
	function setFilter(f: FilterId) {
		ops.filter = f;
	}
	function reset() {
		ops = { ...DEFAULT_EDITS };
		cropMode = false;
	}

	function enterCrop() {
		cropMode = true;
		if (!ops.crop) ops.crop = { x: 0.05, y: 0.05, w: 0.9, h: 0.9 };
	}
	function clearCrop() {
		ops.crop = null;
	}
	function setAspect(r: number | null) {
		if (!ops.crop) ops.crop = { x: 0, y: 0, w: 1, h: 1 };
		if (r == null) {
			ops.crop = { x: 0.05, y: 0.05, w: 0.9, h: 0.9 };
			return;
		}
		const natW = imgEl?.naturalWidth || 1;
		const natH = imgEl?.naturalHeight || 1;
		// desired normalized w/h so that (w*natW)/(h*natH) = r
		const k = (r * natH) / natW;
		let w: number, h: number;
		if (k >= 1) {
			w = 1;
			h = 1 / k;
		} else {
			h = 1;
			w = k;
		}
		w = Math.min(1, w);
		h = Math.min(1, h);
		ops.crop = { x: (1 - w) / 2, y: (1 - h) / 2, w, h };
	}

	// Crop drag (move + 4 corners). Normalized to the displayed image box.
	type DragMode = 'move' | 'nw' | 'ne' | 'sw' | 'se';
	let drag: { mode: DragMode; sx: number; sy: number; start: NonNullable<EditOps['crop']> } | null = null;
	const clamp = (v: number, lo: number, hi: number) => Math.min(hi, Math.max(lo, v));

	function cropDown(e: PointerEvent, mode: DragMode) {
		if (!ops.crop) return;
		e.stopPropagation();
		(e.currentTarget as HTMLElement).setPointerCapture?.(e.pointerId);
		drag = { mode, sx: e.clientX, sy: e.clientY, start: { ...ops.crop } };
	}
	function cropMove(e: PointerEvent) {
		if (!drag || !ops.crop || !wrapEl) return;
		const r = wrapEl.getBoundingClientRect();
		const dx = (e.clientX - drag.sx) / r.width;
		const dy = (e.clientY - drag.sy) / r.height;
		const s = drag.start;
		const MIN = 0.05;
		if (drag.mode === 'move') {
			ops.crop = { ...s, x: clamp(s.x + dx, 0, 1 - s.w), y: clamp(s.y + dy, 0, 1 - s.h) };
		} else {
			let { x, y, w, h } = s;
			if (drag.mode === 'nw') {
				const nx = clamp(s.x + dx, 0, s.x + s.w - MIN);
				const ny = clamp(s.y + dy, 0, s.y + s.h - MIN);
				x = nx;
				y = ny;
				w = s.x + s.w - nx;
				h = s.y + s.h - ny;
			} else if (drag.mode === 'ne') {
				const ny = clamp(s.y + dy, 0, s.y + s.h - MIN);
				y = ny;
				h = s.y + s.h - ny;
				w = clamp(s.w + dx, MIN, 1 - s.x);
			} else if (drag.mode === 'sw') {
				const nx = clamp(s.x + dx, 0, s.x + s.w - MIN);
				x = nx;
				w = s.x + s.w - nx;
				h = clamp(s.h + dy, MIN, 1 - s.y);
			} else {
				w = clamp(s.w + dx, MIN, 1 - s.x);
				h = clamp(s.h + dy, MIN, 1 - s.y);
			}
			ops.crop = { x, y, w, h };
		}
	}
	function cropUp() {
		drag = null;
	}

	async function save() {
		busy = true;
		msg = '';
		try {
			const d = await api.editMedia(id, ops);
			onSaved(d, d.editOps ? Date.now() : Date.now());
			onClose();
		} catch (e) {
			msg = e instanceof Error ? e.message : 'Save failed';
		} finally {
			busy = false;
		}
	}
	async function revert() {
		if (!confirm('Discard all edits and restore the original?')) return;
		busy = true;
		try {
			const d = await api.revertEdits(id);
			onSaved(d, Date.now());
			onClose();
		} catch (e) {
			msg = e instanceof Error ? e.message : 'Revert failed';
		} finally {
			busy = false;
		}
	}
	async function exportCopy() {
		busy = true;
		msg = '';
		try {
			const r = await api.exportEdited(id, ops);
			msg = `Saved a copy: ${r.path.split('/').pop()}`;
		} catch (e) {
			msg = e instanceof Error ? e.message : 'Export failed';
		} finally {
			busy = false;
		}
	}
</script>

<div class="edit-overlay" role="dialog" aria-modal="true" aria-label="Edit photo">
	<div
		class="stage"
		bind:this={wrapEl}
		onpointermove={cropMove}
		onpointerup={cropUp}
		onpointercancel={cropUp}
		role="presentation"
	>
		<!-- svelte-ignore a11y_img_redundant_alt -->
		<img
			bind:this={imgEl}
			{src}
			alt="Editing preview"
			class="preview"
			style="filter: {cssFilter}; transform: {cropMode ? 'none' : geom};"
			draggable="false"
		/>
		{#if cropMode && ops.crop}
			<div class="crop-mask"></div>
			<div
				class="crop-box"
				style="left:{ops.crop.x * 100}%; top:{ops.crop.y * 100}%; width:{ops.crop.w * 100}%; height:{ops.crop.h * 100}%;"
				onpointerdown={(e) => cropDown(e, 'move')}
				role="presentation"
			>
				<span class="h nw" onpointerdown={(e) => cropDown(e, 'nw')} role="presentation"></span>
				<span class="h ne" onpointerdown={(e) => cropDown(e, 'ne')} role="presentation"></span>
				<span class="h sw" onpointerdown={(e) => cropDown(e, 'sw')} role="presentation"></span>
				<span class="h se" onpointerdown={(e) => cropDown(e, 'se')} role="presentation"></span>
			</div>
		{/if}
	</div>

	<aside class="panel">
		<header>
			<h2>Edit</h2>
			<button class="x" onclick={onClose} aria-label="Close editor"><X size={18} /></button>
		</header>

		<div class="controls">
			<section>
				<div class="lbl">Orient</div>
				<div class="btn-row">
					<button onclick={() => rotate(-90)} title="Rotate left"><RotateCcw size={17} /></button>
					<button onclick={() => rotate(90)} title="Rotate right"><RotateCw size={17} /></button>
					<button class:on={ops.flipH} onclick={() => (ops.flipH = !ops.flipH)} title="Flip horizontal"><FlipHorizontal size={17} /></button>
					<button class:on={ops.flipV} onclick={() => (ops.flipV = !ops.flipV)} title="Flip vertical"><FlipVertical size={17} /></button>
					<button class:on={cropMode} onclick={() => (cropMode ? (cropMode = false) : enterCrop())} title="Crop"><CropIcon size={17} /></button>
				</div>
				{#if cropMode}
					<div class="aspects">
						{#each ASPECTS as a (a.label)}
							<button class="chip" onclick={() => setAspect(a.r)}>{a.label}</button>
						{/each}
						<button class="chip" onclick={clearCrop}>Clear</button>
					</div>
				{/if}
			</section>

			<section>
				<div class="lbl">Light &amp; color</div>
				{#each SLIDERS as s (s.key)}
					<label class="slider">
						<span>{s.label}</span>
						<input
							type="range"
							min={s.min}
							max={s.max}
							step={s.step}
							value={ops[s.key]}
							oninput={(e) => setSlider(s.key, Number(e.currentTarget.value))}
						/>
					</label>
				{/each}
			</section>

			<section>
				<div class="lbl">Filters</div>
				<div class="filters">
					{#each FILTERS as f (f)}
						<button class="filter" class:on={ops.filter === f} onclick={() => setFilter(f)}>{f}</button>
					{/each}
				</div>
			</section>
		</div>

		{#if msg}<p class="msg">{msg}</p>{/if}

		<footer>
			<button class="ghost" onclick={reset} title="Reset adjustments"><Undo2 size={15} /> Reset</button>
			<button class="ghost" onclick={revert} disabled={busy} title="Revert to original">Revert</button>
			<button class="ghost" onclick={exportCopy} disabled={busy} title="Save edited copy"><Download size={15} /> Copy</button>
			<button class="save" onclick={save} disabled={busy}><Save size={15} /> {busy ? 'Saving…' : 'Save'}</button>
		</footer>
	</aside>
</div>

<style>
	.edit-overlay {
		position: absolute;
		inset: 0;
		z-index: 6;
		display: flex;
		background: #0b0c0e;
	}
	.stage {
		flex: 1;
		min-width: 0;
		position: relative;
		display: flex;
		align-items: center;
		justify-content: center;
		overflow: hidden;
		touch-action: none;
	}
	.preview {
		max-width: 94%;
		max-height: 94%;
		object-fit: contain;
		user-select: none;
	}
	/* Crop overlay sits over the displayed (exif-oriented) image box. */
	.crop-mask {
		position: absolute;
		inset: 0;
		pointer-events: none;
	}
	.crop-box {
		position: absolute;
		border: 1px solid rgba(255, 255, 255, 0.9);
		box-shadow: 0 0 0 9999px rgba(0, 0, 0, 0.5);
		cursor: move;
	}
	.crop-box .h {
		position: absolute;
		width: 14px;
		height: 14px;
		background: #fff;
		border-radius: 2px;
	}
	.h.nw { left: -7px; top: -7px; cursor: nwse-resize; }
	.h.ne { right: -7px; top: -7px; cursor: nesw-resize; }
	.h.sw { left: -7px; bottom: -7px; cursor: nesw-resize; }
	.h.se { right: -7px; bottom: -7px; cursor: nwse-resize; }
	.panel {
		width: 300px;
		max-width: 84vw;
		flex-shrink: 0;
		background: #121316;
		color: var(--lg-overlay-text);
		border-left: 1px solid var(--lg-overlay-border);
		display: flex;
		flex-direction: column;
		padding: 12px 14px;
	}
	header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		margin-bottom: 8px;
	}
	h2 { font-size: 1.05rem; font-weight: 600; }
	.x { border: none; background: transparent; color: var(--lg-overlay-muted); cursor: pointer; padding: 6px; border-radius: var(--lg-r-sm); }
	.x:hover { background: var(--lg-overlay-hover); }
	.controls { flex: 1; overflow-y: auto; }
	section { padding: 10px 0; border-bottom: 1px solid rgb(255 255 255 / 0.07); }
	.lbl { font-size: 0.7rem; text-transform: uppercase; letter-spacing: 0.04em; color: var(--lg-overlay-muted); margin-bottom: 8px; }
	.btn-row { display: flex; gap: 6px; }
	.btn-row button, .chip, .filter {
		border: 1px solid var(--lg-overlay-border);
		background: rgb(255 255 255 / 0.05);
		color: var(--lg-overlay-text);
		border-radius: var(--lg-r-sm);
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
	}
	.btn-row button { width: 38px; height: 34px; }
	.btn-row button.on, .filter.on { background: var(--lg-accent); border-color: var(--lg-accent); color: #fff; }
	.aspects { display: flex; flex-wrap: wrap; gap: 6px; margin-top: 8px; }
	.chip { padding: 4px 10px; font-size: 0.78rem; }
	.slider { display: flex; flex-direction: column; gap: 3px; margin-bottom: 9px; font-size: 0.8rem; color: var(--lg-overlay-muted); }
	.slider input { width: 100%; accent-color: var(--lg-accent); }
	.filters { display: grid; grid-template-columns: repeat(3, 1fr); gap: 6px; }
	.filter { padding: 7px 4px; font-size: 0.75rem; text-transform: capitalize; }
	.msg { font-size: 0.8rem; color: #34d399; padding: 6px 0; }
	footer { display: flex; flex-wrap: wrap; gap: 6px; padding-top: 10px; }
	.ghost, .save {
		display: flex;
		align-items: center;
		gap: 5px;
		border: none;
		border-radius: var(--lg-r-sm);
		padding: 8px 10px;
		cursor: pointer;
		font-size: 0.82rem;
		font-weight: 500;
	}
	.ghost { background: rgb(255 255 255 / 0.08); color: var(--lg-overlay-text); }
	.ghost:hover { background: rgb(255 255 255 / 0.16); }
	.save { background: var(--lg-accent); color: #fff; margin-left: auto; }
	.save:disabled, .ghost:disabled { opacity: 0.6; cursor: default; }
	@media (max-width: 640px) {
		.edit-overlay { flex-direction: column; }
		.panel { width: 100%; max-width: 100%; border-left: none; border-top: 1px solid var(--lg-overlay-border); max-height: 52%; }
	}
</style>
```

### `src/lib/components/lightbox/InfoPanel.svelte`

```svelte
<script lang="ts">
	import type { MediaDetail, Tag } from '$shared/types';
	import { formatBytes, formatDateTime, formatDuration } from '$shared/format';
	import { api } from '$client/api';
	import { onMount, untrack } from 'svelte';
	import { X, Camera, Calendar, MapPin, FileText, HardDrive, Ruler, Star, Flag, Ban, Tag as TagIcon } from '@lucide/svelte';

	let {
		detail,
		onClose,
		onUpdate
	}: { detail: MediaDetail; onClose: () => void; onUpdate: (d: MediaDetail) => void } = $props();

	const dims = $derived(detail.width && detail.height ? `${detail.width} × ${detail.height}` : '—');

	let caption = $state(untrack(() => detail.caption ?? ''));
	let savingCaption = $state(false);
	let newTag = $state('');
	let allTags = $state<Tag[]>([]);
	let hoverStar = $state(0);

	// Keep the caption box in sync when the lightbox advances to another item.
	$effect(() => {
		caption = detail.caption ?? '';
	});

	onMount(async () => {
		try {
			allTags = (await api.tags()).tags;
		} catch {
			allTags = [];
		}
	});

	async function saveCaption() {
		const next = caption.trim();
		if (next === (detail.caption ?? '')) return;
		savingCaption = true;
		try {
			onUpdate(await api.updateMedia(detail.id, { caption: next || null }));
		} catch {
			/* leave the text as typed */
		} finally {
			savingCaption = false;
		}
	}

	async function setRating(r: number) {
		const next = detail.rating === r ? 0 : r; // click the current star to clear
		try {
			onUpdate(await api.updateMedia(detail.id, { rating: next }));
		} catch {
			/* ignore */
		}
	}

	async function setPick(p: number) {
		const next = detail.pick === p ? 0 : p;
		try {
			onUpdate(await api.updateMedia(detail.id, { pick: next }));
		} catch {
			/* ignore */
		}
	}

	async function addTag() {
		const name = newTag.trim();
		if (!name) return;
		newTag = '';
		try {
			const { tags } = await api.addMediaTag(detail.id, { name });
			onUpdate({ ...detail, tags });
			allTags = (await api.tags()).tags;
		} catch {
			/* ignore */
		}
	}

	async function removeTag(tagId: number) {
		try {
			const { tags } = await api.removeMediaTag(detail.id, tagId);
			onUpdate({ ...detail, tags });
		} catch {
			/* ignore */
		}
	}
</script>

<aside class="panel" aria-label="Media information">
	<header>
		<h2>Info</h2>
		<button onclick={onClose} aria-label="Close info"><X size={18} /></button>
	</header>

	<!-- Organize: rating · pick/reject · caption · tags -->
	<section class="organize">
		<div class="stars" role="group" aria-label="Rating">
			{#each [1, 2, 3, 4, 5] as n (n)}
				<button
					class="star"
					class:active={(hoverStar || detail.rating) >= n}
					onmouseenter={() => (hoverStar = n)}
					onmouseleave={() => (hoverStar = 0)}
					onclick={() => setRating(n)}
					title={`${n} star${n > 1 ? 's' : ''}`}
					aria-label={`Rate ${n}`}
				>
					<Star size={20} fill={(hoverStar || detail.rating) >= n ? 'currentColor' : 'none'} />
				</button>
			{/each}
		</div>
		<div class="flags">
			<button class="flag pick" class:on={detail.pick === 1} onclick={() => setPick(1)} title="Pick (P)">
				<Flag size={15} /> Pick
			</button>
			<button class="flag reject" class:on={detail.pick === -1} onclick={() => setPick(-1)} title="Reject (X)">
				<Ban size={15} /> Reject
			</button>
		</div>
		<label class="caption">
			<span class="lbl">Caption {#if savingCaption}<em>saving…</em>{/if}</span>
			<textarea
				bind:value={caption}
				rows="2"
				placeholder="Add a description…"
				onblur={saveCaption}
				onkeydown={(e) => {
					if (e.key === 'Enter' && (e.ctrlKey || e.metaKey)) {
						e.preventDefault();
						(e.currentTarget as HTMLTextAreaElement).blur();
					}
				}}
			></textarea>
		</label>
		<div class="tags">
			<span class="lbl"><TagIcon size={13} /> Tags</span>
			<div class="chips">
				{#each detail.tags as t (t.id)}
					<span class="chip">{t.name}<button onclick={() => removeTag(t.id)} aria-label={`Remove ${t.name}`}><X size={12} /></button></span>
				{/each}
			</div>
			<input
				class="tag-input"
				bind:value={newTag}
				list="lg-all-tags"
				placeholder="Add tag + Enter"
				onkeydown={(e) => e.key === 'Enter' && addTag()}
			/>
			<datalist id="lg-all-tags">
				{#each allTags as t (t.id)}<option value={t.name}></option>{/each}
			</datalist>
		</div>
	</section>

	<dl>
		<div class="row">
			<dt><FileText size={16} /> File</dt>
			<dd>
				{detail.filename}
				<span class="muted">{detail.type}{detail.durationMs ? ` · ${formatDuration(detail.durationMs)}` : ''}</span>
			</dd>
		</div>
		<div class="row">
			<dt><Calendar size={16} /> Taken</dt>
			<dd>
				{formatDateTime(detail.takenMs)}
				<span class="muted">({detail.takenSource === 'exif' ? 'from EXIF' : 'from file date'})</span>
			</dd>
		</div>
		<div class="row">
			<dt><Ruler size={16} /> Dimensions</dt>
			<dd>{dims}</dd>
		</div>
		<div class="row">
			<dt><HardDrive size={16} /> Size</dt>
			<dd>{formatBytes(detail.sizeBytes)}</dd>
		</div>
		{#if detail.cameraMake || detail.cameraModel}
			<div class="row">
				<dt><Camera size={16} /> Camera</dt>
				<dd>
					{[detail.cameraMake, detail.cameraModel].filter(Boolean).join(' ')}
					{#if detail.lens}<span class="muted">{detail.lens}</span>{/if}
				</dd>
			</div>
		{/if}
		{#if detail.hasGps && detail.gpsLat != null && detail.gpsLon != null}
			<div class="row">
				<dt><MapPin size={16} /> Location</dt>
				<dd>
					{#if detail.placeLocality}
						<a class="link" href="/places">{[detail.placeLocality, detail.placeCountry].filter(Boolean).join(', ')}</a>
						<br />
					{/if}
					<span class="muted">{detail.gpsLat.toFixed(5)}, {detail.gpsLon.toFixed(5)}</span>
					<a class="muted link" href="/map?lat={detail.gpsLat}&lon={detail.gpsLon}">View on map</a>
				</dd>
			</div>
		{/if}
		{#if detail.albums.length}
			<div class="row">
				<dt><FileText size={16} /> Albums</dt>
				<dd>{detail.albums.map((a) => a.name).join(', ')}</dd>
			</div>
		{/if}
		<div class="row path">
			<dt>Path</dt>
			<dd><code>{detail.path}</code></dd>
		</div>
	</dl>
</aside>

<style>
	/* Lives inside the always-dark lightbox → uses the dark overlay tokens (not theme surfaces). */
	.panel {
		position: absolute;
		top: 0;
		right: 0;
		height: 100%;
		width: 340px;
		max-width: 90vw;
		background: #121316;
		color: var(--lg-overlay-text);
		border-left: 1px solid var(--lg-overlay-border);
		padding: 12px 16px;
		overflow-y: auto;
		z-index: 4;
		box-shadow: var(--lg-shadow-3);
		animation: panel-in var(--lg-dur-base) var(--lg-ease);
	}
	@keyframes panel-in {
		from {
			transform: translateX(20px);
			opacity: 0;
		}
	}
	header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		margin-bottom: 10px;
	}
	h2 {
		font-size: 1.05rem;
		font-weight: 600;
	}
	header button {
		border: none;
		background: transparent;
		color: var(--lg-overlay-muted);
		cursor: pointer;
		padding: 6px;
		border-radius: var(--lg-r-sm);
	}
	header button:hover {
		background: var(--lg-overlay-hover);
	}
	.organize {
		padding-bottom: 12px;
		margin-bottom: 6px;
		border-bottom: 1px solid rgb(255 255 255 / 0.08);
		display: flex;
		flex-direction: column;
		gap: 10px;
	}
	.stars {
		display: flex;
		gap: 2px;
	}
	.star {
		border: none;
		background: transparent;
		color: #6b7280;
		cursor: pointer;
		padding: 2px;
		border-radius: var(--lg-r-sm);
	}
	.star.active {
		color: #fde047;
	}
	.flags {
		display: flex;
		gap: 8px;
	}
	.flag {
		display: flex;
		align-items: center;
		gap: 5px;
		padding: 5px 10px;
		border-radius: var(--lg-r-sm);
		border: 1px solid var(--lg-overlay-border);
		background: transparent;
		color: var(--lg-overlay-muted);
		cursor: pointer;
		font-size: 0.8rem;
	}
	.flag.pick.on {
		background: #166534;
		border-color: #166534;
		color: #fff;
	}
	.flag.reject.on {
		background: #7f1d1d;
		border-color: #7f1d1d;
		color: #fff;
	}
	.lbl {
		display: flex;
		align-items: center;
		gap: 5px;
		font-size: 0.72rem;
		text-transform: uppercase;
		letter-spacing: 0.04em;
		color: var(--lg-overlay-muted);
		margin-bottom: 4px;
	}
	.lbl em {
		text-transform: none;
		letter-spacing: 0;
		color: #9ca3af;
	}
	.caption textarea {
		width: 100%;
		resize: vertical;
		background: rgb(255 255 255 / 0.06);
		color: var(--lg-overlay-text);
		border: 1px solid var(--lg-overlay-border);
		border-radius: var(--lg-r-sm);
		padding: 7px 9px;
		font: inherit;
		font-size: 0.85rem;
	}
	.chips {
		display: flex;
		flex-wrap: wrap;
		gap: 6px;
		margin-bottom: 6px;
	}
	.chip {
		display: flex;
		align-items: center;
		gap: 4px;
		padding: 3px 4px 3px 9px;
		border-radius: 999px;
		background: rgb(255 255 255 / 0.1);
		font-size: 0.8rem;
	}
	.chip button {
		display: flex;
		border: none;
		background: transparent;
		color: var(--lg-overlay-muted);
		cursor: pointer;
		padding: 2px;
		border-radius: 50%;
	}
	.chip button:hover {
		background: rgb(255 255 255 / 0.2);
		color: #fff;
	}
	.tag-input {
		width: 100%;
		background: rgb(255 255 255 / 0.06);
		color: var(--lg-overlay-text);
		border: 1px solid var(--lg-overlay-border);
		border-radius: var(--lg-r-sm);
		padding: 6px 9px;
		font-size: 0.85rem;
	}
	dl {
		margin: 0;
	}
	.row {
		padding: 9px 0;
		border-bottom: 1px solid rgb(255 255 255 / 0.06);
	}
	dt {
		display: flex;
		align-items: center;
		gap: 7px;
		font-size: 0.72rem;
		text-transform: uppercase;
		letter-spacing: 0.04em;
		color: var(--lg-overlay-muted);
		margin-bottom: 3px;
	}
	dd {
		margin: 0;
		font-size: 0.9rem;
		word-break: break-word;
	}
	.muted {
		color: var(--lg-overlay-muted);
		font-size: 0.82rem;
		margin-left: 4px;
	}
	.link {
		text-decoration: underline;
	}
	.path code {
		font-size: 0.78rem;
		color: #cbd5e1;
	}

	/* Bottom sheet on phones instead of an off-screen right drawer */
	@media (max-width: 640px) {
		.panel {
			top: auto;
			bottom: 0;
			right: 0;
			left: 0;
			width: 100%;
			max-width: 100%;
			height: auto;
			max-height: 70vh;
			border-left: none;
			border-top: 1px solid var(--lg-overlay-border);
			border-radius: var(--lg-r-xl) var(--lg-r-xl) 0 0;
			animation: sheet-in var(--lg-dur-base) var(--lg-ease);
		}
	}
	@keyframes sheet-in {
		from {
			transform: translateY(30px);
			opacity: 0;
		}
	}
</style>
```

### `src/lib/components/lightbox/Lightbox.svelte`

```svelte
<script lang="ts">
	import { onMount, tick } from 'svelte';
	import type { MediaDetail } from '$shared/types';
	import { gallery } from '$client/state/gallery.svelte';
	import { api } from '$client/api';
	import InfoPanel from './InfoPanel.svelte';
	import EditOverlay from './EditOverlay.svelte';
	import {
		X,
		ChevronLeft,
		ChevronRight,
		Star,
		Info,
		Trash2,
		Play,
		Pause,
		ZoomIn,
		ZoomOut,
		Download,
		Aperture,
		Pencil
	} from '@lucide/svelte';

	let { startId, onClose }: { startId: number; onClose: () => void } = $props();

	let index = $state(0);
	const current = $derived(gallery.items[index] ?? null);

	let showInfo = $state(false);
	let detail = $state<MediaDetail | null>(null);
	let editing = $state(false);
	// Cache-buster for an image whose edits were just saved (edited thumbs reuse the same id/mtime).
	let editBust = $state<{ id: number; v: number } | null>(null);
	let slideshow = $state(false);
	let slideTimer: ReturnType<typeof setInterval> | undefined;

	/** `?v=`/`&v=` suffix to force-reload the current image after its edits were saved. */
	const bustSuffix = $derived(editBust && current && editBust.id === current.id ? editBust.v : 0);

	// Image zoom/pan
	let scale = $state(1);
	let tx = $state(0);
	let ty = $state(0);
	let stage: HTMLDivElement;
	let videoEl: HTMLVideoElement | null = $state(null);
	let originalLoaded = $state(false);
	let motionOn = $state(false);

	const SLIDE_MS = 4000;

	// Codecs browsers generally play; anything else gets a "may not play" hint + download.
	const PLAYABLE = ['h264', 'avc', 'vp8', 'vp9', 'av1', 'av01', 'theora'];
	function isUnplayable(codec: string | null): boolean {
		if (!codec) return false;
		const c = codec.toLowerCase();
		return !PLAYABLE.some((p) => c.includes(p));
	}
	const unplayable = $derived(
		!!(current && current.type === 'video' && detail?.id === current.id && isUnplayable(detail.codec))
	);

	// Load EXIF/codec detail for videos (drives the codec banner) without needing the info panel.
	$effect(() => {
		const c = current;
		if (c?.type === 'video' && detail?.id !== c.id) loadDetail();
	});

	function clamp(v: number, lo: number, hi: number) {
		return Math.min(hi, Math.max(lo, v));
	}

	function resetZoom() {
		scale = 1;
		tx = 0;
		ty = 0;
	}

	async function go(delta: number) {
		const next = index + delta;
		if (next < 0 || next >= gallery.items.length) {
			if (next >= gallery.items.length && !gallery.done) {
				await gallery.loadMore();
				if (next >= gallery.items.length) return;
			} else return;
		}
		index = next;
		resetZoom();
		originalLoaded = false;
		motionOn = false;
		detail = null;
		if (showInfo) loadDetail();
		// prefetch more as we approach the end
		if (index >= gallery.items.length - 4 && !gallery.done) gallery.loadMore();
	}

	async function loadDetail() {
		if (!current) return;
		const id = current.id;
		try {
			const d = await api.detail(id);
			// Guard against a fast next/prev landing after this request was issued.
			if (current?.id === id) detail = d;
		} catch {
			/* ignore */
		}
	}

	function toggleInfo() {
		showInfo = !showInfo;
		if (showInfo && !detail) loadDetail();
	}

	async function openEdit() {
		if (!current || current.type !== 'photo') return;
		if (!detail || detail.id !== current.id) await loadDetail();
		editing = true;
	}

	function onEdited(d: MediaDetail, v: number) {
		detail = d;
		editBust = { id: d.id, v };
		// Reflect any aspect change from a crop in the grid so its layout updates.
		gallery.patchDims(d.id, d.width, d.height);
	}

	async function toggleFavorite() {
		if (!current) return;
		const fav = !current.isFavorite;
		gallery.patchFlags([current.id], { isFavorite: fav });
		try {
			await api.setFlags([current.id], { favorite: fav });
		} catch {
			gallery.patchFlags([current.id], { isFavorite: !fav }); // revert
		}
	}

	async function trashCurrent() {
		if (!current) return;
		const id = current.id;
		try {
			await api.trash([id]);
			gallery.remove([id]);
			if (gallery.items.length === 0) return onClose();
			if (index >= gallery.items.length) index = gallery.items.length - 1;
			resetZoom();
		} catch {
			/* ignore */
		}
	}

	function toggleSlideshow() {
		slideshow = !slideshow;
		clearInterval(slideTimer);
		if (slideshow) slideTimer = setInterval(() => go(1), SLIDE_MS);
	}

	// Rating / culling (keyboard 0-5, p, x). Loads detail as a side effect so the change is visible.
	async function setRating(r: number) {
		if (!current) return;
		const id = current.id;
		try {
			const d = await api.updateMedia(id, { rating: r });
			if (current?.id === id) detail = d;
		} catch {
			/* ignore */
		}
	}
	async function setPick(p: number) {
		if (!current) return;
		const id = current.id;
		const next = detail?.id === id && detail.pick === p ? 0 : p;
		try {
			const d = await api.updateMedia(id, { pick: next });
			if (current?.id === id) detail = d;
		} catch {
			/* ignore */
		}
	}

	function zoomAt(cx: number, cy: number, factor: number) {
		if (!stage) return;
		const rect = stage.getBoundingClientRect();
		const x = cx - rect.left - rect.width / 2;
		const y = cy - rect.top - rect.height / 2;
		const newScale = clamp(scale * factor, 1, 8);
		const ratio = newScale / scale;
		tx = x - (x - tx) * ratio;
		ty = y - (y - ty) * ratio;
		scale = newScale;
		if (scale === 1) {
			tx = 0;
			ty = 0;
		}
	}

	function onWheel(e: WheelEvent) {
		if (!current || current.type !== 'photo') return;
		e.preventDefault();
		zoomAt(e.clientX, e.clientY, e.deltaY < 0 ? 1.15 : 1 / 1.15);
	}

	// Pointer-based pan / swipe / pinch
	const pointers = new Map<number, { x: number; y: number }>();
	let pinchStartDist = 0;
	let pinchStartScale = 1;
	let panStart: { x: number; y: number; tx: number; ty: number } | null = null;
	let swipeStartX = 0;
	let pointerMoved = false; // distinguishes a drag/swipe from a background click-to-close
	let downX = 0;
	let downY = 0;

	function onPointerDown(e: PointerEvent) {
		(e.target as Element).setPointerCapture?.(e.pointerId);
		pointerMoved = false;
		downX = e.clientX;
		downY = e.clientY;
		pointers.set(e.pointerId, { x: e.clientX, y: e.clientY });
		if (pointers.size === 2) {
			const [a, b] = [...pointers.values()];
			pinchStartDist = Math.hypot(a.x - b.x, a.y - b.y);
			pinchStartScale = scale;
		} else if (scale > 1) {
			panStart = { x: e.clientX, y: e.clientY, tx, ty };
		} else {
			swipeStartX = e.clientX;
		}
	}

	function onPointerMove(e: PointerEvent) {
		if (!pointers.has(e.pointerId)) return;
		if (Math.abs(e.clientX - downX) > 6 || Math.abs(e.clientY - downY) > 6) pointerMoved = true;
		pointers.set(e.pointerId, { x: e.clientX, y: e.clientY });
		if (pointers.size === 2 && pinchStartDist > 0) {
			const [a, b] = [...pointers.values()];
			const dist = Math.hypot(a.x - b.x, a.y - b.y);
			const mid = { x: (a.x + b.x) / 2, y: (a.y + b.y) / 2 };
			const target = clamp((pinchStartScale * dist) / pinchStartDist, 1, 8);
			zoomAt(mid.x, mid.y, target / scale);
		} else if (panStart && scale > 1) {
			tx = panStart.tx + (e.clientX - panStart.x);
			ty = panStart.ty + (e.clientY - panStart.y);
		}
	}

	function onPointerUp(e: PointerEvent) {
		const start = swipeStartX;
		pointers.delete(e.pointerId);
		if (pointers.size < 2) pinchStartDist = 0;
		if (panStart) {
			panStart = null;
			return;
		}
		if (scale === 1 && start) {
			const dx = e.clientX - start;
			if (Math.abs(dx) > 60) go(dx < 0 ? 1 : -1);
		}
	}

	function dblclick(e: MouseEvent) {
		if (!current || current.type !== 'photo') return;
		if (scale > 1) resetZoom();
		else zoomAt(e.clientX, e.clientY, 2.2);
	}

	function onKey(e: KeyboardEvent) {
		// While the editor is open, it owns the keyboard; Escape closes it, nothing else leaks through.
		if (editing) {
			if (e.key === 'Escape') {
				e.preventDefault();
				editing = false;
			}
			return;
		}
		switch (e.key) {
			case 'Escape':
				onClose();
				break;
			case 'ArrowRight':
				go(1);
				break;
			case 'ArrowLeft':
				go(-1);
				break;
			case 'f':
			case 'F':
				toggleFavorite();
				break;
			case 'i':
			case 'I':
				toggleInfo();
				break;
			case 'Delete':
				trashCurrent();
				break;
			case '+':
			case '=':
				zoomAt(window.innerWidth / 2, window.innerHeight / 2, 1.3);
				break;
			case '-':
				zoomAt(window.innerWidth / 2, window.innerHeight / 2, 1 / 1.3);
				break;
			case ' ':
				if (current?.type === 'video' && videoEl) {
					e.preventDefault();
					videoEl.paused ? videoEl.play() : videoEl.pause();
				} else {
					e.preventDefault();
					toggleSlideshow();
				}
				break;
			case '0':
			case '1':
			case '2':
			case '3':
			case '4':
			case '5':
				setRating(Number(e.key));
				break;
			case 'p':
			case 'P':
				setPick(1);
				break;
			case 'x':
			case 'X':
				setPick(-1);
				break;
		}
	}

	let dialogEl: HTMLDivElement;
	onMount(() => {
		index = Math.max(0, gallery.indexOf(startId));
		const prevOverflow = document.body.style.overflow;
		document.body.style.overflow = 'hidden';
		tick().then(() => dialogEl?.focus());
		window.addEventListener('keydown', onKey);
		return () => {
			window.removeEventListener('keydown', onKey);
			clearInterval(slideTimer);
			document.body.style.overflow = prevOverflow;
		};
	});
</script>

<div
	class="overlay"
	bind:this={dialogEl}
	role="dialog"
	aria-modal="true"
	aria-label="Media viewer"
	tabindex="-1"
>
	<!-- Top toolbar -->
	<div class="toolbar">
		<button class="icon" onclick={onClose} title="Close (Esc)" aria-label="Close"><X size={22} /></button>
		<div class="spacer"></div>
		{#if current}
			<button class="icon" class:on={current.isFavorite} onclick={toggleFavorite} title="Favorite (f)" aria-label="Favorite">
				<Star size={20} fill={current.isFavorite ? 'currentColor' : 'none'} />
			</button>
			{#if current.livePartnerId != null}
				<button class="icon" class:on={motionOn} onclick={() => (motionOn = !motionOn)} title="Play motion (Live)" aria-label="Play motion photo"><Aperture size={20} /></button>
			{/if}
			{#if current.type === 'photo'}
				<button class="icon" onclick={openEdit} title="Edit" aria-label="Edit photo"><Pencil size={19} /></button>
			{/if}
			<button class="icon" onclick={toggleInfo} class:on={showInfo} title="Info (i)" aria-label="Info"><Info size={20} /></button>
			<a class="icon" href="/api/media/{current.id}/original" download title="Download" aria-label="Download"><Download size={20} /></a>
			<button class="icon" onclick={toggleSlideshow} title="Slideshow (space)" aria-label="Slideshow">
				{#if slideshow}<Pause size={20} />{:else}<Play size={20} />{/if}
			</button>
			{#if current.type === 'photo'}
				<button class="icon" onclick={() => zoomAt(innerWidth / 2, innerHeight / 2, 1.3)} title="Zoom in (+)" aria-label="Zoom in"><ZoomIn size={20} /></button>
				<button class="icon" onclick={() => zoomAt(innerWidth / 2, innerHeight / 2, 1 / 1.3)} title="Zoom out (-)" aria-label="Zoom out"><ZoomOut size={20} /></button>
			{/if}
			<button class="icon danger" onclick={trashCurrent} title="Trash (Del)" aria-label="Trash"><Trash2 size={20} /></button>
		{/if}
	</div>

	<!-- Nav arrows -->
	{#if index > 0}
		<button class="nav left" onclick={() => go(-1)} aria-label="Previous"><ChevronLeft size={34} /></button>
	{/if}
	{#if index < gallery.items.length - 1 || !gallery.done}
		<button class="nav right" onclick={() => go(1)} aria-label="Next"><ChevronRight size={34} /></button>
	{/if}

	<!-- Stage -->
	<div
		class="stage"
		bind:this={stage}
		onwheel={onWheel}
		onpointerdown={onPointerDown}
		onpointermove={onPointerMove}
		onpointerup={onPointerUp}
		onpointercancel={onPointerUp}
		ondblclick={dblclick}
		onclick={(e) => {
			// Click on the empty/black area (not the media/controls, and not the tail of a drag/swipe) closes.
			if (e.target === e.currentTarget && !pointerMoved) onClose();
		}}
		role="presentation"
	>
		{#if current}
			{#key current.id}
				{#if current.type === 'video'}
					<!-- svelte-ignore a11y_media_has_caption -->
					<video
						bind:this={videoEl}
						src="/api/media/{current.id}/stream"
						poster="/api/media/{current.id}/thumb?size=preview"
						controls
						autoplay
						playsinline
						preload="metadata"
						class="media"
					></video>
					{#if unplayable}
						<div class="codec-note" role="status">
							This video's format{detail?.codec ? ` (${detail.codec.toUpperCase()})` : ''} may not play in the
							browser.
							<a href="/api/media/{current.id}/original" download>Download instead</a>
						</div>
					{/if}
				{:else if motionOn && current.livePartnerId != null}
					<!-- svelte-ignore a11y_media_has_caption -->
					<video
						src="/api/media/{current.livePartnerId}/stream"
						poster="/api/media/{current.id}/thumb?size=preview"
						autoplay
						loop
						playsinline
						preload="metadata"
						class="media"
					></video>
				{:else}
					<img
						class="media preview"
						src="/api/media/{current.id}/thumb?size=preview{bustSuffix ? `&v=${bustSuffix}` : ''}"
						alt=""
						class:hidden={originalLoaded}
						style="transform: translate({tx}px,{ty}px) scale({scale});"
						draggable="false"
					/>
					<img
						class="media full"
						src="/api/media/{current.id}/original{bustSuffix ? `?v=${bustSuffix}` : ''}"
						alt=""
						class:loaded={originalLoaded}
						onload={() => (originalLoaded = true)}
						style="transform: translate({tx}px,{ty}px) scale({scale}); cursor: {scale > 1 ? 'grab' : 'auto'};"
						draggable="false"
					/>
				{/if}
			{/key}
		{/if}
	</div>

	{#if showInfo && detail}
		<InfoPanel {detail} onClose={() => (showInfo = false)} onUpdate={(d) => (detail = d)} />
	{/if}

	{#if editing && current && current.type === 'photo'}
		<EditOverlay
			id={current.id}
			src="/api/media/{current.id}/thumb?size=preview{bustSuffix ? `&v=${bustSuffix}` : ''}"
			initial={detail?.id === current.id ? detail.editOps : null}
			onClose={() => (editing = false)}
			onSaved={onEdited}
		/>
	{/if}
</div>

<style>
	.overlay {
		position: fixed;
		inset: 0;
		z-index: 100;
		background: rgba(0, 0, 0, 0.94);
		display: flex;
		align-items: center;
		justify-content: center;
		outline: none;
		animation: lgbox-in 0.18s var(--lg-ease, ease);
	}
	@keyframes lgbox-in {
		from {
			opacity: 0;
			transform: scale(0.985);
		}
	}
	.codec-note {
		position: absolute;
		bottom: 18px;
		left: 50%;
		transform: translateX(-50%);
		z-index: 3;
		display: flex;
		gap: 10px;
		align-items: center;
		padding: 9px 14px;
		border-radius: var(--lg-r-md);
		background: rgb(180 35 24 / 0.92);
		color: #fff;
		font-size: 0.85rem;
		box-shadow: var(--lg-shadow-2);
	}
	.codec-note a {
		color: #fff;
		text-decoration: underline;
		font-weight: 600;
	}
	.toolbar {
		position: absolute;
		top: 0;
		left: 0;
		right: 0;
		display: flex;
		align-items: center;
		gap: 4px;
		padding: 10px 14px;
		z-index: 3;
		background: linear-gradient(rgba(0, 0, 0, 0.5), transparent);
	}
	.spacer {
		flex: 1;
	}
	.icon {
		display: flex;
		align-items: center;
		justify-content: center;
		width: 40px;
		height: 40px;
		border-radius: 50%;
		border: none;
		background: transparent;
		color: #e5e7eb;
		cursor: pointer;
		text-decoration: none;
	}
	.icon:hover {
		background: rgba(255, 255, 255, 0.14);
	}
	.icon.on {
		color: #fde047;
	}
	.icon.danger:hover {
		background: rgba(220, 38, 38, 0.5);
		color: #fff;
	}
	.nav {
		position: absolute;
		top: 50%;
		transform: translateY(-50%);
		z-index: 3;
		width: 52px;
		height: 52px;
		border-radius: 50%;
		border: none;
		background: rgba(255, 255, 255, 0.1);
		color: #fff;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
	}
	.nav:hover {
		background: rgba(255, 255, 255, 0.22);
	}
	.nav.left {
		left: 16px;
	}
	.nav.right {
		right: 16px;
	}
	.stage {
		position: relative;
		width: 100%;
		height: 100%;
		display: flex;
		align-items: center;
		justify-content: center;
		overflow: hidden;
		touch-action: none;
	}
	.media {
		max-width: 96vw;
		max-height: 96vh;
		object-fit: contain;
		user-select: none;
	}
	img.media {
		position: absolute;
		transition: opacity 0.2s ease;
	}
	img.preview {
		filter: blur(1px);
	}
	img.preview.hidden {
		opacity: 0;
	}
	img.full {
		opacity: 0;
	}
	img.full.loaded {
		opacity: 1;
	}
	@media (prefers-reduced-motion: reduce) {
		img.media {
			transition: none;
		}
	}
</style>
```

### `src/lib/components/nav/Sidebar.svelte`

```svelte
<script lang="ts">
	import { page } from '$app/state';
	import {
		Images,
		Star,
		BookImage,
		FolderOpen,
		Search,
		MapPin,
		Globe,
		Users,
		Tag,
		CalendarHeart,
		CopyCheck,
		Archive,
		Trash2,
		Settings,
		Sun,
		Moon,
		MonitorSmartphone
	} from '@lucide/svelte';
	import { settings } from '$client/state/settings.svelte';
	import Logo from '$components/common/Logo.svelte';

	const links = [
		{ href: '/', label: 'Photos', icon: Images },
		{ href: '/favorites', label: 'Favorites', icon: Star },
		{ href: '/albums', label: 'Albums', icon: BookImage },
		{ href: '/folders', label: 'Folders', icon: FolderOpen },
		{ href: '/search', label: 'Search', icon: Search },
		{ href: '/map', label: 'Map', icon: MapPin },
		{ href: '/places', label: 'Places', icon: Globe },
		{ href: '/people', label: 'People', icon: Users },
		{ href: '/tags', label: 'Tags', icon: Tag },
		{ href: '/memories', label: 'Memories', icon: CalendarHeart },
		{ href: '/duplicates', label: 'Duplicates', icon: CopyCheck },
		{ href: '/archive', label: 'Archive', icon: Archive },
		{ href: '/trash', label: 'Trash', icon: Trash2 }
	];

	function isActive(href: string): boolean {
		const path = page.url.pathname;
		return href === '/' ? path === '/' : path.startsWith(href);
	}

	const ThemeIcon = $derived(
		settings.theme === 'light' ? Sun : settings.theme === 'dark' ? Moon : MonitorSmartphone
	);
</script>

<nav class="sidebar" aria-label="Main navigation">
	<a href="/" class="brand">
		<Logo size={26} />
		<span class="brand-name">LGallery</span>
	</a>

	<ul class="links">
		{#each links as link (link.href)}
			<li>
				<a href={link.href} class:active={isActive(link.href)} aria-current={isActive(link.href) ? 'page' : undefined}>
					<link.icon size={20} strokeWidth={2} />
					<span>{link.label}</span>
				</a>
			</li>
		{/each}
	</ul>

	<div class="footer">
		<button class="theme" type="button" onclick={() => settings.cycleTheme()} title="Toggle theme ({settings.theme})">
			<ThemeIcon size={20} />
			<span class="cap">{settings.theme}</span>
		</button>
		<a href="/settings" class:active={isActive('/settings')}>
			<Settings size={20} />
			<span>Settings</span>
		</a>
	</div>
</nav>

<style>
	.sidebar {
		display: flex;
		flex-direction: column;
		width: 216px;
		flex-shrink: 0;
		height: 100vh;
		padding: 14px 10px;
		border-right: 1px solid var(--lg-border);
		background: var(--lg-surface-2);
		overflow-y: auto;
	}
	.brand {
		display: flex;
		align-items: center;
		gap: 10px;
		padding: 6px 8px 14px;
		text-decoration: none;
		color: inherit;
	}
	.brand :global(svg) {
		border-radius: 7px;
		flex-shrink: 0;
	}
	.brand-name {
		font-weight: 700;
		font-size: 1.1rem;
		letter-spacing: -0.01em;
	}
	.links {
		list-style: none;
		margin: 0;
		padding: 0;
		display: flex;
		flex-direction: column;
		gap: 2px;
		flex: 1;
	}
	a,
	.theme {
		position: relative;
		display: flex;
		align-items: center;
		gap: 11px;
		padding: 9px 10px;
		border-radius: var(--lg-r-md);
		text-decoration: none;
		color: var(--lg-text-muted);
		font-size: 0.92rem;
		font-weight: 500;
		width: 100%;
		border: none;
		background: none;
		cursor: pointer;
		text-align: left;
		transition:
			background var(--lg-dur-fast) var(--lg-ease),
			color var(--lg-dur-fast) var(--lg-ease);
	}
	.links a:hover,
	.theme:hover,
	.footer a:hover {
		background: var(--lg-surface-hover);
		color: var(--lg-text);
	}
	.links a.active,
	.footer a.active {
		background: var(--lg-accent-weak);
		color: var(--lg-accent);
		font-weight: 600;
	}
	/* active indicator bar */
	.links a.active::before,
	.footer a.active::before {
		content: '';
		position: absolute;
		left: 2px;
		top: 50%;
		transform: translateY(-50%);
		width: 3px;
		height: 18px;
		border-radius: 999px;
		background: var(--lg-accent);
	}
	.footer {
		border-top: 1px solid var(--lg-border);
		padding-top: 8px;
		margin-top: 8px;
		display: flex;
		flex-direction: column;
		gap: 2px;
	}
	.cap {
		text-transform: capitalize;
	}
	@media (max-width: 700px) {
		.sidebar {
			width: 64px;
		}
		.brand-name,
		.links span,
		.footer span,
		.cap {
			display: none;
		}
	}
</style>
```

### `src/lib/server/ai/aiService.ts`

```ts
/**
 * On-device AI (OFF by default). Local CLIP image/text embeddings for semantic search via
 * @huggingface/transformers + sqlite-vec. Both are OPTIONAL dependencies — enabling AI in
 * Settings expects them installed (and a one-time model download unless models are pre-placed
 * in data/models with ai.modelSource="local"). No images ever leave the machine.
 *
 *   npm i @huggingface/transformers sqlite-vec
 *
 * Face grouping is structured here too; the detector model wiring is the marked integration
 * point (faces are heavier: detect -> align -> embed -> cluster).
 */
import { getDb, type DB } from '../db/index';
import { getConfig } from '../config/configService';
import { ensureVectorTable, upsertEmbedding, searchEmbeddings, hasEmbedding } from './vectorIndex';
import { getAiState, patchAi, type AiKind } from './aiState';
import { mapTimelineRow } from '../db/queries';
import { FACES_SQL } from '../db/schema';
import { optionalImport } from './optional';
import { log } from '../log';
import type { TimelineItem } from '$shared/types';

/* eslint-disable @typescript-eslint/no-explicit-any */
let clip: { model: any; processor: any; tokenizer: any; RawImage: any } | null = null;
const stopRequested: Record<AiKind, boolean> = { semantic: false, faces: false };
const running: Record<AiKind, boolean> = { semantic: false, faces: false };

const CLIP_ID = 'Xenova/clip-vit-base-patch32';

export async function aiAvailable(): Promise<boolean> {
	try {
		await optionalImport('@huggingface/transformers');
		return true;
	} catch {
		return false;
	}
}

async function loadClip(): Promise<typeof clip> {
	if (clip) return clip;
	const t = await optionalImport('@huggingface/transformers');
	const cfg = getConfig().ai;
	t.env.allowRemoteModels = cfg.modelSource !== 'local';
	t.env.localModelPath = cfg.modelsDir;
	t.env.cacheDir = cfg.modelsDir;
	const [model, processor, tokenizer] = await Promise.all([
		t.CLIPModel.from_pretrained(CLIP_ID),
		t.AutoProcessor.from_pretrained(CLIP_ID),
		t.AutoTokenizer.from_pretrained(CLIP_ID)
	]);
	clip = { model, processor, tokenizer, RawImage: t.RawImage };
	return clip;
}

function normalize(v: Float32Array): Float32Array {
	let n = 0;
	for (const x of v) n += x * x;
	n = Math.sqrt(n) || 1;
	const out = new Float32Array(v.length);
	for (let i = 0; i < v.length; i++) out[i] = v[i] / n;
	return out;
}

async function embedImage(path: string): Promise<Float32Array> {
	const c = await loadClip();
	const image = await c!.RawImage.read(path);
	const inputs = await c!.processor(image);
	const out = await c!.model.get_image_features(inputs);
	return normalize(Float32Array.from(out.data as number[]));
}

export async function embedText(text: string): Promise<Float32Array> {
	const c = await loadClip();
	const inputs = c!.tokenizer([text], { padding: true, truncation: true });
	const out = await c!.model.get_text_features(inputs);
	return normalize(Float32Array.from(out.data as number[]));
}

/** Start the semantic (CLIP) indexer in the background. Resumable, newest-first. */
export async function startSemanticIndex(): Promise<void> {
	if (running.semantic) return;
	if (!(await aiAvailable())) {
		patchAi('semantic', { phase: 'unavailable', error: 'Install @huggingface/transformers + sqlite-vec to enable.' });
		return;
	}
	running.semantic = true;
	stopRequested.semantic = false;
	void (async () => {
		const db = getDb();
		try {
			patchAi('semantic', { phase: 'loading-model', error: null });
			const ok = await ensureVectorTable(db);
			if (!ok) {
				patchAi('semantic', { phase: 'unavailable', error: 'sqlite-vec not installed.' });
				return;
			}
			await loadClip();
			const photos = db
				.prepare(`SELECT id, path FROM media WHERE type='photo' AND is_trashed=0 AND meta_status=2 ORDER BY taken_ms DESC`)
				.all() as { id: number; path: string }[];
			patchAi('semantic', { phase: 'indexing', total: photos.length, done: 0 });
			let done = 0;
			for (const p of photos) {
				if (stopRequested.semantic) break;
				if (!hasEmbedding(db, p.id)) {
					try {
						const vec = await embedImage(p.path);
						upsertEmbedding(db, p.id, vec);
					} catch (e) {
						log.debug(`embed failed for ${p.id}`, e);
					}
				}
				patchAi('semantic', { done: ++done });
			}
			patchAi('semantic', { phase: stopRequested.semantic ? 'idle' : 'done' });
		} catch (e) {
			patchAi('semantic', { phase: 'error', error: e instanceof Error ? e.message : String(e) });
			log.error('semantic index failed', e);
		} finally {
			running.semantic = false;
		}
	})();
}

/**
 * Face grouping: detect -> embed -> cluster. The detector/embedder model wiring is the
 * integration point; the table + status plumbing are in place so it can be enabled cleanly.
 */
export async function startFaceIndex(): Promise<void> {
	const db = getDb();
	db.exec(FACES_SQL); // ensure tables exist
	patchAi('faces', {
		phase: 'unavailable',
		error: 'Face detection model not yet wired (see aiService.ts). Tables are ready.'
	});
	log.info('Face grouping requested — detector integration is the remaining step.');
}

export function stopIndex(kind: AiKind): void {
	stopRequested[kind] = true;
}

export function aiStatus() {
	return getAiState();
}

/** Semantic search: embed the query and KNN over the vec index. Returns timeline items. */
export async function semanticSearch(query: string, k = 200): Promise<TimelineItem[]> {
	const db = getDb();
	if (!(await ensureVectorTable(db))) return [];
	const vec = await embedText(query);
	const hits = searchEmbeddings(db, vec, k);
	if (!hits.length) return [];
	const byId = new Map(hits.map((h, i) => [h.media_id, i]));
	const ph = hits.map(() => '?').join(',');
	const rows = db
		.prepare(
			`SELECT id, type, width, height, taken_ms, taken_local_day, duration_ms, blurhash, is_favorite, live_partner_id, thumb_status
			 FROM media WHERE id IN (${ph}) AND is_trashed=0`
		)
		.all(...hits.map((h) => h.media_id)) as any[];
	return rows
		.map(mapTimelineRow)
		.sort((a, b) => (byId.get(a.id) ?? 0) - (byId.get(b.id) ?? 0));
}

/** People clusters (empty until face grouping runs). */
export function getPeople(db: DB) {
	try {
		return db
			.prepare(
				`SELECT fc.id, fc.label, fc.cover_face_id AS coverFaceId,
				        (SELECT COUNT(*) FROM faces f WHERE f.cluster_id=fc.id) AS count
				 FROM face_clusters fc ORDER BY count DESC`
			)
			.all();
	} catch {
		return []; // faces tables not created yet
	}
}
```

### `src/lib/server/ai/aiState.ts`

```ts
/** In-memory AI indexing progress, exposed via GET /api/ai/status. */
export type AiKind = 'semantic' | 'faces';
export type AiPhase = 'idle' | 'loading-model' | 'indexing' | 'done' | 'error' | 'unavailable';

export interface AiKindState {
	phase: AiPhase;
	done: number;
	total: number;
	error: string | null;
}

const state: Record<AiKind, AiKindState> = {
	semantic: { phase: 'idle', done: 0, total: 0, error: null },
	faces: { phase: 'idle', done: 0, total: 0, error: null }
};

export function getAiState() {
	return { semantic: { ...state.semantic }, faces: { ...state.faces } };
}

export function patchAi(kind: AiKind, p: Partial<AiKindState>): void {
	Object.assign(state[kind], p);
}
```

### `src/lib/server/ai/optional.ts`

```ts
/**
 * Import an OPTIONAL dependency at runtime. The specifier is passed as a parameter so the
 * bundler can't statically resolve it — absent packages simply throw at call time (caught by
 * callers), instead of breaking the build. Used for the heavy, opt-in AI deps.
 */
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export function optionalImport(name: string): Promise<any> {
	return import(/* @vite-ignore */ name);
}
```

### `src/lib/server/ai/vectorIndex.ts`

```ts
/**
 * sqlite-vec vector index for CLIP image embeddings. Loaded lazily and only when AI semantic
 * search is enabled. sqlite-vec is an OPTIONAL dependency — install it to use semantic search:
 *   npm i sqlite-vec
 * The dynamic specifier is concatenated so the bundler/TS don't treat it as required.
 */
import type { DB } from '../db/index';
import { EMBEDDINGS_SQL } from '../db/schema';
import { optionalImport } from './optional';
import { log } from '../log';

const ready = new WeakSet<DB>();

export async function ensureVectorTable(db: DB): Promise<boolean> {
	if (ready.has(db)) return true;
	try {
		const mod = await optionalImport('sqlite-vec');
		const load = (mod.load ?? mod.default?.load) as (db: unknown) => void;
		load(db);
		db.exec(EMBEDDINGS_SQL);
		ready.add(db);
		return true;
	} catch (e) {
		log.warn('sqlite-vec is not available — semantic search disabled. `npm i sqlite-vec` to enable.', e);
		return false;
	}
}

export function upsertEmbedding(db: DB, mediaId: number, vec: Float32Array): void {
	const buf = Buffer.from(vec.buffer, vec.byteOffset, vec.byteLength);
	db.prepare(`INSERT OR REPLACE INTO embeddings(media_id, embedding) VALUES(?, ?)`).run(mediaId, buf);
}

export function searchEmbeddings(db: DB, vec: Float32Array, k: number): { media_id: number; distance: number }[] {
	const buf = Buffer.from(vec.buffer, vec.byteOffset, vec.byteLength);
	return db
		.prepare(`SELECT media_id, distance FROM embeddings WHERE embedding MATCH ? ORDER BY distance LIMIT ?`)
		.all(buf, k) as { media_id: number; distance: number }[];
}

export function hasEmbedding(db: DB, mediaId: number): boolean {
	try {
		return !!db.prepare(`SELECT 1 FROM embeddings WHERE media_id=?`).get(mediaId);
	} catch {
		return false;
	}
}
```

### `src/lib/server/config/configService.test.ts`

```ts
import { describe, it, expect } from 'vitest';
import { parseConfig, canonicalHash } from './configService';

describe('parseConfig', () => {
	it('applies defaults and normalizes root paths', () => {
		const cfg = parseConfig({ roots: [{ path: 'D:\\Photos' }] });
		expect(cfg.roots[0].path).toBe('d:/Photos');
		expect(cfg.roots[0].enabled).toBe(true);
		expect(cfg.include).toEqual(['**/*']);
		expect(cfg.imageExtensions).toContain('jpg');
		expect(cfg.scan.onStartup).toBe(true);
		expect(cfg.thumbnails.grid.longEdge).toBe(320);
		expect(cfg.ai.semanticSearch).toBe(false);
	});

	it('lower-cases, strips dots, and de-dupes extensions', () => {
		const cfg = parseConfig({
			roots: [{ path: 'D:/P' }],
			imageExtensions: ['JPG', 'jpg', '.PNG', 'png']
		});
		expect(cfg.imageExtensions).toEqual(['jpg', 'png']);
	});

	it('rejects an empty roots array', () => {
		expect(() => parseConfig({ roots: [] })).toThrow(/at least one root/);
	});

	it('rejects an invalid host', () => {
		expect(() => parseConfig({ roots: [{ path: 'D:/P' }], server: { host: 'evil.example.com' } })).toThrow();
	});
});

describe('canonicalHash', () => {
	it('is independent of root and array ordering', () => {
		const a = parseConfig({
			roots: [
				{ path: 'D:/A' },
				{ path: 'D:/B' }
			],
			exclude: ['x', 'y']
		});
		const b = parseConfig({
			roots: [
				{ path: 'D:/B' },
				{ path: 'D:/A' }
			],
			exclude: ['y', 'x']
		});
		expect(canonicalHash(a)).toBe(canonicalHash(b));
	});

	it('changes when a root is enabled/disabled', () => {
		const a = parseConfig({ roots: [{ path: 'D:/A', enabled: true }] });
		const b = parseConfig({ roots: [{ path: 'D:/A', enabled: false }] });
		expect(canonicalHash(a)).not.toBe(canonicalHash(b));
	});

	it('ignores UI-only changes', () => {
		const a = parseConfig({ roots: [{ path: 'D:/A' }], ui: { theme: 'dark' } });
		const b = parseConfig({ roots: [{ path: 'D:/A' }], ui: { theme: 'light' } });
		expect(canonicalHash(a)).toBe(canonicalHash(b));
	});
});
```

### `src/lib/server/config/configService.ts`

```ts
/**
 * Reads / validates / hashes `lgallery.config.json`. The config is the single source
 * of media roots + settings; see docs/03-CONFIG.md.
 *
 * - On startup: load + validate (zod) + hash.
 * - On reload / Settings write: re-hash; a changed source-hash triggers an incremental rescan.
 */
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { configSchema, type LGalleryConfig } from '$shared/config-schema';
import { normalizePath } from '../paths';
import { hashPassword } from '../security';
import { log } from '../log';

const CONFIG_FILE = path.resolve(process.cwd(), 'lgallery.config.json');
const EXAMPLE_FILE = path.resolve(process.cwd(), 'lgallery.config.example.json');

let current: LGalleryConfig | null = null;
let currentHash = '';

export function getConfig(): LGalleryConfig {
	if (!current) throw new Error('config not loaded — call loadConfig() first');
	return current;
}

export function getConfigHash(): string {
	return currentHash;
}

/** Normalized, enabled root paths — the allow-list basis for path safety. */
export function getEnabledRoots(): string[] {
	return getConfig()
		.roots.filter((r) => r.enabled)
		.map((r) => normalizePath(r.path));
}

/** All normalized root paths (enabled or not). */
export function getAllRoots(): string[] {
	return getConfig().roots.map((r) => normalizePath(r.path));
}

/** Absolute trash dir (added to the allow-list so restores/permanent-deletes are permitted). */
export function getTrashDir(): string {
	return normalizePath(path.resolve(process.cwd(), getConfig().trash.dir));
}

/** Hash only the source-relevant fields; UI/logging changes must NOT trigger a rescan. */
export function canonicalHash(c: LGalleryConfig): string {
	const src = {
		roots: c.roots
			.map((r) => ({ path: normalizePath(r.path), enabled: r.enabled }))
			.sort((a, b) => (a.path < b.path ? -1 : a.path > b.path ? 1 : 0)),
		include: [...c.include].sort(),
		exclude: [...c.exclude].sort(),
		imageExtensions: [...c.imageExtensions].sort(),
		videoExtensions: [...c.videoExtensions].sort()
	};
	return crypto.createHash('sha256').update(JSON.stringify(src)).digest('hex');
}

/** Resolve a root to its canonical (long, real) path; fall back to lexical normalize if missing. */
function canonicalRoot(p: string): string {
	const norm = normalizePath(p);
	try {
		return normalizePath(fs.realpathSync.native(norm));
	} catch {
		return norm;
	}
}

function readRaw(): unknown {
	if (!fs.existsSync(CONFIG_FILE)) {
		// First run: seed from the example so the app is runnable out of the box.
		if (fs.existsSync(EXAMPLE_FILE)) {
			fs.copyFileSync(EXAMPLE_FILE, CONFIG_FILE);
			log.warn(`No lgallery.config.json found; seeded one from the example. Edit "roots" to point at your media.`);
		} else {
			throw new Error('lgallery.config.json is missing and no example file is present');
		}
	}
	// Strip a UTF-8 BOM if present (e.g. config saved by Notepad) so JSON.parse doesn't choke.
	const text = fs.readFileSync(CONFIG_FILE, 'utf8').replace(/^﻿/, '');
	return JSON.parse(text);
}

/** Parse + validate + normalize. Throws (with a readable message) on invalid config. */
export function parseConfig(raw: unknown): LGalleryConfig {
	const parsed = configSchema.safeParse(raw);
	if (!parsed.success) {
		const issues = parsed.error.issues
			.map((i) => `  • ${i.path.join('.') || '(root)'}: ${i.message}`)
			.join('\n');
		throw new Error(`Invalid lgallery.config.json:\n${issues}`);
	}
	const cfg = parsed.data;
	// Canonicalize root paths so the WHOLE system uses one form. On Windows, realpathSync.native
	// expands 8.3 short names (e.g. CLARK~1.BER → clark.bernales); without this, the scanner,
	// watcher (libuv fs-events asserts on 8.3 paths), and allow-list can disagree. Falls back to
	// the lexical normalized form for offline/missing roots.
	cfg.roots = cfg.roots.map((r) => ({ ...r, path: canonicalRoot(r.path) }));
	return cfg;
}

/** Warn (do not fail) about enabled roots that are missing/unreachable at this moment. */
function checkRoots(cfg: LGalleryConfig): void {
	for (const r of cfg.roots) {
		if (!r.enabled) continue;
		try {
			const st = fs.statSync(r.path);
			if (!st.isDirectory()) log.warn(`Root is not a directory (will be skipped): ${r.path}`);
		} catch {
			log.warn(`Root is currently unreachable (offline?); index for it will be retained: ${r.path}`);
		}
	}
}

export function loadConfig(): { config: LGalleryConfig; hash: string } {
	const cfg = parseConfig(readRaw());
	current = cfg;
	currentHash = canonicalHash(cfg);
	// (Re)initialize the logger from config the first time we have it.
	const lg = cfg.logging;
	import('../log').then(({ initLogger }) =>
		initLogger({ level: lg.level, file: lg.file, maxSizeMb: lg.maxSizeMb, maxFiles: lg.maxFiles })
	);
	checkRoots(cfg);
	return { config: cfg, hash: currentHash };
}

/**
 * Re-read the file and return whether the source-hash changed (drives reload-time rescan).
 * Cheap: parse + hash only.
 */
export function reloadIfChanged(): { changed: boolean; config: LGalleryConfig; hash: string } {
	const cfg = parseConfig(readRaw());
	const hash = canonicalHash(cfg);
	const changed = hash !== currentHash;
	current = cfg;
	currentHash = hash;
	return { changed, config: cfg, hash };
}

/** Hash any plaintext password into passwordHash so it's never stored in cleartext. */
function hashPlaintextPassword(cfg: LGalleryConfig): void {
	if (cfg.server.password) {
		cfg.server.passwordHash = hashPassword(cfg.server.password);
		cfg.server.password = null;
	}
}

/** Validate + atomically write a new config, then reload it. Returns the effective config. */
export function saveConfig(raw: unknown): { config: LGalleryConfig; hash: string; changed: boolean } {
	const cfg = parseConfig(raw);
	hashPlaintextPassword(cfg);
	const prevHash = currentHash;
	const tmp = CONFIG_FILE + '.tmp';
	// Write the normalized config (with hashed password) so cleartext never lands on disk.
	fs.writeFileSync(tmp, JSON.stringify(cfg, null, 2) + '\n', 'utf8');
	fs.renameSync(tmp, CONFIG_FILE);
	current = cfg;
	currentHash = canonicalHash(cfg);
	return { config: cfg, hash: currentHash, changed: currentHash !== prevHash };
}

/** If the on-disk config has a plaintext password, hash it and rewrite. Called at startup. */
export function migratePasswordIfNeeded(): void {
	const cfg = getConfig();
	if (cfg.server.password && !cfg.server.passwordHash) {
		log.info('Hashing plaintext server.password at rest.');
		saveConfig(cfg);
	}
}

/** The expected auth state for the current config. */
export function passwordHash(): string | null {
	return getConfig().server.passwordHash ?? null;
}

/** Config view safe to send to the client (no secrets). */
export function clientConfig(cfg: LGalleryConfig = getConfig()) {
	const { server, ...rest } = cfg;
	return {
		...rest,
		server: {
			host: server.host,
			port: server.port,
			sessionTtlHours: server.sessionTtlHours,
			passwordSet: Boolean(server.password || server.passwordHash)
		}
	};
}
```

### `src/lib/server/db/db.test.ts`

```ts
import { describe, it, expect } from 'vitest';
import { openTestDb } from './index';
import { TARGET_SCHEMA_VERSION } from './schema';

describe('migrations / schema', () => {
	it('applies all migrations and records the target schema version', () => {
		const db = openTestDb(':memory:');
		const v = db.prepare(`SELECT value FROM app_state WHERE key='schema_version'`).get() as {
			value: string;
		};
		expect(Number(v.value)).toBe(TARGET_SCHEMA_VERSION);
	});

	it('creates the core tables, indexes, and FTS table', () => {
		const db = openTestDb(':memory:');
		const names = (
			db.prepare(`SELECT name FROM sqlite_master WHERE type IN ('table','index')`).all() as {
				name: string;
			}[]
		).map((r) => r.name);
		for (const t of ['media', 'albums', 'album_items', 'trash', 'scans', 'roots', 'media_fts']) {
			expect(names).toContain(t);
		}
		expect(names).toContain('idx_media_timeline');
		expect(names).toContain('idx_media_day'); // migration v2
		expect(names).toContain('idx_media_retry'); // migration v3
	});

	it('adds the v3 retry columns with safe defaults', () => {
		const db = openTestDb(':memory:');
		const cols = (db.prepare(`PRAGMA table_info(media)`).all() as { name: string; dflt_value: string | null }[]);
		const byName = new Map(cols.map((c) => [c.name, c]));
		expect(byName.has('meta_attempts')).toBe(true);
		expect(byName.has('thumb_attempts')).toBe(true);
		expect(byName.has('next_retry_ms')).toBe(true);
		// New rows default to 0 attempts / NULL retry (lazy upgrade for existing libraries).
		db.prepare(`INSERT INTO roots(id,path,label,enabled) VALUES(1,'d:/r','R',1)`).run();
		db.prepare(
			`INSERT INTO media (id,path,root_id,rel_path,dir,filename,ext,type,size_bytes,mtime_ms,created_at,updated_at)
			 VALUES (1,'d:/r/a.jpg',1,'a.jpg','d:/r','a.jpg','jpg','photo',1,1,1,1)`
		).run();
		const row = db.prepare(`SELECT meta_attempts, thumb_attempts, next_retry_ms FROM media WHERE id=1`).get() as {
			meta_attempts: number;
			thumb_attempts: number;
			next_retry_ms: number | null;
		};
		expect(row.meta_attempts).toBe(0);
		expect(row.thumb_attempts).toBe(0);
		expect(row.next_retry_ms).toBeNull();
	});

	it('keeps the FTS index in sync via triggers (insert + search)', () => {
		const db = openTestDb(':memory:');
		db.prepare(`INSERT INTO roots(id,path,label,enabled) VALUES(1,'d:/r','R',1)`).run();
		db.prepare(
			`INSERT INTO media (id,path,root_id,rel_path,dir,filename,ext,type,size_bytes,mtime_ms,created_at,updated_at)
			 VALUES (1,'d:/r/sunset.jpg',1,'sunset.jpg','d:/r','sunset.jpg','jpg','photo',1,1,1,1)`
		).run();
		const hit = db.prepare(`SELECT rowid FROM media_fts WHERE media_fts MATCH 'sunset'`).get() as {
			rowid: number;
		};
		expect(hit.rowid).toBe(1);
	});
});
```

### `src/lib/server/db/index.ts`

```ts
/**
 * SQLite connection: opens the single DB file, applies performance pragmas
 * (docs/02-DATA-MODEL.md), runs migrations, and provides a singleton + graceful close.
 */
import path from 'node:path';
import fs from 'node:fs';
import Database from 'better-sqlite3';
import { runMigrations } from './migrate';
import { log } from '../log';

export type DB = Database.Database;

const DB_PATH = path.resolve(process.cwd(), 'data', 'lgallery.db');

let db: DB | null = null;

const PRAGMAS = [
	'PRAGMA journal_mode = WAL',
	'PRAGMA synchronous = NORMAL',
	'PRAGMA foreign_keys = ON',
	'PRAGMA temp_store = MEMORY',
	'PRAGMA cache_size = -65536', // ~64 MB
	'PRAGMA mmap_size = 268435456', // 256 MB
	'PRAGMA busy_timeout = 5000'
];

export function getDb(): DB {
	if (db) return db;
	fs.mkdirSync(path.dirname(DB_PATH), { recursive: true });
	const conn = new Database(DB_PATH);
	for (const p of PRAGMAS) conn.pragma(p.replace(/^PRAGMA\s+/i, ''));
	runMigrations(conn, DB_PATH);
	db = conn;
	log.info(`SQLite opened at ${DB_PATH} (WAL).`);
	return db;
}

/** For tests: open an isolated in-memory (or temp-file) DB with the full schema applied. */
export function openTestDb(file = ':memory:'): DB {
	const conn = new Database(file);
	if (file !== ':memory:') conn.pragma('journal_mode = WAL'); // WAL is a no-op for :memory:
	conn.pragma('foreign_keys = ON');
	runMigrations(conn, file);
	return conn;
}

/** Graceful shutdown: checkpoint the WAL so it doesn't grow unbounded, then close. */
export function closeDb(): void {
	if (!db) return;
	try {
		db.pragma('wal_checkpoint(TRUNCATE)');
	} catch (e) {
		log.warn('wal_checkpoint on shutdown failed', e);
	}
	db.close();
	db = null;
	log.info('SQLite closed.');
}
```

### `src/lib/server/db/migrate.ts`

```ts
/**
 * Startup migration runner. Applies any migrations newer than the stored
 * `app_state.schema_version`, each in its own transaction, with a backup-before-migrate
 * copy of the DB file (see docs/08-DATA-SAFETY.md).
 */
import fs from 'node:fs';
import type BetterSqlite3 from 'better-sqlite3';
import { MIGRATIONS, TARGET_SCHEMA_VERSION } from './schema';
import { log } from '../log';

function tableExists(db: BetterSqlite3.Database, name: string): boolean {
	const row = db
		.prepare(`SELECT 1 FROM sqlite_master WHERE type='table' AND name=?`)
		.get(name) as { 1: number } | undefined;
	return !!row;
}

function getSchemaVersion(db: BetterSqlite3.Database): number {
	if (!tableExists(db, 'app_state')) return 0;
	const row = db.prepare(`SELECT value FROM app_state WHERE key='schema_version'`).get() as
		| { value: string }
		| undefined;
	return row ? Number(row.value) : 0;
}

function setSchemaVersion(db: BetterSqlite3.Database, v: number): void {
	db.prepare(
		`INSERT INTO app_state(key, value) VALUES('schema_version', ?)
		 ON CONFLICT(key) DO UPDATE SET value=excluded.value`
	).run(String(v));
}

export function runMigrations(db: BetterSqlite3.Database, dbPath: string): void {
	const current = getSchemaVersion(db);
	if (current >= TARGET_SCHEMA_VERSION) {
		log.debug(`DB schema up to date (v${current}).`);
		return;
	}

	// Backup an existing, populated DB before changing its shape.
	if (current > 0 && dbPath !== ':memory:' && fs.existsSync(dbPath)) {
		const bak = `${dbPath}.bak-${current}`;
		try {
			// Fold the WAL into the main file first so the single-file copy is complete.
			db.pragma('wal_checkpoint(TRUNCATE)');
			fs.copyFileSync(dbPath, bak);
			log.info(`Backed up DB to ${bak} before migrating v${current} → v${TARGET_SCHEMA_VERSION}.`);
		} catch (e) {
			log.warn('Backup-before-migrate failed; proceeding with migration.', e);
		}
	}

	for (const m of MIGRATIONS) {
		if (m.version <= current) continue;
		log.info(`Applying migration v${m.version} (${m.name})…`);
		const tx = db.transaction(() => {
			db.exec(m.sql);
			setSchemaVersion(db, m.version);
		});
		tx();
	}
	log.info(`DB migrated to v${TARGET_SCHEMA_VERSION}.`);
}
```

### `src/lib/server/db/queries.test.ts`

```ts
import { describe, it, expect, beforeEach } from 'vitest';
import type { DB } from './index';
import { openTestDb } from './index';
import * as Q from './queries';
import { localDayFromMs } from '$shared/format';

let db: DB;
let nextId = 1;

interface MediaOverrides {
	id?: number;
	path?: string;
	filename?: string;
	dir?: string;
	rel_path?: string;
	ext?: string;
	type?: 'photo' | 'video';
	taken_ms?: number;
	taken_local_day?: string | null;
	camera_model?: string | null;
	quick_hash?: string | null;
	has_gps?: number;
	gps_lat?: number | null;
	gps_lon?: number | null;
	is_favorite?: number;
	is_archived?: number;
	is_trashed?: number;
	duration_ms?: number | null;
}

function add(o: MediaOverrides = {}): number {
	const id = o.id ?? nextId++;
	const filename = o.filename ?? `f${id}.jpg`;
	const dir = o.dir ?? 'd:/r';
	const taken = o.taken_ms ?? 1_000_000 + id;
	db.prepare(
		`INSERT INTO media (id, path, root_id, rel_path, dir, filename, ext, type, size_bytes, mtime_ms,
		   taken_ms, taken_local_day, taken_source, camera_model, quick_hash, has_gps, gps_lat, gps_lon,
		   is_favorite, is_archived, is_trashed, duration_ms, meta_status, thumb_status, created_at, updated_at)
		 VALUES (@id,@path,1,@rel,@dir,@filename,@ext,@type,1000,@taken,@taken,@day,'exif',@camera,@hash,
		   @gps,@lat,@lon,@fav,@arch,@trash,@dur,2,2,1000,1000)`
	).run({
		id,
		path: o.path ?? `${dir}/${filename}`,
		rel: o.rel_path ?? filename,
		dir,
		filename,
		ext: o.ext ?? 'jpg',
		type: o.type ?? 'photo',
		taken,
		day: o.taken_local_day ?? localDayFromMs(taken),
		camera: o.camera_model ?? null,
		hash: o.quick_hash ?? null,
		gps: o.has_gps ?? 0,
		lat: o.gps_lat ?? null,
		lon: o.gps_lon ?? null,
		fav: o.is_favorite ?? 0,
		arch: o.is_archived ?? 0,
		trash: o.is_trashed ?? 0,
		dur: o.duration_ms ?? null
	});
	return id;
}

beforeEach(() => {
	db = openTestDb(':memory:');
	db.prepare(`INSERT INTO roots(id, path, label, enabled) VALUES(1, 'd:/r', 'R', 1)`).run();
	nextId = 1;
	Q.bustBucketsCache(); // the meta cache is process-global — reset between tests
});

describe('getTimelinePage (keyset)', () => {
	it('returns newest-first and paginates with the cursor (happy path)', () => {
		for (let i = 0; i < 5; i++) add({ taken_ms: 100 + i });
		const p1 = Q.getTimelinePage(db, { limit: 2 });
		expect(p1.items.map((i) => i.takenMs)).toEqual([104, 103]);
		expect(p1.nextCursor).not.toBeNull();
		const p2 = Q.getTimelinePage(db, { ...p1.nextCursor!, limit: 2 });
		expect(p2.items.map((i) => i.takenMs)).toEqual([102, 101]);
	});
	it('breaks ties by id desc with no gaps/dupes', () => {
		add({ id: 1, taken_ms: 500 });
		add({ id: 2, taken_ms: 500 });
		add({ id: 3, taken_ms: 500 });
		const p = Q.getTimelinePage(db, { limit: 10 });
		expect(p.items.map((i) => i.id)).toEqual([3, 2, 1]);
		expect(p.nextCursor).toBeNull();
	});
	it('excludes trashed + archived', () => {
		add({ taken_ms: 1 });
		add({ taken_ms: 2, is_trashed: 1 });
		add({ taken_ms: 3, is_archived: 1 });
		expect(Q.getTimelinePage(db, { limit: 10 }).items).toHaveLength(1);
	});
	it('returns empty for an empty library', () => {
		expect(Q.getTimelinePage(db, {}).items).toEqual([]);
	});
});

describe('buckets cache + bust', () => {
	it('counts days, caches the result, and refreshes only after a bust', () => {
		add({ taken_local_day: '2024-01-01' });
		add({ taken_local_day: '2024-01-01' });
		add({ taken_local_day: '2024-01-02' });
		expect(Q.getTotalCount(db)).toBe(3);
		const b1 = Q.getBuckets(db);
		expect(b1.find((b) => b.day === '2024-01-01')?.n).toBe(2);

		add({ taken_local_day: '2024-01-03' }); // not reflected until bust (cached)
		expect(Q.getTotalCount(db)).toBe(3);
		Q.bustBucketsCache();
		expect(Q.getTotalCount(db)).toBe(4);
	});
});

describe('getMediaDetail', () => {
	it('maps a full detail row (happy) and null for a missing id (failure)', () => {
		const id = add({ camera_model: 'Pixel', has_gps: 1, gps_lat: 1.5, gps_lon: 2.5 });
		const d = Q.getMediaDetail(db, id)!;
		expect(d.cameraModel).toBe('Pixel');
		expect(d.hasGps).toBe(true);
		expect(d.albums).toEqual([]);
		expect(Q.getMediaDetail(db, 9999)).toBeNull();
	});
});

describe('searchMedia', () => {
	it('FTS-matches filenames (happy path)', () => {
		add({ filename: 'beach-sunset.jpg' });
		add({ filename: 'office.jpg' });
		const r = Q.searchMedia(db, { q: 'beach' });
		expect(r.items).toHaveLength(1);
	});
	it('filters by type / favorite / hasGps', () => {
		add({ type: 'photo', is_favorite: 1 });
		add({ type: 'video' });
		add({ type: 'photo', has_gps: 1, gps_lat: 1, gps_lon: 1 });
		expect(Q.searchMedia(db, { type: 'video' }).items).toHaveLength(1);
		expect(Q.searchMedia(db, { fav: true }).items).toHaveLength(1);
		expect(Q.searchMedia(db, { hasGps: true }).items).toHaveLength(1);
	});
	it('hides archived by default but returns them with archived:true', () => {
		add({ is_archived: 1 });
		add({});
		expect(Q.searchMedia(db, {}).items).toHaveLength(1);
		expect(Q.searchMedia(db, { archived: true }).items).toHaveLength(1);
	});
	it('escapes LIKE metacharacters in the camera filter (underscore is literal)', () => {
		add({ camera_model: 'Canon_5D' });
		add({ camera_model: 'CanonX5D' });
		const r = Q.searchMedia(db, { camera: 'Canon_5D' });
		expect(r.items).toHaveLength(1);
	});
});

describe('getMemories', () => {
	it('groups same month-day from prior years and excludes the current year', () => {
		add({ taken_local_day: '2020-06-16' });
		add({ taken_local_day: '2021-06-16' });
		add({ taken_local_day: '2023-06-16' }); // current year → excluded
		add({ taken_local_day: '2022-07-01' }); // different day → excluded
		const groups = Q.getMemories(db, '06-16', 2023);
		expect(groups.map((g) => g.year).sort()).toEqual(['2020', '2021']);
	});
});

describe('getDuplicates', () => {
	it('groups rows that share a quick_hash (exact dupes)', () => {
		add({ quick_hash: 'h1' });
		add({ quick_hash: 'h1' });
		add({ quick_hash: 'h2' }); // unique → not a group
		const groups = Q.getDuplicates(db);
		expect(groups).toHaveLength(1);
		expect(groups[0].items).toHaveLength(2);
		expect(groups[0].kind).toBe('exact');
	});
});

describe('getMapClusters', () => {
	it('clusters geotagged points and respects the bbox', () => {
		add({ has_gps: 1, gps_lat: 40, gps_lon: -74 });
		add({ has_gps: 1, gps_lat: 40.0001, gps_lon: -74.0001 });
		add({ has_gps: 1, gps_lat: -33, gps_lon: 151 });
		const all = Q.getMapClusters(db, null, 3);
		expect(all.reduce((s, c) => s + c.count, 0)).toBe(3);
		const nyOnly = Q.getMapClusters(db, { minLon: -75, minLat: 39, maxLon: -73, maxLat: 41 }, 3);
		expect(nyOnly.reduce((s, c) => s + c.count, 0)).toBe(2);
	});
});

describe('getFolder', () => {
	it('lists roots at the top level and drills into a dir', () => {
		add({ dir: 'd:/r', filename: 'top.jpg' });
		add({ dir: 'd:/r/trip', filename: 'a.jpg' });
		const top = Q.getFolder(db, null);
		expect(top.roots.map((r) => r.path)).toContain('d:/r');
		const inDir = Q.getFolder(db, 'd:/r');
		expect(inDir.subfolders).toContain('trip');
		expect(inDir.page.items.length).toBe(1); // only files directly in d:/r
	});
});

describe('albums', () => {
	it('lists albums with counts and paginates album contents', () => {
		const m1 = add({ taken_ms: 10 });
		const m2 = add({ taken_ms: 20 });
		db.prepare(`INSERT INTO albums(id, name, created_at, sort_order) VALUES(1,'Trip',1000,0)`).run();
		db.prepare(`INSERT INTO album_items(album_id, media_id, added_at, position) VALUES(1,?,1000,0),(1,?,1000,1)`).run(m1, m2);
		const albums = Q.getAlbums(db) as { id: number; count: number }[];
		expect(albums[0].count).toBe(2);
		const page = Q.getAlbumPage(db, 1, { limit: 10 });
		expect(page.items.map((i) => i.id)).toEqual([m2, m1]); // newest-first
	});
});

describe('organize: tags, rating, pick, captions (v4)', () => {
	function setOrg(id: number, o: { rating?: number; pick?: number; caption?: string }) {
		db.prepare(`UPDATE media SET rating=@rating, pick=@pick, caption=@caption WHERE id=@id`).run({
			id,
			rating: o.rating ?? 0,
			pick: o.pick ?? 0,
			caption: o.caption ?? null
		});
	}
	function tag(id: number, name: string) {
		db.prepare(`INSERT INTO tags(name) VALUES(?) ON CONFLICT(name) DO NOTHING`).run(name);
		const tagId = (db.prepare(`SELECT id FROM tags WHERE name=?`).get(name) as { id: number }).id;
		db.prepare(`INSERT INTO media_tags(media_id, tag_id) VALUES(?,?)`).run(id, tagId);
		return tagId;
	}

	it('filters by minimum rating', () => {
		setOrg(add(), { rating: 5 });
		setOrg(add(), { rating: 3 });
		setOrg(add(), { rating: 0 });
		expect(Q.searchMedia(db, { rating: 4 }).items).toHaveLength(1);
		expect(Q.searchMedia(db, { rating: 3 }).items).toHaveLength(2);
	});

	it('filters by pick / reject', () => {
		setOrg(add(), { pick: 1 });
		setOrg(add(), { pick: -1 });
		setOrg(add(), { pick: 0 });
		expect(Q.searchMedia(db, { pick: 1 }).items).toHaveLength(1);
		expect(Q.searchMedia(db, { pick: -1 }).items).toHaveLength(1);
	});

	it('filters by tag and getMediaDetail returns the tags', () => {
		const a = add();
		const b = add();
		const t = tag(a, 'beach');
		tag(b, 'city');
		expect(Q.searchMedia(db, { tag: t }).items.map((i) => i.id)).toEqual([a]);
		expect(Q.getMediaDetail(db, a)!.tags.map((x) => x.name)).toEqual(['beach']);
	});

	it('getTags returns counts (excluding trashed media)', () => {
		const a = add();
		const b = add();
		const c = add({ is_trashed: 1 });
		tag(a, 'beach');
		tag(b, 'beach');
		tag(c, 'beach'); // on a trashed item → not counted
		const beach = Q.getTags(db).find((t) => t.name === 'beach')!;
		expect(beach.count).toBe(2);
	});

	it('searches captions via FTS', () => {
		const a = add({ filename: 'x.jpg' });
		setOrg(a, { caption: 'a lovely waterfall in the forest' });
		add({ filename: 'y.jpg' });
		expect(Q.searchMedia(db, { q: 'waterfall' }).items.map((i) => i.id)).toEqual([a]);
	});
});

describe('places (v5)', () => {
	function setPlace(id: number, locality: string, country: string) {
		db.prepare(
			`UPDATE media SET place_locality=@l, place_country=@c, place_name=@l, geocode_status=1 WHERE id=@id`
		).run({ id, l: locality, c: country });
	}

	it('groups by locality with counts and filters by place', () => {
		const a = add({ has_gps: 1, gps_lat: 35.6, gps_lon: 139.7 });
		const b = add({ has_gps: 1, gps_lat: 35.7, gps_lon: 139.7 });
		const c = add({ has_gps: 1, gps_lat: 48.85, gps_lon: 2.35 });
		setPlace(a, 'Tokyo', 'Japan');
		setPlace(b, 'Tokyo', 'Japan');
		setPlace(c, 'Paris', 'France');
		const places = Q.getPlaces(db);
		expect(places.find((p) => p.locality === 'Tokyo')?.count).toBe(2);
		expect(places[0].locality).toBe('Tokyo'); // most-photographed first
		expect(Q.searchMedia(db, { place: 'Paris' }).items.map((i) => i.id)).toEqual([c]);
	});

	it('getMediaDetail exposes the resolved place', () => {
		const a = add({ has_gps: 1, gps_lat: 1, gps_lon: 1 });
		setPlace(a, 'Singapore', 'Singapore');
		const d = Q.getMediaDetail(db, a)!;
		expect(d.placeLocality).toBe('Singapore');
		expect(d.placeCountry).toBe('Singapore');
	});
});
```

### `src/lib/server/db/queries.ts`

```ts
/**
 * Read queries + row mappers. The hot timeline path uses raw prepared statements
 * (keyset pagination, never OFFSET — docs/05-PERFORMANCE.md). Statements are prepared
 * once per connection and memoized.
 */
import type { DB } from './index';
import type {
	TimelineItem,
	TimelinePage,
	DayBucket,
	MediaDetail,
	MediaType,
	StatusCode
} from '$shared/types';

const MAX_MS = Number.MAX_SAFE_INTEGER;

/** Escape SQLite LIKE metacharacters so user paths/text match literally (use with ESCAPE '\'). */
function escapeLike(s: string): string {
	return s.replace(/[\\%_]/g, (c) => '\\' + c);
}

interface Prepared {
	timeline: import('better-sqlite3').Statement;
	buckets: import('better-sqlite3').Statement;
	total: import('better-sqlite3').Statement;
	detail: import('better-sqlite3').Statement;
	detailAlbums: import('better-sqlite3').Statement;
	detailTags: import('better-sqlite3').Statement;
	pathById: import('better-sqlite3').Statement;
}

const cache = new WeakMap<DB, Prepared>();

const TIMELINE_COLS = `id, type, width, height, taken_ms, taken_local_day, duration_ms, blurhash, is_favorite, live_partner_id, thumb_status`;

function prep(db: DB): Prepared {
	let p = cache.get(db);
	if (p) return p;
	p = {
		timeline: db.prepare(
			`SELECT ${TIMELINE_COLS} FROM media
			 WHERE is_trashed = 0 AND is_archived = 0
			   AND (taken_ms < @curMs OR (taken_ms = @curMs AND id < @curId))
			 ORDER BY taken_ms DESC, id DESC
			 LIMIT @limit`
		),
		buckets: db.prepare(
			`SELECT taken_local_day AS day, COUNT(*) AS n FROM media
			 WHERE is_trashed = 0 AND is_archived = 0 AND taken_local_day IS NOT NULL
			 GROUP BY taken_local_day ORDER BY day DESC`
		),
		total: db.prepare(
			`SELECT COUNT(*) AS n FROM media WHERE is_trashed = 0 AND is_archived = 0`
		),
		detail: db.prepare(`SELECT * FROM media WHERE id = ?`),
		detailAlbums: db.prepare(
			`SELECT a.id, a.name FROM albums a
			 JOIN album_items ai ON ai.album_id = a.id WHERE ai.media_id = ? ORDER BY a.name`
		),
		detailTags: db.prepare(
			`SELECT t.id, t.name FROM tags t
			 JOIN media_tags mt ON mt.tag_id = t.id WHERE mt.media_id = ? ORDER BY t.name`
		),
		pathById: db.prepare(`SELECT path, type FROM media WHERE id = ?`)
	};
	cache.set(db, p);
	return p;
}

/* eslint-disable @typescript-eslint/no-explicit-any */
export function mapTimelineRow(r: any): TimelineItem {
	return {
		id: r.id,
		type: r.type as MediaType,
		width: r.width ?? null,
		height: r.height ?? null,
		takenMs: r.taken_ms ?? 0,
		takenLocalDay: r.taken_local_day ?? '',
		durationMs: r.duration_ms ?? null,
		blurhash: r.blurhash ?? null,
		isFavorite: !!r.is_favorite,
		livePartnerId: r.live_partner_id ?? null,
		thumbStatus: (r.thumb_status ?? 0) as StatusCode
	};
}

export function getTimelinePage(
	db: DB,
	opts: { curMs?: number | null; curId?: number | null; limit?: number } = {}
): TimelinePage {
	const limit = Math.min(Math.max(opts.limit ?? 200, 1), 1000);
	const curMs = opts.curMs ?? MAX_MS;
	const curId = opts.curId ?? MAX_MS;
	const rows = prep(db).timeline.all({ curMs, curId, limit }) as any[];
	const items = rows.map(mapTimelineRow);
	const last = items[items.length - 1];
	const nextCursor =
		items.length === limit && last ? { curMs: last.takenMs, curId: last.id } : null;
	return { items, nextCursor };
}

// The day-bucket aggregate + total are a full(-ish) scan; they change only when media is
// added/removed/(un)archived/(un)trashed or a taken date is (re)computed. Cache the result and
// bust it explicitly on those events (scanner/pipeline/fileService), with a short TTL backstop.
let metaCache: { buckets: DayBucket[]; total: number; at: number } | null = null;
const META_TTL_MS = 10_000;

export function bustBucketsCache(): void {
	metaCache = null;
}

function timelineMeta(db: DB): { buckets: DayBucket[]; total: number } {
	const now = Date.now();
	if (metaCache && now - metaCache.at < META_TTL_MS) return metaCache;
	const buckets = prep(db).buckets.all() as DayBucket[];
	const total = (prep(db).total.get() as { n: number }).n;
	metaCache = { buckets, total, at: now };
	return metaCache;
}

export function getBuckets(db: DB): DayBucket[] {
	return timelineMeta(db).buckets;
}

export function getTotalCount(db: DB): number {
	return timelineMeta(db).total;
}

export function getMediaDetail(db: DB, id: number): MediaDetail | null {
	const r = prep(db).detail.get(id) as any;
	if (!r) return null;
	const albums = prep(db).detailAlbums.all(id) as { id: number; name: string }[];
	const tags = prep(db).detailTags.all(id) as { id: number; name: string }[];
	return {
		...mapTimelineRow(r),
		path: r.path,
		relPath: r.rel_path,
		dir: r.dir,
		filename: r.filename,
		ext: r.ext,
		sizeBytes: r.size_bytes,
		mtimeMs: r.mtime_ms,
		takenSource: r.taken_source ?? null,
		cameraMake: r.camera_make ?? null,
		cameraModel: r.camera_model ?? null,
		lens: r.lens ?? null,
		codec: r.codec ?? null,
		orientation: r.orientation ?? null,
		hasGps: !!r.has_gps,
		gpsLat: r.gps_lat ?? null,
		gpsLon: r.gps_lon ?? null,
		isArchived: !!r.is_archived,
		isTrashed: !!r.is_trashed,
		error: r.error ?? null,
		albums,
		caption: r.caption ?? null,
		rating: r.rating ?? 0,
		pick: r.pick ?? 0,
		tags,
		placeName: r.place_name ?? null,
		placeLocality: r.place_locality ?? null,
		placeCountry: r.place_country ?? null,
		editOps: parseEditOps(r.edit_ops)
	};
}

function parseEditOps(raw: unknown): import('$shared/edits').EditOps | null {
	if (!raw || typeof raw !== 'string') return null;
	try {
		return JSON.parse(raw) as import('$shared/edits').EditOps;
	} catch {
		return null;
	}
}

/** Places: geotagged media grouped by reverse-geocoded locality, most-photographed first. */
export function getPlaces(db: DB): import('$shared/types').PlaceGroup[] {
	return db
		.prepare(
			`SELECT place_locality AS locality, place_country AS country, COUNT(*) AS count,
			        MAX(id) AS sampleId
			 FROM media
			 WHERE is_trashed = 0 AND is_archived = 0 AND place_locality IS NOT NULL
			 GROUP BY place_locality, place_country
			 ORDER BY count DESC, locality`
		)
		.all() as import('$shared/types').PlaceGroup[];
}

/** All tags with their (non-trashed) media counts, most-used first. */
export function getTags(db: DB): import('$shared/types').Tag[] {
	return db
		.prepare(
			`SELECT t.id, t.name,
			        (SELECT COUNT(*) FROM media_tags mt JOIN media m ON m.id = mt.media_id
			         WHERE mt.tag_id = t.id AND m.is_trashed = 0) AS count
			 FROM tags t ORDER BY count DESC, t.name`
		)
		.all() as import('$shared/types').Tag[];
}

/** Internal: resolve a media id to its on-disk path + type (for the byte-serving endpoints). */
export function getMediaPath(db: DB, id: number): { path: string; type: MediaType } | null {
	const r = prep(db).pathById.get(id) as { path: string; type: MediaType } | undefined;
	return r ?? null;
}

export function getTrash(db: DB) {
	const rows = db
		.prepare(
			`SELECT t.id, t.media_id AS mediaId, t.original_path AS originalPath,
			        t.size_bytes AS sizeBytes, t.trashed_at AS trashedAt, m.filename
			 FROM trash t LEFT JOIN media m ON m.id = t.media_id
			 ORDER BY t.trashed_at DESC`
		)
		.all() as { id: number; mediaId: number | null; originalPath: string; sizeBytes: number; trashedAt: number; filename: string | null }[];
	return rows.map((r) => ({ ...r, filename: r.filename ?? r.originalPath.split('/').pop() ?? 'file' }));
}

export function getAlbums(db: DB) {
	return db
		.prepare(
			`SELECT a.id, a.name, a.cover_media_id AS coverMediaId, a.created_at AS createdAt,
			        a.sort_order AS sortOrder,
			        (SELECT COUNT(*) FROM album_items ai WHERE ai.album_id = a.id) AS count
			 FROM albums a ORDER BY a.sort_order, a.created_at DESC`
		)
		.all();
}

const ALBUM_COLS = `m.id, m.type, m.width, m.height, m.taken_ms, m.taken_local_day, m.duration_ms, m.blurhash, m.is_favorite, m.live_partner_id, m.thumb_status`;

export function getAlbumPage(
	db: DB,
	albumId: number,
	opts: { curMs?: number | null; curId?: number | null; limit?: number } = {}
): TimelinePage {
	const limit = Math.min(Math.max(opts.limit ?? 200, 1), 1000);
	const curMs = opts.curMs ?? MAX_MS;
	const curId = opts.curId ?? MAX_MS;
	const rows = db
		.prepare(
			`SELECT ${ALBUM_COLS} FROM media m
			 JOIN album_items ai ON ai.media_id = m.id
			 WHERE ai.album_id = @album AND m.is_trashed = 0
			   AND (m.taken_ms < @curMs OR (m.taken_ms = @curMs AND m.id < @curId))
			 ORDER BY m.taken_ms DESC, m.id DESC LIMIT @limit`
		)
		.all({ album: albumId, curMs, curId, limit }) as any[];
	const items = rows.map(mapTimelineRow);
	const last = items[items.length - 1];
	const nextCursor = items.length === limit && last ? { curMs: last.takenMs, curId: last.id } : null;
	return { items, nextCursor };
}

export interface SearchFilters {
	q?: string;
	from?: number;
	to?: number;
	type?: 'photo' | 'video';
	fav?: boolean;
	archived?: boolean;
	camera?: string;
	hasGps?: boolean;
	album?: number;
	tag?: number;
	/** Minimum star rating (1-5). */
	rating?: number;
	/** Culling flag filter: 1 = picks, -1 = rejects. */
	pick?: number;
	/** Reverse-geocoded locality (exact match). */
	place?: string;
	curMs?: number | null;
	curId?: number | null;
	limit?: number;
}

export function searchMedia(db: DB, f: SearchFilters): TimelinePage {
	const limit = Math.min(Math.max(f.limit ?? 200, 1), 1000);
	const where: string[] = ['m.is_trashed = 0'];
	const params: Record<string, unknown> = { curMs: f.curMs ?? MAX_MS, curId: f.curId ?? MAX_MS, limit };
	let join = '';

	if (f.q && f.q.trim()) {
		const match = f.q
			.trim()
			.split(/\s+/)
			.map((t) => t.replace(/["*^]/g, ''))
			.filter(Boolean)
			.map((t) => `"${t}"*`)
			.join(' ');
		if (match) {
			join += ' JOIN media_fts ON media_fts.rowid = m.id';
			where.push('media_fts MATCH @q');
			params.q = match;
		}
	}
	if (f.from != null) {
		where.push('m.taken_ms >= @from');
		params.from = f.from;
	}
	if (f.to != null) {
		where.push('m.taken_ms <= @to');
		params.to = f.to;
	}
	if (f.type) {
		where.push('m.type = @type');
		params.type = f.type;
	}
	if (f.fav) where.push('m.is_favorite = 1');
	where.push(f.archived === true ? 'm.is_archived = 1' : 'm.is_archived = 0');
	if (f.camera) {
		where.push("m.camera_model LIKE @camera ESCAPE '\\'");
		params.camera = `%${escapeLike(f.camera)}%`;
	}
	if (f.hasGps) where.push('m.has_gps = 1');
	if (f.album != null) {
		join += ' JOIN album_items ai ON ai.media_id = m.id';
		where.push('ai.album_id = @album');
		params.album = f.album;
	}
	if (f.tag != null) {
		join += ' JOIN media_tags mt ON mt.media_id = m.id';
		where.push('mt.tag_id = @tag');
		params.tag = f.tag;
	}
	if (f.rating != null && f.rating > 0) {
		where.push('m.rating >= @rating');
		params.rating = f.rating;
	}
	if (f.pick != null && f.pick !== 0) {
		where.push('m.pick = @pick');
		params.pick = f.pick;
	}
	if (f.place) {
		where.push('m.place_locality = @place');
		params.place = f.place;
	}
	where.push('(m.taken_ms < @curMs OR (m.taken_ms = @curMs AND m.id < @curId))');

	const rows = db
		.prepare(
			`SELECT ${ALBUM_COLS} FROM media m${join} WHERE ${where.join(' AND ')}
			 ORDER BY m.taken_ms DESC, m.id DESC LIMIT @limit`
		)
		.all(params) as any[];
	const items = rows.map(mapTimelineRow);
	const last = items[items.length - 1];
	const nextCursor = items.length === limit && last ? { curMs: last.takenMs, curId: last.id } : null;
	return { items, nextCursor };
}

/** "On this day": same calendar month-day in prior years. */
export function getMemories(db: DB, monthDay: string, year: number) {
	const rows = db
		.prepare(
			`SELECT ${TIMELINE_COLS} FROM media
			 WHERE is_trashed=0 AND is_archived=0 AND taken_local_day IS NOT NULL
			   AND substr(taken_local_day, 6, 5) = @md AND substr(taken_local_day, 1, 4) != @yr
			 ORDER BY taken_local_day DESC, id DESC LIMIT 500`
		)
		.all({ md: monthDay, yr: String(year) }) as any[];
	// group by year
	const byYear = new Map<string, TimelineItem[]>();
	for (const r of rows) {
		const item = mapTimelineRow(r);
		const y = item.takenLocalDay.slice(0, 4);
		if (!byYear.has(y)) byYear.set(y, []);
		byYear.get(y)!.push(item);
	}
	return [...byYear.entries()].map(([y, items]) => ({ year: y, items }));
}

/** Exact-duplicate groups (same quick_hash, count > 1). */
export function getDuplicates(db: DB) {
	const hashes = db
		.prepare(
			`SELECT quick_hash FROM media WHERE quick_hash IS NOT NULL AND is_trashed=0
			 GROUP BY quick_hash HAVING COUNT(*) > 1 LIMIT 500`
		)
		.all() as { quick_hash: string }[];
	const itemStmt = db.prepare(
		`SELECT ${TIMELINE_COLS} FROM media WHERE quick_hash = ? AND is_trashed=0 ORDER BY id`
	);
	return hashes.map((h) => ({
		hash: h.quick_hash,
		kind: 'exact' as const,
		items: (itemStmt.all(h.quick_hash) as any[]).map(mapTimelineRow)
	}));
}

/** Geotagged points within an optional bbox, clustered server-side by a zoom-sized grid. */
export function getMapClusters(
	db: DB,
	bbox: { minLon: number; minLat: number; maxLon: number; maxLat: number } | null,
	zoom: number
) {
	const where = ['has_gps=1', 'is_trashed=0', 'gps_lat IS NOT NULL', 'gps_lon IS NOT NULL'];
	const params: Record<string, number> = {};
	if (bbox) {
		where.push('gps_lat BETWEEN @minLat AND @maxLat AND gps_lon BETWEEN @minLon AND @maxLon');
		Object.assign(params, bbox);
	}
	const pts = db
		.prepare(`SELECT id, gps_lat AS lat, gps_lon AS lon FROM media WHERE ${where.join(' AND ')} LIMIT 20000`)
		.all(params) as { id: number; lat: number; lon: number }[];

	// Grid cluster: cell size shrinks with zoom.
	const cell = 360 / Math.pow(2, Math.min(20, Math.max(1, zoom))) / 2;
	const cells = new Map<string, { lat: number; lon: number; count: number; sampleId: number }>();
	for (const p of pts) {
		const key = `${Math.floor(p.lon / cell)}:${Math.floor(p.lat / cell)}`;
		const c = cells.get(key);
		if (c) {
			c.lat += p.lat;
			c.lon += p.lon;
			c.count++;
		} else {
			cells.set(key, { lat: p.lat, lon: p.lon, count: 1, sampleId: p.id });
		}
	}
	return [...cells.values()].map((c) => ({
		lat: c.lat / c.count,
		lon: c.lon / c.count,
		count: c.count,
		sampleId: c.sampleId
	}));
}

/** Folder browser: immediate subfolders + media directly in `dir` (one level). */
export function getFolder(db: DB, dir: string | null) {
	const roots = db.prepare(`SELECT id, path, label FROM roots WHERE enabled=1`).all() as {
		id: number;
		path: string;
		label: string;
	}[];
	if (!dir) {
		return { dir: null, roots, subfolders: [] as string[], page: { items: [], nextCursor: null } as TimelinePage };
	}
	const sub = db
		.prepare(
			`SELECT DISTINCT
			   CASE WHEN instr(substr(dir, length(@dir)+2), '/') > 0
			        THEN substr(dir, length(@dir)+2, instr(substr(dir, length(@dir)+2), '/') - 1)
			        ELSE substr(dir, length(@dir)+2) END AS name
			 FROM media WHERE is_trashed=0 AND dir LIKE @like ESCAPE '\\' AND dir != @dir AND name != ''
			 ORDER BY name`
		)
		.all({ dir, like: escapeLike(dir) + '/%' }) as { name: string }[];
	const rows = db
		.prepare(
			`SELECT ${TIMELINE_COLS} FROM media WHERE is_trashed=0 AND dir=@dir
			 ORDER BY taken_ms DESC, id DESC LIMIT 500`
		)
		.all({ dir }) as any[];
	return {
		dir,
		roots,
		subfolders: [...new Set(sub.map((s) => s.name))].filter(Boolean),
		page: { items: rows.map(mapTimelineRow), nextCursor: null } as TimelinePage
	};
}
```

### `src/lib/server/db/schema.ts`

```ts
/**
 * Canonical SQLite DDL (see docs/02-DATA-MODEL.md). We hand-write the DDL rather than
 * generate it with drizzle-kit because the schema needs FTS5 virtual tables, sqlite-vec
 * virtual tables, and triggers, which the generator can't express. Migrations are applied
 * on startup (see migrate.ts), versioned via `app_state.schema_version`.
 */

/** v1 — full core schema: tables, indexes, FTS5 + sync triggers. */
export const SCHEMA_V1 = /* sql */ `
CREATE TABLE roots (
  id INTEGER PRIMARY KEY,
  path TEXT NOT NULL UNIQUE,
  label TEXT,
  enabled INTEGER NOT NULL DEFAULT 1,
  online INTEGER NOT NULL DEFAULT 1
);

CREATE TABLE media (
  id INTEGER PRIMARY KEY,
  path TEXT NOT NULL UNIQUE,
  root_id INTEGER NOT NULL REFERENCES roots(id) ON DELETE CASCADE,
  rel_path TEXT NOT NULL, dir TEXT NOT NULL, filename TEXT NOT NULL, ext TEXT NOT NULL,
  type TEXT NOT NULL,
  size_bytes INTEGER NOT NULL,
  mtime_ms INTEGER NOT NULL,
  width INTEGER, height INTEGER, duration_ms INTEGER,
  taken_ms INTEGER,
  taken_local_day TEXT,
  taken_source TEXT,
  camera_make TEXT, camera_model TEXT, lens TEXT, orientation INTEGER,
  codec TEXT,
  has_gps INTEGER NOT NULL DEFAULT 0, gps_lat REAL, gps_lon REAL,
  quick_hash TEXT,
  phash TEXT,
  blurhash TEXT,
  live_partner_id INTEGER REFERENCES media(id) ON DELETE SET NULL,
  is_favorite INTEGER NOT NULL DEFAULT 0,
  is_archived INTEGER NOT NULL DEFAULT 0,
  is_trashed  INTEGER NOT NULL DEFAULT 0,
  meta_status  INTEGER NOT NULL DEFAULT 0,
  thumb_status INTEGER NOT NULL DEFAULT 0,
  error TEXT,
  scan_id INTEGER,
  created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL
);

CREATE TABLE albums (
  id INTEGER PRIMARY KEY, name TEXT NOT NULL,
  cover_media_id INTEGER REFERENCES media(id) ON DELETE SET NULL,
  created_at INTEGER NOT NULL, sort_order INTEGER NOT NULL DEFAULT 0
);
CREATE TABLE album_items (
  album_id INTEGER NOT NULL REFERENCES albums(id) ON DELETE CASCADE,
  media_id INTEGER NOT NULL REFERENCES media(id) ON DELETE CASCADE,
  added_at INTEGER NOT NULL, position INTEGER,
  PRIMARY KEY (album_id, media_id)
);

CREATE TABLE tags (id INTEGER PRIMARY KEY, name TEXT NOT NULL UNIQUE);
CREATE TABLE media_tags (
  media_id INTEGER NOT NULL REFERENCES media(id) ON DELETE CASCADE,
  tag_id   INTEGER NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
  PRIMARY KEY (media_id, tag_id)
);

CREATE TABLE trash (
  id INTEGER PRIMARY KEY,
  media_id INTEGER REFERENCES media(id) ON DELETE SET NULL,
  original_path TEXT NOT NULL, trash_path TEXT NOT NULL,
  size_bytes INTEGER NOT NULL, trashed_at INTEGER NOT NULL
);

CREATE TABLE scans (
  id INTEGER PRIMARY KEY, started_at INTEGER NOT NULL, finished_at INTEGER,
  status TEXT NOT NULL,
  files_seen INTEGER DEFAULT 0, added INTEGER DEFAULT 0,
  updated INTEGER DEFAULT 0, removed INTEGER DEFAULT 0, error TEXT
);

CREATE TABLE app_state (key TEXT PRIMARY KEY, value TEXT);

-- Indexes
CREATE INDEX idx_media_timeline ON media (is_trashed, is_archived, taken_ms DESC, id DESC);
CREATE INDEX idx_media_dir   ON media (root_id, dir, filename);
CREATE INDEX idx_media_type  ON media (type, taken_ms DESC);
CREATE INDEX idx_media_fav   ON media (is_favorite, taken_ms DESC) WHERE is_favorite = 1;
CREATE INDEX idx_media_arch  ON media (is_archived, taken_ms DESC) WHERE is_archived = 1;
CREATE INDEX idx_media_gps   ON media (has_gps, taken_ms DESC)     WHERE has_gps = 1;
CREATE INDEX idx_media_hash  ON media (quick_hash)                 WHERE quick_hash IS NOT NULL;
CREATE INDEX idx_media_phash ON media (phash)                      WHERE phash IS NOT NULL;
CREATE INDEX idx_media_scan  ON media (scan_id);
CREATE INDEX idx_media_pending ON media (meta_status, thumb_status);

-- Full-text search (external-content table kept in sync by triggers).
CREATE VIRTUAL TABLE media_fts USING fts5(
  filename, camera_model, rel_path,
  content='media', content_rowid='id'
);
CREATE TRIGGER media_fts_ai AFTER INSERT ON media BEGIN
  INSERT INTO media_fts(rowid, filename, camera_model, rel_path)
  VALUES (new.id, new.filename, new.camera_model, new.rel_path);
END;
CREATE TRIGGER media_fts_ad AFTER DELETE ON media BEGIN
  INSERT INTO media_fts(media_fts, rowid, filename, camera_model, rel_path)
  VALUES ('delete', old.id, old.filename, old.camera_model, old.rel_path);
END;
CREATE TRIGGER media_fts_au AFTER UPDATE ON media BEGIN
  INSERT INTO media_fts(media_fts, rowid, filename, camera_model, rel_path)
  VALUES ('delete', old.id, old.filename, old.camera_model, old.rel_path);
  INSERT INTO media_fts(rowid, filename, camera_model, rel_path)
  VALUES (new.id, new.filename, new.camera_model, new.rel_path);
END;
`;

/**
 * AI tables — created on demand only when AI features are enabled. The embeddings
 * virtual table requires the sqlite-vec extension to be loaded first.
 */
export const FACES_SQL = /* sql */ `
CREATE TABLE IF NOT EXISTS face_clusters (
  id INTEGER PRIMARY KEY, label TEXT,
  cover_face_id INTEGER
);
CREATE TABLE IF NOT EXISTS faces (
  id INTEGER PRIMARY KEY,
  media_id INTEGER NOT NULL REFERENCES media(id) ON DELETE CASCADE,
  bbox TEXT NOT NULL,
  embedding BLOB NOT NULL,
  cluster_id INTEGER REFERENCES face_clusters(id) ON DELETE SET NULL
);
CREATE INDEX IF NOT EXISTS idx_faces_media ON faces(media_id);
CREATE INDEX IF NOT EXISTS idx_faces_cluster ON faces(cluster_id);
`;

export const EMBEDDINGS_SQL = /* sql */ `
CREATE VIRTUAL TABLE IF NOT EXISTS embeddings USING vec0(media_id INTEGER PRIMARY KEY, embedding FLOAT[512]);
`;

/** v2 — covering index for the day-bucket aggregate (timeline scrollbar estimate). */
export const SCHEMA_V2 = /* sql */ `
CREATE INDEX IF NOT EXISTS idx_media_day ON media (is_trashed, is_archived, taken_local_day);
`;

/**
 * v3 — bounded retry for the media pipeline. Failed rows (meta/thumb status 3) used to be permanent
 * holes; now they carry an attempt counter + a `next_retry_ms` so transient failures (locked file,
 * NAS hiccup) self-heal with backoff while genuinely-bad files stop after maxAttempts. Additive
 * ALTER TABLE — instant even on 200k rows; existing rows default to 0 attempts / NULL retry.
 */
export const SCHEMA_V3 = /* sql */ `
ALTER TABLE media ADD COLUMN meta_attempts  INTEGER NOT NULL DEFAULT 0;
ALTER TABLE media ADD COLUMN thumb_attempts INTEGER NOT NULL DEFAULT 0;
ALTER TABLE media ADD COLUMN next_retry_ms  INTEGER;
CREATE INDEX IF NOT EXISTS idx_media_retry ON media (next_retry_ms) WHERE next_retry_ms IS NOT NULL;
`;

/**
 * v4 — organize: per-photo caption (searchable), 1-5 star rating, and pick/reject flag for culling.
 * `tags`/`media_tags` already exist (v1) but had no UI. The FTS table is recreated with a `caption`
 * column (and its triggers updated) so the free-text search box also matches captions; existing
 * content is reindexed via the fts5 'rebuild' command. Additive columns default to 0/NULL.
 */
export const SCHEMA_V4 = /* sql */ `
ALTER TABLE media ADD COLUMN caption TEXT;
ALTER TABLE media ADD COLUMN rating INTEGER NOT NULL DEFAULT 0;
ALTER TABLE media ADD COLUMN pick   INTEGER NOT NULL DEFAULT 0;

DROP TRIGGER IF EXISTS media_fts_ai;
DROP TRIGGER IF EXISTS media_fts_ad;
DROP TRIGGER IF EXISTS media_fts_au;
DROP TABLE IF EXISTS media_fts;
CREATE VIRTUAL TABLE media_fts USING fts5(
  filename, camera_model, rel_path, caption,
  content='media', content_rowid='id'
);
INSERT INTO media_fts(media_fts) VALUES('rebuild');
CREATE TRIGGER media_fts_ai AFTER INSERT ON media BEGIN
  INSERT INTO media_fts(rowid, filename, camera_model, rel_path, caption)
  VALUES (new.id, new.filename, new.camera_model, new.rel_path, new.caption);
END;
CREATE TRIGGER media_fts_ad AFTER DELETE ON media BEGIN
  INSERT INTO media_fts(media_fts, rowid, filename, camera_model, rel_path, caption)
  VALUES ('delete', old.id, old.filename, old.camera_model, old.rel_path, old.caption);
END;
CREATE TRIGGER media_fts_au AFTER UPDATE ON media BEGIN
  INSERT INTO media_fts(media_fts, rowid, filename, camera_model, rel_path, caption)
  VALUES ('delete', old.id, old.filename, old.camera_model, old.rel_path, old.caption);
  INSERT INTO media_fts(rowid, filename, camera_model, rel_path, caption)
  VALUES (new.id, new.filename, new.camera_model, new.rel_path, new.caption);
END;

CREATE INDEX IF NOT EXISTS idx_media_rating ON media (rating) WHERE rating > 0;
CREATE INDEX IF NOT EXISTS idx_media_pick   ON media (pick)   WHERE pick != 0;
`;

/**
 * v5 — places: reverse-geocoded location names for geotagged media. geocode_status: 0 none,
 * 1 done, 2 fail. Off by default and privacy-gated (see config `geocode`); only the optional
 * `nominatim` provider makes a network request — `offline` uses a bundled city dataset. Additive.
 */
export const SCHEMA_V5 = /* sql */ `
ALTER TABLE media ADD COLUMN place_name     TEXT;
ALTER TABLE media ADD COLUMN place_locality TEXT;
ALTER TABLE media ADD COLUMN place_country  TEXT;
ALTER TABLE media ADD COLUMN geocode_status INTEGER NOT NULL DEFAULT 0;
CREATE INDEX IF NOT EXISTS idx_media_place ON media (place_locality) WHERE place_locality IS NOT NULL;
`;

/**
 * v6 — non-destructive editing. `edit_ops` is a JSON blob of operations (crop/rotate/flip + light &
 * colour adjustments + filter preset) applied to the ORIGINAL at render time; the source file is
 * never modified. `edited_ms` doubles as a cache-buster for the regenerated derivatives. NULL = the
 * photo is unedited. Additive.
 */
export const SCHEMA_V6 = /* sql */ `
ALTER TABLE media ADD COLUMN edit_ops  TEXT;
ALTER TABLE media ADD COLUMN edited_ms INTEGER;
`;

export interface Migration {
	version: number;
	name: string;
	sql: string;
}

/** Ordered migrations. Append new versions; never edit a shipped one. */
export const MIGRATIONS: Migration[] = [
	{ version: 1, name: 'core-schema', sql: SCHEMA_V1 },
	{ version: 2, name: 'day-index', sql: SCHEMA_V2 },
	{ version: 3, name: 'retry-attempts', sql: SCHEMA_V3 },
	{ version: 4, name: 'organize', sql: SCHEMA_V4 },
	{ version: 5, name: 'places', sql: SCHEMA_V5 },
	{ version: 6, name: 'edits', sql: SCHEMA_V6 }
];

export const TARGET_SCHEMA_VERSION = MIGRATIONS[MIGRATIONS.length - 1].version;
```

### `src/lib/server/geo/cities.test.ts`

```ts
import { describe, it, expect } from 'vitest';
import { nearestCity } from './cities';

describe('nearestCity (offline reverse geocode)', () => {
	it('matches a coordinate near a known city', () => {
		const r = nearestCity(35.66, 139.7); // ~Tokyo
		expect(r?.city).toBe('Tokyo');
		expect(r?.country).toBe('Japan');
		expect(r!.distanceKm).toBeLessThan(50);
	});

	it('returns the closer of two nearby cities', () => {
		const r = nearestCity(40.73, -73.99); // Manhattan → New York, not Boston
		expect(r?.city).toBe('New York');
	});

	it('returns null in the open ocean (beyond the threshold)', () => {
		expect(nearestCity(0, -160)).toBeNull(); // middle of the Pacific
	});

	it('honours a tighter max distance', () => {
		// A point ~hundreds of km from any listed city is rejected at a small threshold.
		expect(nearestCity(45.0, 100.0, 50)).toBeNull();
	});
});
```

### `src/lib/server/geo/cities.ts`

```ts
/**
 * A small bundled dataset of major world cities for OFFLINE reverse geocoding (no network). A
 * geotagged photo is labelled with the nearest city within a distance threshold; beyond it the
 * locality is left unknown (so a remote shot isn't mislabelled as a far-off metro). This is a
 * deliberately coarse, approximate grouping — the `nominatim` provider gives precise names.
 *
 * Tuple: [latitude, longitude, city, country]. Coordinates are city-centre, ~2-decimal precision.
 */
export type City = readonly [number, number, string, string];

export const CITIES: City[] = [
	// North America
	[40.71, -74.01, 'New York', 'United States'],
	[34.05, -118.24, 'Los Angeles', 'United States'],
	[41.88, -87.63, 'Chicago', 'United States'],
	[29.76, -95.37, 'Houston', 'United States'],
	[33.45, -112.07, 'Phoenix', 'United States'],
	[37.77, -122.42, 'San Francisco', 'United States'],
	[47.61, -122.33, 'Seattle', 'United States'],
	[39.74, -104.99, 'Denver', 'United States'],
	[32.78, -96.8, 'Dallas', 'United States'],
	[25.76, -80.19, 'Miami', 'United States'],
	[42.36, -71.06, 'Boston', 'United States'],
	[38.91, -77.04, 'Washington', 'United States'],
	[33.75, -84.39, 'Atlanta', 'United States'],
	[36.17, -115.14, 'Las Vegas', 'United States'],
	[21.31, -157.86, 'Honolulu', 'United States'],
	[43.65, -79.38, 'Toronto', 'Canada'],
	[45.5, -73.57, 'Montreal', 'Canada'],
	[49.28, -123.12, 'Vancouver', 'Canada'],
	[19.43, -99.13, 'Mexico City', 'Mexico'],
	[20.97, -89.62, 'Mérida', 'Mexico'],
	[21.16, -86.85, 'Cancún', 'Mexico'],
	// South America
	[-23.55, -46.63, 'São Paulo', 'Brazil'],
	[-22.91, -43.17, 'Rio de Janeiro', 'Brazil'],
	[-34.6, -58.38, 'Buenos Aires', 'Argentina'],
	[-33.45, -70.67, 'Santiago', 'Chile'],
	[-12.05, -77.04, 'Lima', 'Peru'],
	[4.71, -74.07, 'Bogotá', 'Colombia'],
	[-13.16, -72.54, 'Cusco', 'Peru'],
	[10.5, -66.92, 'Caracas', 'Venezuela'],
	// Europe
	[51.51, -0.13, 'London', 'United Kingdom'],
	[48.85, 2.35, 'Paris', 'France'],
	[52.52, 13.4, 'Berlin', 'Germany'],
	[48.14, 11.58, 'Munich', 'Germany'],
	[40.42, -3.7, 'Madrid', 'Spain'],
	[41.39, 2.17, 'Barcelona', 'Spain'],
	[41.9, 12.5, 'Rome', 'Italy'],
	[45.46, 9.19, 'Milan', 'Italy'],
	[45.44, 12.34, 'Venice', 'Italy'],
	[52.37, 4.9, 'Amsterdam', 'Netherlands'],
	[50.85, 4.35, 'Brussels', 'Belgium'],
	[48.21, 16.37, 'Vienna', 'Austria'],
	[47.37, 8.54, 'Zürich', 'Switzerland'],
	[38.72, -9.14, 'Lisbon', 'Portugal'],
	[53.35, -6.26, 'Dublin', 'Ireland'],
	[59.33, 18.07, 'Stockholm', 'Sweden'],
	[59.91, 10.75, 'Oslo', 'Norway'],
	[55.68, 12.57, 'Copenhagen', 'Denmark'],
	[60.17, 24.94, 'Helsinki', 'Finland'],
	[52.23, 21.01, 'Warsaw', 'Poland'],
	[50.08, 14.44, 'Prague', 'Czechia'],
	[47.5, 19.04, 'Budapest', 'Hungary'],
	[37.98, 23.73, 'Athens', 'Greece'],
	[41.01, 28.98, 'Istanbul', 'Turkey'],
	[55.75, 37.62, 'Moscow', 'Russia'],
	[59.93, 30.34, 'Saint Petersburg', 'Russia'],
	[50.45, 30.52, 'Kyiv', 'Ukraine'],
	[64.15, -21.94, 'Reykjavík', 'Iceland'],
	// Africa
	[30.04, 31.24, 'Cairo', 'Egypt'],
	[-33.92, 18.42, 'Cape Town', 'South Africa'],
	[-26.2, 28.05, 'Johannesburg', 'South Africa'],
	[6.52, 3.38, 'Lagos', 'Nigeria'],
	[-1.29, 36.82, 'Nairobi', 'Kenya'],
	[33.57, -7.59, 'Casablanca', 'Morocco'],
	[31.63, -7.99, 'Marrakesh', 'Morocco'],
	[36.81, 10.18, 'Tunis', 'Tunisia'],
	[9.01, 38.76, 'Addis Ababa', 'Ethiopia'],
	[-4.04, 39.67, 'Mombasa', 'Kenya'],
	// Middle East
	[25.2, 55.27, 'Dubai', 'United Arab Emirates'],
	[24.47, 54.37, 'Abu Dhabi', 'United Arab Emirates'],
	[31.77, 35.21, 'Jerusalem', 'Israel'],
	[32.08, 34.78, 'Tel Aviv', 'Israel'],
	[24.71, 46.68, 'Riyadh', 'Saudi Arabia'],
	[35.69, 51.39, 'Tehran', 'Iran'],
	[33.51, 36.29, 'Damascus', 'Syria'],
	[33.89, 35.5, 'Beirut', 'Lebanon'],
	// South & Central Asia
	[28.61, 77.21, 'Delhi', 'India'],
	[19.08, 72.88, 'Mumbai', 'India'],
	[12.97, 77.59, 'Bengaluru', 'India'],
	[13.08, 80.27, 'Chennai', 'India'],
	[22.57, 88.36, 'Kolkata', 'India'],
	[27.71, 85.32, 'Kathmandu', 'Nepal'],
	[23.81, 90.41, 'Dhaka', 'Bangladesh'],
	[24.86, 67.0, 'Karachi', 'Pakistan'],
	[6.93, 79.86, 'Colombo', 'Sri Lanka'],
	// East & Southeast Asia
	[35.68, 139.69, 'Tokyo', 'Japan'],
	[34.69, 135.5, 'Osaka', 'Japan'],
	[35.01, 135.77, 'Kyoto', 'Japan'],
	[37.57, 126.98, 'Seoul', 'South Korea'],
	[39.9, 116.41, 'Beijing', 'China'],
	[31.23, 121.47, 'Shanghai', 'China'],
	[22.32, 114.17, 'Hong Kong', 'China'],
	[23.13, 113.26, 'Guangzhou', 'China'],
	[25.03, 121.57, 'Taipei', 'Taiwan'],
	[1.35, 103.82, 'Singapore', 'Singapore'],
	[13.76, 100.5, 'Bangkok', 'Thailand'],
	[18.79, 98.98, 'Chiang Mai', 'Thailand'],
	[3.14, 101.69, 'Kuala Lumpur', 'Malaysia'],
	[-6.21, 106.85, 'Jakarta', 'Indonesia'],
	[-8.65, 115.22, 'Denpasar', 'Indonesia'],
	[14.6, 120.98, 'Manila', 'Philippines'],
	[21.03, 105.85, 'Hanoi', 'Vietnam'],
	[10.82, 106.63, 'Ho Chi Minh City', 'Vietnam'],
	[11.56, 104.92, 'Phnom Penh', 'Cambodia'],
	// Oceania
	[-33.87, 151.21, 'Sydney', 'Australia'],
	[-37.81, 144.96, 'Melbourne', 'Australia'],
	[-27.47, 153.03, 'Brisbane', 'Australia'],
	[-31.95, 115.86, 'Perth', 'Australia'],
	[-36.85, 174.76, 'Auckland', 'New Zealand'],
	[-41.29, 174.78, 'Wellington', 'New Zealand'],
	[-45.03, 168.66, 'Queenstown', 'New Zealand']
];

const R_KM = 6371;
function haversineKm(aLat: number, aLon: number, bLat: number, bLon: number): number {
	const dLat = ((bLat - aLat) * Math.PI) / 180;
	const dLon = ((bLon - aLon) * Math.PI) / 180;
	const la1 = (aLat * Math.PI) / 180;
	const la2 = (bLat * Math.PI) / 180;
	const h = Math.sin(dLat / 2) ** 2 + Math.cos(la1) * Math.cos(la2) * Math.sin(dLon / 2) ** 2;
	return 2 * R_KM * Math.asin(Math.min(1, Math.sqrt(h)));
}

export interface NearestCity {
	city: string;
	country: string;
	distanceKm: number;
}

/** Nearest bundled city to (lat, lon) within `maxKm`, or null if nothing is close enough. */
export function nearestCity(lat: number, lon: number, maxKm = 200): NearestCity | null {
	let best: NearestCity | null = null;
	for (const [clat, clon, city, country] of CITIES) {
		const d = haversineKm(lat, lon, clat, clon);
		if (d <= maxKm && (!best || d < best.distanceKm)) best = { city, country, distanceKm: d };
	}
	return best;
}
```

### `src/lib/server/geo/geocodeService.ts`

```ts
/**
 * Reverse geocoding for the Places view. OFF by default and privacy-gated via config `geocode`.
 *  - provider 'offline': nearest bundled city (no network) — coarse/approximate.
 *  - provider 'nominatim': OpenStreetMap's reverse geocoder — accurate, rate-limited to ≤1 req/s
 *    (the only outbound network call this feature makes), opt-in.
 * The background pass fills place_name/place_locality/place_country for geotagged rows; geocode_status
 * tracks 0 none / 1 done / 2 fail. Nothing here runs unless the user enables geocoding.
 */
import { getDb, type DB } from '../db/index';
import { getConfig } from '../config/configService';
import { nearestCity } from './cities';
import { bustBucketsCache } from '../db/queries';
import { log } from '../log';

export interface Place {
	name: string | null;
	locality: string | null;
	country: string | null;
}

let running = false;

function offlinePlace(lat: number, lon: number): Place | null {
	const c = nearestCity(lat, lon);
	if (!c) return { name: null, locality: null, country: null }; // resolved, but nothing close
	return { name: `near ${c.city}`, locality: c.city, country: c.country };
}

async function nominatimPlace(lat: number, lon: number, email: string): Promise<Place> {
	const url = `https://nominatim.openstreetmap.org/reverse?format=jsonv2&zoom=12&lat=${lat}&lon=${lon}`;
	const res = await fetch(url, {
		headers: { 'User-Agent': `LGallery/0.1 (${email || 'local user'})`, Accept: 'application/json' }
	});
	if (!res.ok) throw new Error(`nominatim ${res.status}`);
	const data = (await res.json()) as { name?: string; address?: Record<string, string> };
	const a = data.address ?? {};
	const locality = a.city || a.town || a.village || a.municipality || a.county || a.state || null;
	const country = a.country || null;
	const name = data.name || locality || country || null;
	return { name, locality, country };
}

async function resolve(lat: number, lon: number): Promise<Place> {
	const g = getConfig().geocode;
	if (g.provider === 'nominatim') return nominatimPlace(lat, lon, g.email);
	return offlinePlace(lat, lon) ?? { name: null, locality: null, country: null };
}

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

interface GeoRow {
	id: number;
	gps_lat: number;
	gps_lon: number;
}

function pending(db: DB, limit: number): GeoRow[] {
	return db
		.prepare(
			`SELECT id, gps_lat, gps_lon FROM media
			 WHERE is_trashed = 0 AND has_gps = 1 AND gps_lat IS NOT NULL AND gps_lon IS NOT NULL
			   AND geocode_status = 0
			 ORDER BY taken_ms DESC LIMIT ?`
		)
		.all(limit) as GeoRow[];
}

/**
 * Drain geotagged rows that haven't been geocoded yet. Idempotent (no-op if already running or if
 * geocoding is disabled). Nominatim requests are throttled to honour OSM's ≤1 req/s usage policy.
 */
export function geocodePending(): void {
	if (running) return;
	const cfg = getConfig().geocode;
	if (!cfg.enabled) return;
	running = true;
	void (async () => {
		const db = getDb();
		const done = db.prepare(
			`UPDATE media SET place_name=@name, place_locality=@locality, place_country=@country,
			   geocode_status=1, updated_at=@now WHERE id=@id`
		);
		const fail = db.prepare(`UPDATE media SET geocode_status=2, updated_at=@now WHERE id=@id`);
		let processed = 0;
		try {
			for (;;) {
				const rows = pending(db, 50);
				if (!rows.length) break;
				for (const r of rows) {
					try {
						const p = await resolve(r.gps_lat, r.gps_lon);
						done.run({ id: r.id, now: Date.now(), ...p });
					} catch (e) {
						log.debug(`geocode failed for ${r.id}`, e);
						fail.run({ id: r.id, now: Date.now() });
					}
					processed++;
					if (cfg.provider === 'nominatim') await sleep(1100); // ≤1 req/s
				}
			}
		} catch (e) {
			log.error('geocode pass failed', e);
		} finally {
			running = false;
			if (processed) {
				bustBucketsCache();
				log.info(`Geocoded ${processed} location(s) via ${cfg.provider}.`);
			}
		}
	})();
}
```

### `src/lib/server/http.test.ts`

```ts
import { describe, it, expect } from 'vitest';
import type { Cookies } from '@sveltejs/kit';
import { apiError, parseIds, initialGridWidth } from './http';

describe('apiError', () => {
	it('builds a JSON error Response with the right status + envelope', async () => {
		const r = apiError(404, 'NOT_FOUND', 'gone');
		expect(r.status).toBe(404);
		expect(r.headers.get('content-type')).toContain('application/json');
		expect(await r.json()).toEqual({ error: { code: 'NOT_FOUND', message: 'gone' } });
	});
});

describe('parseIds', () => {
	it('keeps positive integers, drops junk/zero/negatives (happy + failure)', () => {
		expect(parseIds([1, 2, '3', 0, -1, 'x', 2.5, null])).toEqual([1, 2, 3]);
	});
	it('returns [] for non-arrays', () => {
		expect(parseIds('1,2,3')).toEqual([]);
		expect(parseIds(undefined)).toEqual([]);
		expect(parseIds(null)).toEqual([]);
	});
});

describe('initialGridWidth', () => {
	const mk = (v: string | undefined): Cookies => ({ get: () => v }) as unknown as Cookies;
	it('subtracts sidebar + padding for a desktop width', () => {
		expect(initialGridWidth(mk('1440'))).toBe(1440 - 216 - 24);
	});
	it('uses the narrow sidebar under 700px', () => {
		expect(initialGridWidth(mk('600'))).toBe(600 - 64 - 24);
	});
	it('falls back to a default when the cookie is absent or invalid', () => {
		expect(initialGridWidth(mk(undefined))).toBe(1200);
		expect(initialGridWidth(mk('nope'))).toBe(1200);
		expect(initialGridWidth(mk('-5'))).toBe(1200);
	});
	it('never goes below the floor', () => {
		expect(initialGridWidth(mk('100'))).toBe(280);
	});
});
```

### `src/lib/server/http.ts`

```ts
/** Tiny HTTP helpers shared by API endpoints. */
import { json, type Cookies } from '@sveltejs/kit';
import type { ApiErrorBody } from '$shared/types';

/**
 * Estimate the timeline grid's content width from the `lg_w` viewport cookie (set by the boot
 * script in app.html), so the grid can lay out during SSR instead of measuring after hydration.
 * Subtracts the sidebar + horizontal padding; falls back to a sane default when the cookie is absent.
 */
export function initialGridWidth(cookies: Cookies): number {
	const w = Number(cookies.get('lg_w'));
	if (!Number.isFinite(w) || w <= 0) return 1200;
	const sidebar = w <= 700 ? 64 : 216;
	const pad = 24; // TimelineGrid horizontal padding (12px each side)
	return Math.max(280, Math.round(w - sidebar - pad));
}

export function apiError(status: number, code: string, message: string): Response {
	return json({ error: { code, message } } satisfies ApiErrorBody, { status });
}

/** Parse a comma/array list of positive integer ids from a request body field. */
export function parseIds(input: unknown): number[] {
	if (Array.isArray(input)) {
		return input.map((x) => Number(x)).filter((n) => Number.isInteger(n) && n > 0);
	}
	return [];
}
```

### `src/lib/server/lock.ts`

```ts
/**
 * A single process-wide mutex shared by the scanner and the file-mutation service, so user
 * actions (trash/move/rename/restore) never interleave with the scanner's DB writes/sweep.
 * FIFO promise chain. Keep critical sections short — the scanner locks per-batch and around the
 * sweep, NOT for the whole walk, so mutations aren't starved during a long scan.
 */
let chain: Promise<unknown> = Promise.resolve();

export function withLock<T>(fn: () => Promise<T> | T): Promise<T> {
	const run = chain.then(fn, fn);
	chain = run.then(
		() => {},
		() => {}
	);
	return run as Promise<T>;
}
```

### `src/lib/server/log.ts`

```ts
/**
 * Local-only rotating logger. Writes to `data/lgallery.log` and (in dev) the console.
 * Nothing is ever transmitted anywhere — see docs/06-PRIVACY-AND-NETWORK.md.
 */
import fs from 'node:fs';
import path from 'node:path';

type Level = 'debug' | 'info' | 'warn' | 'error';
const ORDER: Record<Level, number> = { debug: 10, info: 20, warn: 30, error: 40 };

interface LogConfig {
	level: Level;
	file: string;
	maxSizeMb: number;
	maxFiles: number;
}

let cfg: LogConfig = { level: 'info', file: 'data/lgallery.log', maxSizeMb: 10, maxFiles: 5 };
let absFile = path.resolve(process.cwd(), cfg.file);
let minOrder = ORDER[cfg.level];
let dirReady = false;

export function initLogger(partial: Partial<LogConfig>): void {
	cfg = { ...cfg, ...partial };
	absFile = path.resolve(process.cwd(), cfg.file);
	minOrder = ORDER[cfg.level] ?? ORDER.info;
	dirReady = false;
	ensureDir();
}

function ensureDir(): void {
	if (dirReady) return;
	try {
		fs.mkdirSync(path.dirname(absFile), { recursive: true });
		dirReady = true;
	} catch {
		/* fall back to console-only */
	}
}

function rotateIfNeeded(): void {
	try {
		const stat = fs.statSync(absFile);
		if (stat.size < cfg.maxSizeMb * 1024 * 1024) return;
		// shift log.(n-1) -> log.n, dropping the oldest
		for (let i = cfg.maxFiles - 1; i >= 1; i--) {
			const from = i === 1 ? absFile : `${absFile}.${i - 1}`;
			const to = `${absFile}.${i}`;
			if (fs.existsSync(from)) {
				try {
					fs.rmSync(to, { force: true });
				} catch {
					/* ignore */
				}
				fs.renameSync(from, to);
			}
		}
	} catch {
		/* file may not exist yet */
	}
}

function write(level: Level, msg: string, meta?: unknown): void {
	if (ORDER[level] < minOrder) return;
	const ts = new Date().toISOString();
	let line = `${ts} [${level.toUpperCase()}] ${msg}`;
	if (meta !== undefined) {
		try {
			line += ' ' + (meta instanceof Error ? (meta.stack ?? meta.message) : JSON.stringify(meta));
		} catch {
			line += ' ' + String(meta);
		}
	}
	ensureDir();
	if (dirReady) {
		try {
			rotateIfNeeded();
			fs.appendFileSync(absFile, line + '\n');
		} catch {
			/* ignore disk errors; never crash on logging */
		}
	}
	// Mirror warn/error to the console always; everything else only in dev.
	const toConsole = level === 'warn' || level === 'error' || process.env.NODE_ENV !== 'production';
	if (toConsole) {
		const fn = level === 'error' ? console.error : level === 'warn' ? console.warn : console.log;
		fn(line);
	}
}

export const log = {
	debug: (msg: string, meta?: unknown) => write('debug', msg, meta),
	info: (msg: string, meta?: unknown) => write('info', msg, meta),
	warn: (msg: string, meta?: unknown) => write('warn', msg, meta),
	error: (msg: string, meta?: unknown) => write('error', msg, meta)
};
```

### `src/lib/server/media/editService.test.ts`

```ts
import { describe, it, expect, beforeAll, afterAll, vi } from 'vitest';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import sharp from 'sharp';
import { DEFAULT_EDITS } from '$shared/edits';
import { thumbPathFor } from './render-core.mjs';

const DIR = path.join(os.tmpdir(), `lg-edit-${process.pid}`);
const SRC = path.join(DIR, 'src.jpg');

// editService reads thumbnail config via configService.getConfig — stub it to a temp dir.
vi.mock('../config/configService', () => ({
	getConfig: () => ({
		thumbnails: { dir: DIR, grid: { longEdge: 64, quality: 70 }, preview: { longEdge: 200, quality: 80 } }
	})
}));

beforeAll(async () => {
	fs.mkdirSync(DIR, { recursive: true });
	// 400×200 image so a 90° rotation visibly swaps dimensions.
	await sharp({ create: { width: 400, height: 200, channels: 3, background: { r: 200, g: 120, b: 40 } } })
		.jpeg()
		.toFile(SRC);
});
afterAll(() => {
	try {
		fs.rmSync(DIR, { recursive: true, force: true });
	} catch {
		/* temp */
	}
});

describe('editService.renderEditedThumbs', () => {
	it('applies a 90° rotation (dimensions swap) and writes the sizes', async () => {
		const { renderEditedThumbs } = await import('./editService');
		const r = await renderEditedThumbs(501, SRC, { ...DEFAULT_EDITS, rotate: 90 }, ['grid', 'preview']);
		// 400x200 rotated 90° → 200x400 (portrait)
		expect(r.height).toBeGreaterThan(r.width!);
		expect(typeof r.blurhash).toBe('string');
		expect(fs.existsSync(thumbPathFor(DIR, 501, 'grid'))).toBe(true);
		expect(fs.existsSync(thumbPathFor(DIR, 501, 'preview'))).toBe(true);
	});

	it('applies a crop that changes the aspect ratio', async () => {
		const { renderEditedThumbs } = await import('./editService');
		const full = await renderEditedThumbs(502, SRC, { ...DEFAULT_EDITS }, ['preview']);
		const cropped = await renderEditedThumbs(
			503,
			SRC,
			{ ...DEFAULT_EDITS, crop: { x: 0, y: 0, w: 0.5, h: 1 } },
			['preview']
		);
		// Cropping the left half halves the width-to-height ratio.
		const fullAR = full.width! / full.height!;
		const cropAR = cropped.width! / cropped.height!;
		expect(cropAR).toBeLessThan(fullAR);
	});

	it('a grayscale filter still renders successfully', async () => {
		const { renderEditedThumbs } = await import('./editService');
		const r = await renderEditedThumbs(504, SRC, { ...DEFAULT_EDITS, filter: 'mono' }, ['grid']);
		expect(r.width).toBe(400);
		expect(fs.existsSync(thumbPathFor(DIR, 504, 'grid'))).toBe(true);
	});
});
```

### `src/lib/server/media/editService.ts`

```ts
/**
 * Non-destructive editing: apply EditOps (geometry + light/colour + filter preset) to the ORIGINAL
 * with sharp and render derivatives. The source file is never modified — edits live as JSON on the
 * row and are re-applied at render time. Editing is rare (save-time / generate-on-miss), so we
 * realize the transformed image to a buffer once for correct post-crop dimensions, then render the
 * thumb sizes from it via the shared render core.
 */
import fs from 'node:fs';
import sharp from 'sharp';
import { renderSizesFromPipeline } from './render-core.mjs';
import { renderCfg, type ThumbResult } from './thumbnailService';
import type { ThumbSize } from '../paths';
import type { EditOps } from '$shared/edits';

/** Apply the colour/light/filter ops to a pipeline. Geometry is applied separately (needs dims). */
function applyColour(pipe: sharp.Sharp, ops: EditOps, hasAlpha: boolean): sharp.Sharp {
	let brightness = ops.brightness;
	let contrast = ops.contrast;
	let saturate = ops.saturation * (1 + ops.vibrance * 0.5);
	let warmth = ops.warmth;
	let grayscale = false;
	let normalize = false;
	let sepia = false;

	switch (ops.filter) {
		case 'vivid':
			saturate *= 1.3;
			contrast *= 1.08;
			break;
		case 'warm':
			warmth = Math.min(1, warmth + 0.35);
			saturate *= 1.05;
			break;
		case 'cool':
			warmth = Math.max(-1, warmth - 0.35);
			break;
		case 'fade':
			contrast *= 0.85;
			brightness *= 1.05;
			saturate *= 0.85;
			break;
		case 'mono':
			grayscale = true;
			break;
		case 'sepia':
			grayscale = true;
			sepia = true;
			break;
		case 'noir':
			grayscale = true;
			contrast *= 1.2;
			break;
		case 'auto':
			normalize = true;
			break;
	}

	if (normalize) pipe = pipe.normalize();
	if (grayscale) pipe = pipe.grayscale();
	pipe = pipe.modulate({ brightness, saturation: grayscale ? 1 : Math.max(0, saturate) });
	if (contrast !== 1) pipe = pipe.linear(contrast, 128 * (1 - contrast));
	if (warmth !== 0 && !grayscale) {
		const w = warmth * 0.15;
		// Warm = boost red / cut blue; per-channel array must match the channel count.
		pipe = hasAlpha ? pipe.linear([1 + w, 1, 1 - w, 1], [0, 0, 0, 0]) : pipe.linear([1 + w, 1, 1 - w], [0, 0, 0]);
	}
	if (sepia) pipe = pipe.tint({ r: 112, g: 66, b: 20 });
	return pipe;
}

/**
 * Build the fully-transformed image as a buffer. Order: exif auto-orient → crop → flip → rotate →
 * colour. Crop is defined against the exif-oriented image (so the editor's crop overlay never has to
 * deal with the user rotation/flip), then orientation is applied.
 */
async function buildEditedBuffer(srcPath: string, ops: EditOps): Promise<Buffer> {
	const srcMeta = await sharp(srcPath, { failOn: 'none' }).metadata();
	let pipe = sharp(srcPath, { failOn: 'none', animated: false }).rotate(); // exif auto-orient

	if (ops.crop) {
		// Realize the oriented image so we can extract in concrete pixels.
		const buf = await pipe.toBuffer();
		const m = await sharp(buf).metadata();
		const W = m.width ?? 0;
		const H = m.height ?? 0;
		const left = Math.min(W - 1, Math.max(0, Math.round(ops.crop.x * W)));
		const top = Math.min(H - 1, Math.max(0, Math.round(ops.crop.y * H)));
		const width = Math.max(1, Math.min(W - left, Math.round(ops.crop.w * W)));
		const height = Math.max(1, Math.min(H - top, Math.round(ops.crop.h * H)));
		pipe = sharp(buf).extract({ left, top, width, height });
	}

	if (ops.flipH) pipe = pipe.flop();
	if (ops.flipV) pipe = pipe.flip();
	if (ops.rotate) pipe = pipe.rotate(ops.rotate);

	pipe = applyColour(pipe, ops, !!srcMeta.hasAlpha);
	return pipe.toBuffer();
}

/** Render grid/grid2x/preview from the edited image and return blurhash + post-edit dimensions. */
export async function renderEditedThumbs(
	id: number,
	srcPath: string,
	ops: EditOps,
	sizes: ThumbSize[]
): Promise<ThumbResult> {
	const buf = await buildEditedBuffer(srcPath, ops);
	const meta = await sharp(buf).metadata();
	const blurhash = await renderSizesFromPipeline(sharp(buf, { failOn: 'none' }), id, renderCfg(), sizes);
	return { width: meta.width ?? null, height: meta.height ?? null, blurhash };
}

/** Write a full-resolution edited copy to disk (keeps the source untouched). */
export async function exportEditedCopy(srcPath: string, ops: EditOps, destPath: string): Promise<void> {
	const buf = await buildEditedBuffer(srcPath, ops);
	await fs.promises.writeFile(destPath, buf);
}
```

### `src/lib/server/media/exifService.test.ts`

```ts
import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import sharp from 'sharp';
import { extractImageMeta } from './exifService';
import { localDayFromMs } from '$shared/format';

let dir: string;
let png: string;
let bad: string;
const MTIME = Date.parse('2022-03-04T10:00:00Z');

beforeAll(async () => {
	dir = await fs.promises.mkdtemp(path.join(os.tmpdir(), 'lg-exif-'));
	png = path.join(dir, 'no-exif.png');
	await sharp({ create: { width: 120, height: 80, channels: 3, background: '#246' } })
		.png()
		.toFile(png);
	bad = path.join(dir, 'not-an-image.jpg');
	await fs.promises.writeFile(bad, 'this is not a real image');
});
afterAll(async () => {
	await fs.promises.rm(dir, { recursive: true, force: true });
});

describe('extractImageMeta', () => {
	it('falls back to mtime when there is no EXIF date (happy fallback path)', async () => {
		const m = await extractImageMeta(png, MTIME);
		expect(m.takenSource).toBe('mtime');
		expect(m.takenMs).toBe(MTIME);
		expect(m.takenLocalDay).toBe(localDayFromMs(MTIME));
		expect(m.hasGps).toBe(false);
		expect(m.gpsLat).toBeNull();
	});
	it('never throws on an undecodable/corrupt file (failure path) — still returns mtime', async () => {
		const m = await extractImageMeta(bad, MTIME);
		expect(m.takenSource).toBe('mtime');
		expect(m.takenMs).toBe(MTIME);
	});
});
```

### `src/lib/server/media/exifService.ts`

```ts
/**
 * EXIF / metadata extraction via exifr. Pulls date, GPS, camera, orientation, dimensions.
 * Date policy (docs/05-PERFORMANCE.md): DateTimeOriginal is interpreted as wall-clock and
 * stored as UTC ms (no shift) so day grouping needs no runtime timezone math.
 */
import exifr from 'exifr';
import { wallClockToMs, localDayFromMs } from '$shared/format';
import type { TakenSource } from '$shared/types';

export interface ExtractedMeta {
	width: number | null;
	height: number | null;
	takenMs: number | null;
	takenLocalDay: string | null;
	takenSource: TakenSource | null;
	hasGps: boolean;
	gpsLat: number | null;
	gpsLon: number | null;
	cameraMake: string | null;
	cameraModel: string | null;
	lens: string | null;
	orientation: number | null;
}

const EMPTY: ExtractedMeta = {
	width: null,
	height: null,
	takenMs: null,
	takenLocalDay: null,
	takenSource: null,
	hasGps: false,
	gpsLat: null,
	gpsLon: null,
	cameraMake: null,
	cameraModel: null,
	lens: null,
	orientation: null
};

function dateToWallClockMs(d: unknown): number | null {
	if (!(d instanceof Date) || isNaN(d.getTime())) return null;
	// exifr builds the Date from the EXIF wall-clock in the runtime's local zone, so the
	// LOCAL components are the original capture wall-clock. Re-anchor them to UTC.
	return wallClockToMs(
		d.getFullYear(),
		d.getMonth() + 1,
		d.getDate(),
		d.getHours(),
		d.getMinutes(),
		d.getSeconds()
	);
}

/**
 * Extract metadata for an image. `mtimeMs` is the fallback when no EXIF date exists
 * (screenshots, downloads) — recorded as taken_source='mtime' so ordering is explainable.
 */
export async function extractImageMeta(filePath: string, mtimeMs: number): Promise<ExtractedMeta> {
	let data: Record<string, unknown> | null = null;
	try {
		// `pick` narrows to just the tags we need; cast because exifr's Options typing is
		// awkward when mixing segment flags with `pick`.
		const options = {
			gps: true,
			translateValues: false, // keep Orientation numeric (1–8), not a translated string
			reviveValues: true,
			pick: [
				'DateTimeOriginal',
				'CreateDate',
				'ImageWidth',
				'ImageHeight',
				'ExifImageWidth',
				'ExifImageHeight',
				'Make',
				'Model',
				'LensModel',
				'Orientation',
				'latitude',
				'longitude'
			]
		} as unknown as Parameters<typeof exifr.parse>[1];
		data = (await exifr.parse(filePath, options)) as Record<string, unknown> | null;
	} catch {
		data = null;
	}

	const out: ExtractedMeta = { ...EMPTY };
	if (data) {
		const takenMs =
			dateToWallClockMs(data.DateTimeOriginal) ?? dateToWallClockMs(data.CreateDate);
		if (takenMs != null) {
			out.takenMs = takenMs;
			out.takenLocalDay = localDayFromMs(takenMs);
			out.takenSource = 'exif';
		}
		out.width = (data.ImageWidth as number) ?? (data.ExifImageWidth as number) ?? null;
		out.height = (data.ImageHeight as number) ?? (data.ExifImageHeight as number) ?? null;
		out.orientation = (data.Orientation as number) ?? null;
		// Orientations 5–8 rotate 90°/270°: report display (post-rotation) dimensions so the
		// justified grid lays the tile out with the correct aspect ratio.
		if (out.orientation && out.orientation >= 5 && out.width && out.height) {
			[out.width, out.height] = [out.height, out.width];
		}
		out.cameraMake = ((data.Make as string) ?? '').trim() || null;
		out.cameraModel = ((data.Model as string) ?? '').trim() || null;
		out.lens = ((data.LensModel as string) ?? '').trim() || null;
		const lat = data.latitude as number | undefined;
		const lon = data.longitude as number | undefined;
		if (typeof lat === 'number' && typeof lon === 'number' && (lat !== 0 || lon !== 0)) {
			out.hasGps = true;
			out.gpsLat = lat;
			out.gpsLon = lon;
		}
	}

	// Fallback date from mtime if EXIF had none.
	if (out.takenMs == null) {
		out.takenMs = mtimeMs;
		out.takenLocalDay = localDayFromMs(mtimeMs);
		out.takenSource = 'mtime';
	}
	return out;
}
```

### `src/lib/server/media/fileService.ts`

```ts
/**
 * All real-file mutations (trash / restore / permanent-delete / move / rename) funnel through
 * here, serialized by an in-process mutex so user actions never race the scanner or each other.
 * The DB row is updated in the same logical step as the filesystem change. See docs/07 + docs/08.
 */
import fs from 'node:fs';
import path from 'node:path';
import { getDb, type DB } from '../db/index';
import { bustBucketsCache } from '../db/queries';
import { getConfig, getEnabledRoots, getTrashDir } from '../config/configService';
import {
	assertWithinRoots,
	isWithin,
	normalizePath,
	realPathWithinRoots,
	splitPath,
	thumbPath,
	storyboardPath,
	PathError
} from '../paths';
import { withLock } from '../lock';
import { log } from '../log';
import type { BulkResult } from '$shared/types';

function toStored(abs: string): string {
	return normalizePath(abs);
}

/** Find the enabled root that contains `dest` (segment-aware). Throws if none. */
function owningRoot(dest: string, roots: string[]): string {
	const found = roots.find((r) => isWithin(dest, r));
	if (!found) throw new PathError('resolved destination is outside the allowed roots');
	return found;
}

/**
 * Move a file. Across volumes (EXDEV) fall back to: copy to a temp on the DEST volume, atomic
 * rename into place, then unlink the source only after — so a crash mid-copy leaves at most a
 * stray `.lgpart` temp (ignored by the scanner), never a half-written media file or a lost source.
 */
async function moveFile(src: string, dest: string): Promise<void> {
	await fs.promises.mkdir(path.dirname(dest), { recursive: true });
	try {
		await fs.promises.rename(src, dest);
	} catch (e) {
		if ((e as NodeJS.ErrnoException).code === 'EXDEV') {
			const tmp = `${dest}.lgpart-${process.pid}-${Math.round(performance.now())}`;
			// COPYFILE_EXCL: fail rather than clobber if the temp name somehow exists.
			await fs.promises.copyFile(src, tmp, fs.constants.COPYFILE_EXCL);
			await fs.promises.rename(tmp, dest); // atomic within the dest volume
			await fs.promises.unlink(src);
		} else {
			throw e;
		}
	}
}

/** Pick a non-colliding destination path by appending " (n)" before the extension. */
async function uniquePath(target: string): Promise<string> {
	try {
		await fs.promises.access(target);
	} catch {
		return target; // free
	}
	const dir = path.dirname(target);
	const ext = path.extname(target);
	const base = path.basename(target, ext);
	for (let i = 1; i < 1000; i++) {
		const cand = path.join(dir, `${base} (${i})${ext}`);
		try {
			await fs.promises.access(cand);
		} catch {
			return cand;
		}
	}
	return path.join(dir, `${base} (${Date.now()})${ext}`);
}

function deleteThumbFiles(id: number): void {
	const dir = getConfig().thumbnails.dir;
	for (const f of [
		thumbPath(dir, id, 'grid'),
		thumbPath(dir, id, 'grid2x'),
		thumbPath(dir, id, 'preview'),
		storyboardPath(dir, id)
	]) {
		try {
			fs.rmSync(f, { force: true });
		} catch {
			/* best effort */
		}
	}
}

async function bulk(
	ids: number[],
	op: (db: DB, id: number) => Promise<void>
): Promise<BulkResult> {
	return withLock(async () => {
		const db = getDb();
		const ok: number[] = [];
		const failed: { id: number; error: string }[] = [];
		for (const id of ids) {
			try {
				await op(db, id);
				ok.push(id);
			} catch (e) {
				failed.push({ id, error: e instanceof Error ? e.message : String(e) });
			}
		}
		if (ok.length) bustBucketsCache(); // trashing/restoring/deleting changes timeline counts
		return { ok, failed };
	});
}

export function trash(ids: number[]): Promise<BulkResult> {
	const trashDir = getTrashDir();
	return bulk(ids, async (db, id) => {
		const row = db.prepare(`SELECT path, filename, size_bytes FROM media WHERE id=?`).get(id) as
			| { path: string; filename: string; size_bytes: number }
			| undefined;
		if (!row) throw new Error('not found');
		assertWithinRoots(row.path, getEnabledRoots());
		const dest = path.join(path.resolve(process.cwd(), getConfig().trash.dir), `${id}__${row.filename}`);
		await moveFile(row.path, dest);
		const now = Date.now();
		db.transaction(() => {
			db.prepare(
				`INSERT INTO trash(media_id, original_path, trash_path, size_bytes, trashed_at)
				 VALUES(?,?,?,?,?)`
			).run(id, row.path, toStored(dest), row.size_bytes, now);
			db.prepare(`UPDATE media SET is_trashed=1, updated_at=? WHERE id=?`).run(now, id);
		})();
		void trashDir;
	});
}

export function restore(ids: number[]): Promise<BulkResult> {
	return bulk(ids, async (db, id) => {
		const t = db
			.prepare(`SELECT id, original_path, trash_path FROM trash WHERE media_id=? ORDER BY trashed_at DESC LIMIT 1`)
			.get(id) as { id: number; original_path: string; trash_path: string } | undefined;
		if (!t) throw new Error('no trash record');
		assertWithinRoots(t.original_path, getEnabledRoots());
		const dest = await uniquePath(t.original_path);
		await moveFile(t.trash_path, dest);
		const parts = splitPath(owningRoot(toStored(dest), getEnabledRoots()), toStored(dest));
		const now = Date.now();
		db.transaction(() => {
			db.prepare(
				`UPDATE media SET is_trashed=0, path=@path, dir=@dir, filename=@filename, rel_path=@rel, updated_at=@now WHERE id=@id`
			).run({ path: toStored(dest), dir: parts.dir, filename: parts.filename, rel: parts.relPath, now, id });
			db.prepare(`DELETE FROM trash WHERE id=?`).run(t.id);
		})();
	});
}

export function permanentDelete(ids: number[]): Promise<BulkResult> {
	const trashDir = getTrashDir();
	return bulk(ids, async (db, id) => {
		const t = db.prepare(`SELECT id, trash_path FROM trash WHERE media_id=?`).all(id) as {
			id: number;
			trash_path: string;
		}[];
		for (const rec of t) {
			assertWithinRoots(rec.trash_path, [], [trashDir]);
			try {
				await fs.promises.rm(rec.trash_path, { force: true });
			} catch {
				/* best effort */
			}
		}
		db.transaction(() => {
			db.prepare(`DELETE FROM trash WHERE media_id=?`).run(id);
			db.prepare(`DELETE FROM media WHERE id=?`).run(id);
		})();
		deleteThumbFiles(id);
	});
}

export async function move(ids: number[], destDir: string): Promise<BulkResult> {
	const roots = getEnabledRoots();
	// realpath-validate the (client-supplied) destination dir so a symlink/junction inside a
	// root can't redirect the write outside it.
	const destNorm = await realPathWithinRoots(destDir, roots);
	return bulk(ids, async (db, id) => {
		const row = db.prepare(`SELECT path, filename, root_id FROM media WHERE id=?`).get(id) as
			| { path: string; filename: string; root_id: number }
			| undefined;
		if (!row) throw new Error('not found');
		assertWithinRoots(row.path, roots);
		const target = await uniquePath(path.join(destNorm, row.filename));
		await moveFile(row.path, target);
		const ownerRoot = owningRoot(toStored(target), roots);
		const rootRow = db.prepare(`SELECT id FROM roots WHERE path=?`).get(ownerRoot) as { id: number } | undefined;
		const parts = splitPath(ownerRoot, toStored(target));
		db.prepare(
			`UPDATE media SET path=@path, dir=@dir, filename=@filename, rel_path=@rel, root_id=@root, updated_at=@now WHERE id=@id`
		).run({
			path: toStored(target),
			dir: parts.dir,
			filename: parts.filename,
			rel: parts.relPath,
			root: rootRow?.id ?? row.root_id,
			now: Date.now(),
			id
		});
	});
}

export function rename(id: number, newName: string): Promise<{ ok: boolean }> {
	if (/[\\/]/.test(newName) || newName.includes('\0') || newName === '' || newName === '.' || newName === '..') {
		return Promise.reject(new Error('invalid file name'));
	}
	return withLock(async () => {
		const db = getDb();
		const row = db.prepare(`SELECT path, dir, root_id FROM media WHERE id=?`).get(id) as
			| { path: string; dir: string; root_id: number }
			| undefined;
		if (!row) throw new Error('not found');
		assertWithinRoots(row.path, getEnabledRoots());
		const target = await uniquePath(path.join(row.dir, newName));
		await moveFile(row.path, target);
		const parts = splitPath(owningRoot(toStored(target), getEnabledRoots()), toStored(target));
		db.prepare(
			`UPDATE media SET path=@path, filename=@filename, rel_path=@rel, ext=@ext, updated_at=@now WHERE id=@id`
		).run({
			path: toStored(target),
			filename: parts.filename,
			rel: parts.relPath,
			ext: parts.ext,
			now: Date.now(),
			id
		});
		return { ok: true };
	});
}

/** Permanently remove trash items older than `trash.autoPurgeDays` (0 = never). */
export async function autoPurgeTrash(): Promise<number> {
	const days = getConfig().trash.autoPurgeDays;
	if (!days) return 0;
	const db = getDb();
	const cutoff = Date.now() - days * 24 * 3600 * 1000;
	const stale = db.prepare(`SELECT id, media_id, trash_path FROM trash WHERE trashed_at < ?`).all(cutoff) as {
		id: number;
		media_id: number | null;
		trash_path: string;
	}[];
	const ids = [...new Set(stale.map((s) => s.media_id).filter((x): x is number => x != null))];
	if (ids.length) await permanentDelete(ids);
	// Reclaim orphaned trash rows (media_id NULL, e.g. from an older cascade) keyed by trash.id —
	// otherwise their files + rows would linger forever (permanentDelete keys on media_id).
	const orphans = stale.filter((s) => s.media_id == null);
	if (orphans.length) {
		await withLock(async () => {
			const delRow = db.prepare(`DELETE FROM trash WHERE id = ?`);
			for (const o of orphans) {
				try {
					await fs.promises.rm(o.trash_path, { force: true });
				} catch {
					/* best effort */
				}
				delRow.run(o.id);
			}
		});
	}
	return ids.length + orphans.length;
}

/** Remove thumbnail shard files with no corresponding media row (crash cleanup). */
export async function orphanThumbnailGc(): Promise<number> {
	const db = getDb();
	const dir = path.resolve(process.cwd(), getConfig().thumbnails.dir);
	let removed = 0;
	let shards: string[];
	try {
		shards = await fs.promises.readdir(dir);
	} catch {
		return 0;
	}
	const exists = db.prepare(`SELECT 1 FROM media WHERE id=?`);
	for (const shard of shards) {
		const shardDir = path.join(dir, shard);
		let files: string[];
		try {
			files = await fs.promises.readdir(shardDir);
		} catch {
			continue;
		}
		for (const f of files) {
			const m = /^(\d+)_/.exec(f);
			if (!m) continue;
			if (!exists.get(Number(m[1]))) {
				try {
					await fs.promises.rm(path.join(shardDir, f), { force: true });
					removed++;
				} catch {
					/* ignore */
				}
			}
		}
	}
	if (removed) log.info(`Orphan GC removed ${removed} thumbnail file(s).`);
	return removed;
}
```

### `src/lib/server/media/hashService.test.ts`

```ts
import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { quickHash } from './hashService';

let dir: string;
const files: Record<string, { p: string; size: number }> = {};

async function write(name: string, content: Buffer) {
	const p = path.join(dir, name);
	await fs.promises.writeFile(p, content);
	files[name] = { p, size: content.length };
}

beforeAll(async () => {
	dir = await fs.promises.mkdtemp(path.join(os.tmpdir(), 'lg-hash-'));
	await write('a.bin', Buffer.from('hello world'));
	await write('b.bin', Buffer.from('hello world')); // identical content
	await write('c.bin', Buffer.from('different!!'));
	await write('big1.bin', Buffer.concat([Buffer.alloc(200_000, 1), Buffer.from('TAIL-A')]));
	await write('big2.bin', Buffer.concat([Buffer.alloc(200_000, 1), Buffer.from('TAIL-B')])); // differ only in tail
});
afterAll(async () => {
	await fs.promises.rm(dir, { recursive: true, force: true });
});

describe('quickHash', () => {
	it('is stable for identical content (happy path) and prefixed by size', async () => {
		const a = await quickHash(files['a.bin'].p, files['a.bin'].size);
		const b = await quickHash(files['b.bin'].p, files['b.bin'].size);
		expect(a).toBe(b);
		expect(a.startsWith(`${files['a.bin'].size}-`)).toBe(true);
	});
	it('differs for different content of the same length', async () => {
		const a = await quickHash(files['a.bin'].p, files['a.bin'].size);
		const c = await quickHash(files['c.bin'].p, files['c.bin'].size);
		expect(a).not.toBe(c);
	});
	it('hashes the tail too (large files differing only at the end)', async () => {
		const h1 = await quickHash(files['big1.bin'].p, files['big1.bin'].size);
		const h2 = await quickHash(files['big2.bin'].p, files['big2.bin'].size);
		expect(h1).not.toBe(h2);
	});
	it('rejects a missing file (failure path)', async () => {
		await expect(quickHash(path.join(dir, 'nope.bin'), 10)).rejects.toBeTruthy();
	});
});
```

### `src/lib/server/media/hashService.ts`

```ts
/**
 * quick_hash for exact-duplicate detection: file size + SHA-1 of the head (and tail for
 * larger files). Cheap, collision-resistant enough when combined with size. Perceptual
 * hashing (phash) for near-dupes is a roadmap refinement.
 */
import fs from 'node:fs';
import crypto from 'node:crypto';

const CHUNK = 65536;

export async function quickHash(filePath: string, size: number): Promise<string> {
	const fh = await fs.promises.open(filePath, 'r');
	try {
		const hash = crypto.createHash('sha1');
		const headLen = Math.min(CHUNK, size);
		if (headLen > 0) {
			const head = Buffer.alloc(headLen);
			await fh.read(head, 0, headLen, 0);
			hash.update(head);
		}
		// Hash the tail too whenever the file is larger than the head chunk, so files that share a
		// head but differ later aren't flagged as identical. quick_hash is a candidate key; the
		// dedupe UI groups by it for the user to review, not auto-delete.
		if (size > CHUNK) {
			const tailLen = Math.min(CHUNK, size - CHUNK);
			const tail = Buffer.alloc(tailLen);
			await fh.read(tail, 0, tailLen, size - tailLen);
			hash.update(tail);
		}
		return `${size}-${hash.digest('hex')}`;
	} finally {
		await fh.close();
	}
}
```

### `src/lib/server/media/pipeline.test.ts`

```ts
import { describe, it, expect } from 'vitest';
import { openTestDb, type DB } from '../db/index';
import { pendPredicateFor, retryBackoffMs } from './pipeline';

/** Insert a media row with explicit pipeline-status columns; everything else gets sane defaults. */
function insert(
	db: DB,
	o: {
		id: number;
		meta_status?: number;
		thumb_status?: number;
		meta_attempts?: number;
		thumb_attempts?: number;
		next_retry_ms?: number | null;
		is_trashed?: number;
	}
): void {
	db.prepare(
		`INSERT INTO media (id, path, root_id, rel_path, dir, filename, ext, type, size_bytes, mtime_ms,
		   meta_status, thumb_status, meta_attempts, thumb_attempts, next_retry_ms, is_trashed,
		   taken_ms, created_at, updated_at)
		 VALUES (@id, @path, 1, @path, 'd:/r', @path, 'jpg', 'photo', 1, 1,
		   @meta_status, @thumb_status, @meta_attempts, @thumb_attempts, @next_retry_ms, @is_trashed,
		   @id, 1, 1)`
	).run({
		id: o.id,
		path: `d:/r/${o.id}.jpg`,
		meta_status: o.meta_status ?? 2,
		thumb_status: o.thumb_status ?? 2,
		meta_attempts: o.meta_attempts ?? 0,
		thumb_attempts: o.thumb_attempts ?? 0,
		next_retry_ms: o.next_retry_ms ?? null,
		is_trashed: o.is_trashed ?? 0
	});
}

function selectIds(db: DB, max: number, now: number): number[] {
	return (
		db.prepare(`SELECT id FROM media WHERE is_trashed = 0 AND ${pendPredicateFor(max, now)} ORDER BY id`).all() as {
			id: number;
		}[]
	).map((r) => r.id);
}

describe('pipeline retry selection (pendPredicate)', () => {
	const NOW = 1_000_000_000_000;

	function seed(): DB {
		const db = openTestDb(':memory:');
		db.prepare(`INSERT INTO roots(id,path,label,enabled) VALUES(1,'d:/r','R',1)`).run();
		insert(db, { id: 1, meta_status: 0, thumb_status: 0 }); // never processed
		insert(db, { id: 2, meta_status: 2, thumb_status: 1 }); // thumb in-flight
		insert(db, { id: 3, meta_status: 2, thumb_status: 2 }); // fully done → excluded
		insert(db, { id: 4, thumb_status: 3, thumb_attempts: 1, next_retry_ms: NOW - 1 }); // retriable now
		insert(db, { id: 5, thumb_status: 3, thumb_attempts: 1, next_retry_ms: NOW + 60_000 }); // backing off
		insert(db, { id: 6, thumb_status: 3, thumb_attempts: 3, next_retry_ms: NOW - 1 }); // hit cap → excluded
		insert(db, { id: 7, meta_status: 3, meta_attempts: 0, next_retry_ms: null }); // failed, no retry stamp yet
		return db;
	}

	it('selects pending (0/1) and retriable failures, excludes done / capped / backing-off', () => {
		const ids = selectIds(seed(), 3, NOW);
		expect(ids).toContain(1); // pending
		expect(ids).toContain(2); // in-flight
		expect(ids).toContain(4); // retry window elapsed
		expect(ids).toContain(7); // failed but under cap, NULL retry = eligible
		expect(ids).not.toContain(3); // done
		expect(ids).not.toContain(5); // still backing off
		expect(ids).not.toContain(6); // exceeded maxAttempts
	});

	it('a failure becomes eligible again once its backoff elapses', () => {
		const db = seed();
		// id 5 is backing off until NOW+60s; advancing "now" past it makes it selectable.
		expect(selectIds(db, 3, NOW)).not.toContain(5);
		expect(selectIds(db, 3, NOW + 61_000)).toContain(5);
	});

	it('trashed rows are never selected', () => {
		const db = seed();
		insert(db, { id: 8, meta_status: 0, thumb_status: 0, is_trashed: 1 });
		expect(selectIds(db, 3, NOW)).not.toContain(8);
	});
});

describe('retryBackoffMs', () => {
	it('grows exponentially from 30s and caps at 30 minutes', () => {
		expect(retryBackoffMs(1)).toBe(30_000);
		expect(retryBackoffMs(2)).toBe(60_000);
		expect(retryBackoffMs(3)).toBe(120_000);
		expect(retryBackoffMs(20)).toBe(30 * 60_000); // capped
	});
	it('is monotonic non-decreasing', () => {
		let prev = 0;
		for (let a = 1; a <= 12; a++) {
			const v = retryBackoffMs(a);
			expect(v).toBeGreaterThanOrEqual(prev);
			prev = v;
		}
	});
});
```

### `src/lib/server/media/pipeline.ts`

```ts
/**
 * Media pipeline: drains pending rows (metadata → thumbnails, priority order) and resumes after a
 * restart from meta_status/thumb_status, newest-first. Visible-range hints from the client jump the
 * queue.
 *
 * Scale model (200k libraries): metadata (exif/ffprobe + quick-hash) runs on the main thread, but
 * the CPU-heavy image thumbnailing is dispatched to a worker_threads pool (see workerPool.ts) so all
 * cores decode in parallel with blurhash off the main thread. The MAIN thread still owns every DB
 * write (better-sqlite3 is single-threaded). If the pool can't start, we transparently fall back to
 * in-process rendering. Failed rows are retried with bounded backoff (schema v3), and the 1600px
 * `preview` is generated lazily on first lightbox open unless `thumbnails.eagerPreview` is set.
 */
import os from 'node:os';
import { getDb, type DB } from '../db/index';
import { getConfig } from '../config/configService';
import { setPending, recordProcessed } from '../scan/scanState';
import { extractImageMeta } from './exifService';
import { makeImageThumbs, ensureImageSize, thumbExists, ALL_SIZES, EAGER_SIZES } from './thumbnailService';
import { probeVideo, makeVideoThumbs } from './videoService';
import { quickHash } from './hashService';
import { poolAvailable, runThumbTask } from './workerPool';
import type { ThumbSize } from '../paths';
import { bustBucketsCache } from '../db/queries';
import { log } from '../log';

interface PendingRow {
	id: number;
	path: string;
	type: 'photo' | 'video';
	meta_status: number;
	thumb_status: number;
	meta_attempts: number;
	thumb_attempts: number;
	mtime_ms: number;
	size_bytes: number;
	width: number | null;
	height: number | null;
	duration_ms: number | null;
	edit_ops: string | null;
}

const COLS = `id, path, type, meta_status, thumb_status, meta_attempts, thumb_attempts,
	mtime_ms, size_bytes, width, height, duration_ms, edit_ops`;

const priority = new Set<number>();
// Per-id in-flight guard: a media row is processed by exactly one worker at a time, so the
// background drain and a concurrent generate-on-miss can't both write the same thumbnail file.
const inFlight = new Map<number, Promise<void>>();
// Per-(id,size) guard for the lazy generate-on-miss of a single deferred size (e.g. preview).
const inFlightSize = new Map<string, Promise<void>>();
let draining = false;

export function setVisiblePriority(ids: number[]): void {
	priority.clear();
	for (const id of ids) priority.add(id);
	processPending(); // a new visible range may need on-demand work
}

function maxAttempts(): number {
	return getConfig().scan.maxAttempts ?? 3;
}

/** Capped exponential backoff for the n-th retry attempt (30s, 60s, 120s, … capped at 30m). */
export function retryBackoffMs(attempts: number): number {
	return Math.min(30 * 60_000, 30_000 * 2 ** Math.max(0, attempts - 1));
}

/** Orchestration concurrency — how many rows are processed at once. With workers, the heavy decode
 *  is off-thread so we keep more rows in flight (metadata overlaps); without, leave HTTP headroom. */
function concurrency(): number {
	const cfg = getConfig().scan;
	if (cfg.concurrency > 0) return cfg.concurrency;
	const cores = os.cpus()?.length ?? 2;
	return cfg.useWorkers ? Math.max(2, cores) : Math.max(1, cores - 2);
}

/** Pending predicate: never-done rows (0/1) plus retriable failures (3 under the attempt cap whose
 *  backoff has elapsed). Computed ints are inlined (safe — not user input) to avoid mixing named and
 *  positional binds with the id IN (...) lists. Exported (parameterized) for unit testing. */
export function pendPredicateFor(max: number, now: number): string {
	return `(
		meta_status IN (0,1) OR thumb_status IN (0,1)
		OR (meta_status = 3  AND meta_attempts  < ${max} AND (next_retry_ms IS NULL OR next_retry_ms <= ${now}))
		OR (thumb_status = 3 AND thumb_attempts < ${max} AND (next_retry_ms IS NULL OR next_retry_ms <= ${now}))
	)`;
}
function pendPredicate(): string {
	return pendPredicateFor(maxAttempts(), Date.now());
}

function selectPending(db: DB, limit: number): PendingRow[] {
	const pend = pendPredicate();
	const rows: PendingRow[] = [];
	// Cap bound variables well under SQLite's limit even if a huge visible range was reported.
	const ids = [...priority].slice(0, 400);
	if (ids.length) {
		const ph = ids.map(() => '?').join(',');
		rows.push(
			...(db
				.prepare(
					`SELECT ${COLS} FROM media WHERE id IN (${ph}) AND is_trashed = 0 AND ${pend}
					 ORDER BY taken_ms DESC, id DESC LIMIT ?`
				)
				.all(...ids, limit) as PendingRow[])
		);
	}
	if (rows.length < limit) {
		const seen = rows.map((r) => r.id);
		const notIn = seen.length ? `AND id NOT IN (${seen.map(() => '?').join(',')})` : '';
		rows.push(
			...(db
				.prepare(
					`SELECT ${COLS} FROM media WHERE is_trashed = 0 AND ${pend} ${notIn}
					 ORDER BY taken_ms DESC, id DESC LIMIT ?`
				)
				.all(...seen, limit - rows.length) as PendingRow[])
		);
	}
	// Skip rows already being processed (by a concurrent ensureThumb or this same loop).
	return rows.filter((r) => !inFlight.has(r.id));
}

function statements(db: DB) {
	return {
		photoMeta: db.prepare(
			`UPDATE media SET width=@width, height=@height, taken_ms=@takenMs, taken_local_day=@takenLocalDay,
			   taken_source=@takenSource, has_gps=@hasGps, gps_lat=@gpsLat, gps_lon=@gpsLon,
			   camera_make=@cameraMake, camera_model=@cameraModel, lens=@lens, orientation=@orientation,
			   quick_hash=@quickHash, meta_status=2, updated_at=@now WHERE id=@id`
		),
		videoMeta: db.prepare(
			`UPDATE media SET width=@width, height=@height, duration_ms=@durationMs, codec=@codec,
			   quick_hash=@quickHash, meta_status=2, updated_at=@now WHERE id=@id`
		),
		metaFail: db.prepare(
			`UPDATE media SET meta_status=3, meta_attempts=meta_attempts+1, next_retry_ms=@nextRetry,
			   error=@error, updated_at=@now WHERE id=@id`
		),
		thumbOk: db.prepare(
			`UPDATE media SET blurhash=@blurhash, width=COALESCE(width,@width), height=COALESCE(height,@height),
			   thumb_status=2, updated_at=@now WHERE id=@id`
		),
		thumbFail: db.prepare(
			`UPDATE media SET thumb_status=3, thumb_attempts=thumb_attempts+1, next_retry_ms=@nextRetry,
			   error=@error, updated_at=@now WHERE id=@id`
		)
	};
}
type Stmts = ReturnType<typeof statements>;
const stmtCache = new WeakMap<DB, Stmts>();
function getStmts(db: DB): Stmts {
	let s = stmtCache.get(db);
	if (!s) {
		s = statements(db);
		stmtCache.set(db, s);
	}
	return s;
}

/** Process a row through both stages exactly once at a time (joins any in-flight processing). */
function processRow(db: DB, row: PendingRow): Promise<void> {
	const existing = inFlight.get(row.id);
	if (existing) return existing;
	const p = doProcessRow(db, row).finally(() => inFlight.delete(row.id));
	inFlight.set(row.id, p);
	return p;
}

async function doProcessRow(db: DB, row: PendingRow): Promise<void> {
	const s = getStmts(db);

	if (row.meta_status !== 2) {
		try {
			const now = Date.now();
			const qh = await quickHash(row.path, row.size_bytes).catch(() => null);
			if (row.type === 'photo') {
				const m = await extractImageMeta(row.path, row.mtime_ms);
				s.photoMeta.run({ id: row.id, now, ...m, hasGps: m.hasGps ? 1 : 0, quickHash: qh });
				row.width = m.width ?? row.width;
				row.height = m.height ?? row.height;
			} else {
				const p = await probeVideo(row.path);
				s.videoMeta.run({ id: row.id, now, ...p, quickHash: qh });
				row.width = p.width ?? row.width;
				row.height = p.height ?? row.height;
				row.duration_ms = p.durationMs ?? row.duration_ms;
			}
		} catch (e) {
			s.metaFail.run({
				id: row.id,
				now: Date.now(),
				error: errMsg(e),
				nextRetry: Date.now() + retryBackoffMs(row.meta_attempts + 1)
			});
		}
	}

	if (row.thumb_status !== 2) {
		await makeThumbs(db, row);
	}
}

/** Render a row's thumbnails (photo via the worker pool when available; video in-process) and
 *  record success/failure. */
async function makeThumbs(db: DB, row: PendingRow): Promise<void> {
	const s = getStmts(db);
	const eager = getConfig().thumbnails.eagerPreview;
	try {
		if (row.type === 'photo') {
			const sizes: ThumbSize[] = eager ? ALL_SIZES : EAGER_SIZES;
			// Edited photos render their (non-destructive) edits on the main thread — the worker only
			// handles plain source images. Editing is rare, so this isn't a throughput concern.
			if (row.edit_ops) {
				const { renderEditedThumbs } = await import('./editService');
				const { normalizeEdits } = await import('$shared/edits');
				const t = await renderEditedThumbs(row.id, row.path, normalizeEdits(JSON.parse(row.edit_ops)), sizes);
				thumbDone(s, row, t.width, t.height, t.blurhash);
				return;
			}
			if (poolAvailable()) {
				const r = await runThumbTask({ id: row.id, srcPath: row.path, sizes });
				if (r.ok) {
					thumbDone(s, row, r.width ?? null, r.height ?? null, r.blurhash ?? null);
				} else if (r.error === 'pool unavailable') {
					const t = await makeImageThumbs(row.path, row.id, sizes);
					thumbDone(s, row, t.width, t.height, t.blurhash);
				} else {
					thumbFailed(s, row, r.error ?? 'thumbnail failed');
				}
			} else {
				const t = await makeImageThumbs(row.path, row.id, sizes);
				thumbDone(s, row, t.width, t.height, t.blurhash);
			}
		} else {
			const t = await makeVideoThumbs(row.path, row.id, row.duration_ms ?? null);
			thumbDone(s, row, t.width, t.height, t.blurhash);
		}
	} catch (e) {
		thumbFailed(s, row, errMsg(e));
	}
}

function thumbDone(s: Stmts, row: PendingRow, width: number | null, height: number | null, blurhash: string | null): void {
	s.thumbOk.run({ id: row.id, now: Date.now(), blurhash, width, height });
	recordProcessed(1);
}

function thumbFailed(s: Stmts, row: PendingRow, error: string): void {
	s.thumbFail.run({
		id: row.id,
		now: Date.now(),
		error,
		nextRetry: Date.now() + retryBackoffMs(row.thumb_attempts + 1)
	});
}

function errMsg(e: unknown): string {
	return (e instanceof Error ? e.message : String(e)).slice(0, 500);
}

async function runPool(db: DB, rows: PendingRow[], n: number): Promise<void> {
	let i = 0;
	const worker = async () => {
		while (i < rows.length) {
			const row = rows[i++];
			await processRow(db, row);
		}
	};
	await Promise.all(Array.from({ length: Math.min(n, rows.length) }, worker));
}

let lastPendingUpdate = 0;
function updatePending(db: DB, force = false): void {
	const now = Date.now();
	if (!force && now - lastPendingUpdate < 1000) return;
	lastPendingUpdate = now;
	const meta = db
		.prepare(`SELECT COUNT(*) AS n FROM media WHERE is_trashed = 0 AND meta_status IN (0,1)`)
		.get() as { n: number };
	const thumb = db
		.prepare(`SELECT COUNT(*) AS n FROM media WHERE is_trashed = 0 AND thumb_status IN (0,1)`)
		.get() as { n: number };
	setPending(meta.n, thumb.n);
	// Metadata writes can change taken_local_day → invalidate the cached day buckets.
	bustBucketsCache();
}

/**
 * Reclaim any rows stranded mid-flight by a prior crash (status 1) by resetting them to pending.
 * Called once at startup before the first drain.
 */
export function resetStuckProcessing(db: DB): void {
	db.prepare(`UPDATE media SET meta_status = 0 WHERE meta_status = 1`).run();
	db.prepare(`UPDATE media SET thumb_status = 0 WHERE thumb_status = 1`).run();
}

/** Idempotent: start (or no-op if already running) a drain of all pending work. */
export function processPending(): void {
	if (draining) return;
	draining = true;
	void (async () => {
		const db = getDb();
		const n = concurrency();
		try {
			for (;;) {
				const rows = selectPending(db, 64);
				if (!rows.length) break;
				await runPool(db, rows, n);
				updatePending(db);
			}
		} catch (e) {
			log.error('pipeline drain failed', e);
		} finally {
			updatePending(db, true);
			draining = false;
			// A late-arriving visible-range hint may have queued more work.
			if (selectPending(db, 1).length) processPending();
		}
	})();
}

/** Lazily render one missing size for a row (no status change), joining concurrent requests. */
function ensureSizeGuarded(row: PendingRow, size: ThumbSize): Promise<void> {
	const key = `${row.id}:${size}`;
	const existing = inFlightSize.get(key);
	if (existing) return existing;
	const p = (async () => {
		try {
			if (row.type === 'photo') await ensureImageSize(row.path, row.id, size);
			else await makeVideoThumbs(row.path, row.id, row.duration_ms ?? null, [size]);
		} catch (e) {
			log.debug(`generate-on-miss for ${row.id}/${size} failed`, e);
		}
	})().finally(() => inFlightSize.delete(key));
	inFlightSize.set(key, p);
	return p;
}

/** Generate-on-miss for the thumbnail endpoint: ensure the requested size exists for `id`. */
export async function ensureThumb(id: number, size: ThumbSize = 'grid'): Promise<void> {
	const db = getDb();
	const row = db.prepare(`SELECT ${COLS} FROM media WHERE id = ?`).get(id) as PendingRow | undefined;
	if (!row) return;
	// Run the base pipeline if thumbs aren't done yet (joins the background drain via the guard).
	if (row.thumb_status !== 2) await processRow(db, row);
	// The deferred `preview` (and any size still missing) is rendered on demand here.
	if (!thumbExists(id, size)) await ensureSizeGuarded(row, size);
}
```

### `src/lib/server/media/render-core.mjs`

```js
// @ts-check
/**
 * Shared image-render core used by BOTH the main-thread thumbnailService (the in-process /
 * fallback path + vitest) AND the worker_threads thumb-worker. Authored as plain ESM (no app or
 * TS-only imports) so the worker can `import` it raw under Node while Vite still bundles it into
 * the SSR server build. ONE implementation → the worker and the fallback can never drift.
 *
 * Only `sharp` + `blurhash` (both SSR-external, always present at runtime) are imported here.
 * Metadata extraction (exif/ffprobe) stays in the TS services on the main thread — this module is
 * purely the CPU-heavy resize + blurhash that we want to parallelize across worker threads.
 */
import fs from 'node:fs';
import path from 'node:path';
import sharp from 'sharp';
import { encode as blurhashEncode } from 'blurhash';

/** @typedef {'grid'|'grid2x'|'preview'} ThumbSize */
/**
 * @typedef {Object} RenderCfg
 * @property {string} dir            thumbnails dir (relative to cwd), e.g. "data/thumbnails"
 * @property {number} gridLongEdge   long edge of the 1x grid thumb (e.g. 320)
 * @property {number} gridQuality    webp quality for the grid thumb (1-100)
 * @property {number} previewLongEdge long edge of the lightbox preview (e.g. 1600)
 * @property {number} previewQuality  webp quality for the preview (1-100)
 */
/** @typedef {{ width: number|null, height: number|null, blurhash: string|null }} ThumbResult */

/**
 * Two-hex shard derived from id (`id % 256`) — mirrors paths.ts thumbShard.
 * @param {number} id
 * @returns {string}
 */
export function thumbShard(id) {
	return (id & 0xff).toString(16).padStart(2, '0');
}

/**
 * Absolute path of a cached thumbnail: `<dir>/<shard>/<id>_<size>.webp`.
 * @param {string} dir
 * @param {number} id
 * @param {ThumbSize} size
 * @returns {string}
 */
export function thumbPathFor(dir, id, size) {
	return path.join(path.resolve(process.cwd(), dir), thumbShard(id), `${id}_${size}.webp`);
}

/**
 * @param {sharp.Sharp} img
 * @returns {Promise<string|null>}
 */
async function computeBlurhash(img) {
	try {
		const { data, info } = await img
			.resize(32, 32, { fit: 'inside' })
			.raw()
			.ensureAlpha()
			.toBuffer({ resolveWithObject: true });
		return blurhashEncode(
			new Uint8ClampedArray(data.buffer, data.byteOffset, data.byteLength),
			info.width,
			info.height,
			4,
			3
		);
	} catch {
		return null;
	}
}

/**
 * Render the requested WebP sizes from a sharp pipeline source and return the blurhash. Exported so
 * the non-destructive editor can render derivatives from an already-transformed pipeline.
 * @param {sharp.Sharp} base
 * @param {number} id
 * @param {RenderCfg} cfg
 * @param {ThumbSize[]} sizes
 * @returns {Promise<string|null>}
 */
export async function renderSizesFromPipeline(base, id, cfg, sizes) {
	/** @type {Record<ThumbSize, { file: string, edge: number, quality: number }>} */
	const targets = {
		grid: { file: thumbPathFor(cfg.dir, id, 'grid'), edge: cfg.gridLongEdge, quality: cfg.gridQuality },
		// 2x variant for retina/4K grids; slightly lower quality is fine at double resolution.
		grid2x: {
			file: thumbPathFor(cfg.dir, id, 'grid2x'),
			edge: cfg.gridLongEdge * 2,
			quality: Math.max(60, cfg.gridQuality - 5)
		},
		preview: { file: thumbPathFor(cfg.dir, id, 'preview'), edge: cfg.previewLongEdge, quality: cfg.previewQuality }
	};
	// All sizes for an id share one shard dir, so a single mkdir suffices.
	await fs.promises.mkdir(path.dirname(targets.grid.file), { recursive: true });
	for (const s of sizes) {
		const t = targets[s];
		await base
			.clone()
			.resize(t.edge, t.edge, { fit: 'inside', withoutEnlargement: true })
			.webp({ quality: t.quality })
			.toFile(t.file);
	}
	return computeBlurhash(base.clone());
}

/**
 * Build thumbnails for a still-image file. Returns post-orientation dimensions + blurhash.
 * @param {string} srcPath
 * @param {number} id
 * @param {RenderCfg} cfg
 * @param {ThumbSize[]} sizes
 * @returns {Promise<ThumbResult>}
 */
export async function renderImageThumbs(srcPath, id, cfg, sizes) {
	const input = sharp(srcPath, { failOn: 'none', animated: false }).rotate(); // auto-orient first
	const meta = await sharp(srcPath, { failOn: 'none' }).metadata();
	const blurhash = await renderSizesFromPipeline(input, id, cfg, sizes);

	let width = meta.width ?? null;
	let height = meta.height ?? null;
	// EXIF orientations 5-8 imply a 90°/270° rotation; report swapped dimensions.
	if (meta.orientation && meta.orientation >= 5 && width && height) {
		[width, height] = [height, width];
	}
	return { width, height, blurhash };
}

/**
 * Build thumbnails from an already-extracted frame buffer (e.g. a video poster).
 * @param {Buffer} buffer
 * @param {number} id
 * @param {RenderCfg} cfg
 * @param {ThumbSize[]} sizes
 * @returns {Promise<ThumbResult>}
 */
export async function renderThumbsFromBuffer(buffer, id, cfg, sizes) {
	const input = sharp(buffer, { failOn: 'none' });
	const meta = await input.metadata();
	const blurhash = await renderSizesFromPipeline(input.clone(), id, cfg, sizes);
	return { width: meta.width ?? null, height: meta.height ?? null, blurhash };
}

/**
 * Render a single missing size from an image source, WITHOUT touching the DB (used by the deferred
 * generate-on-miss path when only the lazy `preview` is absent).
 * @param {string} srcPath
 * @param {number} id
 * @param {ThumbSize} size
 * @param {RenderCfg} cfg
 * @returns {Promise<void>}
 */
export async function renderOneSize(srcPath, id, size, cfg) {
	const input = sharp(srcPath, { failOn: 'none', animated: false }).rotate();
	await renderSizesFromPipeline(input, id, cfg, [size]);
}
```

### `src/lib/server/media/render-core.test.ts`

```ts
import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import sharp from 'sharp';
import { renderImageThumbs, renderOneSize, thumbPathFor } from './render-core.mjs';

// thumbPathFor resolves against process.cwd() unless `dir` is absolute — so use an absolute temp dir.
const DIR = path.join(os.tmpdir(), `lg-rendercore-${process.pid}`);
const SRC = path.join(DIR, 'src.jpg');
const cfg = { dir: DIR, gridLongEdge: 64, gridQuality: 70, previewLongEdge: 200, previewQuality: 80 };

beforeAll(async () => {
	fs.mkdirSync(DIR, { recursive: true });
	// A 300×150 solid image: wide enough that grid (64) and preview (200) are distinct, and the
	// long edge (300) exceeds preview so withoutEnlargement still produces a 200px result.
	await sharp({ create: { width: 300, height: 150, channels: 3, background: { r: 12, g: 80, b: 160 } } })
		.jpeg()
		.toFile(SRC);
});

afterAll(() => {
	// Best-effort temp cleanup; Windows can briefly hold the freshly-written webp files.
	try {
		fs.rmSync(DIR, { recursive: true, force: true });
	} catch {
		/* the OS reclaims the temp dir later */
	}
});

describe('render-core (shared by the in-process path and the worker)', () => {
	it('renders only the requested sizes and returns dims + blurhash (deferred preview)', async () => {
		const r = await renderImageThumbs(SRC, 101, cfg, ['grid', 'grid2x']);
		expect(r.width).toBe(300);
		expect(r.height).toBe(150);
		expect(typeof r.blurhash).toBe('string');
		expect(r.blurhash && r.blurhash.length).toBeGreaterThan(6);

		expect(fs.existsSync(thumbPathFor(DIR, 101, 'grid'))).toBe(true);
		expect(fs.existsSync(thumbPathFor(DIR, 101, 'grid2x'))).toBe(true);
		// preview was NOT requested → must not exist yet (the lazy/backfill split).
		expect(fs.existsSync(thumbPathFor(DIR, 101, 'preview'))).toBe(false);
	});

	it('renderOneSize fills in a single missing size without re-rendering the others', async () => {
		await renderImageThumbs(SRC, 102, cfg, ['grid', 'grid2x']);
		expect(fs.existsSync(thumbPathFor(DIR, 102, 'preview'))).toBe(false);

		await renderOneSize(SRC, 102, 'preview', cfg);
		expect(fs.existsSync(thumbPathFor(DIR, 102, 'preview'))).toBe(true);

		// The generated grid thumb's long edge is clamped to the configured 64px.
		const meta = await sharp(thumbPathFor(DIR, 102, 'grid')).metadata();
		expect(Math.max(meta.width ?? 0, meta.height ?? 0)).toBe(64);
	});

	it('a corrupt/unreadable source rejects (so the pipeline can mark it failed)', async () => {
		const bad = path.join(DIR, 'not-an-image.jpg');
		fs.writeFileSync(bad, 'this is not an image');
		await expect(renderImageThumbs(bad, 103, cfg, ['grid'])).rejects.toBeTruthy();
	});
});
```

### `src/lib/server/media/streamService.ts`

```ts
/**
 * Range-aware serving of original files (and video streams). Path safety: the id is mapped
 * to media.path, which is realpath-checked against the allow-list before any read — see
 * docs/07-SECURITY.md. HTTP Range (206) is what makes <video> seek instantly.
 */
import fs from 'node:fs';
import { Readable } from 'node:stream';
import type { DB } from '../db/index';
import { getMediaPath } from '../db/queries';
import { realPathWithinRoots } from '../paths';
import { getEnabledRoots, getTrashDir } from '../config/configService';
import { apiError } from '../http';
import { log } from '../log';

const MIME: Record<string, string> = {
	jpg: 'image/jpeg',
	jpeg: 'image/jpeg',
	png: 'image/png',
	gif: 'image/gif',
	webp: 'image/webp',
	avif: 'image/avif',
	bmp: 'image/bmp',
	tiff: 'image/tiff',
	tif: 'image/tiff',
	heic: 'image/heic',
	heif: 'image/heif',
	mp4: 'video/mp4',
	mov: 'video/quicktime',
	m4v: 'video/x-m4v',
	webm: 'video/webm',
	mkv: 'video/x-matroska',
	avi: 'video/x-msvideo',
	wmv: 'video/x-ms-wmv',
	mts: 'video/mp2t',
	m2ts: 'video/mp2t',
	'3gp': 'video/3gpp'
};

function mimeFor(p: string): string {
	const ext = p.slice(p.lastIndexOf('.') + 1).toLowerCase();
	return MIME[ext] ?? 'application/octet-stream';
}

function toWeb(stream: NodeJS.ReadableStream): ReadableStream {
	return Readable.toWeb(stream as Readable) as unknown as ReadableStream;
}

export async function serveOriginal(db: DB, id: number, request: Request): Promise<Response> {
	const media = getMediaPath(db, id);
	if (!media) return apiError(404, 'NOT_FOUND', 'Media not found.');

	let realPath: string;
	try {
		realPath = await realPathWithinRoots(media.path, getEnabledRoots(), [getTrashDir()]);
	} catch (e) {
		log.warn(
			`serveOriginal denied id=${id} path=${media.path} roots=${JSON.stringify(getEnabledRoots())}`,
			e instanceof Error ? e.message : e
		);
		return apiError(403, 'FORBIDDEN', 'Path is not allowed.');
	}

	let stat: fs.Stats;
	try {
		stat = await fs.promises.stat(realPath);
	} catch {
		return apiError(404, 'GONE', 'File is missing on disk.');
	}

	const size = stat.size;
	const type = mimeFor(realPath);
	const etag = `"o${id}-${Math.round(stat.mtimeMs)}-${size}"`;
	const range = request.headers.get('range');

	if (!range && request.headers.get('if-none-match') === etag) {
		return new Response(null, { status: 304, headers: { etag } });
	}

	const base: Record<string, string> = {
		'content-type': type,
		'accept-ranges': 'bytes',
		'cache-control': 'private, max-age=86400',
		'content-disposition': 'inline',
		etag
	};

	if (range) {
		const m = /bytes=(\d*)-(\d*)/.exec(range);
		const hasStart = !!(m && m[1]);
		const hasEnd = !!(m && m[2]);
		let start: number;
		let end: number;
		if (!hasStart && hasEnd) {
			// Suffix range `bytes=-N` → the last N bytes (RFC 7233).
			const n = parseInt(m![2], 10);
			start = Math.max(0, size - n);
			end = size - 1;
		} else {
			start = hasStart ? parseInt(m![1], 10) : 0;
			end = hasEnd ? parseInt(m![2], 10) : size - 1;
		}
		if (!Number.isFinite(start) || start < 0) start = 0;
		if (!Number.isFinite(end) || end >= size) end = size - 1;
		if (start > end || start >= size) {
			return new Response(null, { status: 416, headers: { 'content-range': `bytes */${size}` } });
		}
		return new Response(toWeb(fs.createReadStream(realPath, { start, end })), {
			status: 206,
			headers: {
				...base,
				'content-range': `bytes ${start}-${end}/${size}`,
				'content-length': String(end - start + 1)
			}
		});
	}

	return new Response(toWeb(fs.createReadStream(realPath)), {
		status: 200,
		headers: { ...base, 'content-length': String(size) }
	});
}
```

### `src/lib/server/media/thumbnailService.ts`

```ts
/**
 * Image thumbnailing via sharp: EXIF-orientation-corrected grid + grid2x (+ optional preview) WebP,
 * plus a blurhash placeholder. The actual resize/blurhash work lives in `render-core.mjs` so the
 * worker_threads pool and this in-process/fallback path share ONE implementation (no drift). Cache
 * layout is sharded (docs/05-PERFORMANCE.md). RAW/HEIC that libvips can't decode throw here and are
 * recorded as a thumb failure (roadmap: fallbacks).
 */
import fs from 'node:fs';
import { thumbPath, type ThumbSize } from '../paths';
import { getConfig } from '../config/configService';
import { renderImageThumbs, renderThumbsFromBuffer, renderOneSize } from './render-core.mjs';

export interface ThumbResult {
	width: number | null;
	height: number | null;
	blurhash: string | null;
}

/** Plain config the shared render core needs (structurally matches render-core.mjs RenderCfg). */
export interface RenderCfg {
	dir: string;
	gridLongEdge: number;
	gridQuality: number;
	previewLongEdge: number;
	previewQuality: number;
}

/** All thumbnail sizes, in render order. `preview` is deferred (lazy) for photos by default. */
export const ALL_SIZES: ThumbSize[] = ['grid', 'grid2x', 'preview'];
/** Sizes generated eagerly during a backfill when preview is deferred. */
export const EAGER_SIZES: ThumbSize[] = ['grid', 'grid2x'];

/** Build the plain render config the shared core needs from the live app config. */
export function renderCfg(): RenderCfg {
	const c = getConfig().thumbnails;
	return {
		dir: c.dir,
		gridLongEdge: c.grid.longEdge,
		gridQuality: c.grid.quality,
		previewLongEdge: c.preview.longEdge,
		previewQuality: c.preview.quality
	};
}

/** Build thumbnails for a still image file. Returns post-orientation dimensions + blurhash. */
export function makeImageThumbs(srcPath: string, id: number, sizes: ThumbSize[] = ALL_SIZES): Promise<ThumbResult> {
	return renderImageThumbs(srcPath, id, renderCfg(), sizes);
}

/** Build thumbnails from an already-extracted frame buffer (e.g. a video poster). */
export function makeThumbsFromBuffer(buffer: Buffer, id: number, sizes: ThumbSize[] = ALL_SIZES): Promise<ThumbResult> {
	return renderThumbsFromBuffer(buffer, id, renderCfg(), sizes);
}

/** Render a single missing size from an image source (no DB write) — for deferred preview. */
export function ensureImageSize(srcPath: string, id: number, size: ThumbSize): Promise<void> {
	return renderOneSize(srcPath, id, size, renderCfg());
}

/** True if a cached thumbnail of the given size already exists. */
export function thumbExists(id: number, size: ThumbSize): boolean {
	return fs.existsSync(thumbPath(getConfig().thumbnails.dir, id, size));
}
```

### `src/lib/server/media/thumb-worker.mjs`

```js
// @ts-check
/**
 * worker_threads entry for image thumbnailing. Runs the CPU-heavy sharp resize + blurhash off the
 * main JS thread so N workers decode in parallel across cores while the main thread keeps serving
 * HTTP and owns every DB write. Self-contained: imports only `render-core.mjs` + `sharp` (both
 * resolve from node_modules at runtime), so it loads identically under `vite dev` and `node build`.
 *
 * Protocol: parent posts { taskId, id, srcPath, sizes }; we reply
 *   { taskId, ok: true, width, height, blurhash }  on success, or
 *   { taskId, ok: false, error }                   on a decode failure (NOT an infra crash).
 */
import { parentPort, workerData } from 'node:worker_threads';
import sharp from 'sharp';
import { renderImageThumbs } from './render-core.mjs';

// One libvips thread per worker: N workers × 1 = N parallel decodes, no threadpool oversubscription.
sharp.concurrency(1);

const cfg = workerData?.renderCfg;

if (!parentPort) throw new Error('thumb-worker must run as a worker thread');

parentPort.on('message', async (task) => {
	try {
		const r = await renderImageThumbs(task.srcPath, task.id, cfg, task.sizes);
		parentPort.postMessage({ taskId: task.taskId, ok: true, width: r.width, height: r.height, blurhash: r.blurhash });
	} catch (e) {
		parentPort.postMessage({ taskId: task.taskId, ok: false, error: e instanceof Error ? e.message : String(e) });
	}
});
```

### `src/lib/server/media/videoService.ts`

```ts
/**
 * Video probing + poster extraction via fluent-ffmpeg using the bundled static binaries
 * (no system ffmpeg needed). Codec is recorded so unplayable formats can be surfaced
 * (transcoding is a roadmap item — docs/12-ROADMAP.md).
 */
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import ffmpeg from 'fluent-ffmpeg';
import ffmpegStatic from 'ffmpeg-static';
import ffprobeStatic from 'ffprobe-static';
import { makeThumbsFromBuffer, ALL_SIZES, type ThumbResult } from './thumbnailService';
import type { ThumbSize } from '../paths';
import { getConfig } from '../config/configService';

let configured = false;
function ensureConfigured(): void {
	if (configured) return;
	if (ffmpegStatic) ffmpeg.setFfmpegPath(ffmpegStatic as unknown as string);
	if (ffprobeStatic?.path) ffmpeg.setFfprobePath(ffprobeStatic.path);
	configured = true;
}

export interface VideoProbe {
	width: number | null;
	height: number | null;
	durationMs: number | null;
	codec: string | null;
}

export function probeVideo(srcPath: string): Promise<VideoProbe> {
	ensureConfigured();
	return new Promise((resolve) => {
		ffmpeg.ffprobe(srcPath, (err, data) => {
			if (err || !data) {
				resolve({ width: null, height: null, durationMs: null, codec: null });
				return;
			}
			const v = data.streams?.find((s) => s.codec_type === 'video');
			const durationMs = data.format?.duration
				? Math.round(Number(data.format.duration) * 1000)
				: null;
			resolve({
				width: v?.width ?? null,
				height: v?.height ?? null,
				durationMs,
				codec: v?.codec_name ?? null
			});
		});
	});
}

function extractFrame(srcPath: string, seekSec: number, outPath: string): Promise<void> {
	ensureConfigured();
	return new Promise((resolve, reject) => {
		ffmpeg(srcPath)
			.seekInput(seekSec)
			.frames(1)
			.outputOptions('-q:v', '2')
			.on('end', () => resolve())
			.on('error', (e) => reject(e))
			.save(outPath);
	});
}

/** Extract a poster frame (~videoFrameAtPercent of duration) and build WebP thumbs from it. */
export async function makeVideoThumbs(
	srcPath: string,
	id: number,
	durationMs: number | null,
	sizes: ThumbSize[] = ALL_SIZES
): Promise<ThumbResult> {
	const cfg = getConfig().thumbnails;
	const pct = cfg.videoFrameAtPercent / 100;
	const seekSec = durationMs && durationMs > 0 ? Math.max(0, (durationMs / 1000) * pct) : 0;
	const tmp = path.join(os.tmpdir(), `lg_poster_${id}_${process.pid}.png`);
	await extractFrame(srcPath, seekSec, tmp);
	try {
		const buf = await fs.promises.readFile(tmp);
		// One ffmpeg extract dominates a video's cost; rendering all sizes off that single frame is
		// cheap, so videos aren't subject to the photo "defer preview" split.
		return await makeThumbsFromBuffer(buf, id, sizes);
	} finally {
		fs.promises.rm(tmp, { force: true }).catch(() => {});
	}
}
```

### `src/lib/server/media/workerPool.ts`

```ts
/**
 * A small hand-rolled worker_threads pool for image thumbnailing (see thumb-worker.mjs). One task
 * type, so a ~120-line pool keeps deps lean and sidesteps the bundling fragility a generic pool
 * library would add under adapter-node. Each worker handles exactly one task at a time; the main
 * thread owns all DB writes and only hands workers `{id, srcPath, sizes}`.
 *
 * Failure model: a *decode* error comes back as a normal `{ok:false}` reply and is surfaced to the
 * caller (the row is a genuine thumb failure). A *worker crash* (error/exit with a job in flight) is
 * infrastructure, not a bad file — we re-queue that job onto another worker (up to MAX_REQUEUE) and
 * respawn. If the pool can't be created at all, `poolAvailable()` is false and the pipeline falls
 * back to in-process rendering.
 */
import { Worker } from 'node:worker_threads';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { getConfig } from '../config/configService';
import { renderCfg } from './thumbnailService';
import type { ThumbSize } from '../paths';
import { log } from '../log';

export interface ThumbTask {
	id: number;
	srcPath: string;
	sizes: ThumbSize[];
}
export interface ThumbReply {
	ok: boolean;
	width?: number | null;
	height?: number | null;
	blurhash?: string | null;
	error?: string;
}

interface Job {
	task: ThumbTask;
	resolve: (r: ThumbReply) => void;
	attempts: number;
}

const MAX_REQUEUE = 3;

let workers: Worker[] | null = null;
let available = true;
let seq = 0;
const idle: Worker[] = [];
const busy = new Map<Worker, Job>();
const queue: Job[] = [];

/** Locate thumb-worker.mjs. Run-from-source (this app's deploy) has src/ at cwd; also try sibling. */
function resolveWorkerPath(): string | null {
	const candidates = [
		path.resolve(process.cwd(), 'src/lib/server/media/thumb-worker.mjs'),
		fileURLToPath(new URL('./thumb-worker.mjs', import.meta.url))
	];
	for (const c of candidates) {
		try {
			if (fs.existsSync(c)) return c;
		} catch {
			/* keep trying */
		}
	}
	return null;
}

function desiredCount(): number {
	const scan = getConfig().scan;
	if (scan.workerCount && scan.workerCount > 0) return scan.workerCount;
	if (scan.concurrency && scan.concurrency > 0) return scan.concurrency;
	return Math.max(1, (os.cpus()?.length ?? 2) - 1);
}

function spawn(workerPath: string, cfg: ReturnType<typeof renderCfg>): Worker {
	const w = new Worker(workerPath, { workerData: { renderCfg: cfg } });
	w.on('message', (msg: ThumbReply & { taskId: number }) => {
		const job = busy.get(w);
		busy.delete(w);
		idle.push(w);
		if (job) job.resolve({ ok: msg.ok, width: msg.width, height: msg.height, blurhash: msg.blurhash, error: msg.error });
		dispatch();
	});
	const onDeath = (why: string) => {
		const job = busy.get(w);
		busy.delete(w);
		// Drop the dead worker from idle if it was parked there.
		const ix = idle.indexOf(w);
		if (ix !== -1) idle.splice(ix, 1);
		if (workers) workers = workers.filter((x) => x !== w);
		if (job) {
			// Infra failure, not a bad file — re-queue unless we've bounced it too many times.
			if (job.attempts < MAX_REQUEUE) {
				job.attempts++;
				queue.unshift(job);
			} else {
				job.resolve({ ok: false, error: `thumb worker repeatedly failed: ${why}` });
			}
		}
		// Respawn to keep the pool full, unless we've been told to stop.
		if (available) {
			try {
				const repl = spawn(workerPath, cfg);
				workers?.push(repl);
				idle.push(repl);
				dispatch();
			} catch (e) {
				log.warn('thumb worker respawn failed; disabling pool', e);
				disablePool();
			}
		}
	};
	w.on('error', (err: Error) => onDeath(err?.message ?? String(err)));
	w.on('exit', (code) => {
		if (code !== 0) onDeath(`exit ${code}`);
	});
	return w;
}

function ensurePool(): boolean {
	if (workers) return true;
	if (!available) return false;
	const workerPath = resolveWorkerPath();
	if (!workerPath) {
		log.warn('thumb-worker.mjs not found; using in-process thumbnailing.');
		available = false;
		return false;
	}
	try {
		const cfg = renderCfg();
		const n = desiredCount();
		workers = [];
		for (let i = 0; i < n; i++) {
			const w = spawn(workerPath, cfg);
			workers.push(w);
			idle.push(w);
		}
		log.info(`Thumbnail worker pool started (${n} worker${n === 1 ? '' : 's'}).`);
		return true;
	} catch (e) {
		log.warn('thumb worker pool failed to start; using in-process thumbnailing.', e);
		disablePool();
		return false;
	}
}

function dispatch(): void {
	while (idle.length && queue.length) {
		const w = idle.shift()!;
		const job = queue.shift()!;
		busy.set(w, job);
		w.postMessage({ taskId: seq++, id: job.task.id, srcPath: job.task.srcPath, sizes: job.task.sizes });
	}
}

/** True if the worker pool is (or can be) used. The pipeline checks this once per row. */
export function poolAvailable(): boolean {
	if (!available) return false;
	return ensurePool();
}

/** Run one image-thumb task on the pool. Resolves with the worker reply (ok true/false). */
export function runThumbTask(task: ThumbTask): Promise<ThumbReply> {
	if (!poolAvailable()) return Promise.resolve({ ok: false, error: 'pool unavailable' });
	return new Promise<ThumbReply>((resolve) => {
		queue.push({ task, resolve, attempts: 0 });
		dispatch();
	});
}

function disablePool(): void {
	available = false;
	const ws = workers ?? [];
	workers = null;
	idle.length = 0;
	busy.clear();
	for (const w of ws) void w.terminate();
}

/** Terminate all workers (called on graceful shutdown). */
export async function shutdownPool(): Promise<void> {
	available = false;
	const ws = workers ?? [];
	workers = null;
	idle.length = 0;
	busy.clear();
	await Promise.all(ws.map((w) => w.terminate().catch(() => {})));
}
```

### `src/lib/server/paths.test.ts`

```ts
import { describe, it, expect } from 'vitest';
import {
	normalizePath,
	isWithin,
	assertWithinRoots,
	PathError,
	thumbShard,
	splitPath
} from './paths';

describe('normalizePath', () => {
	it('lower-cases the drive letter and uses forward slashes', () => {
		expect(normalizePath('D:\\Photos\\Sub')).toBe('d:/Photos/Sub');
	});
	it('strips trailing slashes', () => {
		expect(normalizePath('D:/Photos/')).toBe('d:/Photos');
	});
	it('collapses .. segments', () => {
		expect(normalizePath('D:/Photos/../Pics')).toBe('d:/Pics');
	});
	it('preserves UNC roots', () => {
		expect(normalizePath('//server/share/x')).toBe('//server/share/x');
	});
	it('rejects null bytes', () => {
		expect(() => normalizePath('D:/a b')).toThrow(PathError);
	});
	it('is idempotent', () => {
		const once = normalizePath('D:\\Photos\\..\\Pics\\');
		expect(normalizePath(once)).toBe(once);
	});
});

describe('isWithin', () => {
	it('matches a child path', () => {
		expect(isWithin('d:/photos/a.jpg', 'd:/photos')).toBe(true);
	});
	it('respects segment boundaries (no prefix-only matches)', () => {
		expect(isWithin('d:/photos2/a.jpg', 'd:/photos')).toBe(false);
	});
	it('is case-insensitive on Windows', () => {
		expect(isWithin('D:/Photos/A.JPG', 'd:/photos')).toBe(true);
	});
	it('treats an identical path as within', () => {
		expect(isWithin('d:/photos', 'd:/photos')).toBe(true);
	});
});

describe('assertWithinRoots', () => {
	const roots = ['D:/Photos', '//nas/media'];
	it('passes for a path inside a root and returns the normalized form', () => {
		expect(assertWithinRoots('D:/Photos/2024/a.jpg', roots)).toBe('d:/Photos/2024/a.jpg');
	});
	it('passes for an extra allowed dir (e.g. trash)', () => {
		expect(assertWithinRoots('C:/app/data/trash/x.jpg', roots, ['C:/app/data/trash'])).toBe(
			'c:/app/data/trash/x.jpg'
		);
	});
	it('throws for a sibling escape', () => {
		expect(() => assertWithinRoots('D:/Other/a.jpg', roots)).toThrow(PathError);
	});
	it('throws for a parent escape', () => {
		expect(() => assertWithinRoots('D:/a.jpg', roots)).toThrow(PathError);
	});
});

describe('thumbShard', () => {
	it('produces a 2-hex shard from id % 256', () => {
		expect(thumbShard(0)).toBe('00');
		expect(thumbShard(255)).toBe('ff');
		expect(thumbShard(256)).toBe('00');
		expect(thumbShard(258)).toBe('02');
	});
});

describe('splitPath', () => {
	it('splits rel/dir/filename/ext relative to the root', () => {
		const r = splitPath('d:/photos', 'd:/photos/2024/trip/IMG_1.JPG');
		expect(r).toEqual({
			relPath: '2024/trip/IMG_1.JPG',
			dir: 'd:/photos/2024/trip',
			filename: 'IMG_1.JPG',
			ext: 'jpg'
		});
	});
});
```

### `src/lib/server/paths.ts`

```ts
/**
 * Path normalization, the traversal allow-list (`assertWithinRoots`), the symlink-escape
 * guard, and thumbnail-cache sharding. This is the primary path-safety boundary —
 * see docs/07-SECURITY.md. Pure-ish (uses node:path/fs but no app state).
 */
import path from 'node:path';
import fs from 'node:fs';

const isWin = process.platform === 'win32';

export class PathError extends Error {
	code = 'PATH_FORBIDDEN';
	constructor(message: string) {
		super(message);
		this.name = 'PathError';
	}
}

/**
 * Normalize to a canonical, comparable form:
 *  - absolute, forward-slashes
 *  - lower-cased Windows drive letter
 *  - no trailing slash (except a bare root)
 *  - UNC (`//server/share`) preserved
 * Rejects null bytes defensively.
 */
export function normalizePath(input: string): string {
	if (input == null) throw new PathError('path is required');
	if (input.indexOf('\0') !== -1) throw new PathError('null byte in path');
	const raw = String(input).trim();
	if (raw === '') throw new PathError('empty path');

	const wasUnc = /^[\\/]{2}[^\\/]/.test(raw);
	let resolved = path.resolve(raw).replace(/\\/g, '/');

	// Lower-case a leading drive letter: "C:/x" -> "c:/x"
	resolved = resolved.replace(/^([a-zA-Z]):\//, (_m, d: string) => d.toLowerCase() + ':/');

	// path.resolve collapses a UNC root to a single leading slash on some inputs; restore "//".
	if (wasUnc && !resolved.startsWith('//')) {
		resolved = '/' + resolved.replace(/^\/+/, '/');
	}

	// Strip trailing slashes but keep a minimal root ("c:/", "//server/share").
	if (resolved.length > 1) resolved = resolved.replace(/\/+$/, '');
	return resolved;
}

/** Lower-case for comparison on case-insensitive Windows filesystems. */
function cmp(p: string): string {
	return isWin ? p.toLowerCase() : p;
}

/** True if `child` is `parent` or lives beneath it (segment-boundary aware). */
export function isWithin(child: string, parent: string): boolean {
	const c = cmp(normalizePath(child));
	const p = cmp(normalizePath(parent));
	if (c === p) return true;
	const withSlash = p.endsWith('/') ? p : p + '/';
	return c.startsWith(withSlash);
}

/**
 * Throw unless `candidate` resolves inside one of the allowed roots (or an `extra`
 * allowed dir such as `data/trash`). `roots`/`extra` may be un-normalized.
 */
export function assertWithinRoots(candidate: string, roots: string[], extra: string[] = []): string {
	const normalized = normalizePath(candidate);
	for (const r of roots) {
		if (r && isWithin(normalized, r)) return normalized;
	}
	for (const e of extra) {
		if (e && isWithin(normalized, e)) return normalized;
	}
	throw new PathError('path is outside the allowed roots');
}

/**
 * Resolve the real (symlink-followed) path and re-check the allow-list, so a symlink
 * placed inside a root cannot point outside it. Returns the normalized real path.
 */
export async function realPathWithinRoots(
	candidate: string,
	roots: string[],
	extra: string[] = []
): Promise<string> {
	assertWithinRoots(candidate, roots, extra); // cheap lexical pre-check
	let real: string;
	try {
		real = await fs.promises.realpath(candidate);
	} catch {
		// File may not exist yet (e.g. a thumb we're about to write) — fall back to the
		// lexical check already passed above.
		return normalizePath(candidate);
	}
	// Compare the canonical real path against canonical (realpath'd) roots, so an 8.3 short
	// name or junction in the configured root doesn't cause a false rejection, while a symlink
	// escaping outside every root is still caught.
	const [realRoots, realExtra] = await Promise.all([
		Promise.all(roots.map(realRootCanon)),
		Promise.all(extra.map(realRootCanon))
	]);
	return assertWithinRoots(real, realRoots, realExtra);
}

// Cache realpath-canonicalized roots so the allow-list survives 8.3 short names, junctions,
// and case differences. IMPORTANT: use the async fs.promises.realpath here — on Windows it
// expands 8.3 short names to the long form, whereas fs.realpathSync does NOT, and the
// candidate is resolved with the async API too. Mixing the two silently breaks the check.
const rootRealCache = new Map<string, string>();
async function realRootCanon(r: string): Promise<string> {
	const norm = normalizePath(r);
	const cached = rootRealCache.get(norm);
	if (cached) return cached;
	let real = norm;
	try {
		real = normalizePath(await fs.promises.realpath(norm));
	} catch {
		/* offline/missing root: fall back to the lexical normalized form */
	}
	rootRealCache.set(norm, real);
	return real;
}

/** Two-hex shard derived from id (`id % 256`) so no thumbnail dir holds 50k flat files. */
export function thumbShard(id: number): string {
	return (id & 0xff).toString(16).padStart(2, '0');
}

export type ThumbSize = 'grid' | 'grid2x' | 'preview';

/** Absolute path of a cached thumbnail: `<dir>/<shard>/<id>_<size>.webp`. */
export function thumbPath(thumbnailsDir: string, id: number, size: ThumbSize): string {
	return path.join(path.resolve(process.cwd(), thumbnailsDir), thumbShard(id), `${id}_${size}.webp`);
}

/** Absolute path of a video storyboard sprite for an id. */
export function storyboardPath(thumbnailsDir: string, id: number): string {
	return path.join(path.resolve(process.cwd(), thumbnailsDir), thumbShard(id), `${id}_sb.webp`);
}

/** Split a normalized absolute path into useful pieces for the DB row. */
export function splitPath(rootNormalized: string, fileNormalized: string) {
	const rel = fileNormalized.startsWith(rootNormalized + '/')
		? fileNormalized.slice(rootNormalized.length + 1)
		: fileNormalized;
	const lastSlash = fileNormalized.lastIndexOf('/');
	const dir = lastSlash >= 0 ? fileNormalized.slice(0, lastSlash) : fileNormalized;
	const filename = lastSlash >= 0 ? fileNormalized.slice(lastSlash + 1) : fileNormalized;
	const dot = filename.lastIndexOf('.');
	const ext = dot >= 0 ? filename.slice(dot + 1).toLowerCase() : '';
	return { relPath: rel, dir, filename, ext };
}
```

### `src/lib/server/scan/pairing.test.ts`

```ts
import { describe, it, expect, beforeEach } from 'vitest';
import type { DB } from '../db/index';
import { openTestDb } from '../db/index';
import { pairLivePhotos } from './pairing';

let db: DB;
let id = 1;

function media(filename: string, ext: string, type: 'photo' | 'video', dir = 'd:/r') {
	const mid = id++;
	db.prepare(
		`INSERT INTO media (id, path, root_id, rel_path, dir, filename, ext, type, size_bytes, mtime_ms, created_at, updated_at)
		 VALUES (?, ?, 1, ?, ?, ?, ?, ?, 1, 1, 1, 1)`
	).run(mid, `${dir}/${filename}`, filename, dir, filename, ext, type);
	return mid;
}
const partner = (mid: number) =>
	(db.prepare(`SELECT live_partner_id AS p FROM media WHERE id=?`).get(mid) as { p: number | null }).p;

beforeEach(() => {
	db = openTestDb(':memory:');
	db.prepare(`INSERT INTO roots(id, path, label, enabled) VALUES(1,'d:/r','R',1)`).run();
	id = 1;
});

describe('pairLivePhotos', () => {
	it('links an image + video that share a base name in the same dir (happy path)', () => {
		const jpg = media('IMG_1.jpg', 'jpg', 'photo');
		const mov = media('IMG_1.mov', 'mov', 'video');
		const lone = media('IMG_2.jpg', 'jpg', 'photo');
		pairLivePhotos(db);
		expect(partner(jpg)).toBe(mov);
		expect(partner(mov)).toBe(jpg);
		expect(partner(lone)).toBeNull();
	});

	it('does not pair two photos or two videos (only opposite types)', () => {
		const a = media('X.jpg', 'jpg', 'photo');
		const b = media('X.png', 'png', 'photo'); // same base, both photos
		pairLivePhotos(db);
		expect(partner(a)).toBeNull();
		expect(partner(b)).toBeNull();
	});

	it('is case-insensitive on the base name', () => {
		const jpg = media('Clip.HEIC', 'heic', 'photo');
		const mov = media('clip.MP4', 'mp4', 'video');
		pairLivePhotos(db);
		expect(partner(jpg)).toBe(mov);
	});
});
```

### `src/lib/server/scan/pairing.ts`

```ts
/**
 * Live/Motion-photo pairing: an image and a video sharing the same directory + base name
 * (e.g. IMG_1234.HEIC + IMG_1234.MOV, or a Google motion JPEG/MP4 pair) are linked via
 * live_partner_id so the UI can badge them and play the motion clip on hover. Cheap DB pass
 * run after each scan.
 */
import type { DB } from '../db/index';
import { log } from '../log';

export function pairLivePhotos(db: DB): number {
	// basename without extension = filename minus (".ext"); ext column excludes the dot.
	const stmt = db.prepare(`
		UPDATE media SET live_partner_id = (
			SELECT m2.id FROM media m2
			WHERE m2.dir = media.dir
			  AND m2.id != media.id
			  AND m2.type != media.type
			  AND m2.is_trashed = 0
			  AND lower(substr(m2.filename, 1, length(m2.filename) - length(m2.ext) - 1))
			    = lower(substr(media.filename, 1, length(media.filename) - length(media.ext) - 1))
			ORDER BY m2.id LIMIT 1
		)
		WHERE is_trashed = 0
	`);
	const info = stmt.run();
	log.debug(`Live/Motion pairing pass updated ${info.changes} row(s).`);
	return info.changes;
}
```

### `src/lib/server/scan/scanner.ts`

```ts
/**
 * Scan orchestrator: walk → incremental diff → upsert → stale-sweep, with offline-root
 * protection and per-file resilience. Batched transactions keep the event loop responsive.
 * See docs/05-PERFORMANCE.md (scanner) and docs/08-DATA-SAFETY.md (resilience).
 */
import fs from 'node:fs';
import path from 'node:path';
import { getDb, type DB } from '../db/index';
import { bustBucketsCache } from '../db/queries';
import { getConfig, getTrashDir } from '../config/configService';
import { walkRoot, type WalkOptions } from './walker';
import { withLock } from '../lock';
import { patchScan, bumpScan, getScanState, setPending } from './scanState';
import { localDayFromMs } from '$shared/format';
import { thumbPath, storyboardPath } from '../paths';
import { log } from '../log';

const BATCH = 1000;

let running = false;
let rescanQueued: null | { reason: string; full: boolean } = null;
let backstopTimer: ReturnType<typeof setInterval> | null = null;

interface RootRow {
	id: number;
	path: string;
}

function getRootRows(db: DB): RootRow[] {
	return db.prepare(`SELECT id, path FROM roots WHERE enabled = 1`).all() as RootRow[];
}

/**
 * Reconcile the `roots` table against config: upsert configured roots, and DROP roots that are no
 * longer in config (cascade-deleting their media rows + thumbnails). Called at startup and on
 * config save, so removing a folder from config actually removes its photos from the library.
 */
export function reconcileRoots(db: DB): void {
	const cfg = getConfig();
	const paths = cfg.roots.map((r) => r.path);
	const upsert = db.prepare(
		`INSERT INTO roots(path, label, enabled, online) VALUES(@path, @label, @enabled, 1)
		 ON CONFLICT(path) DO UPDATE SET label=excluded.label, enabled=excluded.enabled`
	);
	const ph = paths.map(() => '?').join(',');
	const staleRows = (
		paths.length
			? (db.prepare(`SELECT id, path FROM roots WHERE path NOT IN (${ph})`).all(...paths) as { id: number; path: string }[])
			: (db.prepare(`SELECT id, path FROM roots`).all() as { id: number; path: string }[])
	);
	// SAFETY: purge a de-configured root's media only when its folder is currently REACHABLE
	// (an intentional "stop indexing this present folder"). If it's unreachable — drive unplugged /
	// offline NAS at the moment of a config save, or a normalization drift — just disable the root
	// and KEEP its index, so a momentarily-offline drive can't nuke favorites/albums/metadata.
	const stale: { id: number }[] = [];
	for (const s of staleRows) {
		if (rootReachable(s.path)) {
			stale.push({ id: s.id });
		} else {
			db.prepare(`UPDATE roots SET enabled = 0, online = 0 WHERE id = ?`).run(s.id);
			log.warn(`Reconcile: root "${s.path}" left config but is unreachable — disabled, index kept (not purged).`);
		}
	}
	const staleMedia = stale.length
		? (db
				.prepare(`SELECT id FROM media WHERE root_id IN (${stale.map(() => '?').join(',')})`)
				.all(...stale.map((s) => s.id)) as { id: number }[])
		: [];
	const tx = db.transaction(() => {
		for (const r of cfg.roots) upsert.run({ path: r.path, label: r.label ?? '', enabled: r.enabled ? 1 : 0 });
		for (const s of stale) db.prepare(`DELETE FROM roots WHERE id = ?`).run(s.id); // cascade removes media
	});
	tx();
	for (const m of staleMedia) deleteThumbs(m.id);
	if (stale.length) log.info(`Reconcile: removed ${stale.length} de-configured root(s) and their media.`);
	bustBucketsCache();
}

function setRootOnline(db: DB, id: number, online: boolean): void {
	db.prepare(`UPDATE roots SET online = ? WHERE id = ?`).run(online ? 1 : 0, id);
}

function rootReachable(p: string): boolean {
	try {
		return fs.statSync(p).isDirectory();
	} catch {
		return false;
	}
}

function walkOptions(): WalkOptions {
	const c = getConfig();
	return {
		include: c.include,
		exclude: c.exclude,
		imageExtensions: new Set(c.imageExtensions),
		videoExtensions: new Set(c.videoExtensions),
		followSymlinks: c.scan.followSymlinks,
		skipDirs: [path.resolve(process.cwd(), 'data').replace(/\\/g, '/').toLowerCase()]
	};
}

function deleteThumbs(id: number): void {
	const dir = getConfig().thumbnails.dir;
	for (const f of [
		thumbPath(dir, id, 'grid'),
		thumbPath(dir, id, 'grid2x'),
		thumbPath(dir, id, 'preview'),
		storyboardPath(dir, id)
	]) {
		try {
			fs.rmSync(f, { force: true });
		} catch {
			/* best effort */
		}
	}
}

/** True only if the path is confirmed GONE (ENOENT) — not merely temporarily inaccessible. */
function fileGone(p: string): boolean {
	try {
		fs.statSync(p);
		return false;
	} catch (e) {
		return (e as NodeJS.ErrnoException).code === 'ENOENT';
	}
}

function updatePendingCounts(db: DB): void {
	const meta = db
		.prepare(`SELECT COUNT(*) AS n FROM media WHERE is_trashed = 0 AND meta_status IN (0,1)`)
		.get() as { n: number };
	const thumb = db
		.prepare(`SELECT COUNT(*) AS n FROM media WHERE is_trashed = 0 AND thumb_status IN (0,1)`)
		.get() as { n: number };
	setPending(meta.n, thumb.n);
}

async function runScan(full: boolean): Promise<void> {
	const db = getDb();
	const startedAt = Date.now();
	const scanRow = db
		.prepare(`INSERT INTO scans(started_at, status) VALUES(?, 'running')`)
		.run(startedAt);
	const scanId = Number(scanRow.lastInsertRowid);

	patchScan({
		status: 'running',
		scanId,
		filesSeen: 0,
		added: 0,
		updated: 0,
		removed: 0,
		startedAt,
		finishedAt: null,
		error: null,
		currentRoot: null
	});
	log.info(`Scan #${scanId} started (${full ? 'full' : 'incremental'}).`);

	const getByPath = db.prepare(`SELECT id, mtime_ms, size_bytes FROM media WHERE path = ?`);
	const insertMedia = db.prepare(
		`INSERT INTO media (path, root_id, rel_path, dir, filename, ext, type, size_bytes, mtime_ms,
		   taken_ms, taken_local_day, taken_source, meta_status, thumb_status, scan_id, created_at, updated_at)
		 VALUES (@path, @root_id, @rel_path, @dir, @filename, @ext, @type, @size_bytes, @mtime_ms,
		   @taken_ms, @taken_local_day, 'mtime', 0, 0, @scan_id, @now, @now)`
	);
	const updateChanged = db.prepare(
		`UPDATE media SET size_bytes=@size_bytes, mtime_ms=@mtime_ms, dir=@dir, filename=@filename,
		   rel_path=@rel_path, ext=@ext, type=@type, meta_status=0, thumb_status=0, scan_id=@scan_id,
		   taken_ms=@mtime_ms, taken_local_day=@taken_local_day, taken_source='mtime', updated_at=@now
		 WHERE id=@id`
	);
	const stampScan = db.prepare(`UPDATE media SET scan_id=@scan_id WHERE id=@id`);

	const onlineRootIds: number[] = [];
	let errored: string | null = null;

	// Start thumbnailing as soon as the first batch lands, so it overlaps the (possibly long) walk
	// rather than waiting for the whole library to be enumerated first.
	let kickPipeline: (() => void) | null = null;
	let pipelineKicked = false;
	try {
		kickPipeline = (await import('../media/pipeline')).processPending;
	} catch {
		/* pipeline lands in P2 */
	}

	try {
		const opts = walkOptions();
		for (const root of getRootRows(db)) {
			if (!rootReachable(root.path)) {
				setRootOnline(db, root.id, false);
				log.warn(`Root offline, retaining its index and skipping sweep: ${root.path}`);
				continue;
			}
			setRootOnline(db, root.id, true);
			onlineRootIds.push(root.id);
			patchScan({ currentRoot: root.path });

			// Buffer entries and flush in batched transactions.
			let buffer: {
				row: ReturnType<typeof toRow>;
				existing: { id: number; mtime_ms: number; size_bytes: number } | undefined;
			}[] = [];

			// Flush under the shared lock so a batch can't interleave with a user mutation
			// (trash/move/rename) mid-operation. Critical section is just the transaction.
			const flush = () => {
				if (!buffer.length) return Promise.resolve();
				const items = buffer;
				buffer = [];
				const now = Date.now();
				return withLock(() => {
					const tx = db.transaction(() => {
						for (const { row, existing } of items) {
							if (!existing) {
								insertMedia.run({ ...row, scan_id: scanId, now });
								bumpScan('added');
							} else if (
								existing.mtime_ms !== row.mtime_ms ||
								existing.size_bytes !== row.size_bytes
							) {
								updateChanged.run({ ...row, id: existing.id, scan_id: scanId, now });
								bumpScan('updated');
							} else {
								stampScan.run({ id: existing.id, scan_id: scanId });
							}
							bumpScan('filesSeen');
						}
					});
					tx();
				}).then(() => {
					// Start thumbnailing after the first batch so it overlaps the rest of the walk.
					if (kickPipeline && !pipelineKicked) {
						pipelineKicked = true;
						kickPipeline();
					}
				});
			};

			const toRow = (e: { path: string; mtimeMs: number; sizeBytes: number; ext: string; type: string }) => {
				const lastSlash = e.path.lastIndexOf('/');
				const dir = e.path.slice(0, lastSlash);
				const filename = e.path.slice(lastSlash + 1);
				const rel = e.path.startsWith(root.path + '/') ? e.path.slice(root.path.length + 1) : filename;
				return {
					path: e.path,
					root_id: root.id,
					rel_path: rel,
					dir,
					filename,
					ext: e.ext,
					type: e.type,
					size_bytes: e.sizeBytes,
					mtime_ms: e.mtimeMs,
					taken_ms: e.mtimeMs,
					taken_local_day: localDayFromMs(e.mtimeMs)
				};
			};

			for await (const entry of walkRoot(root.path, opts, (where, err) => {
				log.warn(`Scan skip: ${where}`, err instanceof Error ? err.message : err);
			})) {
				const existing = getByPath.get(entry.path) as
					| { id: number; mtime_ms: number; size_bytes: number }
					| undefined;
				buffer.push({ row: toRow(entry), existing });
				if (buffer.length >= BATCH) {
					await flush();
					await new Promise((r) => setImmediate(r)); // keep the event loop responsive
				}
			}
			await flush();
		}

		// Sweep: rows in online roots not re-stamped this scan. We DELETE only rows whose file is
		// genuinely gone from disk — never rows merely excluded by a filter change, and never
		// trashed rows (those moved to data/trash and must stay restorable).
		if (getConfig().scan.removeMissing && onlineRootIds.length) {
			const placeholders = onlineRootIds.map(() => '?').join(',');
			const stale = db
				.prepare(
					`SELECT id, path FROM media
					 WHERE (scan_id IS NULL OR scan_id != ?) AND is_trashed = 0 AND root_id IN (${placeholders})`
				)
				.all(scanId, ...onlineRootIds) as { id: number; path: string }[];
			const missing = stale.filter((r) => fileGone(r.path));
			if (missing.length) {
				await withLock(() => {
					const del = db.prepare(`DELETE FROM media WHERE id = ?`);
					db.transaction(() => {
						for (const { id } of missing) del.run(id);
					})();
				});
				for (const { id } of missing) deleteThumbs(id);
				patchScan({ removed: missing.length });
				log.info(
					`Sweep removed ${missing.length} missing file(s)` +
						(stale.length > missing.length
							? ` (kept ${stale.length - missing.length} still on disk but unmatched, e.g. filtered out).`
							: '.')
				);
			}
		}

		// Link Live/Motion photo pairs (image + video sharing dir + base name).
		try {
			const { pairLivePhotos } = await import('./pairing');
			pairLivePhotos(db);
		} catch (e) {
			log.debug('live-photo pairing failed', e);
		}
	} catch (e) {
		errored = e instanceof Error ? e.message : String(e);
		log.error(`Scan #${scanId} failed`, e);
	}

	const finishedAt = Date.now();
	const s = getScanState();
	db.prepare(
		`UPDATE scans SET finished_at=?, status=?, files_seen=?, added=?, updated=?, removed=?, error=? WHERE id=?`
	).run(
		finishedAt,
		errored ? 'error' : 'done',
		s.filesSeen,
		s.added,
		s.updated,
		s.removed,
		errored,
		scanId
	);
	patchScan({ status: errored ? 'error' : 'done', finishedAt, error: errored, currentRoot: null });
	updatePendingCounts(db);
	bustBucketsCache(); // counts/day-buckets may have changed this scan
	log.info(
		`Scan #${scanId} ${errored ? 'errored' : 'done'} in ${finishedAt - startedAt}ms — seen ${s.filesSeen}, +${s.added} ~${s.updated} -${s.removed}.`
	);

	// Hand pending work to the media pipeline (P2). Lazy + non-fatal.
	try {
		const { processPending } = await import('../media/pipeline');
		processPending();
	} catch (e) {
		log.debug('media pipeline not available yet', e);
	}
	// Reverse-geocode any new geotagged photos (no-op unless geocoding is enabled).
	try {
		const { geocodePending } = await import('../geo/geocodeService');
		geocodePending();
	} catch (e) {
		log.debug('geocode pass skipped', e);
	}
}

/** Start a scan if one isn't running; otherwise mark that another pass is wanted. */
export function requestRescan(opts: { reason: string; full?: boolean } = { reason: 'manual' }): void {
	const full = !!opts.full;
	if (running) {
		rescanQueued = { reason: opts.reason, full: full || (rescanQueued?.full ?? false) };
		log.debug(`Rescan queued (${opts.reason}); a scan is already running.`);
		return;
	}
	running = true;
	(async () => {
		try {
			await runScan(full);
			while (rescanQueued) {
				const next = rescanQueued;
				rescanQueued = null;
				await runScan(next.full);
			}
		} finally {
			running = false;
		}
	})();
}

export function isScanning(): boolean {
	return running;
}

/** Called once at startup: scan if configured, or if the index is empty. */
export async function bootScan(): Promise<void> {
	const db = getDb();
	const count = (db.prepare(`SELECT COUNT(*) AS n FROM media`).get() as { n: number }).n;
	updatePendingCounts(db);

	// Always resume pending pipeline work from a prior run (resumable, newest-first). First reclaim
	// any rows a prior crash left mid-flight (status 1) by resetting them to pending.
	try {
		const { processPending, resetStuckProcessing } = await import('../media/pipeline');
		resetStuckProcessing(db);
		processPending();
		// Back-stop: periodically re-trigger the (idempotent) drain so a worker crash that leaves the
		// queue with nothing in flight can't permanently strand the remaining backlog.
		if (!backstopTimer) {
			backstopTimer = setInterval(() => {
				const pend = db
					.prepare(`SELECT 1 FROM media WHERE is_trashed = 0 AND (meta_status IN (0,1) OR thumb_status IN (0,1)) LIMIT 1`)
					.get();
				if (pend) processPending();
			}, 5 * 60_000);
			backstopTimer.unref?.();
		}
	} catch {
		/* pipeline lands in P2 */
	}

	if (getConfig().scan.onStartup || count === 0) {
		requestRescan({ reason: count === 0 ? 'empty-index' : 'startup' });
	}

	// Resume reverse-geocoding for any geotagged photos awaiting it (no-op unless enabled).
	try {
		const { geocodePending } = await import('../geo/geocodeService');
		geocodePending();
	} catch {
		/* optional */
	}

	// Live watcher (optional, scan.watch): auto-index new/changed/removed files without a rescan.
	try {
		const { startWatcher } = await import('./watcher');
		startWatcher();
	} catch (e) {
		log.debug('watcher start skipped', e);
	}
}
```

### `src/lib/server/scan/scanState.test.ts`

```ts
import { describe, it, expect } from 'vitest';
import { getScanState, patchScan, bumpScan, setPending, subscribeScan } from './scanState';

describe('scanState', () => {
	it('patches, bumps counters, and tracks pending (happy path)', () => {
		patchScan({ status: 'running', added: 0, filesSeen: 0 });
		bumpScan('added', 2);
		bumpScan('filesSeen');
		setPending(5, 9);
		const s = getScanState();
		expect(s.status).toBe('running');
		expect(s.added).toBe(2);
		expect(s.filesSeen).toBe(1);
		expect(s.metaPending).toBe(5);
		expect(s.thumbsPending).toBe(9);
	});

	it('returns a snapshot copy (mutating it does not affect state)', () => {
		const snap = getScanState();
		snap.added = 999;
		expect(getScanState().added).not.toBe(999);
	});

	it('notifies subscribers on change and unsubscribe stops them', async () => {
		const seen: number[] = [];
		const unsub = subscribeScan((s) => seen.push(s.added));
		expect(seen).toHaveLength(1); // immediate snapshot
		patchScan({ added: 42 });
		await Promise.resolve(); // notify is coalesced into a microtask
		expect(seen.at(-1)).toBe(42);
		unsub();
		patchScan({ added: 43 });
		await Promise.resolve();
		expect(seen.at(-1)).toBe(42); // no further calls after unsubscribe
	});
});
```

### `src/lib/server/scan/scanState.ts`

```ts
/**
 * In-memory scan progress. Exposed via GET /api/scan/status (poll) and pushed over
 * GET /api/scan/stream (SSE). Lives in the single long-lived server process.
 */
import type { ScanState } from '$shared/types';

const state: ScanState = {
	status: 'idle',
	scanId: null,
	filesSeen: 0,
	added: 0,
	updated: 0,
	removed: 0,
	metaPending: 0,
	thumbsPending: 0,
	throughputPerSec: 0,
	etaMs: null,
	startedAt: null,
	finishedAt: null,
	error: null,
	currentRoot: null
};

type Listener = (s: ScanState) => void;
const listeners = new Set<Listener>();

export function getScanState(): ScanState {
	return { ...state };
}

export function subscribeScan(fn: Listener): () => void {
	listeners.add(fn);
	fn(getScanState());
	return () => listeners.delete(fn);
}

let notifyScheduled = false;
function notify(): void {
	// Coalesce bursts of updates into one emit per tick.
	if (notifyScheduled) return;
	notifyScheduled = true;
	queueMicrotask(() => {
		notifyScheduled = false;
		const snap = getScanState();
		for (const fn of listeners) {
			try {
				fn(snap);
			} catch {
				/* a dead SSE listener must not break others */
			}
		}
	});
}

export function patchScan(p: Partial<ScanState>): void {
	Object.assign(state, p);
	notify();
}

export function bumpScan(field: 'filesSeen' | 'added' | 'updated' | 'removed', by = 1): void {
	state[field] += by;
	notify();
}

export function setPending(metaPending: number, thumbsPending: number): void {
	state.metaPending = metaPending;
	state.thumbsPending = thumbsPending;
	recomputeEta();
	notify();
}

// Rolling throughput: keep ~30s of cumulative-count samples and derive a per-second rate + ETA.
const RATE_WINDOW_MS = 30_000;
const rate: { samples: { t: number; total: number }[]; total: number } = { samples: [], total: 0 };

function recomputeEta(): void {
	const first = rate.samples[0];
	if (!first) {
		state.throughputPerSec = 0;
		state.etaMs = null;
		return;
	}
	const now = Date.now();
	const dt = (now - first.t) / 1000;
	const dn = rate.total - first.total;
	state.throughputPerSec = dt > 0 ? dn / dt : 0;
	state.etaMs =
		state.throughputPerSec > 0 && state.thumbsPending > 0
			? Math.round((state.thumbsPending / state.throughputPerSec) * 1000)
			: state.thumbsPending === 0
				? 0
				: null;
}

/** Record `n` thumbnails finished — feeds the rolling throughput + ETA estimate. */
export function recordProcessed(n = 1): void {
	const now = Date.now();
	rate.total += n;
	rate.samples.push({ t: now, total: rate.total });
	while (rate.samples.length > 1 && now - rate.samples[0].t > RATE_WINDOW_MS) rate.samples.shift();
	recomputeEta();
	notify();
}
```

### `src/lib/server/scan/walker.test.ts`

```ts
import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { globToRegExp, walkRoot, type WalkOptions } from './walker';
import { normalizePath } from '../paths';

describe('globToRegExp', () => {
	it('** / * matches any depth', () => {
		const re = globToRegExp('**/*');
		expect(re.test('a.jpg')).toBe(true);
		expect(re.test('x/y/a.jpg')).toBe(true);
	});
	it('**/.* matches hidden files at any depth', () => {
		const re = globToRegExp('**/.*');
		expect(re.test('.hidden')).toBe(true);
		expect(re.test('a/.hidden')).toBe(true);
		expect(re.test('a.jpg')).toBe(false);
	});
	it('**/@eaDir/** matches files under @eaDir', () => {
		const re = globToRegExp('**/@eaDir/**');
		expect(re.test('@eaDir/z.jpg')).toBe(true);
		expect(re.test('x/@eaDir/y.jpg')).toBe(true);
		expect(re.test('x/other/y.jpg')).toBe(false);
	});
	it('* does not cross slashes', () => {
		const re = globToRegExp('*.jpg');
		expect(re.test('a.jpg')).toBe(true);
		expect(re.test('x/a.jpg')).toBe(false);
	});
});

describe('walkRoot', () => {
	let root: string;
	beforeAll(async () => {
		root = await fs.promises.mkdtemp(path.join(os.tmpdir(), 'lg-walk-'));
		await fs.promises.writeFile(path.join(root, 'a.jpg'), 'x');
		await fs.promises.writeFile(path.join(root, 'b.txt'), 'x');
		await fs.promises.writeFile(path.join(root, '.hidden.jpg'), 'x');
		await fs.promises.mkdir(path.join(root, 'sub'));
		await fs.promises.writeFile(path.join(root, 'sub', 'c.png'), 'x');
		await fs.promises.mkdir(path.join(root, '@eaDir'));
		await fs.promises.writeFile(path.join(root, '@eaDir', 'd.jpg'), 'x');
	});
	afterAll(async () => {
		await fs.promises.rm(root, { recursive: true, force: true });
	});

	it('yields only included media, skipping junk/hidden/non-media', async () => {
		const opts: WalkOptions = {
			include: ['**/*'],
			exclude: ['**/.*', '**/@eaDir/**', '**/Thumbs.db'],
			imageExtensions: new Set(['jpg', 'png']),
			videoExtensions: new Set(),
			followSymlinks: false
		};
		const found: string[] = [];
		for await (const e of walkRoot(normalizePath(root), opts)) {
			found.push(e.path.slice(normalizePath(root).length + 1));
		}
		found.sort();
		expect(found).toEqual(['a.jpg', 'sub/c.png']);
	});
});
```

### `src/lib/server/scan/walker.ts`

```ts
/**
 * Iterative (explicit-stack) directory walk using fs.promises.opendir, which streams
 * entries — bounded memory even on huge trees. Yields media files only, after applying
 * include/exclude globs and the configured extension sets. See docs/05-PERFORMANCE.md.
 */
import fs from 'node:fs';
import path from 'node:path';
import type { MediaType } from '$shared/types';

const isWin = process.platform === 'win32';

/** Directory names we never descend into. */
const JUNK_DIRS = new Set([
	'@eadir',
	'#recycle',
	'$recycle.bin',
	'system volume information',
	'node_modules',
	'.git'
]);

export interface WalkEntry {
	/** Normalized (forward-slash, lower-cased drive) absolute path. */
	path: string;
	mtimeMs: number;
	sizeBytes: number;
	ext: string;
	type: MediaType;
}

export interface WalkOptions {
	include: string[];
	exclude: string[];
	imageExtensions: Set<string>;
	videoExtensions: Set<string>;
	followSymlinks: boolean;
	/** Absolute normalized dirs to skip entirely (e.g. the app's own data/). */
	skipDirs?: string[];
}

/** Minimal glob -> RegExp supporting double-star, double-star-slash, single-star, and ?. */
export function globToRegExp(glob: string): RegExp {
	let re = '';
	for (let i = 0; i < glob.length; i++) {
		const c = glob[i];
		if (c === '*') {
			if (glob[i + 1] === '*') {
				if (glob[i + 2] === '/') {
					re += '(?:.*/)?'; // **/  -> zero or more leading dirs
					i += 2;
				} else {
					re += '.*'; // **  -> anything, including slashes
					i += 1;
				}
			} else {
				re += '[^/]*'; // *  -> anything except a slash
			}
		} else if (c === '?') {
			re += '[^/]';
		} else if ('.+^${}()|[]\\'.includes(c)) {
			re += '\\' + c; // escape regex specials (slash stays literal)
		} else {
			re += c;
		}
	}
	return new RegExp('^' + re + '$', isWin ? 'i' : '');
}

export function compileGlobs(globs: string[]): RegExp[] {
	return globs.map(globToRegExp);
}

function matchesAny(res: RegExp[], rel: string): boolean {
	for (const re of res) if (re.test(rel)) return true;
	return false;
}

function toStored(abs: string): string {
	let p = abs.replace(/\\/g, '/');
	p = p.replace(/^([a-zA-Z]):\//, (_m, d: string) => d.toLowerCase() + ':/');
	return p;
}

/**
 * Walk one root, yielding media WalkEntry objects. Resilient: a directory that throws
 * (permission denied, vanished) is reported via `onError` and skipped, not fatal.
 */
export async function* walkRoot(
	rootNormalized: string,
	opts: WalkOptions,
	onError?: (where: string, err: unknown) => void
): AsyncGenerator<WalkEntry> {
	const includeRes = compileGlobs(opts.include.length ? opts.include : ['**/*']);
	const excludeRes = compileGlobs(opts.exclude);
	const skip = new Set((opts.skipDirs ?? []).map((d) => d.toLowerCase()));
	const stack: string[] = [rootNormalized];

	while (stack.length) {
		const cur = stack.pop()!;
		let dir: fs.Dir;
		try {
			dir = await fs.promises.opendir(cur);
		} catch (err) {
			onError?.(cur, err);
			continue;
		}
		try {
			for await (const ent of dir) {
				const full = toStored(path.join(cur, ent.name));
				const rel = full.startsWith(rootNormalized + '/')
					? full.slice(rootNormalized.length + 1)
					: ent.name;

				let isDir = ent.isDirectory();
				let isFile = ent.isFile();
				if (ent.isSymbolicLink()) {
					if (!opts.followSymlinks) continue;
					try {
						const st = await fs.promises.stat(full); // follow the link
						isDir = st.isDirectory();
						isFile = st.isFile();
					} catch (err) {
						onError?.(full, err);
						continue;
					}
				}

				if (isDir) {
					const lower = ent.name.toLowerCase();
					if (ent.name.startsWith('.') || JUNK_DIRS.has(lower)) continue;
					if (skip.has(full.toLowerCase())) continue;
					stack.push(full);
					continue;
				}
				if (!isFile) continue;

				const dot = ent.name.lastIndexOf('.');
				const ext = dot >= 0 ? ent.name.slice(dot + 1).toLowerCase() : '';
				const type: MediaType | null = opts.imageExtensions.has(ext)
					? 'photo'
					: opts.videoExtensions.has(ext)
						? 'video'
						: null;
				if (!type) continue;
				if (!matchesAny(includeRes, rel)) continue;
				if (matchesAny(excludeRes, rel)) continue;

				let st: fs.Stats;
				try {
					st = await fs.promises.stat(full);
				} catch (err) {
					onError?.(full, err);
					continue;
				}
				yield { path: full, mtimeMs: Math.round(st.mtimeMs), sizeBytes: st.size, ext, type };
			}
		} catch (err) {
			onError?.(cur, err);
		}
	}
}
```

### `src/lib/server/scan/watcher.ts`

```ts
/**
 * Optional live filesystem watcher (chokidar), gated by `scan.watch`. When on, files added /
 * changed / removed in the roots are indexed incrementally — no manual rescan needed. Events are
 * debounced + batched, and DB writes go through the shared lock (same as the scanner/fileService).
 */
import fs from 'node:fs';
import chokidar, { type FSWatcher } from 'chokidar';
import { getDb, type DB } from '../db/index';
import { getConfig, getEnabledRoots } from '../config/configService';
import { normalizePath, isWithin, splitPath, thumbPath, storyboardPath } from '../paths';
import { withLock } from '../lock';
import { bustBucketsCache } from '../db/queries';
import { localDayFromMs } from '$shared/format';
import { patchScan } from './scanState';
import { log } from './../log';

let watcher: FSWatcher | null = null;
const pending = new Map<string, 'upsert' | 'remove'>();
let flushTimer: ReturnType<typeof setTimeout> | undefined;

function extOf(p: string): string {
	const dot = p.lastIndexOf('.');
	return dot >= 0 ? p.slice(dot + 1).toLowerCase() : '';
}

function mediaType(ext: string): 'photo' | 'video' | null {
	const c = getConfig();
	if (c.imageExtensions.includes(ext)) return 'photo';
	if (c.videoExtensions.includes(ext)) return 'video';
	return null;
}

function rootFor(db: DB, norm: string): { id: number; path: string } | null {
	const roots = db.prepare(`SELECT id, path FROM roots WHERE enabled = 1`).all() as {
		id: number;
		path: string;
	}[];
	for (const r of roots) if (isWithin(norm, r.path)) return r;
	return null;
}

function deleteWatchThumbs(id: number): void {
	const dir = getConfig().thumbnails.dir;
	for (const f of [
		thumbPath(dir, id, 'grid'),
		thumbPath(dir, id, 'grid2x'),
		thumbPath(dir, id, 'preview'),
		storyboardPath(dir, id)
	]) {
		try {
			fs.rmSync(f, { force: true });
		} catch {
			/* best effort */
		}
	}
}

function scheduleFlush() {
	clearTimeout(flushTimer);
	flushTimer = setTimeout(() => void flush(), 600);
}

async function flush() {
	if (!pending.size) return;
	const batch = [...pending.entries()];
	pending.clear();
	const db = getDb();

	await withLock(async () => {
		const insert = db.prepare(
			`INSERT INTO media (path, root_id, rel_path, dir, filename, ext, type, size_bytes, mtime_ms,
			   taken_ms, taken_local_day, taken_source, meta_status, thumb_status, scan_id, created_at, updated_at)
			 VALUES (@path,@root_id,@rel,@dir,@filename,@ext,@type,@size,@mtime,@mtime,@day,'mtime',0,0,NULL,@now,@now)
			 ON CONFLICT(path) DO UPDATE SET size_bytes=@size, mtime_ms=@mtime, meta_status=0, thumb_status=0,
			   taken_ms=@mtime, taken_local_day=@day, taken_source='mtime', updated_at=@now`
		);
		const findByPath = db.prepare(`SELECT id, is_trashed FROM media WHERE path = ?`);
		const del = db.prepare(`DELETE FROM media WHERE id = ?`);
		for (const [abs, kind] of batch) {
			const norm = normalizePath(abs);
			try {
				if (kind === 'remove') {
					const row = findByPath.get(norm) as { id: number; is_trashed: number } | undefined;
					// Skip if: not indexed; trashed (trash() moved the file out — the row must stay
					// restorable); or the file still exists (spurious/atomic-rename event).
					if (!row || row.is_trashed) continue;
					if (fs.existsSync(abs)) continue;
					del.run(row.id);
					deleteWatchThumbs(row.id);
					continue;
				}
				const root = rootFor(db, norm);
				if (!root) continue;
				const st = fs.statSync(abs);
				if (!st.isFile()) continue;
				const ext = extOf(norm);
				const type = mediaType(ext);
				if (!type) continue;
				const parts = splitPath(root.path, norm);
				insert.run({
					path: norm,
					root_id: root.id,
					rel: parts.relPath,
					dir: parts.dir,
					filename: parts.filename,
					ext,
					type,
					size: st.size,
					mtime: Math.round(st.mtimeMs),
					day: localDayFromMs(Math.round(st.mtimeMs)),
					now: Date.now()
				});
			} catch (e) {
				log.debug(`watch index skip ${abs}`, e instanceof Error ? e.message : e);
			}
		}
	});

	bustBucketsCache();
	try {
		const { pairLivePhotos } = await import('./pairing');
		pairLivePhotos(db);
	} catch {
		/* ignore */
	}
	try {
		const { processPending } = await import('../media/pipeline');
		processPending();
	} catch {
		/* ignore */
	}
	// nudge the progress chip so the UI reflects new pending work
	const meta = db.prepare(`SELECT COUNT(*) AS n FROM media WHERE is_trashed=0 AND meta_status IN (0,1)`).get() as { n: number };
	const thumb = db.prepare(`SELECT COUNT(*) AS n FROM media WHERE is_trashed=0 AND thumb_status IN (0,1)`).get() as { n: number };
	patchScan({ metaPending: meta.n, thumbsPending: thumb.n });
	log.info(`Watcher indexed ${batch.length} change(s).`);
}

function queue(abs: string, kind: 'upsert' | 'remove') {
	// Only care about media files (cheap ext gate; full validation happens on flush).
	if (kind === 'upsert' && !mediaType(extOf(abs))) return;
	pending.set(abs, kind);
	scheduleFlush();
}

export function startWatcher(): void {
	stopWatcher();
	const cfg = getConfig();
	if (!cfg.scan.watch) return;
	const roots = getEnabledRoots().filter((r) => {
		try {
			return fs.statSync(r).isDirectory();
		} catch {
			return false;
		}
	});
	if (!roots.length) return;

	watcher = chokidar.watch(roots, {
		ignoreInitial: true,
		persistent: true,
		followSymlinks: cfg.scan.followSymlinks,
		awaitWriteFinish: { stabilityThreshold: 800, pollInterval: 100 },
		ignored: (p: string) => /[\\/](\.|@eaDir|#recycle|\$RECYCLE\.BIN|node_modules)/i.test(p)
	});
	watcher
		.on('add', (p) => queue(p, 'upsert'))
		.on('change', (p) => queue(p, 'upsert'))
		.on('unlink', (p) => queue(p, 'remove'))
		.on('error', (e) => log.warn('watcher error', e));
	log.info(`File watcher started on ${roots.length} root(s).`);
}

export function stopWatcher(): void {
	if (watcher) {
		void watcher.close();
		watcher = null;
	}
	clearTimeout(flushTimer);
}
```

### `src/lib/server/security.test.ts`

```ts
import { describe, it, expect } from 'vitest';
import type { RequestEvent } from '@sveltejs/kit';
import {
	hashPassword,
	verifyPassword,
	sessionTokenFor,
	timingSafeStrEqual,
	isSameOrigin,
	requireMutation
} from './security';

describe('password hashing', () => {
	it('verifies the correct password and rejects wrong ones (happy + fail)', () => {
		const h = hashPassword('hunter2');
		expect(h.startsWith('scrypt$')).toBe(true);
		expect(verifyPassword('hunter2', h)).toBe(true);
		expect(verifyPassword('nope', h)).toBe(false);
	});
	it('rejects a malformed stored hash without throwing', () => {
		expect(verifyPassword('x', 'not-a-real-hash')).toBe(false);
		expect(verifyPassword('x', 'scrypt$zz$zz')).toBe(false);
	});
	it('produces different hashes for the same password (random salt)', () => {
		expect(hashPassword('a')).not.toBe(hashPassword('a'));
	});
});

describe('sessionTokenFor', () => {
	it('is deterministic per hash and differs across hashes', () => {
		expect(sessionTokenFor('abc')).toBe(sessionTokenFor('abc'));
		expect(sessionTokenFor('abc')).not.toBe(sessionTokenFor('abd'));
	});
});

describe('timingSafeStrEqual', () => {
	it('matches equal strings, rejects unequal / different-length', () => {
		expect(timingSafeStrEqual('abc', 'abc')).toBe(true);
		expect(timingSafeStrEqual('abc', 'abd')).toBe(false);
		expect(timingSafeStrEqual('abc', 'abcd')).toBe(false);
		expect(timingSafeStrEqual('', '')).toBe(true);
	});
});

function evt(opts: {
	sfs?: string;
	origin?: string;
	cookie?: string;
	header?: string;
	authed?: boolean;
}): RequestEvent {
	const h = new Headers();
	if (opts.sfs) h.set('sec-fetch-site', opts.sfs);
	if (opts.origin) h.set('origin', opts.origin);
	if (opts.header) h.set('x-csrf-token', opts.header);
	return {
		request: new Request('http://localhost/api/x', { headers: h }),
		url: new URL('http://localhost/api/x'),
		cookies: { get: (n: string) => (n === 'lg_csrf' ? opts.cookie : undefined) },
		locals: { authed: opts.authed ?? true, csrfToken: opts.cookie ?? '' }
	} as unknown as RequestEvent;
}

describe('isSameOrigin', () => {
	it('allows same-origin / none, rejects cross-site (Sec-Fetch-Site)', () => {
		expect(isSameOrigin(evt({ sfs: 'same-origin' }))).toBe(true);
		expect(isSameOrigin(evt({ sfs: 'none' }))).toBe(true);
		expect(isSameOrigin(evt({ sfs: 'cross-site' }))).toBe(false);
	});
	it('falls back to Origin header when Sec-Fetch-Site is absent', () => {
		expect(isSameOrigin(evt({ origin: 'http://localhost' }))).toBe(true);
		expect(isSameOrigin(evt({ origin: 'http://evil.example' }))).toBe(false);
		expect(isSameOrigin(evt({}))).toBe(true); // no headers → non-browser, allowed
	});
});

describe('requireMutation', () => {
	it('passes for same-origin + matching CSRF + authed (happy path)', () => {
		expect(requireMutation(evt({ sfs: 'same-origin', cookie: 't', header: 't', authed: true }))).toBeNull();
	});
	it('rejects cross-site (403)', () => {
		expect(requireMutation(evt({ sfs: 'cross-site', cookie: 't', header: 't' }))?.status).toBe(403);
	});
	it('rejects a missing/!mismatched CSRF token (403)', () => {
		expect(requireMutation(evt({ sfs: 'same-origin', cookie: 't' }))?.status).toBe(403); // header missing
		expect(requireMutation(evt({ sfs: 'same-origin', cookie: 't', header: 'x' }))?.status).toBe(403);
	});
	it('rejects unauthenticated (401)', () => {
		expect(requireMutation(evt({ sfs: 'same-origin', cookie: 't', header: 't', authed: false }))?.status).toBe(401);
	});
});
```

### `src/lib/server/security.ts`

```ts
/**
 * Request-level guards for mutating endpoints: same-origin + CSRF double-submit, and
 * (when a password is configured) an authenticated session. See docs/07-SECURITY.md.
 * Read endpoints are side-effect-free and don't call this.
 */
import type { RequestEvent } from '@sveltejs/kit';
import crypto from 'node:crypto';
import { apiError } from './http';

// ---- password hashing (scrypt) + session derivation ----

/** Hash a plaintext password as `scrypt$<saltHex>$<hashHex>` for at-rest storage. */
export function hashPassword(plain: string): string {
	const salt = crypto.randomBytes(16);
	const hash = crypto.scryptSync(plain, salt, 64);
	return `scrypt$${salt.toString('hex')}$${hash.toString('hex')}`;
}

export function verifyPassword(plain: string, stored: string): boolean {
	const parts = stored.split('$');
	if (parts.length !== 3 || parts[0] !== 'scrypt') return false;
	const salt = Buffer.from(parts[1], 'hex');
	const expected = Buffer.from(parts[2], 'hex');
	// Reject malformed hashes (invalid/empty hex), or an all-empty key would match any password.
	if (salt.length === 0 || expected.length === 0) return false;
	const actual = crypto.scryptSync(plain, salt, expected.length);
	return expected.length === actual.length && crypto.timingSafeEqual(expected, actual);
}

/** Deterministic session token derived from the stored hash (no server-side session store). */
export function sessionTokenFor(passwordHash: string): string {
	return crypto.createHash('sha256').update('lg-session:' + passwordHash).digest('hex');
}

/** Constant-time string equality (lengths compared first; length isn't secret here). */
export function timingSafeStrEqual(a: string, b: string): boolean {
	if (a.length !== b.length) return false;
	try {
		return crypto.timingSafeEqual(Buffer.from(a), Buffer.from(b));
	} catch {
		return false;
	}
}

/** A browser cross-site request (the CSRF case) is rejected; same-origin/none is allowed. */
export function isSameOrigin(event: RequestEvent): boolean {
	const sfs = event.request.headers.get('sec-fetch-site');
	if (sfs) return sfs === 'same-origin' || sfs === 'none';
	const origin = event.request.headers.get('origin');
	if (!origin) return true; // non-browser client or same-origin navigation
	return origin === event.url.origin;
}

/**
 * Returns a 4xx Response if the mutation should be blocked, otherwise null.
 * Layered defenses: same-origin, CSRF double-submit token, and auth session.
 */
export function requireMutation(event: RequestEvent): Response | null {
	if (!isSameOrigin(event)) return apiError(403, 'CSRF', 'Cross-origin request rejected.');

	// Double-submit token: the header MUST be present and equal the cookie. (A cross-site
	// attacker can't read the cookie, so they can't set a matching header — and a missing header
	// must fail, not pass.) The cookie is seeded in hooks on the first request.
	const cookie = event.cookies.get('lg_csrf') ?? '';
	const header = event.request.headers.get('x-csrf-token') ?? '';
	if (!cookie || !header || !timingSafeStrEqual(cookie, header)) {
		return apiError(403, 'CSRF', 'Missing or invalid CSRF token.');
	}

	if (!event.locals.authed) return apiError(401, 'AUTH', 'Authentication required.');
	return null;
}
```

### `src/lib/server/startup.ts`

```ts
/**
 * One-time server bootstrap, invoked from hooks.server.ts. Loads config, opens the DB
 * (runs migrations), reconciles roots, and (P1+) kicks off the background scanner.
 * Idempotent — safe to call on every request; the heavy work runs once.
 */
import { loadConfig, getConfig, getAllRoots } from './config/configService';
import { getDb, closeDb } from './db/index';
import { log } from './log';

let started = false;
let startPromise: Promise<void> | null = null;

async function doStart(): Promise<void> {
	const { config, hash } = loadConfig();
	const db = getDb();

	// sharp dispatches its resizes to the libuv threadpool (default size 4), read once at process
	// init — so UV_THREADPOOL_SIZE must be set on the launch command (start scripts / setup), not
	// here. Advise if it's left at the default, which would bottleneck the worker pool at ~4 cores.
	if (!process.env.UV_THREADPOOL_SIZE) {
		log.warn(
			'UV_THREADPOOL_SIZE is unset (libuv defaults to 4). For fast large-library thumbnailing, ' +
				'launch via start-lgallery.cmd / setup-lgallery (which set it) or export UV_THREADPOOL_SIZE=16.'
		);
	}

	// Ensure any plaintext server.password is hashed at rest before serving requests.
	try {
		const { migratePasswordIfNeeded } = await import('./config/configService');
		migratePasswordIfNeeded();
	} catch (e) {
		log.warn('password migration skipped', e);
	}

	// Reconcile roots against config (upsert configured, drop de-configured + their media).
	const { reconcileRoots } = await import('./scan/scanner');
	reconcileRoots(db);

	// Persist current config hash so reload-time rescan detection has a baseline.
	db.prepare(
		`INSERT INTO app_state(key, value) VALUES('config_hash', ?)
		 ON CONFLICT(key) DO UPDATE SET value=excluded.value`
	).run(hash);

	log.info(
		`LGallery started. ${config.roots.length} root(s) configured: ${getAllRoots().join(', ')}`
	);

	// Scanner bootstrap (P1) is wired in scan/scanner.ts and called here.
	try {
		const { bootScan } = await import('./scan/scanner');
		await bootScan();
	} catch (e) {
		// Scanner module may not exist yet during early bring-up; never block startup.
		log.debug('Scanner bootstrap skipped/failed', e);
	}

	registerShutdown();
}

export function ensureStarted(): Promise<void> {
	if (started) return Promise.resolve();
	if (!startPromise) {
		startPromise = doStart()
			.then(() => {
				started = true;
			})
			.catch((e) => {
				startPromise = null; // allow a retry on the next request
				log.error('Startup failed', e);
				throw e;
			});
	}
	return startPromise;
}

let shutdownRegistered = false;
function registerShutdown(): void {
	if (shutdownRegistered) return;
	shutdownRegistered = true;
	const handler = (sig: string) => {
		log.info(`Received ${sig}; shutting down gracefully…`);
		// Best-effort: stop the thumbnail worker pool so its threads don't linger.
		import('./media/workerPool')
			.then((m) => m.shutdownPool())
			.catch(() => {})
			.finally(() => {
				try {
					closeDb();
				} finally {
					process.exit(0);
				}
			});
	};
	process.once('SIGINT', () => handler('SIGINT'));
	process.once('SIGTERM', () => handler('SIGTERM'));
}
```

### `src/lib/shared/blurhash.test.ts`

```ts
import { describe, it, expect } from 'vitest';
import { blurhashAverageColor } from './blurhash';

describe('blurhashAverageColor', () => {
	it('decodes a valid hash to an rgb() string (happy path)', () => {
		const c = blurhashAverageColor('LOK26MDwzx8d-pIMGEO|niZ2v~M#');
		expect(c).toMatch(/^rgb\(\d{1,3},\d{1,3},\d{1,3}\)$/);
	});
	it('returns the neutral gray for null/empty/too-short (failure paths)', () => {
		const neutral = 'rgb(229,231,235)';
		expect(blurhashAverageColor(null)).toBe(neutral);
		expect(blurhashAverageColor(undefined)).toBe(neutral);
		expect(blurhashAverageColor('')).toBe(neutral);
		expect(blurhashAverageColor('abc')).toBe(neutral);
	});
	it('clamps channels to 0–255', () => {
		const c = blurhashAverageColor('LEHV6nWB2yk8pyo0adR*.7kCMdnj')!;
		const nums = c.match(/\d+/g)!.map(Number);
		expect(nums).toHaveLength(3);
		for (const n of nums) expect(n).toBeGreaterThanOrEqual(0), expect(n).toBeLessThanOrEqual(255);
	});
});
```

### `src/lib/shared/blurhash.ts`

```ts
/**
 * Cheap blurhash helpers for the client. We avoid a full per-tile canvas decode (expensive
 * at 50k tiles) and instead extract just the DC term — the average colour — which gives an
 * instant tinted placeholder behind the fading-in thumbnail. Pure / isomorphic.
 */

const DIGITS = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz#$%*+,-.:;=?@[]^_{|}~';

function decode83(str: string): number {
	let value = 0;
	for (let i = 0; i < str.length; i++) {
		const d = DIGITS.indexOf(str[i]);
		if (d === -1) return value;
		value = value * 83 + d;
	}
	return value;
}

/** Extract the average sRGB colour from a blurhash as a CSS `rgb(...)` string. */
export function blurhashAverageColor(hash: string | null | undefined): string {
	if (!hash || hash.length < 6) return 'rgb(229,231,235)'; // neutral gray-200
	const dc = decode83(hash.slice(2, 6));
	const r = (dc >> 16) & 255;
	const g = (dc >> 8) & 255;
	const b = dc & 255;
	return `rgb(${r},${g},${b})`;
}
```

### `src/lib/shared/config-schema.ts`

```ts
/**
 * Zod schema + inferred types for `lgallery.config.json`. Isomorphic (zod only, no
 * node deps) so the same validator runs on startup, on `PUT /api/config`, and could be
 * reused client-side. File IO + canonical hashing live in the server configService.
 * See docs/03-CONFIG.md.
 */
import { z } from 'zod';

const extensions = (def: string[]) =>
	z
		.array(z.string())
		.default(def)
		.transform((arr) => [...new Set(arr.map((e) => e.toLowerCase().replace(/^\./, '')))]);

export const rootSchema = z.object({
	path: z.string().min(1),
	label: z.string().default(''),
	enabled: z.boolean().default(true)
});

export const configSchema = z.object({
	roots: z.array(rootSchema).min(1, 'at least one root folder is required'),

	include: z.array(z.string()).default(['**/*']),
	exclude: z
		.array(z.string())
		.default(['**/.*', '**/@eaDir/**', '**/#recycle/**', '**/Thumbs.db']),
	imageExtensions: extensions([
		'jpg', 'jpeg', 'png', 'gif', 'webp', 'avif', 'bmp', 'tiff', 'tif',
		'heic', 'heif', 'cr2', 'cr3', 'nef', 'arw', 'dng', 'raf', 'orf', 'rw2'
	]),
	videoExtensions: extensions([
		'mp4', 'mov', 'm4v', 'webm', 'mkv', 'avi', 'wmv', 'mts', 'm2ts', '3gp'
	]),

	scan: z
		.object({
			onStartup: z.boolean().default(true),
			rescanOnReload: z.boolean().default(true),
			watch: z.boolean().default(false),
			concurrency: z.number().int().min(0).default(0),
			// Thumbnailing runs in a worker_threads pool by default (all cores; blurhash + DB off the
			// hot path). workerCount 0 = derive from `concurrency` or (cores-1). Set useWorkers:false to
			// force the in-process path (also the automatic fallback if workers can't be spawned).
			useWorkers: z.boolean().default(true),
			workerCount: z.number().int().min(0).default(0),
			// Bounded retries for failed metadata/thumbnail rows (transient errors self-heal w/ backoff).
			maxAttempts: z.number().int().min(1).default(3),
			removeMissing: z.boolean().default(true),
			followSymlinks: z.boolean().default(false)
		})
		.default({}),

	thumbnails: z
		.object({
			dir: z.string().default('data/thumbnails'),
			format: z.literal('webp').default('webp'),
			grid: z
				.object({ longEdge: z.number().int().positive().default(320), quality: z.number().int().min(1).max(100).default(70) })
				.default({}),
			preview: z
				.object({ longEdge: z.number().int().positive().default(1600), quality: z.number().int().min(1).max(100).default(80) })
				.default({}),
			// When false (default), the 1600px preview is generated lazily on first lightbox open
			// instead of during the backfill — roughly halves the pixels processed per photo at scan
			// time, so a 200k library reaches a full grid much sooner.
			eagerPreview: z.boolean().default(false),
			videoFrameAtPercent: z.number().min(0).max(100).default(10),
			videoStoryboardFrames: z.number().int().min(0).default(5)
		})
		.default({}),

	trash: z
		.object({
			dir: z.string().default('data/trash'),
			perRoot: z.boolean().default(false),
			autoPurgeDays: z.number().int().min(0).default(30)
		})
		.default({}),

	server: z
		.object({
			host: z
				.string()
				.regex(/^(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}|localhost)$/, 'host must be an IPv4 address or localhost')
				.default('127.0.0.1'),
			port: z.number().int().min(1).max(65535).default(4173),
			password: z.string().nullable().default(null),
			passwordHash: z.string().nullable().default(null),
			sessionTtlHours: z.number().int().positive().default(168)
		})
		.default({}),

	map: z
		.object({
			enabled: z.boolean().default(true),
			tileUrl: z.string().default('https://tile.openstreetmap.org/{z}/{x}/{y}.png'),
			attribution: z.string().default('© OpenStreetMap contributors'),
			reverseGeocode: z.boolean().default(false)
		})
		.default({}),

	// Places: reverse-geocode geotagged photos into location names. OFF by default. `offline` uses a
	// small bundled city dataset (no network). `nominatim` is accurate but makes a rate-limited
	// network request per location to OpenStreetMap's service — the only new outbound call, opt-in.
	geocode: z
		.object({
			enabled: z.boolean().default(false),
			provider: z.enum(['offline', 'nominatim']).default('offline'),
			/** Contact email — OSM's Nominatim usage policy asks for one in the User-Agent. */
			email: z.string().default('')
		})
		.default({}),

	ai: z
		.object({
			semanticSearch: z.boolean().default(false),
			faceGrouping: z.boolean().default(false),
			modelsDir: z.string().default('data/models'),
			modelSource: z.enum(['huggingface', 'local']).default('huggingface'),
			device: z.enum(['cpu', 'auto']).default('cpu')
		})
		.default({}),

	ui: z
		.object({
			theme: z.enum(['light', 'dark', 'system']).default('system'),
			gridDensity: z.enum(['compact', 'comfortable', 'spacious']).default('comfortable'),
			startView: z.enum(['timeline', 'folders', 'albums']).default('timeline')
		})
		.default({}),

	logging: z
		.object({
			level: z.enum(['debug', 'info', 'warn', 'error']).default('info'),
			file: z.string().default('data/lgallery.log'),
			maxSizeMb: z.number().positive().default(10),
			maxFiles: z.number().int().positive().default(5)
		})
		.default({})
});

export type LGalleryConfig = z.infer<typeof configSchema>;
export type RootConfig = z.infer<typeof rootSchema>;

/** The minimal object that, when parsed, yields a fully-defaulted config. */
export const MINIMAL_CONFIG_HINT = { roots: [{ path: 'D:/Photos', label: 'Main', enabled: true }] };
```

### `src/lib/shared/edits.test.ts`

```ts
import { describe, it, expect } from 'vitest';
import { DEFAULT_EDITS, normalizeEdits, isEdited, cssFilterFor } from './edits';

describe('edit ops model', () => {
	it('isEdited is false for defaults, true for any deviation', () => {
		expect(isEdited(DEFAULT_EDITS)).toBe(false);
		expect(isEdited({ ...DEFAULT_EDITS, rotate: 90 })).toBe(true);
		expect(isEdited({ ...DEFAULT_EDITS, filter: 'mono' })).toBe(true);
		expect(isEdited({ ...DEFAULT_EDITS, brightness: 1.2 })).toBe(true);
	});

	it('normalizeEdits clamps ranges and snaps rotation to 90s', () => {
		const o = normalizeEdits({ rotate: 100, brightness: 9, contrast: -3, saturation: 5, vibrance: 4, warmth: -9, filter: 'bogus' as never });
		expect(o.rotate).toBe(90);
		expect(o.brightness).toBeLessThanOrEqual(2);
		expect(o.contrast).toBeGreaterThanOrEqual(0.2);
		expect(o.saturation).toBeLessThanOrEqual(2);
		expect(o.vibrance).toBe(1);
		expect(o.warmth).toBe(-1);
		expect(o.filter).toBe('none'); // unknown filter rejected
	});

	it('normalizeEdits drops a full-frame crop (same as no crop)', () => {
		expect(normalizeEdits({ crop: { x: 0, y: 0, w: 1, h: 1 } }).crop).toBeNull();
		const c = normalizeEdits({ crop: { x: 0.1, y: 0.2, w: 0.5, h: 0.5 } }).crop;
		expect(c).toEqual({ x: 0.1, y: 0.2, w: 0.5, h: 0.5 });
	});

	it('normalizeEdits clamps a crop that would overflow the frame', () => {
		const c = normalizeEdits({ crop: { x: 0.8, y: 0.8, w: 0.9, h: 0.9 } }).crop!;
		expect(c.x + c.w).toBeLessThanOrEqual(1.0001);
		expect(c.y + c.h).toBeLessThanOrEqual(1.0001);
	});

	it('cssFilterFor produces a CSS filter string reflecting adjustments', () => {
		expect(cssFilterFor(DEFAULT_EDITS)).toContain('brightness');
		expect(cssFilterFor({ ...DEFAULT_EDITS, filter: 'mono' })).toContain('grayscale');
		expect(cssFilterFor({ ...DEFAULT_EDITS, filter: 'sepia' })).toContain('sepia');
	});
});
```

### `src/lib/shared/edits.ts`

```ts
/**
 * Non-destructive edit operations — isomorphic (no node deps) so the client can render a live CSS
 * preview while the server applies the same intent with sharp. Edits are stored as JSON on the row
 * and applied to the ORIGINAL at render time; the source file is never modified.
 */

export interface CropRect {
	/** All normalized 0..1 against the rotated image. */
	x: number;
	y: number;
	w: number;
	h: number;
}

export interface EditOps {
	/** Clockwise rotation in degrees: 0 | 90 | 180 | 270. */
	rotate: number;
	flipH: boolean;
	flipV: boolean;
	crop: CropRect | null;
	/** Multipliers around 1.0 (none). */
	brightness: number;
	contrast: number;
	saturation: number;
	/** -1..1, 0 = none. */
	vibrance: number;
	/** -1..1 (cool → warm), 0 = none. */
	warmth: number;
	/** Preset id; 'none' applies only the sliders above. */
	filter: FilterId;
}

export type FilterId = 'none' | 'auto' | 'vivid' | 'warm' | 'cool' | 'fade' | 'mono' | 'sepia' | 'noir';

export const FILTERS: FilterId[] = ['none', 'auto', 'vivid', 'warm', 'cool', 'fade', 'mono', 'sepia', 'noir'];

export const DEFAULT_EDITS: EditOps = {
	rotate: 0,
	flipH: false,
	flipV: false,
	crop: null,
	brightness: 1,
	contrast: 1,
	saturation: 1,
	vibrance: 0,
	warmth: 0,
	filter: 'none'
};

/** Coerce arbitrary input into a valid, clamped EditOps (used on the server before persisting). */
export function normalizeEdits(input: Partial<EditOps> | null | undefined): EditOps {
	const o = { ...DEFAULT_EDITS, ...(input ?? {}) };
	const clamp = (v: number, lo: number, hi: number, d: number) =>
		Number.isFinite(v) ? Math.min(hi, Math.max(lo, v)) : d;
	const rot = ((Math.round((o.rotate ?? 0) / 90) * 90) % 360 + 360) % 360;
	let crop: CropRect | null = null;
	if (o.crop && [o.crop.x, o.crop.y, o.crop.w, o.crop.h].every((n) => Number.isFinite(n))) {
		const x = clamp(o.crop.x, 0, 1, 0);
		const y = clamp(o.crop.y, 0, 1, 0);
		crop = { x, y, w: clamp(o.crop.w, 0.01, 1 - x, 1 - x), h: clamp(o.crop.h, 0.01, 1 - y, 1 - y) };
		// A full-frame crop is the same as no crop.
		if (crop.x === 0 && crop.y === 0 && crop.w >= 0.999 && crop.h >= 0.999) crop = null;
	}
	return {
		rotate: rot,
		flipH: !!o.flipH,
		flipV: !!o.flipV,
		crop,
		brightness: clamp(o.brightness, 0.2, 2, 1),
		contrast: clamp(o.contrast, 0.2, 2, 1),
		saturation: clamp(o.saturation, 0, 2, 1),
		vibrance: clamp(o.vibrance, -1, 1, 0),
		warmth: clamp(o.warmth, -1, 1, 0),
		filter: FILTERS.includes(o.filter as FilterId) ? (o.filter as FilterId) : 'none'
	};
}

/** True if the ops deviate from an unedited image. */
export function isEdited(o: EditOps): boolean {
	return (
		o.rotate !== 0 ||
		o.flipH ||
		o.flipV ||
		o.crop != null ||
		o.brightness !== 1 ||
		o.contrast !== 1 ||
		o.saturation !== 1 ||
		o.vibrance !== 0 ||
		o.warmth !== 0 ||
		o.filter !== 'none'
	);
}

/**
 * A CSS `filter` string approximating the colour ops, for the client's live preview. Geometry
 * (rotate/flip/crop) is handled separately by the editor's transform/overlay. This only needs to
 * *look* close; the server render via sharp is the source of truth on save.
 */
export function cssFilterFor(o: EditOps): string {
	const parts: string[] = [];
	// Filter presets fold into approximate CSS.
	let brightness = o.brightness;
	let contrast = o.contrast;
	let saturate = o.saturation * (1 + o.vibrance * 0.5);
	let sepia = 0;
	let grayscale = 0;
	let hueRotate = 0;
	switch (o.filter) {
		case 'vivid':
			saturate *= 1.3;
			contrast *= 1.08;
			break;
		case 'warm':
			sepia = 0.25;
			saturate *= 1.05;
			break;
		case 'cool':
			hueRotate = -12;
			saturate *= 1.02;
			break;
		case 'fade':
			contrast *= 0.85;
			brightness *= 1.05;
			saturate *= 0.85;
			break;
		case 'mono':
			grayscale = 1;
			break;
		case 'sepia':
			sepia = 0.6;
			break;
		case 'noir':
			grayscale = 1;
			contrast *= 1.2;
			break;
		case 'auto':
			contrast *= 1.05;
			break;
	}
	// Warmth: nudge hue/sepia warm (+) or cool (-).
	if (o.warmth > 0) sepia = Math.min(1, sepia + o.warmth * 0.3);
	else if (o.warmth < 0) hueRotate += o.warmth * 12;

	parts.push(`brightness(${brightness.toFixed(3)})`);
	parts.push(`contrast(${contrast.toFixed(3)})`);
	parts.push(`saturate(${saturate.toFixed(3)})`);
	if (grayscale) parts.push(`grayscale(${grayscale})`);
	if (sepia) parts.push(`sepia(${sepia.toFixed(3)})`);
	if (hueRotate) parts.push(`hue-rotate(${hueRotate.toFixed(1)}deg)`);
	return parts.join(' ');
}
```

### `src/lib/shared/format.test.ts`

```ts
import { describe, it, expect } from 'vitest';
import {
	wallClockToMs,
	localDayFromMs,
	monthKeyFromDay,
	dayHeaderLabel,
	monthHeaderLabel,
	floatingDateLabel,
	formatBytes,
	formatDuration,
	formatDateTime
} from './format';

describe('date policy', () => {
	it('wall-clock round-trips to the same local day regardless of runtime TZ', () => {
		const ms = wallClockToMs(2026, 6, 16, 23, 59, 0);
		expect(localDayFromMs(ms)).toBe('2026-06-16');
	});
	it('midnight stays on its own day', () => {
		const ms = wallClockToMs(2024, 1, 1, 0, 0, 0);
		expect(localDayFromMs(ms)).toBe('2024-01-01');
	});
	it('derives the month key', () => {
		expect(monthKeyFromDay('2026-06-16')).toBe('2026-06');
	});
});

describe('labels', () => {
	it('formats a day header', () => {
		expect(dayHeaderLabel('2026-06-16')).toBe('Tuesday, June 16, 2026');
	});
	it('formats a month header', () => {
		expect(monthHeaderLabel('2026-06')).toBe('June 2026');
	});
	it('formats a short floating label', () => {
		expect(floatingDateLabel('2026-06-16')).toBe('Jun 2026');
	});
});

describe('formatBytes', () => {
	it('handles bytes/KB/MB/GB', () => {
		expect(formatBytes(512)).toBe('512 B');
		expect(formatBytes(2048)).toBe('2.0 KB');
		expect(formatBytes(5 * 1024 * 1024)).toBe('5.0 MB');
		expect(formatBytes(3 * 1024 * 1024 * 1024)).toBe('3.0 GB');
	});
});

describe('formatDuration', () => {
	it('formats m:ss and h:mm:ss', () => {
		expect(formatDuration(65000)).toBe('1:05');
		expect(formatDuration(3661000)).toBe('1:01:01');
		expect(formatDuration(0)).toBe('');
	});
});

describe('formatDateTime', () => {
	it('renders the wall-clock instant', () => {
		const ms = wallClockToMs(2026, 6, 16, 14, 5, 0);
		expect(formatDateTime(ms)).toBe('June 16, 2026 · 2:05 PM');
	});
});
```

### `src/lib/shared/format.ts`

```ts
/**
 * Pure formatting + date-policy helpers. Isomorphic (no `node:` imports).
 *
 * Date policy (see docs/05-PERFORMANCE.md): `taken_ms` stores the capture instant
 * as wall-clock-interpreted-as-UTC, so the "local day" is simply the UTC calendar
 * day of `taken_ms`. That keeps day/month grouping free of any runtime timezone math.
 */

const MONTHS = [
	'January',
	'February',
	'March',
	'April',
	'May',
	'June',
	'July',
	'August',
	'September',
	'October',
	'November',
	'December'
];
const WEEKDAYS = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];

function pad2(n: number): string {
	return n < 10 ? '0' + n : String(n);
}

/** Build a UTC-ms timestamp from wall-clock parts (the date-policy storage form). */
export function wallClockToMs(
	year: number,
	month1to12: number,
	day: number,
	hour = 0,
	min = 0,
	sec = 0,
	ms = 0
): number {
	return Date.UTC(year, month1to12 - 1, day, hour, min, sec, ms);
}

/** 'YYYY-MM-DD' for the UTC calendar day of `ms`. */
export function localDayFromMs(ms: number): string {
	const d = new Date(ms);
	return `${d.getUTCFullYear()}-${pad2(d.getUTCMonth() + 1)}-${pad2(d.getUTCDate())}`;
}

/** 'YYYY-MM' month key for grouping/headers. Accepts a day string or ms. */
export function monthKeyFromDay(day: string): string {
	return day.slice(0, 7);
}

/** Human header for a day key, e.g. "Monday, June 16, 2026". */
export function dayHeaderLabel(day: string): string {
	const [y, m, d] = day.split('-').map(Number);
	const date = new Date(Date.UTC(y, m - 1, d));
	return `${WEEKDAYS[date.getUTCDay()]}, ${MONTHS[m - 1]} ${d}, ${y}`;
}

/** Human header for a month key 'YYYY-MM', e.g. "June 2026". */
export function monthHeaderLabel(monthKey: string): string {
	const [y, m] = monthKey.split('-').map(Number);
	return `${MONTHS[m - 1]} ${y}`;
}

/** Short label for the floating scroll indicator, e.g. "Jun 2026". */
export function floatingDateLabel(day: string): string {
	const [y, m] = day.split('-').map(Number);
	return `${MONTHS[m - 1].slice(0, 3)} ${y}`;
}

export function formatBytes(bytes: number): string {
	if (!Number.isFinite(bytes) || bytes < 0) return '—';
	if (bytes < 1024) return `${bytes} B`;
	const units = ['KB', 'MB', 'GB', 'TB'];
	let v = bytes / 1024;
	let i = 0;
	while (v >= 1024 && i < units.length - 1) {
		v /= 1024;
		i++;
	}
	return `${v < 10 ? v.toFixed(1) : Math.round(v)} ${units[i]}`;
}

/** ms → "m:ss" or "h:mm:ss". */
export function formatDuration(ms: number | null | undefined): string {
	if (!ms || ms <= 0) return '';
	const total = Math.round(ms / 1000);
	const h = Math.floor(total / 3600);
	const m = Math.floor((total % 3600) / 60);
	const s = total % 60;
	if (h > 0) return `${h}:${pad2(m)}:${pad2(s)}`;
	return `${m}:${pad2(s)}`;
}

/** Full date+time for the info panel, in the capture's wall-clock terms (UTC components). */
export function formatDateTime(ms: number | null | undefined): string {
	if (ms == null) return '—';
	const d = new Date(ms);
	const h = d.getUTCHours();
	const ampm = h >= 12 ? 'PM' : 'AM';
	const h12 = h % 12 === 0 ? 12 : h % 12;
	return `${MONTHS[d.getUTCMonth()]} ${d.getUTCDate()}, ${d.getUTCFullYear()} · ${h12}:${pad2(d.getUTCMinutes())} ${ampm}`;
}
```

### `src/lib/shared/layout.test.ts`

```ts
import { describe, it, expect } from 'vitest';
import {
	computeLayout,
	findRowRange,
	estimateHeightFromBuckets,
	monthMarksFromBuckets,
	type LayoutInput,
	type LayoutOptions,
	type LayoutRow
} from './layout';

const OPTS: LayoutOptions = {
	containerWidth: 1000,
	targetRowHeight: 200,
	gap: 0,
	dayHeaderHeight: 40,
	monthHeaderHeight: 64,
	sectionGap: 0
};

function squares(day: string, count: number): LayoutInput[] {
	return Array.from({ length: count }, (_, i) => ({
		id: i + 1,
		width: 100,
		height: 100,
		takenLocalDay: day
	}));
}

describe('computeLayout — justified rows', () => {
	it('fills a row to the container width then justifies to that width', () => {
		const layout = computeLayout(squares('2026-06-16', 5), OPTS);
		const tileRows = layout.rows.filter((r) => r.type === 'tiles');
		expect(tileRows).toHaveLength(1);
		const row = tileRows[0];
		expect(row.tiles).toHaveLength(5);
		expect(row.h).toBe(200); // 5 squares at 1000px → exactly target
		const last = row.tiles![4];
		expect(last.x + last.w).toBe(1000); // fills width
	});

	it('scales row height below target when wide items overflow', () => {
		const items: LayoutInput[] = Array.from({ length: 3 }, (_, i) => ({
			id: i + 1,
			width: 200,
			height: 100, // aspect 2
			takenLocalDay: '2026-06-16'
		}));
		const row = computeLayout(items, OPTS).rows.find((r) => r.type === 'tiles')!;
		expect(row.tiles).toHaveLength(3);
		expect(row.h).toBeLessThan(200);
		expect(row.tiles![2].x + row.tiles![2].w).toBeCloseTo(1000, 0);
	});

	it('keeps a trailing partial row at the target height (no over-stretch)', () => {
		const row = computeLayout(squares('2026-06-16', 2), OPTS).rows.find((r) => r.type === 'tiles')!;
		expect(row.h).toBe(200);
		expect(row.tiles![1].x + row.tiles![1].w).toBe(400); // left-aligned, not stretched
	});

	it('respects the gap between tiles', () => {
		const layout = computeLayout(squares('2026-06-16', 5), { ...OPTS, gap: 10 });
		const row = layout.rows.find((r) => r.type === 'tiles')!;
		// 5 tiles, 4 gaps of 10 → tile area 960 → h = 960/5 = 192
		expect(row.h).toBe(192);
	});
});

describe('computeLayout — headers', () => {
	it('inserts a month header on month change and day headers within a month', () => {
		const items = [
			...squares('2026-06-16', 1),
			...squares('2026-06-15', 1),
			...squares('2026-05-30', 1)
		];
		// give them unique ids
		items.forEach((it, i) => (it.id = i + 1));
		const headers = computeLayout(items, OPTS).rows.filter((r) => r.type === 'header');
		expect(headers.map((h) => h.day)).toEqual(['2026-06-16', '2026-06-15', '2026-05-30']);
		expect(headers.map((h) => h.isMonthStart)).toEqual([true, false, true]);
	});

	it('is deterministic for identical input', () => {
		const a = computeLayout(squares('2026-06-16', 7), OPTS);
		const b = computeLayout(squares('2026-06-16', 7), OPTS);
		expect(a).toEqual(b);
	});
});

describe('findRowRange', () => {
	const rows: LayoutRow[] = [
		{ type: 'header', y: 0, h: 40 },
		{ type: 'tiles', y: 40, h: 200 },
		{ type: 'tiles', y: 240, h: 200 },
		{ type: 'tiles', y: 440, h: 200 },
		{ type: 'tiles', y: 640, h: 200 }
	];
	it('returns rows intersecting the viewport', () => {
		const [s, e] = findRowRange(rows, 250, 500);
		// viewport [250,500) intersects rows at y=240 (ends 440) and y=440 (ends 640)
		expect(rows.slice(s, e).map((r) => r.y)).toEqual([240, 440]);
	});
	it('includes a row exactly at the top edge', () => {
		const [s] = findRowRange(rows, 240, 300);
		expect(rows[s].y).toBe(240);
	});
	it('handles a viewport past the end', () => {
		const [s, e] = findRowRange(rows, 5000, 6000);
		expect(s).toBe(e); // empty window
	});
});

describe('estimateHeightFromBuckets', () => {
	it('produces a positive estimate that grows with item count', () => {
		const small = estimateHeightFromBuckets([{ day: '2026-06-16', n: 10 }], OPTS, 5);
		const big = estimateHeightFromBuckets([{ day: '2026-06-16', n: 100 }], OPTS, 5);
		expect(small).toBeGreaterThan(0);
		expect(big).toBeGreaterThan(small);
	});
});

describe('monthMarksFromBuckets (date-jump scrubber)', () => {
	const buckets = [
		{ day: '2026-06-16', n: 5 },
		{ day: '2026-06-15', n: 5 },
		{ day: '2026-05-30', n: 5 },
		{ day: '2025-12-31', n: 5 }
	];
	it('emits one mark per month boundary, in bucket order', () => {
		const marks = monthMarksFromBuckets(buckets, OPTS, 5);
		expect(marks.map((m) => m.key)).toEqual(['2026-06', '2026-05', '2025-12']);
	});
	it('marks have strictly increasing y offsets aligned to the height estimate', () => {
		const marks = monthMarksFromBuckets(buckets, OPTS, 5);
		expect(marks[0].y).toBe(0);
		for (let i = 1; i < marks.length; i++) expect(marks[i].y).toBeGreaterThan(marks[i - 1].y);
		// the last month's offset stays within the total estimated height
		expect(marks.at(-1)!.y).toBeLessThan(estimateHeightFromBuckets(buckets, OPTS, 5));
	});
});
```

### `src/lib/shared/layout.ts`

```ts
/**
 * Pure justified-row layout math for the timeline grid. No DOM, no node deps — unit-tested
 * and reused in SSR. The component (TimelineGrid.svelte) consumes `rows` + `totalHeight` and
 * windows them with `findRowRange` (binary search). See docs/05-PERFORMANCE.md.
 *
 * Greedy justified algorithm: accumulate items at the target row height until their natural
 * width exceeds the container, then scale the row so it fills the width exactly. Day headers
 * (and larger month headers on month change) are inserted as their own rows.
 */
import { monthKeyFromDay } from './format';

export interface LayoutInput {
	id: number;
	width: number | null;
	height: number | null;
	takenLocalDay: string;
}

export interface LayoutTile {
	id: number;
	/** Index into the original items array (stable key / paging). */
	index: number;
	x: number;
	y: number;
	w: number;
	h: number;
}

export interface LayoutRow {
	type: 'header' | 'tiles';
	y: number;
	h: number;
	// header rows:
	day?: string;
	isMonthStart?: boolean;
	// tile rows:
	tiles?: LayoutTile[];
}

export interface Layout {
	rows: LayoutRow[];
	totalHeight: number;
	width: number;
}

export interface LayoutOptions {
	containerWidth: number;
	targetRowHeight: number;
	gap: number;
	dayHeaderHeight: number;
	monthHeaderHeight: number;
	/** Extra vertical space after each day's tiles. */
	sectionGap: number;
}

export const DEFAULT_ASPECT = 1; // square placeholder before real dimensions arrive

export function densityOptions(
	density: 'compact' | 'comfortable' | 'spacious',
	containerWidth: number
): LayoutOptions {
	const target = density === 'compact' ? 140 : density === 'spacious' ? 280 : 200;
	const gap = density === 'compact' ? 3 : density === 'spacious' ? 6 : 4;
	return {
		containerWidth,
		targetRowHeight: target,
		gap,
		dayHeaderHeight: 40,
		monthHeaderHeight: 64,
		sectionGap: 16
	};
}

function aspectOf(it: LayoutInput): number {
	if (it.width && it.height && it.width > 0 && it.height > 0) {
		const a = it.width / it.height;
		// clamp extreme panoramas so one tile can't dominate a row
		return Math.max(0.3, Math.min(a, 4));
	}
	return DEFAULT_ASPECT;
}

export function computeLayout(items: LayoutInput[], opts: LayoutOptions): Layout {
	const rows: LayoutRow[] = [];
	const { containerWidth: W, targetRowHeight: target, gap } = opts;
	const n = items.length;
	let y = 0;
	let i = 0;
	let lastMonth = '';

	while (i < n) {
		const day = items[i].takenLocalDay || '';
		const month = monthKeyFromDay(day);
		const isMonthStart = month !== lastMonth;
		lastMonth = month;

		const headerH = isMonthStart ? opts.monthHeaderHeight : opts.dayHeaderHeight;
		rows.push({ type: 'header', y, h: headerH, day, isMonthStart });
		y += headerH;

		// Find the [i, dayEnd) span belonging to this day.
		let dayEnd = i;
		while (dayEnd < n && (items[dayEnd].takenLocalDay || '') === day) dayEnd++;

		let k = i;
		while (k < dayEnd) {
			// Accumulate items until the natural (target-height) width fills the container.
			let sumAspect = 0;
			let j = k;
			let overflow = false;
			while (j < dayEnd) {
				sumAspect += aspectOf(items[j]);
				j++;
				const count = j - k;
				const naturalWidth = sumAspect * target + gap * (count - 1);
				if (naturalWidth >= W) {
					overflow = true;
					break;
				}
			}
			const count = j - k;
			// Justify to width on overflow; otherwise (trailing partial row) keep target height.
			const h = overflow ? (W - gap * (count - 1)) / sumAspect : target;

			const tiles: LayoutTile[] = [];
			let x = 0;
			for (let t = k; t < j; t++) {
				const w = aspectOf(items[t]) * h;
				tiles.push({
					id: items[t].id,
					index: t,
					x: Math.round(x),
					y,
					w: Math.round(w),
					h: Math.round(h)
				});
				x += w + gap;
			}
			rows.push({ type: 'tiles', y, h: Math.round(h), tiles });
			y += Math.round(h) + gap;
			k = j;
		}
		y += opts.sectionGap;
		i = dayEnd;
	}

	return { rows, totalHeight: Math.ceil(y), width: W };
}

/**
 * Binary-search the [start, end) row indices intersecting the vertical viewport [top, bottom).
 * Rows are sorted by `y` and non-overlapping, so this is O(log n).
 */
export function findRowRange(rows: LayoutRow[], top: number, bottom: number): [number, number] {
	// first row whose bottom edge is below `top`
	let lo = 0;
	let hi = rows.length;
	while (lo < hi) {
		const mid = (lo + hi) >> 1;
		if (rows[mid].y + rows[mid].h <= top) lo = mid + 1;
		else hi = mid;
	}
	const start = lo;
	// first row whose top edge is at/below `bottom`
	let lo2 = start;
	let hi2 = rows.length;
	while (lo2 < hi2) {
		const mid = (lo2 + hi2) >> 1;
		if (rows[mid].y < bottom) lo2 = mid + 1;
		else hi2 = mid;
	}
	return [start, lo2];
}

/**
 * Estimate total content height from day-count buckets before per-item dimensions exist, so
 * the native scrollbar proportion is sane up front. Assumes ~`itemsPerRow` square-ish tiles.
 */
export function estimateHeightFromBuckets(
	buckets: { day: string; n: number }[],
	opts: LayoutOptions,
	itemsPerRow: number
): number {
	let y = 0;
	let lastMonth = '';
	for (const b of buckets) {
		const month = monthKeyFromDay(b.day);
		y += month !== lastMonth ? opts.monthHeaderHeight : opts.dayHeaderHeight;
		lastMonth = month;
		const rowsForDay = Math.max(1, Math.ceil(b.n / Math.max(1, itemsPerRow)));
		y += rowsForDay * (opts.targetRowHeight + opts.gap) + opts.sectionGap;
	}
	return Math.ceil(y);
}

export interface MonthMark {
	/** 'YYYY-MM' */
	key: string;
	/** Estimated content-y of this month's header (same math as estimateHeightFromBuckets). */
	y: number;
}

/**
 * Cumulative content-y of each month boundary, for the date-jump scrubber. Uses the SAME estimate
 * as estimateHeightFromBuckets / computeLayout so a tick maps to the right scroll offset. Buckets
 * are newest-first, so marks run top (newest) → bottom (oldest).
 */
export function monthMarksFromBuckets(
	buckets: { day: string; n: number }[],
	opts: LayoutOptions,
	itemsPerRow: number
): MonthMark[] {
	const marks: MonthMark[] = [];
	let y = 0;
	let lastMonth = '';
	for (const b of buckets) {
		const month = monthKeyFromDay(b.day);
		if (month !== lastMonth) marks.push({ key: month, y });
		y += month !== lastMonth ? opts.monthHeaderHeight : opts.dayHeaderHeight;
		lastMonth = month;
		const rowsForDay = Math.max(1, Math.ceil(b.n / Math.max(1, itemsPerRow)));
		y += rowsForDay * (opts.targetRowHeight + opts.gap) + opts.sectionGap;
	}
	return marks;
}
```

### `src/lib/shared/types.ts`

```ts
/**
 * Pure, isomorphic domain types shared by server and client.
 * No `node:` imports may appear in this file (it is bundled into the client).
 */

export type MediaType = 'photo' | 'video';
export type TakenSource = 'exif' | 'mtime';
export type GridDensity = 'compact' | 'comfortable' | 'spacious';
export type Theme = 'light' | 'dark' | 'system';

/** Status codes shared by `meta_status` / `thumb_status` columns. */
export const Status = {
	None: 0,
	InProgress: 1,
	Ready: 2,
	Fail: 3
} as const;
export type StatusCode = (typeof Status)[keyof typeof Status];

/**
 * Row shape returned by the hot timeline keyset query. Deliberately lightweight —
 * only what the grid needs to lay out and paint a tile.
 */
export interface TimelineItem {
	id: number;
	type: MediaType;
	width: number | null;
	height: number | null;
	takenMs: number;
	takenLocalDay: string; // 'YYYY-MM-DD'
	durationMs: number | null;
	blurhash: string | null;
	isFavorite: boolean;
	livePartnerId: number | null;
	thumbStatus: StatusCode;
}

export interface Cursor {
	curMs: number;
	curId: number;
}

export interface TimelinePage {
	items: TimelineItem[];
	nextCursor: Cursor | null;
}

export interface DayBucket {
	day: string; // 'YYYY-MM-DD'
	n: number;
}

export interface MediaDetail extends TimelineItem {
	path: string; // full path is shown in the info panel (single-user local app)
	relPath: string;
	dir: string;
	filename: string;
	ext: string;
	sizeBytes: number;
	mtimeMs: number;
	takenSource: TakenSource | null;
	cameraMake: string | null;
	cameraModel: string | null;
	lens: string | null;
	codec: string | null;
	orientation: number | null;
	hasGps: boolean;
	gpsLat: number | null;
	gpsLon: number | null;
	isArchived: boolean;
	isTrashed: boolean;
	error: string | null;
	albums: { id: number; name: string }[];
	/** Free-text caption (searchable). */
	caption: string | null;
	/** 0 = unrated, 1-5 stars. */
	rating: number;
	/** Culling flag: 1 = pick, -1 = reject, 0 = none. */
	pick: number;
	tags: { id: number; name: string }[];
	/** Reverse-geocoded place (null unless geocoding is enabled + resolved). */
	placeName: string | null;
	placeLocality: string | null;
	placeCountry: string | null;
	/** Non-destructive edit operations, or null if the photo is unedited. */
	editOps: import('./edits').EditOps | null;
}

export interface Tag {
	id: number;
	name: string;
	count: number;
}

export interface PlaceGroup {
	locality: string;
	country: string | null;
	count: number;
	/** Representative media id for the place's cover thumbnail. */
	sampleId: number;
}

export type ScanStatus = 'idle' | 'running' | 'done' | 'error';

export interface ScanState {
	status: ScanStatus;
	scanId: number | null;
	filesSeen: number;
	added: number;
	updated: number;
	removed: number;
	metaPending: number;
	thumbsPending: number;
	/** Rolling thumbnails-completed-per-second over the last ~30s (0 when idle). */
	throughputPerSec: number;
	/** Estimated ms to drain the remaining thumbnail backlog, or null when unknown/idle. */
	etaMs: number | null;
	startedAt: number | null;
	finishedAt: number | null;
	error: string | null;
	currentRoot: string | null;
}

export interface Album {
	id: number;
	name: string;
	coverMediaId: number | null;
	count: number;
	createdAt: number;
	sortOrder: number;
}

export interface MapPoint {
	id: number;
	lat: number;
	lon: number;
}

export interface MapCluster {
	lat: number;
	lon: number;
	count: number;
	/** Representative media id for the cluster thumbnail. */
	sampleId: number;
}

export interface TrashItem {
	id: number;
	mediaId: number | null;
	originalPath: string;
	sizeBytes: number;
	trashedAt: number;
	filename: string;
}

export interface DuplicateGroup {
	hash: string;
	kind: 'exact' | 'near';
	items: TimelineItem[];
}

/** Standard JSON error envelope for all API endpoints. */
export interface ApiErrorBody {
	error: { code: string; message: string };
}

/** Per-id result for bulk mutations so partial failures are visible. */
export interface BulkResult {
	ok: number[];
	failed: { id: number; error: string }[];
}
```

### `src/routes/+layout.server.ts`

```ts
import type { LayoutServerLoad } from './$types';
import {
	clientConfig,
	reloadIfChanged,
	getConfig,
	getConfigHash
} from '$server/config/configService';
import { getDb } from '$server/db/index';
import { log } from '$server/log';

export const load: LayoutServerLoad = async () => {
	// Reload-time config check: if the source-hash changed, reconcile + enqueue a rescan.
	try {
		if (getConfig().scan.rescanOnReload) {
			const { changed } = reloadIfChanged();
			if (changed) {
				const db = getDb();
				db.prepare(
					`INSERT INTO app_state(key, value) VALUES('config_hash', ?)
					 ON CONFLICT(key) DO UPDATE SET value=excluded.value`
				).run(getConfigHash());
				const { requestRescan } = await import('$server/scan/scanner');
				requestRescan({ reason: 'config-changed' });
				log.info('Config changed on reload → incremental rescan enqueued.');
			}
		}
	} catch (e) {
		log.debug('reload rescan check failed', e);
	}

	return { config: clientConfig() };
};
```

### `src/routes/+layout.svelte`

```svelte
<script lang="ts">
	import '../app.css';
	import type { Snippet } from 'svelte';
	import { onMount } from 'svelte';
	import Sidebar from '$components/nav/Sidebar.svelte';
	import ScanChip from '$components/common/ScanChip.svelte';
	import CommandPalette from '$components/common/CommandPalette.svelte';
	import { scanStatus } from '$client/state/scanStatus.svelte';

	let { children }: { data: unknown; children: Snippet } = $props();

	onMount(() => {
		scanStatus.start();
		return () => scanStatus.stop();
	});
</script>

<svelte:head>
	<title>LGallery</title>
</svelte:head>

<div class="app">
	<Sidebar />
	<main class="content">
		{@render children()}
	</main>
</div>
<ScanChip />
<CommandPalette />

<style>
	.app {
		display: flex;
		height: 100vh;
		width: 100%;
		overflow: hidden;
	}
	.content {
		flex: 1;
		position: relative;
		height: 100vh;
		overflow: hidden;
		min-width: 0;
	}
</style>
```

### `src/routes/+page.server.ts`

```ts
import type { PageServerLoad } from './$types';
import { getDb } from '$server/db/index';
import { getTimelinePage, getBuckets, getTotalCount } from '$server/db/queries';
import { initialGridWidth } from '$server/http';

const PAGE = 200;

export const load: PageServerLoad = async ({ cookies }) => {
	const db = getDb();
	const initialPage = getTimelinePage(db, { limit: PAGE });
	const buckets = getBuckets(db);
	const total = getTotalCount(db);
	return { initialPage, buckets, total, initialWidth: initialGridWidth(cookies) };
};
```

### `src/routes/+page.svelte`

```svelte
<script lang="ts">
	import type { TimelinePage, DayBucket } from '$shared/types';
	import MediaGridView from '$components/grid/MediaGridView.svelte';
	import DensityToggle from '$components/common/DensityToggle.svelte';
	import PageHeader from '$components/common/PageHeader.svelte';
	import EmptyState from '$components/common/EmptyState.svelte';
	import { untrack } from 'svelte';
	import { gallery } from '$client/state/gallery.svelte';
	import { api } from '$client/api';
	import { ImageOff } from '@lucide/svelte';

	let {
		data
	}: { data: { initialPage: TimelinePage; buckets: DayBucket[]; total: number; initialWidth: number } } =
		$props();

	// Seed during render (incl. SSR) so the timeline grid is present in the first HTML — no
	// blank-then-pop. (Single-user local app: the shared gallery store seeded per render is fine.)
	untrack(() => {
		gallery.setSource((c) => api.timeline(c));
		gallery.seed(data.initialPage, data.total);
	});
</script>

<div class="page">
	<PageHeader title="Photos" count={gallery.total || null}>
		{#snippet actions()}<DensityToggle />{/snippet}
	</PageHeader>

	<div class="grid-wrap">
		{#if data.total === 0}
			<EmptyState
				icon={ImageOff}
				title="No media indexed yet"
				description="Point lgallery.config.json at your photo folders (or use Settings → Media folders), then reload — the background scan fills the timeline."
			/>
		{:else}
			<MediaGridView buckets={data.buckets} initialWidth={data.initialWidth} />
		{/if}
	</div>
</div>

<style>
	.page {
		display: flex;
		flex-direction: column;
		height: 100%;
	}
	.grid-wrap {
		flex: 1;
		min-height: 0;
		position: relative;
	}
</style>
```

### `src/routes/albums/[id]/+page.server.ts`

```ts
import type { PageServerLoad } from './$types';
import { error } from '@sveltejs/kit';
import { getDb } from '$server/db/index';
import { getAlbumPage } from '$server/db/queries';
import type { Album } from '$shared/types';

export const load: PageServerLoad = async ({ params }) => {
	const id = Number(params.id);
	if (!Number.isInteger(id) || id <= 0) throw error(400, 'Invalid album id');
	const db = getDb();
	const album = db
		.prepare(
			`SELECT id, name, cover_media_id AS coverMediaId, created_at AS createdAt, sort_order AS sortOrder,
			        (SELECT COUNT(*) FROM album_items WHERE album_id=albums.id) AS count
			 FROM albums WHERE id=?`
		)
		.get(id) as Album | undefined;
	if (!album) throw error(404, 'Album not found');
	const page = getAlbumPage(db, id, { limit: 200 });
	return { album, page, albumId: id };
};
```

### `src/routes/albums/[id]/+page.svelte`

```svelte
<script lang="ts">
	import { onMount } from 'svelte';
	import { goto, invalidateAll } from '$app/navigation';
	import type { Album, TimelinePage } from '$shared/types';
	import MediaGridView from '$components/grid/MediaGridView.svelte';
	import DensityToggle from '$components/common/DensityToggle.svelte';
	import PageHeader from '$components/common/PageHeader.svelte';
	import EmptyState from '$components/common/EmptyState.svelte';
	import { gallery } from '$client/state/gallery.svelte';
	import { api } from '$client/api';
	import { ChevronLeft, Pencil, Trash2 } from '@lucide/svelte';

	let { data }: { data: { album: Album; page: TimelinePage; albumId: number } } = $props();

	onMount(() => {
		gallery.setSource((c) => api.album(data.albumId, c).then((r) => r.page));
		gallery.seed(data.page, data.album.count);
	});

	async function renameAlbum() {
		const name = prompt('Rename album', data.album.name);
		if (!name || !name.trim()) return;
		await api.updateAlbum(data.albumId, { name: name.trim() });
		await invalidateAll();
	}
	async function deleteAlbum() {
		if (!confirm(`Delete album “${data.album.name}”? (Photos are not deleted.)`)) return;
		await api.deleteAlbum(data.albumId);
		goto('/albums');
	}
</script>

<div class="page">
	<PageHeader count={data.album.count}>
		{#snippet children()}
			<a class="back" href="/albums" aria-label="Back to albums"><ChevronLeft size={20} /></a>
			<h1>{data.album.name}</h1>
		{/snippet}
		{#snippet actions()}
			<button class="btn" onclick={renameAlbum} title="Rename"><Pencil size={16} /></button>
			<button class="btn btn-danger" onclick={deleteAlbum} title="Delete album"><Trash2 size={16} /></button>
			<DensityToggle />
		{/snippet}
	</PageHeader>
	<div class="grid-wrap">
		{#if data.album.count === 0}
			<EmptyState title="This album is empty" description="Select photos in the timeline and choose “Album”." />
		{:else}
			<MediaGridView />
		{/if}
	</div>
</div>

<style>
	.page {
		display: flex;
		flex-direction: column;
		height: 100%;
	}
	.back {
		color: inherit;
		display: flex;
	}
	h1 {
		font-size: 1.3rem;
		font-weight: 700;
	}
	.grid-wrap {
		flex: 1;
		min-height: 0;
		position: relative;
	}
</style>
```

### `src/routes/albums/+page.server.ts`

```ts
import type { PageServerLoad } from './$types';
import { getDb } from '$server/db/index';
import { getAlbums } from '$server/db/queries';
import type { Album } from '$shared/types';

export const load: PageServerLoad = async () => {
	return { albums: getAlbums(getDb()) as Album[] };
};
```

### `src/routes/albums/+page.svelte`

```svelte
<script lang="ts">
	import { invalidateAll } from '$app/navigation';
	import type { Album } from '$shared/types';
	import { api } from '$client/api';
	import PageHeader from '$components/common/PageHeader.svelte';
	import EmptyState from '$components/common/EmptyState.svelte';
	import { Plus, BookImage } from '@lucide/svelte';

	let { data }: { data: { albums: Album[] } } = $props();
	let newName = $state('');
	let creating = $state(false);

	async function create() {
		const name = newName.trim();
		if (!name || creating) return;
		creating = true;
		try {
			await api.createAlbum(name);
			newName = '';
			await invalidateAll();
		} finally {
			creating = false;
		}
	}
</script>

<div class="page">
	<PageHeader title="Albums" count={data.albums.length}>
		{#snippet actions()}
			<div class="new">
				<input class="lg-input" placeholder="New album…" bind:value={newName} onkeydown={(e) => e.key === 'Enter' && create()} />
				<button class="btn btn-primary" onclick={create} disabled={creating}><Plus size={16} /> Create</button>
			</div>
		{/snippet}
	</PageHeader>

	<div class="scroll">
		{#if data.albums.length === 0}
			<EmptyState icon={BookImage} title="No albums yet" description="Create one above, or select photos and choose “Album”." />
		{:else}
			<ul class="grid">
				{#each data.albums as a (a.id)}
					<li>
						<a href="/albums/{a.id}">
							<div class="cover">
								{#if a.coverMediaId}
									<img src="/api/media/{a.coverMediaId}/thumb?size=grid" alt="" loading="lazy" />
								{:else}
									<div class="ph"><BookImage size={28} /></div>
								{/if}
							</div>
							<div class="meta">
								<span class="name">{a.name}</span>
								<span class="count">{a.count} item{a.count === 1 ? '' : 's'}</span>
							</div>
						</a>
					</li>
				{/each}
			</ul>
		{/if}
	</div>
</div>

<style>
	.page {
		display: flex;
		flex-direction: column;
		height: 100%;
	}
	.new {
		display: flex;
		gap: 6px;
	}
	.scroll {
		flex: 1;
		overflow-y: auto;
		padding: 18px;
	}
	.grid {
		list-style: none;
		margin: 0;
		padding: 0;
		display: grid;
		grid-template-columns: repeat(auto-fill, minmax(180px, 1fr));
		gap: 16px;
	}
	.grid a {
		text-decoration: none;
		color: inherit;
		display: block;
	}
	.cover {
		aspect-ratio: 1;
		border-radius: var(--lg-r-lg);
		overflow: hidden;
		background: var(--lg-surface-2);
	}
	.cover img {
		width: 100%;
		height: 100%;
		object-fit: cover;
	}
	.ph {
		width: 100%;
		height: 100%;
		display: flex;
		align-items: center;
		justify-content: center;
		color: var(--lg-text-muted);
	}
	.meta {
		display: flex;
		flex-direction: column;
		padding: 8px 2px;
	}
	.name {
		font-weight: 600;
	}
	.count {
		font-size: 0.8rem;
		color: var(--lg-text-muted);
	}
</style>
```

### `src/routes/api/ai/index/+server.ts`

```ts
import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { getConfig } from '$server/config/configService';
import { requireMutation } from '$server/security';
import { apiError } from '$server/http';
import { startSemanticIndex, startFaceIndex, stopIndex } from '$server/ai/aiService';

export const POST: RequestHandler = async (event) => {
	const guard = requireMutation(event);
	if (guard) return guard;
	const body = (await event.request.json().catch(() => ({}))) as {
		action?: 'start' | 'stop';
		kind?: 'semantic' | 'faces';
	};
	const kind = body.kind === 'faces' ? 'faces' : 'semantic';
	const ai = getConfig().ai;

	if (body.action === 'stop') {
		stopIndex(kind);
		return json({ ok: true });
	}

	if (kind === 'semantic' && !ai.semanticSearch) {
		return apiError(400, 'AI_OFF', 'Enable semantic search in Settings first.');
	}
	if (kind === 'faces' && !ai.faceGrouping) {
		return apiError(400, 'AI_OFF', 'Enable face grouping in Settings first.');
	}

	if (kind === 'semantic') await startSemanticIndex();
	else await startFaceIndex();
	return json({ ok: true });
};
```

### `src/routes/api/ai/status/+server.ts`

```ts
import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { aiStatus } from '$server/ai/aiService';

export const GET: RequestHandler = () => json(aiStatus());
```

### `src/routes/api/albums/[id]/+server.ts`

```ts
import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { getDb } from '$server/db/index';
import { getAlbumPage } from '$server/db/queries';
import { requireMutation } from '$server/security';
import { apiError } from '$server/http';

function albumId(params: { id: string }): number | null {
	const id = Number(params.id);
	return Number.isInteger(id) && id > 0 ? id : null;
}

export const GET: RequestHandler = ({ params, url }) => {
	const id = albumId(params);
	if (id == null) return apiError(400, 'BAD_ID', 'Invalid album id.');
	const db = getDb();
	const album = db
		.prepare(
			`SELECT id, name, cover_media_id AS coverMediaId, created_at AS createdAt, sort_order AS sortOrder,
			        (SELECT COUNT(*) FROM album_items WHERE album_id=albums.id) AS count
			 FROM albums WHERE id=?`
		)
		.get(id);
	if (!album) return apiError(404, 'NOT_FOUND', 'Album not found.');
	const num = (k: string) => {
		const v = url.searchParams.get(k);
		return v == null || v === '' ? null : Number(v);
	};
	const page = getAlbumPage(db, id, { curMs: num('curMs'), curId: num('curId'), limit: num('limit') ?? 200 });
	return json({ album, page });
};

export const PATCH: RequestHandler = async (event) => {
	const guard = requireMutation(event);
	if (guard) return guard;
	const id = albumId(event.params);
	if (id == null) return apiError(400, 'BAD_ID', 'Invalid album id.');
	const body = (await event.request.json().catch(() => ({}))) as { name?: string; coverMediaId?: number };
	const db = getDb();
	if (typeof body.name === 'string' && body.name.trim()) {
		db.prepare(`UPDATE albums SET name=? WHERE id=?`).run(body.name.trim(), id);
	}
	if (Number.isInteger(body.coverMediaId)) {
		db.prepare(`UPDATE albums SET cover_media_id=? WHERE id=?`).run(body.coverMediaId, id);
	}
	return json({ ok: true });
};

export const DELETE: RequestHandler = async (event) => {
	const guard = requireMutation(event);
	if (guard) return guard;
	const id = albumId(event.params);
	if (id == null) return apiError(400, 'BAD_ID', 'Invalid album id.');
	getDb().prepare(`DELETE FROM albums WHERE id=?`).run(id); // album_items cascade
	return json({ ok: true });
};
```

### `src/routes/api/albums/[id]/items/+server.ts`

```ts
import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { getDb } from '$server/db/index';
import { requireMutation } from '$server/security';
import { apiError, parseIds } from '$server/http';
import type { BulkResult } from '$shared/types';

function albumId(params: { id: string }): number | null {
	const id = Number(params.id);
	return Number.isInteger(id) && id > 0 ? id : null;
}

export const POST: RequestHandler = async (event) => {
	const guard = requireMutation(event);
	if (guard) return guard;
	const id = albumId(event.params);
	if (id == null) return apiError(400, 'BAD_ID', 'Invalid album id.');
	const body = (await event.request.json().catch(() => ({}))) as { ids?: unknown };
	const ids = parseIds(body.ids);
	if (!ids.length) return apiError(400, 'NO_IDS', 'No media ids provided.');

	const db = getDb();
	const stmt = db.prepare(
		`INSERT INTO album_items(album_id, media_id, added_at, position)
		 VALUES(@album, @media, @now, (SELECT COALESCE(MAX(position),-1)+1 FROM album_items WHERE album_id=@album))
		 ON CONFLICT(album_id, media_id) DO NOTHING`
	);
	const ok: number[] = [];
	const failed: BulkResult['failed'] = [];
	db.transaction(() => {
		for (const media of ids) {
			try {
				stmt.run({ album: id, media, now: Date.now() });
				ok.push(media);
			} catch (e) {
				failed.push({ id: media, error: e instanceof Error ? e.message : String(e) });
			}
		}
		// auto-set a cover if the album has none
		db.prepare(
			`UPDATE albums SET cover_media_id=? WHERE id=? AND cover_media_id IS NULL`
		).run(ids[0], id);
	})();
	return json({ ok, failed } satisfies BulkResult);
};

export const DELETE: RequestHandler = async (event) => {
	const guard = requireMutation(event);
	if (guard) return guard;
	const id = albumId(event.params);
	if (id == null) return apiError(400, 'BAD_ID', 'Invalid album id.');
	const body = (await event.request.json().catch(() => ({}))) as { ids?: unknown };
	const ids = parseIds(body.ids);
	if (!ids.length) return apiError(400, 'NO_IDS', 'No media ids provided.');
	const db = getDb();
	const stmt = db.prepare(`DELETE FROM album_items WHERE album_id=? AND media_id=?`);
	db.transaction(() => {
		for (const media of ids) stmt.run(id, media);
	})();
	return json({ ok: ids, failed: [] } satisfies BulkResult);
};
```

### `src/routes/api/albums/+server.ts`

```ts
import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { getDb } from '$server/db/index';
import { getAlbums } from '$server/db/queries';
import { requireMutation } from '$server/security';
import { apiError } from '$server/http';

export const GET: RequestHandler = () => json({ albums: getAlbums(getDb()) });

export const POST: RequestHandler = async (event) => {
	const guard = requireMutation(event);
	if (guard) return guard;
	const body = (await event.request.json().catch(() => ({}))) as { name?: string };
	const name = (body.name ?? '').trim();
	if (!name) return apiError(400, 'NO_NAME', 'Album name is required.');
	const db = getDb();
	const now = Date.now();
	const info = db
		.prepare(`INSERT INTO albums(name, created_at, sort_order) VALUES(?,?,0)`)
		.run(name, now);
	const id = Number(info.lastInsertRowid);
	return json({ id, name, coverMediaId: null, count: 0, createdAt: now, sortOrder: 0 });
};
```

### `src/routes/api/auth/login/+server.ts`

```ts
import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { getConfig, passwordHash } from '$server/config/configService';
import { verifyPassword, sessionTokenFor, isSameOrigin } from '$server/security';
import { apiError } from '$server/http';

// Simple in-memory rate limiter (this is a single-process, single-user app).
const attempts = new Map<string, { count: number; lockedUntil: number }>();
const MAX = 5;

export const POST: RequestHandler = async (event) => {
	if (!isSameOrigin(event)) return apiError(403, 'CSRF', 'Cross-origin request rejected.');
	const hash = passwordHash();
	if (!hash) return json({ ok: true }); // no password configured

	const ip = event.getClientAddress();
	const now = Date.now();
	const rec = attempts.get(ip) ?? { count: 0, lockedUntil: 0 };
	if (rec.lockedUntil > now) {
		return apiError(429, 'RATE_LIMIT', `Too many attempts. Try again in ${Math.ceil((rec.lockedUntil - now) / 1000)}s.`);
	}

	const body = (await event.request.json().catch(() => ({}))) as { password?: string };
	if (typeof body.password === 'string' && verifyPassword(body.password, hash)) {
		attempts.delete(ip);
		const ttl = getConfig().server.sessionTtlHours * 3600;
		event.cookies.set('lg_session', sessionTokenFor(hash), {
			path: '/',
			httpOnly: true,
			sameSite: 'lax',
			secure: event.url.protocol === 'https:', // mark Secure when served over TLS
			maxAge: ttl
		});
		return json({ ok: true });
	}

	rec.count++;
	if (rec.count >= MAX) {
		rec.lockedUntil = now + Math.min(15 * 60_000, 1000 * 2 ** (rec.count - MAX)); // exponential backoff
	}
	attempts.set(ip, rec);
	return apiError(401, 'BAD_PASSWORD', 'Incorrect password.');
};
```

### `src/routes/api/auth/logout/+server.ts`

```ts
import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { isSameOrigin } from '$server/security';
import { apiError } from '$server/http';

export const POST: RequestHandler = (event) => {
	// Reject cross-origin logout attempts (CSRF), matching the login handler.
	if (!isSameOrigin(event)) return apiError(403, 'CSRF', 'Cross-origin request rejected.');
	event.cookies.delete('lg_session', { path: '/' });
	return json({ ok: true });
};
```

### `src/routes/api/backup/+server.ts`

```ts
import { json } from '@sveltejs/kit';
import fs from 'node:fs';
import path from 'node:path';
import type { RequestHandler } from './$types';
import { getDb } from '$server/db/index';
import { requireMutation } from '$server/security';
import { log } from '$server/log';

/** GET → JSON export of DB-only data (favorites/albums/tags), keyed by path + quick_hash. */
export const GET: RequestHandler = () => {
	const db = getDb();
	const favorites = db
		.prepare(`SELECT path, quick_hash AS quickHash FROM media WHERE is_favorite=1`)
		.all();
	const albums = (db.prepare(`SELECT id, name FROM albums`).all() as { id: number; name: string }[]).map((a) => ({
		name: a.name,
		items: db
			.prepare(
				`SELECT m.path, m.quick_hash AS quickHash FROM album_items ai JOIN media m ON m.id=ai.media_id WHERE ai.album_id=? ORDER BY ai.position`
			)
			.all(a.id)
	}));
	const tags = db
		.prepare(
			`SELECT t.name, m.path FROM media_tags mt JOIN tags t ON t.id=mt.tag_id JOIN media m ON m.id=mt.media_id`
		)
		.all();
	const payload = { version: 1, exportedAt: Date.now(), favorites, albums, tags };
	return json(payload, {
		headers: { 'content-disposition': 'attachment; filename="lgallery-export.json"' }
	});
};

/** POST → make an on-disk backup copy of the SQLite DB (checkpointed). */
export const POST: RequestHandler = async (event) => {
	const guard = requireMutation(event);
	if (guard) return guard;
	const db = getDb();
	db.pragma('wal_checkpoint(TRUNCATE)');
	const src = path.resolve(process.cwd(), 'data', 'lgallery.db');
	const stamp = new Date(event.request.headers.get('date') ?? Date.now()).toISOString().replace(/[:.]/g, '-');
	const dest = path.resolve(process.cwd(), 'data', `lgallery.backup-${stamp}.db`);
	await fs.promises.copyFile(src, dest);
	log.info(`DB backup written to ${dest}`);
	return json({ ok: true, file: path.basename(dest) });
};
```

### `src/routes/api/config/+server.ts`

```ts
import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { getDb } from '$server/db/index';
import { getConfig, clientConfig, saveConfig, getConfigHash } from '$server/config/configService';
import { requireMutation } from '$server/security';
import { apiError } from '$server/http';
import { log } from '$server/log';

export const GET: RequestHandler = () => json(clientConfig());

export const PUT: RequestHandler = async (event) => {
	const guard = requireMutation(event);
	if (guard) return guard;

	const incoming = (await event.request.json().catch(() => null)) as
		| (Record<string, unknown> & { newPassword?: string; clearPassword?: boolean })
		| null;
	if (!incoming) return apiError(400, 'BAD_BODY', 'Invalid config body.');

	const current = getConfig();
	const { newPassword, clearPassword, server: incServer, ...rest } = incoming as Record<string, any>;

	// Merge over the current config so secrets (passwordHash) are preserved unless changed.
	const merged: Record<string, unknown> = {
		...current,
		...rest,
		server: {
			...current.server,
			...(incServer ?? {}),
			password: newPassword ? newPassword : null,
			passwordHash: clearPassword ? null : (current.server.passwordHash ?? null)
		}
	};

	let result;
	try {
		result = saveConfig(merged);
	} catch (e) {
		return apiError(400, 'INVALID_CONFIG', e instanceof Error ? e.message : 'Invalid config.');
	}

	// Reconcile roots (upsert configured, drop de-configured + their media) + rescan if changed.
	const db = getDb();
	const { reconcileRoots } = await import('$server/scan/scanner');
	reconcileRoots(db);
	db.prepare(
		`INSERT INTO app_state(key,value) VALUES('config_hash',?) ON CONFLICT(key) DO UPDATE SET value=excluded.value`
	).run(getConfigHash());

	if (result.changed) {
		const { requestRescan } = await import('$server/scan/scanner');
		requestRescan({ reason: 'config-saved' });
		log.info('Config saved via Settings → rescan enqueued.');
	}
	// (Re)start the live watcher to reflect scan.watch / roots changes.
	try {
		const { startWatcher } = await import('$server/scan/watcher');
		startWatcher();
	} catch (e) {
		log.debug('watcher restart skipped', e);
	}
	return json({ ok: true, config: clientConfig(), rescan: result.changed });
};
```

### `src/routes/api/duplicates/+server.ts`

```ts
import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { getDb } from '$server/db/index';
import { getDuplicates } from '$server/db/queries';

export const GET: RequestHandler = () => json({ groups: getDuplicates(getDb()) });
```

### `src/routes/api/export/+server.ts`

```ts
import type { RequestHandler } from './$types';
import { Readable } from 'node:stream';
import { ZipArchive } from 'archiver';
import { getDb } from '$server/db/index';
import { getMediaPath } from '$server/db/queries';
import { realPathWithinRoots } from '$server/paths';
import { getEnabledRoots, getTrashDir } from '$server/config/configService';
import { apiError, parseIds } from '$server/http';
import { log } from '$server/log';

/** Stream a zip of selected originals. GET so it can be a plain download link. */
export const GET: RequestHandler = async ({ url }) => {
	const ids = parseIds((url.searchParams.get('ids') ?? '').split(',').map((s) => Number(s)));
	if (!ids.length) return apiError(400, 'NO_IDS', 'No media ids provided.');

	const db = getDb();
	const roots = getEnabledRoots();
	const trash = getTrashDir();
	// archiver v8 is ESM and exposes archive classes (no callable vending fn).
	const archive = new ZipArchive({ zlib: { level: 6 } });
	archive.on('warning', (e: Error) => log.warn('export archive warning', e));
	archive.on('error', (e: Error) => log.error('export archive error', e));

	const seen = new Set<string>();
	let added = 0;
	for (const id of ids) {
		const media = getMediaPath(db, id);
		if (!media) continue;
		try {
			const real = await realPathWithinRoots(media.path, roots, [trash]);
			let name = real.split('/').pop() ?? `media-${id}`;
			if (seen.has(name)) name = `${id}-${name}`;
			seen.add(name);
			archive.file(real, { name });
			added++;
		} catch {
			/* skip files that fail the allow-list / are missing */
		}
	}
	if (added === 0) return apiError(404, 'EMPTY', 'No exportable files found.');
	void archive.finalize();

	return new Response(Readable.toWeb(archive) as unknown as ReadableStream, {
		headers: {
			'content-type': 'application/zip',
			'content-disposition': 'attachment; filename="lgallery-export.zip"',
			'cache-control': 'no-store'
		}
	});
};
```

### `src/routes/api/folders/+server.ts`

```ts
import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { getDb } from '$server/db/index';
import { getFolder } from '$server/db/queries';

export const GET: RequestHandler = ({ url }) => {
	const dir = url.searchParams.get('dir');
	return json(getFolder(getDb(), dir));
};
```

### `src/routes/api/map/points/+server.ts`

```ts
import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { getDb } from '$server/db/index';
import { getMapClusters } from '$server/db/queries';

export const GET: RequestHandler = ({ url }) => {
	const zoom = Number(url.searchParams.get('zoom') ?? 3);
	const raw = url.searchParams.get('bbox');
	let bbox = null;
	if (raw) {
		const [minLon, minLat, maxLon, maxLat] = raw.split(',').map(Number);
		if ([minLon, minLat, maxLon, maxLat].every(Number.isFinite)) bbox = { minLon, minLat, maxLon, maxLat };
	}
	return json({ clusters: getMapClusters(getDb(), bbox, Number.isFinite(zoom) ? zoom : 3) });
};
```

### `src/routes/api/media/[id]/+server.ts`

```ts
import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { getDb } from '$server/db/index';
import { getMediaDetail } from '$server/db/queries';
import { requireMutation } from '$server/security';
import { apiError } from '$server/http';

export const GET: RequestHandler = ({ params }) => {
	const id = Number(params.id);
	if (!Number.isInteger(id) || id <= 0) return apiError(400, 'BAD_ID', 'Invalid media id.');
	const detail = getMediaDetail(getDb(), id);
	if (!detail) return apiError(404, 'NOT_FOUND', 'Media not found.');
	return json(detail);
};

/** Update a single item's caption / rating / pick flag. Returns the refreshed detail. */
export const PATCH: RequestHandler = async (event) => {
	const guard = requireMutation(event);
	if (guard) return guard;
	const id = Number(event.params.id);
	if (!Number.isInteger(id) || id <= 0) return apiError(400, 'BAD_ID', 'Invalid media id.');
	const body = (await event.request.json().catch(() => ({}))) as {
		caption?: string | null;
		rating?: number;
		pick?: number;
	};

	const sets: string[] = [];
	const params: Record<string, unknown> = {};
	if (body.caption !== undefined) {
		sets.push('caption=@caption');
		params.caption = body.caption == null ? null : String(body.caption).slice(0, 2000);
	}
	if (body.rating !== undefined) {
		const r = Math.max(0, Math.min(5, Math.round(Number(body.rating) || 0)));
		sets.push('rating=@rating');
		params.rating = r;
	}
	if (body.pick !== undefined) {
		const p = Number(body.pick);
		sets.push('pick=@pick');
		params.pick = p > 0 ? 1 : p < 0 ? -1 : 0;
	}
	if (!sets.length) return apiError(400, 'NO_FIELDS', 'Nothing to update.');

	const db = getDb();
	if (!db.prepare(`SELECT 1 FROM media WHERE id = ?`).get(id)) {
		return apiError(404, 'NOT_FOUND', 'Media not found.');
	}
	db.prepare(`UPDATE media SET ${sets.join(', ')}, updated_at=@now WHERE id=@id`).run({
		...params,
		now: Date.now(),
		id
	});
	return json(getMediaDetail(db, id));
};
```

### `src/routes/api/media/[id]/edit/+server.ts`

```ts
import { json } from '@sveltejs/kit';
import path from 'node:path';
import fs from 'node:fs';
import type { RequestHandler } from './$types';
import { getDb } from '$server/db/index';
import { getMediaDetail, getMediaPath } from '$server/db/queries';
import { requireMutation } from '$server/security';
import { apiError } from '$server/http';
import { renderEditedThumbs, exportEditedCopy } from '$server/media/editService';
import { makeImageThumbs, ALL_SIZES } from '$server/media/thumbnailService';
import { normalizeEdits, isEdited, type EditOps } from '$shared/edits';
import { assertWithinRoots, normalizePath } from '$server/paths';
import { getEnabledRoots } from '$server/config/configService';

function photoRow(id: number) {
	const db = getDb();
	const row = db.prepare(`SELECT path, type, width, height FROM media WHERE id = ?`).get(id) as
		| { path: string; type: string; width: number | null; height: number | null }
		| undefined;
	return row;
}

/** Apply (or, for a no-op edit, clear) non-destructive edits and regenerate derivatives. */
export const PUT: RequestHandler = async (event) => {
	const guard = requireMutation(event);
	if (guard) return guard;
	const id = Number(event.params.id);
	if (!Number.isInteger(id) || id <= 0) return apiError(400, 'BAD_ID', 'Invalid media id.');
	const row = photoRow(id);
	if (!row) return apiError(404, 'NOT_FOUND', 'Media not found.');
	if (row.type !== 'photo') return apiError(400, 'NOT_PHOTO', 'Only photos can be edited.');

	const body = (await event.request.json().catch(() => ({}))) as Partial<EditOps>;
	const ops = normalizeEdits(body);
	const db = getDb();
	try {
		if (isEdited(ops)) {
			const t = await renderEditedThumbs(id, row.path, ops, ALL_SIZES);
			db.prepare(
				`UPDATE media SET edit_ops=@ops, edited_ms=@ms, blurhash=@bh, width=@w, height=@h,
				   thumb_status=2, updated_at=@ms WHERE id=@id`
			).run({ id, ops: JSON.stringify(ops), ms: Date.now(), bh: t.blurhash, w: t.width, h: t.height });
		} else {
			// All-default ops → revert to the original render.
			const t = await makeImageThumbs(row.path, id, ALL_SIZES);
			db.prepare(
				`UPDATE media SET edit_ops=NULL, edited_ms=NULL, blurhash=@bh, width=@w, height=@h,
				   thumb_status=2, updated_at=@now WHERE id=@id`
			).run({ id, now: Date.now(), bh: t.blurhash, w: t.width, h: t.height });
		}
	} catch (e) {
		return apiError(500, 'EDIT_FAILED', e instanceof Error ? e.message : 'Failed to render edits.');
	}
	return json(getMediaDetail(db, id));
};

/** Revert to the original (clear edits, regenerate from source). */
export const DELETE: RequestHandler = async (event) => {
	const guard = requireMutation(event);
	if (guard) return guard;
	const id = Number(event.params.id);
	if (!Number.isInteger(id) || id <= 0) return apiError(400, 'BAD_ID', 'Invalid media id.');
	const row = photoRow(id);
	if (!row) return apiError(404, 'NOT_FOUND', 'Media not found.');

	const db = getDb();
	try {
		const t = await makeImageThumbs(row.path, id, ALL_SIZES);
		db.prepare(
			`UPDATE media SET edit_ops=NULL, edited_ms=NULL, blurhash=@bh, width=@w, height=@h,
			   thumb_status=2, updated_at=@now WHERE id=@id`
		).run({ id, now: Date.now(), bh: t.blurhash, w: t.width, h: t.height });
	} catch (e) {
		return apiError(500, 'EDIT_FAILED', e instanceof Error ? e.message : 'Failed to revert.');
	}
	return json(getMediaDetail(db, id));
};

/** Write a full-resolution edited copy next to the original (source untouched). */
export const POST: RequestHandler = async (event) => {
	const guard = requireMutation(event);
	if (guard) return guard;
	const id = Number(event.params.id);
	if (!Number.isInteger(id) || id <= 0) return apiError(400, 'BAD_ID', 'Invalid media id.');
	const media = getMediaPath(getDb(), id);
	if (!media) return apiError(404, 'NOT_FOUND', 'Media not found.');
	if (media.type !== 'photo') return apiError(400, 'NOT_PHOTO', 'Only photos can be exported.');

	const body = (await event.request.json().catch(() => ({}))) as Partial<EditOps>;
	const ops = normalizeEdits(body);

	const src = normalizePath(media.path);
	const ext = path.extname(src) || '.jpg';
	const base = src.slice(0, src.length - ext.length);
	let dest = `${base}-edited${ext}`;
	let n = 2;
	while (fs.existsSync(dest)) dest = `${base}-edited-${n++}${ext}`;
	try {
		assertWithinRoots(dest, getEnabledRoots()); // stay inside a configured root
		await exportEditedCopy(media.path, ops, dest);
	} catch (e) {
		return apiError(500, 'EXPORT_FAILED', e instanceof Error ? e.message : 'Export failed.');
	}
	return json({ ok: true, path: dest });
};
```

### `src/routes/api/media/[id]/original/+server.ts`

```ts
import type { RequestHandler } from './$types';
import { getDb } from '$server/db/index';
import { serveOriginal } from '$server/media/streamService';
import { apiError } from '$server/http';

export const GET: RequestHandler = ({ params, request }) => {
	const id = Number(params.id);
	if (!Number.isInteger(id) || id <= 0) return apiError(400, 'BAD_ID', 'Invalid media id.');
	return serveOriginal(getDb(), id, request);
};
```

### `src/routes/api/media/[id]/stream/+server.ts`

```ts
import type { RequestHandler } from './$types';
import { getDb } from '$server/db/index';
import { serveOriginal } from '$server/media/streamService';
import { apiError } from '$server/http';

// Video streaming reuses the same Range-aware server as originals; <video> sends Range headers.
export const GET: RequestHandler = ({ params, request }) => {
	const id = Number(params.id);
	if (!Number.isInteger(id) || id <= 0) return apiError(400, 'BAD_ID', 'Invalid media id.');
	return serveOriginal(getDb(), id, request);
};
```

### `src/routes/api/media/[id]/tags/+server.ts`

```ts
import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { getDb, type DB } from '$server/db/index';
import { requireMutation } from '$server/security';
import { apiError } from '$server/http';

function tagsFor(db: DB, mediaId: number): { id: number; name: string }[] {
	return db
		.prepare(
			`SELECT t.id, t.name FROM tags t JOIN media_tags mt ON mt.tag_id = t.id
			 WHERE mt.media_id = ? ORDER BY t.name`
		)
		.all(mediaId) as { id: number; name: string }[];
}

/** Add a tag to a media item — by existing `tagId` or by `name` (created on demand). */
export const POST: RequestHandler = async (event) => {
	const guard = requireMutation(event);
	if (guard) return guard;
	const id = Number(event.params.id);
	if (!Number.isInteger(id) || id <= 0) return apiError(400, 'BAD_ID', 'Invalid media id.');
	const body = (await event.request.json().catch(() => ({}))) as { tagId?: number; name?: string };

	const db = getDb();
	if (!db.prepare(`SELECT 1 FROM media WHERE id = ?`).get(id)) {
		return apiError(404, 'NOT_FOUND', 'Media not found.');
	}

	let tagId = body.tagId;
	if (!tagId) {
		const name = (body.name ?? '').trim();
		if (!name) return apiError(400, 'NO_TAG', 'Provide a tagId or name.');
		db.prepare(`INSERT INTO tags(name) VALUES(?) ON CONFLICT(name) DO NOTHING`).run(name);
		tagId = (db.prepare(`SELECT id FROM tags WHERE name = ?`).get(name) as { id: number }).id;
	}
	db.prepare(`INSERT INTO media_tags(media_id, tag_id) VALUES(?, ?) ON CONFLICT DO NOTHING`).run(id, tagId);
	return json({ tags: tagsFor(db, id) });
};

/** Remove a tag (`tagId`) from a media item. */
export const DELETE: RequestHandler = async (event) => {
	const guard = requireMutation(event);
	if (guard) return guard;
	const id = Number(event.params.id);
	if (!Number.isInteger(id) || id <= 0) return apiError(400, 'BAD_ID', 'Invalid media id.');
	const body = (await event.request.json().catch(() => ({}))) as { tagId?: number };
	if (!body.tagId) return apiError(400, 'NO_TAG', 'tagId is required.');

	const db = getDb();
	db.prepare(`DELETE FROM media_tags WHERE media_id = ? AND tag_id = ?`).run(id, body.tagId);
	return json({ tags: tagsFor(db, id) });
};
```

### `src/routes/api/media/[id]/thumb/+server.ts`

```ts
import fs from 'node:fs';
import type { RequestHandler } from './$types';
import { getDb } from '$server/db/index';
import { getConfig } from '$server/config/configService';
import { ensureThumb } from '$server/media/pipeline';
import { thumbPath } from '$server/paths';
import { apiError } from '$server/http';

export const GET: RequestHandler = async ({ params, url, request }) => {
	const id = Number(params.id);
	if (!Number.isInteger(id) || id <= 0) return apiError(400, 'BAD_ID', 'Invalid media id.');
	const sizeParam = url.searchParams.get('size');
	const size = sizeParam === 'preview' ? 'preview' : sizeParam === 'grid2x' ? 'grid2x' : 'grid';

	const row = getDb()
		.prepare(`SELECT mtime_ms, thumb_status, edited_ms FROM media WHERE id = ?`)
		.get(id) as { mtime_ms: number; thumb_status: number; edited_ms: number | null } | undefined;
	if (!row) return apiError(404, 'NOT_FOUND', 'Media not found.');

	const file = thumbPath(getConfig().thumbnails.dir, id, size);
	// Fold edited_ms into the etag so a re-edit invalidates caches. Edited derivatives are served
	// must-revalidate (the original source is immutable, but an edit reuses the same id/mtime).
	const edited = row.edited_ms ?? 0;
	const etag = `"t${id}-${row.mtime_ms}-${edited}-${size}"`;
	const cacheControl = edited ? 'public, max-age=0, must-revalidate' : 'public, max-age=31536000, immutable';
	if (request.headers.get('if-none-match') === etag) {
		return new Response(null, { status: 304, headers: { etag, 'cache-control': cacheControl } });
	}

	let exists = fs.existsSync(file);
	if (!exists) {
		await ensureThumb(id, size); // generate-on-miss (renders the deferred preview if that's what's asked)
		exists = fs.existsSync(file);
	}
	if (!exists) return apiError(404, 'NO_THUMB', 'Thumbnail unavailable.');

	const buf = await fs.promises.readFile(file);
	return new Response(buf, {
		headers: {
			'content-type': 'image/webp',
			'cache-control': cacheControl,
			etag,
			'content-length': String(buf.length)
		}
	});
};
```

### `src/routes/api/media/+server.ts`

```ts
import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { getDb } from '$server/db/index';
import { bustBucketsCache } from '$server/db/queries';
import { requireMutation } from '$server/security';
import { apiError, parseIds } from '$server/http';
import type { BulkResult } from '$shared/types';

/** Bulk set favorite / archived flags. */
export const PATCH: RequestHandler = async (event) => {
	const guard = requireMutation(event);
	if (guard) return guard;
	const body = (await event.request.json().catch(() => ({}))) as {
		ids?: unknown;
		favorite?: boolean;
		archived?: boolean;
		rating?: number;
		pick?: number;
	};
	const ids = parseIds(body.ids);
	if (!ids.length) return apiError(400, 'NO_IDS', 'No media ids provided.');

	const sets: string[] = [];
	const params: Record<string, number> = {};
	if (typeof body.favorite === 'boolean') {
		sets.push('is_favorite=@favorite');
		params.favorite = body.favorite ? 1 : 0;
	}
	if (typeof body.archived === 'boolean') {
		sets.push('is_archived=@archived');
		params.archived = body.archived ? 1 : 0;
	}
	if (typeof body.rating === 'number') {
		sets.push('rating=@rating');
		params.rating = Math.max(0, Math.min(5, Math.round(body.rating)));
	}
	if (typeof body.pick === 'number') {
		sets.push('pick=@pick');
		params.pick = body.pick > 0 ? 1 : body.pick < 0 ? -1 : 0;
	}
	if (!sets.length) return apiError(400, 'NO_FIELDS', 'Nothing to update.');

	const db = getDb();
	const stmt = db.prepare(`UPDATE media SET ${sets.join(', ')}, updated_at=@now WHERE id=@id`);
	const ok: number[] = [];
	const failed: BulkResult['failed'] = [];
	db.transaction(() => {
		for (const id of ids) {
			try {
				stmt.run({ ...params, now: Date.now(), id });
				ok.push(id);
			} catch (e) {
				failed.push({ id, error: e instanceof Error ? e.message : String(e) });
			}
		}
	})();
	if (typeof body.archived === 'boolean') bustBucketsCache(); // archived items leave the timeline
	return json({ ok, failed } satisfies BulkResult);
};
```

### `src/routes/api/media/move/+server.ts`

```ts
import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { requireMutation } from '$server/security';
import { apiError, parseIds } from '$server/http';
import { move } from '$server/media/fileService';
import { PathError } from '$server/paths';

export const POST: RequestHandler = async (event) => {
	const guard = requireMutation(event);
	if (guard) return guard;
	const body = (await event.request.json().catch(() => ({}))) as { ids?: unknown; destDir?: string };
	const ids = parseIds(body.ids);
	if (!ids.length) return apiError(400, 'NO_IDS', 'No media ids provided.');
	if (!body.destDir) return apiError(400, 'NO_DEST', 'No destination folder provided.');
	try {
		return json(await move(ids, body.destDir));
	} catch (e) {
		if (e instanceof PathError) return apiError(403, 'FORBIDDEN', 'Destination is outside the allowed roots.');
		return apiError(500, 'MOVE_FAILED', e instanceof Error ? e.message : 'Move failed.');
	}
};
```

### `src/routes/api/media/rename/+server.ts`

```ts
import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { requireMutation } from '$server/security';
import { apiError } from '$server/http';
import { rename } from '$server/media/fileService';

export const POST: RequestHandler = async (event) => {
	const guard = requireMutation(event);
	if (guard) return guard;
	const body = (await event.request.json().catch(() => ({}))) as { id?: number; newName?: string };
	const id = Number(body.id);
	if (!Number.isInteger(id) || id <= 0) return apiError(400, 'BAD_ID', 'Invalid media id.');
	if (!body.newName) return apiError(400, 'NO_NAME', 'No new name provided.');
	try {
		return json(await rename(id, body.newName));
	} catch (e) {
		return apiError(400, 'RENAME_FAILED', e instanceof Error ? e.message : 'Rename failed.');
	}
};
```

### `src/routes/api/media/trash/+server.ts`

```ts
import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { requireMutation } from '$server/security';
import { apiError, parseIds } from '$server/http';
import { trash } from '$server/media/fileService';

export const POST: RequestHandler = async (event) => {
	const guard = requireMutation(event);
	if (guard) return guard;
	const body = (await event.request.json().catch(() => ({}))) as { ids?: unknown };
	const ids = parseIds(body.ids);
	if (!ids.length) return apiError(400, 'NO_IDS', 'No media ids provided.');
	return json(await trash(ids));
};
```

### `src/routes/api/memories/+server.ts`

```ts
import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { getDb } from '$server/db/index';
import { getMemories } from '$server/db/queries';

export const GET: RequestHandler = () => {
	const now = new Date();
	const md = `${String(now.getMonth() + 1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')}`;
	return json({ today: md, groups: getMemories(getDb(), md, now.getFullYear()) });
};
```

### `src/routes/api/people/[id]/+server.ts`

```ts
import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { getDb } from '$server/db/index';
import { mapTimelineRow } from '$server/db/queries';
import { apiError } from '$server/http';

export const GET: RequestHandler = ({ params }) => {
	const id = Number(params.id);
	if (!Number.isInteger(id) || id <= 0) return apiError(400, 'BAD_ID', 'Invalid person id.');
	const db = getDb();
	try {
		const rows = db
			.prepare(
				`SELECT DISTINCT m.id, m.type, m.width, m.height, m.taken_ms, m.taken_local_day, m.duration_ms,
				        m.blurhash, m.is_favorite, m.live_partner_id, m.thumb_status
				 FROM media m JOIN faces f ON f.media_id = m.id
				 WHERE f.cluster_id = ? AND m.is_trashed = 0
				 ORDER BY m.taken_ms DESC, m.id DESC LIMIT 500`
			)
			.all(id) as any[];
		return json({ items: rows.map(mapTimelineRow), nextCursor: null });
	} catch {
		return json({ items: [], nextCursor: null }); // faces tables not present yet
	}
};
```

### `src/routes/api/people/+server.ts`

```ts
import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { getDb } from '$server/db/index';
import { getPeople } from '$server/ai/aiService';

export const GET: RequestHandler = () => json({ people: getPeople(getDb()) });
```

### `src/routes/api/places/+server.ts`

```ts
import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { getDb } from '$server/db/index';
import { getPlaces } from '$server/db/queries';
import { getConfig } from '$server/config/configService';

/** Geotagged media grouped by reverse-geocoded locality (empty unless geocoding is enabled). */
export const GET: RequestHandler = () => {
	return json({ enabled: getConfig().geocode.enabled, places: getPlaces(getDb()) });
};
```

### `src/routes/api/scan/+server.ts`

```ts
import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { requestRescan } from '$server/scan/scanner';
import { requireMutation } from '$server/security';

export const POST: RequestHandler = async (event) => {
	const guard = requireMutation(event);
	if (guard) return guard;
	const body = (await event.request.json().catch(() => ({}))) as { full?: boolean };
	requestRescan({ reason: 'manual', full: !!body.full });
	return json({ ok: true });
};
```

### `src/routes/api/scan/status/+server.ts`

```ts
import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { getScanState } from '$server/scan/scanState';

export const GET: RequestHandler = () => json(getScanState());
```

### `src/routes/api/scan/stream/+server.ts`

```ts
import type { RequestHandler } from './$types';
import { subscribeScan } from '$server/scan/scanState';
import type { ScanState } from '$shared/types';

/** Server-Sent Events stream of live scan progress (one-way; works cleanly with adapter-node). */
export const GET: RequestHandler = () => {
	const enc = new TextEncoder();
	let unsubscribe: (() => void) | undefined;
	let heartbeat: ReturnType<typeof setInterval> | undefined;

	const stream = new ReadableStream({
		start(controller) {
			const send = (s: ScanState) => {
				try {
					controller.enqueue(enc.encode(`event: scan\ndata: ${JSON.stringify(s)}\n\n`));
				} catch {
					/* controller closed */
				}
			};
			unsubscribe = subscribeScan(send);
			heartbeat = setInterval(() => {
				try {
					controller.enqueue(enc.encode(`: ping\n\n`));
				} catch {
					/* ignore */
				}
			}, 15000);
		},
		cancel() {
			unsubscribe?.();
			if (heartbeat) clearInterval(heartbeat);
		}
	});

	return new Response(stream, {
		headers: {
			'content-type': 'text/event-stream',
			'cache-control': 'no-cache, no-transform',
			connection: 'keep-alive'
		}
	});
};
```

### `src/routes/api/search/+server.ts`

```ts
import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { getDb } from '$server/db/index';
import { searchMedia, type SearchFilters } from '$server/db/queries';
import { getConfig } from '$server/config/configService';
import { semanticSearch } from '$server/ai/aiService';

export const GET: RequestHandler = async ({ url }) => {
	const sp = url.searchParams;
	const num = (k: string) => (sp.get(k) ? Number(sp.get(k)) : undefined);
	const bool = (k: string) => sp.get(k) === '1' || sp.get(k) === 'true';
	const t = sp.get('type');

	// Optional semantic (CLIP) search — only when AI is enabled and a query is present.
	if (bool('semantic') && sp.get('q') && getConfig().ai.semanticSearch) {
		const items = await semanticSearch(sp.get('q') as string);
		return json({ items, nextCursor: null });
	}
	const filters: SearchFilters = {
		q: sp.get('q') ?? undefined,
		from: num('from'),
		to: num('to'),
		type: t === 'photo' || t === 'video' ? t : undefined,
		fav: bool('fav'),
		archived: bool('archived'),
		camera: sp.get('camera') ?? undefined,
		hasGps: bool('hasGps'),
		album: num('album'),
		tag: num('tag'),
		rating: num('rating'),
		pick: num('pick'),
		place: sp.get('place') ?? undefined,
		curMs: num('curMs') ?? null,
		curId: num('curId') ?? null,
		limit: num('limit')
	};
	return json(searchMedia(getDb(), filters));
};
```

### `src/routes/api/tags/[id]/+server.ts`

```ts
import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { getDb } from '$server/db/index';
import { requireMutation } from '$server/security';
import { apiError } from '$server/http';

/** Delete a tag (cascade removes its media_tags links). */
export const DELETE: RequestHandler = (event) => {
	const guard = requireMutation(event);
	if (guard) return guard;
	const id = Number(event.params.id);
	if (!Number.isInteger(id) || id <= 0) return apiError(400, 'BAD_ID', 'Invalid tag id.');
	getDb().prepare(`DELETE FROM tags WHERE id = ?`).run(id);
	return json({ ok: true });
};
```

### `src/routes/api/tags/+server.ts`

```ts
import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { getDb } from '$server/db/index';
import { getTags } from '$server/db/queries';
import { requireMutation } from '$server/security';
import { apiError } from '$server/http';

/** List all tags with their media counts. */
export const GET: RequestHandler = () => {
	return json({ tags: getTags(getDb()) });
};

/** Create a tag (idempotent on name). Returns the tag row. */
export const POST: RequestHandler = async (event) => {
	const guard = requireMutation(event);
	if (guard) return guard;
	const body = (await event.request.json().catch(() => ({}))) as { name?: string };
	const name = (body.name ?? '').trim();
	if (!name) return apiError(400, 'NO_NAME', 'Tag name is required.');
	if (name.length > 80) return apiError(400, 'TOO_LONG', 'Tag name is too long.');

	const db = getDb();
	db.prepare(`INSERT INTO tags(name) VALUES(?) ON CONFLICT(name) DO NOTHING`).run(name);
	const row = db.prepare(`SELECT id, name FROM tags WHERE name = ?`).get(name) as { id: number; name: string };
	return json({ id: row.id, name: row.name, count: 0 });
};
```

### `src/routes/api/timeline/+server.ts`

```ts
import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { getDb } from '$server/db/index';
import { getTimelinePage } from '$server/db/queries';

export const GET: RequestHandler = ({ url }) => {
	const num = (k: string) => {
		const v = url.searchParams.get(k);
		return v == null || v === '' ? null : Number(v);
	};
	const page = getTimelinePage(getDb(), {
		curMs: num('curMs'),
		curId: num('curId'),
		limit: num('limit') ?? 200
	});
	return json(page);
};
```

### `src/routes/api/timeline/buckets/+server.ts`

```ts
import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { getDb } from '$server/db/index';
import { getBuckets, getTotalCount } from '$server/db/queries';

export const GET: RequestHandler = () => {
	const db = getDb();
	return json({ buckets: getBuckets(db), total: getTotalCount(db) });
};
```

### `src/routes/api/timeline/visible/+server.ts`

```ts
import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { setVisiblePriority } from '$server/media/pipeline';
import { parseIds } from '$server/http';

/** Client posts the currently-visible media ids so the pipeline prioritizes their thumbs. */
export const POST: RequestHandler = async ({ request }) => {
	const body = (await request.json().catch(() => ({}))) as { ids?: unknown };
	setVisiblePriority(parseIds(body.ids));
	return json({ ok: true });
};
```

### `src/routes/api/trash/+server.ts`

```ts
import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { getDb } from '$server/db/index';
import { getTrash } from '$server/db/queries';
import { requireMutation } from '$server/security';
import { apiError, parseIds } from '$server/http';
import { permanentDelete } from '$server/media/fileService';

export const GET: RequestHandler = () => json({ items: getTrash(getDb()) });

/** Permanent delete (explicitly confirmed on the client). */
export const DELETE: RequestHandler = async (event) => {
	const guard = requireMutation(event);
	if (guard) return guard;
	const body = (await event.request.json().catch(() => ({}))) as { ids?: unknown };
	const ids = parseIds(body.ids);
	if (!ids.length) return apiError(400, 'NO_IDS', 'No media ids provided.');
	return json(await permanentDelete(ids));
};
```

### `src/routes/api/trash/restore/+server.ts`

```ts
import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { requireMutation } from '$server/security';
import { apiError, parseIds } from '$server/http';
import { restore } from '$server/media/fileService';

export const POST: RequestHandler = async (event) => {
	const guard = requireMutation(event);
	if (guard) return guard;
	const body = (await event.request.json().catch(() => ({}))) as { ids?: unknown };
	const ids = parseIds(body.ids);
	if (!ids.length) return apiError(400, 'NO_IDS', 'No media ids provided.');
	return json(await restore(ids));
};
```

### `src/routes/archive/+page.svelte`

```svelte
<script lang="ts">
	import { onMount } from 'svelte';
	import MediaGridView from '$components/grid/MediaGridView.svelte';
	import PageHeader from '$components/common/PageHeader.svelte';
	import EmptyState from '$components/common/EmptyState.svelte';
	import DensityToggle from '$components/common/DensityToggle.svelte';
	import { gallery } from '$client/state/gallery.svelte';
	import { api } from '$client/api';
	import { Archive } from '@lucide/svelte';

	let ready = $state(false);
	onMount(async () => {
		gallery.setSource((c) => api.search({ archived: true, curMs: c?.curMs, curId: c?.curId }));
		gallery.seed(await api.search({ archived: true }));
		ready = true;
	});
</script>

<div class="page">
	<PageHeader title="Archive" icon={Archive}>
		{#snippet actions()}<DensityToggle />{/snippet}
	</PageHeader>
	<div class="grid-wrap">
		{#if ready && gallery.items.length === 0}
			<EmptyState
				icon={Archive}
				title="Archive is empty"
				description="Archived photos are hidden from the main timeline but kept here."
			/>
		{:else}
			<MediaGridView />
		{/if}
	</div>
</div>

<style>
	.page {
		display: flex;
		flex-direction: column;
		height: 100%;
	}
	.grid-wrap {
		flex: 1;
		min-height: 0;
		position: relative;
	}
</style>
```

### `src/routes/duplicates/+page.svelte`

```svelte
<script lang="ts">
	import { onMount } from 'svelte';
	import type { DuplicateGroup } from '$shared/types';
	import { api } from '$client/api';
	import { blurhashAverageColor } from '$shared/blurhash';
	import PageHeader from '$components/common/PageHeader.svelte';
	import EmptyState from '$components/common/EmptyState.svelte';
	import { CopyCheck, Trash2 } from '@lucide/svelte';

	let groups = $state<DuplicateGroup[]>([]);
	let loading = $state(true);
	let selected = $state<Set<number>>(new Set());
	let busy = $state(false);

	async function load() {
		loading = true;
		groups = (await api.duplicates()).groups;
		// pre-select all but the first (lowest id) of each group
		const s = new Set<number>();
		for (const g of groups) g.items.slice(1).forEach((i) => s.add(i.id));
		selected = s;
		loading = false;
	}
	onMount(load);

	function toggle(id: number) {
		const s = new Set(selected);
		s.has(id) ? s.delete(id) : s.add(id);
		selected = s;
	}
	async function trashSelected() {
		const ids = [...selected];
		if (!ids.length) return;
		if (!confirm(`Move ${ids.length} duplicate(s) to trash?`)) return;
		busy = true;
		try {
			await api.trash(ids);
			await load();
		} catch (e) {
			alert(e instanceof Error ? e.message : 'Failed');
		} finally {
			busy = false;
		}
	}
</script>

<div class="page">
	<PageHeader title="Duplicates" icon={CopyCheck}>
		{#snippet actions()}
			{#if groups.length}
				<button class="btn btn-danger" onclick={trashSelected} disabled={busy || selected.size === 0}>
					<Trash2 size={16} /> Trash selected ({selected.size})
				</button>
			{/if}
		{/snippet}
	</PageHeader>
	<div class="scroll">
		{#if loading}
			<EmptyState icon={CopyCheck} title="Scanning for duplicates…" />
		{:else if groups.length === 0}
			<EmptyState icon={CopyCheck} title="No exact duplicates found." />
		{:else}
			{#each groups as g (g.hash)}
				<section>
					<div class="ghead">{g.items.length} identical files</div>
					<div class="row">
						{#each g.items as it, i (it.id)}
							<button
								class="thumb"
								class:sel={selected.has(it.id)}
								style="background-color:{blurhashAverageColor(it.blurhash)}"
								onclick={() => toggle(it.id)}
							>
								<img src="/api/media/{it.id}/thumb?size=grid" alt="" loading="lazy" />
								{#if i === 0}<span class="keep">keep</span>{/if}
							</button>
						{/each}
					</div>
				</section>
			{/each}
		{/if}
	</div>
</div>

<style>
	.page {
		display: flex;
		flex-direction: column;
		height: 100%;
	}
	.scroll {
		flex: 1;
		overflow-y: auto;
		padding: 8px 18px 24px;
	}
	section {
		margin-top: 16px;
		padding-bottom: 12px;
		border-bottom: 1px solid var(--lg-border);
	}
	.ghead {
		font-size: 0.85rem;
		color: var(--lg-text-muted);
		margin-bottom: 8px;
	}
	.row {
		display: flex;
		gap: 8px;
		flex-wrap: wrap;
	}
	.thumb {
		position: relative;
		width: 130px;
		height: 130px;
		border-radius: var(--lg-r-md);
		overflow: hidden;
		border: 3px solid transparent;
		padding: 0;
		cursor: pointer;
	}
	.thumb.sel {
		border-color: var(--lg-danger);
	}
	.thumb img {
		width: 100%;
		height: 100%;
		object-fit: cover;
	}
	.keep {
		position: absolute;
		bottom: 4px;
		left: 4px;
		font-size: 0.7rem;
		background: #16a34a;
		color: #fff;
		padding: 1px 6px;
		border-radius: var(--lg-r-sm);
	}
</style>
```

### `src/routes/favorites/+page.svelte`

```svelte
<script lang="ts">
	import { onMount } from 'svelte';
	import MediaGridView from '$components/grid/MediaGridView.svelte';
	import PageHeader from '$components/common/PageHeader.svelte';
	import EmptyState from '$components/common/EmptyState.svelte';
	import DensityToggle from '$components/common/DensityToggle.svelte';
	import { gallery } from '$client/state/gallery.svelte';
	import { api } from '$client/api';
	import { Star } from '@lucide/svelte';

	let ready = $state(false);
	onMount(async () => {
		gallery.setSource((c) => api.search({ fav: true, curMs: c?.curMs, curId: c?.curId }));
		gallery.seed(await api.search({ fav: true }));
		ready = true;
	});
</script>

<div class="page">
	<PageHeader title="Favorites" icon={Star}>
		{#snippet actions()}<DensityToggle />{/snippet}
	</PageHeader>
	<div class="grid-wrap">
		{#if ready && gallery.items.length === 0}
			<EmptyState
				icon={Star}
				title="No favorites yet"
				description="Tap the star on a photo, or press f in the viewer, to add it here."
			/>
		{:else}
			<MediaGridView />
		{/if}
	</div>
</div>

<style>
	.page {
		display: flex;
		flex-direction: column;
		height: 100%;
	}
	.grid-wrap {
		flex: 1;
		min-height: 0;
		position: relative;
	}
</style>
```

### `src/routes/folders/+page.server.ts`

```ts
import type { PageServerLoad } from './$types';
import { getDb } from '$server/db/index';
import { getFolder } from '$server/db/queries';

export const load: PageServerLoad = async ({ url }) => {
	const dir = url.searchParams.get('dir');
	return { folder: getFolder(getDb(), dir) };
};
```

### `src/routes/folders/+page.svelte`

```svelte
<script lang="ts">
	import type { TimelinePage } from '$shared/types';
	import MediaGridView from '$components/grid/MediaGridView.svelte';
	import PageHeader from '$components/common/PageHeader.svelte';
	import EmptyState from '$components/common/EmptyState.svelte';
	import { gallery } from '$client/state/gallery.svelte';
	import { Folder, FolderOpen, HardDrive } from '@lucide/svelte';

	type Root = { id: number; path: string; label: string };
	type FolderData = { dir: string | null; roots: Root[]; subfolders: string[]; page: TimelinePage };
	let { data }: { data: { folder: FolderData } } = $props();

	// Re-seed the shared list whenever we navigate to a different folder.
	$effect(() => {
		const f = data.folder;
		gallery.setSource(async () => ({ items: [], nextCursor: null })); // folders load eagerly
		gallery.seed(f.page);
	});

	const crumbs = $derived.by(() => {
		const f = data.folder;
		if (!f.dir) return [];
		const root = f.roots.find((r) => f.dir === r.path || f.dir!.startsWith(r.path + '/'));
		if (!root) return [{ name: f.dir, dir: f.dir }];
		const rest = f.dir.slice(root.path.length).split('/').filter(Boolean);
		const out: { name: string; dir: string }[] = [{ name: root.label || root.path, dir: root.path }];
		let acc = root.path;
		for (const seg of rest) {
			acc += '/' + seg;
			out.push({ name: seg, dir: acc });
		}
		return out;
	});
</script>

<div class="page">
	<PageHeader>
		{#snippet children()}
			<h1>Folders</h1>
			{#if crumbs.length}
				<nav class="crumbs">
					<a href="/folders">Roots</a>
					{#each crumbs as c (c.dir)}
						<span class="sep">/</span><a href="/folders?dir={encodeURIComponent(c.dir)}">{c.name}</a>
					{/each}
				</nav>
			{/if}
		{/snippet}
	</PageHeader>

	<div class="body">
		{#if !data.folder.dir}
			<ul class="roots">
				{#each data.folder.roots as r (r.id)}
					<li>
						<a href="/folders?dir={encodeURIComponent(r.path)}">
							<HardDrive size={22} />
							<div><strong>{r.label || r.path}</strong><span>{r.path}</span></div>
						</a>
					</li>
				{/each}
			</ul>
		{:else}
			{#if data.folder.subfolders.length}
				<ul class="subs">
					{#each data.folder.subfolders as name (name)}
						<li>
							<a href="/folders?dir={encodeURIComponent(data.folder.dir + '/' + name)}">
								<Folder size={18} />{name}
							</a>
						</li>
					{/each}
				</ul>
			{/if}
			{#if data.folder.page.items.length}
				<div class="grid-wrap"><MediaGridView /></div>
			{:else if data.folder.subfolders.length === 0}
				<EmptyState icon={FolderOpen} title="No media in this folder." />
			{/if}
		{/if}
	</div>
</div>

<style>
	.page {
		display: flex;
		flex-direction: column;
		height: 100%;
	}
	h1 {
		font-size: 1.4rem;
		font-weight: 700;
	}
	.crumbs {
		display: flex;
		align-items: center;
		gap: 6px;
		font-size: 0.9rem;
	}
	.crumbs a {
		color: var(--lg-accent);
		text-decoration: none;
	}
	.sep {
		color: var(--lg-text-muted);
	}
	.body {
		flex: 1;
		min-height: 0;
		display: flex;
		flex-direction: column;
		overflow: hidden;
	}
	.roots {
		list-style: none;
		margin: 0;
		padding: 18px;
		display: grid;
		grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
		gap: 12px;
		overflow-y: auto;
	}
	.roots a {
		display: flex;
		align-items: center;
		gap: 12px;
		padding: 14px;
		border: 1px solid var(--lg-border);
		border-radius: var(--lg-r-md);
		text-decoration: none;
		color: inherit;
	}
	.roots div {
		display: flex;
		flex-direction: column;
		min-width: 0;
	}
	.roots span {
		font-size: 0.78rem;
		color: var(--lg-text-muted);
		overflow: hidden;
		text-overflow: ellipsis;
		white-space: nowrap;
	}
	.subs {
		list-style: none;
		margin: 0;
		padding: 12px 18px;
		display: flex;
		flex-wrap: wrap;
		gap: 8px;
		flex-shrink: 0;
	}
	.subs a {
		display: flex;
		align-items: center;
		gap: 6px;
		padding: 7px 12px;
		border-radius: 999px;
		background: var(--lg-accent-weak);
		color: var(--lg-accent);
		text-decoration: none;
		font-size: 0.85rem;
	}
	.grid-wrap {
		flex: 1;
		min-height: 0;
		position: relative;
	}
</style>
```

### `src/routes/login/+page.svelte`

```svelte
<script lang="ts">
	import { Lock } from '@lucide/svelte';

	let password = $state('');
	let error = $state('');
	let busy = $state(false);

	function csrf(): string {
		const m = document.cookie.match(/(?:^|;\s*)lg_csrf=([^;]+)/);
		return m ? decodeURIComponent(m[1]) : '';
	}

	async function submit(e: Event) {
		e.preventDefault();
		busy = true;
		error = '';
		try {
			const r = await fetch('/api/auth/login', {
				method: 'POST',
				headers: { 'content-type': 'application/json', 'x-csrf-token': csrf() },
				body: JSON.stringify({ password })
			});
			if (r.ok) {
				window.location.href = '/';
			} else {
				const j = await r.json().catch(() => null);
				error = j?.error?.message ?? 'Login failed';
			}
		} catch {
			error = 'Login failed';
		} finally {
			busy = false;
		}
	}
</script>

<div class="overlay">
	<form class="card" onsubmit={submit}>
		<div class="logo"><Lock size={26} /></div>
		<h1>LGallery</h1>
		<p>This gallery is password-protected.</p>
		<!-- svelte-ignore a11y_autofocus -->
		<input type="password" placeholder="Password" bind:value={password} autofocus />
		{#if error}<p class="err">{error}</p>{/if}
		<button type="submit" disabled={busy || !password}>{busy ? 'Signing in…' : 'Unlock'}</button>
	</form>
</div>

<style>
	.overlay {
		position: fixed;
		inset: 0;
		z-index: 200;
		display: flex;
		align-items: center;
		justify-content: center;
		background: #0a0a0a;
		color: var(--lg-overlay-text);
	}
	.card {
		width: 320px;
		max-width: 90vw;
		text-align: center;
		display: flex;
		flex-direction: column;
		gap: 10px;
		padding: 28px;
		border: 1px solid var(--lg-overlay-border);
		border-radius: var(--lg-r-xl);
		background: #141414;
	}
	.logo {
		display: flex;
		justify-content: center;
		color: var(--lg-accent-hi);
	}
	h1 {
		font-size: 1.4rem;
		font-weight: 700;
	}
	p {
		color: var(--lg-overlay-muted);
		font-size: 0.9rem;
	}
	input {
		padding: 10px 12px;
		border-radius: var(--lg-r-md);
		border: 1px solid var(--lg-overlay-border);
		background: #0b0b0b;
		color: #fff;
		font-size: 1rem;
	}
	.err {
		color: #f87171;
		font-size: 0.85rem;
	}
	button {
		padding: 10px;
		border: none;
		border-radius: var(--lg-r-md);
		background: var(--lg-accent);
		color: var(--lg-accent-text);
		font-weight: 600;
		cursor: pointer;
	}
	button:disabled {
		opacity: 0.6;
	}
</style>
```

### `src/routes/map/+page.svelte`

```svelte
<script lang="ts">
	import { onMount } from 'svelte';
	import 'leaflet/dist/leaflet.css';
	import { api } from '$client/api';
	import { gallery } from '$client/state/gallery.svelte';
	import Lightbox from '$components/lightbox/Lightbox.svelte';

	// Map config comes from the layout load (clientConfig). Tiles are the one expected
	// outbound call, only while this view is open (docs/06-PRIVACY-AND-NETWORK.md).
	let { data }: { data: { config?: { map?: { enabled: boolean; tileUrl: string; attribution: string } } } } =
		$props();
	const mapCfg = $derived(data?.config?.map);

	let el = $state<HTMLDivElement>();
	let lightboxId = $state<number | null>(null);
	// eslint-disable-next-line @typescript-eslint/no-explicit-any
	let map: any = null;
	// eslint-disable-next-line @typescript-eslint/no-explicit-any
	let L: any = null;
	// eslint-disable-next-line @typescript-eslint/no-explicit-any
	let layer: any = null;
	let timer: ReturnType<typeof setTimeout> | undefined;

	async function refresh() {
		if (!map || !L) return;
		const b = map.getBounds();
		const bbox = `${b.getWest()},${b.getSouth()},${b.getEast()},${b.getNorth()}`;
		const zoom = map.getZoom();
		let clusters;
		try {
			clusters = (await api.mapPoints(bbox, zoom)).clusters;
		} catch {
			return;
		}
		layer.clearLayers();
		for (const c of clusters) {
			const r = Math.min(28, 9 + Math.log(c.count + 1) * 5);
			const m = L.circleMarker([c.lat, c.lon], {
				radius: r,
				color: '#fff',
				weight: 2,
				fillColor: '#2563eb',
				fillOpacity: 0.85
			});
			m.bindTooltip(String(c.count), { permanent: true, direction: 'center', className: 'cl-label' });
			m.on('click', async () => {
				if (c.count > 1) map.setView([c.lat, c.lon], Math.min(18, zoom + 3));
				else {
					try {
						const d = await api.detail(c.sampleId);
						gallery.setSource(async () => ({ items: [], nextCursor: null }));
						gallery.seed({ items: [d], nextCursor: null });
						lightboxId = c.sampleId;
					} catch {
						/* ignore */
					}
				}
			});
			layer.addLayer(m);
		}
	}

	onMount(() => {
		if (!mapCfg?.enabled) return;
		let destroyed = false;
		(async () => {
			const mod = await import('leaflet');
			L = (mod as { default?: unknown }).default ?? mod;
			if (destroyed || !el) return;
			map = L.map(el, { worldCopyJump: true }).setView([20, 0], 2);
			L.tileLayer(mapCfg.tileUrl, { attribution: mapCfg.attribution, maxZoom: 19 }).addTo(map);
			layer = L.layerGroup().addTo(map);
			map.on('moveend', () => {
				clearTimeout(timer);
				timer = setTimeout(refresh, 200);
			});
			refresh();
		})();
		return () => {
			destroyed = true;
			clearTimeout(timer);
			map?.remove();
		};
	});
</script>

<div class="page">
	{#if !mapCfg?.enabled}
		<p class="msg">The map is disabled in <code>lgallery.config.json</code> (<code>map.enabled = false</code>).</p>
	{:else}
		<div class="map" bind:this={el}></div>
	{/if}
</div>

{#if lightboxId !== null}
	<Lightbox startId={lightboxId} onClose={() => (lightboxId = null)} />
{/if}

<style>
	.page {
		height: 100%;
		width: 100%;
	}
	.map {
		height: 100%;
		width: 100%;
	}
	.msg {
		padding: 24px;
		color: #6b7280;
	}
	:global(.cl-label) {
		background: transparent;
		border: none;
		box-shadow: none;
		color: #fff;
		font-weight: 700;
		font-size: 0.75rem;
	}
	:global(.leaflet-container) {
		background: #aadaff;
	}
</style>
```

### `src/routes/map/+page.ts`

```ts
// Leaflet touches `window` and is large; render the map route client-only so its chunk + CSS
// never enter the SSR/critical path.
export const ssr = false;
```

### `src/routes/memories/+page.svelte`

```svelte
<script lang="ts">
	import { onMount } from 'svelte';
	import type { TimelineItem } from '$shared/types';
	import { api } from '$client/api';
	import { gallery } from '$client/state/gallery.svelte';
	import { blurhashAverageColor } from '$shared/blurhash';
	import Lightbox from '$components/lightbox/Lightbox.svelte';
	import PageHeader from '$components/common/PageHeader.svelte';
	import EmptyState from '$components/common/EmptyState.svelte';
	import { CalendarHeart } from '@lucide/svelte';

	let groups = $state<{ year: string; items: TimelineItem[] }[]>([]);
	let loading = $state(true);
	let lightboxId = $state<number | null>(null);

	onMount(async () => {
		const r = await api.memories();
		groups = r.groups;
		const flat = groups.flatMap((g) => g.items);
		gallery.setSource(async () => ({ items: [], nextCursor: null }));
		gallery.seed({ items: flat, nextCursor: null });
		loading = false;
	});
</script>

<div class="page">
	<PageHeader title="On this day" icon={CalendarHeart} />
	<div class="scroll">
		{#if loading}
			<EmptyState icon={CalendarHeart} title="Loading…" />
		{:else if groups.length === 0}
			<EmptyState
				icon={CalendarHeart}
				title="Nothing from this day in previous years — yet."
			/>
		{:else}
			{#each groups as g (g.year)}
				<section>
					<h2>{g.year}</h2>
					<div class="strip">
						{#each g.items as it (it.id)}
							<button
								class="thumb"
								style="background-color:{blurhashAverageColor(it.blurhash)}"
								onclick={() => (lightboxId = it.id)}
								aria-label="Open"
							>
								<img src="/api/media/{it.id}/thumb?size=grid" alt="" loading="lazy" />
							</button>
						{/each}
					</div>
				</section>
			{/each}
		{/if}
	</div>
</div>

{#if lightboxId !== null}
	<Lightbox startId={lightboxId} onClose={() => (lightboxId = null)} />
{/if}

<style>
	.page {
		display: flex;
		flex-direction: column;
		height: 100%;
	}
	.scroll {
		flex: 1;
		overflow-y: auto;
		padding: 8px 18px 24px;
	}
	section {
		margin-top: 18px;
	}
	h2 {
		font-size: 1.1rem;
		font-weight: 700;
		margin-bottom: 8px;
	}
	.strip {
		display: flex;
		gap: 8px;
		flex-wrap: wrap;
	}
	.thumb {
		width: 150px;
		height: 150px;
		border-radius: var(--lg-r-md);
		overflow: hidden;
		border: none;
		padding: 0;
		cursor: pointer;
	}
	.thumb img {
		width: 100%;
		height: 100%;
		object-fit: cover;
	}
</style>
```

### `src/routes/people/+page.svelte`

```svelte
<script lang="ts">
	import EmptyState from '$components/common/EmptyState.svelte';
	import { Users } from '@lucide/svelte';

	let { data }: { data: { config?: { ai?: { faceGrouping: boolean } } } } = $props();
	const enabled = $derived(!!data?.config?.ai?.faceGrouping);
</script>

<EmptyState icon={Users} title="People">
	{#snippet children()}
		{#if enabled}
			<p>Face grouping is enabled. Clusters appear here as the background AI pass runs.</p>
			<!-- Cluster grid is wired in P8 (GET /api/people). -->
		{:else}
			<p>
				Face grouping is an optional, on-device feature and is <strong>off by default</strong>. Enable it in
				<a href="/settings">Settings → AI</a>. Nothing is uploaded — all detection runs locally.
			</p>
		{/if}
	{/snippet}
</EmptyState>

<style>
	a {
		color: var(--lg-accent);
	}
</style>
```

### `src/routes/places/+page.svelte`

```svelte
<script lang="ts">
	import { onMount } from 'svelte';
	import MediaGridView from '$components/grid/MediaGridView.svelte';
	import PageHeader from '$components/common/PageHeader.svelte';
	import EmptyState from '$components/common/EmptyState.svelte';
	import DensityToggle from '$components/common/DensityToggle.svelte';
	import { gallery } from '$client/state/gallery.svelte';
	import { api } from '$client/api';
	import type { PlaceGroup } from '$shared/types';
	import { Globe, ChevronLeft } from '@lucide/svelte';

	let enabled = $state(true);
	let places = $state<PlaceGroup[]>([]);
	let selected = $state<PlaceGroup | null>(null);
	let ready = $state(false);
	let loaded = $state(false);

	onMount(async () => {
		const r = await api.places();
		enabled = r.enabled;
		places = r.places;
		loaded = true;
	});

	async function open(p: PlaceGroup) {
		selected = p;
		ready = false;
		gallery.setSource((c) => api.search({ place: p.locality, curMs: c?.curMs, curId: c?.curId }));
		gallery.seed(await api.search({ place: p.locality }));
		ready = true;
	}
</script>

<div class="page">
	<PageHeader title={selected ? selected.locality : 'Places'} icon={Globe}>
		{#snippet actions()}
			{#if selected}
				<button class="btn" onclick={() => (selected = null)}><ChevronLeft size={16} /> All places</button>
			{/if}
			<DensityToggle />
		{/snippet}
	</PageHeader>

	<div class="body">
		{#if selected}
			<div class="grid-wrap">
				{#if ready && gallery.items.length === 0}
					<EmptyState icon={Globe} title="Nothing here yet" />
				{:else}
					<MediaGridView />
				{/if}
			</div>
		{:else if loaded && !enabled}
			<EmptyState
				icon={Globe}
				title="Places is off"
				description="Enable reverse geocoding in Settings to group geotagged photos by location. It’s off by default for privacy; an offline city dataset is built in, or you can opt into OpenStreetMap’s Nominatim for precise names."
			/>
		{:else if loaded && places.length === 0}
			<EmptyState icon={Globe} title="No located photos yet" description="Geotagged photos appear here once they’ve been reverse-geocoded in the background." />
		{:else}
			<div class="cards">
				{#each places as p (p.locality)}
					<button class="card" onclick={() => open(p)}>
						<img src="/api/media/{p.sampleId}/thumb?size=grid2x" alt="" loading="lazy" />
						<div class="meta">
							<span class="name">{p.locality}</span>
							<span class="sub">{p.country ?? ''} · {p.count.toLocaleString()}</span>
						</div>
					</button>
				{/each}
			</div>
		{/if}
	</div>
</div>

<style>
	.page {
		display: flex;
		flex-direction: column;
		height: 100%;
	}
	.body {
		flex: 1;
		min-height: 0;
		position: relative;
		overflow-y: auto;
	}
	.grid-wrap {
		position: absolute;
		inset: 0;
	}
	.cards {
		display: grid;
		grid-template-columns: repeat(auto-fill, minmax(180px, 1fr));
		gap: 14px;
		padding: 16px;
	}
	.card {
		display: flex;
		flex-direction: column;
		border: none;
		padding: 0;
		background: var(--lg-surface-2);
		border-radius: var(--lg-r-lg);
		overflow: hidden;
		cursor: pointer;
		text-align: left;
		box-shadow: var(--lg-shadow-1);
		transition: transform var(--lg-dur-fast) var(--lg-ease);
	}
	.card:hover {
		transform: translateY(-2px);
	}
	.card img {
		width: 100%;
		aspect-ratio: 4 / 3;
		object-fit: cover;
		background: var(--lg-surface-hover);
	}
	.meta {
		display: flex;
		flex-direction: column;
		gap: 1px;
		padding: 9px 11px;
	}
	.name {
		font-weight: 600;
		color: var(--lg-text);
	}
	.sub {
		font-size: 0.8rem;
		color: var(--lg-text-muted);
	}
	@media (prefers-reduced-motion: reduce) {
		.card {
			transition: none;
		}
	}
</style>
```

### `src/routes/search/+page.svelte`

```svelte
<script lang="ts">
	import MediaGridView from '$components/grid/MediaGridView.svelte';
	import DensityToggle from '$components/common/DensityToggle.svelte';
	import PageHeader from '$components/common/PageHeader.svelte';
	import EmptyState from '$components/common/EmptyState.svelte';
	import { untrack } from 'svelte';
	import { page } from '$app/state';
	import { gallery } from '$client/state/gallery.svelte';
	import { api } from '$client/api';
	import { Search, Image, Video, Star, MapPin, Flag, Ban } from '@lucide/svelte';

	// Prefill from ?q= (e.g. the command palette's "Search for …").
	let q = $state(untrack(() => page.url.searchParams.get('q') ?? ''));
	let type = $state<'' | 'photo' | 'video'>('');
	let fav = $state(false);
	let hasGps = $state(false);
	let minRating = $state(0); // 0 = any, else cycles 1-5
	let pick = $state(0); // 0 = any, 1 = picks, -1 = rejects
	let ran = $state(false);
	let count = $state(0);
	let timer: ReturnType<typeof setTimeout> | undefined;

	function filters() {
		return {
			q,
			type: type || undefined,
			fav,
			hasGps,
			rating: minRating || undefined,
			pick: pick || undefined
		};
	}

	async function run() {
		const f = filters();
		gallery.setSource((c) => api.search({ ...f, curMs: c?.curMs, curId: c?.curId }));
		const first = await api.search(f);
		gallery.seed(first);
		count = first.items.length;
		ran = true;
	}

	function scheduleRun() {
		clearTimeout(timer);
		timer = setTimeout(run, 250);
	}

	$effect(() => {
		// re-run when any filter changes
		void [q, type, fav, hasGps, minRating, pick];
		scheduleRun();
	});

	const PickIcon = $derived(pick === -1 ? Ban : Flag);
</script>

<div class="page">
	<PageHeader>
		{#snippet children()}
			<div class="search">
				<Search size={18} />
				<!-- svelte-ignore a11y_autofocus -->
				<input placeholder="Search filenames, cameras…" bind:value={q} autofocus />
			</div>
		{/snippet}
		{#snippet actions()}
			<button class="btn" class:on={type === 'photo'} onclick={() => (type = type === 'photo' ? '' : 'photo')} title="Photos"><Image size={16} /></button>
			<button class="btn" class:on={type === 'video'} onclick={() => (type = type === 'video' ? '' : 'video')} title="Videos"><Video size={16} /></button>
			<button class="btn" class:on={fav} onclick={() => (fav = !fav)} title="Favorites"><Star size={16} /></button>
			<button class="btn" class:on={hasGps} onclick={() => (hasGps = !hasGps)} title="Has location"><MapPin size={16} /></button>
			<button
				class="btn rating"
				class:on={minRating > 0}
				onclick={() => (minRating = (minRating + 1) % 6)}
				title="Minimum rating"
			>
				<Star size={16} fill={minRating > 0 ? 'currentColor' : 'none'} />
				{#if minRating > 0}<span class="num">{minRating}+</span>{/if}
			</button>
			<button
				class="btn"
				class:on={pick !== 0}
				class:reject={pick === -1}
				onclick={() => (pick = pick === 0 ? 1 : pick === 1 ? -1 : 0)}
				title={pick === 1 ? 'Picks' : pick === -1 ? 'Rejects' : 'Pick / reject'}
			>
				<PickIcon size={16} />
			</button>
			<DensityToggle />
		{/snippet}
	</PageHeader>
	<div class="grid-wrap">
		{#if ran && gallery.items.length === 0}
			<EmptyState icon={Search} title="No matches." />
		{:else if ran}
			<MediaGridView />
		{:else}
			<EmptyState icon={Search} title="Type to search your library." />
		{/if}
	</div>
</div>

<style>
	.page {
		display: flex;
		flex-direction: column;
		height: 100%;
	}
	.search {
		display: flex;
		align-items: center;
		gap: 8px;
		flex: 1;
		min-width: 220px;
		padding: 8px 12px;
		border: 1px solid var(--lg-border);
		border-radius: var(--lg-r-md);
		color: var(--lg-text-muted);
	}
	.search input {
		flex: 1;
		border: none;
		background: transparent;
		color: inherit;
		font-size: 0.95rem;
		outline: none;
	}
	.btn.on {
		background: var(--lg-accent);
		color: var(--lg-accent-text);
		border-color: var(--lg-accent);
	}
	.btn.reject {
		background: var(--lg-danger);
		border-color: var(--lg-danger);
		color: #fff;
	}
	.btn.rating {
		display: inline-flex;
		align-items: center;
		gap: 3px;
	}
	.btn.rating .num {
		font-size: 0.78rem;
		font-weight: 600;
	}
	.grid-wrap {
		flex: 1;
		min-height: 0;
		position: relative;
	}
</style>
```

### `src/routes/settings/+page.server.ts`

```ts
import type { PageServerLoad } from './$types';
import { clientConfig } from '$server/config/configService';

export const load: PageServerLoad = async () => {
	return { config: clientConfig(), appDir: process.cwd() };
};
```

### `src/routes/settings/+page.svelte`

```svelte
<script lang="ts">
	import { untrack } from 'svelte';
	import { api } from '$client/api';
	import { settings } from '$client/state/settings.svelte';
	import { Plus, Trash2, Save, Database, Download, RefreshCw, ShieldAlert, LogOut, Power, Copy } from '@lucide/svelte';

	// eslint-disable-next-line @typescript-eslint/no-explicit-any
	let { data }: { data: { config: any; appDir: string } } = $props();
	// Editable copy of the loaded config (capture the initial value only).
	// eslint-disable-next-line @typescript-eslint/no-explicit-any
	let cfg = $state<any>(untrack(() => structuredClone(data.config)));
	let newPassword = $state('');
	let clearPassword = $state(false);
	let saving = $state(false);
	let msg = $state('');
	let copied = $state(false);

	function copy(text: string) {
		navigator.clipboard?.writeText(text).then(() => {
			copied = true;
			setTimeout(() => (copied = false), 1500);
		});
	}

	function addRoot() {
		cfg.roots = [...cfg.roots, { path: '', label: '', enabled: true }];
	}
	function removeRoot(i: number) {
		cfg.roots = cfg.roots.filter((_: unknown, idx: number) => idx !== i);
	}

	async function save() {
		saving = true;
		msg = '';
		try {
			const body = { ...cfg };
			delete body.server.passwordSet;
			if (newPassword) body.newPassword = newPassword;
			if (clearPassword) body.clearPassword = true;
			const r = await api.saveConfig(body);
			msg = r.rescan ? 'Saved — rescanning library…' : 'Saved.';
			newPassword = '';
			clearPassword = false;
		} catch (e) {
			msg = e instanceof Error ? e.message : 'Save failed';
		} finally {
			saving = false;
		}
	}

	async function backup() {
		try {
			const r = await api.backupDb();
			msg = `Database backed up to data/${r.file}`;
		} catch (e) {
			msg = e instanceof Error ? e.message : 'Backup failed';
		}
	}
	async function rescan() {
		await api.rescan(false);
		msg = 'Rescan started.';
	}
	async function logout() {
		await api.logout();
		window.location.href = '/login';
	}
</script>

<div class="page">
	<header class="bar">
		<h1>Settings</h1>
		<div class="head-actions">
			{#if msg}<span class="msg">{msg}</span>{/if}
			<button class="primary" onclick={save} disabled={saving}><Save size={16} /> {saving ? 'Saving…' : 'Save'}</button>
		</div>
	</header>

	<div class="scroll">
		<!-- ROOTS -->
		<section>
			<h2>Media folders</h2>
			<p class="hint">Folders scanned for photos &amp; videos. Changes trigger an incremental rescan.</p>
			{#each cfg.roots as root, i (i)}
				<div class="root">
					<input class="grow" placeholder="D:/Photos" bind:value={root.path} />
					<input class="lbl" placeholder="Label" bind:value={root.label} />
					<label class="chk"><input type="checkbox" bind:checked={root.enabled} /> Enabled</label>
					<button class="icon danger" onclick={() => removeRoot(i)} aria-label="Remove"><Trash2 size={15} /></button>
				</div>
			{/each}
			<button class="add" onclick={addRoot}><Plus size={15} /> Add folder</button>
		</section>

		<!-- APPEARANCE (client-side) -->
		<section>
			<h2>Appearance</h2>
			<div class="row">
				<span class="k">Theme</span>
				<select value={settings.theme} onchange={(e) => settings.setTheme(e.currentTarget.value as never)}>
					<option value="system">System</option><option value="light">Light</option><option value="dark">Dark</option>
				</select>
			</div>
			<div class="row">
				<span class="k">Grid density</span>
				<select value={settings.density} onchange={(e) => settings.setDensity(e.currentTarget.value as never)}>
					<option value="compact">Compact</option><option value="comfortable">Comfortable</option><option value="spacious">Spacious</option>
				</select>
			</div>
		</section>

		<!-- SCAN + THUMBNAILS -->
		<section>
			<h2>Scanning</h2>
			<label class="chk"><input type="checkbox" bind:checked={cfg.scan.watch} /> Live-watch folders (auto-index new/changed files — no manual rescan)</label>
			<label class="chk"><input type="checkbox" bind:checked={cfg.scan.removeMissing} /> Remove DB entries for files deleted on disk</label>
			<label class="chk"><input type="checkbox" bind:checked={cfg.scan.followSymlinks} /> Follow symlinks</label>
			<div class="row"><span class="k">Thumbnail quality (grid)</span><input type="number" min="1" max="100" bind:value={cfg.thumbnails.grid.quality} /></div>
			<div class="row"><span class="k">Preview long edge (px)</span><input type="number" min="320" bind:value={cfg.thumbnails.preview.longEdge} /></div>
		</section>

		<!-- MAP -->
		<section>
			<h2>Map</h2>
			<label class="chk"><input type="checkbox" bind:checked={cfg.map.enabled} /> Enable map view (uses OpenStreetMap tiles when open)</label>
		</section>

		<!-- PLACES / GEOCODING -->
		<section>
			<h2>Places <span class="badge">off by default</span></h2>
			<p class="hint">
				Group geotagged photos by location name. <strong>Offline</strong> uses a small built-in city list (no
				network, approximate). <strong>Nominatim</strong> is precise but sends each photo's coordinates to
				OpenStreetMap's service, rate-limited to 1/sec — the only outbound call this adds.
			</p>
			<label class="chk"><input type="checkbox" bind:checked={cfg.geocode.enabled} /> Enable Places (reverse geocoding)</label>
			<div class="row">
				<span class="k">Provider</span>
				<select bind:value={cfg.geocode.provider}>
					<option value="offline">Offline — built-in cities (no network)</option>
					<option value="nominatim">OpenStreetMap Nominatim (network)</option>
				</select>
			</div>
			{#if cfg.geocode.provider === 'nominatim'}
				<div class="row"><span class="k">Contact email</span><input type="email" placeholder="you@example.com" bind:value={cfg.geocode.email} /></div>
			{/if}
		</section>

		<!-- AI -->
		<section>
			<h2>On-device AI <span class="badge">off by default</span></h2>
			<p class="hint">Local CLIP semantic search + face grouping. Enabling triggers a one-time model download (or place models in <code>data/models</code> for offline).</p>
			<label class="chk"><input type="checkbox" bind:checked={cfg.ai.semanticSearch} /> Semantic search</label>
			<label class="chk"><input type="checkbox" bind:checked={cfg.ai.faceGrouping} /> Face grouping (People)</label>
			<div class="row">
				<span class="k">Model source</span>
				<select bind:value={cfg.ai.modelSource}><option value="huggingface">Download from Hugging Face</option><option value="local">Local only (offline)</option></select>
			</div>
		</section>

		<!-- NETWORK / SECURITY -->
		<section>
			<h2>Network &amp; access</h2>
			<div class="row">
				<span class="k">Bind address</span>
				<select bind:value={cfg.server.host}>
					<option value="127.0.0.1">127.0.0.1 (this PC only)</option>
					<option value="0.0.0.0">0.0.0.0 (allow LAN access)</option>
				</select>
			</div>
			<div class="row"><span class="k">Port</span><input type="number" min="1" max="65535" bind:value={cfg.server.port} /></div>
			<div class="row">
				<span class="k">Access password</span>
				<input type="password" placeholder={cfg.server.passwordSet ? '•••••••• (set)' : 'none'} bind:value={newPassword} />
			</div>
			{#if cfg.server.passwordSet}
				<label class="chk"><input type="checkbox" bind:checked={clearPassword} /> Remove password</label>
			{/if}
			{#if cfg.server.host === '0.0.0.0'}
				<div class="guide">
					<ShieldAlert size={16} />
					<div>
						<strong>Enabling LAN access</strong>
						<ol>
							<li>Save, then <strong>restart</strong> the server (host changes need a restart).</li>
							<li>Find this PC's LAN IP (<code>ipconfig</code> → IPv4) and open <code>http://&lt;ip&gt;:{cfg.server.port}</code> from your phone on the same Wi-Fi.</li>
							<li>Allow the port through <strong>Windows Defender Firewall</strong> (Private networks only).</li>
							<li>Set an <strong>access password</strong> above — strongly recommended.</li>
						</ol>
					</div>
				</div>
			{/if}
		</section>

		<!-- DATA SAFETY -->
		<section>
			<h2>Backup &amp; export</h2>
			<p class="hint">Favorites, albums &amp; tags live only in the database — back them up.</p>
			<div class="btns">
				<button class="btn" onclick={backup}><Database size={16} /> Backup database</button>
				<a class="btn" href="/api/backup" download><Download size={16} /> Export JSON</a>
				<button class="btn" onclick={rescan}><RefreshCw size={16} /> Rescan now</button>
				{#if cfg.server.passwordSet}<button class="btn" onclick={logout}><LogOut size={16} /> Log out</button>{/if}
			</div>
		</section>

		<!-- STARTUP / AUTOSTART -->
		<section>
			<h2><Power size={18} /> Start on Windows login</h2>
			<p class="hint">
				A launcher script ships with the app: <code>start-lgallery.cmd</code>. It builds (first run) and
				serves the gallery, then opens your browser. To run it automatically at login:
			</p>
			<ol class="steps">
				<li>Press <kbd>Win</kbd>+<kbd>R</kbd>, type <code>shell:startup</code>, press Enter.</li>
				<li>Copy <code>start-lgallery.cmd</code> (or a shortcut to it) into that folder. For no console window, use <code>start-lgallery-hidden.vbs</code> instead.</li>
			</ol>
			<div class="kv">
				<span class="k">App location</span>
				<code class="path">{data.appDir}</code>
				<button class="btn" onclick={() => copy(data.appDir)} title="Copy path"><Copy size={14} /></button>
			</div>
			<div class="kv">
				<span class="k">Launcher</span>
				<code class="path">{data.appDir}\start-lgallery.cmd</code>
				<button class="btn" onclick={() => copy(`${data.appDir}\\start-lgallery.cmd`)} title="Copy"><Copy size={14} /></button>
			</div>
			<p class="hint">
				Serves on <code>http://{cfg.server.host}:{cfg.server.port}</code> — the launcher's <code>PORT</code>/<code>HOST</code>
				default to 4173/127.0.0.1; keep them in sync with the values above (edit the .cmd if you change the port).
				{#if copied}<span class="ok">✓ copied</span>{/if}
			</p>
		</section>
	</div>
</div>

<style>
	.page { display: flex; flex-direction: column; height: 100%; }
	.bar {
		display: flex; align-items: center; justify-content: space-between;
		padding: 12px 18px; flex-shrink: 0; border-bottom: 1px solid var(--lg-border);
		background: color-mix(in srgb, var(--lg-bg) 78%, transparent);
		backdrop-filter: blur(10px);
	}
	h1 { font-size: 1.4rem; font-weight: 700; letter-spacing: -0.01em; }
	.head-actions { display: flex; align-items: center; gap: 12px; }
	.msg { font-size: 0.85rem; color: #16a34a; }
	.scroll { flex: 1; overflow-y: auto; padding: 18px; max-width: 760px; }
	section { margin-bottom: 28px; }
	h2 { font-size: 1.05rem; font-weight: 700; margin-bottom: 6px; display: flex; align-items: center; gap: 8px; }
	.badge { font-size: 0.65rem; font-weight: 600; background: #eab308; color: #422006; padding: 2px 6px; border-radius: 999px; text-transform: uppercase; }
	.hint { font-size: 0.85rem; color: var(--lg-text-muted); margin-bottom: 10px; line-height: 1.5; }
	.root { display: flex; gap: 8px; align-items: center; margin-bottom: 8px; }
	.row { display: flex; align-items: center; justify-content: space-between; gap: 12px; margin: 8px 0; max-width: 460px; }
	.row .k { color: var(--lg-text-muted); }
	input, select {
		padding: 7px 10px; border-radius: var(--lg-r-md); border: 1px solid var(--lg-border);
		background: var(--lg-bg); color: var(--lg-text);
	}
	input:focus-visible, select:focus-visible { outline: none; border-color: var(--lg-accent); box-shadow: 0 0 0 3px var(--lg-accent-weak); }
	.grow { flex: 1; } .lbl { width: 120px; }
	.chk { display: flex; align-items: center; gap: 8px; margin: 8px 0; font-size: 0.9rem; }
	.chk input { width: auto; }
	.icon { display: flex; padding: 7px; border: none; border-radius: var(--lg-r-md); background: transparent; color: inherit; cursor: pointer; }
	.icon.danger:hover { background: var(--lg-danger); color: #fff; }
	.add {
		display: inline-flex; align-items: center; gap: 6px; padding: 7px 12px;
		border: 1px dashed var(--lg-border); border-radius: var(--lg-r-md); background: transparent;
		color: inherit; cursor: pointer; margin-top: 4px;
	}
	.add:hover { background: var(--lg-surface-hover); }
	.primary {
		display: flex; align-items: center; gap: 6px; padding: 8px 14px; border: none;
		border-radius: var(--lg-r-md); background: var(--lg-accent); color: var(--lg-accent-text);
		cursor: pointer; font-weight: 600;
	}
	.primary:disabled { opacity: 0.6; }
	.guide, .steps { font-size: 0.85rem; }
	.guide {
		display: flex; gap: 10px; margin-top: 10px; padding: 12px;
		border-radius: var(--lg-r-lg); background: rgba(234, 179, 8, 0.12); color: inherit;
	}
	.guide ol, .steps { margin: 6px 0 10px; padding-left: 18px; }
	.guide li, .steps li { margin: 4px 0; }
	.btns { display: flex; flex-wrap: wrap; gap: 10px; }
	.kv { display: flex; align-items: center; gap: 10px; margin: 8px 0; }
	.kv .k { width: 100px; flex-shrink: 0; color: var(--lg-text-muted); font-size: 0.85rem; }
	.path {
		flex: 1; overflow-x: auto; white-space: nowrap; padding: 6px 9px;
		background: var(--lg-surface-2); border-radius: var(--lg-r-sm); font-size: 0.8rem;
	}
	.ok { color: #16a34a; margin-left: 6px; }
	kbd {
		font-family: inherit; font-size: 0.78rem; background: var(--lg-surface-2);
		border: 1px solid var(--lg-border); border-radius: var(--lg-r-sm); padding: 1px 5px;
	}
	code { background: var(--lg-surface-2); padding: 1px 5px; border-radius: var(--lg-r-sm); }
</style>
```

### `src/routes/tags/+page.svelte`

```svelte
<script lang="ts">
	import { onMount } from 'svelte';
	import { page } from '$app/state';
	import MediaGridView from '$components/grid/MediaGridView.svelte';
	import PageHeader from '$components/common/PageHeader.svelte';
	import EmptyState from '$components/common/EmptyState.svelte';
	import DensityToggle from '$components/common/DensityToggle.svelte';
	import { gallery } from '$client/state/gallery.svelte';
	import { api } from '$client/api';
	import type { Tag } from '$shared/types';
	import { Tag as TagIcon, X } from '@lucide/svelte';

	let tags = $state<Tag[]>([]);
	let selected = $state<number | null>(null);
	let ready = $state(false);

	async function loadTags() {
		tags = (await api.tags()).tags;
	}

	async function select(id: number) {
		selected = id;
		ready = false;
		gallery.setSource((c) => api.search({ tag: id, archived: false, curMs: c?.curMs, curId: c?.curId }));
		gallery.seed(await api.search({ tag: id }));
		ready = true;
	}

	async function removeTag(t: Tag) {
		if (!confirm(`Delete the tag "${t.name}"? This removes it from all photos (the photos stay).`)) return;
		await api.deleteTag(t.id);
		if (selected === t.id) selected = null;
		await loadTags();
	}

	onMount(async () => {
		await loadTags();
		const initial = Number(page.url.searchParams.get('tag'));
		if (Number.isInteger(initial) && initial > 0) select(initial);
	});

	const activeName = $derived(tags.find((t) => t.id === selected)?.name ?? '');
</script>

<div class="page">
	<PageHeader title={selected ? `Tag: ${activeName}` : 'Tags'} icon={TagIcon}>
		{#snippet actions()}<DensityToggle />{/snippet}
	</PageHeader>

	<div class="cloud">
		{#if tags.length === 0}
			<span class="hint">No tags yet — add tags from a photo's Info panel (press <kbd>i</kbd> in the viewer).</span>
		{:else}
			{#each tags as t (t.id)}
				<span class="tag" class:active={selected === t.id}>
					<button class="name" onclick={() => select(t.id)}>{t.name}<span class="n">{t.count}</span></button>
					<button class="del" onclick={() => removeTag(t)} aria-label={`Delete tag ${t.name}`}><X size={13} /></button>
				</span>
			{/each}
		{/if}
	</div>

	<div class="grid-wrap">
		{#if selected == null}
			<EmptyState icon={TagIcon} title="Pick a tag" description="Select a tag above to see the photos that carry it." />
		{:else if ready && gallery.items.length === 0}
			<EmptyState icon={TagIcon} title="Nothing tagged “{activeName}” yet" description="Add this tag to photos from the Info panel." />
		{:else}
			<MediaGridView />
		{/if}
	</div>
</div>

<style>
	.page {
		display: flex;
		flex-direction: column;
		height: 100%;
	}
	.cloud {
		display: flex;
		flex-wrap: wrap;
		gap: 8px;
		padding: 4px 16px 12px;
		border-bottom: 1px solid var(--lg-border);
	}
	.hint {
		color: var(--lg-text-muted);
		font-size: 0.9rem;
	}
	.tag {
		display: flex;
		align-items: center;
		border-radius: 999px;
		background: var(--lg-surface-2);
		border: 1px solid var(--lg-border);
		overflow: hidden;
	}
	.tag.active {
		background: var(--lg-accent-weak);
		border-color: var(--lg-accent);
	}
	.name {
		display: flex;
		align-items: center;
		gap: 7px;
		padding: 6px 4px 6px 12px;
		border: none;
		background: transparent;
		color: var(--lg-text);
		cursor: pointer;
		font-size: 0.88rem;
	}
	.tag.active .name {
		color: var(--lg-accent);
		font-weight: 600;
	}
	.n {
		color: var(--lg-text-muted);
		font-size: 0.76rem;
	}
	.del {
		display: flex;
		border: none;
		background: transparent;
		color: var(--lg-text-muted);
		cursor: pointer;
		padding: 6px 8px 6px 4px;
	}
	.del:hover {
		color: var(--lg-danger);
	}
	.grid-wrap {
		flex: 1;
		min-height: 0;
		position: relative;
	}
</style>
```

### `src/routes/trash/+page.server.ts`

```ts
import type { PageServerLoad } from './$types';
import { getDb } from '$server/db/index';
import { getTrash } from '$server/db/queries';

export const load: PageServerLoad = async () => {
	return { items: getTrash(getDb()) };
};
```

### `src/routes/trash/+page.svelte`

```svelte
<script lang="ts">
	import { invalidateAll } from '$app/navigation';
	import type { TrashItem } from '$shared/types';
	import { formatBytes } from '$shared/format';
	import { api } from '$client/api';
	import PageHeader from '$components/common/PageHeader.svelte';
	import EmptyState from '$components/common/EmptyState.svelte';
	import { Undo2, Trash2, CheckSquare } from '@lucide/svelte';

	let { data }: { data: { items: TrashItem[] } } = $props();
	let selected = $state<Set<number>>(new Set());
	let busy = $state(false);

	function toggle(mediaId: number | null) {
		if (mediaId == null) return;
		const s = new Set(selected);
		s.has(mediaId) ? s.delete(mediaId) : s.add(mediaId);
		selected = s;
	}
	function selectAll() {
		selected = new Set(data.items.map((i) => i.mediaId).filter((x): x is number => x != null));
	}

	async function restore() {
		const ids = [...selected];
		if (!ids.length) return;
		await run(() => api.restore(ids));
	}
	async function purge() {
		const ids = [...selected];
		if (!ids.length) return;
		if (!confirm(`Permanently delete ${ids.length} item(s)? This cannot be undone.`)) return;
		await run(() => api.permanentDelete(ids));
	}
	async function run(fn: () => Promise<unknown>) {
		busy = true;
		try {
			await fn();
			selected = new Set();
			await invalidateAll();
		} catch (e) {
			alert(e instanceof Error ? e.message : 'Action failed');
		} finally {
			busy = false;
		}
	}
</script>

<div class="page">
	<PageHeader title="Trash" icon={Trash2}>
		{#snippet actions()}
			{#if data.items.length}
				<button class="btn" onclick={selectAll}><CheckSquare size={16} /> Select all</button>
				<button class="btn" onclick={restore} disabled={busy || selected.size === 0}><Undo2 size={16} /> Restore ({selected.size})</button>
				<button class="btn btn-danger" onclick={purge} disabled={busy || selected.size === 0}><Trash2 size={16} /> Delete forever</button>
			{/if}
		{/snippet}
	</PageHeader>
	<div class="scroll">
		{#if data.items.length === 0}
			<EmptyState
				icon={Trash2}
				title="Trash is empty."
				description="Deleted photos move here and can be restored."
			/>
		{:else}
			<ul class="grid">
				{#each data.items as t (t.id)}
					<li>
						<button
							class="cell"
							class:sel={t.mediaId != null && selected.has(t.mediaId)}
							onclick={() => toggle(t.mediaId)}
							title={t.originalPath}
						>
							{#if t.mediaId}
								<img src="/api/media/{t.mediaId}/thumb?size=grid" alt="" loading="lazy" />
							{:else}
								<div class="ph"></div>
							{/if}
							<span class="fn">{t.filename}</span>
							<span class="sz">{formatBytes(t.sizeBytes)}</span>
						</button>
					</li>
				{/each}
			</ul>
		{/if}
	</div>
</div>

<style>
	.page {
		display: flex;
		flex-direction: column;
		height: 100%;
	}
	.scroll {
		flex: 1;
		overflow-y: auto;
		padding: 18px;
	}
	.grid {
		list-style: none;
		margin: 0;
		padding: 0;
		display: grid;
		grid-template-columns: repeat(auto-fill, minmax(150px, 1fr));
		gap: 12px;
	}
	.cell {
		width: 100%;
		border: 2px solid transparent;
		border-radius: var(--lg-r-md);
		overflow: hidden;
		padding: 0;
		background: var(--lg-surface-2);
		cursor: pointer;
		display: block;
	}
	.cell.sel {
		border-color: var(--lg-accent);
	}
	.cell img,
	.cell .ph {
		width: 100%;
		aspect-ratio: 1;
		object-fit: cover;
		display: block;
		opacity: 0.85;
	}
	.fn {
		display: block;
		font-size: 0.78rem;
		padding: 4px 6px 0;
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
		text-align: left;
	}
	.sz {
		display: block;
		font-size: 0.7rem;
		color: var(--lg-text-muted);
		padding: 0 6px 6px;
		text-align: left;
	}
</style>
```

### `src/service-worker.ts`

```ts
/// <reference types="@sveltejs/kit" />
/// <reference lib="webworker" />

/**
 * Service worker: precache the app shell + built assets for instant repeat loads and
 * offline browsing, and cache-first the (immutable) thumbnail responses. Fully local —
 * no external requests are introduced here. See docs/05-PERFORMANCE.md.
 */
import { build, files, version } from '$service-worker';

const sw = self as unknown as ServiceWorkerGlobalScope;

const APP_CACHE = `lg-app-${version}`;
const THUMB_CACHE = `lg-thumbs`;
const ASSETS = [...build, ...files];

sw.addEventListener('install', (event) => {
	event.waitUntil(caches.open(APP_CACHE).then((c) => c.addAll(ASSETS)).then(() => sw.skipWaiting()));
});

sw.addEventListener('activate', (event) => {
	event.waitUntil(
		caches
			.keys()
			.then((keys) =>
				Promise.all(keys.filter((k) => k !== APP_CACHE && k !== THUMB_CACHE).map((k) => caches.delete(k)))
			)
			.then(() => sw.clients.claim())
	);
});

sw.addEventListener('fetch', (event) => {
	const req = event.request;
	if (req.method !== 'GET') return;
	const url = new URL(req.url);
	if (url.origin !== location.origin) return; // never intercept cross-origin (e.g. map tiles)

	// Built assets / static files → cache-first.
	if (ASSETS.includes(url.pathname)) {
		event.respondWith(caches.match(req).then((hit) => hit ?? fetch(req)));
		return;
	}

	// Thumbnails → stale-while-revalidate: serve the cache instantly, refresh in the background so
	// an edited/replaced photo (same URL, new mtime) propagates within one load. The server still
	// validates via ETag. The cache is capped so a long browse can't grow it without bound.
	if (url.pathname.startsWith('/api/media/') && url.pathname.includes('/thumb')) {
		event.respondWith(
			caches.open(THUMB_CACHE).then(async (cache) => {
				const hit = await cache.match(req);
				const fetching = fetch(req)
					.then((res) => {
						if (res.ok) {
							cache.put(req, res.clone());
							void trimThumbCache(cache);
						}
						return res;
					})
					.catch(() => hit ?? Response.error());
				return hit ?? fetching;
			})
		);
	}
	// Everything else (API data, originals, video) goes straight to the network.
});

// Keep the thumbnail cache bounded (simple FIFO trim of oldest entries).
const THUMB_CACHE_MAX = 1500;
async function trimThumbCache(cache: Cache): Promise<void> {
	const keys = await cache.keys();
	if (keys.length <= THUMB_CACHE_MAX) return;
	for (let i = 0; i < keys.length - THUMB_CACHE_MAX; i++) await cache.delete(keys[i]);
}
```

### `start.mjs`

```js
/**
 * Production entry (`bun run start` / `node start.mjs`). sharp and ffmpeg dispatch their work to the
 * libuv threadpool, whose size (default 4) is read once when libuv first initializes. We set
 * UV_THREADPOOL_SIZE here — BEFORE importing the adapter-node build that starts the server — so a
 * large thumbnail backfill can actually use all cores. Setting it after a threadpool task has run
 * would be a no-op, hence this thin launcher in front of `build/index.js`.
 */
import os from 'node:os';

if (!process.env.UV_THREADPOOL_SIZE) {
	process.env.UV_THREADPOOL_SIZE = String(Math.max(8, (os.cpus()?.length ?? 4) * 2));
}

await import('./build/index.js');
```

### `start-lgallery.cmd`

```bat
@echo off
REM ============================================================================
REM  LGallery launcher — starts the local gallery server, then opens your browser.
REM  Self-locating: it always runs from the folder this .cmd lives in, so you can
REM  drop it (or a shortcut to it) into  shell:startup  to launch LGallery on login.
REM
REM  To autostart on Windows:
REM    1) Press Win+R, type  shell:startup , press Enter.
REM    2) Copy this file (or a shortcut to it) into that folder.
REM  Tip: to run without a console window, make a shortcut and set "Run: Minimized",
REM       or wrap it with the included start-lgallery-hidden.vbs.
REM ============================================================================

cd /d "%~dp0"

REM Server bind — keep in sync with "server.port"/"server.host" in lgallery.config.json.
if "%PORT%"=="" set PORT=4173
if "%HOST%"=="" set HOST=127.0.0.1
set NODE_ENV=production

REM Size the libuv threadpool so sharp/ffmpeg can use all cores during thumbnail backfill.
REM (Read once at process start, so it must be set BEFORE node launches.)
if "%UV_THREADPOOL_SIZE%"=="" set UV_THREADPOOL_SIZE=16

REM Build the production bundle on first run (or after updates) if it's missing.
if not exist "build\index.js" (
  echo [LGallery] First run - building...
  call bun run build
)

REM Open the gallery in the default browser a moment after the server starts.
start "" /b cmd /c "timeout /t 2 >nul & start http://%HOST%:%PORT%/"

echo [LGallery] Serving http://%HOST%:%PORT%/  (close this window to stop)
node start.mjs
```

### `start-lgallery-hidden.vbs`

```vbnet
' Launches start-lgallery.cmd with no visible console window (for silent autostart).
' Put this (or a shortcut to it) in shell:startup to run LGallery hidden on login.
Set sh = CreateObject("WScript.Shell")
sh.CurrentDirectory = CreateObject("Scripting.FileSystemObject").GetParentFolderName(WScript.ScriptFullName)
sh.Run "cmd /c start-lgallery.cmd", 0, False
```

### `static/favicon.svg`

```xml
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" role="img" aria-label="LGallery">
  <defs>
    <linearGradient id="lg-bg" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#3b82f6" />
      <stop offset="1" stop-color="#7c3aed" />
    </linearGradient>
  </defs>
  <rect width="64" height="64" rx="15" fill="url(#lg-bg)" />
  <!-- photo scene: sun + mountains -->
  <circle cx="21" cy="24" r="6" fill="#fde047" />
  <path d="M8 52 L24 31 L34 43 L41 35 L56 52 Z" fill="#ffffff" fill-opacity="0.96" />
  <!-- video play badge -->
  <circle cx="46" cy="19" r="10" fill="#ffffff" />
  <path d="M42.5 13.5 L53 19 L42.5 24.5 Z" fill="#2563eb" />
</svg>
```

### `static/manifest.webmanifest`

```json
{
	"name": "LGallery",
	"short_name": "LGallery",
	"description": "Local, private photo & video gallery",
	"start_url": "/",
	"display": "standalone",
	"background_color": "#0a0a0a",
	"theme_color": "#111827",
	"icons": [
		{ "src": "/favicon.svg", "sizes": "any", "type": "image/svg+xml", "purpose": "any" }
	]
}
```

### `svelte.config.js`

```js
import adapter from '@sveltejs/adapter-node';
import { vitePreprocess } from '@sveltejs/vite-plugin-svelte';

/** @type {import('@sveltejs/kit').Config} */
const config = {
	preprocess: vitePreprocess(),
	kit: {
		// precompress serves the prebuilt .br/.gz assets for the app shell + static files.
		adapter: adapter({ precompress: true }),
		alias: {
			$shared: 'src/lib/shared',
			$server: 'src/lib/server',
			$client: 'src/lib/client',
			$components: 'src/lib/components'
		}
	},
	compilerOptions: {
		// Svelte 5 runes mode
		runes: true
	}
};

export default config;
```

### `token-usage.html`

```html
<!doctype html>
<html lang="en">
	<head>
		<meta charset="utf-8" />
		<meta name="viewport" content="width=device-width, initial-scale=1" />
		<meta name="referrer" content="no-referrer" />
		<title>Token Usage</title>
		<style>
			/* Fully self-contained — no external fonts, scripts, or styles (local-only). */
			:root {
				color-scheme: light dark;
				--bg: #f8fafc;
				--card: #ffffff;
				--border: #e2e8f0;
				--text: #0f172a;
				--muted: #64748b;
				--accent: #2563eb;
				--accent-soft: #eff6ff;
			}
			@media (prefers-color-scheme: dark) {
				:root {
					--bg: #0a0a0a;
					--card: #171717;
					--border: #2a2a2a;
					--text: #f5f5f5;
					--muted: #a3a3a3;
					--accent: #3b82f6;
					--accent-soft: #1e293b;
				}
			}
			* {
				box-sizing: border-box;
			}
			body {
				margin: 0;
				min-height: 100vh;
				display: flex;
				align-items: flex-start;
				justify-content: center;
				background: var(--bg);
				color: var(--text);
				font-family: ui-sans-serif, system-ui, -apple-system, 'Segoe UI', Roboto, sans-serif;
				padding: 2.5rem 1rem;
			}
			.card {
				width: 100%;
				max-width: 30rem;
				background: var(--card);
				border: 1px solid var(--border);
				border-radius: 1rem;
				padding: 1.75rem;
				box-shadow: 0 1px 3px rgba(0, 0, 0, 0.08);
			}
			h1 {
				margin: 0 0 0.25rem;
				font-size: 1.4rem;
			}
			p.sub {
				margin: 0 0 1.5rem;
				color: var(--muted);
				font-size: 0.875rem;
			}
			label {
				display: block;
				font-size: 0.8rem;
				font-weight: 600;
				color: var(--muted);
				margin: 0 0 0.35rem;
				text-transform: uppercase;
				letter-spacing: 0.03em;
			}
			.field {
				margin-bottom: 1rem;
			}
			input[type='number'] {
				width: 100%;
				padding: 0.6rem 0.75rem;
				font-size: 1rem;
				border: 1px solid var(--border);
				border-radius: 0.6rem;
				background: var(--bg);
				color: var(--text);
			}
			input[type='number']:focus {
				outline: 2px solid var(--accent);
				outline-offset: 1px;
			}
			.row {
				display: flex;
				gap: 1rem;
			}
			.row .field {
				flex: 1;
			}
			.totals {
				margin-top: 1.25rem;
				border-top: 1px solid var(--border);
				padding-top: 1.25rem;
			}
			.line {
				display: flex;
				justify-content: space-between;
				align-items: baseline;
				padding: 0.4rem 0;
				font-variant-numeric: tabular-nums;
			}
			.line .k {
				color: var(--muted);
			}
			.line .v {
				font-weight: 600;
				font-size: 1.05rem;
			}
			.total {
				margin-top: 0.5rem;
				background: var(--accent-soft);
				border-radius: 0.75rem;
				padding: 0.85rem 1rem;
			}
			.total .k {
				color: var(--text);
				font-weight: 600;
			}
			.total .v {
				color: var(--accent);
				font-size: 1.5rem;
				font-weight: 700;
			}
			details {
				margin-top: 1.25rem;
			}
			summary {
				cursor: pointer;
				color: var(--muted);
				font-size: 0.85rem;
			}
			.cost {
				margin-top: 0.75rem;
			}
			.hint {
				font-size: 0.7rem;
				color: var(--muted);
				margin-top: 0.25rem;
			}
			footer {
				margin-top: 1.5rem;
				font-size: 0.7rem;
				color: var(--muted);
				text-align: center;
			}
			button.reset {
				margin-top: 1rem;
				width: 100%;
				padding: 0.55rem;
				border: 1px solid var(--border);
				border-radius: 0.6rem;
				background: transparent;
				color: var(--muted);
				cursor: pointer;
				font-size: 0.85rem;
			}
			button.reset:hover {
				color: var(--text);
				border-color: var(--accent);
			}
		</style>
	</head>
	<body>
		<main class="card">
			<h1>Token Usage</h1>
			<p class="sub">Enter input &amp; output token counts to see the total consumed. Runs entirely in your browser — nothing is sent anywhere.</p>

			<div class="row">
				<div class="field">
					<label for="inTok">Input tokens</label>
					<input id="inTok" type="number" min="0" step="1" inputmode="numeric" placeholder="0" />
				</div>
				<div class="field">
					<label for="outTok">Output tokens</label>
					<input id="outTok" type="number" min="0" step="1" inputmode="numeric" placeholder="0" />
				</div>
			</div>

			<div class="totals">
				<div class="line"><span class="k">Input</span><span class="v" id="inOut">0</span></div>
				<div class="line"><span class="k">Output</span><span class="v" id="outOut">0</span></div>
				<div class="line total"><span class="k">Total consumed</span><span class="v" id="totalOut">0</span></div>
			</div>

			<details>
				<summary>Estimate cost (optional)</summary>
				<div class="cost">
					<div class="row">
						<div class="field">
							<label for="inRate">Input $ / 1M</label>
							<input id="inRate" type="number" min="0" step="0.01" placeholder="0.00" />
						</div>
						<div class="field">
							<label for="outRate">Output $ / 1M</label>
							<input id="outRate" type="number" min="0" step="0.01" placeholder="0.00" />
						</div>
					</div>
					<div class="line total">
						<span class="k">Estimated cost</span><span class="v" id="costOut">$0.00</span>
					</div>
					<p class="hint">Rates are per 1,000,000 tokens. Fill them in for your model/provider.</p>
				</div>
			</details>

			<button class="reset" id="resetBtn" type="button">Reset</button>
			<footer>Local utility — no network, no storage, no telemetry.</footer>
		</main>

		<script>
			(function () {
				const $ = (id) => document.getElementById(id);
				const els = {
					inTok: $('inTok'),
					outTok: $('outTok'),
					inRate: $('inRate'),
					outRate: $('outRate'),
					inOut: $('inOut'),
					outOut: $('outOut'),
					totalOut: $('totalOut'),
					costOut: $('costOut'),
					reset: $('resetBtn')
				};
				const fmt = new Intl.NumberFormat();
				const num = (el) => {
					const n = parseFloat(el.value);
					return Number.isFinite(n) && n >= 0 ? n : 0;
				};

				function render() {
					const input = Math.round(num(els.inTok));
					const output = Math.round(num(els.outTok));
					const total = input + output;
					els.inOut.textContent = fmt.format(input);
					els.outOut.textContent = fmt.format(output);
					els.totalOut.textContent = fmt.format(total);

					const cost = (input / 1e6) * num(els.inRate) + (output / 1e6) * num(els.outRate);
					els.costOut.textContent =
						'$' + cost.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 4 });
				}

				['inTok', 'outTok', 'inRate', 'outRate'].forEach((k) =>
					els[k].addEventListener('input', render)
				);
				els.reset.addEventListener('click', () => {
					['inTok', 'outTok', 'inRate', 'outRate'].forEach((k) => (els[k].value = ''));
					render();
				});
				render();
			})();
		</script>
	</body>
</html>
```

### `tsconfig.json`

```json
{
  "extends": "./.svelte-kit/tsconfig.json",
  "compilerOptions": {
    "allowJs": true,
    "checkJs": true,
    "esModuleInterop": true,
    "forceConsistentCasingInFileNames": true,
    "resolveJsonModule": true,
    "skipLibCheck": true,
    "sourceMap": true,
    "strict": true,
    "moduleResolution": "bundler"
  }
}
```

### `vite.config.ts`

```ts
/// <reference types="vitest/config" />
import { sveltekit } from '@sveltejs/kit/vite';
import tailwindcss from '@tailwindcss/vite';
import { defineConfig } from 'vitest/config';

export default defineConfig({
	plugins: [tailwindcss(), sveltekit()],
	// Native modules must stay external (never bundled into the SSR build). The AI packages are
	// OPTIONAL and may be absent — keep them external so the build doesn't try to resolve them;
	// the runtime import() is guarded and degrades gracefully when they aren't installed.
	ssr: {
		external: [
			'better-sqlite3',
			'sharp',
			'fluent-ffmpeg',
			'ffmpeg-static',
			'ffprobe-static',
			'archiver',
			'@huggingface/transformers',
			'sqlite-vec'
		]
	},
	test: {
		include: ['src/**/*.{test,spec}.{js,ts}'],
		// Pure shared code + server modules run under node; component tests can opt into jsdom per-file.
		environment: 'node',
		coverage: {
			provider: 'v8',
			reporter: ['text', 'html'],
			// Cover the logic-heavy server + shared code (Svelte components are exercised via
			// the runtime smokes, not vitest).
			// Server + shared logic is unit-tested under node; client/* is browser code exercised
			// via runtime smokes, not vitest, so it's excluded from the coverage denominator.
			include: ['src/lib/server/**', 'src/lib/shared/**'],
			exclude: ['**/*.test.ts', '**/*.spec.ts', '**/*.svelte', 'src/lib/server/ai/**']
		}
	}
});
```

## Appendix B — Coverage & review notes

> _Editor's note: this is the raw automated-review output, kept for transparency. Two findings have been **fixed in the body above** — `editService.ts` now appears in the §6 build order, and the stray `scripts/gen-source-appendix.sh` subsection (this document's own generator, not an app file) was removed. Clarifications on the rest: (a) the **authoritative test total is 128**, as reported by `vitest run` — the review's static count of 138 over-counted `it(`/`test(` substrings; the §10.3 table and headline are correct. (b) `data/` is created automatically at startup by `getDb()` (`fs.mkdirSync(..., { recursive: true })`), so the absent `data/.gitkeep` does not affect a rebuild._

The guide covers the application's 188 tracked files at a high level, and Appendix A is stated to carry every file verbatim. Coverage of the **tracked** set is essentially complete (every tracked file's role is at least named in §1.6 layout map or the per-section narratives). However, there are concrete gaps, one factual error repeated several times, and a phantom file that cannot be in Appendix A.

### Files not explicitly covered

- **`src/lib/server/media/editService.ts`** — has its own responsibility entry **missing from the §6 build order**. §6's intro enumerates the media files to build in order (`render-core → thumb-worker → thumbnailService → workerPool → exif/hash/video → pipeline → fileService → streamService`) and omits `editService.ts`. It is only ever referenced indirectly via its exports `renderEditedThumbs` / `exportEditedCopy` (in §6.7, §7.3) and lumped as "edit services" in the §1.6 list. A rebuilder following §6's stated order never creates it, yet `pipeline.ts` and the `/edit` endpoints import it. Its build position (before `pipeline.ts`, after `render-core.mjs`/`thumbnailService.ts`) and exact exports (`renderEditedThumbs(id, srcPath, ops, sizes)`, `exportEditedCopy(srcPath, ops, destPath)`) are never spelled out.
- **`scripts/gen-source-appendix.sh` is NOT a tracked file** — it is untracked (`git status` = `??`). The guide §10.1 documents it and says "Reproduce verbatim from Appendix A," but Appendix A only carries the 188 tracked files, so it cannot be there. Either drop it from the guide or note it is untracked/out-of-band.
- The 10 `.claude/memory/*` files are referenced only generically ("project status + key-decision + feedback memory notes" in §1.6; "the entire `.claude/memory/*` … reproduced verbatim" in §10.5). Individual roles (`MEMORY.md`, `reference-docs.md`, `project-overview.md`, the five `feedback-*.md`) are not described. Acceptable as docs, but noted.

### Gaps / corrections

1. **Test count is wrong (build-verification gotcha).** The guide repeatedly states "98 → 128 tests," labels the `test` script "(98 → 128)," and gives a per-suite table summing to **128**. Actual `it()/test()` count is **138**. The error is concentrated in **`walker.test.ts`: guide says 5, actual is 15** (the table's other rows sum correctly to the rest). A rebuilder verifying against "128 passing" would wrongly conclude failure. Fix the table (walker = 15) and the totals (138).
2. **`data/.gitkeep` does not exist in the repo.** §1.6 says `data/` "ships with `.gitkeep`" and §2.6 describes `!data/.gitkeep`. The `.gitignore` negation pattern is present, but no `data/.gitkeep` is tracked, so `data/` is not preserved by an empty-checkout. Likewise the `.gitignore` negations `!.vscode/extensions.json` and `!.env.example` exist but those files are **not tracked** — harmless, but the prose implies they ship.
3. **§3.3 `canonicalRoot` realpath claim is slightly off vs Golden Rule 5 / §4.1.** §3.3 correctly states configService uses `fs.realpathSync.native` (verified, line 66). But Golden Rule 5 and §5/§8 lean on the *async* `fs.promises.realpath` story (`paths.ts` `realRootCanon`). Both are true in their own files, but the guide asserts a single canonical-root resolution shared by scanner + watcher + allow-list ("resolve a single `canonicalRoot` once" — §10.6 gotcha 5), whereas the repo actually has **two** canonicalization paths: sync `.native` in `configService` and async `fs.promises.realpath` in `paths.ts`. §4.1 documents this asymmetry correctly; §10.6 gotcha 5 oversimplifies it into one resolution. Minor, but a rebuilder could wrongly unify them.

No ordering problem would *hard-fail* a rebuild except the `editService.ts` omission in §6's build order — because `pipeline.ts` (built per §6) imports `./editService` via dynamic `import()`, the module must exist or the edit path throws at runtime (typecheck still passes since the import is dynamic). Everything else (toolchain → config/schema → migrations v1→v6 → server foundation → scan → media → queries/API → geo/ai → client → scripts) is correctly ordered and the dependency-version, `UV_THREADPOOL_SIZE`, zod-v3, cookie-override, migration-append-only, and realpath gotchas are accurate.

Appendix A still carries every one of the 188 tracked files verbatim; the gaps above are about the *narrative* coverage, not the verbatim source dump (except the untracked `gen-source-appendix.sh`, which is neither narrated correctly nor present in Appendix A).
