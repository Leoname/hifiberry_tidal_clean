#!/bin/bash
# Diagnostic script for AirPlay issues on HiFiBerry

echo "=========================================="
echo "AirPlay Diagnostic Check"
echo "=========================================="
echo ""

# 1. Check for AirPlay-related services
echo "1. Checking AirPlay Services:"
echo ""

# Common AirPlay service names
SERVICES=("shairport-sync" "raat" "airplay" "shairport")

FOUND_SERVICE=""
for service in "${SERVICES[@]}"; do
    if systemctl list-unit-files | grep -q "^${service}"; then
        echo "   ✓ Found service: ${service}"
        FOUND_SERVICE="${service}"
        STATUS=$(systemctl is-active "${service}" 2>/dev/null || echo "inactive")
        ENABLED=$(systemctl is-enabled "${service}" 2>/dev/null || echo "unknown")
        echo "      Status: ${STATUS}"
        echo "      Enabled: ${ENABLED}"
    fi
done

if [ -z "$FOUND_SERVICE" ]; then
    echo "   ⚠ No AirPlay services found in systemd"
    echo "   Checking for running processes..."
    ps aux | grep -iE "shairport|raat|airplay" | grep -v grep || echo "      No AirPlay processes found"
fi

echo ""

# 2. Check mDNS/Avahi for AirPlay service
echo "2. Checking mDNS/Avahi for AirPlay service:"
if command -v avahi-browse >/dev/null 2>&1; then
    echo "   Checking for _raop._tcp (AirPlay)..."
    avahi-browse -t _raop._tcp -r 2>/dev/null | head -20 || echo "      No AirPlay service found via mDNS"
else
    echo "   ⚠ avahi-browse not found"
fi
echo ""

# 3. Check Avahi daemon
echo "3. Avahi daemon status:"
if systemctl is-active --quiet avahi-daemon; then
    echo "   ✓ Avahi daemon is running"
else
    echo "   ✗ Avahi daemon is NOT running (required for AirPlay discovery)"
    echo "      Start with: systemctl start avahi-daemon"
fi
echo ""

# 4. Check for AirPlay processes
echo "4. Running AirPlay processes:"
AIRPLAY_PROCS=$(ps aux | grep -iE "shairport|raat|airplay" | grep -v grep)
if [ -n "$AIRPLAY_PROCS" ]; then
    echo "$AIRPLAY_PROCS"
else
    echo "   ⚠ No AirPlay processes running"
fi
echo ""

# 5. Check audio device availability
echo "5. Audio device status:"
if [ -d "/proc/asound" ]; then
    echo "   ALSA cards:"
    cat /proc/asound/cards 2>/dev/null || echo "      Could not read ALSA cards"
else
    echo "   ⚠ /proc/asound not found"
fi
echo ""

# 6. Check recent logs
echo "6. Recent service logs (if service found):"
if [ -n "$FOUND_SERVICE" ]; then
    echo "   Last 20 lines of ${FOUND_SERVICE} logs:"
    journalctl -u "${FOUND_SERVICE}" -n 20 --no-pager 2>/dev/null || echo "      Could not read logs"
else
    echo "   Checking system logs for AirPlay errors..."
    journalctl -n 50 --no-pager | grep -iE "airplay|shairport|raat" | tail -10 || echo "      No recent AirPlay-related log entries"
fi
echo ""

# 7. Check network connectivity
echo "7. Network status:"
if ip addr show | grep -q "state UP" >/dev/null 2>&1; then
    echo "   ✓ Network interfaces are up"
    ip addr show | grep -E "^[0-9]+:|inet " | head -10
else
    echo "   ⚠ Network may be down"
fi
echo ""

# 8. Check firewall/iptables (if applicable)
echo "8. Firewall status:"
if command -v ufw >/dev/null 2>&1; then
    ufw status | head -5
elif command -v iptables >/dev/null 2>&1; then
    echo "   iptables is installed (check rules manually if needed)"
else
    echo "   No firewall detected"
fi
echo ""

# Summary and recommendations
echo "=========================================="
echo "Summary & Recommendations:"
echo "=========================================="

if [ -z "$FOUND_SERVICE" ]; then
    echo "⚠ AirPlay service not found!"
    echo ""
    echo "On HiFiBerryOS, AirPlay is typically provided by:"
    echo "  1. shairport-sync (most common)"
    echo "  2. raat (HiFiBerry's AirPlay implementation)"
    echo ""
    echo "To enable AirPlay:"
    echo "  1. Check HiFiBerryOS web interface: Settings > Audio > AirPlay"
    echo "  2. Or install shairport-sync manually:"
    echo "     apt-get update && apt-get install shairport-sync"
    echo "     systemctl enable shairport-sync"
    echo "     systemctl start shairport-sync"
elif [ "$STATUS" != "active" ]; then
    echo "⚠ AirPlay service found but not running!"
    echo ""
    echo "To start:"
    echo "  systemctl start ${FOUND_SERVICE}"
    echo "  systemctl enable ${FOUND_SERVICE}  # to start on boot"
elif ! systemctl is-active --quiet avahi-daemon; then
    echo "⚠ Avahi daemon is not running (required for AirPlay discovery)!"
    echo ""
    echo "To fix:"
    echo "  systemctl start avahi-daemon"
    echo "  systemctl enable avahi-daemon"
else
    echo "✓ AirPlay service appears to be configured"
    echo ""
    echo "If AirPlay still doesn't work:"
    echo "  1. Restart the service: systemctl restart ${FOUND_SERVICE}"
    echo "  2. Check logs: journalctl -u ${FOUND_SERVICE} -f"
    echo "  3. Verify audio device is not in use by another service"
    echo "  4. Check HiFiBerryOS web interface for AirPlay settings"
fi
echo ""

