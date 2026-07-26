# Task 15.2: Create Environment Files

**Source**: `BUILD-FROM-SCRATCH.md` section 17 + env file patterns

**Goal**: Verify environment configuration files are created correctly.

---

## What to Check

### 15.3: Create .env File

```
# Environment variables for LGallery:
UV_THREADPOOL_SIZE=8
```

**Verify these properties:**
1. Creates `.env` file at project root (not in .gitignore)
2. Contains `UV_THREADPOOL_SIZE=8` to set threadpool size before importing build
3. Can be overridden via command-line: `node start.mjs --uv-threadpool-size 16`
4. No secrets or private keys committed (empty password hash is expected)
5. Location: `.env` at project root
6. No other environment variables required by default
7. File format compatible with Bun's env parsing (.env file extension)
8. UV_THREADPOOL_SIZE can be set dynamically via CLI flag
9. Password hash stored in database, not .env file (for security)
10. No hardcoded API keys or external service tokens (self-hosted by design)

---

## Verification Command

```powershell
# Verify .env exists and has correct content:
Get-Content ".\env"
```

---

## Expected Output

```
UV_THREADPOOL_SIZE=8
```

---

## Success Criteria

- [ ] `.env` file exists at project root
- [ ] Contains `UV_THREADPOOL_SIZE=8` to set threadpool size before importing build
