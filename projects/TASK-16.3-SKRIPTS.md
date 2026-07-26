# Task 16.3: Create Dev Helper Scripts

**Source**: `BUILD-FROM-SCRATCH.md` section 19 + scripts directory

**Goal**: Verify dev helper scripts are created correctly.

---

## What to Check

### 17.4: Create scripts/gen-fixtures.mjs

```javascript
// Generates sample library and config:
#!/usr/bin/env node
```

**Verify these properties:**
1. Uses `bun run gen-fixtures` command from package.json
2. Generates sample data for testing UI components
3. Creates or updates `lgallery.config.json` with example values
4. Sample library includes:
   - Config schema with all fields populated with defaults
   - Example roots (e.g., /home/photos, /home/videos)
   - Sample image/video extensions list
5. Sample config includes:
   - Root directories with labels and enabled flags
   - Include/exclude patterns
6. Usage: `bun run gen-fixtures`
7. Generates deterministic output for reproducible tests
8. Can be modified to add custom roots or test data
9. Script exits with proper status code (0 on success)
10. Located in `scripts/gen-fixtures.mjs`

---

## Verification Command

```powershell
# Check gen-fixtures script exists:
Test-Path "scripts\gen-fixtures.mjs"
```

---

## Expected Output

```javascript
// Sample code structure from scripts/gen-fixtures.mjs: -->
#!/usr/bin/env node
import { writeFileSync } from 'fs';
import { defaultConfig } from './src/lib/shared/config-schema';

const config = {
  roots: [...],
  imageExtensions: [...],
  ...
};

writeFileSync('lgallery.config.json', JSON.stringify(config, null, 2));
```

---

## Success Criteria

- [ ] `scripts/gen-fixtures.mjs` exists
- [ ] Generates sample library and config matching BUILD-FROM-SCRATCH.md section 19
