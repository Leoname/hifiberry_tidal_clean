#!/bin/bash
# Debug why UI shows playing when MPD is stopped

echo "=========================================="
echo "Debugging UI State Issue"
echo "=========================================="
echo ""

echo "1. Actual MPD state:"
mpc status
echo ""

echo "2. AudioControl2 API - Player states:"
curl -s http://127.0.0.1:81/api/player/status 2>/dev/null | python3 -m json.tool 2>/dev/null || curl -s http://127.0.0.1:81/api/player/status
echo ""

echo "3. AudioControl2 API - Active player:"
curl -s http://127.0.0.1:81/api/player/active 2>/dev/null
echo ""
echo ""

echo "4. AudioControl2 logs (recent MPD state updates):"
journalctl -u audiocontrol2 -n 30 --no-pager 2>/dev/null | grep -i "mpd\|state\|playing\|stopped" | tail -10
echo ""

echo "5. Checking MPDControl state method:"
if [ -f "/opt/audiocontrol2/ac2/players/mpdcontrol.py" ]; then
    echo "   Looking for state() or get_state() method:"
    grep -A 10 "def.*state" /opt/audiocontrol2/ac2/players/mpdcontrol.py | head -15
fi
echo ""

echo "6. Testing direct MPD connection:"
python3 << 'PYTHON_TEST'
import mpd
try:
    client = mpd.MPDClient()
    client.connect("localhost", 6600)
    status = client.status()
    print(f"   MPD state: {status.get('state', 'unknown')}")
    print(f"   MPD song: {status.get('song', 'none')}")
    client.close()
except Exception as e:
    print(f"   Error: {e}")
PYTHON_TEST
echo ""

echo "=========================================="
echo "If MPD is stopped but UI shows playing,"
echo "MPDControl might not be updating state correctly."
echo "=========================================="

