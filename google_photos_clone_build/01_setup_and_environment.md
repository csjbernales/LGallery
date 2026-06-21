# Task 1: Project Setup & Golden Rules

This section covers the foundational understanding of the project structure, dependencies, required tooling, and non-negotiable operational constraints (Golden Rules). This MUST be read first before attempting any build or coding.

## 📖 Overview and Goal
LGallery is a **local, self-hosted, "Google Photos"-style media gallery** that runs entirely on the owner's own machine. It indexes local images/videos and presents them as a fast, responsive, private gallery: timeline grid, albums, search, map view, lightbox, favorites, etc.

The defining product constraint is **privacy**: there is no account, no upload, no cloud backend, no CDN, no analytics, or telemetry. Media files must never leave the machine. It targets 50,000–200,000+ items via a SQLite index and virtualized scrolling.

## ✨ Golden Rules (Mandatory Constraints)
1. **Bun builds, Node serves.** Bun is used as package manager/dev runner, but the production server MUST run on Node (`node start.mjs`). Reason: `better-sqlite3` (native module) is unsupported in the Bun runtime.
2. **Zod v3 only.** The schema relies on Zod 3 semantics; upgrading to Zod 4 will break the default typing pattern.
3. **Migrations are append-only.** Only new versions can be added (v1 → v6). Never alter a shipped migration, as this corrupts upgrade paths for existing databases.
4. **Privacy Invariant.** Only three things may touch the network: (a) OpenStreetMap map tiles, (b) one-time AI model download (opt-in), and (c) Nominatim reverse-geocoding (throttled). Everything else is self-hosted.
5. **Canonical Root Paths.** All configured roots MUST be canonicalized using `fs.realpathSync.native` to correctly handle Windows 8.3 short names, which is critical for path safety across the scanner and chokidar watcher.

## 🛠 Toolchain & Dependencies (From package.json)
*   **Package Manager:** Bun (`bun@1.3.14`) is required for `bun install`.
*   **Runtime Environment:** Node.js LTS (Node 20+) is mandatory for the production server process.
*   **Critical Packages to Pin:**
    *   `zod ^3.25.76`: Use this exact version.
    *   Native dependencies: `better-sqlite3`, `sharp`, `fluent-ffmpeg` must be correctly linked and handled by the adapter-node build process.

## 🚀 Build/Run Sequence
Follow these steps in order:
1. `bun install` (Uses committed `bun.lock`).
2. `bun run build` (`vite build` creates the Node adapter output in the `build/` folder, precompressed).
3. `bun run start` (`node start.mjs`) — This script MUST set `UV_THREADPOOL_SIZE = Math.max(8, (cpuCount * 2))` before importing the built server, ensuring correct threadpool sizing for media processing (sharp/ffmpeg).

## 📂 Repository Layout
The primary application source is in `src/`. Key structural directories:
- `$shared`: Isomorphic code (`src/lib/shared`) - must have NO Node imports.
- `$server`: Server-only logic (`src/lib/server`). This contains DB access, path guards, and core services.
- `$client`: Browser-only code (`src/lib/client`).
- `$components`: Reusable Svelte 5 components.

---
**Next Steps:** Focus on defining the data model using `src/lib/shared/config-schema.ts` (Task 2).