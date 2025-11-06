#!/bin/bash

# Volume Bridge: Syncs speaker_controller volume to ALSA mixer
# This enables phone volume control to actually work on HifiBerry

ALSA_MIXER="Digital"  # HifiBerry DAC+ uses the Digital mixer
PREV_VOLUME=-1

echo "Starting volume bridge..."
echo "Monitoring speaker controller and syncing to ALSA mixer: $ALSA_MIXER"

while true; do
    # Scrape volume from speaker controller (count # symbols in the volume bar)
    # Volume bar looks like: l##########################k (with carriage return)
    VOLUME=$(docker exec -t tidal_connect /usr/bin/tmux capture-pane -pS -10 2>/dev/null | \
             tr -d '\r' | grep 'l.*#.*k$' | tr -cd '#' | wc -c)
    
    # Only update if volume changed
    if [ "$VOLUME" != "$PREV_VOLUME" ] && [ -n "$VOLUME" ] && [ "$VOLUME" -ge 0 ]; then
        # Map volume: speaker controller shows 0-38 # symbols
        # Map to ALSA Digital mixer range 0-207
        ALSA_VALUE=$((VOLUME * 207 / 38))
        
        # Clamp to valid range
        if [ "$ALSA_VALUE" -gt 207 ]; then
            ALSA_VALUE=207
        fi
        
        echo "[$(date '+%H:%M:%S')] Volume changed: $VOLUME/38 -> Setting ALSA $ALSA_MIXER to $ALSA_VALUE/207"
        
        # Set ALSA mixer volume
        docker exec tidal_connect amixer set "$ALSA_MIXER" "$ALSA_VALUE" > /dev/null 2>&1
        
        PREV_VOLUME=$VOLUME
    fi
    
    sleep 0.5  # Check twice per second
done

