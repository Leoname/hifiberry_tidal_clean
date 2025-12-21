# Tidal Connect for HiFiBerry - Clean Implementation

A clean, actively maintained Tidal Connect setup for HiFiBerry devices using [GioF71's tidal-connect](https://github.com/GioF71/tidal-connect).

![hifiberry_sources](img/hifiberry_listsources.png?raw=true)

## Why This Fork?

This repository provides a **clean, simplified implementation** focused on the **GioF71/tidal-connect** setup, which solves the TLS compatibility issues that plagued earlier implementations.

### Background: TLS Errors and the Solution

**The Problem:**
- Original Docker images (e.g., `edgecrush3r/tidal-connect`) used outdated SSL libraries (OpenSSL 1.0.1t from 2019)
- Tidal's servers updated their TLS requirements, causing handshake failures
- Error: `[error] handle_transport_init received error: TLS handshake failed`
- The proprietary Tidal Connect binary was compiled against ancient dependencies, making updates difficult

**The Solution:**
- **GioF71/tidal-connect**: Uses a modern Debian base image with up-to-date SSL libraries
- Better ALSA integration and audio device handling
- Actively maintained (last updated December 2024)
- Handles mDNS registration more reliably
- Cleaner Docker setup without custom builds

**What This Repository Provides:**
- Automated installation script for HiFiBerry devices
- Volume bridge for phone volume control and metadata export
- AudioControl2 integration for HiFiBerry UI
- mDNS collision prevention (permanent fix)
- Diagnostic tools and reset scripts
- Clean separation from legacy code

## Features

- ✅ **Tidal Connect** - Full Tidal Connect integration for high-quality music streaming
- ✅ **Phone Volume Control** - Volume adjustments from your phone/tablet sync to ALSA mixer
- ✅ **Metadata Display** - Now playing info (artist, title, album) shown in HiFiBerry UI via AudioControl2
- ✅ **Web UI Controls** - Play/pause, next, previous controls work from the HiFiBerry web interface
- ✅ **mDNS Collision Prevention** - Automatic handling of mDNS registration to prevent discovery issues
- ✅ **Auto-start on Boot** - Systemd service ensures Tidal Connect starts automatically
- ✅ **Radio Stream Support** - Works alongside MPD and other audio players without conflicts
- ✅ **TLS Compatible** - Uses modern SSL libraries compatible with current Tidal servers

## Quick Start

### Installation

```bash
# On your HiFiBerry device
cd /data
git clone https://github.com/Leoname/hifiberry_tidal_clean.git tidal-connect-docker
cd tidal-connect-docker

# Run the installer
./install-tidal-gio.sh
```

The installer will:
- Clone GioF71's tidal-connect repository to `/data/tidal-connect`
- Configure it for HiFiBerry DAC+
- Set up systemd services (`tidal-gio.service`, `tidal-volume-bridge.service`)
- Configure AudioControl2 integration (if available)
- Set up mDNS collision prevention

**After installation, test with a reboot:**
```bash
sudo reboot
```

Your device should appear in the Tidal app as "TidalConnect" (or the name you configured).

## Configuration

Edit `/data/tidal-connect/.env` to customize:

```bash
FRIENDLY_NAME=TidalConnect    # Name shown in Tidal app
MODEL_NAME=hifiberry          # Device model name
CARD_NAME=snd_rpi_hifiberry_dacplus  # ALSA card name
```

After changing configuration:
```bash
cd /data/tidal-connect-docker
./reset-tidal-gio.sh
```

## Management

### Check Status
```bash
cd /data/tidal-connect-docker
./check-tidal-status.sh
```

### Reset/Reinstall
```bash
cd /data/tidal-connect-docker
./reset-tidal-gio.sh
```

### View Logs
```bash
# Container logs
cd /data/tidal-connect && docker-compose logs -f

# Or directly
docker logs tidal-connect --tail 50 -f

# Volume bridge logs
journalctl -u tidal-volume-bridge -f
```

### Manual Service Control
```bash
# Start/Stop/Restart
systemctl start tidal-gio.service
systemctl stop tidal-gio.service
systemctl restart tidal-gio.service

# Check status
systemctl status tidal-gio.service
```

## Troubleshooting

### Device Not Appearing in Tidal App

1. **Run the reset script:**
   ```bash
   cd /data/tidal-connect-docker
   ./reset-tidal-gio.sh
   ```

2. **Wait 15-20 seconds**, then:
   - Force close the Tidal app completely
   - Reopen it
   - Pull down to refresh/scan for devices

3. **Check mDNS is working:**
   ```bash
   avahi-browse -t _tidalconnect._tcp -r
   ```
   Should show your device with IP and port 2019

4. **Verify container is running:**
   ```bash
   docker ps | grep tidal-connect
   ./check-tidal-status.sh
   ```

### Radio/MPD Controls Not Working

If you can't stop radio streams through the UI, the AudioControl2 integration may be interfering. The updated `tidalcontrol.py` only activates when Tidal is actually playing, so this should be resolved. If issues persist:

```bash
# Restart AudioControl2
systemctl restart audiocontrol2
```

### mDNS Collision Errors

The service is now configured to prevent mDNS collisions automatically. If you see collision errors:

```bash
cd /data/tidal-connect-docker
./reset-tidal-gio.sh
```

This will clear the mDNS cache and restart everything cleanly.

## AudioControl2 Integration (Optional)

For metadata display and web UI controls, install the AudioControl2 integration:

```bash
cd /data/tidal-connect-docker/work-in-progress/audiocontrol2

# Manual installation (if install.sh doesn't work)
ln -s $(pwd)/tidalcontrol.py /opt/audiocontrol2/ac2/players/tidalcontrol.py

# Edit /opt/audiocontrol2/audiocontrol2.py to add:
# from ac2.players.tidalcontrol import TidalControl
# tdctl = TidalControl()
# tdctl.start()
# mpris.register_nonmpris_player(tdctl.playername, tdctl)

# Restart AudioControl2
systemctl restart audiocontrol2
```

See `work-in-progress/audiocontrol2/README.md` for detailed instructions.

## Architecture

- **GioF71/tidal-connect**: Main Tidal Connect implementation (Docker container)
- **tidal-gio.service**: Systemd service managing the Docker container
- **volume-bridge.sh**: Syncs phone volume to ALSA and exports metadata for AudioControl2
- **tidal-volume-bridge.service**: Systemd service for volume bridge
- **tidalcontrol.py**: AudioControl2 plugin for UI integration

## Files

- `install-tidal-gio.sh` - Main installer script
- `reset-tidal-gio.sh` - Reset/troubleshooting script
- `switch-to-gio.sh` - Migration script from legacy setup
- `check-tidal-status.sh` - Diagnostic script
- `volume-bridge.sh` - Volume sync and metadata export
- `speaker-controller-service` - Speaker controller management

## Credits

- Based on [GioF71/tidal-connect](https://github.com/GioF71/tidal-connect) - Actively maintained Tidal Connect implementation
- Original Docker port by [TonyTromp/tidal-connect-docker](https://github.com/TonyTromp/tidal-connect-docker)
- Tidal Connect binary from iFi Audio

## License

See individual component licenses in their respective repositories.
