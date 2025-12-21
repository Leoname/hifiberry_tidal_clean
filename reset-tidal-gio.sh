#!/bin/bash
# Reset script for Tidal Connect (GioF71 version)
# Use this when things get stuck or after updates

set -e

echo "========================================"
echo "Tidal Connect Reset (GioF71)"
echo "========================================"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

INSTALL_DIR="/data/tidal-connect"

# Step 1: Stop all services
echo "1. Stopping all Tidal services..."
systemctl stop tidal-volume-bridge.service 2>/dev/null || true
systemctl stop tidal-gio.service 2>/dev/null || true
echo "   ✓ Services stopped"

# Step 2: Remove containers
echo "2. Removing Docker containers..."
docker rm -f tidal-connect 2>/dev/null || true
docker rm -f tidal_connect 2>/dev/null || true
echo "   ✓ Containers removed"

# Step 3: Clean Docker networks
echo "3. Cleaning Docker networks..."
docker network prune -f 2>/dev/null || true
echo "   ✓ Networks cleaned"

# Step 4: Restart Avahi and wait for mDNS to clear
echo "4. Restarting Avahi daemon..."
systemctl restart avahi-daemon
echo "   Waiting for mDNS cache to clear (mDNS TTL is ~120s)..."
echo "   This prevents collision errors on restart"
sleep 5
echo "   ✓ Avahi restarted (waiting additional time for mDNS to stabilize)"
sleep 10
echo "   ✓ mDNS cache cleared"

# Step 5: Reload ALSA
echo "5. Reloading ALSA state..."
alsactl restore 2>/dev/null || true
echo "   ✓ ALSA reloaded"

# Step 6: Start services
echo "6. Starting Tidal Connect..."
cd "$INSTALL_DIR"
systemctl start tidal-gio.service
echo "   ✓ Tidal Connect started"

sleep 5

echo "7. Starting Volume Bridge..."
systemctl start tidal-volume-bridge.service 2>/dev/null || true
echo "   ✓ Volume Bridge started"

echo "========================================"
echo "Reset Complete!"
echo "========================================"
echo

# Show status
docker ps | grep tidal && echo "✓ Container is running" || echo "✗ Container not running"
echo

echo "Check your TIDAL app - the device should appear shortly."

