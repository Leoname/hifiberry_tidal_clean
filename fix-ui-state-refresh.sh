#!/bin/bash
# Force AudioControl2 to refresh MPD state

echo "=========================================="
echo "Forcing AudioControl2 State Refresh"
echo "=========================================="
echo ""

echo "1. Current MPD actual state:"
mpc status | head -1
echo ""

echo "2. Current AudioControl2 API state:"
curl -s http://127.0.0.1:81/api/player/status 2>/dev/null | python3 -m json.tool 2>/dev/null | grep -A 5 "mpd" || echo "   Could not get state"
echo ""

echo "3. Forcing state refresh by restarting AudioControl2:"
systemctl restart audiocontrol2
sleep 3
echo "   ✓ AudioControl2 restarted"
echo ""

echo "4. Checking state after refresh:"
sleep 1
curl -s http://127.0.0.1:81/api/player/status 2>/dev/null | python3 -m json.tool 2>/dev/null | grep -A 5 "mpd" || echo "   Could not get state"
echo ""

echo "5. If still showing playing, try:"
echo "   - Stop MPD: mpc stop"
echo "   - Clear playlist: mpc clear"  
echo "   - Restart AudioControl2: systemctl restart audiocontrol2"
echo ""

