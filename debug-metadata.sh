#!/bin/bash
# Debug metadata and artwork issues

echo "=========================================="
echo "Debugging Metadata and Artwork Issues"
echo "=========================================="
echo ""

echo "1. Current MPD Status:"
mpc status
echo ""

echo "2. Current MPD Song Details:"
CURRENT_SONG=$(mpc current -f "%artist% - %title% - %album%")
echo "   Song: ${CURRENT_SONG:-none}"
mpc current -f "   Artist: %artist%\n   Title: %title%\n   Album: %album%\n   File: %file%"
echo ""

echo "3. AudioControl2 API - Player States (with metadata):"
curl -s http://127.0.0.1:81/api/player/status 2>/dev/null | python3 -m json.tool 2>/dev/null | grep -A 10 '"name": "mpd"' | head -15
echo ""

echo "4. AudioControl2 API - Current Track Info:"
curl -s http://127.0.0.1:81/api/player/current 2>/dev/null | python3 -m json.tool 2>/dev/null || curl -s http://127.0.0.1:81/api/player/current 2>/dev/null
echo ""

echo "5. MPD Database - Current Song ID and Details:"
python3 << 'PYTHON_CHECK'
import mpd
try:
    client = mpd.MPDClient()
    client.connect("localhost", 6600)
    status = client.status()
    current_song = client.currentsong()
    
    print(f"   State: {status.get('state', 'unknown')}")
    print(f"   Song ID: {status.get('songid', 'none')}")
    print(f"   Song Pos: {status.get('song', 'none')}")
    
    if current_song:
        print(f"   Artist: {current_song.get('artist', 'Unknown')}")
        print(f"   Title: {current_song.get('title', 'Unknown')}")
        print(f"   Album: {current_song.get('album', 'Unknown')}")
        print(f"   Date: {current_song.get('date', 'Unknown')}")
        print(f"   File: {current_song.get('file', 'Unknown')}")
        
        # Check for artwork-related tags
        if 'artwork' in current_song:
            print(f"   Artwork tag: {current_song.get('artwork')}")
        if 'picture' in current_song:
            print(f"   Picture tag: {current_song.get('picture')}")
    else:
        print("   No current song")
    
    client.close()
except Exception as e:
    print(f"   Error: {e}")
PYTHON_CHECK
echo ""

echo "6. Tidal Status File (if exists):"
if [ -f "/tmp/tidal-status.json" ]; then
    echo "   File exists, contents:"
    cat /tmp/tidal-status.json | python3 -m json.tool 2>/dev/null || cat /tmp/tidal-status.json
    echo "   Last modified: $(stat -c %y /tmp/tidal-status.json 2>/dev/null || stat -f '%Sm' /tmp/tidal-status.json 2>/dev/null)"
else
    echo "   File does not exist"
fi
echo ""

echo "7. Volume Bridge Status:"
if systemctl is-active --quiet tidal-volume-bridge 2>/dev/null; then
    echo "   ✓ Service is running"
    journalctl -u tidal-volume-bridge -n 20 --no-pager 2>/dev/null | tail -10
else
    echo "   ✗ Service is not running"
fi
echo ""

echo "8. AudioControl2 Logs - Metadata Updates:"
journalctl -u audiocontrol2 -n 50 --no-pager 2>/dev/null | grep -i "metadata\|artwork\|album\|artist\|title" | tail -15
echo ""

echo "9. MPD Logs - Recent Activity:"
journalctl -u mpd -n 30 --no-pager 2>/dev/null | grep -i "update\|database\|metadata" | tail -10
echo ""

echo "10. Checking for Artwork Files:"
if [ -d "/library/artwork" ]; then
    echo "   Artwork directory exists"
    echo "   Files: $(find /library/artwork -type f 2>/dev/null | wc -l)"
    echo "   Recent files:"
    find /library/artwork -type f -mtime -1 2>/dev/null | head -5
else
    echo "   Artwork directory not found at /library/artwork"
fi
echo ""

echo "11. MPD Config - Artwork Settings:"
if [ -f "/etc/mpd.conf" ]; then
    grep -i "artwork\|music_directory\|playlist_directory" /etc/mpd.conf | head -5
else
    echo "   MPD config not found at /etc/mpd.conf"
fi
echo ""

echo "12. Testing MPD Database Query:"
python3 << 'PYTHON_DB'
import mpd
try:
    client = mpd.MPDClient()
    client.connect("localhost", 6600)
    
    # Try to find current song in database
    current_song = client.currentsong()
    if current_song and 'file' in current_song:
        file_path = current_song['file']
        print(f"   Current file: {file_path}")
        
        # Try to search for this file in database
        results = client.search("file", file_path)
        if results:
            print(f"   Found {len(results)} matches in database")
            if len(results) > 0:
                print(f"   First match artist: {results[0].get('artist', 'Unknown')}")
                print(f"   First match album: {results[0].get('album', 'Unknown')}")
        else:
            print("   File not found in database")
    else:
        print("   No current song to check")
    
    client.close()
except Exception as e:
    print(f"   Error: {e}")
PYTHON_DB
echo ""

echo "=========================================="
echo "Summary:"
echo "=========================================="
echo "If metadata is missing:"
echo "1. Check if MPD database is up to date: mpc update"
echo "2. Check if current song has metadata tags: mpc current -f '%artist% - %title%'"
echo "3. Check AudioControl2 logs for errors"
echo "4. Restart AudioControl2 if needed: systemctl restart audiocontrol2"
echo ""

