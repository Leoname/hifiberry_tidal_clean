#!/bin/bash
# Fix MPDControl to better parse metadata from radio streams

echo "=========================================="
echo "Fixing MPDControl Metadata Parsing"
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

echo "2. Checking current metadata parsing logic..."
grep -A 30 "def get_meta(self):" "$MPD_CONTROL" | head -35
echo ""

echo "3. Applying fix to improve metadata parsing..."
python3 << 'PYTHON_FIX'
import sys
import re

mpd_control_file = "/opt/audiocontrol2/ac2/players/mpdcontrol.py"

with open(mpd_control_file, 'r') as f:
    lines = f.readlines()

fixed = False

# Find get_meta() method and enhance it to parse "Artist - Title" format
for i, line in enumerate(lines):
    if "def get_meta(self):" in line:
        # Look for where map_attributes is called or where md is returned
        for j in range(i + 1, min(i + 30, len(lines))):
            # Find where map_attributes is called
            if "map_attributes" in lines[j]:
                # Add parsing after map_attributes but before return
                indent = len(lines[j]) - len(lines[j].lstrip())
                indent_str = ' ' * indent
                
                # Find the return statement
                for k in range(j + 1, min(j + 10, len(lines))):
                    if "return md" in lines[k] or "return" in lines[k]:
                        # Insert parsing logic before return
                        parse_code = [
                            f'{indent_str}# Parse "Artist - Title" format from title if artist is missing\n',
                            f'{indent_str}if not md.artist and md.title and " - " in md.title:\n',
                            f'{indent_str}    # Split "Artist - Title" format (common in radio streams)\n',
                            f'{indent_str}    parts = md.title.split(" - ", 1)\n',
                            f'{indent_str}    if len(parts) == 2:\n',
                            f'{indent_str}        md.artist = parts[0].strip()\n',
                            f'{indent_str}        md.title = parts[1].strip()\n'
                        ]
                        
                        lines[k:k] = parse_code
                        fixed = True
                        print("✓ Added metadata parsing for 'Artist - Title' format")
                        break
                if fixed:
                    break
        break

if not fixed:
    print("⚠ Could not find map_attributes call, trying alternative approach...")
    
    # Try alternative - look for return md statement in get_meta
    for i, line in enumerate(lines):
        if "def get_meta(self):" in line:
            # Find return statement
            for j in range(i + 1, min(i + 30, len(lines))):
                if "return md" in lines[j]:
                    indent = len(lines[j]) - len(lines[j].lstrip())
                    indent_str = ' ' * indent
                    
                    # Insert before return
                    parse_code = [
                        f'{indent_str}# Parse "Artist - Title" format from title if artist is missing\n',
                        f'{indent_str}if hasattr(md, "artist") and hasattr(md, "title"):\n',
                        f'{indent_str}    if not md.artist and md.title and " - " in md.title:\n',
                        f'{indent_str}        parts = md.title.split(" - ", 1)\n',
                        f'{indent_str}        if len(parts) == 2:\n',
                        f'{indent_str}            md.artist = parts[0].strip()\n',
                        f'{indent_str}            md.title = parts[1].strip()\n'
                    ]
                    
                    lines[j:j] = parse_code
                    fixed = True
                    print("✓ Added metadata parsing (before return)")
                    break
            if fixed:
                break

if not fixed:
    print("✗ Could not apply fix - metadata parsing structure may be different")
    sys.exit(1)

# Write the fixed file
with open(mpd_control_file, 'w') as f:
    f.writelines(lines)

# Verify syntax
import py_compile
try:
    py_compile.compile(mpd_control_file, doraise=True)
    print("✓ Fix applied successfully!")
except py_compile.PyCompileError as e:
    print(f"✗ Syntax error: {e}")
    sys.exit(1)
PYTHON_FIX

if [ $? -ne 0 ]; then
    echo "✗ Fix failed. Restoring backup..."
    cp "$BACKUP" "$MPD_CONTROL"
    exit 1
fi

echo ""
echo "4. Showing fixed code:"
grep -A 15 "Parse.*Artist.*Title" "$MPD_CONTROL" | head -18
echo ""
echo "=========================================="
echo "Fix Applied!"
echo "=========================================="
echo ""
echo "This will parse 'Artist - Title' format from radio stream titles"
echo "when artist metadata is missing."
echo ""
echo "Next steps:"
echo "1. Restart AudioControl2:"
echo "   systemctl restart audiocontrol2"
echo ""
echo "2. Test with a radio stream - metadata should now be parsed correctly"
echo ""

