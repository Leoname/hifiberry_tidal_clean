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
for i in {1..3}; do
    docker exec "$CONTAINER" /usr/bin/tmux send-keys -t speaker_controller_application 'P' 2>/dev/null || true
    sleep 0.5
done

# Remove status file
rm -f /tmp/tidal-status.json

# Restart AudioControl2
systemctl restart audiocontrol2

echo "Done. Try playing radio now."
echo ""
echo "If it still doesn't work, you may need to:"
echo "1. Stop Tidal playback from your phone app"
echo "2. Or restart the Tidal container: systemctl restart tidal-gio.service"

