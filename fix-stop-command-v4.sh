#!/bin/bash
# Fix stop command - use send_command with auto-activation like other commands

echo "=========================================="
echo "Fixing Stop Command Bug (v4)"
echo "=========================================="
echo ""

WEBSERVER="/opt/audiocontrol2/ac2/webserver.py"
BACKUP="${WEBSERVER}.backup.$(date +%Y%m%d_%H%M%S)"

# Check if file exists
if [ ! -f "$WEBSERVER" ]; then
    echo "✗ Webserver file not found"
    exit 1
fi

# Check if already fixed (v4 - with auto-activation)
if grep -q "# Auto-activate playing player for stop command" "$WEBSERVER"; then
    echo "✓ v4 fix already applied"
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

# Use Python to fix it with auto-activation
python3 << 'PYTHON_FIX'
import sys

webserver_file = "/opt/audiocontrol2/ac2/webserver.py"

# Read the file
with open(webserver_file, 'r') as f:
    lines = f.readlines()

# Find the stop command and replace it with auto-activation logic
fixed = False
for i, line in enumerate(lines):
    if 'elif command == "stop":' in line:
        # Find the next line with stop() or send_command
        for j in range(i + 1, min(i + 5, len(lines))):
            if 'self.player_control.stop()' in lines[j] or 'self.player_control.send_command("Stop")' in lines[j] or 'self.player_control.send_command(CMD_STOP)' in lines[j]:
                # Replace with auto-activation logic like other commands
                indent = len(lines[j]) - len(lines[j].lstrip())
                indent_str = ' ' * indent
                
                # Build the replacement code
                replacement = [
                    f'{indent_str}# Auto-activate playing player for stop command\n',
                    f'{indent_str}if self.player_control is not None:\n',
                    f'{indent_str}    states = self.player_control.states()\n',
                    f'{indent_str}    # Find the first playing player\n',
                    f'{indent_str}    for player in states.get("players", []):\n',
                    f'{indent_str}        if player.get("state", "").lower() == "playing":\n',
                    f'{indent_str}            player_name = player.get("name")\n',
                    f'{indent_str}            if player_name:\n',
                    f'{indent_str}                logging.info("Auto-activating playing player for stop: %s", player_name)\n',
                    f'{indent_str}                self.player_control.activate_player(player_name)\n',
                    f'{indent_str}                break\n',
                    f'{indent_str}self.player_control.send_command("Stop")\n'
                ]
                
                # Replace the line
                lines[j:j+1] = replacement
                fixed = True
                break
        if fixed:
            break

if not fixed:
    print("✗ Could not find stop() or send_command() call to replace")
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
if grep -q "# Auto-activate playing player for stop command" "$WEBSERVER"; then
    echo ""
    echo "3. Showing fixed code:"
    grep -B 2 -A 15 "# Auto-activate playing player for stop command" "$WEBSERVER" | head -20
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

