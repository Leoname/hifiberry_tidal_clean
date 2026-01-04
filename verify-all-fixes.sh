#!/bin/bash
# Verify all fixes are applied and working

echo "=========================================="
echo "Verifying All Fixes"
echo "=========================================="
echo ""

echo "1. Checking is_active() fix:"
if [ -f "/opt/audiocontrol2/ac2/players/mpdcontrol.py" ]; then
    if grep -A 10 "def is_active" /opt/audiocontrol2/ac2/players/mpdcontrol.py | grep -q "get_state()"; then
        echo "   ✓ is_active() fix is applied (calls get_state())"
        grep -A 10 "def is_active" /opt/audiocontrol2/ac2/players/mpdcontrol.py | head -12
    else
        echo "   ✗ is_active() fix may not be applied"
        echo "   Current implementation:"
        grep -A 5 "def is_active" /opt/audiocontrol2/ac2/players/mpdcontrol.py | head -8
    fi
else
    echo "   ✗ MPDControl file not found"
fi
echo ""

echo "2. Checking activePlayer fix:"
if [ -f "/opt/audiocontrol2/ac2/controller.py" ]; then
    if grep -A 20 "def states(self):" /opt/audiocontrol2/ac2/controller.py | grep -q "activePlayer"; then
        echo "   ✓ activePlayer fix is applied"
        grep -A 20 "def states(self):" /opt/audiocontrol2/ac2/controller.py | grep -A 5 "activePlayer" | head -8
    else
        echo "   ✗ activePlayer fix may not be applied"
    fi
else
    echo "   ✗ Controller file not found"
fi
echo ""

echo "3. Testing MPDControl.is_active() when playing:"
python3 << 'PYTHON_TEST'
import sys
sys.path.insert(0, '/opt/audiocontrol2')
try:
    from ac2.players.mpdcontrol import MPDControl
    
    mpd = MPDControl()
    mpd.start()
    
    state = mpd.get_state()
    is_active = mpd.is_active()
    
    print(f"   get_state(): {state}")
    print(f"   is_active(): {is_active}")
    print(f"   Expected: is_active() should be True when state is 'playing' or 'paused'")
    if state in ['playing', 'paused'] and is_active:
        print("   ✓ is_active() is working correctly")
    elif state in ['playing', 'paused'] and not is_active:
        print("   ✗ is_active() is NOT working - returns False when it should be True")
    else:
        print(f"   ⚠ State is '{state}', is_active()={is_active}")
except Exception as e:
    print(f"   Error: {e}")
    import traceback
    traceback.print_exc()
PYTHON_TEST
echo ""

echo "4. Current API Status:"
curl -s http://localhost:81/api/player/status | python3 -c "
import sys, json
data = json.load(sys.stdin)
print(f'   Active Player: {data.get(\"activePlayer\", \"None\")}')
mpd = [p for p in data.get('players', []) if p.get('name') == 'mpd']
if mpd:
    print(f'   MPD State: {mpd[0].get(\"state\")}')
    print(f'   MPD is activePlayer: {mpd[0].get(\"name\") == data.get(\"activePlayer\")}')
"
echo ""

echo "=========================================="
echo "Summary"
echo "=========================================="
echo "If UI still doesn't show MPD as playing or allow stopping:"
echo "1. Check if is_active() returns True (should be fixed)"
echo "2. Check if activePlayer is set (should be working)"
echo "3. UI might need to be refreshed/reloaded"
echo "4. Check browser console for errors"
echo ""

