#!/bin/bash
# Debug script to check why UI controls aren't working for MPD

echo "=========================================="
echo "UI Controls Debug"
echo "=========================================="
echo ""

# 1. Check MPD status
echo "1. MPD Status:"
mpc status 2>/dev/null || echo "MPD not running or mpc not available"
echo ""

# 2. Check Tidal status file
echo "2. Tidal Status File:"
if [ -f "/tmp/tidal-status.json" ]; then
    echo "Status file EXISTS:"
    cat /tmp/tidal-status.json | python3 -m json.tool 2>/dev/null || cat /tmp/tidal-status.json
    STATE=$(cat /tmp/tidal-status.json | python3 -c "import sys, json; print(json.load(sys.stdin).get('state', 'UNKNOWN'))" 2>/dev/null || echo "UNKNOWN")
    MTIME=$(stat -c %Y /tmp/tidal-status.json 2>/dev/null || stat -f %m /tmp/tidal-status.json 2>/dev/null)
    NOW=$(date +%s)
    AGE=$((NOW - MTIME))
    echo ""
    echo "State: $STATE"
    echo "File age: ${AGE}s (should be < 10s for Tidal to be active)"
else
    echo "No status file (Tidal is idle)"
fi
echo ""

# 3. Check Tidal container state
echo "3. Tidal Container State:"
if docker ps | grep -q "tidal-connect"; then
    CONTAINER="tidal-connect"
elif docker ps | grep -q "tidal_connect"; then
    CONTAINER="tidal_connect"
else
    echo "No Tidal container found"
    CONTAINER=""
fi

if [ -n "$CONTAINER" ]; then
    STATE=$(docker exec "$CONTAINER" /usr/bin/tmux capture-pane -pS -10 2>/dev/null | grep -o 'PlaybackState::[A-Z]*' | cut -d: -f3 | tail -1)
    echo "Container: $CONTAINER"
    echo "Playback State: ${STATE:-UNKNOWN}"
else
    echo "No container running"
fi
echo ""

# 4. Check AudioControl2 active player
echo "4. AudioControl2 Active Player:"
# Try to get active player from AudioControl2 API
AC2_ACTIVE=$(curl -s http://127.0.0.1:81/api/player/status 2>/dev/null | python3 -c "import sys, json; d=json.load(sys.stdin); print(d.get('activePlayer', 'UNKNOWN'))" 2>/dev/null || echo "Could not query API")
echo "Active Player: ${AC2_ACTIVE}"
echo ""

# 5. Check AudioControl2 logs for Tidal plugin
echo "5. Recent AudioControl2 Tidal Plugin Logs:"
journalctl -u audiocontrol2 -n 50 --no-pager 2>/dev/null | grep -i "tidal" | tail -10 || echo "No Tidal logs found"
echo ""

# 6. Check if Tidal plugin thinks it's active
echo "6. Checking Tidal Plugin Status:"
if [ -f "/opt/audiocontrol2/ac2/players/tidalcontrol.py" ]; then
    echo "Tidal plugin installed: YES"
    # Try to check if plugin is reporting as active
    python3 << 'PYEOF'
import sys
sys.path.insert(0, '/opt/audiocontrol2')
try:
    from ac2.players.tidalcontrol import TidalControl
    plugin = TidalControl()
    plugin.start()
    is_active = plugin.is_active()
    state = plugin.get_state()
    print(f"Tidal plugin reports: is_active={is_active}, state={state}")
except Exception as e:
    print(f"Could not check plugin: {e}")
PYEOF
else
    echo "Tidal plugin not found at /opt/audiocontrol2/ac2/players/tidalcontrol.py"
fi
echo ""

# 7. Check volume bridge logs
echo "7. Recent Volume Bridge Logs:"
journalctl -u tidal-volume-bridge.service -n 30 --no-pager 2>/dev/null | tail -15 || echo "No volume bridge logs found"
echo ""

# 8. Test MPD control directly
echo "8. Testing MPD Control Directly:"
echo "Current MPD state:"
mpc status 2>/dev/null | head -3
echo ""
echo "Attempting to pause MPD (this should work even if UI doesn't)..."
mpc pause 2>&1
sleep 1
echo "MPD state after pause command:"
mpc status 2>/dev/null | head -3
echo ""

# 9. Recommendations
echo "=========================================="
echo "Diagnosis:"
echo "=========================================="

if [ -f "/tmp/tidal-status.json" ]; then
    AGE=$(($(date +%s) - $(stat -c %Y /tmp/tidal-status.json 2>/dev/null || stat -f %m /tmp/tidal-status.json 2>/dev/null)))
    if [ "$AGE" -lt 10 ]; then
        echo "⚠️  PROBLEM: Tidal status file is recent (< 10s old)"
        echo "   This means Tidal plugin might think it's active"
        echo "   Solution: Remove status file when MPD is playing"
    else
        echo "✓ Tidal status file is stale (> 10s old) - plugin should not be active"
    fi
else
    echo "✓ No Tidal status file - Tidal plugin should not be active"
fi

if [ "$AC2_ACTIVE" = "Tidal" ] || [ "$AC2_ACTIVE" = "tidal" ]; then
    echo "⚠️  PROBLEM: AudioControl2 thinks Tidal is the active player"
    echo "   This is why UI controls aren't working for MPD"
    echo "   Solution: Restart AudioControl2 or fix Tidal plugin to report inactive"
else
    echo "✓ AudioControl2 active player: ${AC2_ACTIVE:-MPD/Other}"
fi

echo ""
echo "Try these fixes:"
echo "1. Remove Tidal status file: rm -f /tmp/tidal-status.json"
echo "2. Restart AudioControl2: systemctl restart audiocontrol2"
echo "3. Check if MPD can be controlled: mpc pause && mpc play"
echo "4. Check volume bridge logs: journalctl -u tidal-volume-bridge.service -f"

