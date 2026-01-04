#!/bin/bash
# Check current state of MPD and AudioControl2 after webserver fix

echo "=========================================="
echo "Current System State Check"
echo "=========================================="
echo ""

echo "1. MPD Actual State:"
mpc status 2>/dev/null | head -3
echo ""

echo "2. AudioControl2 API - All Players:"
curl -s http://localhost:81/api/player/status | python3 -c "
import sys, json
data = json.load(sys.stdin)
players = data.get('players', [])
print(f'Total players: {len(players)}')
for p in players:
    name = p.get('name', 'unknown')
    state = p.get('state', 'unknown')
    artist = p.get('artist') or 'null'
    title = p.get('title') or 'null'
    cmds = len(p.get('supported_commands', []))
    print(f'  - {name}: state={state}, artist={artist}, title={title}, commands={cmds}')
"
echo ""

echo "3. AudioControl2 API - MPD Players Only:"
curl -s http://localhost:81/api/player/status | python3 -c "
import sys, json
data = json.load(sys.stdin)
mpd_players = [p for p in data.get('players', []) if p.get('name') == 'mpd']
print(f'Found {len(mpd_players)} MPD player(s):')
for i, p in enumerate(mpd_players, 1):
    print(f'  Player {i}:')
    print(f'    State: {p.get(\"state\")}')
    print(f'    Artist: {p.get(\"artist\")}')
    print(f'    Title: {p.get(\"title\")}')
    print(f'    Supported commands: {len(p.get(\"supported_commands\", []))} commands')
    print(f'    Commands: {p.get(\"supported_commands\", [])}')
"
echo ""

echo "4. Checking webserver.py playerstatus_handler (first 30 lines):"
grep -A 30 "def playerstatus_handler" /opt/audiocontrol2/ac2/webserver.py | head -35
echo ""

echo "5. AudioControl2 Service Status:"
if systemctl is-active --quiet audiocontrol2; then
    echo "✓ AudioControl2 is running"
    echo "  Last restart: $(systemctl show audiocontrol2 -p ActiveEnterTimestamp --value)"
else
    echo "✗ AudioControl2 is not running"
fi
echo ""

echo "6. Testing MPDControl directly (if accessible):"
python3 << 'PYTHON_TEST'
import sys
sys.path.insert(0, '/opt/audiocontrol2')
try:
    from ac2.players.mpdcontrol import MPDControl
    mpd = MPDControl()
    if mpd.is_active():
        state = mpd.get_state()
        meta = mpd.get_meta()
        print(f"  MPDControl is_active(): True")
        print(f"  get_state(): {state}")
        if meta:
            print(f"  get_meta(): artist={meta.artist}, title={meta.title}")
        else:
            print(f"  get_meta(): None")
    else:
        print(f"  MPDControl is_active(): False")
except Exception as e:
    print(f"  Error: {e}")
PYTHON_TEST
echo ""

echo "=========================================="
echo "Summary"
echo "=========================================="
echo "If MPD shows 'unknown' state in API but is actually playing:"
echo "1. The webserver filter is working (only one MPD player shown)"
echo "2. But MPDControl.get_state() may be returning 'unknown'"
echo "3. Check MPDControl connection and state detection"
echo ""

