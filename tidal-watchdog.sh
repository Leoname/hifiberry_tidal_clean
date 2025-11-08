#!/bin/bash

# Tidal Connect Watchdog: Monitors for connection issues and auto-recovers
# This script detects token expiration and connection errors, then restarts the service

LOG_FILE="/var/log/tidal-watchdog.log"
CHECK_INTERVAL=30  # Check every 30 seconds
RESTART_COOLDOWN=60  # Don't restart more than once per minute
LAST_RESTART=0

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

get_container_status() {
    docker inspect -f '{{.State.Running}}' tidal_connect 2>/dev/null
}

check_for_errors() {
    # Get logs from the last CHECK_INTERVAL seconds
    RECENT_LOGS=$(docker logs --since ${CHECK_INTERVAL}s tidal_connect 2>&1)
    
    # Check for critical errors
    # Token expiration - these are clear errors that require restart
    if echo "$RECENT_LOGS" | grep -qiE "(invalid_grant|token has expired|authentication.*failed)"; then
        echo "token_expired"
        return
    fi
    
    # Connection loss - only trigger on actual errors, not normal EOF
    # "End of file" (EOF) is normal during connection teardown, so we ignore those
    if echo "$RECENT_LOGS" | grep -qiE "handle_read_frame error|connection.*refused|connection.*reset|socket.*disconnected" && \
       ! echo "$RECENT_LOGS" | grep -qiE "asio\.misc:2.*End of file|normal.*shutdown"; then
        echo "connection_lost"
        return
    fi
    
    # Check if container is running but not responsive
    if [ "$(get_container_status)" != "true" ]; then
        echo "container_down"
        return
    fi
    
    echo "ok"
}

restart_service() {
    local reason="$1"
    local current_time=$(date +%s)
    
    # Enforce cooldown to prevent restart loops
    if [ $((current_time - LAST_RESTART)) -lt $RESTART_COOLDOWN ]; then
        log "⏳ Restart requested but cooldown active (${RESTART_COOLDOWN}s)"
        return 1
    fi
    
    log "🔄 Restarting Tidal Connect service (Reason: $reason)"
    
    # If service is stuck in stopping state, force stop it first
    if systemctl is-active --quiet tidal.service || systemctl is-failed tidal.service; then
        # Service is active or failed, try normal restart
        systemctl restart tidal.service
    else
        # Service might be stuck, force stop then start
        log "⚠ Service appears stuck, forcing stop..."
        systemctl stop tidal.service --no-block 2>/dev/null || true
        sleep 5
        # Kill any stuck docker-compose processes
        pkill -f "docker-compose.*tidal" 2>/dev/null || true
        sleep 2
        systemctl start tidal.service
    fi
    
    # Wait for service to fully start (longer timeout for stuck services)
    local max_wait=30
    local waited=0
    while [ $waited -lt $max_wait ]; do
        if [ "$(get_container_status)" = "true" ]; then
            break
        fi
        sleep 2
        waited=$((waited + 2))
    done
    
    if [ "$(get_container_status)" = "true" ]; then
        log "✓ Service restarted successfully (waited ${waited}s)"
        LAST_RESTART=$current_time
        
        # Also restart volume bridge to ensure it reconnects
        sleep 2
        systemctl restart tidal-volume-bridge.service 2>/dev/null || true
        
        return 0
    else
        log "✗ Service restart failed after ${waited}s - container not running"
        return 1
    fi
}

# Main monitoring loop
log "=========================================="
log "Tidal Connect Watchdog started"
log "Check interval: ${CHECK_INTERVAL}s"
log "Restart cooldown: ${RESTART_COOLDOWN}s"
log "=========================================="

while true; do
    # Check if container exists
    if ! docker ps -a | grep -q tidal_connect; then
        log "⚠ Tidal Connect container not found, waiting..."
        sleep $CHECK_INTERVAL
        continue
    fi
    
    # Check for errors
    STATUS=$(check_for_errors)
    
    case "$STATUS" in
        token_expired)
            log "⚠ Detected: Token expired"
            restart_service "token_expired"
            ;;
        connection_lost)
            log "⚠ Detected: Connection lost"
            restart_service "connection_lost"
            ;;
        container_down)
            log "⚠ Detected: Container down"
            restart_service "container_down"
            ;;
        ok)
            # Silently continue
            ;;
    esac
    
    sleep $CHECK_INTERVAL
done

