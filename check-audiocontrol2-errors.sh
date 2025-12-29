#!/bin/bash
# Check AudioControl2 error logs in detail

echo "=========================================="
echo "AudioControl2 Error Analysis"
echo "=========================================="
echo ""

# 1. Get detailed error logs
echo "1. Recent Error Logs (with tracebacks):"
journalctl -u audiocontrol2 -n 200 --no-pager 2>/dev/null | grep -A 20 "500\|error\|Error\|ERROR\|Traceback\|Exception" | tail -50
echo ""

# 2. Check specifically for command errors
echo "2. Command-Related Errors:"
journalctl -u audiocontrol2 -n 200 --no-pager 2>/dev/null | grep -B 5 -A 15 "command\|Command\|/api/player/command" | tail -30
echo ""

# 3. Check AudioControl2 source for command handling
echo "3. Checking AudioControl2 Command Handling:"
if [ -f "/opt/audiocontrol2/audiocontrol2.py" ]; then
    echo "Looking for command endpoint handler..."
    grep -A 30 "/api/player/command\|def.*command" /opt/audiocontrol2/audiocontrol2.py 2>/dev/null | head -40 || echo "Could not find command handler"
else
    echo "AudioControl2 main file not found"
fi
echo ""

# 4. Test with activePlayer explicitly set
echo "4. Testing if activePlayer needs to be set:"
# Check if there's a way to set active player via API
curl -s http://127.0.0.1:81/api/player/status | python3 -c "
import sys, json
d = json.load(sys.stdin)
# Find playing player
for p in d.get('players', []):
    if p.get('state') == 'playing':
        print(f\"Playing player found: {p['name']}\")
        print(f\"This should be the active player, but activePlayer is: {d.get('activePlayer')}\")
"
echo ""

# 5. Check AudioControl2 player selection logic
echo "5. Checking Player Selection Logic:"
if [ -f "/opt/audiocontrol2/audiocontrol2.py" ]; then
    echo "Looking for active player selection..."
    grep -A 20 "activePlayer\|get_active\|determine.*active\|select.*player" /opt/audiocontrol2/audiocontrol2.py 2>/dev/null | head -50 || echo "Could not find active player logic"
fi
echo ""

echo "=========================================="
echo "Key Findings:"
echo "=========================================="
echo "1. API returns HTTP 500 for commands"
echo "2. MPD is detected as playing"
echo "3. activePlayer is None (not set)"
echo "4. Direct mpc control works"
echo ""
echo "Likely cause: AudioControl2 requires activePlayer to be set"
echo "before it can route commands. Since activePlayer is None,"
echo "commands fail with 500 error."
echo ""
echo "Possible solutions:"
echo "1. Find how AudioControl2 sets activePlayer"
echo "2. Manually trigger activePlayer selection"
echo "3. Check if there's a bug in AudioControl2's player selection"
echo "4. Use mpc directly as workaround (but UI won't work)"

