# Task 2.3: Create Root Configuration Files

**Source**: `BUILD-FROM-SCRATCH.md` sections 2.2 (package.json) + 2.6 (.gitignore)

**Goal**: Copy/create all root-level configuration files that define the project structure and settings.

---

## What to Create/Copy

### 2.4: Copy lgallery.config.example.json to lgallery.config.json

```powershell
# Copy example config to runtime config (gitignored)
Copy-Item ".\lgallery.config.example.json" -Destination ".\lgallery.config.json"
```

**Note**: The config file is ignored by git because it contains local filesystem paths. It's generated/personal.

### 2.5: Verify package.json Fields

```powershell
# Check all top-level fields match exactly:
Get-Content ".\package.json" | Format-HighString -Width 256
```

**Required fields to verify:**
- `name": "lgallery"`, `version": "0.1.0"`, `private`: true
- `type": "module"` — whole project is ESM
- `description`: "A local, self-hosted Google-Photos-style gallery built with SvelteKit + Bun. Fully private, no cloud, no telemetry."
- `packageManager": "bun@1.3.14"`
- `engines": { "bun": ">=1.3.0" }`
- `overrides": { "cookie": "^0.7.2" }` — forces non-vulnerable cookie version

### 2.6: Verify svelte.config.js

```powershell
# Key values to verify:
Get-Content ".\svelte.config.js"
```

**Verify:**
- `kit.adapter: adapter({ precompress: true })` — adapter-node with precompression
- Four aliases: `$shared → src/lib/shared`, `$server → src/lib/server`, `$client → src/lib/client`, `$components → src/lib/components`
- `compilerOptions.runes: true` — Svelte 5 runes mode forced on globally

### 2.7: Verify vite.config.ts

```powershell
# Should show:
Get-Content ".\vite.config.ts"
```

**Verify:**
- Plugins order: `plugins: [tailwindcss(), sveltekit()]` (Tailwind plugin BEFORE SvelteKit)
- `ssr.external`: native modules + optional AI packages (not bundled into SSR build)
- Test block with Vitest configuration

### 2.8: Verify tsconfig.json

```powershell
# compilerOptions should include:
Get-Content ".\tsconfig.json"
```

**Verify:**
- Extends `.svelte-kit/tsconfig.json` (requires `svelte-kit sync` before typechecking)
- `"allowJs": true`, `"checkJs": true` — JS files are type-checked
- `"strict": true`

### 2.9: Verify .gitignore

```powershell
# Check these patterns exist:
Get-Content ".\gitignore" | Select-String -Pattern "^data|^lgallery\.config"
```

**Verify:**
- `data/` is ignored except `.gitkeep`
- `lgallery.config.json` is ignored (runtime config)
- Build output: `.svelte-kit/`, `build/`, `dist/`

---

## Verification Commands

```powershell
# Verify configs exist
Test-Path ".\lgallery.config.example.json"
Test-Path ".\package.json"
Test-Path ".\svelte.config.js"
Test-Path ".\vite.config.ts"
```

---

## Expected Output

```powershell
# All files should exist:
True
True
...

# package.json fields example output:
{
  "name": "lgallery",
  "version": "0.1.0",
  "private": true,
  ...
}
```

---

## Success Criteria

- [ ] `lgallery.config.example.json` copied to `.\lgallery.config.json`
- [ ] All config files exist (package.json, svelte.config.js, vite.config.ts)
- [ ] package.json has correct top-level fields from BUILD-FROM-SCRATCH.md
- [ ] svelte.config.js has adapter-node with precompress enabled
- [ ] vite.config.ts has correct plugin order (tailwindcss before sveltekit)
- [ ] tsconfig.json extends .svelte-kit/tsconfig.json
