#!/bin/bash
# Test if stop command is working correctly

echo "=========================================="
echo "Testing Stop Command"
echo "=========================================="
echo ""

echo "1. Current MPD state:"
mpc status
echo ""

echo "2. Current playlist:"
PLAYLIST_COUNT=$(mpc playlist | wc -l)
echo "   Items: $PLAYLIST_COUNT"
if [ "$PLAYLIST_COUNT" -gt 0 ]; then
    echo "   Playlist contents:"
    mpc playlist | head -3
else
    echo "   ✓ Playlist is empty"
fi
echo ""

echo "3. Verifying fixes are applied:"
echo "   MPDControl CMD_STOP handler:"
if grep -A 5 "elif command == CMD_STOP:" /opt/audiocontrol2/ac2/players/mpdcontrol.py | grep -q "self.client.clear()"; then
    echo "   ✓ clear() is called in MPDControl"
    grep -A 5 "elif command == CMD_STOP:" /opt/audiocontrol2/ac2/players/mpdcontrol.py | head -6
else
    echo "   ✗ clear() NOT found in MPDControl"
fi
echo ""

echo "4. Testing stop via API:"
echo "   Sending stop command..."
RESPONSE=$(curl -s -X POST http://127.0.0.1:81/api/player/stop 2>/dev/null)
echo "   Response: $RESPONSE"
sleep 2
echo ""
echo "   MPD state after stop:"
mpc status | head -1
echo ""
echo "   Playlist after stop:"
PLAYLIST_AFTER=$(mpc playlist | wc -l)
echo "   Items: $PLAYLIST_AFTER"
if [ "$PLAYLIST_AFTER" -eq 0 ]; then
    echo "   ✓ Playlist is empty (stop is working!)"
else
    echo "   ✗ Playlist still has items"
    mpc playlist | head -3
fi
echo ""

echo "5. Checking AudioControl2 logs:"
journalctl -u audiocontrol2 -n 10 --no-pager | grep -i "stop\|clear" | tail -5
echo ""

echo "=========================================="
if [ "$PLAYLIST_AFTER" -eq 0 ]; then
    echo "✓ Stop command appears to be working!"
    echo "  Playlist is cleared after stop."
else
    echo "✗ Stop command may not be working correctly"
    echo "  Playlist still has items after stop."
fi
echo "=========================================="

