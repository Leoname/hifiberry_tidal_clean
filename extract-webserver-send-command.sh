#!/bin/bash
# Extract webserver send_command method to see how it handles stop

WEBSERVER="/opt/audiocontrol2/ac2/webserver.py"

echo "=========================================="
echo "Extracting Webserver send_command Method"
echo "=========================================="
echo ""

# Find send_command method
SEND_CMD_LINE=$(grep -n "def send_command" "$WEBSERVER" | head -1 | cut -d: -f1)

if [ -n "$SEND_CMD_LINE" ] && [ "$SEND_CMD_LINE" -gt 0 ] 2>/dev/null; then
    echo "Found send_command at line $SEND_CMD_LINE:"
    END_LINE=$((SEND_CMD_LINE+80))
    sed -n "${SEND_CMD_LINE},${END_LINE}p" "$WEBSERVER"
else
    echo "send_command method not found"
fi
echo ""

# Also check how stop is handled
echo "=== How stop command is handled ==="
grep -n -A 10 "stop\|Stop\|STOP" "$WEBSERVER" | grep -A 10 "def\|elif\|if.*stop" | head -30
echo ""

