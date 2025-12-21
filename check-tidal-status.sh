#!/bin/bash

# Diagnostic script to check why Tidal Connect isn't being recognized
# Works with both legacy (tidal_connect) and GioF71 (tidal-connect) setups

echo "=========================================="
echo "Tidal Connect Status Check"
echo "=========================================="
echo ""

# Auto-detect container name (check both running and stopped containers)
# Use exact name matching to avoid false positives
if docker ps -a --format '{{.Names}}' | grep -q "^tidal-connect$"; then
    CONTAINER="tidal-connect"
    SETUP_TYPE="GioF71"
    SERVICE_NAME="tidal-gio.service"
elif docker ps -a --format '{{.Names}}' | grep -q "^tidal_connect$"; then
    CONTAINER="tidal_connect"
    SETUP_TYPE="Legacy"
    SERVICE_NAME="tidal.service"
else
    # Fallback: check if any tidal container exists (less precise but catches edge cases)
    TIDAL_CONTAINER=$(docker ps -a --format '{{.Names}}' | grep -E "tidal[-_]connect" | head -1)
    if [ -n "$TIDAL_CONTAINER" ]; then
        CONTAINER="$TIDAL_CONTAINER"
        if [[ "$CONTAINER" == *"-"* ]]; then
            SETUP_TYPE="GioF71"
            SERVICE_NAME="tidal-gio.service"
        else
            SETUP_TYPE="Legacy"
            SERVICE_NAME="tidal.service"
        fi
    else
        CONTAINER=""
        SETUP_TYPE="Unknown"
        SERVICE_NAME="tidal.service"
    fi
fi

echo "Setup Type: $SETUP_TYPE"
echo "Container: ${CONTAINER:-not found}"
echo ""

# Check if container is running
echo "1. Container Status:"
if [ -n "$CONTAINER" ] && docker ps --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
    echo "   ✓ Container is running"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Image}}" | grep -E "NAMES|${CONTAINER}"
else
    echo "   ✗ Container is NOT running"
    if [ -n "$CONTAINER" ]; then
        echo "   Checking stopped containers..."
        docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Image}}" | grep -E "NAMES|${CONTAINER}" || echo "   No container found with name: $CONTAINER"
    else
        echo "   No Tidal container detected"
    fi
fi
echo ""

# Check service status
echo "2. Service Status:"
# For oneshot services (like tidal-gio), "inactive (dead)" is normal after startup
# The service runs once, starts the container, then exits - container keeps running
SERVICE_STATE=$(systemctl is-active "$SERVICE_NAME" 2>/dev/null || echo "inactive")
if systemctl is-enabled --quiet "$SERVICE_NAME" 2>/dev/null; then
    if [ -n "$CONTAINER" ] && docker ps --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
        if [ "$SERVICE_STATE" = "active" ] || [ "$SERVICE_STATE" = "inactive" ]; then
            echo "   ✓ $SERVICE_NAME is enabled (oneshot service - inactive is normal)"
        else
            echo "   ✓ $SERVICE_NAME is enabled and container is running"
        fi
    else
        echo "   ⚠️  $SERVICE_NAME is enabled but container is not running"
    fi
else
    echo "   ✗ $SERVICE_NAME is not enabled"
fi
systemctl status "$SERVICE_NAME" --no-pager -l 2>/dev/null | head -10
echo ""

# Check Avahi status
echo "3. Avahi Daemon Status:"
if systemctl is-active --quiet avahi-daemon; then
    echo "   ✓ Avahi is running"
else
    echo "   ✗ Avahi is NOT running"
fi
systemctl status avahi-daemon --no-pager -l | head -5
echo ""

# Check for Avahi collisions in logs
echo "4. Avahi/mDNS Status:"
if [ -n "$CONTAINER" ]; then
    COLLISION_CHECK=$(docker logs "$CONTAINER" 2>&1 | grep -i "AVAHI_CLIENT_S_COLLISION\|AVAHI_CLIENT_FAILURE" | tail -5)
    if [ -n "$COLLISION_CHECK" ]; then
        echo "   ⚠️  MDNS COLLISION DETECTED!"
        echo "   =========================================="
        echo "   Most likely: Service restarted too fast (mDNS has ~120s TTL)"
        echo "   Less likely: Another device has the same name"
        echo ""
        echo "   This prevents TIDAL from discovering your device."
        echo ""
        echo "   Recent collision errors:"
        echo "$COLLISION_CHECK" | sed 's/^/   /'
        echo ""
        echo "   🔧 FIX: See recommendations below"
        echo "   =========================================="
    else
        OTHER_ERRORS=$(docker logs "$CONTAINER" 2>&1 | grep -i "avahi\|mDNS" | grep -i "error\|warning" | tail -5)
        if [ -n "$OTHER_ERRORS" ]; then
            echo "   ⚠️  Avahi warnings found:"
            echo "$OTHER_ERRORS" | sed 's/^/   /'
        else
            echo "   ✓ No Avahi/mDNS errors detected"
        fi
    fi
else
    echo "   Cannot check - no container found"
fi
echo ""

# Check container logs for errors
echo "5. Recent Container Errors (last 20 lines):"
if [ -n "$CONTAINER" ]; then
    docker logs "$CONTAINER" --tail 20 2>&1 | grep -iE "(error|warning|failed|crash)" || echo "   No errors found"
else
    echo "   Cannot check - no container found"
fi
echo ""

# Check if mDNS is advertising
echo "6. mDNS Advertisement Check:"
if command -v avahi-browse >/dev/null 2>&1; then
    echo "   Checking for Tidal services..."
    timeout 5 avahi-browse -t _tidalconnect._tcp 2>/dev/null || echo "   No Tidal services found (this is normal if not playing)"
else
    echo "   avahi-browse not available"
fi
echo ""

# Check network connectivity
echo "7. Network Connectivity:"
if [ -n "$CONTAINER" ] && docker ps | grep -q "$CONTAINER"; then
    if docker exec "$CONTAINER" ping -c 1 8.8.8.8 >/dev/null 2>&1; then
        echo "   ✓ Container has internet connectivity"
    else
        echo "   ✗ Container cannot reach internet"
    fi
else
    echo "   Cannot check - container not running"
fi
echo ""

# Check volume bridge
echo "8. Volume Bridge Status:"
systemctl status tidal-volume-bridge.service --no-pager -l 2>/dev/null | head -5 || echo "   Volume bridge service not found"
echo ""

# Check watchdog (legacy only)
echo "9. Watchdog Status:"
if [ "$SETUP_TYPE" = "Legacy" ]; then
    systemctl status tidal-watchdog.service --no-pager -l 2>/dev/null | head -5 || echo "   Watchdog service not found"
else
    echo "   Not applicable for GioF71 setup"
fi
echo ""

# Check recent watchdog activity
if [ -f "/var/log/tidal-watchdog.log" ]; then
    echo "10. Recent Watchdog Activity:"
    tail -10 /var/log/tidal-watchdog.log
else
    echo "10. Watchdog log not found (normal for GioF71 setup)"
fi
echo ""

echo "=========================================="
echo "Recommendations:"
echo "=========================================="
echo ""

# Check for name collision first (most common issue)
if [ -n "$CONTAINER" ] && docker logs "$CONTAINER" 2>&1 | grep -q "AVAHI_CLIENT_S_COLLISION\|AVAHI_CLIENT_FAILURE"; then
    echo "🚨 PRIMARY ISSUE: mDNS COLLISION"
    echo ""
    echo "The service is colliding with its own mDNS registration during restarts."
    echo "mDNS announcements have a TTL (~120s), and rapid restarts cause conflicts."
    echo ""
    if [ "$SETUP_TYPE" = "GioF71" ]; then
        echo "Fix - Run reset script:"
        echo "  cd /data/tidal-connect-docker && ./reset-tidal-gio.sh"
    else
        echo "Fix - Run reset script:"
        echo "  cd /data/tidal-connect-docker && ./reset-tidal.sh"
    fi
    echo ""
    echo "=========================================="
    echo ""
fi

if [ -z "$CONTAINER" ] || ! docker ps | grep -q "$CONTAINER"; then
    echo "→ Container is not running."
    if [ "$SETUP_TYPE" = "GioF71" ]; then
        echo "  Try: systemctl restart tidal-gio.service"
    else
        echo "  Try: systemctl restart tidal.service"
    fi
fi
if ! systemctl is-active --quiet avahi-daemon; then
    echo "→ Avahi is not running. Try: systemctl restart avahi-daemon"
fi
if [ -n "$CONTAINER" ] && docker ps | grep -q "$CONTAINER" && ! docker logs "$CONTAINER" 2>&1 | grep -q "AVAHI_CLIENT_S_COLLISION"; then
    echo "→ If device still not visible, try:"
    echo "  1. systemctl restart avahi-daemon"
    if [ "$SETUP_TYPE" = "GioF71" ]; then
        echo "  2. systemctl restart tidal-gio.service"
    else
        echo "  2. systemctl restart tidal.service"
    fi
    echo "  3. Wait 10-15 seconds"
    echo "  4. Refresh Tidal app"
fi
echo ""
echo "For full reset:"
if [ "$SETUP_TYPE" = "GioF71" ]; then
    echo "  cd /data/tidal-connect-docker && ./reset-tidal-gio.sh"
else
    echo "  cd /data/tidal-connect-docker && ./reset-tidal.sh"
fi
echo ""
