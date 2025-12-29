#!/bin/bash
# Correct fix for stop command - properly insert playlist clearing

echo "=========================================="
echo "Correct Fix for Stop Command"
echo "=========================================="
echo ""

WEBSERVER="/opt/audiocontrol2/ac2/webserver.py"

# Find the most recent backup
BACKUP=$(ls -t /opt/audiocontrol2/ac2/webserver.py.backup.* 2>/dev/null | head -1)

if [ -z "$BACKUP" ]; then
    echo "✗ No backup found"
    exit 1
fi

echo "1. Restoring from backup: $BACKUP"
cp "$BACKUP" "$WEBSERVER"
echo "✓ Restored"
echo ""

# Apply fix using Python
echo "2. Applying fix..."
python3 << 'PYTHON_FIX'
import sys
import re

webserver_file = "/opt/audiocontrol2/ac2/webserver.py"

# Read the file
with open(webserver_file, 'r') as f:
    lines = f.readlines()

# Check if subprocess is imported
has_subprocess = False
for i, line in enumerate(lines):
    if 'import subprocess' in line or 'from subprocess import' in line:
        has_subprocess = True
        break

# Add import if needed
if not has_subprocess:
    for i, line in enumerate(lines):
        if line.strip().startswith('import ') and ('logging' in line or 'json' in line):
            lines.insert(i + 1, 'import subprocess\n')
            break

# Find the stop command and the send_command line
fixed = False
for i, line in enumerate(lines):
    if 'elif command == "stop":' in line:
        # Look for send_command("Stop") or send_command(CMD_STOP) after this
        for j in range(i + 1, min(i + 30, len(lines))):
            if 'self.player_control.send_command("Stop")' in lines[j] or 'self.player_control.send_command(CMD_STOP)' in lines[j]:
                # Get the indentation of the send_command line
                indent = len(lines[j]) - len(lines[j].lstrip())
                indent_str = ' ' * indent
                
                # Insert clearing code right before send_command
                clearing_code = [
                    f'{indent_str}# Clear playlist to prevent auto-resume\n',
                    f'{indent_str}try:\n',
                    f'{indent_str}    subprocess.run(["mpc", "clear"], check=False, capture_output=True, timeout=2)\n',
                    f'{indent_str}except:\n',
                    f'{indent_str}    pass  # Ignore errors if mpc is not available\n'
                ]
                
                # Insert before the send_command line
                lines[j:j] = clearing_code
                fixed = True
                break
        if fixed:
            break

if not fixed:
    print("✗ Could not find send_command('Stop') call")
    sys.exit(1)

# Write the fixed file
with open(webserver_file, 'w') as f:
    f.writelines(lines)

# Verify syntax
import py_compile
try:
    py_compile.compile(webserver_file, doraise=True)
    print("✓ Fix applied successfully!")
except py_compile.PyCompileError as e:
    print(f"✗ Syntax error: {e}")
    sys.exit(1)
PYTHON_FIX

if [ $? -ne 0 ]; then
    echo "✗ Fix failed - restoring backup"
    cp "$BACKUP" "$WEBSERVER"
    exit 1
fi

# Verify syntax again
echo ""
echo "3. Verifying Python syntax..."
python3 -m py_compile "$WEBSERVER" 2>&1
if [ $? -eq 0 ]; then
    echo "✓ Syntax is valid"
    echo ""
    echo "4. Showing fixed code:"
    grep -B 3 -A 6 "# Clear playlist to prevent auto-resume" "$WEBSERVER" | head -10
    echo ""
    echo "=========================================="
    echo "Fix Applied Successfully!"
    echo "=========================================="
    echo ""
    echo "Next steps:"
    echo "1. Restart AudioControl2:"
    echo "   systemctl restart audiocontrol2"
    echo ""
    echo "2. Test stop command via UI"
    echo ""
else
    echo "✗ Syntax error still exists"
    exit 1
fi

