#!/bin/bash
# Simple fix for AudioControl2 active player bug

echo "=========================================="
echo "Applying AudioControl2 Active Player Fix"
echo "=========================================="
echo ""

WEBSERVER="/opt/audiocontrol2/ac2/webserver.py"
BACKUP="${WEBSERVER}.backup.$(date +%Y%m%d_%H%M%S)"

# Check if file exists
if [ ! -f "$WEBSERVER" ]; then
    echo "✗ Webserver file not found at $WEBSERVER"
    exit 1
fi

# Check if already fixed
if grep -q "Auto-activating playing player" "$WEBSERVER"; then
    echo "✓ Fix already applied!"
    exit 0
fi

# Create backup
echo "1. Creating backup..."
cp "$WEBSERVER" "$BACKUP"
echo "✓ Backup: $BACKUP"
echo ""

# Find the line to replace
LINE_NUM=$(grep -n "if not(self.send_command(command)):" "$WEBSERVER" | head -1 | cut -d: -f1)

if [ -z "$LINE_NUM" ] || [ "$LINE_NUM" -lt 1 ]; then
    echo "✗ Could not find target line"
    exit 1
fi

echo "2. Found target at line $LINE_NUM"
echo ""

# Create temp file with the fix
TMPFILE=$(mktemp)

# Copy everything before the target line
sed -n "1,$((LINE_NUM-1))p" "$WEBSERVER" > "$TMPFILE"

# Add the new code
cat >> "$TMPFILE" << 'FIX_CODE'
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
            
            if not result:
FIX_CODE

# Copy everything after the target line (skip the old if statement and the next few lines)
# We need to skip: "if not(self.send_command(command)):" and "response.status = 500" and "return ..."
END_LINE=$((LINE_NUM+3))
TOTAL_LINES=$(wc -l < "$WEBSERVER")
sed -n "$((END_LINE+1)),${TOTAL_LINES}p" "$WEBSERVER" >> "$TMPFILE"

# Replace original file
mv "$TMPFILE" "$WEBSERVER"

# Verify
if grep -q "Auto-activating playing player" "$WEBSERVER"; then
    echo "✓ Fix applied successfully!"
    echo ""
    echo "3. Modified code:"
    LINE_NUM=$(grep -n "def playercontrol_handler" "$WEBSERVER" | head -1 | cut -d: -f1)
    sed -n "${LINE_NUM},$((LINE_NUM+30))p" "$WEBSERVER"
    echo ""
    echo "=========================================="
    echo "Next steps:"
    echo "=========================================="
    echo "1. Restart AudioControl2:"
    echo "   systemctl restart audiocontrol2"
    echo ""
    echo "2. Test UI controls with MPD playing"
    echo ""
    echo "3. If issues, restore backup:"
    echo "   cp $BACKUP $WEBSERVER"
    echo "   systemctl restart audiocontrol2"
    echo ""
else
    echo "✗ Fix verification failed! Restoring backup..."
    cp "$BACKUP" "$WEBSERVER"
    exit 1
fi

