# Task 3: Core Server Foundation & Shared Libraries

This section details the foundational utility layer (`src/lib/server`) that provides safety, identity, logging, and standardized HTTP responses for the entire application. Almost every API endpoint relies on these services being correct and robust.

## 🛡 Path Safety Boundary (`src/lib/server/paths.ts`)
This class manages canonical path resolution and ensures all file operations are confined to authorized "roots".

### Core Functions:
*   **`normalizePath(input)`**: Creates a consistent, comparable form (absolute, forward-slashes, lower-casing the drive letter). Must handle UNC paths (`//server/share`) correctly.
*   **`isWithin(child, parent)`**: The path traversal guard. This function must be aware of OS differences: case-insensitivity on Windows, strict prefix checking otherwise.
*   **`realPathWithinRoots()`**: The asynchronous canonicalizer. **Critical Gotcha:** Must use `fs.promises.realpath` (async) for roots and candidates to expand 8.3 short names on Windows; falling back gracefully if the target path does not exist yet is required, but the root check MUST pass the async realpath first.
*   **Sharding**: Thumbnail storage must use `thumbShard(id)` based on `(id & 0xff).toString(16).padStart(2,'0')` to prevent file name collisions in flat directories.

## 🔑 Security and Authentication (`src/lib/server/security.ts`)
Provides the mechanism for securing endpoints against unauthorized access and manipulation.

### Key Mechanisms:
*   **Password Hashing**: Uses `scrypt$<saltHex>$<hashHex>` (16-byte random salt, 64-byte key). The `verifyPassword` logic must include a specific fix to handle empty-hex stored keys correctly during comparison.
*   **Session Token Generation**: Deterministic via SHA256: `sha256('lg-session:' + passwordHash)`.
*   **CSRF Protection (`requireMutation(event)`):** Requires three checks for any mutation API call to pass (and return a 4xx error otherwise):
    1. Same Origin check (`isSameOrigin`).
    2. Double-Submit Cookie validation: `lg_csrf` cookie MUST match the `X-CSRF-Token` header value.
    3. Authentication status check (`event.locals.authed`).

## 🗄️ Logging and State Management
*   **Logger (`src/lib/server/log.ts`)**: Local, file-system only logger. Implements log rotation based on size (10MB) and file count (5 files). Writes `ISO timestamp [LEVEL] msg` plus serialized metadata. Must be resilient to disk write errors.
*   **Mutex (`src/lib/server/lock.ts`)**: Global FIFO mutex pattern (`withLock<T>(fn)`). Used to serialize critical operations (e.g., scanner database writes, full DB sweeps) to prevent race conditions between concurrent processes (scanner vs user mutation API calls).

## 🌐 HTTP Helpers and Bootstrap
*   **`src/lib/server/http.ts`**: Provides standardized error responses (`apiError(status, code, message)`) and crucial client-side data: `initialGridWidth()` reads the viewport width cookie (`lg_w`) set by the bootstrap script in `app.html`.
*   **`src/lib/server/startup.ts`**: The idempotent entry point. It MUST run `ensureStarted()` on every request to initialize system state (e.g., connect DB, load config).

---
**Next Steps:** Focus on media handling and scanning services that use these utilities (Task 4).