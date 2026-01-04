#!/bin/bash
# Check if both fixes are applied and working

echo "=========================================="
echo "Checking Fix Status"
echo "=========================================="
echo ""

echo "1. Checking if is_active() fix is applied:"
if [ -f "/opt/audiocontrol2/ac2/players/mpdcontrol.py" ]; then
    grep -A 10 "def is_active" /opt/audiocontrol2/ac2/players/mpdcontrol.py | head -15
    if grep -q "get_state()" /opt/audiocontrol2/ac2/players/mpdcontrol.py | grep -A 5 "def is_active"; then
        echo "   ✓ is_active() fix appears to be applied"
    else
        echo "   ✗ is_active() fix may not be applied"
    fi
else
    echo "   ✗ MPDControl file not found"
fi
echo ""

echo "2. Checking if activePlayer fix is applied:"
if [ -f "/opt/audiocontrol2/ac2/controller.py" ]; then
    grep -A 15 "def states(self):" /opt/audiocontrol2/ac2/controller.py | grep -A 5 "activePlayer" | head -10
    if grep -q "activePlayer" /opt/audiocontrol2/ac2/controller.py | grep -A 5 "def states"; then
        echo "   ✓ activePlayer fix appears to be applied"
    else
        echo "   ✗ activePlayer fix may not be applied"
    fi
else
    echo "   ✗ Controller file not found"
fi
echo ""

echo "3. Current API Response:"
curl -s http://localhost:81/api/player/status | python3 -c "
import sys, json
data = json.load(sys.stdin)
print(f'Active Player: {data.get(\"activePlayer\", \"None\")}')
mpd_players = [p for p in data.get('players', []) if p.get('name') == 'mpd']
if mpd_players:
    p = mpd_players[0]
    print(f'MPD State: {p.get(\"state\")}')
    print(f'MPD Artist: {p.get(\"artist\")}')
    print(f'MPD Title: {p.get(\"title\")}')
    print(f'MPD is activePlayer: {p.get(\"name\") == data.get(\"activePlayer\")}')
"
echo ""

echo "4. Testing MPDControl.is_active() directly:"
python3 << 'PYTHON_TEST'
import sys
sys.path.insert(0, '/opt/audiocontrol2')
try:
    from ac2.players.mpdcontrol import MPDControl
    
    mpd = MPDControl()
    mpd.start()
    
    state = mpd.get_state()
    is_active = mpd.is_active()
    
    print(f"  get_state(): {state}")
    print(f"  is_active(): {is_active}")
    print(f"  Should be active: {state in ['playing', 'paused']}")
except Exception as e:
    print(f"  Error: {e}")
    import traceback
    traceback.print_exc()
PYTHON_TEST
echo ""

echo "=========================================="
echo "Summary"
echo "=========================================="
echo "If activePlayer is None or not 'mpd':"
echo "1. Check if is_active() returns True when playing"
echo "2. Check if activePlayer detection logic is working"
echo "3. Restart AudioControl2 if fixes were just applied"
echo ""

