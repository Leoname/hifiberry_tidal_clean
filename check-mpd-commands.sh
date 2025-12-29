#!/bin/bash
# Check what commands MPD player control supports

echo "=========================================="
echo "Checking MPD Command Support"
echo "=========================================="
echo ""

# 1. Check MPDControl player implementation
echo "1. Checking MPDControl Player Implementation:"
if [ -f "/opt/audiocontrol2/ac2/players/mpdcontrol.py" ]; then
    echo "MPDControl file found"
    echo ""
    echo "Supported commands:"
    grep -n "def.*command\|CMD_\|get_supported_commands" /opt/audiocontrol2/ac2/players/mpdcontrol.py | head -20
    echo ""
    echo "send_command method:"
    grep -A 30 "def send_command" /opt/audiocontrol2/ac2/players/mpdcontrol.py | head -40
else
    echo "MPDControl file not found"
fi
echo ""

# 2. Check what commands are defined
echo "2. Checking Command Constants:"
if [ -f "/opt/audiocontrol2/ac2/constants.py" ]; then
    grep -n "CMD_\|STOP\|PAUSE" /opt/audiocontrol2/ac2/constants.py
fi
echo ""

# 3. Test what happens when we send stop via AudioControl2
echo "3. Testing Stop Command via AudioControl2:"
echo "Current MPD state:"
mpc status 2>/dev/null | head -1
echo ""
echo "Sending stop via API..."
curl -s -X POST http://127.0.0.1:81/api/player/stop 2>/dev/null
echo ""
sleep 1
echo "MPD state after API stop:"
mpc status 2>/dev/null | head -1
echo ""

# 4. Check AudioControl2 logs for stop command
echo "4. AudioControl2 Logs for Stop Command:"
journalctl -u audiocontrol2 -n 50 --no-pager 2>/dev/null | grep -i "stop\|Stop\|STOP" | tail -10
echo ""

# 5. Check if stop command is mapped correctly
echo "5. Checking Command Mapping:"
if [ -f "/opt/audiocontrol2/ac2/webserver.py" ]; then
    echo "Checking how /api/player/stop is routed:"
    grep -n "route.*stop\|/api/player/stop" /opt/audiocontrol2/ac2/webserver.py | head -10
    echo ""
    echo "Checking playercontrol_handler:"
    grep -A 5 "def playercontrol_handler" /opt/audiocontrol2/ac2/webserver.py | head -10
fi
echo ""

# 6. Test pause vs stop
echo "6. Testing Pause vs Stop:"
echo "Starting playback..."
mpc play >/dev/null 2>&1
sleep 2
echo "Current state:"
mpc status 2>/dev/null | head -1
echo ""
echo "Sending pause via API..."
curl -s -X POST http://127.0.0.1:81/api/player/pause 2>/dev/null
echo ""
sleep 1
echo "State after pause:"
mpc status 2>/dev/null | head -1
echo ""
echo "Sending stop via API..."
curl -s -X POST http://127.0.0.1:81/api/player/stop 2>/dev/null
echo ""
sleep 1
echo "State after stop:"
mpc status 2>/dev/null | head -1
echo ""

echo "=========================================="
echo "Diagnosis:"
echo "=========================================="
echo "If pause works but stop doesn't:"
echo "1. MPDControl might not support CMD_STOP"
echo "2. The stop command might need to be mapped differently"
echo "3. We might need to use pause + clear instead of stop"
echo ""

