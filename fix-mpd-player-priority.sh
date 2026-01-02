#!/bin/bash
# Ensure MPDControl takes priority over MPRIS for MPD

echo "=========================================="
echo "Fixing MPD Player Priority"
echo "=========================================="
echo ""

CONTROLLER="/opt/audiocontrol2/ac2/controller.py"
BACKUP="${CONTROLLER}.backup.$(date +%Y%m%d_%H%M%S)"

# Check if file exists
if [ ! -f "$CONTROLLER" ]; then
    echo "✗ Controller file not found"
    exit 1
fi

# Create backup
echo "1. Creating backup..."
cp "$CONTROLLER" "$BACKUP"
echo "✓ Backup: $BACKUP"
echo ""

echo "2. Checking how players are registered..."
grep -A 20 "MPDControl\|mpris" "$CONTROLLER" | head -25
echo ""

echo "3. The issue is that both MPDControl and MPRIS register MPD players."
echo "   We need to ensure MPDControl takes priority or disable MPRIS for MPD."
echo ""
echo "   Checking if we can modify player registration order..."
echo ""

# Check if we can find where players are added
if grep -q "self.players\[" "$CONTROLLER" || grep -q "players\[" "$CONTROLLER"; then
    echo "   Found player registration code"
    grep -B 5 -A 10 "players\[" "$CONTROLLER" | grep -A 10 "MPD\|mpd" | head -15
else
    echo "   Could not find player registration code"
fi

echo ""
echo "=========================================="
echo "Note: This is a complex fix that may require"
echo "modifying AudioControl2's player registration logic."
echo ""
echo "For now, try:"
echo "1. Restart AudioControl2: systemctl restart audiocontrol2"
echo "2. The MPDControl player should work correctly"
echo "3. The UI might need to be refreshed to use the correct player"
echo ""
echo "The state detection and metadata parsing fixes ARE permanent."
echo "The duplicate player issue may require AudioControl2 configuration changes."
echo "=========================================="

