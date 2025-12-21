# Updating Your HiFiBerry System

After the mDNS collision fixes and other improvements, here's what you need to do on your HiFiBerry to keep everything up to date.

## Initial Update (One-Time)

### 1. Update the Scripts

```bash
# On your HiFiBerry
cd /data/tidal-connect-docker
git pull origin master
# Or if you need to set the remote:
# git remote add clean https://github.com/Leoname/hifiberry_tidal_clean.git
# git pull clean master
```

### 2. Update the Systemd Service

The systemd service (`tidal-gio.service`) has been updated with mDNS collision prevention. Update it:

```bash
# Copy the updated service configuration
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

# Reload systemd
systemctl daemon-reload
```

### 3. Update the Volume Bridge Script

The volume bridge script has been updated to support both container names. Update it:

```bash
# Copy the updated script
cd /data/tidal-connect-docker
# The script should already be updated if you pulled from git
# If not, copy it manually or pull again
```

### 4. Update AudioControl2 Integration (if installed)

If you have AudioControl2 installed, update the Tidal plugin:

```bash
# Copy the updated plugin
cd /data/tidal-connect-docker
cp work-in-progress/audiocontrol2/tidalcontrol.py /opt/audiocontrol2/ac2/players/tidalcontrol.py

# Restart AudioControl2
systemctl restart audiocontrol2
```

### 5. Restart Everything

```bash
# Apply all updates
cd /data/tidal-connect-docker
./reset-tidal-gio.sh
```

## Ongoing Updates

### Regular Updates

To keep your system up to date with the latest fixes:

```bash
# On your HiFiBerry
cd /data/tidal-connect-docker

# Pull latest changes
git pull clean master

# Check if systemd service needs updating
# (Compare /etc/systemd/system/tidal-gio.service with install-tidal-gio.sh)
# If the service file is outdated, re-run the installer or manually update it

# Restart to apply changes
./reset-tidal-gio.sh
```

### After Pulling Updates

1. **Check what changed:**
   ```bash
   git log --oneline -5
   ```

2. **If systemd service changed**, update it:
   ```bash
   # Re-run installer (safe, preserves settings)
   ./install-tidal-gio.sh
   ```

3. **If scripts changed**, restart services:
   ```bash
   ./reset-tidal-gio.sh
   ```

### Updating GioF71's Tidal Connect

The GioF71 repository is separate. To update it:

```bash
cd /data/tidal-connect
git pull origin main

# Restart the service
systemctl restart tidal-gio.service
```

## What Changed (mDNS Fixes)

The following improvements prevent mDNS collisions:

1. **Systemd Service**:
   - Waits for Avahi to be ready before starting
   - Waits 5 seconds before starting container (lets mDNS cache clear)
   - Increased timeout to 120 seconds

2. **Reset Script**:
   - Waits 15 seconds total for mDNS cache to clear
   - Better sequencing of Avahi restart

3. **Volume Bridge**:
   - Auto-detects container name (supports both `tidal-connect` and `tidal_connect`)
   - More robust error handling

4. **AudioControl2 Integration**:
   - Only activates when Tidal is actually playing (prevents interference with MPD/radio)
   - Auto-detects container name

## Verification

After updating, verify everything works:

```bash
# Check status
./check-tidal-status.sh

# Verify mDNS is working
avahi-browse -t _tidalconnect._tcp -r

# Check services
systemctl status tidal-gio.service
systemctl status tidal-volume-bridge.service
```

## Troubleshooting Updates

If something breaks after updating:

```bash
# Full reset
cd /data/tidal-connect-docker
./reset-tidal-gio.sh

# Check logs
docker logs tidal-connect --tail 50
journalctl -u tidal-gio.service -n 50
```

