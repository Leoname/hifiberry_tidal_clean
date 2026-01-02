#!/bin/bash
# Clean up duplicate metadata parsing code

echo "=========================================="
echo "Cleaning Up Duplicate Metadata Parsing"
echo "=========================================="
echo ""

MPD_CONTROL="/opt/audiocontrol2/ac2/players/mpdcontrol.py"
BACKUP="${MPD_CONTROL}.backup.$(date +%Y%m%d_%H%M%S)"

# Check if file exists
if [ ! -f "$MPD_CONTROL" ]; then
    echo "✗ MPDControl file not found"
    exit 1
fi

# Create backup
echo "1. Creating backup..."
cp "$MPD_CONTROL" "$BACKUP"
echo "✓ Backup: $BACKUP"
echo ""

echo "2. Checking for duplicate parsing code..."
DUPLICATE_COUNT=$(grep -c "Parse.*Artist.*Title.*format" "$MPD_CONTROL" 2>/dev/null || echo "0")
if [ "$DUPLICATE_COUNT" -gt 1 ]; then
    echo "   ⚠ Found $DUPLICATE_COUNT instances of parsing code"
    echo "   Cleaning up duplicates..."
else
    echo "   ✓ No duplicates found"
    exit 0
fi
echo ""

echo "3. Removing duplicate code..."
python3 << 'PYTHON_CLEANUP'
import sys
import re

mpd_control_file = "/opt/audiocontrol2/ac2/players/mpdcontrol.py"

with open(mpd_control_file, 'r') as f:
    lines = f.readlines()

# Find get_meta() method
cleaned = False
for i, line in enumerate(lines):
    if "def get_meta(self):" in line:
        # Find all parsing blocks
        parsing_blocks = []
        in_parsing_block = False
        block_start = None
        
        for j in range(i + 1, min(i + 50, len(lines))):
            if "Parse.*Artist.*Title" in lines[j] or "# Parse" in lines[j] and "Artist" in lines[j] and "Title" in lines[j]:
                if not in_parsing_block:
                    in_parsing_block = True
                    block_start = j
            elif in_parsing_block:
                # Check if this is the end of the parsing block (next non-comment, non-blank line at same or less indent)
                if lines[j].strip() and not lines[j].strip().startswith('#'):
                    indent = len(lines[j]) - len(lines[j].lstrip())
                    block_indent = len(lines[block_start]) - len(lines[block_start].lstrip())
                    if indent <= block_indent:
                        parsing_blocks.append((block_start, j))
                        in_parsing_block = False
                        block_start = None
        
        # If we found multiple blocks, keep only the last (most complete) one
        if len(parsing_blocks) > 1:
            # Remove all but the last block
            for start, end in parsing_blocks[:-1]:
                # Remove the block
                for k in range(start, end):
                    lines[k] = ""
                cleaned = True
                print(f"✓ Removed duplicate parsing block (lines {start+1}-{end})")
        
        break

if not cleaned:
    print("⚠ No duplicates found or structure is different")
    # Try simpler approach - just remove old single-format parsing if new dual-format exists
    content = ''.join(lines)
    if '" - "' in content and '" / "' in content:
        # Find and remove the old single-format parsing
        new_lines = []
        skip_old_block = False
        for i, line in enumerate(lines):
            if '# Parse "Artist - Title" format from title if artist is missing' in line:
                # Check if this is the old single-format version (no " / " handling)
                # Look ahead to see if it handles both formats
                has_slash_format = False
                for j in range(i, min(i + 15, len(lines))):
                    if '" / "' in lines[j]:
                        has_slash_format = True
                        break
                    if 'return md' in lines[j]:
                        break
                
                if not has_slash_format:
                    # This is the old single-format block, skip it
                    skip_old_block = True
                    continue
            
            if skip_old_block:
                # Skip lines until we hit the next non-indented line or return
                if line.strip() and not line.strip().startswith('#') and not line.strip().startswith('if'):
                    indent = len(line) - len(line.lstrip())
                    if indent <= 8:  # Same level as the parsing block
                        skip_old_block = False
                        new_lines.append(line)
                # Skip this line
                continue
            
            new_lines.append(line)
        
        if len(new_lines) < len(lines):
            lines = new_lines
            cleaned = True
            print("✓ Removed old single-format parsing block")

# Write the cleaned file
with open(mpd_control_file, 'w') as f:
    f.writelines(lines)

# Verify syntax
import py_compile
try:
    py_compile.compile(mpd_control_file, doraise=True)
    if cleaned:
        print("✓ Cleanup successful!")
    else:
        print("✓ File is clean (no duplicates found)")
except py_compile.PyCompileError as e:
    print(f"✗ Syntax error: {e}")
    sys.exit(1)
PYTHON_CLEANUP

if [ $? -ne 0 ]; then
    echo "✗ Cleanup failed. Restoring backup..."
    cp "$BACKUP" "$MPD_CONTROL"
    exit 1
fi

echo ""
echo "4. Verifying final code:"
grep -A 12 "Parse.*Artist.*Title" "$MPD_CONTROL" | head -15
echo ""
echo "=========================================="
echo "Cleanup Complete!"
echo "=========================================="
echo ""
echo "The fix is permanent - it modifies MPDControl directly."
echo "It will persist until AudioControl2 is updated."
echo ""

