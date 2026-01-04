#!/bin/bash
# Debug if AudioControl2 is caching state/metadata or not calling our methods

echo "=========================================="
echo "Debugging AudioControl2 Cache/State Issues"
echo "=========================================="
echo ""

echo "1. Actual MPD State:"
mpc status | head -1
CURRENT_TITLE=$(mpc current -f "%title%")
echo "   Title: ${CURRENT_TITLE}"
echo ""

echo "2. Testing MPDControl directly (bypassing AudioControl2 cache):"
python3 << 'PYTHON_TEST'
import sys
sys.path.insert(0, '/opt/audiocontrol2')
try:
    from ac2.players.mpdcontrol import MPDControl
    
    mpd_control = MPDControl()
    
    print("   Testing get_state()...")
    state = mpd_control.get_state()
    print(f"   State: {state}")
    
    print("   Testing get_meta()...")
    meta = mpd_control.get_meta()
    if meta:
        print(f"   Artist: {meta.artist if hasattr(meta, 'artist') and meta.artist else 'N/A'}")
        print(f"   Title: {meta.title if hasattr(meta, 'title') and meta.title else 'N/A'}")
    
    # Check tracking variables
    if hasattr(mpd_control, 'last_song_id'):
        print(f"   Last Song ID: {mpd_control.last_song_id}")
    if hasattr(mpd_control, 'last_title'):
        print(f"   Last Title: {mpd_control.last_title}")
    
    # Force a refresh by calling again
    print("   Calling get_meta() again to check if it refreshes...")
    meta2 = mpd_control.get_meta()
    if meta2:
        print(f"   Artist (2nd call): {meta2.artist if hasattr(meta2, 'artist') and meta2.artist else 'N/A'}")
        print(f"   Title (2nd call): {meta2.title if hasattr(meta2, 'title') and meta2.title else 'N/A'}")
    
except Exception as e:
    print(f"   Error: {e}")
    import traceback
    traceback.print_exc()
PYTHON_TEST
echo ""

echo "3. AudioControl2 API - What it's showing:"
curl -s http://127.0.0.1:81/api/player/status 2>/dev/null | python3 -c "
import sys, json
data = json.load(sys.stdin)
players = data.get('players', [])
for p in players:
    if p.get('name') == 'mpd':
        print(f\"   State: {p.get('state', 'unknown')}\")
        print(f\"   Artist: {p.get('artist', 'N/A')}\")
        print(f\"   Title: {p.get('title', 'N/A')}\")
        break
"
echo ""

echo "4. Checking AudioControl2 controller to see how it calls MPDControl:"
if [ -f "/opt/audiocontrol2/ac2/controller.py" ]; then
    echo "   Looking for how players are registered and called..."
    grep -B 5 -A 10 "MPDControl\|mpdcontrol" /opt/audiocontrol2/ac2/controller.py | head -20
fi
echo ""

echo "5. AudioControl2 Logs - Recent get_state/get_meta calls:"
journalctl -u audiocontrol2 -n 100 --no-pager 2>/dev/null | grep -i "get_state\|get_meta\|mpdcontrol" | tail -20
echo ""

echo "6. Checking if there are multiple MPDControl instances:"
python3 << 'PYTHON_INSTANCES'
import sys
sys.path.insert(0, '/opt/audiocontrol2')
try:
    # Try to see how AudioControl2 instantiates players
    import importlib.util
    spec = importlib.util.spec_from_file_location("controller", "/opt/audiocontrol2/ac2/controller.py")
    if spec and spec.loader:
        print("   Can access controller.py")
        # Don't actually import it, just check if we can
except Exception as e:
    print(f"   Note: {e}")
PYTHON_INSTANCES
echo ""

echo "=========================================="
echo "Summary:"
echo "=========================================="
echo "If MPDControl directly returns correct data but AudioControl2 shows wrong data:"
echo "1. AudioControl2 might be caching at a higher level"
echo "2. AudioControl2 might not be calling get_state()/get_meta() frequently"
echo "3. There might be multiple MPDControl instances"
echo "4. AudioControl2 might be using a different player (MPRIS vs MPDControl)"
echo ""

