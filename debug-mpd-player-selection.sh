#!/bin/bash
# Debug which MPD player AudioControl2 is using and why metadata is stale

echo "=========================================="
echo "Debugging MPD Player Selection"
echo "=========================================="
echo ""

echo "1. Actual MPD State:"
mpc status | head -1
CURRENT_TITLE=$(mpc current -f "%title%")
CURRENT_ARTIST=$(mpc current -f "%artist%")
echo "   Title: ${CURRENT_TITLE}"
echo "   Artist: ${CURRENT_ARTIST}"
echo ""

echo "2. All MPD Players in AudioControl2 API:"
curl -s http://127.0.0.1:81/api/player/status 2>/dev/null | python3 -m json.tool 2>/dev/null | grep -B 5 -A 15 '"name": "mpd"' | head -40
echo ""

echo "3. Checking MPDControl directly:"
python3 << 'PYTHON_CHECK'
import sys
sys.path.insert(0, '/opt/audiocontrol2')
try:
    from ac2.players.mpdcontrol import MPDControl
    mpd_control = MPDControl()
    
    state = mpd_control.get_state()
    print(f"   State: {state}")
    
    meta = mpd_control.get_meta()
    if meta:
        print(f"   Artist: {meta.artist if hasattr(meta, 'artist') else 'N/A'}")
        print(f"   Title: {meta.title if hasattr(meta, 'title') else 'N/A'}")
        print(f"   Album: {meta.albumTitle if hasattr(meta, 'albumTitle') else 'N/A'}")
    
    # Check if last_song_id is being tracked
    if hasattr(mpd_control, 'last_song_id'):
        print(f"   Last Song ID: {mpd_control.last_song_id}")
    else:
        print("   ⚠ last_song_id not found - metadata refresh fix may not be applied")
        
except Exception as e:
    print(f"   Error: {e}")
    import traceback
    traceback.print_exc()
PYTHON_CHECK
echo ""

echo "4. Checking MPD song ID changes:"
python3 << 'PYTHON_ID'
import mpd
import time

try:
    client = mpd.MPDClient()
    client.connect("localhost", 6600)
    
    # Get current song ID
    status1 = client.status()
    song1 = client.currentsong()
    song_id1 = status1.get('songid', 'none')
    title1 = song1.get('title', 'N/A') if song1 else 'N/A'
    
    print(f"   Current Song ID: {song_id1}")
    print(f"   Current Title: {title1}")
    
    # Wait a moment and check again
    time.sleep(2)
    status2 = client.status()
    song2 = client.currentsong()
    song_id2 = status2.get('songid', 'none')
    title2 = song2.get('title', 'N/A') if song2 else 'N/A'
    
    print(f"   After 2s Song ID: {song_id2}")
    print(f"   After 2s Title: {title2}")
    
    if song_id1 != song_id2:
        print("   ✓ Song ID changed - metadata should refresh")
    else:
        print("   ⚠ Song ID unchanged - may be same song or radio stream")
    
    client.close()
except Exception as e:
    print(f"   Error: {e}")
PYTHON_ID
echo ""

echo "5. AudioControl2 Active Player:"
curl -s http://127.0.0.1:81/api/player/status 2>/dev/null | python3 -c "
import sys, json
data = json.load(sys.stdin)
active = data.get('activePlayer', 'None')
print(f'   Active Player: {active}')
players = data.get('players', [])
for p in players:
    if p.get('name') == 'mpd':
        print(f'   MPD Player State: {p.get(\"state\", \"unknown\")}')
        print(f'   MPD Player Artist: {p.get(\"artist\", \"N/A\")}')
        print(f'   MPD Player Title: {p.get(\"title\", \"N/A\")}')
"
echo ""

echo "6. Checking if metadata parsing fix is applied:"
if grep -q "Parse.*Artist.*Title" /opt/audiocontrol2/ac2/players/mpdcontrol.py 2>/dev/null; then
    echo "   ✓ Metadata parsing fix is present"
    grep -A 5 "Parse.*Artist.*Title" /opt/audiocontrol2/ac2/players/mpdcontrol.py | head -8
else
    echo "   ✗ Metadata parsing fix NOT found"
fi
echo ""

echo "7. Checking if metadata refresh fix is applied:"
if grep -q "last_song_id" /opt/audiocontrol2/ac2/players/mpdcontrol.py 2>/dev/null; then
    echo "   ✓ Metadata refresh fix is present"
    grep -B 2 -A 5 "last_song_id" /opt/audiocontrol2/ac2/players/mpdcontrol.py | head -10
else
    echo "   ✗ Metadata refresh fix NOT found"
fi
echo ""

echo "=========================================="
echo "Summary:"
echo "=========================================="
echo "If metadata is stale:"
echo "1. Check which MPD player is active (MPDControl vs MPRIS)"
echo "2. Verify metadata refresh fix is tracking song ID changes"
echo "3. Verify metadata parsing fix is parsing 'Artist - Title' format"
echo "4. Restart AudioControl2: systemctl restart audiocontrol2"
echo ""

