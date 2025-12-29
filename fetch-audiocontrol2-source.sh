#!/bin/bash
# Fetch AudioControl2 webserver source from HiFiBerry OS repository

echo "=========================================="
echo "Fetching AudioControl2 Source from GitHub"
echo "=========================================="
echo ""

# Try to fetch webserver.py from GitHub
WEBSERVER_URL="https://raw.githubusercontent.com/hifiberry/hifiberry-os/master/buildroot/package/audiocontrol2/src/ac2/webserver.py"

echo "Fetching webserver.py..."
if curl -s "$WEBSERVER_URL" -o /tmp/webserver.py 2>/dev/null; then
    echo "✓ Downloaded webserver.py"
    echo ""
    echo "=== playercontrol_handler ==="
    grep -n "def playercontrol_handler" /tmp/webserver.py | head -1
    CONTROL_LINE=$(grep -n "def playercontrol_handler" /tmp/webserver.py | head -1 | cut -d: -f1)
    if [ -n "$CONTROL_LINE" ]; then
        sed -n "$CONTROL_LINE,$((CONTROL_LINE+80))p" /tmp/webserver.py
    fi
    echo ""
    echo "=== playerstatus_handler ==="
    grep -n "def playerstatus_handler" /tmp/webserver.py | head -1
    STATUS_LINE=$(grep -n "def playerstatus_handler" /tmp/webserver.py | head -1 | cut -d: -f1)
    if [ -n "$STATUS_LINE" ]; then
        sed -n "$STATUS_LINE,$((STATUS_LINE+80))p" /tmp/webserver.py
    fi
    echo ""
    echo "=== activePlayer usage ==="
    grep -n "activePlayer" /tmp/webserver.py
    echo ""
    echo "=== activePlayer context ==="
    grep -n "activePlayer" /tmp/webserver.py | while read line; do
        LINE_NUM=$(echo "$line" | cut -d: -f1)
        echo "--- Line $LINE_NUM ---"
        sed -n "$((LINE_NUM-5)),$((LINE_NUM+15))p" /tmp/webserver.py
        echo ""
    done | head -150
    echo ""
    echo "Full file saved to: /tmp/webserver.py"
    echo "You can view it with: cat /tmp/webserver.py"
else
    echo "✗ Failed to download. Trying alternative path..."
    
    # Try alternative path
    WEBSERVER_URL2="https://raw.githubusercontent.com/hifiberry/hifiberry-os/master/buildroot/package/audiocontrol2/audiocontrol2/ac2/webserver.py"
    if curl -s "$WEBSERVER_URL2" -o /tmp/webserver.py 2>/dev/null; then
        echo "✓ Downloaded from alternative path"
        grep -n "def playercontrol_handler\|def playerstatus_handler\|activePlayer" /tmp/webserver.py | head -20
    else
        echo "✗ Could not fetch from GitHub"
        echo "Please check the repository structure at:"
        echo "https://github.com/hifiberry/hifiberry-os/tree/master/buildroot/package/audiocontrol2"
    fi
fi

