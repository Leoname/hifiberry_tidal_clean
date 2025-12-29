#!/bin/bash
# Extract send_command method and player_control logic

WEBSERVER="/opt/audiocontrol2/ac2/webserver.py"
CONTROLLER="/opt/audiocontrol2/ac2/controller.py"

echo "=========================================="
echo "Extracting send_command and player_control Logic"
echo "=========================================="
echo ""

# 1. Find send_command method in webserver
echo "=== send_command method in webserver ==="
SEND_CMD_LINE=$(grep -n "def send_command" "$WEBSERVER" | head -1 | cut -d: -f1)
if [ -n "$SEND_CMD_LINE" ] && [ "$SEND_CMD_LINE" -gt 0 ] 2>/dev/null; then
    echo "Found at line $SEND_CMD_LINE:"
    END_LINE=$((SEND_CMD_LINE+50))
    sed -n "${SEND_CMD_LINE},${END_LINE}p" "$WEBSERVER"
else
    echo "Not found in webserver.py"
fi
echo ""

# 2. Find how player_control is initialized
echo "=== player_control initialization ==="
grep -n "self.player_control\|player_control\s*=" "$WEBSERVER" | head -10
echo ""

# 3. Find states() method in controller
echo "=== states() method in controller ==="
if [ -f "$CONTROLLER" ]; then
    STATES_LINE=$(grep -n "def states" "$CONTROLLER" | head -1 | cut -d: -f1)
    if [ -n "$STATES_LINE" ] && [ "$STATES_LINE" -gt 0 ] 2>/dev/null; then
        echo "Found at line $STATES_LINE:"
        END_LINE=$((STATES_LINE+100))
        sed -n "${STATES_LINE},${END_LINE}p" "$CONTROLLER" | head -120
    else
        echo "Not found"
    fi
else
    echo "Controller file not found"
fi
echo ""

# 4. Find activePlayer in controller
echo "=== activePlayer in controller ==="
if [ -f "$CONTROLLER" ]; then
    grep -n "activePlayer" "$CONTROLLER" | head -20
    echo ""
    echo "Context:"
    grep -n "activePlayer" "$CONTROLLER" | while read line; do
        LINE_NUM=$(echo "$line" | cut -d: -f1)
        if [ -n "$LINE_NUM" ] && [ "$LINE_NUM" -gt 0 ] 2>/dev/null; then
            START_LINE=$((LINE_NUM-5))
            END_LINE=$((LINE_NUM+15))
            if [ "$START_LINE" -lt 1 ]; then
                START_LINE=1
            fi
            echo "--- Line $LINE_NUM ---"
            sed -n "${START_LINE},${END_LINE}p" "$CONTROLLER"
            echo ""
        fi
    done | head -100
else
    echo "Controller file not found"
fi
echo ""

# 5. Find send_command in controller (if it exists there)
echo "=== send_command in controller ==="
if [ -f "$CONTROLLER" ]; then
    SEND_CMD_LINE=$(grep -n "def send_command" "$CONTROLLER" | head -1 | cut -d: -f1)
    if [ -n "$SEND_CMD_LINE" ] && [ "$SEND_CMD_LINE" -gt 0 ] 2>/dev/null; then
        echo "Found at line $SEND_CMD_LINE:"
        END_LINE=$((SEND_CMD_LINE+50))
        sed -n "${SEND_CMD_LINE},${END_LINE}p" "$CONTROLLER"
    else
        echo "Not found"
    fi
else
    echo "Controller file not found"
fi
echo ""

# 6. Find get_active_player or similar methods
echo "=== Active player methods ==="
if [ -f "$CONTROLLER" ]; then
    grep -n "def.*active\|get.*active\|active.*player" "$CONTROLLER" | head -20
    echo ""
    echo "Context:"
    grep -n "def.*active\|get.*active\|active.*player" "$CONTROLLER" | while read line; do
        LINE_NUM=$(echo "$line" | cut -d: -f1)
        if [ -n "$LINE_NUM" ] && [ "$LINE_NUM" -gt 0 ] 2>/dev/null; then
            START_LINE=$((LINE_NUM-3))
            END_LINE=$((LINE_NUM+30))
            if [ "$START_LINE" -lt 1 ]; then
                START_LINE=1
            fi
            echo "--- Line $LINE_NUM ---"
            sed -n "${START_LINE},${END_LINE}p" "$CONTROLLER"
            echo ""
        fi
    done | head -150
else
    echo "Controller file not found"
fi
echo ""

echo "=========================================="
echo "Now we can create the fix!"
echo "=========================================="

