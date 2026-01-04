#!/bin/bash
# Debug why metadata parsing isn't working correctly

echo "=========================================="
echo "Debugging Metadata Parsing"
echo "=========================================="
echo ""

echo "1. Current MPD title:"
CURRENT_TITLE=$(mpc current -f "%title%")
echo "   Title: ${CURRENT_TITLE}"
echo ""

echo "2. Testing MPDControl metadata parsing:"
python3 << 'PYTHON_TEST'
import sys
sys.path.insert(0, '/opt/audiocontrol2')
try:
    from ac2.players.mpdcontrol import MPDControl
    
    mpd_control = MPDControl()
    mpd_control.start()
    
    meta = mpd_control.get_meta()
    if meta:
        print(f"   Raw title from MPD: {meta.title if hasattr(meta, 'title') and meta.title else 'N/A'}")
        print(f"   Parsed artist: {meta.artist if hasattr(meta, 'artist') and meta.artist else 'N/A'}")
        print(f"   Parsed title: {meta.title if hasattr(meta, 'title') and meta.title else 'N/A'}")
        
        # Check if parsing logic is present
        import inspect
        source = inspect.getsource(mpd_control.get_meta)
        if '" - "' in source or "split(\" - \"" in source:
            print("   ✓ Parsing logic is present in get_meta()")
        else:
            print("   ✗ Parsing logic NOT found in get_meta()")
except Exception as e:
    print(f"   Error: {e}")
    import traceback
    traceback.print_exc()
PYTHON_TEST
echo ""

echo "3. Checking if metadata parsing code is in mpdcontrol.py:"
if [ -f "/opt/audiocontrol2/ac2/players/mpdcontrol.py" ]; then
    echo "   Looking for parsing logic:"
    grep -A 10 "Parse.*Artist.*Title" /opt/audiocontrol2/ac2/players/mpdcontrol.py | head -15
    echo ""
    echo "   Checking get_meta() method:"
    grep -A 30 "def get_meta(self):" /opt/audiocontrol2/ac2/players/mpdcontrol.py | grep -A 20 "map_attributes" | head -25
fi
echo ""

echo "4. AudioControl2 API - What it's showing:"
curl -s http://127.0.0.1:81/api/player/status 2>/dev/null | python3 -c "
import sys, json
data = json.load(sys.stdin)
players = data.get('players', [])
for i, p in enumerate(players):
    if p.get('name') == 'mpd':
        print(f\"   MPD Player {i+1}:\")
        print(f\"      State: {p.get('state', 'unknown')}\")
        print(f\"      Artist: {p.get('artist', 'null')}\")
        print(f\"      Title: {p.get('title', 'null')}\")
"
echo ""

echo "5. The issue:"
echo "   - MPDControl returns correct metadata when called directly"
echo "   - But AudioControl2 might be showing different data"
echo "   - Or the parsing logic isn't being applied correctly"
echo ""

