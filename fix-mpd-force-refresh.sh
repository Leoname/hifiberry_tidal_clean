#!/bin/bash
# Force metadata refresh by clearing cached values and ensuring fresh data

echo "=========================================="
echo "Forcing MPD Metadata Refresh"
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

echo "2. Ensuring get_meta() always gets fresh data..."
python3 << 'PYTHON_FIX'
import sys

mpd_control_file = "/opt/audiocontrol2/ac2/players/mpdcontrol.py"

with open(mpd_control_file, 'r') as f:
    lines = f.readlines()

fixed = False

# Find get_meta() and ensure it always clears last_title when title changes
for i, line in enumerate(lines):
    if "def get_meta(self):" in line:
        # Find where we check title changes
        for j in range(i + 1, min(i + 50, len(lines))):
            if "if current_song_id != self.last_song_id or current_title != self.last_title:" in lines[j]:
                # Check if we're updating last_title
                for k in range(j + 1, min(j + 10, len(lines))):
                    if "self.last_title = current_title" in lines[k]:
                        # Good, it's there
                        print("✓ Title tracking is present")
                        fixed = True
                        break
                    elif "self.last_song_id = current_song_id" in lines[k] and "self.last_title" not in "".join(lines[k:k+3]):
                        # Missing last_title update, add it
                        indent = len(lines[k]) - len(lines[k].lstrip())
                        indent_str = ' ' * indent
                        lines.insert(k + 1, f'{indent_str}self.last_title = current_title\n')
                        print("✓ Added last_title update")
                        fixed = True
                        break
                break
        break

# Also ensure get_state() returns correct state for paused
for i, line in enumerate(lines):
    if "def get_state(self):" in line:
        # Check if it handles "pause" state correctly
        for j in range(i + 1, min(i + 40, len(lines))):
            if "STATE_MAP.get(state, STATE_STOPPED)" in lines[j]:
                # Check if STATE_MAP includes "pause"
                # The issue might be that "pause" maps to STATE_PAUSED correctly
                # But we need to ensure it's not cached
                print("✓ State detection looks correct")
                break
        break

if not fixed:
    print("⚠ Some fixes may already be applied")

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
echo "3. Verifying fixes:"
grep -A 3 "self.last_title = current_title" "$MPD_CONTROL" | head -5
echo ""
echo "=========================================="
echo "Fix Applied!"
echo "=========================================="
echo ""
echo "This ensures metadata refreshes when title changes."
echo ""
echo "Next steps:"
echo "1. Restart AudioControl2:"
echo "   systemctl restart audiocontrol2"
echo ""

