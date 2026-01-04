#!/bin/bash
# Fix MPDControl.is_active() to return True when playing

echo "=========================================="
echo "Fixing MPDControl is_active() Method"
echo "=========================================="
echo ""

MPD_CONTROL="/opt/audiocontrol2/ac2/players/mpdcontrol.py"
BACKUP="${MPD_CONTROL}.backup.$(date +%Y%m%d_%H%M%S)"

if [ ! -f "$MPD_CONTROL" ]; then
    echo "✗ MPDControl file not found"
    exit 1
fi

echo "1. Creating backup..."
cp "$MPD_CONTROL" "$BACKUP"
echo "✓ Backup: $BACKUP"
echo ""

echo "2. Finding is_active() method..."
grep -B 5 -A 15 "def is_active" "$MPD_CONTROL" | head -25
echo ""

echo "3. Fixing is_active() to return True when playing..."
python3 << 'PYTHON_FIX'
import sys
import re

mpd_control_file = "/opt/audiocontrol2/ac2/players/mpdcontrol.py"

with open(mpd_control_file, 'r') as f:
    lines = f.readlines()

fixed = False

# Find is_active() method
for i, line in enumerate(lines):
    if "def is_active(self):" in line:
        # Found is_active() method
        # Check what it currently does
        method_start = i
        method_end = i + 1
        
        # Find the end of the method (next def or class)
        for j in range(i + 1, min(i + 30, len(lines))):
            if lines[j].strip().startswith("def ") or lines[j].strip().startswith("class "):
                method_end = j
                break
        
        # Get indentation from the method definition line itself
        indent = len(line) - len(line.lstrip())
        indent_str = ' ' * indent
        
        # Check if it already checks get_state()
        method_body = "".join(lines[i:method_end])
        
        if "get_state()" in method_body and "STATE_PLAYING" in method_body:
            print("   ⚠ is_active() already checks get_state() and STATE_PLAYING")
            # But maybe it's not working correctly, let's enhance it
            # Replace the method with a more robust version
            new_method = [
                f'{indent_str}def is_active(self):\n',
                f'{indent_str}    """Return True if MPD is playing or paused"""\n',
                f'{indent_str}    try:\n',
                f'{indent_str}        state = self.get_state()\n',
                f'{indent_str}        # Return True if playing or paused (active states)\n',
                f'{indent_str}        return state in [STATE_PLAYING, STATE_PAUSED]\n',
                f'{indent_str}    except:\n',
                f'{indent_str}        return False\n'
            ]
            
            # Replace the method
            lines[i:method_end] = new_method
            fixed = True
            print(f"   ✓ Enhanced is_active() to check get_state() at line {i+1}")
            break
        elif "get_state()" not in method_body:
            # Method doesn't check get_state(), add it
            # Replace with new implementation
            new_method = [
                f'{indent_str}def is_active(self):\n',
                f'{indent_str}    """Return True if MPD is playing or paused"""\n',
                f'{indent_str}    try:\n',
                f'{indent_str}        state = self.get_state()\n',
                f'{indent_str}        # Return True if playing or paused (active states)\n',
                f'{indent_str}        return state in [STATE_PLAYING, STATE_PAUSED]\n',
                f'{indent_str}    except:\n',
                f'{indent_str}        return False\n'
            ]
            
            # Replace the method
            lines[i:method_end] = new_method
            fixed = True
            print(f"   ✓ Added get_state() check to is_active() at line {i+1}")
            break

if not fixed:
    print("   ✗ Could not find or fix is_active() method")
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
echo "4. Showing fixed is_active() method:"
grep -A 10 "def is_active" "$MPD_CONTROL" | head -15
echo ""
echo "=========================================="
echo "Fix Applied!"
echo "=========================================="
echo ""
echo "The is_active() method now:"
echo "1. Calls get_state() to get current MPD state"
echo "2. Returns True if state is PLAYING or PAUSED"
echo "3. Returns False on any error"
echo ""
echo "Next steps:"
echo "1. Restart AudioControl2:"
echo "   systemctl restart audiocontrol2"
echo "2. Test - MPD should now be marked as active when playing"
echo ""

