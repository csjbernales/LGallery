# Task 4: Media Pipeline & Scanning Subsystem

This section details the high-throughput components responsible for processing raw media files into usable indexed data (thumbnails, hashes, metadata). These services use the foundation layers defined in Task 3 and rely heavily on external binaries (`sharp`, `ffmpeg`).

## ⚙️ Media Processing Core
The `src/lib/server/media` module manages all file transformations.

### Components:
*   **Worker Pool**: Uses a worker thread pool to execute tasks concurrently, preventing the main request handling loop from blocking during bulk processing.
*   **Thumbnail Generation**: Generates WebP format images for different use cases (grid, preview). The process must handle potential failures (`thumb_status` update) and queue retries using backoff logic defined in v3 migrations.
*   **Metadata Extraction**: Uses `exifr` to pull EXIF data (GPS, camera make/model, time) robustly.
*   **Hashing**: Calculates multiple hashes for deduplication: `quick_hash`, `phash`, and `blurhash`.

### Video Handling:
*   Requires `fluent-ffmpeg` integration.
*   The pipeline must calculate duration and extract a representative frame (e.g., the 10th percentile frame, or using storyboard frames).

## 🔍 Scanning Subsystem (`src/lib/server/scan`)
Responsible for walking configured roots, detecting changes, and orchestrating processing.

### Flow:
1. **Watcher**: Uses `chokidar` to monitor root directories for real-time changes.
2. **Scanner**: The primary worker (the "Crawler"). It iterates over the filesystem, identifying new/modified files that need processing.
3. **State Management**: Updates the `scans` table and tracks files seen/added/updated/removed to ensure transactional consistency during a full scan run.

### Critical Considerations:
*   **Pairing**: Must detect Live Photo equivalents (paired media files) and update corresponding records via `live_partner_id`.
*   **Efficiency**: The scanner must be designed for background, resumable operation, using the mutex (`src/lib/server/lock.ts`) to manage its write operations against the database.

## 🗺 Geocoding and AI (Optional)
These modules handle complex, optional features that require external APIs or local machine learning resources.

*   **`geo/`**: Handles offline city lookups using pre-populated data + optional Nominatim calls. The `geocode_status` field is crucial for tracking success/failure.
*   **`ai/` (Optional)**: Supports CLIP semantic search and face grouping. This must be guarded by an explicit check of the config (`ai.semanticSearch`) and must gracefully degrade if the necessary packages (`@huggingface/transformers`, `sqlite-vec`) are not installed or available in the build environment.

---
**Next Steps:** Create the final manifest file detailing the sequence for deployment, development, testing, and verification (Task 5).