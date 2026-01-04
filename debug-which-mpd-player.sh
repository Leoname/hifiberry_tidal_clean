#!/bin/bash
# Debug which MPD player AudioControl2 is actually using

echo "=========================================="
echo "Debugging Which MPD Player AudioControl2 Uses"
echo "=========================================="
echo ""

echo "1. All MPD players in AudioControl2 API:"
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
"
echo ""

echo "2. Testing MPDControl directly:"
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

echo "3. Checking AudioControl2 controller to see player registration:"
if [ -f "/opt/audiocontrol2/audiocontrol2.py" ]; then
    echo "   MPDControl registration:"
    grep -B 3 -A 5 "register_nonmpris_player.*mpd" /opt/audiocontrol2/audiocontrol2.py | head -10
    echo ""
    echo "   MPRIS registration:"
    grep -B 3 -A 5 "mpris\." /opt/audiocontrol2/audiocontrol2.py | grep -i mpd | head -5
fi
echo ""

echo "4. Checking if MPRIS is providing MPD player:"
python3 << 'PYTHON_MPRIS'
import dbus
try:
    bus = dbus.SystemBus()
    # List all MPRIS players
    player_names = []
    for name in bus.list_names():
        if 'mpris' in name.lower() and 'mpd' in name.lower():
            player_names.append(name)
    
    if player_names:
        print(f"   Found MPRIS MPD players: {player_names}")
    else:
        print("   No MPRIS MPD players found")
except Exception as e:
    print(f"   Error checking MPRIS: {e}")
PYTHON_MPRIS
echo ""

echo "5. The issue:"
echo "   - MPDControl returns correct metadata when called directly"
echo "   - But AudioControl2 API shows null metadata"
echo "   - This suggests AudioControl2 is using MPRIS for MPD, not MPDControl"
echo ""
echo "   Solution: We need to ensure AudioControl2 uses MPDControl for MPD"
echo "   instead of MPRIS, or ensure MPDControl takes priority."
echo ""

