#!/bin/bash
# Fix stop command - also clear playlist to prevent auto-resume

echo "=========================================="
echo "Fixing Stop Command - Clear Playlist"
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
if grep -q "# Clear playlist to prevent auto-resume" "$WEBSERVER"; then
    echo "✓ Fix already applied"
    exit 0
fi

# Create backup
echo "1. Creating backup..."
cp "$WEBSERVER" "$BACKUP"
echo "✓ Backup: $BACKUP"
echo ""

# Find the stop command section
STOP_LINE=$(grep -n 'elif command == "stop":' "$WEBSERVER" | head -1 | cut -d: -f1)

if [ -z "$STOP_LINE" ] || [ "$STOP_LINE" -lt 1 ]; then
    echo "✗ Could not find stop command line"
    exit 1
fi

echo "2. Found stop command at line $STOP_LINE"
echo ""

# Use Python to add playlist clearing
python3 << 'PYTHON_FIX'
import sys

webserver_file = "/opt/audiocontrol2/ac2/webserver.py"

# Read the file
with open(webserver_file, 'r') as f:
    lines = f.readlines()

# Find the stop command section and add playlist clearing
fixed = False
for i, line in enumerate(lines):
    if 'elif command == "stop":' in line:
        # Find where send_command("Stop") is called
        for j in range(i + 1, min(i + 20, len(lines))):
            if 'self.player_control.send_command("Stop")' in lines[j] or 'self.player_control.send_command(CMD_STOP)' in lines[j]:
                # Add playlist clearing before the stop command
                indent = len(lines[j]) - len(lines[j].lstrip())
                indent_str = ' ' * indent
                
                # Insert playlist clearing code before send_command
                # We need to call MPD directly to clear the playlist
                # Check if subprocess is imported
                has_subprocess = False
                for k in range(min(30, len(lines))):
                    if 'import subprocess' in lines[k] or 'from subprocess import' in lines[k]:
                        has_subprocess = True
                        break
                
                # Add import if needed
                if not has_subprocess:
                    # Find where imports are
                    for k in range(min(30, len(lines))):
                        if 'import' in lines[k] and ('logging' in lines[k] or 'json' in lines[k]):
                            # Add subprocess import after this line
                            lines.insert(k + 1, 'import subprocess\n')
                            break
                
                # Insert the playlist clearing code
                clearing_code = [
                    f'{indent_str}# Clear playlist to prevent auto-resume\n',
                    f'{indent_str}try:\n',
                    f'{indent_str}    subprocess.run(["mpc", "clear"], check=False, capture_output=True, timeout=2)\n',
                    f'{indent_str}except:\n',
                    f'{indent_str}    pass  # Ignore errors if mpc is not available\n'
                ]
                
                # Insert before send_command
                lines[j:j] = clearing_code
                fixed = True
                break
        if fixed:
            break

if not fixed:
    print("✗ Could not find send_command('Stop') call to modify")
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
if grep -q "# Clear playlist to prevent auto-resume" "$WEBSERVER"; then
    echo ""
    echo "3. Showing fixed code:"
    grep -B 5 -A 5 "# Clear playlist to prevent auto-resume" "$WEBSERVER" | head -15
    echo ""
    echo "=========================================="
    echo "Fix Applied!"
    echo "=========================================="
    echo ""
    echo "Next steps:"
    echo "1. Restart AudioControl2:"
    echo "   systemctl restart audiocontrol2"
    echo ""
    echo "2. Test stop command via UI - it should now clear the playlist"
    echo ""
else
    echo "✗ Fix verification failed!"
    cp "$BACKUP" "$WEBSERVER"
    exit 1
fi

