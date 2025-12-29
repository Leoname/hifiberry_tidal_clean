#!/bin/bash
# Diagnose why stop command isn't working even though fix is applied

echo "=========================================="
echo "Diagnosing Stop Command Issue"
echo "=========================================="
echo ""

# 1. Verify fix is applied
echo "1. Checking if fix is applied:"
if grep -q "self.player_control.stop()" /opt/audiocontrol2/ac2/webserver.py && ! grep -q "self.player_control.stop(ignore=" /opt/audiocontrol2/ac2/webserver.py; then
    echo "✓ Fix is applied"
else
    echo "✗ Fix is NOT applied - need to reapply"
    exit 1
fi
echo ""

# 2. Check AudioControl2 service status
echo "2. AudioControl2 Service Status:"
systemctl is-active audiocontrol2 && echo "✓ Running" || echo "✗ Not running"
echo ""

# 3. Check recent errors
echo "3. Recent AudioControl2 Errors (stop-related):"
journalctl -u audiocontrol2 -n 50 --no-pager 2>/dev/null | grep -i "stop\|error\|exception" | tail -10 || echo "No errors found"
echo ""

# 4. Test stop command via API
echo "4. Testing stop command via API:"
echo "Current MPD state:"
mpc status 2>/dev/null | head -1
echo ""
echo "Sending stop via API..."
RESPONSE=$(curl -s -X POST http://127.0.0.1:81/api/player/stop 2>/dev/null)
echo "Response: $RESPONSE"
sleep 1
echo "MPD state after stop:"
mpc status 2>/dev/null | head -1
echo ""

# 5. Check if AudioControl2 needs restart
echo "5. Checking if AudioControl2 was restarted after fix:"
LAST_RESTART=$(systemctl show audiocontrol2 -p ActiveEnterTimestamp --value 2>/dev/null)
FIX_TIME=$(stat -c %Y /opt/audiocontrol2/ac2/webserver.py 2>/dev/null)
if [ -n "$LAST_RESTART" ] && [ -n "$FIX_TIME" ]; then
    RESTART_EPOCH=$(date -d "$LAST_RESTART" +%s 2>/dev/null || echo "0")
    if [ "$RESTART_EPOCH" -lt "$FIX_TIME" ]; then
        echo "⚠️  AudioControl2 was NOT restarted after fix was applied"
        echo "   Fix time: $(date -d @$FIX_TIME)"
        echo "   Last restart: $LAST_RESTART"
        echo ""
        echo "   Solution: Restart AudioControl2:"
        echo "   systemctl restart audiocontrol2"
    else
        echo "✓ AudioControl2 was restarted after fix"
    fi
else
    echo "⚠️  Could not determine restart time"
fi
echo ""

# 6. Check what happens when we send stop directly
echo "6. Testing direct stop command:"
echo "Current state:"
mpc status 2>/dev/null | head -1
mpc stop >/dev/null 2>&1
sleep 1
echo "State after direct mpc stop:"
mpc status 2>/dev/null | head -1
echo ""

echo "=========================================="
echo "Summary:"
echo "=========================================="
if [ "$RESPONSE" != "ok" ]; then
    echo "✗ Stop command via API failed: $RESPONSE"
    echo ""
    echo "Possible causes:"
    echo "1. AudioControl2 needs to be restarted after fix"
    echo "2. There's still an error in the code"
    echo "3. MPD connection issue"
    echo ""
    echo "Try: systemctl restart audiocontrol2"
else
    echo "✓ Stop command via API succeeded"
    echo "   If UI still doesn't work, check browser/UI logs"
fi
echo ""

