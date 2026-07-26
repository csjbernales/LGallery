# Task 10.1: Create Settings Page

**Source**: `BUILD-FROM-SCRATCH.md` section 10 (Settings UI)

**Goal**: Verify the settings page provides configuration form with proper validation and saving.

---

## What to Check

### 10.2: Create /settings Page

```svelte
<!-- Should show config fields from lgallery.config.json -->
<svelte:options tag="page" />
<script>
  // Read current config, validate against zod schema, provide form fields
</script>
```

**Verify these properties:**
1. Uses `app.d.ts` type declaration for server-rendered input types in forms
2. Reads current config from API endpoint (or $env.staticConfig if available)
3. Validates form inputs against zod schema before submit
4. Provides proper Svelte 5 runes state management (`$:`, `$effect`) for reactive form handling
5. Form fields map to each config option (roots, imageExtensions, videoExtensions, scan, etc.)
6. Uses Zod error handling with `.error.issues` from zod v3
7. Saves config on form submit via API call (/api/config)
8. Shows validation errors inline in the UI for invalid inputs
9. Provides clear instructions and field descriptions
10. Handles loading state while saving (indeterminate progress indicator)

---

## Verification Command

```powershell
# Check settings page exists:
Test-Path "src\routes\settings\+page.svelte"
```

---

## Expected Output

```svelte
<!-- Sample form structure: -->
<form>
  <fieldset>Roots</fieldset>
    {#each roots as root} ... /end:each }
  <fieldset>Image Extensions</fieldset>
    <input type="text" name="imageExtensions" value={config.imageExtensions} />
    ...
  ...
  <button type="submit">Save settings</button>
</form>
```

---

## Success Criteria

- [ ] `src/routes/settings/+page.svelte` exists
- [ ] Form validates against zod schema before submit
- [ ] Uses Zod error handling with .error.issues from zod v3
- [ ] Saves config on form submit via API call (/api/config)
