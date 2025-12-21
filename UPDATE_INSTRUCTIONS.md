# Updating Your HiFiBerry System

Keep your Tidal Connect setup up to date with the latest fixes and improvements.

## Quick Update (Recommended)

```bash
cd /data/tidal-connect-docker
./sync-from-github.sh
./reset-tidal-gio.sh
```

The sync script will:
- Pull latest changes from GitHub
- Handle any conflicts automatically
- Make scripts executable
- Show you what changed

## Initial Setup

If you haven't set up the git remote yet:

```bash
cd /data/tidal-connect-docker
git remote add clean https://github.com/Leoname/hifiberry_tidal_clean.git 2>/dev/null || true
git remote set-url clean https://github.com/Leoname/hifiberry_tidal_clean.git
./sync-from-github.sh
```

## After Updating

### Check What Changed

```bash
git log --oneline -5
```

### If Systemd Service Changed

The installer will update the service automatically. Re-run it:

```bash
./install-tidal-gio.sh
```

This is safe - it preserves your existing configuration.

### If Scripts Changed

Restart services to apply changes:

```bash
./reset-tidal-gio.sh
```

## Updating GioF71's Tidal Connect

The GioF71 repository is separate. To update the underlying Tidal Connect:

```bash
cd /data/tidal-connect
git pull origin main
systemctl restart tidal-gio.service
```

## Verification

After updating, verify everything works:

```bash
# Check status
./check-tidal-status.sh

# Verify mDNS is working
avahi-browse -t _tidalconnect._tcp -r
```

## Troubleshooting

If something breaks after updating:

```bash
# Full reset
cd /data/tidal-connect-docker
./reset-tidal-gio.sh

# Check logs
docker logs tidal-connect --tail 50
journalctl -u tidal-gio.service -n 50
```

## What's Included

The repository includes:
- **mDNS collision prevention** - Automatic delays prevent collision errors
- **Container name auto-detection** - Works with both old and new setups
- **Volume bridge** - Syncs phone volume and exports metadata
- **AudioControl2 integration** - Only activates when Tidal is playing (doesn't interfere with MPD/radio)
