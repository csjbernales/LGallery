---
name: custom-incremental-file-reader
description: Progressively reads, chunks, and summarizes large files (HTML, CSS, JS, JSON, text) and web search/fetch responses using temporary status tracking to avoid context window overflow.
---

# INCREMENTAL FILE & WEB READER SKILL

## When to Use This Skill
Use this skill when reading large local source files (`.html`, `.css`, `.js`, `.json`, `.txt`, `.md`) or when fetching large web pages/search results to prevent token window overflow and context compaction.

---

## Workflow Procedure

### 1. Pre-Inspection (Schema Check)
- **Local Files:** Inspect the first 20 lines using `Get-Content -LiteralPath "<file>" -TotalCount 20`.
- **Web Pages/APIs:** Save the fetched web payload to `temp/raw-web-response.html` (or `.json`) first before processing.
- Verify the actual content type regardless of extension (e.g., check if a `.txt` or web response is actually formatted JSON, HTML, or raw markdown).

### 2. State File Initialization
Create a tracking document in `temp/read-file-<filename-or-domain>.md`:

```markdown
# Read Tracking: <filename_or_domain>
- Source Type: [Local File | Web Fetch | Search Result]
- Total Lines/Size: <total_count>
- Status: IN_PROGRESS

## Chunk Log
```

### 3. Progressive Line-Batch & Web Chunking
1. **Batch Read:** Read line blocks in chunks of 100 lines (e.g., lines 1–100, 101–200).
2. **Single-Line / Minified / Web HTML Handling:** If the file or web page is minified or single-line HTML, chunk by character offset (e.g., characters 0–2000) instead of line count.
3. **Log Progress & Extract Key Data:** Append the summary of the analyzed chunk to `temp/read-file-<filename-or-domain>.md`:

```markdown
### Chunk [Lines 1-100] - STATUS: COMPLETED
- **Key Facts / Extracted Links:** Verified URL `https://example.com/page`, key layout details, and primary API fields.
```

4. **Mark Next Block:** Append the next block header as `STATUS: IN_PROGRESS` before reading.

### 4. Final Aggregation & Cleanup
Upon reaching EOF (End of File) or processing all web chunks:
1. Update `temp/read-file-<filename-or-domain>.md` status header to `STATUS: COMPLETED`.
2. Compile the chunk descriptions into a high-level architectural or search summary.
3. Deliver the clean answer to the user.
4. **Cleanup:** Delete raw web dumps (`Remove-Item -Force -LiteralPath "temp/raw-web-response.*"`). Retain only the concise tracking log if needed.