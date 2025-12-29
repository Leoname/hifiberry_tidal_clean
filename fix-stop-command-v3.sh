#!/bin/bash
# Fix stop command - use send_command instead of stop() directly

echo "=========================================="
echo "Fixing Stop Command Bug (v3)"
echo "=========================================="
echo ""

WEBSERVER="/opt/audiocontrol2/ac2/webserver.py"
BACKUP="${WEBSERVER}.backup.$(date +%Y%m%d_%H%M%S)"

# Check if file exists
if [ ! -f "$WEBSERVER" ]; then
    echo "✗ Webserver file not found"
    exit 1
fi

# Check if already fixed (using send_command with CMD_STOP)
if grep -q "self.player_control.send_command(CMD_STOP)" "$WEBSERVER"; then
    echo "✓ Fix already applied (v3)"
    exit 0
fi

# Create backup
echo "1. Creating backup..."
cp "$WEBSERVER" "$BACKUP"
echo "✓ Backup: $BACKUP"
echo ""

# Find the stop command line
STOP_LINE=$(grep -n 'elif command == "stop":' "$WEBSERVER" | head -1 | cut -d: -f1)

if [ -z "$STOP_LINE" ] || [ "$STOP_LINE" -lt 1 ]; then
    echo "✗ Could not find stop command line"
    exit 1
fi

echo "2. Found stop command at line $STOP_LINE"
echo ""

# Use Python to fix it properly
python3 << 'PYTHON_FIX'
import sys

webserver_file = "/opt/audiocontrol2/ac2/webserver.py"

# Read the file
with open(webserver_file, 'r') as f:
    lines = f.readlines()

# Find the stop command line and replace it
fixed = False
for i, line in enumerate(lines):
    if 'elif command == "stop":' in line:
        # Find the next line with stop()
        for j in range(i + 1, min(i + 5, len(lines))):
            if 'self.player_control.stop()' in lines[j]:
                # Replace with send_command using CMD_STOP constant
                indent = len(lines[j]) - len(lines[j].lstrip())
                indent_str = ' ' * indent
                # Check if CMD_STOP is imported, if not add import
                has_import = False
                for k in range(min(50, len(lines))):
                    if 'from ac2.constants import' in lines[k] and 'CMD_STOP' in lines[k]:
                        has_import = True
                        break
                    elif 'import' in lines[k] and 'CMD_STOP' in lines[k]:
                        has_import = True
                        break
                
                # Use the constant if available, otherwise use string
                if has_import:
                    lines[j] = f'{indent_str}self.player_control.send_command(CMD_STOP)\n'
                else:
                    # Try to add import at the top
                    import_line = -1
                    for k in range(min(30, len(lines))):
                        if 'from ac2.constants import' in lines[k]:
                            # Add CMD_STOP to existing import
                            lines[k] = lines[k].rstrip() + ', CMD_STOP\n'
                            import_line = k
                            break
                        elif 'import' in lines[k] and 'ac2' in lines[k]:
                            import_line = k
                            break
                    
                    if import_line >= 0:
                        lines[j] = f'{indent_str}self.player_control.send_command(CMD_STOP)\n'
                    else:
                        # Fallback to string
                        lines[j] = f'{indent_str}self.player_control.send_command("Stop")\n'
                fixed = True
                break
        if fixed:
            break

if not fixed:
    print("✗ Could not find stop() call to replace")
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
if grep -q 'self.player_control.send_command("Stop")' "$WEBSERVER"; then
    echo ""
    echo "3. Showing fixed code:"
    grep -B 2 -A 2 'self.player_control.send_command("Stop")' "$WEBSERVER" | head -5
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

