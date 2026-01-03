#!/bin/bash
# Fix MPDControl to parse "Artist - Title" format - improved version

echo "=========================================="
echo "Fixing MPDControl Metadata Parsing (v2)"
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

echo "2. Applying fix to parse 'Artist - Title' format..."
python3 << 'PYTHON_FIX'
import sys
import re

mpd_control_file = "/opt/audiocontrol2/ac2/players/mpdcontrol.py"

with open(mpd_control_file, 'r') as f:
    lines = f.readlines()

fixed = False

# Find get_meta() method and add parsing after map_attributes
for i, line in enumerate(lines):
    if "map_attributes(song, md.__dict__, MPD_ATTRIBUTE_MAP)" in line:
        # Check if parsing is already present
        if "Parse.*Artist.*Title" in "".join(lines[i:i+20]) or '" - "' in "".join(lines[i:i+20]):
            # Check if it's working correctly
            for j in range(i+1, min(i+20, len(lines))):
                if "if not md.artist and md.title:" in lines[j]:
                    print("✓ Metadata parsing already present")
                    fixed = True
                    break
            if fixed:
                break
        
        # Find the return statement after map_attributes
        for j in range(i + 1, min(i + 20, len(lines))):
            if "return md" in lines[j]:
                indent = len(lines[j]) - len(lines[j].lstrip())
                indent_str = ' ' * indent
                
                # Insert parsing logic before return
                parse_code = [
                    f'{indent_str}# Parse "Artist - Title" or "Title / Artist" format from title if artist is missing\n',
                    f'{indent_str}if not md.artist and md.title:\n',
                    f'{indent_str}    # Try " - " format first (most common: "Artist - Title")\n',
                    f'{indent_str}    if " - " in md.title:\n',
                    f'{indent_str}        parts = md.title.split(" - ", 1)\n',
                    f'{indent_str}        if len(parts) == 2:\n',
                    f'{indent_str}            md.artist = parts[0].strip()\n',
                    f'{indent_str}            md.title = parts[1].strip()\n',
                    f'{indent_str}    # Try " / " format (some radio stations: "Title / Artist")\n',
                    f'{indent_str}    elif " / " in md.title:\n',
                    f'{indent_str}        parts = md.title.split(" / ", 1)\n',
                    f'{indent_str}        if len(parts) == 2:\n',
                    f'{indent_str}            md.artist = parts[1].strip()  # Artist is usually after / in this format\n',
                    f'{indent_str}            md.title = parts[0].strip()\n'
                ]
                
                lines[j:j] = parse_code
                fixed = True
                print("✓ Added metadata parsing for 'Artist - Title' and 'Title / Artist' formats")
                break
        break

if not fixed:
    print("✗ Could not apply fix - metadata parsing structure may be different")
    print("   Looking for map_attributes call...")
    for i, line in enumerate(lines):
        if "map_attributes" in line:
            print(f"   Found map_attributes at line {i+1}: {line.strip()}")
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
echo "3. Showing fixed code:"
grep -B 2 -A 12 "Parse.*Artist.*Title" "$MPD_CONTROL" | head -15
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

