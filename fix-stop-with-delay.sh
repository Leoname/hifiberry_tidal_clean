#!/bin/bash
# Fix: Add a small delay and double-check playlist is cleared after stop

echo "=========================================="
echo "Enhanced Stop Fix - Clear with Delay"
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

echo "2. Applying enhanced fix..."
python3 << 'PYTHON_FIX'
import sys
import time

mpd_control_file = "/opt/audiocontrol2/ac2/players/mpdcontrol.py"

with open(mpd_control_file, 'r') as f:
    lines = f.readlines()

fixed = False

# Find CMD_STOP handler
for i, line in enumerate(lines):
    if "elif command == CMD_STOP:" in line:
        # Find self.client.stop()
        for j in range(i + 1, min(i + 15, len(lines))):
            if "self.client.stop()" in lines[j]:
                indent = len(lines[j]) - len(lines[j].lstrip())
                indent_str = ' ' * indent
                
                # Check if we already have clear() calls
                has_clear = False
                for k in range(j + 1, min(j + 5, len(lines))):
                    if "self.client.clear()" in lines[k]:
                        has_clear = True
                        break
                
                if has_clear:
                    print("✓ clear() already present, enhancing...")
                    # Find the clear() line and add a second clear() after a small delay
                    for k in range(j + 1, min(j + 5, len(lines))):
                        if "self.client.clear()" in lines[k]:
                            # Add a second clear() call after a brief comment
                            lines.insert(k + 1, f'{indent_str}# Force clear again to prevent auto-resume\n')
                            lines.insert(k + 2, f'{indent_str}time.sleep(0.1)  # Brief delay\n')
                            lines.insert(k + 3, f'{indent_str}try:\n')
                            lines.insert(k + 4, f'{indent_str}    self.client.clear()\n')
                            lines.insert(k + 5, f'{indent_str}except:\n')
                            lines.insert(k + 6, f'{indent_str}    pass\n')
                            fixed = True
                            print("✓ Added second clear() with delay")
                            break
                else:
                    # Add clear() call
                    lines.insert(j + 1, f'{indent_str}self.client.clear()  # Clear playlist to prevent auto-resume\n')
                    lines.insert(j + 2, f'{indent_str}# Force clear again after brief delay\n')
                    lines.insert(j + 3, f'{indent_str}time.sleep(0.1)\n')
                    lines.insert(j + 4, f'{indent_str}try:\n')
                    lines.insert(j + 5, f'{indent_str}    self.client.clear()\n')
                    lines.insert(j + 6, f'{indent_str}except:\n')
                    lines.insert(j + 7, f'{indent_str}    pass\n')
                    fixed = True
                    print("✓ Added clear() calls with delay")
                
                # Check if time module is imported
                has_time = False
                for k in range(min(30, len(lines))):
                    if 'import time' in lines[k] or 'from time import' in lines[k]:
                        has_time = True
                        break
                
                if not has_time:
                    # Add time import
                    for k in range(min(30, len(lines))):
                        if 'import' in lines[k] and ('logging' in lines[k] or 'mpd' in lines[k]):
                            lines.insert(k + 1, 'import time\n')
                            print("✓ Added time import")
                            break
                
                break
        if fixed:
            break

if not fixed:
    print("✗ Could not find CMD_STOP handler")
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
grep -B 2 -A 10 "elif command == CMD_STOP:" "$MPD_CONTROL" | head -15
echo ""
echo "=========================================="
echo "Fix Applied!"
echo "=========================================="
echo ""
echo "This adds a second clear() call after a brief delay"
echo "to catch any streams that get re-added automatically."
echo ""
echo "Next steps:"
echo "1. Restart AudioControl2:"
echo "   systemctl restart audiocontrol2"
echo "2. Test stop command via UI"
echo ""

