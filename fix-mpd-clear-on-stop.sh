#!/bin/bash
# Fix MPDControl to clear playlist when CMD_STOP is received

echo "=========================================="
echo "Fixing MPDControl to Clear Playlist on Stop"
echo "=========================================="
echo ""

MPD_CONTROL="/opt/audiocontrol2/ac2/players/mpdcontrol.py"
BACKUP="${MPD_CONTROL}.backup.$(date +%Y%m%d_%H%M%S)"

# Check if file exists
if [ ! -f "$MPD_CONTROL" ]; then
    echo "✗ MPDControl file not found at $MPD_CONTROL"
    exit 1
fi

# Check if already fixed
if grep -q "self.client.clear()" "$MPD_CONTROL" && grep -q "def clear_playlist(self):" "$MPD_CONTROL"; then
    echo "✓ Fix already applied!"
    exit 0
fi

# Create backup
echo "1. Creating backup..."
cp "$MPD_CONTROL" "$BACKUP"
echo "✓ Backup: $BACKUP"
echo ""

echo "2. Applying fix..."
python3 << 'PYTHON_FIX'
import sys
import re

mpd_control_file = "/opt/audiocontrol2/ac2/players/mpdcontrol.py"

with open(mpd_control_file, 'r') as f:
    lines = f.readlines()

fixed = False
clear_method_added = False
stop_modified = False

# First, add clear_playlist method if not present
for i, line in enumerate(lines):
    if "class MPDControl(PlayerControl):" in line:
        # Look for send_command method to add clear_playlist before it
        for j in range(i + 1, min(i + 50, len(lines))):
            if "def send_command(self, command, parameters={}):" in lines[j]:
                # Add clear_playlist method before send_command
                indent = len(lines[j]) - len(lines[j].lstrip())
                indent_str = ' ' * indent
                
                clear_method = [
                    f'\n{indent_str}def clear_playlist(self):\n',
                    f'{indent_str}    """Clear MPD playlist to prevent auto-resume"""\n',
                    f'{indent_str}    try:\n',
                    f'{indent_str}        if self.client is None:\n',
                    f'{indent_str}            self.reconnect()\n',
                    f'{indent_str}        if self.client is not None:\n',
                    f'{indent_str}            self.client.clear()\n',
                    f'{indent_str}            logging.info("MPD playlist cleared.")\n',
                    f'{indent_str}    except Exception as e:\n',
                    f'{indent_str}        logging.error("Error clearing MPD playlist: %s", e)\n'
                ]
                
                lines[j:j] = clear_method
                clear_method_added = True
                print("✓ Added clear_playlist method.")
                break
        break

# Now modify the CMD_STOP handler to call clear_playlist
for i, line in enumerate(lines):
    if "elif command == CMD_STOP:" in line:
        # Find the next line with self.client.stop()
        for j in range(i + 1, min(i + 10, len(lines))):
            if "self.client.stop()" in lines[j]:
                indent = len(lines[j]) - len(lines[j].lstrip())
                indent_str = ' ' * indent
                
                # Add clear_playlist call after stop
                lines.insert(j + 1, f'{indent_str}self.clear_playlist()  # Clear playlist to prevent auto-resume\n')
                stop_modified = True
                print("✓ Modified CMD_STOP to clear playlist.")
                break
        if stop_modified:
            break

if not clear_method_added or not stop_modified:
    print("✗ Could not apply all fixes")
    if not clear_method_added:
        print("  - Failed to add clear_playlist method")
    if not stop_modified:
        print("  - Failed to modify CMD_STOP handler")
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

# Verify
if grep -q "self.client.clear()" "$MPD_CONTROL" && grep -q "def clear_playlist(self):" "$MPD_CONTROL"; then
    echo ""
    echo "3. Showing fixed code:"
    echo "   clear_playlist method:"
    grep -A 10 "def clear_playlist(self):" "$MPD_CONTROL" | head -12
    echo ""
    echo "   CMD_STOP handler:"
    grep -B 2 -A 3 "elif command == CMD_STOP:" "$MPD_CONTROL" | head -6
    echo ""
    echo "=========================================="
    echo "Fix Applied!"
    echo "=========================================="
    echo ""
    echo "Next steps:"
    echo "1. Restart AudioControl2:"
    echo "   systemctl restart audiocontrol2"
    echo ""
    echo "2. Test stop command via UI - playlist should be cleared"
    echo ""
else
    echo "✗ Fix verification failed!"
    cp "$BACKUP" "$MPD_CONTROL"
    exit 1
fi

