#!/bin/bash
# Check if stop command fix is still applied

WEBSERVER="/opt/audiocontrol2/ac2/webserver.py"

echo "=========================================="
echo "Checking Stop Command Fix Status"
echo "=========================================="
echo ""

if [ ! -f "$WEBSERVER" ]; then
    echo "✗ Webserver file not found"
    exit 1
fi

# Check if fix is applied
if grep -q "self.player_control.stop()" "$WEBSERVER" && ! grep -q "self.player_control.stop(ignore=" "$WEBSERVER"; then
    echo "✓ Fix is applied correctly"
    echo ""
    echo "Current stop command line:"
    grep -n "elif command == \"stop\":" "$WEBSERVER" -A 1 | head -2
    exit 0
else
    echo "✗ Fix is NOT applied or has been reverted"
    echo ""
    echo "Current stop command line:"
    grep -n "elif command == \"stop\":" "$WEBSERVER" -A 1 | head -2
    echo ""
    echo "Would you like to reapply the fix? (y/n)"
    read -r answer
    if [ "$answer" = "y" ]; then
        ./fix-stop-command-simple.sh
    fi
    exit 1
fi

