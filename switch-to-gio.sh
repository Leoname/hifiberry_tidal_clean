#!/bin/bash
# Quick script to switch from old tidal.service to new tidal-gio.service
# Run this on your HiFiBerry after the GioF71 setup is installed

set -e

echo "========================================"
echo "Switching to GioF71 Tidal Connect"
echo "========================================"
echo

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

# Check if GioF71 setup exists
if [ ! -d "/data/tidal-connect" ]; then
    echo "ERROR: GioF71 setup not found at /data/tidal-connect"
    echo "Please run install-tidal-gio.sh first"
    exit 1
fi

# Step 1: Stop old services
echo "1. Stopping old services..."
systemctl stop tidal.service 2>/dev/null || true
systemctl stop tidal-watchdog.service 2>/dev/null || true
systemctl stop tidal-volume-bridge.service 2>/dev/null || true
echo "   ✓ Old services stopped"

# Step 2: Remove old containers
echo "2. Removing old containers..."
docker rm -f tidal_connect 2>/dev/null || true
echo "   ✓ Old containers removed"

# Step 3: Disable old services
echo "3. Disabling old services..."
systemctl disable tidal.service 2>/dev/null || true
systemctl disable tidal-watchdog.service 2>/dev/null || true
echo "   ✓ Old services disabled"

# Step 4: Check if tidal-gio.service exists
if [ ! -f "/etc/systemd/system/tidal-gio.service" ]; then
    echo
    echo "⚠️  tidal-gio.service not found!"
    echo "Creating it now..."
    
    cat > /etc/systemd/system/tidal-gio.service << 'EOF'
[Unit]
Description=Tidal Connect (GioF71)
After=docker.service network-online.target avahi-daemon.service
Requires=docker.service
Wants=avahi-daemon.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/data/tidal-connect
ExecStartPre=/bin/bash -c 'docker rm -f tidal-connect 2>/dev/null || true'
ExecStart=/usr/bin/docker-compose up -d
ExecStop=/usr/bin/docker-compose down --timeout 10
TimeoutStartSec=60
TimeoutStopSec=30

[Install]
WantedBy=multi-user.target
EOF
    echo "   ✓ Service file created"
fi

# Step 5: Reload systemd and enable new service
echo "4. Enabling new service..."
systemctl daemon-reload
systemctl enable tidal-gio.service
echo "   ✓ tidal-gio.service enabled"

# Step 6: Start new service
echo "5. Starting Tidal Connect..."
systemctl start tidal-gio.service
echo "   ✓ Service started"

# Wait a moment
sleep 5

# Step 7: Start volume bridge (if it exists and was updated)
if [ -f "/etc/systemd/system/tidal-volume-bridge.service" ]; then
    echo "6. Starting volume bridge..."
    systemctl start tidal-volume-bridge.service 2>/dev/null || true
    echo "   ✓ Volume bridge started"
fi

echo
echo "========================================"
echo "Switch Complete!"
echo "========================================"
echo

# Show status
echo "Container Status:"
docker ps | grep tidal || echo "   ⚠️  Container not running yet (check logs)"
echo

echo "Service Status:"
systemctl status tidal-gio.service --no-pager -l | head -10
echo

echo "Recent Logs:"
cd /data/tidal-connect
docker-compose logs --tail 10 2>/dev/null || docker logs tidal-connect --tail 10 2>/dev/null || echo "   No logs yet"
echo

echo "Your device should appear in the TIDAL app shortly!"
echo "If not, check logs with: docker-compose -f /data/tidal-connect/docker-compose.yaml logs -f"

