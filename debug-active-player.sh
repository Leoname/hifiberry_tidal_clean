#!/bin/bash
# Debug why UI doesn't show MPD as playing/active even though state is "playing"

echo "=========================================="
echo "Debugging Active Player Selection"
echo "=========================================="
echo ""

echo "1. MPD Actual State:"
mpc status 2>/dev/null | head -3
echo ""

echo "2. AudioControl2 API - Full Response:"
curl -s http://localhost:81/api/player/status | python3 -c "
import sys, json
data = json.load(sys.stdin)
print(f'Active Player: {data.get(\"activePlayer\", \"None\")}')
print(f'Total players: {len(data.get(\"players\", []))}')
print('')
print('All players:')
for p in data.get('players', []):
    name = p.get('name', 'unknown')
    state = p.get('state', 'unknown')
    is_active = ' (ACTIVE)' if name == data.get('activePlayer') else ''
    print(f'  - {name}: state={state}{is_active}')
"
echo ""

echo "3. Checking controller.py for active player logic:"
if [ -f "/opt/audiocontrol2/ac2/controller.py" ]; then
    echo "  Looking for activePlayer assignment..."
    grep -B 5 -A 10 "activePlayer\|active_player" /opt/audiocontrol2/ac2/controller.py | head -30
    echo ""
    echo "  Looking for is_active() usage..."
    grep -B 3 -A 8 "is_active()" /opt/audiocontrol2/ac2/controller.py | head -20
fi
echo ""

echo "4. Testing MPDControl.is_active() directly:"
python3 << 'PYTHON_TEST'
import sys
sys.path.insert(0, '/opt/audiocontrol2')
try:
    from ac2.players.mpdcontrol import MPDControl
    
    mpd = MPDControl()
    mpd.start()
    
    print(f"  MPDControl.is_active(): {mpd.is_active()}")
    print(f"  MPDControl.get_state(): {mpd.get_state()}")
except Exception as e:
    print(f"  Error: {e}")
    import traceback
    traceback.print_exc()
PYTHON_TEST
echo ""

echo "5. Checking how activePlayer is determined in webserver:"
if [ -f "/opt/audiocontrol2/ac2/webserver.py" ]; then
    echo "  Looking for activePlayer in playerstatus_handler..."
    grep -B 10 -A 20 "activePlayer" /opt/audiocontrol2/ac2/webserver.py | head -40
fi
echo ""

echo "=========================================="
echo "Summary"
echo "=========================================="
echo "If state is 'playing' but UI doesn't show it:"
echo "1. Check if activePlayer is set to 'mpd'"
echo "2. Check if is_active() returns True for MPDControl"
echo "3. Check if UI checks for different state format"
echo ""

