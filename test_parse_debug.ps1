# Test JSON Lines Parser

Testing whether PowerShell ConvertFrom-Json parses all lines correctly.

## Expected behavior:
1. Empty lines should be skipped (return)
2. Standalone '{' or '}' should be skipped (return)
3. Valid JSON lines should parse successfully
4. Error lines should output error messages and continue processing

## Test data to add:
- Line 502: Empty line for testing skip behavior
- Line 503: Valid JSON: `{"test":"empty_line_skipped","ok":true}`
- Line 504: Standalone '{' 
- Line 505: Standalone '}'
- Line 506: Valid JSON with special chars: `{"special":"newline\nand\ttab",¡²}`

Run this after adding test data to verify parsing.