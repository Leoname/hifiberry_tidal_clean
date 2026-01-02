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
        # Look for where artist and title are extracted
        for j in range(i + 1, min(i + 60, len(lines))):
            # Find where artist is set from song data
            if "artist" in lines[j].lower() and ("=" in lines[j] or "song.get" in lines[j] or "song[" in lines[j]):
                # Check if we need to add parsing logic
                # Look ahead to see if title parsing exists
                needs_fix = False
                for k in range(j, min(j + 20, len(lines))):
                    if "title" in lines[k].lower() and ("=" in lines[k] or "song.get" in lines[k]):
                        # Check if artist is empty but title has "Artist - Title" format
                        indent = len(lines[k]) - len(lines[k].lstrip())
                        indent_str = ' ' * indent
                        
                        # Add logic to parse "Artist - Title" from title if artist is missing
                        parse_code = [
                            f'{indent_str}# Parse "Artist - Title" format from title if artist is missing\n',
                            f'{indent_str}if not md.artist and md.title and " - " in md.title:\n',
                            f'{indent_str}    # Split "Artist - Title" format\n',
                            f'{indent_str}    parts = md.title.split(" - ", 1)\n',
                            f'{indent_str}    if len(parts) == 2:\n',
                            f'{indent_str}        md.artist = parts[0].strip()\n',
                            f'{indent_str}        md.title = parts[1].strip()\n'
                        ]
                        
                        # Insert after title is set
                        lines[k+1:k+1] = parse_code
                        fixed = True
                        print("✓ Added metadata parsing for 'Artist - Title' format")
                        break
                if fixed:
                    break
        break

if not fixed:
    print("⚠ Could not find get_meta() method or metadata assignment")
    print("   Checking if metadata is set differently...")
    
    # Try alternative approach - look for where Metadata() is created
    for i, line in enumerate(lines):
        if "Metadata()" in line or "md = Metadata()" in line or "meta = Metadata()" in line:
            # Find where title is set
            for j in range(i + 1, min(i + 30, len(lines))):
                if "title" in lines[j].lower() and ("=" in lines[j] or ".title" in lines[j]):
                    indent = len(lines[j]) - len(lines[j].lstrip())
                    indent_str = ' ' * indent
                    
                    # Add parsing after title assignment
                    parse_code = [
                        f'\n{indent_str}# Parse "Artist - Title" format from title if artist is missing\n',
                        f'{indent_str}if hasattr(md, "artist") and hasattr(md, "title"):\n',
                        f'{indent_str}    if not md.artist and md.title and " - " in md.title:\n',
                        f'{indent_str}        parts = md.title.split(" - ", 1)\n',
                        f'{indent_str}        if len(parts) == 2:\n',
                        f'{indent_str}            md.artist = parts[0].strip()\n',
                        f'{indent_str}            md.title = parts[1].strip()\n'
                    ]
                    
                    lines[j+1:j+1] = parse_code
                    fixed = True
                    print("✓ Added metadata parsing (alternative location)")
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

