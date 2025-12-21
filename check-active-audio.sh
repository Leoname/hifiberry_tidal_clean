#!/bin/bash
# Diagnostic script to check what's actively using audio devices

echo "=========================================="
echo "Active Audio Device Check"
echo "=========================================="
echo ""

# 1. Check Tidal status file
echo "1. Tidal Status File:"
if [ -f "/tmp/tidal-status.json" ]; then
    cat /tmp/tidal-status.json | python3 -m json.tool 2>/dev/null || cat /tmp/tidal-status.json
    STATE=$(cat /tmp/tidal-status.json | python3 -c "import sys, json; print(json.load(sys.stdin).get('state', 'UNKNOWN'))" 2>/dev/null || echo "UNKNOWN")
    echo ""
    echo "State: $STATE"
else
    echo "No status file (Tidal is idle)"
fi
echo ""

# 2. Check Tidal container actual state
echo "2. Tidal Container State:"
if docker ps | grep -q "tidal-connect"; then
    CONTAINER="tidal-connect"
elif docker ps | grep -q "tidal_connect"; then
    CONTAINER="tidal_connect"
else
    echo "No Tidal container found"
    CONTAINER=""
fi

if [ -n "$CONTAINER" ]; then
    STATE=$(docker exec "$CONTAINER" /usr/bin/tmux capture-pane -pS -20 2>/dev/null | grep -o 'PlaybackState::[A-Z]*' | cut -d: -f3 | tail -1)
    echo "Container: $CONTAINER"
    echo "Playback State: ${STATE:-UNKNOWN}"
else
    echo "No container running"
fi
echo ""

# 3. Check MPD status
echo "3. MPD Status:"
mpc status 2>/dev/null || echo "MPD not running or mpc not available"
echo ""

# 4. Check what's holding ALSA devices
echo "4. ALSA Device Usage:"
echo "Control devices:"
lsof /dev/snd/controlC* 2>/dev/null | grep -E "tidal|mpd|python|speaker" || echo "No processes found"
echo ""
echo "PCM devices:"
lsof /dev/snd/pcmC* 2>/dev/null | grep -E "tidal|mpd|python|speaker" || echo "No processes found"
echo ""

# 5. Check processes
echo "5. Audio Processes:"
ps aux | grep -E "tidal|mpd|speaker_controller" | grep -v grep || echo "No relevant processes found"
echo ""

# 6. Check if ALSA device is locked
echo "6. ALSA Device Lock Check:"
if [ -f "/dev/snd/pcmC0D0p" ]; then
    echo "Checking PCM device..."
    fuser /dev/snd/pcmC0D0p 2>/dev/null && echo "Device is in use" || echo "Device is free"
else
    echo "PCM device not found at expected path"
fi
echo ""

# 7. Recommendations
echo "=========================================="
echo "Recommendations:"
echo "=========================================="

if [ -n "$CONTAINER" ]; then
    CURRENT_STATE=$(docker exec "$CONTAINER" /usr/bin/tmux capture-pane -pS -10 2>/dev/null | grep -o 'PlaybackState::[A-Z]*' | cut -d: -f3 | tail -1)
    
    if [ "$CURRENT_STATE" = "PAUSED" ]; then
        echo "⚠️  Tidal is PAUSED and likely holding ALSA device"
        echo ""
        echo "Try these solutions (in order):"
        echo "1. Stop Tidal from your phone app (this sends proper stop command)"
        echo "2. Run: ./stop-tidal-for-radio.sh"
        echo "3. Restart Tidal container: systemctl restart tidal-gio.service"
        echo "4. If still stuck, restart container: docker restart $CONTAINER"
    elif [ "$CURRENT_STATE" = "IDLE" ] || [ "$CURRENT_STATE" = "STOPPED" ]; then
        echo "✓ Tidal is IDLE/STOPPED (should not be holding device)"
        if mpc status 2>&1 | grep -q "Device or resource busy"; then
            echo "⚠️  But MPD still can't access device - may need container restart"
        fi
    else
        echo "Tidal state: $CURRENT_STATE"
    fi
else
    echo "No Tidal container found"
fi

