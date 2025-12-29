#!/bin/bash
# Analyze AudioControl2 source code to find active player logic

echo "=========================================="
echo "Analyzing AudioControl2 Source Code"
echo "=========================================="
echo ""

AC2_SOURCE="/opt/audiocontrol2/audiocontrol2.py"

if [ ! -f "$AC2_SOURCE" ]; then
    echo "✗ AudioControl2 source not found"
    exit 1
fi

# 1. Find command endpoint
echo "1. Finding Command Endpoint Handler:"
echo "Searching for '/api/player/command'..."
grep -n "/api/player/command" "$AC2_SOURCE" | head -5
echo ""

# Get line numbers and show context
COMMAND_LINE=$(grep -n "/api/player/command\|@.*route.*command" "$AC2_SOURCE" | head -1 | cut -d: -f1)
if [ -n "$COMMAND_LINE" ]; then
    echo "Command endpoint found at line $COMMAND_LINE:"
    sed -n "$((COMMAND_LINE-5)),$((COMMAND_LINE+50))p" "$AC2_SOURCE" | head -60
else
    echo "Command endpoint not found with that pattern, searching differently..."
    grep -n "def.*command\|player.*command" "$AC2_SOURCE" | head -10
fi
echo ""

# 2. Find status endpoint
echo "2. Finding Status Endpoint Handler:"
STATUS_LINE=$(grep -n "/api/player/status\|@.*route.*status" "$AC2_SOURCE" | head -1 | cut -d: -f1)
if [ -n "$STATUS_LINE" ]; then
    echo "Status endpoint found at line $STATUS_LINE:"
    sed -n "$((STATUS_LINE-5)),$((STATUS_LINE+50))p" "$AC2_SOURCE" | head -60
else
    echo "Status endpoint not found, searching differently..."
    grep -n "def.*status\|player.*status" "$AC2_SOURCE" | head -10
fi
echo ""

# 3. Find activePlayer usage
echo "3. Finding activePlayer Usage:"
grep -n "activePlayer" "$AC2_SOURCE" | head -20
echo ""

# Show context around activePlayer assignments
echo "Context around activePlayer assignments:"
grep -n "activePlayer" "$AC2_SOURCE" | while read line; do
    LINE_NUM=$(echo "$line" | cut -d: -f1)
    echo "--- Line $LINE_NUM ---"
    sed -n "$((LINE_NUM-3)),$((LINE_NUM+10))p" "$AC2_SOURCE"
    echo ""
done | head -100
echo ""

# 4. Find player selection logic
echo "4. Finding Player Selection/Active Logic:"
grep -n -i "get.*active\|select.*player\|determine.*active\|active.*player" "$AC2_SOURCE" | head -20
echo ""

# 5. Show player list/iteration
echo "5. Finding Player List Iteration:"
grep -n -A 5 "for.*player\|players\[" "$AC2_SOURCE" | head -30
echo ""

echo "=========================================="
echo "Summary:"
echo "=========================================="
echo "Review the output above to find:"
echo "1. Where /api/player/command is handled"
echo "2. Where activePlayer is set/used"
echo "3. How to fix it to auto-select playing player"

