# Task 17.1: Create README.md

**Source**: `BUILD-FROM-SCRATCH.md` section 20 (Documentation)

**Goal**: Verify README.md contains project description and key information.

---

## What to Check

### 17.2: Read src/README.md

```markdown
# LGallery
```

**Verify these properties:**
1. Title is `LGallery` at top of file
2. Contains project description matching BUILD-FROM-SCRATCH.md section 20 (Documentation)
3. Includes installation instructions for Bun and Node.js
4. Mentions production server runs on Node, not Bun (`node start.mjs` → imports build/index.js)
5. Links to key documentation sections:
   - `docs/` directory for detailed guides
6. Includes quickstart or getting started section
7. Lists main features (local storage, privacy-first, self-hosted)
8. No external CDN dependencies mentioned as required
9. OpenStreetMap tile source noted as external dependency
10. Location: `src/README.md` at project root
11. Markdown format with proper headers and formatting
12. Compatible with GitHub README rendering
13. Includes badges or status indicators if applicable
14. No hardcoded URLs that would break on fork (except OSRM for tiles)

---

## Verification Command

```powershell
# Verify README.md exists and has correct title:
Get-Content "src\README.md" | Select-First 5
```

---

## Expected Output

```markdown
# LGallery

A local, self-hosted Google-Photos-style gallery built with SvelteKit + Bun. Fully private, no cloud, no telemetry.

... (rest of README content)
```

---

## Success Criteria

- [ ] `src/README.md` exists at project root
- [ ] Title is `LGallery` at top of file
