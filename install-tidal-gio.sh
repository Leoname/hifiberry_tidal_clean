#!/bin/bash
# Tidal Connect Installer for HiFiBerry (using GioF71's tidal-connect)
# 
# This script installs Tidal Connect on a HiFiBerry device using
# the actively maintained GioF71/tidal-connect Docker setup.
#
# Usage: 
#   scp install-tidal-gio.sh root@hifiberry:/tmp/
#   ssh root@hifiberry 'bash /tmp/install-tidal-gio.sh'
#
# Or run directly:
#   ssh root@hifiberry 'bash -s' < install-tidal-gio.sh

set -e

# Configuration
INSTALL_DIR="/data/tidal-connect"
SCRIPTS_DIR="/data/tidal-connect-docker"
FRIENDLY_NAME="${1:-hifiberry}"
MODEL_NAME="${2:-hifiberry}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[INSTALL]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    error "Please run as root"
fi

echo "========================================"
echo "Tidal Connect Installer (GioF71)"
echo "========================================"
echo "Friendly Name: $FRIENDLY_NAME"
echo "Model Name: $MODEL_NAME"
echo "========================================"
echo

# Step 1: Stop existing services
log "Stopping existing Tidal services..."
systemctl stop tidal-watchdog.service 2>/dev/null || true
systemctl stop tidal-volume-bridge.service 2>/dev/null || true
systemctl stop tidal.service 2>/dev/null || true
systemctl stop tidal-gio.service 2>/dev/null || true

# Remove old containers
docker rm -f tidal_connect 2>/dev/null || true
docker rm -f tidal-connect 2>/dev/null || true

# Step 2: Install dependencies
log "Checking dependencies..."
if ! command -v docker &> /dev/null; then
    error "Docker is not installed. Please install Docker first."
fi

if ! command -v docker-compose &> /dev/null; then
    log "Installing docker-compose..."
    apt-get update && apt-get install -y docker-compose
fi

# Step 3: Clone GioF71's tidal-connect repo
log "Setting up Tidal Connect..."
if [ -d "$INSTALL_DIR" ]; then
    log "Updating existing installation..."
    cd "$INSTALL_DIR"
    git pull || warn "Could not update repo, using existing version"
else
    log "Cloning GioF71/tidal-connect..."
    git clone https://github.com/GioF71/tidal-connect.git "$INSTALL_DIR"
    cd "$INSTALL_DIR"
fi

# Step 4: Configure for HiFiBerry
log "Configuring for HiFiBerry DAC+..."
cat > .env << EOF
FRIENDLY_NAME=${FRIENDLY_NAME}
MODEL_NAME=${MODEL_NAME}
CARD_NAME=snd_rpi_hifiberry_dacplus
EOF

log "Configuration:"
cat .env

# Step 5: Create systemd service for Tidal Connect
log "Creating systemd service..."
cat > /etc/systemd/system/tidal-gio.service << EOF
[Unit]
Description=Tidal Connect (GioF71)
After=docker.service network-online.target avahi-daemon.service
Requires=docker.service
Wants=avahi-daemon.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=${INSTALL_DIR}
# Wait for Avahi to be fully ready
ExecStartPre=/bin/bash -c 'while ! systemctl is-active --quiet avahi-daemon; do sleep 1; done'
ExecStartPre=/bin/sleep 2
# Remove old container
ExecStartPre=/bin/bash -c 'docker rm -f tidal-connect 2>/dev/null || true'
# Wait for mDNS to clear to prevent collision (mDNS TTL is ~120s)
# This delay prevents collision errors when restarting quickly
ExecStartPre=/bin/sleep 5
ExecStart=/usr/bin/docker-compose up -d
ExecStop=/usr/bin/docker-compose down --timeout 10
TimeoutStartSec=120
TimeoutStopSec=30

[Install]
WantedBy=multi-user.target
EOF

# Step 6: Set up volume bridge (if scripts dir exists)
if [ -d "$SCRIPTS_DIR" ] && [ -f "$SCRIPTS_DIR/volume-bridge.sh" ]; then
    log "Setting up volume bridge..."
    
    # Update container name in volume-bridge.sh
    sed -i 's/tidal_connect/tidal-connect/g' "$SCRIPTS_DIR/volume-bridge.sh"
    chmod +x "$SCRIPTS_DIR/volume-bridge.sh"
    
    cat > /etc/systemd/system/tidal-volume-bridge.service << EOF
[Unit]
Description=Tidal Volume Bridge
After=tidal-gio.service
Requires=tidal-gio.service

[Service]
Type=simple
ExecStart=${SCRIPTS_DIR}/volume-bridge.sh
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl enable tidal-volume-bridge.service
else
    warn "Volume bridge script not found at $SCRIPTS_DIR/volume-bridge.sh"
    warn "Skipping volume bridge setup"
fi

# Step 7: Disable old services
log "Disabling old services..."
systemctl disable tidal.service 2>/dev/null || true
systemctl disable tidal-watchdog.service 2>/dev/null || true

# Step 8: Enable and start new services
log "Enabling services..."
systemctl daemon-reload
systemctl enable tidal-gio.service

log "Starting Tidal Connect..."
systemctl start tidal-gio.service

# Wait for container to be ready
log "Waiting for container to start..."
sleep 10

# Start volume bridge if configured
if [ -f /etc/systemd/system/tidal-volume-bridge.service ]; then
    systemctl start tidal-volume-bridge.service
fi

# Step 9: Verify installation
log "Verifying installation..."
echo
echo "========================================"
echo "Service Status"
echo "========================================"
systemctl status tidal-gio.service --no-pager -l | head -15
echo
if [ -f /etc/systemd/system/tidal-volume-bridge.service ]; then
    systemctl status tidal-volume-bridge.service --no-pager -l | head -10
fi

echo
echo "========================================"
echo "Container Status"
echo "========================================"
docker ps | grep tidal || warn "Container not running!"

echo
echo "========================================"
echo "Recent Logs"
echo "========================================"
docker-compose logs --tail 20 2>/dev/null || docker logs tidal-connect --tail 20 2>/dev/null

echo
echo "========================================"
echo -e "${GREEN}Installation Complete!${NC}"
echo "========================================"
echo
echo "Your device should now appear in the TIDAL app as: $FRIENDLY_NAME"
echo
echo "Useful commands:"
echo "  View logs:     docker-compose -f $INSTALL_DIR/docker-compose.yaml logs -f"
echo "  Restart:       systemctl restart tidal-gio.service"
echo "  Status:        systemctl status tidal-gio.service"
echo
echo "Test with a hard reboot to verify persistence:"
echo "  sudo reboot"
echo

