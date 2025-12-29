#!/bin/bash
# Fix AudioControl2 MPD state detection when MPD is playing but AC2 thinks it's stopped

echo "=========================================="
echo "Fixing MPD State Detection in AudioControl2"
echo "=========================================="
echo ""

# 1. Check actual MPD status
echo "1. Actual MPD Status:"
mpc status 2>&1
MPD_PLAYING=$(mpc status 2>/dev/null | head -1 | grep -q "\[playing\]" && echo "yes" || echo "no")
echo "MPD is playing: $MPD_PLAYING"
echo ""

# 2. Check what AudioControl2 thinks
echo "2. AudioControl2 Player Status:"
curl -s http://127.0.0.1:81/api/player/status 2>/dev/null | python3 -c "
import sys, json
d = json.load(sys.stdin)
print('Active Player:', d.get('activePlayer', 'None'))
print('Players:')
for p in d.get('players', []):
    if p['name'] == 'mpd':
        print(f\"  MPD: state={p.get('state')}, artist={p.get('artist')}, title={p.get('title')}\")
" || echo "Could not query API"
echo ""

# 3. Check MPD connection from AudioControl2 perspective
echo "3. Testing MPD Connection:"
python3 << 'PYEOF'
import mpd
try:
    client = mpd.MPDClient()
    client.connect("localhost", 6600)
    status = client.status()
    current = client.currentsong()
    print(f"MPD Connection: OK")
    print(f"State: {status.get('state', 'unknown')}")
    print(f"Current: {current.get('artist', '')} - {current.get('title', '')}")
    client.close()
except Exception as e:
    print(f"MPD Connection Error: {e}")
PYEOF
echo ""

# 4. Force AudioControl2 to refresh MPD state
echo "4. Forcing AudioControl2 to refresh MPD state..."
# Try to trigger a state update by querying the API
curl -s http://127.0.0.1:81/api/player/status > /dev/null
sleep 1

# Restart AudioControl2 to force reconnection
echo "Restarting AudioControl2..."
systemctl restart audiocontrol2
sleep 4
echo "✓ AudioControl2 restarted"
echo ""

# 5. Check state after restart
echo "5. State After Restart:"
sleep 2
curl -s http://127.0.0.1:81/api/player/status 2>/dev/null | python3 -c "
import sys, json
d = json.load(sys.stdin)
print('Active Player:', d.get('activePlayer', 'None'))
for p in d.get('players', []):
    if p['name'] == 'mpd':
        print(f\"MPD State: {p.get('state')}\")
        if p.get('state') == 'playing':
            print('✓ MPD detected as playing!')
        else:
            print('⚠️  MPD still not detected as playing')
" || echo "Could not query API"
echo ""

# 6. If still not working, try restarting MPD
if [ "$MPD_PLAYING" = "yes" ]; then
    echo "6. MPD is actually playing but AudioControl2 may not detect it"
    echo "   Trying to restart MPD to refresh connection..."
    systemctl restart mpd
    sleep 2
    # Resume playback if it was playing
    mpc play 2>/dev/null || true
    sleep 2
    echo "✓ MPD restarted"
    echo ""
    
    echo "7. Final Check:"
    curl -s http://127.0.0.1:81/api/player/status 2>/dev/null | python3 -c "
import sys, json
d = json.load(sys.stdin)
for p in d.get('players', []):
    if p['name'] == 'mpd':
        print(f\"MPD State: {p.get('state')}\")
        print(f\"Active Player: {d.get('activePlayer', 'None')}\")
" || echo "Could not query API"
fi

echo ""
echo "=========================================="
echo "Recommendations:"
echo "=========================================="
echo "If MPD is still not detected as playing:"
echo "1. Check AudioControl2 logs: journalctl -u audiocontrol2 -n 100 | grep -i mpd"
echo "2. Check MPD logs: journalctl -u mpd -n 50"
echo "3. Try manually triggering state update:"
echo "   curl -X POST http://127.0.0.1:81/api/player/command -d '{\"player\":\"mpd\",\"command\":\"status\"}'"
echo "4. Check if MPD socket is accessible:"
echo "   ls -la /run/mpd/socket"

