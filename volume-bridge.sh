#!/bin/bash

# Tidal Connect Bridge: Syncs volume and exports metadata for AudioControl2
# This enables phone volume control and HifiBerry UI metadata display

ALSA_MIXER="Digital"  # HifiBerry DAC+ uses the Digital mixer
STATUS_FILE="/tmp/tidal-status.json"
PREV_VOLUME=-1
PREV_HASH=""

echo "Starting Tidal Connect bridge..."
echo "Monitoring speaker controller and syncing to ALSA mixer: $ALSA_MIXER"
echo "Exporting metadata to: $STATUS_FILE"

# Function to check if container is ready
# Support both container names (legacy and GioF71)
is_container_ready() {
    if docker ps | grep -q "tidal-connect"; then
        docker exec tidal-connect pgrep -f "speaker_controller_application" >/dev/null 2>&1
    elif docker ps | grep -q "tidal_connect"; then
        docker exec tidal_connect pgrep -f "speaker_controller_application" >/dev/null 2>&1
    else
        return 1
    fi
}

# Function to wait for container with retry logic
wait_for_container() {
    local max_attempts=60  # 60 * 2s = 2 minutes
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if is_container_ready; then
            echo "Container is ready (attempt $((attempt + 1)))"
            return 0
        fi
        
        if [ $((attempt % 10)) -eq 0 ] && [ $attempt -gt 0 ]; then
            echo "Waiting for container... ($attempt attempts)"
        fi
        
        sleep 2
        attempt=$((attempt + 1))
    done
    
    echo "ERROR: Container did not become ready after $max_attempts attempts"
    return 1
}

# Wait for initial container startup
if ! wait_for_container; then
    echo "Exiting: Container not available"
    exit 1
fi

CONSECUTIVE_ERRORS=0
MAX_CONSECUTIVE_ERRORS=5

while true; do
    # Check if container is still available
    if ! is_container_ready; then
        echo "[$(date '+%H:%M:%S')] Container not available, waiting for restart..."
        CONSECUTIVE_ERRORS=$((CONSECUTIVE_ERRORS + 1))
        
        if [ $CONSECUTIVE_ERRORS -ge $MAX_CONSECUTIVE_ERRORS ]; then
            echo "Waiting for container to become available..."
            if wait_for_container; then
                echo "Container recovered, resuming monitoring"
                CONSECUTIVE_ERRORS=0
            else
                echo "Container did not recover, retrying..."
                sleep 10
            fi
        else
            sleep 2
        fi
        continue
    fi
    
    # Reset error counter on successful connection
    if [ $CONSECUTIVE_ERRORS -gt 0 ]; then
        echo "[$(date '+%H:%M:%S')] Container connection restored"
        CONSECUTIVE_ERRORS=0
    fi
    
    # Determine container name
    if docker ps | grep -q "tidal-connect"; then
        CONTAINER_NAME="tidal-connect"
    elif docker ps | grep -q "tidal_connect"; then
        CONTAINER_NAME="tidal_connect"
    else
        sleep 0.5
        continue
    fi
    
    # Capture tmux output from speaker_controller_application
    TMUX_OUTPUT=$(docker exec -t "$CONTAINER_NAME" /usr/bin/tmux capture-pane -pS -50 2>/dev/null | tr -d '\r')
    
    if [ -z "$TMUX_OUTPUT" ]; then
        # Container might be restarting - remove status file if it exists
        if [ -f "$STATUS_FILE" ]; then
            rm -f "$STATUS_FILE"
        fi
        sleep 0.5
        continue
    fi
    
    # Check if container is in a valid state (not just starting up)
    # If we can't parse a valid state, skip this cycle
    STATE_CHECK=$(echo "$TMUX_OUTPUT" | grep -o 'PlaybackState::[A-Z]*' | cut -d: -f3)
    if [ -z "$STATE_CHECK" ] && [ -f "$STATUS_FILE" ]; then
        # Container might be restarting - remove stale status file
        rm -f "$STATUS_FILE"
        sleep 0.5
        continue
    fi
    
    # Parse playback state (PLAYING, PAUSED, IDLE, BUFFERING)
    STATE=$(echo "$TMUX_OUTPUT" | grep -o 'PlaybackState::[A-Z]*' | cut -d: -f3)
    [ -z "$STATE" ] && STATE="IDLE"
    
    # Parse metadata fields
    # Extract value up to first "xx" separator or end of line, then trim trailing spaces and 'x' characters
    ARTIST=$(echo "$TMUX_OUTPUT" | grep '^xartists:' | sed 's/^xartists: //' | sed 's/xx.*$//' | sed 's/ *x*$//' | sed 's/[[:space:]]*$//')
    ALBUM=$(echo "$TMUX_OUTPUT" | grep '^xalbum name:' | sed 's/^xalbum name: //' | sed 's/xx.*$//' | sed 's/ *x*$//' | sed 's/[[:space:]]*$//')
    TITLE=$(echo "$TMUX_OUTPUT" | grep '^xtitle:' | sed 's/^xtitle: //' | sed 's/xx.*$//' | sed 's/ *x*$//' | sed 's/[[:space:]]*$//')
    DURATION=$(echo "$TMUX_OUTPUT" | grep '^xduration:' | sed 's/^xduration: //' | sed 's/xx.*$//' | sed 's/[[:space:]]*$//')
    SHUFFLE=$(echo "$TMUX_OUTPUT" | grep '^xshuffle:' | sed 's/^xshuffle: //' | sed 's/xx.*$//' | sed 's/[[:space:]]*$//')
    
    # Parse position (e.g., "38 / 227")
    POSITION_LINE=$(echo "$TMUX_OUTPUT" | grep -E '^ *[0-9]+ */ *[0-9]+$' | tr -d ' ')
    POSITION=$(echo "$POSITION_LINE" | cut -d'/' -f1)
    [ -z "$POSITION" ] && POSITION=0
    
    # Parse volume from volume bar (count # symbols)
    VOLUME=$(echo "$TMUX_OUTPUT" | grep 'l.*#.*k$' | tr -cd '#' | wc -c)
    
    # Convert duration from milliseconds to seconds if present
    if [ -n "$DURATION" ] && [ "$DURATION" -gt 0 ]; then
        DURATION_SEC=$((DURATION / 1000))
    else
        DURATION_SEC=0
    fi
    
    # Create status hash to detect changes
    STATUS_HASH="${STATE}|${ARTIST}|${TITLE}|${ALBUM}|${POSITION}|${VOLUME}"
    
    # Check if MPD wants to play - if so, stop Tidal and remove status file
    # This prevents Tidal from interfering with radio/MPD playback
    if systemctl is-active --quiet mpd 2>/dev/null; then
        MPD_STATUS=$(mpc status 2>/dev/null || echo "")
        MPD_STATE=$(echo "$MPD_STATUS" | head -1 | grep -oE '\[playing\]|\[paused\]' || echo "")
        MPD_HAS_TRACK=$(echo "$MPD_STATUS" | grep -v "^volume:" | grep -v "^ERROR:" | head -1 | grep -q "http://\|file://" && echo "yes" || echo "no")
        MPD_ERROR=$(echo "$MPD_STATUS" | grep -q "Device or resource busy" && echo "yes" || echo "no")
        
        # If MPD is playing OR has a track queued (even if paused) and Tidal is PAUSED, restart Tidal
        # This releases the ALSA device so MPD can play
        if [ "$MPD_STATE" = "[playing]" ] || ([ "$MPD_HAS_TRACK" = "yes" ] && [ "$MPD_ERROR" = "yes" ]); then
            if [ "$STATE" = "PAUSED" ]; then
                echo "[$(date '+%H:%M:%S')] MPD wants to play but Tidal is PAUSED (holding ALSA device)"
                # Remove status file immediately to prevent stale metadata
                if [ -f "$STATUS_FILE" ]; then
                    rm -f "$STATUS_FILE"
                    echo "[$(date '+%H:%M:%S')] Removed Tidal status file before restart"
                fi
                echo "[$(date '+%H:%M:%S')] Restarting Tidal container to release ALSA device..."
                systemctl restart tidal-gio.service
                sleep 3  # Wait for container to restart
                echo "[$(date '+%H:%M:%S')] Tidal container restarted, ALSA device should be free"
                PREV_HASH=""  # Force update on next cycle
                # Skip metadata export for this cycle - container is restarting
                continue  # Skip to next iteration
            elif [ "$STATE" != "IDLE" ] && [ "$STATE" != "STOPPED" ]; then
                # Tidal is PLAYING or BUFFERING - try to stop it first
                echo "[$(date '+%H:%M:%S')] MPD wants to play, stopping Tidal..."
                docker exec "$CONTAINER_NAME" /usr/bin/tmux send-keys -t speaker_controller_application 'P' 2>/dev/null || true
                sleep 0.5
                docker exec "$CONTAINER_NAME" /usr/bin/tmux send-keys -t speaker_controller_application 'P' 2>/dev/null || true
            fi
            # Always remove status file when MPD wants to play
            if [ -f "$STATUS_FILE" ]; then
                rm -f "$STATUS_FILE"
                echo "[$(date '+%H:%M:%S')] MPD wants to play, removed Tidal status file"
                PREV_HASH=""  # Force update on next cycle
            fi
        fi
    fi
    
    # Update ALSA volume if changed
    if [ "$VOLUME" != "$PREV_VOLUME" ] && [ -n "$VOLUME" ] && [ "$VOLUME" -ge 0 ]; then
        # Map volume: speaker controller shows 0-38 # symbols
        # Map to ALSA Digital mixer range 0-207
        ALSA_VALUE=$((VOLUME * 207 / 38))
        
        # Clamp to valid range
        if [ "$ALSA_VALUE" -gt 207 ]; then
            ALSA_VALUE=207
        fi
        
        echo "[$(date '+%H:%M:%S')] Volume changed: $VOLUME/38 -> Setting ALSA $ALSA_MIXER to $ALSA_VALUE/207"
        docker exec "$CONTAINER_NAME" amixer set "$ALSA_MIXER" "$ALSA_VALUE" > /dev/null 2>&1
        
        PREV_VOLUME=$VOLUME
    fi
    
    # Export metadata to JSON file if anything changed
    # Only write file when Tidal is actually playing (not IDLE/PAUSED/STOPPED)
    # PAUSED still holds the ALSA device, preventing MPD/radio from playing
    # This prevents AudioControl2 from thinking Tidal is active when it's idle or paused
    if [ "$STATUS_HASH" != "$PREV_HASH" ]; then
        if [ "$STATE" = "IDLE" ] || [ "$STATE" = "STOPPED" ] || [ "$STATE" = "PAUSED" ]; then
            # Remove status file when Tidal is idle/paused - prevents plugin from thinking it's active
            if [ -f "$STATUS_FILE" ]; then
                rm -f "$STATUS_FILE"
                echo "[$(date '+%H:%M:%S')] Tidal $STATE, removed status file"
            fi
        else
            # Get current timestamp
            TIMESTAMP=$(date +%s)
            
            # Escape quotes in strings for JSON
            ARTIST_JSON=$(echo "$ARTIST" | sed 's/"/\\"/g')
            TITLE_JSON=$(echo "$TITLE" | sed 's/"/\\"/g')
            ALBUM_JSON=$(echo "$ALBUM" | sed 's/"/\\"/g')
            
            # Write JSON status file (atomic write via temp file)
            cat > "${STATUS_FILE}.tmp" <<EOF
{
  "state": "$STATE",
  "artist": "$ARTIST_JSON",
  "title": "$TITLE_JSON",
  "album": "$ALBUM_JSON",
  "duration": $DURATION_SEC,
  "position": $POSITION,
  "volume": $VOLUME,
  "shuffle": "$SHUFFLE",
  "timestamp": $TIMESTAMP
}
EOF
            mv "${STATUS_FILE}.tmp" "$STATUS_FILE"
            
            echo "[$(date '+%H:%M:%S')] Updated metadata: $STATE - $ARTIST - $TITLE"
        fi
        
        PREV_HASH=$STATUS_HASH
    fi
    
    sleep 0.5  # Check twice per second
done

