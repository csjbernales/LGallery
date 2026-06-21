# Task 2: Configuration and Data Models

This task defines the two persistence layers—the application configuration file (`lgallery.config.json`) and the database schema (`data/lgallery.db`). These definitions are foundational to all subsequent services, especially path handling, resource scanning, and API surface design.

## 📄 A. The Application Configuration Schema
The entire config structure is defined by `src/lib/shared/config-schema.ts` using Zod v3. This schema must be replicated exactly for validation and type inference.

### Key Definitions:
*   **`extensions(def)` helper**: Canonicalizes file extensions (lowercases, strips leading dots, de-duplicates).
*   **Root Schema (`rootSchema`)**: Defines a root folder (`path`, `label`, `enabled`). This is the core source of truth for scanning.
*   **Full Config Fields**: Every default value must be honored (e.g., `scan` defaults, `thumbnails.format: 'webp'`, `server.port: 4173`).

### Critical Gotchas:
*   The hash generation (`canonicalHash`) MUST sort all arrays (`roots`, `include`, `exclude`, etc.) and drop non-source-relevant fields (like `label` on roots) to prevent spurious full rescan triggers.
*   Configuration persistence: The service must handle copying the example file, stripping potential UTF-8 BOMs from manually edited configs, and saving a **hashed version** of the configuration (`server.passwordHash`) to disk.

## 💾 B. SQLite Database Schema & Migrations
The database schema is defined by `src/lib/server/db/schema.ts` and evolved through ordered migrations in `src/lib/server/db/migrate.ts`. The target version MUST be 6.

### Core Tables (v1):
*   **`media`**: Central table. Stores path, metadata (width, height, hash), status (`meta_status`, `thumb_status`), and relational links. Includes critical fields for backfilling: `meta_attempts`/`thumb_attempts`/`next_retry_ms`.
*   **`roots`**: Defines the source folders to scan.
*   **`albums` / `album_items`**: Standard grouping structure.
*   **`trash`**: For deleted media files.

### Migration History (Append-Only):
1. **v2 (`day-index`)**: Adds `idx_media_day` on `(is_trashed, is_archived, taken_local_day)`.
2. **v3 (`retry-attempts`)**: Introduces bounded, backoff retries via `meta_attempts`, `thumb_attempts`, and `next_retry_ms`.
3. **v4 (`organize`)**: Adds `caption` (TEXT), `rating` (INT), `pick` (INT). This is the trigger point for updating FTS5 content to include caption data.
4. **v5 (`places`)**: Adds place details (`place_name`, `geocode_status`).
5. **v6 (`edits`)**: Adds editing metadata (`edit_ops TEXT`, `edited_ms`).

### Data Access Layer:
*   The DB connection module must manage PRAGMAS (WAL, foreign\_keys=ON) and the state machine via `app_state` table to ensure migrations are run only once.

---
**Next Steps:** Focus on implementing the core server services that rely heavily on these schemas (Task 3).