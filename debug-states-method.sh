#!/bin/bash
# Debug why states() method returns wrong data even though MPDControl works directly

echo "=========================================="
echo "Debugging states() Method vs Direct Calls"
echo "=========================================="
echo ""

echo "1. Testing MPDControl directly:"
python3 << 'PYTHON_DIRECT'
import sys
sys.path.insert(0, '/opt/audiocontrol2')
try:
    from ac2.players.mpdcontrol import MPDControl
    
    mpd = MPDControl()
    mpd.start()
    
    print("  Direct MPDControl calls:")
    state = mpd.get_state()
    meta = mpd.get_meta()
    print(f"    get_state(): {state}")
    print(f"    get_meta(): artist={meta.artist if meta and hasattr(meta, 'artist') else 'None'}, title={meta.title if meta and hasattr(meta, 'title') else 'None'}")
    print(f"    is_active(): {mpd.is_active()}")
except Exception as e:
    print(f"  Error: {e}")
    import traceback
    traceback.print_exc()
PYTHON_DIRECT
echo ""

echo "2. Inspecting controller.py states() method:"
if [ -f "/opt/audiocontrol2/ac2/controller.py" ]; then
    echo "  Finding states() method implementation..."
    grep -A 80 "def states(" /opt/audiocontrol2/ac2/controller.py | head -100
else
    echo "  ✗ controller.py not found"
fi
echo ""

echo "3. Testing states() via API (what the webserver returns):"
curl -s http://localhost:81/api/player/status | python3 -c "
import sys, json
data = json.load(sys.stdin)
mpd_players = [p for p in data.get('players', []) if p.get('name') == 'mpd']
print(f'  MPD players from API: {len(mpd_players)}')
for i, p in enumerate(mpd_players, 1):
    print(f'    Player {i}:')
    print(f'      state: {p.get(\"state\")}')
    print(f'      artist: {p.get(\"artist\")}')
    print(f'      title: {p.get(\"title\")}')
    print(f'      commands: {len(p.get(\"supported_commands\", []))}')
"
echo ""

echo "4. Checking controller.py to see how state is serialized:"
if [ -f "/opt/audiocontrol2/ac2/controller.py" ]; then
    echo "  Looking for where player state is converted to string..."
    grep -B 5 -A 15 '"state"' /opt/audiocontrol2/ac2/controller.py | grep -A 15 "get_state\|STATE_" | head -30
    echo ""
    echo "  Looking for where player metadata is extracted..."
    grep -B 5 -A 15 '"artist"\|"title"' /opt/audiocontrol2/ac2/controller.py | head -30
else
    echo "  ✗ controller.py not found"
fi
echo ""

echo "=========================================="
echo "Summary"
echo "=========================================="
echo "This will show:"
echo "1. What MPDControl returns when called directly"
echo "2. What states() method returns"
echo "3. How states() serializes the player data"
echo ""

