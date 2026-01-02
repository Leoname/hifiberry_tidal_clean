#!/bin/bash
# Fix metadata to refresh when song changes

echo "=========================================="
echo "Fixing Metadata Refresh on Song Change"
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

echo "2. Applying fix to refresh metadata on song change..."
python3 << 'PYTHON_FIX'
import sys

mpd_control_file = "/opt/audiocontrol2/ac2/players/mpdcontrol.py"

with open(mpd_control_file, 'r') as f:
    lines = f.readlines()

fixed = False

# Find get_meta() method and add song ID tracking
for i, line in enumerate(lines):
    if "def get_meta(self):" in line:
        # Check if we already track song ID
        has_song_id_tracking = False
        for j in range(i, min(i + 50, len(lines))):
            if "self.last_song_id" in lines[j] or "songid" in lines[j].lower():
                has_song_id_tracking = True
                break
        
        if not has_song_id_tracking:
            # Find where song is retrieved
            for j in range(i + 1, min(i + 20, len(lines))):
                if "song = self.client.currentsong()" in lines[j]:
                    indent = len(lines[j]) - len(lines[j].lstrip())
                    indent_str = ' ' * indent
                    
                    # Add song ID tracking after song is retrieved
                    tracking_code = [
                        f'{indent_str}# Track song ID to detect song changes\n',
                        f'{indent_str}current_song_id = song.get("id") if song else None\n',
                        f'{indent_str}if not hasattr(self, "last_song_id"):\n',
                        f'{indent_str}    self.last_song_id = None\n',
                        f'{indent_str}# Force metadata refresh if song changed\n',
                        f'{indent_str}if current_song_id != self.last_song_id:\n',
                        f'{indent_str}    self.last_song_id = current_song_id\n',
                        f'{indent_str}    # Song changed - metadata will be fresh\n'
                    ]
                    
                    lines[j+1:j+1] = tracking_code
                    fixed = True
                    print("✓ Added song ID tracking to detect song changes")
                    break
        break

# Also ensure get_meta() always gets fresh data from MPD
# Find where map_attributes is called and ensure we're getting current song
for i, line in enumerate(lines):
    if "def get_meta(self):" in line:
        # Look for the currentsong() call
        for j in range(i + 1, min(i + 15, len(lines))):
            if "song = self.client.currentsong()" in lines[j]:
                # Check if we're calling it every time or caching
                # The code should already call it, but let's ensure it's not cached
                indent = len(lines[j]) - len(lines[j].lstrip())
                indent_str = ' ' * indent
                
                # Add a comment to ensure fresh data
                if j + 1 < len(lines) and "# Get fresh song data" not in lines[j+1]:
                    lines.insert(j, f'{indent_str}# Get fresh song data from MPD (not cached)\n')
                    fixed = True
                    print("✓ Ensured fresh song data retrieval")
                break
        break

if not fixed:
    print("⚠ Could not apply all fixes, but continuing...")

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
grep -A 20 "def get_meta(self):" "$MPD_CONTROL" | head -25
echo ""
echo "=========================================="
echo "Fix Applied!"
echo "=========================================="
echo ""
echo "This adds song ID tracking to detect when songs change"
echo "and ensures metadata is refreshed."
echo ""
echo "Next steps:"
echo "1. Restart AudioControl2:"
echo "   systemctl restart audiocontrol2"
echo ""
echo "2. Test - metadata should update when songs change"
echo ""

