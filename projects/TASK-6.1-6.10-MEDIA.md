# Task 6.1-6.10: Media Pipeline & Worker Thread Pool

**Source**: `BUILD-FROM-SCRATCH.md` section 6 (`src/lib/server/media/*.{ts,mjs}`)

**Goal**: Verify complete media processing pipeline including render core, worker pool, and thumbnail services.

---

## Files to Check

| File | Path | Purpose |
|------|------|--------|
| render-core.mjs | `src/lib/server/media/render-core.mjs` | Shared ES module render engine (no node imports) |
| thumb-worker.mjs | `src/lib/server/media/thumb-worker.mjs` | Worker_threads entry point for thumbnail processing |
| thumbnailService.ts | `src/lib/server/media/thumbnailService.ts` | Main-thread fallback wrapper |
| workerPool.ts | `src/lib/server/media/workerPool.ts` | Hand-rolled worker pool implementation |
| pipeline.ts | `src/lib/server/media/pipeline.ts` | Drain loop & orchestration |
| fileService.ts | `src/lib/server/media/fileService.ts` | File mutation service |
| streamService.ts | `src/lib/server/media/streamService.ts` | Range-aware original serving |

---

## Verification Command

```powershell
# Verify all media files exist:
Test-Path "src\lib\server\media\render-core.mjs"
Test-Path "src\lib\server\media\thumb-worker.mjs"
Test-Path "src\lib\server\media\thumbnailService.ts"
Test-Path "src\lib\server\media\workerPool.ts"
Test-Path "src/lib/server/media/pipeline.ts"
Test-Path "src/lib/server/media/fileService.ts"
Test-Path "src/lib/server/media/streamService.ts"
```

**Run in Node to test render-core (ES module):**
```powershell
node --loader ts-node/esm -e "
import { renderMedia } from './src/lib/server/media/render-core.mjs';
console.log('renderMedia:', typeof renderMedia);
"
```

---

## Expected Output

### render-core.mjs (ES Module, no node imports allowed!)
```typescript
// Must import only browser APIs and shared code:
import { blurhash } from './blurhash.ts'; // local module
import { formatDurationMs } from '../format'; // local module

export async function renderMedia(media: Media): Promise<RenderResult> {
  const width = media.width || GRID_CONFIG.tileWidth;
  const height = media.height || GRID_CONFIG.tileWidth;
  const scale = Math.max(width, height) / GRID_CONFIG.thumbnailGridSize;
  // ... rendering logic using canvas API
}
```

### workerPool.ts exports:
```typescript
export class WorkerPool {
  constructor(workerCount: number);
  runQueue(): void; // drains queue in loop
  getPendingCount(): number;
}
```

---

## Success Criteria

- [ ] All media files exist at `src/lib/server/media/*.{ts,mjs}`
- [ ] render-core.mjs is an ES module (no node built-in imports)
- [ ] WorkerPool class can be instantiated and drains queue
- [ ] thumbnailService.ts provides fallback rendering capability
