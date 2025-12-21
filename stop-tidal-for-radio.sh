#!/bin/bash
# Stop Tidal playback to release ALSA device for radio/MPD

echo "Stopping Tidal to release ALSA device..."

# Detect container
if docker ps | grep -q "tidal-connect"; then
    CONTAINER="tidal-connect"
elif docker ps | grep -q "tidal_connect"; then
    CONTAINER="tidal_connect"
else
    echo "No Tidal container found"
    exit 1
fi

# Send multiple stop/pause commands to try to release
echo "Sending stop commands..."
for i in {1..5}; do
    docker exec "$CONTAINER" /usr/bin/tmux send-keys -t speaker_controller_application 'P' 2>/dev/null || true
    sleep 0.3
done

# Wait a moment for state to change
sleep 1

# Check if Tidal is still not IDLE - if so, we may need to restart container
CURRENT_STATE=$(docker exec "$CONTAINER" /usr/bin/tmux capture-pane -pS -10 2>/dev/null | grep -o 'PlaybackState::[A-Z]*' | cut -d: -f3 | tail -1)
if [ "$CURRENT_STATE" != "IDLE" ] && [ "$CURRENT_STATE" != "STOPPED" ]; then
    echo "Warning: Tidal is still $CURRENT_STATE (not IDLE)"
    echo "You may need to stop Tidal from your phone app or restart the container"
fi

# Remove status file
rm -f /tmp/tidal-status.json

# Restart AudioControl2
systemctl restart audiocontrol2

echo "Done. Try playing radio now."
echo ""
echo "If it still doesn't work, you may need to:"
echo "1. Stop Tidal playback from your phone app"
echo "2. Or restart the Tidal container: systemctl restart tidal-gio.service"

