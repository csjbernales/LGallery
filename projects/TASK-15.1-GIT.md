# Task 15.1: Create Git Configuration Files

**Source**: `BUILD-FROM-SCRATCH.md` section 16 (Post-copy)

**Goal**: Verify gitignore and .gitkeep files are created correctly.

---

## What to Check

### 15.2: Create .gitkeep and .gitignore Files

```
git keep these directories:
data/           # Database - ignored except .gitkeep
lgallery.config.json   # Config - ignored (runtime config)
node_modules/    # Dependencies - gitignored
build/          # Build output - gitignored
.svelte-kit/     # SvelteKit build artifacts - gitignored
dist/            # Output for adapter-node - gitignored
```

**Verify these properties:**
1. Creates `.gitkeep` file in `data/` directory (empty file to track presence)
2. `.gitignore` contains correct patterns:
   - `data/` is ignored except `.gitkeep`
   - `lgallery.config.json` is ignored
3. No sensitive data committed to git
4. Build output directories are gitignored
5. node_modules/ is gitignored (Bun handles this automatically)
6. .svelte-kit/ is gitignored (SvelteKit convention)
7. Location: `.gitignore` at project root
8. .gitkeep file in `data/` directory to track database presence without storing data
9. No other ignored files that shouldn't be tracked
10. Config file path correct: `lgallery.config.json`

---

## Verification Command

```powershell
# Verify .gitignore exists and has correct patterns:
Get-Content ".\gitignore" | Select-String -Pattern "^data|^lgallery\.config"

# Create .gitkeep in data/ directory if it doesn't exist
if (!(Test-Path ".\data\.gitkeep")) {
  New-Item -ItemType File -LiteralPath ".\data\.gitkeep" -Value ""
}
```

---

## Expected Output

```powershell
# .gitignore should contain:
data/
lgallery.config.json

# Verify patterns match:
True
True

# .gitkeep should exist in data/: ->
$true
```

---

## Success Criteria

- [ ] `.gitignore` exists with correct ignore patterns (data/, lgallery.config.json)
- [ ] `.gitkeep` file exists in `data/` directory to track database presence
