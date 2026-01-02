#!/bin/bash
# Debug why AudioControl2 shows wrong state

echo "=========================================="
echo "Debugging State Detection Issue"
echo "=========================================="
echo ""

echo "1. Actual MPD State:"
mpc status | head -1
echo ""

echo "2. Direct MPD Connection Test:"
python3 << 'PYTHON_TEST'
import mpd
try:
    client = mpd.MPDClient()
    client.connect("localhost", 6600)
    status = client.status()
    print(f"   State: {status.get('state', 'unknown')}")
    print(f"   Song ID: {status.get('songid', 'none')}")
    client.close()
except Exception as e:
    print(f"   Error: {e}")
PYTHON_TEST
echo ""

echo "3. AudioControl2 API - All Players:"
curl -s http://127.0.0.1:81/api/player/status 2>/dev/null | python3 -m json.tool 2>/dev/null | grep -A 5 '"name": "mpd"' | head -10
echo ""

echo "4. Checking MPDControl get_state() method:"
if [ -f "/opt/audiocontrol2/ac2/players/mpdcontrol.py" ]; then
    echo "   get_state() method:"
    grep -A 25 "def get_state(self):" /opt/audiocontrol2/ac2/players/mpdcontrol.py | head -30
fi
echo ""

echo "5. AudioControl2 Logs - Recent State Updates:"
journalctl -u audiocontrol2 -n 50 --no-pager 2>/dev/null | grep -i "mpd\|state\|get_state" | tail -15
echo ""

echo "6. Testing MPDControl connection directly:"
python3 << 'PYTHON_DIRECT'
import sys
sys.path.insert(0, '/opt/audiocontrol2')
try:
    from ac2.players.mpdcontrol import MPDControl
    mpd_control = MPDControl()
    state = mpd_control.get_state()
    print(f"   MPDControl.get_state() returned: {state}")
    meta = mpd_control.get_meta()
    print(f"   Artist: {meta.artist if hasattr(meta, 'artist') else 'N/A'}")
    print(f"   Title: {meta.title if hasattr(meta, 'title') else 'N/A'}")
except Exception as e:
    print(f"   Error: {e}")
    import traceback
    traceback.print_exc()
PYTHON_DIRECT
echo ""

echo "7. Checking if reconnect fix is applied:"
if grep -q "self.reconnect()" /opt/audiocontrol2/ac2/players/mpdcontrol.py 2>/dev/null; then
    echo "   ✓ Reconnect fix is present"
    grep -A 3 "except:" /opt/audiocontrol2/ac2/players/mpdcontrol.py | grep -A 3 "reconnect" | head -5
else
    echo "   ✗ Reconnect fix NOT found"
fi
echo ""

echo "=========================================="
echo "If state is wrong, try:"
echo "1. Restart AudioControl2: systemctl restart audiocontrol2"
echo "2. Check if fix-mpd-state-simple.sh was applied"
echo "3. Re-apply fix if needed: ./fix-mpd-state-simple.sh"
echo "=========================================="

