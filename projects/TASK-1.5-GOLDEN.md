# Task 1.5: Golden Rules Verification

**Source**: `BUILD-FROM-SCRATCH.md` section 1.5 (`### 1.5 GOLDEN RULES`) 

**Goal**: Verify and document all golden rules that must be followed during build.

---

## Read: BUILD-FROM-SCRATCH.md Section 1.5

```markdown
### 1.5 GOLDEN RULES (honor these or the app won't match)

1. Bun builds, Node serves.
2. `zod` is pinned to v3 (`^3.25.76`). Do not upgrade to zod 4.
3. DB migrations are append-only, v1 → v6.
4. Privacy invariant — only three things may touch the network, all opt-in/scoped.
5. Canonical root paths via `fs.realpathSync.native`.
```

---

## Verification Command

```powershell
# Verify bun.lock exists with correct lockfileVersion:
bun x -y --help > /dev/null 2>&1 && echo "Bun available"
test $(bun info --json | jq '.lockfileVersion') -eq 1 && echo "Lockfile Version 1 found"
```

**Check package.json for Zod pin:**
```powershell
node -e "
const pkg = require('./package.json');
console.log('Zod version:', pkg.dependencies.zod);
if (pkg.dependencies.zod === '^3.25.76') {
  console.log('✓ Zod pinned to v3 as required by golden rule #2');
}
"
```

---

## Expected Output

### Golden Rule #1: Bun builds, Node serves
- `bun.lock` exists with lockfileVersion: 1
- Production server launched via `node start.mjs`, NOT `bun build/index.js`

### Golden Rule #2: Zod v3 pinned
- `package.json.dependencies.zod === '^3.25.76'`
- No zod ^4 or higher versions present

### Golden Rule #3: Migrations append-only
- Migration set at `src/lib/server/db/schema.ts` contains v1→v6 array
- Each migration has unique version number (v1, v2, ..., v6)

---

## Success Criteria

- [ ] All 5 golden rules documented and verified
- [ ] Zod pinned to v3 (not upgraded)
