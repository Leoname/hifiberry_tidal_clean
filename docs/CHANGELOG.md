# Changelog

## [2024-12-21] - Migration to GioF71 Setup

### Changed
- **Migrated to GioF71/tidal-connect**: Replaced legacy Docker build with actively maintained [GioF71/tidal-connect](https://github.com/GioF71/tidal-connect)
- **New installer**: `install-tidal-gio.sh` replaces `install_hifiberry.sh`
- **New reset script**: `reset-tidal-gio.sh` with improved mDNS collision handling
- **Updated scripts**: All scripts now support both `tidal-connect` (GioF71) and `tidal_connect` (legacy) container names

### Fixed
- **mDNS collision prevention**: Service now waits for mDNS cache to clear before starting
- **Container name detection**: Scripts automatically detect which container is running
- **Radio/MPD interference**: AudioControl2 integration only activates when Tidal is actually playing
- **Volume bridge**: Updated to work with new container name

### Added
- `check-tidal-status.sh` - Enhanced diagnostic script with auto-detection
- Improved mDNS collision handling in reset script
- `sync-from-github.sh` - Easy sync script for keeping HiFiBerry updated

### Removed
- Legacy Docker build system (`Docker/` directory)
- Old service templates (`templates/`)
- Legacy scripts (watchdog, old wait scripts, etc.)
- Outdated documentation

### Technical Details

**Why GioF71?**
- Actively maintained (last updated December 2024)
- Better audio device handling
- More reliable ALSA integration
- Cleaner Docker setup

**mDNS Collision Fix:**
- Reset script now waits 15 seconds for mDNS cache to clear (mDNS TTL is ~120s)
- Systemd service waits 5 seconds before starting container
- Prevents collision errors on rapid restarts

**Container Name Support:**
- All scripts now detect container name automatically
- Supports both `tidal-connect` (GioF71) and `tidal_connect` (legacy)
- No manual configuration needed

---

## Previous Entries

### Phone Volume Control
- `volume-bridge.sh` syncs phone volume to ALSA Digital mixer
- Exports metadata to `/tmp/tidal-status.json` for AudioControl2

### AudioControl2 Integration
- `tidalcontrol.py` plugin for metadata display and web UI controls
- Only activates when Tidal is actually playing (prevents interference with MPD/radio)

### mDNS Stability
- Improved collision handling
- Better restart sequence
- Automatic cache clearing
