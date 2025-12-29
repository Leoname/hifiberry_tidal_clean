#!/bin/bash
# Debug why stop command doesn't work

echo "=========================================="
echo "Debugging Stop Command Issue"
echo "=========================================="
echo ""

# 1. Check MPD status
echo "1. MPD Status:"
mpc status 2>/dev/null || echo "MPD not running"
echo ""

# 2. Test stop command directly
echo "2. Testing stop command directly via mpc:"
echo "Current state:"
mpc status 2>/dev/null | head -1
echo "Sending stop command..."
mpc stop >/dev/null 2>&1
sleep 1
echo "State after stop:"
mpc status 2>/dev/null | head -1
echo ""

# 3. Check AudioControl2 active player
echo "3. AudioControl2 Active Player:"
AC2_STATUS=$(curl -s http://127.0.0.1:81/api/player/status 2>/dev/null)
AC2_ACTIVE=$(echo "$AC2_STATUS" | python3 -c "import sys, json; print(json.load(sys.stdin).get('activePlayer', 'UNKNOWN'))" 2>/dev/null || echo "UNKNOWN")
echo "Active Player: ${AC2_ACTIVE}"
echo ""

# 4. Check what command is being sent
echo "4. Testing stop via AudioControl2 API:"
echo "Sending stop command via API..."
RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X POST http://127.0.0.1:81/api/player/stop 2>/dev/null)
echo "$RESPONSE"
echo ""

# 5. Check MPD status after API stop
echo "5. MPD Status After API Stop:"
sleep 1
mpc status 2>/dev/null | head -1
echo ""

# 6. Check AudioControl2 logs for stop command
echo "6. Recent AudioControl2 Logs (stop-related):"
journalctl -u audiocontrol2 -n 50 --no-pager 2>/dev/null | grep -i "stop\|Stop\|STOP" | tail -10 || echo "No stop-related logs"
echo ""

# 7. Check if there's auto-play logic
echo "7. Checking for auto-play/auto-resume logic:"
if [ -f "/opt/audiocontrol2/ac2/controller.py" ]; then
    grep -n "auto.*play\|auto.*resume\|auto.*start" /opt/audiocontrol2/ac2/controller.py | head -10 || echo "No auto-play logic found"
fi
echo ""

# 8. Check MPD configuration for auto-play
echo "8. Checking MPD Configuration:"
if [ -f "/etc/mpd.conf" ]; then
    grep -i "auto\|restore\|state" /etc/mpd.conf | head -10 || echo "No auto-play settings found"
fi
echo ""

# 9. Check if stop command is being sent to correct player
echo "9. Testing different stop commands:"
echo "Via mpc stop:"
mpc stop >/dev/null 2>&1
sleep 1
mpc status 2>/dev/null | head -1
echo ""
echo "Via mpc pause:"
mpc pause >/dev/null 2>&1
sleep 1
mpc status 2>/dev/null | head -1
echo ""
echo "Via mpc clear + stop:"
mpc clear >/dev/null 2>&1
mpc stop >/dev/null 2>&1
sleep 1
mpc status 2>/dev/null | head -1
echo ""

echo "=========================================="
echo "Diagnosis:"
echo "=========================================="
echo "If stop works via mpc but not via UI:"
echo "1. Check if AudioControl2 is sending the right command"
echo "2. Check if there's auto-resume logic in AudioControl2"
echo "3. Check if MPD has auto-play enabled"
echo ""

