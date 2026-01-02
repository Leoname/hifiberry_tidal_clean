#!/bin/bash
# Fix MPDControl to always refresh state and reconnect properly

echo "=========================================="
echo "Fixing MPDControl State Detection (Permanent)"
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

echo "2. Applying fix to ensure state is always refreshed..."
python3 << 'PYTHON_FIX'
import sys
import re

mpd_control_file = "/opt/audiocontrol2/ac2/players/mpdcontrol.py"

with open(mpd_control_file, 'r') as f:
    lines = f.readlines()

fixed_get_state = False
fixed_send_command = False

# Fix 1: Ensure get_state() always reconnects and refreshes
for i, line in enumerate(lines):
    if "def get_state(self):" in line:
        # Find the end of the method (next def or class at same/lesser indent)
        method_start = i
        method_indent = len(line) - len(line.lstrip())
        
        # Look for the return statement or end of method
        for j in range(i + 1, min(i + 50, len(lines))):
            # Check if we've hit the next method/class
            if lines[j].strip() and not lines[j].startswith(' ') and not lines[j].startswith('\t'):
                if lines[j].strip().startswith('def ') or lines[j].strip().startswith('class '):
                    break
            
            # Check if we're at the same indent level (end of method)
            if lines[j].strip() and len(lines[j]) - len(lines[j].lstrip()) <= method_indent:
                if not lines[j].strip().startswith('#'):
                    break
            
            # Find the return statement
            if "return" in lines[j] and "STATE_" in lines[j]:
                # Add a reconnect/refresh before return
                indent = len(lines[j]) - len(lines[j].lstrip())
                indent_str = ' ' * indent
                
                # Insert reconnect check before return
                reconnect_code = [
                    f'{indent_str}# Ensure connection is fresh before returning state\n',
                    f'{indent_str}try:\n',
                    f'{indent_str}    if self.client is None:\n',
                    f'{indent_str}        self.reconnect()\n',
                    f'{indent_str}    elif hasattr(self.client, "ping"):\n',
                    f'{indent_str}        self.client.ping()  # Test connection\n',
                    f'{indent_str}except:\n',
                    f'{indent_str}    # Connection broken, reconnect\n',
                    f'{indent_str}    self.reconnect()\n'
                ]
                
                lines[j:j] = reconnect_code
                fixed_get_state = True
                print("✓ Enhanced get_state() to always refresh connection")
                break
        break

# Fix 2: After send_command (especially CMD_STOP), force state refresh
for i, line in enumerate(lines):
    if "elif command == CMD_STOP:" in line:
        # Find where we added the clear() calls
        for j in range(i + 1, min(i + 20, len(lines))):
            if "self.client.clear()" in lines[j] and "# Force clear again" in lines[j-1] if j > 0 else False:
                # Find the end of the CMD_STOP block
                for k in range(j + 1, min(j + 10, len(lines))):
                    if "elif command ==" in lines[k] or "else:" in lines[k] or lines[k].strip() == "":
                        # Add state refresh after stop/clear
                        indent = len(lines[j]) - len(lines[j].lstrip())
                        indent_str = ' ' * indent
                        
                        refresh_code = [
                            f'{indent_str}# Force state refresh after stop to update UI immediately\n',
                            f'{indent_str}try:\n',
                            f'{indent_str}    # Trigger state update by calling get_state\n',
                            f'{indent_str}    self.get_state()\n',
                            f'{indent_str}except:\n',
                            f'{indent_str}    pass  # Ignore errors in state refresh\n'
                        ]
                        
                        lines[k:k] = refresh_code
                        fixed_send_command = True
                        print("✓ Added state refresh after CMD_STOP")
                        break
                if fixed_send_command:
                    break
        if fixed_send_command:
            break

if not fixed_get_state and not fixed_send_command:
    print("✗ Could not apply fixes")
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
echo "   get_state() enhancement:"
grep -A 15 "def get_state(self):" "$MPD_CONTROL" | head -18
echo ""
echo "   CMD_STOP with state refresh:"
grep -B 2 -A 12 "elif command == CMD_STOP:" "$MPD_CONTROL" | head -15
echo ""
echo "=========================================="
echo "Fix Applied!"
echo "=========================================="
echo ""
echo "This ensures:"
echo "1. get_state() always checks/refreshes MPD connection"
echo "2. After stop command, state is immediately refreshed"
echo ""
echo "Next steps:"
echo "1. Restart AudioControl2:"
echo "   systemctl restart audiocontrol2"
echo ""
echo "2. Test - state should now always be accurate"
echo ""

