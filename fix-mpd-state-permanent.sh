#!/bin/bash
# Comprehensive permanent fix for MPDControl state detection

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

echo "2. Applying comprehensive fix..."
python3 << 'PYTHON_FIX'
import sys
import re

mpd_control_file = "/opt/audiocontrol2/ac2/players/mpdcontrol.py"

with open(mpd_control_file, 'r') as f:
    lines = f.readlines()

fixed_get_state = False
fixed_get_meta = False

# Fix 1: Make get_state() always reconnect and get fresh state
for i, line in enumerate(lines):
    if "def get_state(self):" in line:
        # Find the try block
        for j in range(i + 1, min(i + 40, len(lines))):
            if "try:" in lines[j] and "status = self.client.status()" in "".join(lines[j:j+10]):
                # Check if we already have reconnect logic
                if "self.reconnect()" in "".join(lines[j:j+20]):
                    print("✓ get_state() already has reconnect logic")
                else:
                    # Add reconnect before status call
                    indent = len(lines[j]) - len(lines[j].lstrip())
                    indent_str = ' ' * indent
                    
                    # Find where status() is called
                    for k in range(j + 1, min(j + 15, len(lines))):
                        if "status = self.client.status()" in lines[k] or "self.client.status()" in lines[k]:
                            # Insert reconnect and ensure connection before status
                            reconnect_code = [
                                f'{indent_str}# Ensure connection is active before checking state\n',
                                f'{indent_str}if self.client is None:\n',
                                f'{indent_str}    self.reconnect()\n',
                                f'{indent_str}try:\n',
                                f'{indent_str}    # Test connection by pinging\n',
                                f'{indent_str}    self.client.ping()\n',
                                f'{indent_str}except:\n',
                                f'{indent_str}    # Connection broken, reconnect\n',
                                f'{indent_str}    self.reconnect()\n'
                            ]
                            lines[k:k] = reconnect_code
                            fixed_get_state = True
                            print("✓ Added connection check and reconnect to get_state()")
                            break
                    break
        break

# Fix 2: Make get_meta() always get fresh data
for i, line in enumerate(lines):
    if "def get_meta(self):" in line:
        # Find where we call currentsong()
        for j in range(i + 1, min(i + 50, len(lines))):
            if "song = self.client.currentsong()" in lines[j]:
                # Check if we already have connection check
                if "self.client.ping()" in "".join(lines[j-10:j]):
                    print("✓ get_meta() already has connection check")
                else:
                    # Add connection check before currentsong
                    indent = len(lines[j]) - len(lines[j].lstrip())
                    indent_str = ' ' * indent
                    
                    connection_check = [
                        f'{indent_str}# Ensure connection is active before getting metadata\n',
                        f'{indent_str}if self.client is None:\n',
                        f'{indent_str}    self.reconnect()\n',
                        f'{indent_str}try:\n',
                        f'{indent_str}    self.client.ping()\n',
                        f'{indent_str}except:\n',
                        f'{indent_str}    self.reconnect()\n'
                    ]
                    lines[j:j] = connection_check
                    fixed_get_meta = True
                    print("✓ Added connection check to get_meta()")
                    break
        break

# Fix 3: Enhance exception handling in get_state() to always reconnect
for i, line in enumerate(lines):
    if "def get_state(self):" in line:
        # Find except blocks
        for j in range(i + 1, min(i + 50, len(lines))):
            if "except:" in lines[j] or "except Exception" in lines[j] or "except mpd" in lines[j]:
                # Check if reconnect is already there
                if "self.reconnect()" not in "".join(lines[j:j+5]):
                    indent = len(lines[j]) - len(lines[j].lstrip())
                    indent_str = ' ' * indent
                    
                    # Add reconnect in exception handler
                    lines.insert(j + 1, f'{indent_str}    self.reconnect()\n')
                    lines.insert(j + 2, f'{indent_str}    # Retry getting state after reconnect\n')
                    lines.insert(j + 3, f'{indent_str}    try:\n')
                    lines.insert(j + 4, f'{indent_str}        status = self.client.status()\n')
                    lines.insert(j + 5, f'{indent_str}        state = status.get("state", "stop")\n')
                    lines.insert(j + 6, f'{indent_str}        return STATE_MAP.get(state, STATE_STOPPED)\n')
                    lines.insert(j + 7, f'{indent_str}    except:\n')
                    lines.insert(j + 8, f'{indent_str}        pass  # If still fails, return stopped\n')
                    print("✓ Enhanced exception handling in get_state() to retry after reconnect")
                    fixed_get_state = True
                break
        break

if not fixed_get_state and not fixed_get_meta:
    print("⚠ Some fixes may already be applied, continuing...")

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
echo "   get_state() connection check:"
grep -B 2 -A 5 "Ensure connection is active before checking state" "$MPD_CONTROL" | head -8
echo ""
echo "   get_meta() connection check:"
grep -B 2 -A 5 "Ensure connection is active before getting metadata" "$MPD_CONTROL" | head -8
echo ""
echo "=========================================="
echo "Fix Applied!"
echo "=========================================="
echo ""
echo "This ensures:"
echo "1. get_state() always checks connection and reconnects if needed"
echo "2. get_meta() always checks connection before getting metadata"
echo "3. Exception handlers retry after reconnecting"
echo "4. State is always fresh from MPD, never stale"
echo ""
echo "Next steps:"
echo "1. Restart AudioControl2:"
echo "   systemctl restart audiocontrol2"
echo ""
echo "2. Test - state should now always match actual MPD state"
echo ""

