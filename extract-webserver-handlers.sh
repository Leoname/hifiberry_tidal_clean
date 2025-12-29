#!/bin/bash
# Extract the webserver handler functions

WEBSERVER="/opt/audiocontrol2/ac2/webserver.py"

if [ ! -f "$WEBSERVER" ]; then
    echo "Webserver file not found"
    exit 1
fi

echo "=========================================="
echo "Extracting Webserver Handler Functions"
echo "=========================================="
echo ""

# 1. Find playercontrol_handler
echo "=== playercontrol_handler (command endpoint) ==="
CONTROL_LINE=$(grep -n "def playercontrol_handler" "$WEBSERVER" | cut -d: -f1)
if [ -n "$CONTROL_LINE" ]; then
    echo "Found at line $CONTROL_LINE:"
    sed -n "$CONTROL_LINE,$((CONTROL_LINE+100))p" "$WEBSERVER" | head -120
else
    echo "Not found"
fi
echo ""

# 2. Find playerstatus_handler
echo "=== playerstatus_handler (status endpoint) ==="
STATUS_LINE=$(grep -n "def playerstatus_handler" "$WEBSERVER" | cut -d: -f1)
if [ -n "$STATUS_LINE" ]; then
    echo "Found at line $STATUS_LINE:"
    sed -n "$STATUS_LINE,$((STATUS_LINE+100))p" "$WEBSERVER" | head -120
else
    echo "Not found"
fi
echo ""

# 3. Find activePlayer usage
echo "=== activePlayer Usage in Webserver ==="
grep -n "activePlayer" "$WEBSERVER"
echo ""

# Show context
echo "=== activePlayer Context ==="
grep -n "activePlayer" "$WEBSERVER" | while read line; do
    LINE_NUM=$(echo "$line" | cut -d: -f1)
    echo "--- Line $LINE_NUM ---"
    sed -n "$((LINE_NUM-5)),$((LINE_NUM+15))p" "$WEBSERVER"
    echo ""
done
echo ""

# 4. Check how players are accessed
echo "=== Player Access Methods ==="
grep -n -A 10 "self\.controller\|mpris\|get.*player" "$WEBSERVER" | head -50
echo ""

echo "=========================================="
echo "Now we can create a fix!"
echo "=========================================="

