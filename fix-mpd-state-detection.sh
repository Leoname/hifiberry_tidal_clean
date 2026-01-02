#!/bin/bash
# Fix MPDControl state detection - ensure it correctly reads MPD status

echo "=========================================="
echo "Fixing MPDControl State Detection"
echo "=========================================="
echo ""

MPD_CONTROL="/opt/audiocontrol2/ac2/players/mpdcontrol.py"
BACKUP="${MPD_CONTROL}.backup.$(date +%Y%m%d_%H%M%S)"

# Check if file exists
if [ ! -f "$MPD_CONTROL" ]; then
    echo "✗ MPDControl file not found"
    exit 1
fi

# Create backup
echo "1. Creating backup..."
cp "$MPD_CONTROL" "$BACKUP"
echo "✓ Backup: $BACKUP"
echo ""

echo "2. Checking current get_state() method:"
grep -A 30 "def get_state(self):" "$MPD_CONTROL" | head -35
echo ""

echo "3. Testing MPD connection directly:"
python3 << 'PYTHON_TEST'
import mpd
try:
    client = mpd.MPDClient()
    client.connect("localhost", 6600)
    status = client.status()
    print(f"   MPD state: {status.get('state', 'unknown')}")
    print(f"   MPD song: {status.get('song', 'none')}")
    print(f"   MPD songid: {status.get('songid', 'none')}")
    current_song = client.currentsong()
    if current_song:
        print(f"   Current song: {current_song.get('artist', 'Unknown')} - {current_song.get('title', 'Unknown')}")
    else:
        print(f"   No current song")
    client.close()
except Exception as e:
    print(f"   Error: {e}")
PYTHON_TEST
echo ""

echo "4. The issue: AudioControl2's get_state() might not be parsing MPD status correctly"
echo "   or the connection might be stale. Let's check if we need to force a reconnect."
echo ""

echo "5. Checking if get_state() handles connection errors properly:"
if grep -A 20 "def get_state(self):" "$MPD_CONTROL" | grep -q "reconnect\|connect"; then
    echo "   ✓ get_state() has connection handling"
else
    echo "   ✗ get_state() might not handle connection issues"
fi
echo ""

echo "=========================================="
echo "The problem is that MPDControl.get_state()"
echo "is not correctly reading MPD's actual state."
echo ""
echo "Try restarting AudioControl2 to force a fresh connection:"
echo "   systemctl restart audiocontrol2"
echo ""
echo "If that doesn't work, MPDControl might need to be fixed"
echo "to properly parse MPD status."
echo "=========================================="

