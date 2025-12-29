#!/bin/bash
# Apply AudioControl2 active player fix with backup

echo "=========================================="
echo "AudioControl2 Active Player Fix"
echo "=========================================="
echo ""

WEBSERVER="/opt/audiocontrol2/ac2/webserver.py"
BACKUP="${WEBSERVER}.backup.$(date +%Y%m%d_%H%M%S)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check if file exists
if [ ! -f "$WEBSERVER" ]; then
    echo "✗ Webserver file not found at $WEBSERVER"
    exit 1
fi

# Check if already fixed
if grep -q "Auto-activating playing player" "$WEBSERVER"; then
    echo "✓ Fix already applied!"
    exit 0
fi

# Create backup
echo "1. Creating backup..."
cp "$WEBSERVER" "$BACKUP"
echo "✓ Backup created: $BACKUP"
echo ""

# Apply fix
echo "2. Applying fix..."
if [ -f "$SCRIPT_DIR/apply-audiocontrol2-fix.py" ]; then
    python3 "$SCRIPT_DIR/apply-audiocontrol2-fix.py"
else
    echo "✗ Fix script not found!"
    echo "Restoring backup..."
    cp "$BACKUP" "$WEBSERVER"
    exit 1
fi

if [ $? -eq 0 ]; then
    echo ""
    echo "=========================================="
    echo "Fix Applied Successfully!"
    echo "=========================================="
    echo ""
    echo "3. Showing modified code:"
    LINE_NUM=$(grep -n "def playercontrol_handler" "$WEBSERVER" | head -1 | cut -d: -f1)
    sed -n "${LINE_NUM},$((LINE_NUM+30))p" "$WEBSERVER"
    echo ""
    echo "=========================================="
    echo "Next Steps:"
    echo "=========================================="
    echo "1. Restart AudioControl2:"
    echo "   systemctl restart audiocontrol2"
    echo ""
    echo "2. Test UI controls with MPD playing"
    echo ""
    echo "3. If issues persist, restore backup:"
    echo "   cp $BACKUP $WEBSERVER"
    echo "   systemctl restart audiocontrol2"
    echo ""
else
    echo ""
    echo "✗ Fix failed! Restoring backup..."
    cp "$BACKUP" "$WEBSERVER"
    exit 1
fi

