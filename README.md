# Tidal Connect for HiFiBerry

Clean implementation using [GioF71's tidal-connect](https://github.com/GioF71/tidal-connect) to solve TLS compatibility issues with outdated Docker images.

## Why This Fork?

Original Docker images used outdated SSL libraries (OpenSSL 1.0.1t from 2019), causing TLS handshake failures when Tidal updated their server requirements. This repository uses GioF71's actively maintained setup with modern SSL libraries.

## Installation

```bash
cd /data
git clone https://github.com/Leoname/hifiberry_tidal_clean.git tidal-connect-docker
cd tidal-connect-docker
./install-tidal-gio.sh
```

## Configuration

Edit `/data/tidal-connect/.env`:

```bash
FRIENDLY_NAME=TidalConnect
MODEL_NAME=hifiberry
CARD_NAME=snd_rpi_hifiberry_dacplus
```

## Management

```bash
# Check status
./check-tidal-status.sh

# Reset
./reset-tidal-gio.sh

# View logs
cd /data/tidal-connect && docker-compose logs -f
```

## Troubleshooting

**Device not appearing:**
```bash
./reset-tidal-gio.sh
# Wait 15-20 seconds, then refresh Tidal app
```

**Check mDNS:**
```bash
avahi-browse -t _tidalconnect._tcp -r
```

## Updating

See [UPDATE_INSTRUCTIONS.md](UPDATE_INSTRUCTIONS.md) for keeping your system updated.

## Files

- `install-tidal-gio.sh` - Installer
- `reset-tidal-gio.sh` - Reset script
- `check-tidal-status.sh` - Diagnostics
- `volume-bridge.sh` - Volume sync & metadata
- `work-in-progress/audiocontrol2/` - AudioControl2 integration

## Credits

- [GioF71/tidal-connect](https://github.com/GioF71/tidal-connect)
- [TonyTromp/tidal-connect-docker](https://github.com/TonyTromp/tidal-connect-docker)
