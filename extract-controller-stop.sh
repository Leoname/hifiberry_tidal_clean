#!/bin/bash
# Extract AudioController stop method

CONTROLLER="/opt/audiocontrol2/ac2/controller.py"

echo "=========================================="
echo "Extracting AudioController stop() Method"
echo "=========================================="
echo ""

if [ ! -f "$CONTROLLER" ]; then
    echo "✗ Controller file not found"
    exit 1
fi

# Find stop method
STOP_LINE=$(grep -n "def stop" "$CONTROLLER" | head -1 | cut -d: -f1)

if [ -n "$STOP_LINE" ] && [ "$STOP_LINE" -gt 0 ] 2>/dev/null; then
    echo "Found stop() at line $STOP_LINE:"
    END_LINE=$((STOP_LINE+30))
    sed -n "${STOP_LINE},${END_LINE}p" "$CONTROLLER"
else
    echo "stop() method not found"
    echo ""
    echo "Searching for stop-related methods:"
    grep -n "def.*stop\|stop\|STOP" "$CONTROLLER" | head -20
fi
echo ""

# Also check for mpris_command
echo "=== Searching for mpris_command ==="
grep -n "mpris_command" "$CONTROLLER" | head -10
echo ""

