#!/bin/bash
# Fix syntax error in stop command - restore backup and reapply correctly

echo "=========================================="
echo "Fixing Syntax Error in Stop Command"
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

# Check Python syntax
echo "2. Checking Python syntax..."
python3 -m py_compile "$WEBSERVER" 2>&1
if [ $? -eq 0 ]; then
    echo "✓ Syntax is valid"
else
    echo "✗ Syntax error found"
    exit 1
fi
echo ""

# Now apply the fix correctly
echo "3. Applying fix correctly..."
python3 << 'PYTHON_FIX'
import sys
import re

webserver_file = "/opt/audiocontrol2/ac2/webserver.py"

# Read the file
with open(webserver_file, 'r') as f:
    content = f.read()
    lines = content.split('\n')

# Find the stop command section
fixed = False
for i, line in enumerate(lines):
    if 'elif command == "stop":' in line:
        # Find the send_command("Stop") line - it should be after the auto-activation code
        for j in range(i + 1, min(i + 30, len(lines))):
            if 'self.player_control.send_command("Stop")' in lines[j] or 'self.player_control.send_command(CMD_STOP)' in lines[j]:
                # Get indentation from the send_command line
                indent = len(lines[j]) - len(lines[j].lstrip())
                indent_str = ' ' * indent
                
                # Check if subprocess is imported
                has_subprocess = 'import subprocess' in content or 'from subprocess import' in content
                
                # Add import if needed
                if not has_subprocess:
                    # Find import section
                    for k in range(min(30, len(lines))):
                        if 'import logging' in lines[k] or 'import json' in lines[k]:
                            lines.insert(k + 1, 'import subprocess')
                            break
                
                # Check if there's already a break statement right before send_command
                # If so, we need to insert after the break, not before
                prev_line_idx = j - 1
                if prev_line_idx >= 0 and 'break' in lines[prev_line_idx] and lines[prev_line_idx].strip().startswith('break'):
                    # Insert after the break statement
                    insert_pos = j
                else:
                    # Insert before send_command
                    insert_pos = j
                
                # Insert clearing code right before send_command line
                # Make sure it's at the same indentation level as send_command
                clearing_lines = [
                    f'{indent_str}# Clear playlist to prevent auto-resume',
                    f'{indent_str}try:',
                    f'{indent_str}    subprocess.run(["mpc", "clear"], check=False, capture_output=True, timeout=2)',
                    f'{indent_str}except:',
                    f'{indent_str}    pass  # Ignore errors if mpc is not available'
                ]
                
                # Insert at the correct position
                lines[insert_pos:insert_pos] = clearing_lines
                fixed = True
                break
        if fixed:
            break

if not fixed:
    print("✗ Could not find send_command('Stop') call")
    sys.exit(1)

# Write the fixed file
with open(webserver_file, 'w') as f:
    f.write('\n'.join(lines))

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
    echo "✗ Fix failed"
    exit 1
fi

# Verify syntax again
echo ""
echo "4. Verifying Python syntax..."
python3 -m py_compile "$WEBSERVER" 2>&1
if [ $? -eq 0 ]; then
    echo "✓ Syntax is valid"
    echo ""
    echo "5. Showing fixed code:"
    grep -B 3 -A 8 "# Clear playlist to prevent auto-resume" "$WEBSERVER" | head -12
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

