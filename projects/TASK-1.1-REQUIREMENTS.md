# Task 1.1: Understand Requirements and Golden Rules

**Source**: `BUILD-FROM-SCRATCH.md` section 1.1-1.5

**Goal**: Read and document the requirements and golden rules for exact LGallery reproduction.

---

## What to Verify

### 1.1: Read BUILD-FROM-SCRATCH.md sections 1.1-1.5 completely

Read these sections from `C:\Users\Clark\.config\opencode\projects\BUILD-FROM-SCRATCH.md`:

- **Section 1.1**: What LGallery is — local, self-hosted photo/video gallery with privacy focus
- **Section 1.2**: Goal of BUILD-FROM-SCRATCH.md — exact reproduction from commit `f32f74b`
- **Section 1.3**: How to use the document (two tracks: human/agent following instructions OR agent given entire file)
- **Section 1.4**: Exact environment and toolchain requirements
- **Section 1.5**: GOLDEN RULES — non-negotiable constraints for exact reproduction

### 1.2: Note the golden rules that must be followed

Document these golden rules:

**Rule #1**: Bun builds, Node serves
- Bun is package manager, script runner, bundler driver
- Production server MUST run on Node (`node start.mjs` → `import('./build/index.js')`
- Reason: better-sqlite3 native module unsupported in Bun runtime (Bun #4290)

**Rule #2**: Zod pinned to v3
- Do NOT upgrade to zod 4
- Zod 4 breaks `.object({...}).default({})` typing pattern used in config schema
- Config-defaulting design relies on zod 3 semantics

**Rule #3**: DB migrations are append-only (v1 → v6)
- Each migration is immutable shipped step
- Never edit a migration that has already shipped — only append new versions
- Real installs migrate forward in place with backup, altering past migrations corrupts upgrade paths

**Rule #4**: Privacy invariant — only three things may touch network (all opt-in/scoped):
- (a) OpenStreetMap map tiles when map view is open
- (b) One-time AI model download when AI is turned on (or air-gapped via local models)
- (c) Nominatim reverse-geocoding only when `geocode.enabled` with `provider:"nominatim"` (throttled ≤1 req/s)
- Everything else — fonts, icons, all assets — is self-hosted and local. No telemetry, no CDNs.

**Rule #5**: Canonical root paths via `fs.realpathSync.native`
- All configured roots are canonicalized using `fs.realpathSync.native` (NOT plain `fs.realpathSync`)
- Windows 8.3 short names expanded to long form
- Keeps scanner, chokidar watcher, and path allow-list/traversal guard consistent
- Fixes libuv fs-event crash

---

## Verification Command

```powershell
# Verify sections exist in BUILD-FROM-SCRATCH.md
Get-Content "C:\Users\Clark\.config\opencode\projects\BUILD-FROM-SCRATCH.md" | Select-String -Pattern "^1\.5 GOLDEN RULES|^### 1\.[0-9]"
```

---

## Expected Output

After completing this task:
- Sections 1.1-1.5 are read and documented in notes
- Golden rules are recorded for reference during build
- Understanding of why each rule exists is captured

**Success criteria**: Golden rules understood and documented; ready to verify environment requirements.
