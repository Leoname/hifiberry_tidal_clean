#!/bin/bash
# Test stop command after v3 fix

echo "=========================================="
echo "Testing Stop Command After v3 Fix"
echo "=========================================="
echo ""

# 1. Verify v3 fix is applied
echo "1. Checking if v3 fix is applied:"
if grep -q 'self.player_control.send_command("Stop")' /opt/audiocontrol2/ac2/webserver.py; then
    echo "✓ v3 fix is applied"
else
    echo "✗ v3 fix is NOT applied"
    exit 1
fi
echo ""

# 2. Check current MPD state
echo "2. Current MPD State:"
mpc status 2>/dev/null | head -3
echo ""

# 3. Test stop via API
echo "3. Testing stop via API:"
RESPONSE=$(curl -s -X POST http://127.0.0.1:81/api/player/stop 2>/dev/null)
echo "Response: $RESPONSE"
sleep 1
echo "MPD state after stop:"
mpc status 2>/dev/null | head -1
echo ""

# 4. Check AudioControl2 logs for errors
echo "4. Recent AudioControl2 Errors:"
journalctl -u audiocontrol2 -n 30 --no-pager 2>/dev/null | grep -i "error\|exception\|traceback\|stop" | tail -15
echo ""

# 5. Check what send_command does with "Stop"
echo "5. Checking how send_command handles 'Stop':"
echo "Looking at controller send_command method..."
if [ -f "/opt/audiocontrol2/ac2/controller.py" ]; then
    grep -A 20 "def send_command" /opt/audiocontrol2/ac2/controller.py | head -25
fi
echo ""

echo "=========================================="
echo "If still failing, the issue might be:"
echo "1. send_command('Stop') expects CMD_STOP constant, not string"
echo "2. Need to import CMD_STOP in webserver"
echo "3. Need to use different approach"
echo ""

