#!/bin/bash
# Quick system status check

echo "=========================================="
echo "System Status Check"
echo "=========================================="
echo ""

# 1. MPD Status
echo "1. MPD Status:"
mpc status 2>/dev/null || echo "MPD not running"
echo ""

# 2. Tidal Status
echo "2. Tidal Status:"
if [ -f "/tmp/tidal-status.json" ]; then
    STATE=$(cat /tmp/tidal-status.json | python3 -c "import sys, json; print(json.load(sys.stdin).get('state', 'UNKNOWN'))" 2>/dev/null || echo "UNKNOWN")
    echo "Status file exists - State: $STATE"
else
    echo "No status file (Tidal is idle)"
fi

if docker ps | grep -q "tidal-connect"; then
    CONTAINER="tidal-connect"
elif docker ps | grep -q "tidal_connect"; then
    CONTAINER="tidal_connect"
else
    CONTAINER=""
fi

if [ -n "$CONTAINER" ]; then
    TIDAL_STATE=$(docker exec "$CONTAINER" /usr/bin/tmux capture-pane -pS -10 2>/dev/null | grep -o 'PlaybackState::[A-Z]*' | cut -d: -f3 | tail -1)
    echo "Container: $CONTAINER - State: ${TIDAL_STATE:-UNKNOWN}"
else
    echo "No Tidal container running"
fi
echo ""

# 3. AudioControl2 Active Player
echo "3. AudioControl2 Active Player:"
AC2_ACTIVE=$(curl -s http://127.0.0.1:81/api/player/status 2>/dev/null | python3 -c "import sys, json; d=json.load(sys.stdin); print(d.get('activePlayer', 'UNKNOWN'))" 2>/dev/null || echo "Could not query")
echo "Active Player: ${AC2_ACTIVE}"
echo ""

# 4. Service Status
echo "4. Service Status:"
systemctl is-active --quiet mpd && echo "✓ MPD: running" || echo "✗ MPD: not running"
systemctl is-active --quiet audiocontrol2 && echo "✓ AudioControl2: running" || echo "✗ AudioControl2: not running"
systemctl is-active --quiet tidal-gio.service && echo "✓ Tidal: running" || echo "✗ Tidal: not running"
systemctl is-active --quiet tidal-volume-bridge.service && echo "✓ Volume Bridge: running" || echo "✗ Volume Bridge: not running"
echo ""

# 5. Test UI Control
echo "5. Testing UI Control:"
if [ "$AC2_ACTIVE" != "UNKNOWN" ] && [ -n "$AC2_ACTIVE" ]; then
    echo "✓ AudioControl2 has active player: ${AC2_ACTIVE}"
    echo "  UI controls should work!"
else
    echo "⚠️  AudioControl2 active player: ${AC2_ACTIVE}"
    echo "  UI controls may not work"
fi
echo ""

echo "=========================================="
echo "Summary:"
echo "=========================================="

MPD_STATE=$(mpc status 2>/dev/null | head -1 | grep -oE '\[playing\]|\[paused\]|\[stopped\]' || echo "")
if [ -n "$MPD_STATE" ]; then
    echo "MPD: $MPD_STATE"
else
    echo "MPD: not running or no track"
fi

if [ -f "/tmp/tidal-status.json" ]; then
    TIDAL_STATE=$(cat /tmp/tidal-status.json | python3 -c "import sys, json; print(json.load(sys.stdin).get('state', 'UNKNOWN'))" 2>/dev/null || echo "UNKNOWN")
    echo "Tidal: $TIDAL_STATE"
else
    echo "Tidal: idle (no status file)"
fi

echo "AudioControl2 Active: ${AC2_ACTIVE}"

