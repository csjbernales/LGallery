# Task 13.2: Create App Type Declarations

**Source**: `BUILD-FROM-SCRATCH.md` section 13 (App shell)

**Goal**: Verify app.d.ts and ambient.d.ts provide type declarations for server-rendered form inputs.

---

## What to Check

### 13.3: Create src/app.d.ts

```typescript
// Type definitions for server-rendered form input attributes:
type ServerInputAttributes = {
  name: string;
  type?: 'text' | 'password' | 'checkbox';
  value: any; // can be array, object, or primitive
};
```

**Verify these properties:**
1. Defines `ServerInputAttributes` type for server-rendered input elements
2. Includes all necessary attributes: name, type, value
3. Value attribute can hold arrays of strings (checkboxes), objects (nested inputs)
4. Used in forms to provide complete type information at compile time
5. Enables SvelteKit's automatic form field generation from types
6. Located in `src/app.d.ts` as per LGallery convention
7. Uses proper TypeScript syntax and JSDoc comments if needed
8. Type is exported for use across components
9. Includes nested input type definitions (checkboxes, radios)
10. Compatible with SvelteKit's `$forms` plugin API

---

## Verification Command

```powershell
# Check app.d.ts exists:
Test-Path "src\app.d.ts"
```

---

## Expected Output

```typescript
// Sample type definitions from src/app.d.ts: -->
type ServerInputAttributes = {
  name: string;
  type?: 'text' | 'password';
  value: any;
};

export default ServerInputAttributes; // or similar
```

---

## Success Criteria

- [ ] `src/app.d.ts` exists with proper type declarations for server-rendered forms
