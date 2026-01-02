#!/bin/bash
# Check and fix duplicate MPD player registrations

echo "=========================================="
echo "Checking for Duplicate MPD Players"
echo "=========================================="
echo ""

echo "1. AudioControl2 API - All MPD players:"
curl -s http://127.0.0.1:81/api/player/status 2>/dev/null | python3 -m json.tool 2>/dev/null | grep -B 2 -A 8 '"name": "mpd"'
echo ""

echo "2. Checking MPRIS players:"
dbus-send --system --print-reply --dest=org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus.ListNames 2>/dev/null | grep -i mpris | grep -i mpd
echo ""

echo "3. AudioControl2 player registration:"
if [ -f "/opt/audiocontrol2/ac2/controller.py" ]; then
    echo "   Checking how players are registered..."
    grep -A 10 "MPDControl\|mpd" /opt/audiocontrol2/ac2/controller.py | head -20
fi
echo ""

echo "4. The issue:"
echo "   - There are two MPD players registered"
echo "   - One shows 'unknown' state (likely MPRIS)"
echo "   - One shows 'playing' state (MPDControl)"
echo ""
echo "   The UI might be using the wrong one."
echo ""
echo "5. Solution:"
echo "   Restart AudioControl2 to refresh player registrations:"
echo "   systemctl restart audiocontrol2"
echo ""
echo "   If that doesn't work, we may need to disable MPRIS MPD player"
echo "   or ensure MPDControl takes priority."
echo ""

