# Task 3.1: Verify Zod Schema Configuration

**Source**: `BUILD-FROM-SCRATCH.md` section 3.1 + src/lib/shared/config-schema.ts

**Goal**: Verify the isomorphic config validator uses zod v3 idioms with correct defaults.

---

## What to Check

### 3.2: Read and verify src/lib/shared/config-schema.ts

```powershell
# Read the config schema file:
Get-Content "src\lib\shared\config-schema.ts"
```

**Verify these properties:**
1. No node imports (isomorphic validator runs client-side too)
2. Uses zod v3 idioms: `.default({})`, `.safeParse`, `.error.issues`
3. Contains correct default values matching BUILD-FROM-SCRATCH.md
4. `extensions()` helper lowercases and strips leading dot:
   ```typescript
   const extensions = (def) => z.array(z.string()).default(def)
     .transform((arr) => [...new Set(arr.map(e => e.toLowerCase().replace(/^\./, '')))]);
   ```
5. `MINIMAL_CONFIG_HINT` object present with required fields

### 3.3: Verify schema fields against BUILD-FROM-SCRATCH.md defaults

**Required fields to verify:**
- `roots`: array of { path, label, enabled }
- `include`: default ['**/*']
- `exclude`: default ['**/.*', '**/@eaDir/**', '**/#recycle/**', '**/Thumbs.db']
- `imageExtensions`: 19-entry list including jpg, jpeg, png, gif, webp, avif, bmp, tiff, tif, heic, heif
- `videoExtensions`: mp4, mov, m4v, webm, mkv, avi, wmv, mts, m2ts, 3gp
- `scan` defaults: onStartup true, rescanOnReload true, watch false
- `thumbnails` default format: z.literal('webp')
- `trash` config with autoPurgeDays default 30
- `server`: host default '127.0.0.1', port default 4173
- `ai`: semanticSearch false, faceGrouping false

---

## Verification Command

```powershell
# Verify schema file exists and can be read:
Test-Path "src\lib\shared\config-schema.ts"

# Check for zod v3 patterns (should find .default({}), safeParse):
Get-Content "src\lib\shared\config-schema.ts" | Select-String -Pattern ".default\(\{\}\)"
```

---

## Expected Output

```powershell
# Schema file should exist:
True

# Zod v3 idioms (should find many matches):
Get-Content "src\lib\shared\config-schema.ts" | Select-String -Pattern ".default\(\{\}\)"
```

---

## Success Criteria

- [ ] `config-schema.ts` exists at correct path
- [ ] No node imports (isomorphic validator)
- [ ] Uses zod v3 syntax: `.default({})`, `.safeParse()`
- [ ] Contains minimal config hint with required roots field
- [ ] Defaults match BUILD-FROM-SCRATCH.md section 3.1
