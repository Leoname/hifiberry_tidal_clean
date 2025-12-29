#!/bin/bash
# Debug why MPD keeps restarting after stop

echo "=========================================="
echo "Debugging MPD Auto-Restart Issue"
echo "=========================================="
echo ""

echo "1. Current MPD state:"
mpc status
echo ""

echo "2. Current playlist:"
mpc playlist
echo ""

echo "3. MPD state file (if exists):"
if [ -f "/var/lib/mpd/state" ]; then
    echo "   Found: /var/lib/mpd/state"
    cat /var/lib/mpd/state | head -20
else
    echo "   Not found"
fi
echo ""

echo "4. MPD config file:"
if [ -f "/etc/mpd.conf" ]; then
    echo "   Checking for state_file and playlist_directory:"
    grep -E "state_file|playlist_directory" /etc/mpd.conf || echo "   Not found in config"
fi
echo ""

echo "5. Testing stop and clear manually:"
echo "   Stopping MPD..."
mpc stop
sleep 1
echo "   Clearing playlist..."
mpc clear
sleep 1
echo "   Current state:"
mpc status
echo ""

echo "6. Checking if playlist is really empty:"
PLAYLIST_COUNT=$(mpc playlist | wc -l)
echo "   Playlist items: $PLAYLIST_COUNT"
if [ "$PLAYLIST_COUNT" -gt 0 ]; then
    echo "   ✗ Playlist is NOT empty!"
    echo "   Playlist contents:"
    mpc playlist | head -5
else
    echo "   ✓ Playlist is empty"
fi
echo ""

echo "7. Checking MPD logs for auto-resume:"
journalctl -u mpd -n 20 --no-pager | grep -i "play\|resume\|start" | tail -10
echo ""

echo "=========================================="
echo "If playlist clears but playback resumes,"
echo "MPD might be loading from persistent state."
echo "Try: systemctl stop mpd && rm -f /var/lib/mpd/state && systemctl start mpd"
echo ""

