# Task 14.1: Create Tailwind Configuration

**Source**: `BUILD-FROM-SCRATCH.md` section 14 (Tailwind CSS v4)

**Goal**: Verify tailwind.config.ts provides custom colors and fonts for Anthropic brand styling.

---

## What to Check

### 14.2: Create src/app.css / tailwind config

```css
/* Tailwind directives + custom theme in app.css */
<script>
  import { addBase, matchColor } from "tailwindcss";
  
  // Custom colors matching Anthropic brand guidelines
</script>
```

**Verify these properties:**
1. Includes Tailwind CSS v4 directives with `@theme` or equivalent
2. Uses `tailwind.config = { ... }` script tag for custom theme (v4 style)
3. Custom colors matching Anthropic brand guidelines (from brand-guidelines skill):
   - Primary: #F7F9FC (light gray), #09090B (dark black)
   - Secondary: #E0E1DD, #1A1A1A
   - Accent: #3E546C (slate blue), #252A35
   - Background: #F7F9FC, #FFFFFF
4. Custom font families for Anthropic typography:
   - Heading fonts: Inter or similar clean sans-serif
   - Body text: System-ui fallbacks
5. Tailwind v4 configuration with preflight disabled (corePlugins.preflight = false)
6. Uses `matchColor` function to derive color variants from base colors
7. Custom spacing, border radii, shadows matching brand guidelines
8. Location: either in `src/app.css` or separate `tailwind.config.ts`
9. Compatible with Tailwind v4's new CSS-first configuration approach
10. No external CDN dependencies (self-hosted theme)

---

## Verification Command

```powershell
# Check tailwind config exists:
Test-Path "src\app.css"
Get-Content "package.json" | Select-String -Pattern "tailwindcss"
```

---

## Expected Output

```css
/* Sample Tailwind v4 configuration in src/app.css: */
<script>
  import { addBase, matchColor } from "tailwindcss";
  
  tailwind.config = {
    corePlugins: { preflight: false },
    theme: {
      extend: {
        colors: {
          primary: { light: '#F7F9FC', DEFAULT: '#09090B' },
          secondary: { light: '#E0E1DD', DEFAULT: '#1A1A1A' },
          accent: { light: '#3E546C', DEFAULT: '#252A35' },
        }
      }
    }
  };
</script>
```

---

## Success Criteria

- [ ] `src/app.css` exists with Tailwind v4 configuration
- [ ] Custom colors matching Anthropic brand guidelines are defined
