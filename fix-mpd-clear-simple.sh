#!/bin/bash
# Simple fix: Add clear() call directly in CMD_STOP handler

echo "=========================================="
echo "Fixing MPDControl to Clear Playlist on Stop (Simple)"
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
if grep -q "self.client.clear()" "$MPD_CONTROL" && grep -A 2 "elif command == CMD_STOP:" "$MPD_CONTROL" | grep -q "self.client.clear()"; then
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

mpd_control_file = "/opt/audiocontrol2/ac2/players/mpdcontrol.py"

with open(mpd_control_file, 'r') as f:
    lines = f.readlines()

fixed = False

# Find CMD_STOP handler and add clear() call after stop()
for i, line in enumerate(lines):
    if "elif command == CMD_STOP:" in line:
        # Find the next line with self.client.stop()
        for j in range(i + 1, min(i + 15, len(lines))):
            if "self.client.stop()" in lines[j]:
                indent = len(lines[j]) - len(lines[j].lstrip())
                indent_str = ' ' * indent
                
                # Check if clear() is already called
                if j + 1 < len(lines) and "self.client.clear()" in lines[j + 1]:
                    print("✓ clear() already called after stop()")
                    fixed = True
                    break
                
                # Add clear() call right after stop()
                lines.insert(j + 1, f'{indent_str}self.client.clear()  # Clear playlist to prevent auto-resume\n')
                fixed = True
                print("✓ Added clear() call after stop()")
                break
        if fixed:
            break

if not fixed:
    print("✗ Could not find CMD_STOP handler or self.client.stop()")
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
if grep -A 3 "elif command == CMD_STOP:" "$MPD_CONTROL" | grep -q "self.client.clear()"; then
    echo ""
    echo "3. Showing fixed code:"
    grep -B 2 -A 4 "elif command == CMD_STOP:" "$MPD_CONTROL" | head -7
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

