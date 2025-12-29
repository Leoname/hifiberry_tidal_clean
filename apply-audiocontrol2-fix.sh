#!/bin/bash
# Apply fix for AudioControl2 active player bug

echo "=========================================="
echo "Applying AudioControl2 Active Player Fix"
echo "=========================================="
echo ""

WEBSERVER="/opt/audiocontrol2/ac2/webserver.py"
BACKUP="${WEBSERVER}.backup.$(date +%Y%m%d_%H%M%S)"

# 1. Check if file exists
if [ ! -f "$WEBSERVER" ]; then
    echo "✗ Webserver file not found at $WEBSERVER"
    exit 1
fi

echo "✓ Found webserver file: $WEBSERVER"
echo ""

# 2. Create backup
echo "1. Creating backup..."
cp "$WEBSERVER" "$BACKUP"
echo "✓ Backup created: $BACKUP"
echo ""

# 3. Check if fix already applied
if grep -q "Auto-activating playing player" "$WEBSERVER"; then
    echo "⚠️  Fix appears to already be applied!"
    echo "   Remove the backup and re-run if you want to re-apply."
    exit 0
fi

# 4. Find the playercontrol_handler function
echo "2. Locating playercontrol_handler function..."
LINE_NUM=$(grep -n "def playercontrol_handler" "$WEBSERVER" | head -1 | cut -d: -f1)

if [ -z "$LINE_NUM" ] || [ "$LINE_NUM" -lt 1 ]; then
    echo "✗ Could not find playercontrol_handler function"
    exit 1
fi

echo "✓ Found at line $LINE_NUM"
echo ""

# 5. Show current code
echo "3. Current code (lines $LINE_NUM-$((LINE_NUM+10))):"
sed -n "${LINE_NUM},$((LINE_NUM+10))p" "$WEBSERVER"
echo ""

# 6. Apply the fix
echo "4. Applying fix..."
python3 << 'PYTHON_SCRIPT'
import sys
import re

webserver_file = "/opt/audiocontrol2/ac2/webserver.py"

# Read the file
with open(webserver_file, 'r') as f:
    content = f.read()

# Find the playercontrol_handler function
pattern = r'(def playercontrol_handler\(self, command\):\s+try:\s+if not\(self\.send_command\(command\)\):)'

# Check if already patched
if "Auto-activating playing player" in content:
    print("⚠️  Fix already applied!")
    sys.exit(0)

# Replace the simple check with the auto-activation logic
replacement = r'''def playercontrol_handler(self, command):
        try:
            # Try to send command
            result = self.send_command(command)
            
            # If command failed because active_player is None, try to auto-select playing player
            if not result and self.player_control is not None:
                states = self.player_control.states()
                # Find the first playing player
                for player in states.get("players", []):
                    if player.get("state", "").lower() == "playing":
                        player_name = player.get("name")
                        if player_name:
                            logging.info("Auto-activating playing player: %s", player_name)
                            # Activate the playing player
                            if self.activate_player(player_name):
                                # Retry the command
                                result = self.send_command(command)
                                break
            
            if not result:'''

# Try to match the exact pattern
old_pattern = r'def playercontrol_handler\(self, command\):\s+try:\s+if not\(self\.send_command\(command\)\):'
new_code = '''def playercontrol_handler(self, command):
        try:
            # Try to send command
            result = self.send_command(command)
            
            # If command failed because active_player is None, try to auto-select playing player
            if not result and self.player_control is not None:
                states = self.player_control.states()
                # Find the first playing player
                for player in states.get("players", []):
                    if player.get("state", "").lower() == "playing":
                        player_name = player.get("name")
                        if player_name:
                            logging.info("Auto-activating playing player: %s", player_name)
                            # Activate the playing player
                            if self.activate_player(player_name):
                                # Retry the command
                                result = self.send_command(command)
                                break
            
            if not result:'''

# Replace using a more flexible approach
lines = content.split('\n')
new_lines = []
i = 0
found = False

while i < len(lines):
    line = lines[i]
    
    # Look for the function definition
    if 'def playercontrol_handler(self, command):' in line:
        found = True
        new_lines.append(line)
        i += 1
        
        # Skip 'try:'
        if i < len(lines) and 'try:' in lines[i]:
            new_lines.append(lines[i])
            i += 1
        
        # Replace the if statement
        if i < len(lines) and 'if not(self.send_command(command)):' in lines[i]:
            # Add the new logic
            new_lines.append('            # Try to send command')
            new_lines.append('            result = self.send_command(command)')
            new_lines.append('            ')
            new_lines.append('            # If command failed because active_player is None, try to auto-select playing player')
            new_lines.append('            if not result and self.player_control is not None:')
            new_lines.append('                states = self.player_control.states()')
            new_lines.append('                # Find the first playing player')
            new_lines.append('                for player in states.get("players", []):')
            new_lines.append('                    if player.get("state", "").lower() == "playing":')
            new_lines.append('                        player_name = player.get("name")')
            new_lines.append('                        if player_name:')
            new_lines.append('                            logging.info("Auto-activating playing player: %s", player_name)')
            new_lines.append('                            # Activate the playing player')
            new_lines.append('                            if self.activate_player(player_name):')
            new_lines.append('                                # Retry the command')
            new_lines.append('                                result = self.send_command(command)')
            new_lines.append('                                break')
            new_lines.append('            ')
            new_lines.append('            if not result:')
            i += 1
        else:
            # Keep original line if pattern doesn't match
            new_lines.append(lines[i])
            i += 1
    else:
        new_lines.append(line)
        i += 1

if not found:
    print("✗ Could not find playercontrol_handler function")
    sys.exit(1)

# Write the modified content
with open(webserver_file, 'w') as f:
    f.write('\n'.join(new_lines))

print("✓ Fix applied successfully!")
PYTHON_SCRIPT

if [ $? -ne 0 ]; then
    echo "✗ Failed to apply fix. Restoring backup..."
    cp "$BACKUP" "$WEBSERVER"
    exit 1
fi

echo ""

# 7. Verify the fix
echo "5. Verifying fix..."
if grep -q "Auto-activating playing player" "$WEBSERVER"; then
    echo "✓ Fix verified!"
    echo ""
    echo "6. Showing modified code:"
    LINE_NUM=$(grep -n "def playercontrol_handler" "$WEBSERVER" | head -1 | cut -d: -f1)
    sed -n "${LINE_NUM},$((LINE_NUM+30))p" "$WEBSERVER"
    echo ""
    echo "=========================================="
    echo "Fix Applied Successfully!"
    echo "=========================================="
    echo ""
    echo "Next steps:"
    echo "1. Restart AudioControl2: systemctl restart audiocontrol2"
    echo "2. Test UI controls with MPD playing"
    echo "3. If issues persist, restore backup:"
    echo "   cp $BACKUP $WEBSERVER"
    echo "   systemctl restart audiocontrol2"
    echo ""
else
    echo "✗ Fix verification failed!"
    echo "Restoring backup..."
    cp "$BACKUP" "$WEBSERVER"
    exit 1
fi

