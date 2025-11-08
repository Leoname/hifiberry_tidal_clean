#!/bin/bash

# Diagnostic script to check why Tidal Connect isn't being recognized

echo "=========================================="
echo "Tidal Connect Status Check"
echo "=========================================="
echo ""

# Check if container is running
echo "1. Container Status:"
if docker ps | grep -q tidal_connect; then
    echo "   ✓ Container is running"
    docker ps | grep tidal_connect
else
    echo "   ✗ Container is NOT running"
    echo "   Checking stopped containers..."
    docker ps -a | grep tidal_connect
fi
echo ""

# Check service status
echo "2. Service Status:"
systemctl status tidal.service --no-pager -l | head -10
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
echo "4. Recent Avahi Errors (last 50 lines):"
docker logs tidal_connect 2>&1 | grep -i "avahi\|collision\|mDNS" | tail -10 || echo "   No Avahi errors found"
echo ""

# Check container logs for errors
echo "5. Recent Container Errors (last 20 lines):"
docker logs tidal_connect --tail 20 2>&1 | grep -iE "(error|warning|failed|crash)" || echo "   No errors found"
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
if docker exec tidal_connect ping -c 1 8.8.8.8 >/dev/null 2>&1; then
    echo "   ✓ Container has internet connectivity"
else
    echo "   ✗ Container cannot reach internet"
fi
echo ""

# Check volume bridge
echo "8. Volume Bridge Status:"
systemctl status tidal-volume-bridge.service --no-pager -l | head -5
echo ""

# Check watchdog
echo "9. Watchdog Status:"
systemctl status tidal-watchdog.service --no-pager -l | head -5
echo ""

# Check recent watchdog activity
if [ -f "/var/log/tidal-watchdog.log" ]; then
    echo "10. Recent Watchdog Activity:"
    tail -10 /var/log/tidal-watchdog.log
else
    echo "10. Watchdog log not found"
fi
echo ""

echo "=========================================="
echo "Recommendations:"
echo "=========================================="
echo ""
if ! docker ps | grep -q tidal_connect; then
    echo "→ Container is not running. Try: systemctl restart tidal.service"
fi
if ! systemctl is-active --quiet avahi-daemon; then
    echo "→ Avahi is not running. Try: systemctl restart avahi-daemon"
fi
echo "→ If device still not visible, try:"
echo "  1. systemctl restart avahi-daemon"
echo "  2. systemctl restart tidal.service"
echo "  3. Wait 10-15 seconds"
echo "  4. Refresh Tidal app"
echo ""

