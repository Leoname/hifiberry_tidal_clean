#!/bin/bash
# Fix MPDControl to refresh metadata for radio streams even when song ID doesn't change

echo "=========================================="
echo "Fixing Radio Stream Metadata Refresh"
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

echo "2. Applying fix to refresh metadata when title changes (for radio streams)..."
python3 << 'PYTHON_FIX'
import sys
import re

mpd_control_file = "/opt/audiocontrol2/ac2/players/mpdcontrol.py"

with open(mpd_control_file, 'r') as f:
    lines = f.readlines()

fixed = False

# Find get_meta() method and enhance it to track title changes
for i, line in enumerate(lines):
    if "def get_meta(self):" in line:
        # Look for where we track song ID
        for j in range(i + 1, min(i + 40, len(lines))):
            # Find where we check song ID
            if "current_song_id = song.get(\"id\")" in lines[j] or "current_song_id = song.get('id')" in lines[j]:
                indent = len(lines[j]) - len(lines[j].lstrip())
                indent_str = ' ' * indent
                
                # Check if title tracking is already present
                if "current_title = song.get" in lines[j+1] or "last_title" in lines[j+5]:
                    print("✓ Title tracking already present")
                    fixed = True
                    break
                
                # Insert title tracking after song ID tracking
                title_tracking = [
                    f'{indent_str}# Also track title changes for radio streams (song ID may not change)\n',
                    f'{indent_str}current_title = song.get("title", "") if song else ""\n',
                    f'{indent_str}if not hasattr(self, "last_title"):\n',
                    f'{indent_str}    self.last_title = None\n',
                    f'{indent_str}# Force refresh if song ID changed OR title changed (for radio streams)\n',
                    f'{indent_str}if current_song_id != self.last_song_id or current_title != self.last_title:\n',
                    f'{indent_str}    self.last_song_id = current_song_id\n',
                    f'{indent_str}    self.last_title = current_title\n',
                    f'{indent_str}    # Song or metadata changed - metadata will be fresh\n'
                ]
                
                # Find the line with "if current_song_id != self.last_song_id:"
                for k in range(j + 1, min(j + 10, len(lines))):
                    if "if current_song_id != self.last_song_id:" in lines[k]:
                        # Replace the if statement and add title tracking
                        lines[k] = f'{indent_str}if current_song_id != self.last_song_id or current_title != self.last_title:\n'
                        # Insert title tracking before the if statement
                        lines[k:k] = title_tracking[:-1]  # Insert all but the last line (which is the if statement)
                        fixed = True
                        print("✓ Added title tracking for radio stream metadata refresh")
                        break
                if fixed:
                    break
        break

# Also need to initialize last_title in __init__
if fixed:
    for i, line in enumerate(lines):
        if "def __init__(self, args={}):" in line:
            for j in range(i + 1, min(i + 15, len(lines))):
                if "self.last_song_id = None" in lines[j]:
                    indent = len(lines[j]) - len(lines[j].lstrip())
                    indent_str = ' ' * indent
                    if "self.last_title = None" not in lines[j+1]:
                        lines.insert(j + 1, f'{indent_str}self.last_title = None  # Track last title for radio stream metadata refresh\n')
                        print("✓ Added last_title initialization to __init__")
                    break
            break

if not fixed:
    print("✗ Could not apply fix - metadata refresh structure may be different")
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
grep -B 3 -A 8 "Also track title changes" "$MPD_CONTROL" | head -12
echo ""
echo "=========================================="
echo "Fix Applied!"
echo "=========================================="
echo ""
echo "This will refresh metadata when the title changes,"
echo "even if the song ID stays the same (for radio streams)."
echo ""
echo "Next steps:"
echo "1. Restart AudioControl2:"
echo "   systemctl restart audiocontrol2"
echo ""
echo "2. Test with a radio stream - metadata should now update"
echo "   when the stream metadata changes, even if song ID doesn't change"
echo ""

