# Task 5.1-5.6: Scan Subsystem Components

**Source**: `BUILD-FROM-SCRATCH.md` section 5 (`src/lib/server/scan/*.ts`)

**Goal**: Verify all scan subsystem modules for the media indexing startup process.

---

## Files to Check

| File | Path | Purpose |
|------|------|--------|
| scanState.ts | `src/lib/server/scan/scanState.ts` | In-memory progress tracking + SSE fan-out |
| pairing.ts | `src/lib/server/scan/pairing.ts` | Live/Motion photo pairing algorithm |
| walker.ts | `src/lib/server/scan/walker.ts` | Iterative streaming directory walk |
| scanner.ts | `src/lib/server/scan/scanner.ts` | Main orchestrator that coordinates everything |
| watcher.ts | `src/lib/server/scan/watcher.ts` | Optional chokidar live indexer (when enabled) |

---

## Verification Command

```powershell
# Verify all scan files exist:
Test-Path "src\lib\server\scan\scanState.ts"
Test-Path "src\lib\server\scan\pairing.ts"
Test-Path "src\lib\server\scan\walker.ts"
Test-Path "src\lib\server\scan\scanner.ts"
Test-Path "src\lib\server\scan\watcher.ts"
```

**Run in Node to test scanner module loads:**
```powershell
node -e "
// Test that scanState module exports:
const { ScanState } = require('./src/lib/server/scan/scanState.ts');
console.log('ScanState:', typeof ScanState);

// Test pairing module exports:
const { pairMedia, isMotionVideo } = require('./src/lib/server/scan/pairing.ts');
console.log('pairMedia:', typeof pairMedia);
console.log('isMotionVideo:', typeof isMotionVideo);
"
```

---

## Expected Output

```typescript
// scanState.ts exports:
export class ScanState {
  progress: { startedAt?: number; finishedAt?: number; status: 'running' | 'idle' };
  filesSeen: number;
  filesAdded: number;
  filesUpdated: number;
  filesRemoved: number;
  // SSE handler methods
}

// pairing.ts exports:
export function pairMedia(
  primary: Media,
  candidates: Media[]
): string | null; // partner id or null if no match

export function isMotionVideo(media: Media): boolean; // motion detection via EXIF orientation

// scanner.ts exports:
export class Scanner {
  state: ScanState;
  config: RootConfig;
  constructor(state, config);
  scanRoot(root: RootConfig): void;
}

// walker.ts exports:
export function walkDirectory(dirPath: string, rootNormalized: string, include?: string[], exclude?: string[]): AsyncIterableIterator<FileInfo>;

// watcher.ts exports (when enabled):
export function startWatcher(root: RootConfig, callback: (file: FileInfo) => void): () => void; // cleanup handler
```

---

## Success Criteria

- [ ] All 5 scan module files exist at `src/lib/server/scan/*.ts`
- [ ] Scanner class exports and can be instantiated
- [ ] Pairing function returns correct partner media id or null
- [ ] Walker generates AsyncIterableIterator of FileInfo objects
- [ ] Watcher function returns cleanup handler
