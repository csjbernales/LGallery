# Task 5: Deployment Manifest, Testing & Verification

This task summarizes the complete workflow—from initial installation to production deployment and continuous testing—using all previously defined components and rules.

## 🚀 Development Workflow (Daily Use)
The development environment is managed by `vite dev` via Bun:
1.  **Start Dev Server**: `bun run dev` — Runs SvelteKit in development mode, serving content from `src/`. The server runs on the client-side build output but uses Vite's hot module reloading.
2.  **Type Checking**: Run this periodically after making structural changes: `bun run check`. This executes `svelte-kit sync` and then `svelte-check`, ensuring all code adheres to Svelte 5 runes syntax and type definitions in `$shared`.
3.  **Testing**: Use the isolated unit testing suite (`vitest`). Coverage report generation is available via `bun run test:cov`.

## ✅ Verification (The Golden Path)
After feature completion, verification MUST include these steps:
1. **Local Build Check**: Run `bun run check` to validate code correctness and type safety against the configured aliases/runes.
2. **Full Test Suite**: Execute comprehensive unit tests using `bun run test`.
3. **Production Simulation**: Perform a dry-run build followed by serving:
    *   `bun run build` (Creates static, precompressed assets in `build/`).
    *   `node build/index.js` (Simulates the production startup sequence *without* launching a full server loop).

## 📦 Production Deployment (Production Start)
This process is linear and must respect the tooling chain:
1. **Dependency Installation**: `bun install` (Ensures all dependencies, including native modules like `better-sqlite3`, are resolved using the committed `bun.lock`).
2. **Build Assets**: `bun run build` (Compiles SvelteKit to an optimized Node server package in `build/`).
3. **Execution Launcher**: `bun run start` (This triggers the crucial step: setting `UV_THREADPOOL_SIZE` before executing `node start.mjs`, guaranteeing correct media worker initialization).

## 💡 Summary of Actions Required for New Features
1.  **Define Schema Change:** Update a migration in `src/lib/server/db/schema.ts` (e.g., v7).
2.  **Implement Logic:** Write the new service code using shared utilities (`paths.ts`, `security.ts`).
3.  **Update Migration**: Create a new script or modify `migrate.ts` to run the DDL/DML, ensuring it uses transaction blocks and respects existing version logic (append-only).
4.  **Test & Verify:** Write unit tests (`*.test.ts`) for all changes, followed by running the full test suite (`bun run test`).