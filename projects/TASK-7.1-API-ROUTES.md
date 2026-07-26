# Task 7.1: Create API Routes Directory Structure

**Source**: `BUILD-FROM-SCRATCH.md` section 7 (Read queries & HTTP/API surface)

**Goal**: Set up route structure for media, timeline, config and other HTTP APIs.

---

## What to Check

### 7.2: Create API Route Directories

```powershell
# Create API route directories:
New-Item -ItemType Directory -Force "src\routes\api\media\+server.ts"
New-Item -ItemType Directory -Force "src\routes\timeline\+server.ts"
New-Item -ItemType Directory -Force "src\routes\config\+server.ts"
```

---

## Verification Command

```powershell
# Verify API routes exist:
Test-Path "src\routes\api\media\+server.ts"
Test-Path "src\routes\timeline\+server.ts"
Test-Path "src\routes\config\+server.ts"
```

---

## Expected Output

```powershell
# All API route directories should exist:
True
True
...
```

---

## Success Criteria

- [ ] `src/routes/api/media/+server.ts` exists for media listing endpoint
- [ ] `src/routes/timeline/+server.ts` exists for timeline endpoint
- [ ] `src/routes/config/+server.ts` exists for config endpoint
