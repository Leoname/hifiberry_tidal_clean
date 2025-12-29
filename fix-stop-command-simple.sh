#!/bin/bash
# Simple fix for stop command - remove ignore parameter

echo "=========================================="
echo "Fixing Stop Command Bug"
echo "=========================================="
echo ""

WEBSERVER="/opt/audiocontrol2/ac2/webserver.py"
BACKUP="${WEBSERVER}.backup.$(date +%Y%m%d_%H%M%S)"

# Check if file exists
if [ ! -f "$WEBSERVER" ]; then
    echo "✗ Webserver file not found"
    exit 1
fi

# Check if already fixed
if grep -q "self.player_control.stop()" "$WEBSERVER" && ! grep -q "self.player_control.stop(ignore=" "$WEBSERVER"; then
    echo "✓ Fix already applied!"
    exit 0
fi

# Create backup
echo "1. Creating backup..."
cp "$WEBSERVER" "$BACKUP"
echo "✓ Backup: $BACKUP"
echo ""

# Fix using sed - replace the stop line
echo "2. Applying fix..."
sed -i 's/self\.player_control\.stop(ignore=ignore)/self.player_control.stop()  # Fix: stop() doesn't accept ignore parameter/g' "$WEBSERVER"

# Verify
if grep -q "self.player_control.stop()" "$WEBSERVER" && ! grep -q "self.player_control.stop(ignore=" "$WEBSERVER"; then
    echo "✓ Fix applied successfully!"
    echo ""
    echo "3. Showing fixed code:"
    grep -B 2 -A 2 "self.player_control.stop()" "$WEBSERVER" | head -5
    echo ""
    echo "=========================================="
    echo "Fix Applied!"
    echo "=========================================="
    echo ""
    echo "Next steps:"
    echo "1. Restart AudioControl2:"
    echo "   systemctl restart audiocontrol2"
    echo ""
    echo "2. Test stop command via UI"
    echo ""
else
    echo "✗ Fix verification failed!"
    echo "Restoring backup..."
    cp "$BACKUP" "$WEBSERVER"
    exit 1
fi

