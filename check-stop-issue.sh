#!/bin/bash
# Check why stop command doesn't work - playback resumes immediately

echo "=========================================="
echo "Checking Stop Command Issue"
echo "=========================================="
echo ""

# 1. Check MPD status and queue
echo "1. MPD Status and Queue:"
mpc status 2>/dev/null || echo "MPD not running"
echo ""
echo "Queue:"
mpc playlist 2>/dev/null | head -5 || echo "No queue"
echo ""

# 2. Test stop directly
echo "2. Testing stop command directly:"
echo "Current state:"
mpc status 2>/dev/null | head -1
echo "Sending stop..."
mpc stop >/dev/null 2>&1
sleep 1
echo "State after stop:"
mpc status 2>/dev/null | head -1
echo "Waiting 3 seconds..."
sleep 3
echo "State after 3 seconds:"
mpc status 2>/dev/null | head -1
echo ""

# 3. Check if MPD has auto-play enabled
echo "3. Checking MPD Configuration for Auto-Play:"
if [ -f "/etc/mpd.conf" ]; then
    echo "Checking for auto-play, restore, or state_file settings:"
    grep -i "auto\|restore\|state_file\|save_state" /etc/mpd.conf | head -10 || echo "No auto-play settings found"
else
    echo "MPD config not found at /etc/mpd.conf"
fi
echo ""

# 4. Check AudioControl2 logs for stop command
echo "4. Recent AudioControl2 Logs (stop command):"
journalctl -u audiocontrol2 -n 100 --no-pager 2>/dev/null | grep -i "stop\|Stop" | tail -15 || echo "No stop-related logs"
echo ""

# 5. Check what command AudioControl2 sends for stop
echo "5. Testing stop via AudioControl2 API:"
echo "Sending stop command..."
RESPONSE=$(curl -s -X POST http://127.0.0.1:81/api/player/stop 2>/dev/null)
echo "Response: $RESPONSE"
sleep 1
echo "MPD state after API stop:"
mpc status 2>/dev/null | head -1
echo ""

# 6. Check if there's a playlist that auto-resumes
echo "6. Checking MPD Playlist:"
PLAYLIST_COUNT=$(mpc playlist 2>/dev/null | wc -l)
echo "Playlist items: $PLAYLIST_COUNT"
if [ "$PLAYLIST_COUNT" -gt 0 ]; then
    echo "Playlist exists - clearing it..."
    mpc clear >/dev/null 2>&1
    sleep 1
    echo "State after clear:"
    mpc status 2>/dev/null | head -1
    echo "Sending stop again..."
    mpc stop >/dev/null 2>&1
    sleep 2
    echo "State after stop (with empty playlist):"
    mpc status 2>/dev/null | head -1
fi
echo ""

# 7. Check AudioControl2 controller for auto-resume logic
echo "7. Checking AudioControl2 for Auto-Resume Logic:"
if [ -f "/opt/audiocontrol2/ac2/controller.py" ]; then
    grep -n "auto.*play\|auto.*resume\|auto.*start" /opt/audiocontrol2/ac2/controller.py | head -10 || echo "No auto-resume logic found"
fi
echo ""

# 8. Check what happens when we send pause instead of stop
echo "8. Testing pause vs stop:"
echo "Current state:"
mpc status 2>/dev/null | head -1
echo "Sending pause..."
mpc pause >/dev/null 2>&1
sleep 2
echo "State after pause:"
mpc status 2>/dev/null | head -1
echo "Sending stop..."
mpc stop >/dev/null 2>&1
sleep 2
echo "State after stop:"
mpc status 2>/dev/null | head -1
echo ""

echo "=========================================="
echo "Diagnosis:"
echo "=========================================="
echo "If stop works via mpc but not via UI:"
echo "1. AudioControl2 might be sending the wrong command"
echo "2. There might be auto-resume logic"
echo ""
echo "If stop works but playback resumes:"
echo "1. MPD might have auto-play enabled"
echo "2. There might be a playlist that auto-starts"
echo "3. AudioControl2 might have auto-resume logic"
echo ""

