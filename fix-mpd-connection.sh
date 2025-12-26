#!/bin/bash
# Fix MPD connection issue in AudioControl2

echo "=========================================="
echo "Fixing MPD Connection in AudioControl2"
echo "=========================================="
echo ""

# 1. Check MPD status
echo "1. MPD Service Status:"
systemctl status mpd --no-pager -l | head -10
echo ""

# 2. Test MPD connection directly
echo "2. Testing MPD Connection:"
mpc status 2>&1
echo ""

# 3. Check MPD socket
echo "3. Checking MPD Socket:"
if [ -S /run/mpd/socket ]; then
    echo "✓ MPD socket exists: /run/mpd/socket"
    ls -la /run/mpd/socket
elif [ -S /var/run/mpd/socket ]; then
    echo "✓ MPD socket exists: /var/run/mpd/socket"
    ls -la /var/run/mpd/socket
else
    echo "⚠️  MPD socket not found in standard locations"
    echo "Searching for MPD socket..."
    find /run /var/run -name "*mpd*socket*" 2>/dev/null || echo "No MPD socket found"
fi
echo ""

# 4. Restart MPD to refresh connection
echo "4. Restarting MPD to refresh connection..."
systemctl restart mpd
sleep 2
echo "✓ MPD restarted"
echo ""

# 5. Test MPD connection again
echo "5. Testing MPD Connection After Restart:"
mpc status 2>&1
echo ""

# 6. Restart AudioControl2 to reconnect
echo "6. Restarting AudioControl2 to reconnect to MPD..."
systemctl restart audiocontrol2
sleep 3
echo "✓ AudioControl2 restarted"
echo ""

# 7. Check for connection errors
echo "7. Checking for Connection Errors:"
sleep 2
journalctl -u audiocontrol2 -n 20 --no-pager 2>/dev/null | grep -i "connection\|error\|mpd" | tail -5 || echo "No recent errors"
echo ""

# 8. Test UI command
echo "8. Testing if UI commands work now:"
# Try to get active player
AC2_ACTIVE=$(curl -s http://127.0.0.1:81/api/player/status 2>/dev/null | python3 -c "import sys, json; d=json.load(sys.stdin); print(d.get('activePlayer', 'UNKNOWN'))" 2>/dev/null || echo "Could not query")
echo "Active Player: ${AC2_ACTIVE}"
echo ""

# 9. Recommendations
echo "=========================================="
echo "Status:"
echo "=========================================="

if [ "$AC2_ACTIVE" != "UNKNOWN" ] && [ -n "$AC2_ACTIVE" ]; then
    echo "✓ AudioControl2 now detects active player: ${AC2_ACTIVE}"
    echo "  UI controls should work now!"
else
    echo "⚠️  AudioControl2 still shows active player as: ${AC2_ACTIVE}"
    echo ""
    echo "Additional troubleshooting:"
    echo "1. Check MPD configuration:"
    echo "   cat /etc/mpd.conf | grep -E 'bind_to_address|port'"
    echo ""
    echo "2. Check AudioControl2 MPD plugin configuration:"
    echo "   grep -r 'mpd\|MPD' /opt/audiocontrol2/ac2/players/ | head -10"
    echo ""
    echo "3. Check if MPD is listening:"
    echo "   netstat -tlnp | grep mpd || ss -tlnp | grep mpd"
    echo ""
    echo "4. Check AudioControl2 full logs:"
    echo "   journalctl -u audiocontrol2 -n 100 | grep -i mpd"
fi

