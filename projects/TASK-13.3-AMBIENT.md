# Task 13.3: Create Ambient Type Declarations

**Source**: `BUILD-FROM-SCRATCH.md` section 13 (App shell)

**Goal**: Verify ambient.d.ts provides additional type declarations for global types and utilities.

---

## What to Check

### 13.4: Create src/ambient.d.ts

```typescript
// Additional ambient type definitions:
type AppConfig = typeof defaultConfig;
```

**Verify these properties:**
1. Defines `AppConfig` as the entire config object from lgallery.config.json
2. Includes all top-level config fields (roots, include, exclude, etc.)
3. Located in `src/ambient.d.ts` for global type availability
4. Types are ambient declarations (no explicit export)
5. Compatible with SvelteKit's `$env.staticConfig` if available
6. Used to provide complete type information throughout the application
7. Includes nested types where appropriate (e.g., RootDefinition, MediaItem)
8. Located in `src/ambient.d.ts` as per LGallery convention
9. Types are exported for use across components and pages
10. Compatible with Zod schema types from config-schema.ts

---

## Verification Command

```powershell
# Check ambient.d.ts exists:
Test-Path "src\ambient.d.ts"
```

---

## Expected Output

```typescript
// Sample type definitions from src/ambient.d.ts: -->
type AppConfig = typeof defaultConfig;
export default AppConfig; // or similar
```

---

## Success Criteria

- [ ] `src/ambient.d.ts` exists with proper ambient type declarations
