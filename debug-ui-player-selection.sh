#!/bin/bash
# Debug which player the UI is actually using and why state isn't showing correctly

echo "=========================================="
echo "Debugging UI Player Selection"
echo "=========================================="
echo ""

echo "1. Actual MPD State:"
mpc status | head -1
echo ""

echo "2. All MPD players in AudioControl2 API:"
curl -s http://127.0.0.1:81/api/player/status 2>/dev/null | python3 -c "
import sys, json
data = json.load(sys.stdin)
players = data.get('players', [])
mpd_players = [p for p in players if p.get('name') == 'mpd']
print(f'   Found {len(mpd_players)} MPD players:')
for i, p in enumerate(mpd_players):
    print(f'   Player {i+1}:')
    print(f'      State: {p.get(\"state\", \"unknown\")}')
    print(f'      Artist: {p.get(\"artist\", \"null\")}')
    print(f'      Title: {p.get(\"title\", \"null\")}')
    print(f'      Supported commands: {len(p.get(\"supported_commands\", []))} commands')
    print()
"
echo ""

echo "3. Active Player:"
curl -s http://127.0.0.1:81/api/player/status 2>/dev/null | python3 -c "
import sys, json
data = json.load(sys.stdin)
active = data.get('activePlayer', 'None')
print(f'   Active Player: {active}')
"
echo ""

echo "4. Testing MPDControl directly:"
python3 << 'PYTHON_TEST'
import sys
sys.path.insert(0, '/opt/audiocontrol2')
try:
    from ac2.players.mpdcontrol import MPDControl
    
    mpd_control = MPDControl()
    mpd_control.start()
    
    state = mpd_control.get_state()
    meta = mpd_control.get_meta()
    
    print(f"   State: {state}")
    print(f"   Artist: {meta.artist if meta and hasattr(meta, 'artist') and meta.artist else 'null'}")
    print(f"   Title: {meta.title if meta and hasattr(meta, 'title') and meta.title else 'null'}")
except Exception as e:
    print(f"   Error: {e}")
    import traceback
    traceback.print_exc()
PYTHON_TEST
echo ""

echo "5. Checking controller priority fix:"
if [ -f "/opt/audiocontrol2/ac2/controller.py" ]; then
    echo "   Priority fix:"
    grep -B 2 -A 5 "For MPD, prefer non-MPRIS" /opt/audiocontrol2/ac2/controller.py | head -8
    echo ""
    echo "   But this might be in the wrong method. Checking all player getters:"
    grep -B 2 -A 10 "def get.*player" /opt/audiocontrol2/ac2/controller.py | head -20
fi
echo ""

echo "6. The issue might be:"
echo "   - The priority fix is in get_state() but UI might use a different method"
echo "   - UI might be selecting the first MPD player (MPRIS) instead of MPDControl"
echo "   - The activePlayer might not be set correctly"
echo ""

