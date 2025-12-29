#!/bin/bash
# Fix stop command - AudioController.stop() doesn't accept 'ignore' parameter

echo "=========================================="
echo "Fixing Stop Command Bug"
echo "=========================================="
echo ""

WEBSERVER="/opt/audiocontrol2/ac2/webserver.py"
BACKUP="${WEBSERVER}.backup.$(date +%Y%m%d_%H%M%S)"

# Check if file exists
if [ ! -f "$WEBSERVER" ]; then
    echo "✗ Webserver file not found"
    exit 1
fi

# Check if already fixed
if grep -q "# Fix: stop doesn't accept ignore parameter" "$WEBSERVER"; then
    echo "✓ Fix already applied!"
    exit 0
fi

# Create backup
echo "1. Creating backup..."
cp "$WEBSERVER" "$BACKUP"
echo "✓ Backup: $BACKUP"
echo ""

# Find the send_command method
SEND_CMD_LINE=$(grep -n "def send_command" "$WEBSERVER" | head -1 | cut -d: -f1)

if [ -z "$SEND_CMD_LINE" ] || [ "$SEND_CMD_LINE" -lt 1 ]; then
    echo "✗ Could not find send_command method"
    exit 1
fi

echo "2. Found send_command at line $SEND_CMD_LINE"
echo ""

# Use Python to fix it
python3 << 'PYTHON_FIX'
import sys
import re

webserver_file = "/opt/audiocontrol2/ac2/webserver.py"

# Read the file
with open(webserver_file, 'r') as f:
    lines = f.readlines()

# Find send_command method
send_cmd_start = None
for i, line in enumerate(lines):
    if 'def send_command(self, command, ignore=None):' in line or 'def send_command(self, command' in line:
        send_cmd_start = i
        break

if send_cmd_start is None:
    print("✗ Could not find send_command method")
    sys.exit(1)

# Find where stop is called
fixed = False
for i in range(send_cmd_start, min(send_cmd_start + 100, len(lines))):
    line = lines[i]
    
    # Look for stop command handling
    if 'elif command == "stop":' in line or 'if command == "stop":' in line:
        # Find the next line that calls stop
        for j in range(i + 1, min(i + 10, len(lines))):
            if 'self.player_control.stop(' in lines[j]:
                # Check if it has ignore parameter
                if 'ignore=' in lines[j]:
                    # Replace with version without ignore
                    indent = len(lines[j]) - len(lines[j].lstrip())
                    indent_str = ' ' * indent
                    lines[j] = f'{indent_str}# Fix: stop doesn't accept ignore parameter\n'
                    lines.insert(j + 1, f'{indent_str}self.player_control.stop()\n')
                    # Remove the old line (it's now at j+2)
                    del lines[j + 2]
                    fixed = True
                    break
        if fixed:
            break

if not fixed:
    # Try a different approach - look for any stop() call with ignore
    for i, line in enumerate(lines):
        if 'self.player_control.stop(ignore=' in line:
            # Replace it
            indent = len(line) - len(line.lstrip())
            indent_str = ' ' * indent
            lines[i] = f'{indent_str}# Fix: stop doesn't accept ignore parameter\n{indent_str}self.player_control.stop()\n'
            fixed = True
            break

if not fixed:
    print("⚠️  Could not find stop() call with ignore parameter")
    print("   The code might already be fixed or structured differently")
    sys.exit(1)

# Write the fixed file
with open(webserver_file, 'w') as f:
    f.writelines(lines)

print("✓ Fix applied successfully!")
PYTHON_FIX

if [ $? -ne 0 ]; then
    echo "✗ Fix failed. Restoring backup..."
    cp "$BACKUP" "$WEBSERVER"
    exit 1
fi

# Verify
if grep -q "# Fix: stop doesn't accept ignore parameter" "$WEBSERVER"; then
    echo ""
    echo "3. Showing fixed code:"
    grep -B 2 -A 2 "Fix: stop doesn't accept ignore" "$WEBSERVER"
    echo ""
    echo "=========================================="
    echo "Fix Applied!"
    echo "=========================================="
    echo ""
    echo "Next steps:"
    echo "1. Restart AudioControl2:"
    echo "   systemctl restart audiocontrol2"
    echo ""
    echo "2. Test stop command via UI"
    echo ""
else
    echo "✗ Fix verification failed!"
    cp "$BACKUP" "$WEBSERVER"
    exit 1
fi

