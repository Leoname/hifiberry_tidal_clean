#!/bin/bash
# Fix AudioControl2 active player detection

echo "=========================================="
echo "Fixing AudioControl2 Active Player Detection"
echo "=========================================="
echo ""

# 1. Check AudioControl2 status
echo "1. AudioControl2 Service Status:"
systemctl status audiocontrol2 --no-pager -l | head -15
echo ""

# 2. Check AudioControl2 logs for errors
echo "2. Recent AudioControl2 Errors:"
journalctl -u audiocontrol2 -n 100 --no-pager 2>/dev/null | grep -i "error\|exception\|traceback\|failed" | tail -10 || echo "No errors found"
echo ""

# 3. Check what players AudioControl2 knows about
echo "3. AudioControl2 Player Detection:"
# Try to query the API for all players
curl -s http://127.0.0.1:81/api/player/status 2>/dev/null | python3 -m json.tool 2>/dev/null | head -30 || echo "Could not query API"
echo ""

# 4. Check MPD status from AudioControl2 perspective
echo "4. MPD Status (from system):"
mpc status 2>/dev/null || echo "MPD not running"
echo ""

# 5. Restart AudioControl2 to refresh player detection
echo "5. Restarting AudioControl2 to refresh player detection..."
systemctl restart audiocontrol2
sleep 3
echo "✓ AudioControl2 restarted"
echo ""

# 6. Check active player again
echo "6. Active Player After Restart:"
sleep 2
AC2_ACTIVE=$(curl -s http://127.0.0.1:81/api/player/status 2>/dev/null | python3 -c "import sys, json; d=json.load(sys.stdin); print(d.get('activePlayer', 'UNKNOWN'))" 2>/dev/null || echo "Could not query")
echo "Active Player: ${AC2_ACTIVE}"
echo ""

# 7. Recommendations
echo "=========================================="
echo "Recommendations:"
echo "=========================================="

if [ "$AC2_ACTIVE" = "UNKNOWN" ] || [ -z "$AC2_ACTIVE" ]; then
    echo "⚠️  AudioControl2 still doesn't detect an active player"
    echo ""
    echo "Try these additional fixes:"
    echo "1. Check AudioControl2 configuration:"
    echo "   cat /opt/audiocontrol2/audiocontrol2.py | grep -A 5 'mpd\|MPD'"
    echo ""
    echo "2. Check if MPD plugin is loaded:"
    echo "   ls -la /opt/audiocontrol2/ac2/players/ | grep mpd"
    echo ""
    echo "3. Check AudioControl2 full logs:"
    echo "   journalctl -u audiocontrol2 -n 200 | tail -50"
    echo ""
    echo "4. Try stopping and starting MPD:"
    echo "   systemctl restart mpd"
    echo "   mpc play"
else
    echo "✓ AudioControl2 now detects active player: ${AC2_ACTIVE}"
    echo "  UI controls should now work!"
fi

