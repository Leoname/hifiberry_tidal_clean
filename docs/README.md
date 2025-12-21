# TIDAL Connect Documentation

## Quick Start

See the main [README.md](../README.md) for installation and basic usage.

---

## Documentation Index

### Change History
- **[CHANGELOG.md](CHANGELOG.md)** - All changes and version history

---

## Architecture

### Current Setup (GioF71)

The current implementation uses [GioF71's tidal-connect](https://github.com/GioF71/tidal-connect), which is actively maintained and handles audio device setup more reliably than the legacy Docker build approach.

**Components:**
- **GioF71/tidal-connect**: Main Tidal Connect Docker container (uses `edgecrush3r/tidal-connect:latest` image)
- **tidal-gio.service**: Systemd service managing the Docker container
- **volume-bridge.sh**: Syncs phone volume to ALSA mixer and exports metadata for AudioControl2
- **tidal-volume-bridge.service**: Systemd service for volume bridge
- **tidalcontrol.py**: AudioControl2 plugin for UI integration (optional)

### Key Scripts

**Installation & Management:**
- `install-tidal-gio.sh` - Main installer for GioF71 setup
- `reset-tidal-gio.sh` - Reset/troubleshooting script
- `check-tidal-status.sh` - Diagnostic script
- `sync-from-github.sh` - Sync script for keeping system updated

**Integration:**
- `volume-bridge.sh` - Volume sync and metadata export
- `speaker-controller-service` - Speaker controller management
- `work-in-progress/audiocontrol2/tidalcontrol.py` - AudioControl2 player plugin

---

## Troubleshooting

### Device Not Appearing

1. Run diagnostics:
   ```bash
   ./check-tidal-status.sh
   ```

2. Check mDNS:
   ```bash
   avahi-browse -t _tidalconnect._tcp -r
   ```

3. Reset everything:
   ```bash
   ./reset-tidal-gio.sh
   ```

### mDNS Collision

The service is configured to prevent mDNS collisions automatically. If you see collision errors, the reset script will clear them.

### Radio/MPD Controls

The AudioControl2 integration only activates when Tidal is actually playing, so it won't interfere with MPD or other players.

---

## Getting Help

1. Run diagnostics: `./check-tidal-status.sh`
2. Check container logs:
   ```bash
   cd /data/tidal-connect && docker-compose logs -f
   ```
3. Check service status:
   ```bash
   systemctl status tidal-gio.service
   systemctl status tidal-volume-bridge.service
   ```
