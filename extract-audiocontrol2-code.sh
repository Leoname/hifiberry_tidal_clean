#!/bin/bash
# Extract relevant AudioControl2 code sections

AC2_SOURCE="/opt/audiocontrol2/audiocontrol2.py"

if [ ! -f "$AC2_SOURCE" ]; then
    echo "AudioControl2 source not found at $AC2_SOURCE"
    exit 1
fi

echo "=========================================="
echo "Extracting AudioControl2 Code Sections"
echo "=========================================="
echo ""

# 1. Find and show command endpoint
echo "=== COMMAND ENDPOINT ==="
# Try different patterns
COMMAND_LINE=$(grep -n "api/player/command\|@app.route.*command\|def.*command" "$AC2_SOURCE" | head -1 | cut -d: -f1)
if [ -z "$COMMAND_LINE" ]; then
    # Try searching for POST with command
    COMMAND_LINE=$(grep -n "POST.*command\|request.*command" "$AC2_SOURCE" | head -1 | cut -d: -f1)
fi

if [ -n "$COMMAND_LINE" ]; then
    echo "Found at line $COMMAND_LINE:"
    sed -n "$((COMMAND_LINE-10)),$((COMMAND_LINE+80))p" "$AC2_SOURCE"
else
    echo "Not found, showing all route definitions:"
    grep -n "@app.route\|@route" "$AC2_SOURCE" | head -20
fi
echo ""

# 2. Find and show status endpoint
echo "=== STATUS ENDPOINT ==="
STATUS_LINE=$(grep -n "api/player/status\|@app.route.*status\|def.*status" "$AC2_SOURCE" | head -1 | cut -d: -f1)
if [ -n "$STATUS_LINE" ]; then
    echo "Found at line $STATUS_LINE:"
    sed -n "$((STATUS_LINE-10)),$((STATUS_LINE+80))p" "$AC2_SOURCE"
else
    echo "Not found"
fi
echo ""

# 3. Show all activePlayer usage
echo "=== activePlayer USAGE ==="
grep -n "activePlayer" "$AC2_SOURCE"
echo ""

# Show context for each
echo "=== activePlayer CONTEXT ==="
grep -n "activePlayer" "$AC2_SOURCE" | while read line; do
    LINE_NUM=$(echo "$line" | cut -d: -f1)
    echo "--- Line $LINE_NUM: $line ---"
    sed -n "$((LINE_NUM-5)),$((LINE_NUM+15))p" "$AC2_SOURCE"
    echo ""
done | head -200
echo ""

# 4. Show player management
echo "=== PLAYER MANAGEMENT ==="
grep -n -i "class.*player\|def.*player\|players\s*=" "$AC2_SOURCE" | head -20
echo ""

# 5. Show how players are iterated
echo "=== PLAYER ITERATION ==="
grep -n -A 10 "for.*player\|players\[" "$AC2_SOURCE" | head -40
echo ""

echo "=========================================="
echo "Save this output and share it to create a fix"
echo "=========================================="

