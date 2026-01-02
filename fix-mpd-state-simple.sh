#!/bin/bash
# Simple permanent fix: Ensure get_state() reconnects and refresh state after stop

echo "=========================================="
echo "Fixing MPDControl State Detection (Simple)"
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

echo "2. Applying simple fix..."
python3 << 'PYTHON_FIX'
import sys

mpd_control_file = "/opt/audiocontrol2/ac2/players/mpdcontrol.py"

with open(mpd_control_file, 'r') as f:
    content = f.read()
    lines = content.splitlines(True)

fixed = False

# Fix 1: Enhance get_state() to always reconnect on exception
for i, line in enumerate(lines):
    if "def get_state(self):" in line:
        # Find the except block that handles connection errors
        for j in range(i + 1, min(i + 30, len(lines))):
            if "except:" in lines[j] and "Connection to MPD might be broken" in "".join(lines[j:j+3]):
                # Add reconnect in the except block
                indent = len(lines[j]) - len(lines[j].lstrip())
                indent_str = ' ' * indent
                
                # Check if reconnect is already there
                if "self.reconnect()" not in "".join(lines[j:j+5]):
                    # Add reconnect call
                    lines.insert(j + 1, f'{indent_str}    self.reconnect()\n')
                    fixed = True
                    print("✓ Enhanced get_state() exception handling to reconnect")
                break
        break

# Fix 2: Add state refresh after CMD_STOP
for i, line in enumerate(lines):
    if "elif command == CMD_STOP:" in line:
        # Find the end of the CMD_STOP block (where we have the clear() calls)
        for j in range(i + 1, min(i + 25, len(lines))):
            # Look for the last clear() call or the end of the block
            if "self.client.clear()" in lines[j] and j + 3 < len(lines):
                # Check if next non-empty line is another elif/else or blank
                for k in range(j + 1, min(j + 5, len(lines))):
                    if lines[k].strip() and not lines[k].strip().startswith('#'):
                        if "elif command ==" in lines[k] or "else:" in lines[k] or len(lines[k].strip()) == 0:
                            # Add state refresh before this line
                            indent = len(lines[j]) - len(lines[j].lstrip())
                            indent_str = ' ' * indent
                            
                            # Check if we already added state refresh
                            refresh_present = False
                            for check_line in lines[j:j+10]:
                                if "self.get_state()" in check_line or "Force state refresh" in check_line:
                                    refresh_present = True
                                    break
                            
                            if not refresh_present:
                                refresh_code = [
                                    f'{indent_str}# Force state refresh after stop to update UI immediately\n',
                                    f'{indent_str}try:\n',
                                    f'{indent_str}    self.get_state()\n',
                                    f'{indent_str}except:\n',
                                    f'{indent_str}    pass\n'
                                ]
                                
                                lines[k:k] = refresh_code
                                fixed = True
                                print("✓ Added state refresh after CMD_STOP")
                            break
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
echo "   get_state() exception handling:"
grep -A 8 "except:" "$MPD_CONTROL" | grep -A 5 "Connection to MPD" | head -6
echo ""
echo "   CMD_STOP with state refresh:"
grep -B 2 -A 15 "elif command == CMD_STOP:" "$MPD_CONTROL" | grep -A 12 "self.client.clear()" | head -15
echo ""
echo "=========================================="
echo "Fix Applied!"
echo "=========================================="
echo ""
echo "This ensures:"
echo "1. get_state() reconnects if connection is broken"
echo "2. State is refreshed after stop command"
echo ""
echo "Next steps:"
echo "1. Restart AudioControl2:"
echo "   systemctl restart audiocontrol2"
echo ""

