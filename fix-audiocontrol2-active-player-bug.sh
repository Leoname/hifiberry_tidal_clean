#!/bin/bash
# Fix AudioControl2 bug where activePlayer is not set when MPD is playing

echo "=========================================="
echo "Fixing AudioControl2 Active Player Bug"
echo "=========================================="
echo ""

# 1. Check AudioControl2 source location
echo "1. Locating AudioControl2 Source:"
AC2_SOURCE="/opt/audiocontrol2/audiocontrol2.py"
if [ ! -f "$AC2_SOURCE" ]; then
    echo "⚠️  AudioControl2 source not found at $AC2_SOURCE"
    echo "Searching for it..."
    AC2_SOURCE=$(find /opt -name "audiocontrol2.py" 2>/dev/null | head -1)
    if [ -z "$AC2_SOURCE" ]; then
        echo "✗ Could not find AudioControl2 source"
        exit 1
    fi
fi
echo "Found: $AC2_SOURCE"
echo ""

# 2. Backup original
echo "2. Creating Backup:"
BACKUP="${AC2_SOURCE}.backup.$(date +%Y%m%d_%H%M%S)"
cp "$AC2_SOURCE" "$BACKUP"
echo "✓ Backup created: $BACKUP"
echo ""

# 3. Check current active player logic
echo "3. Analyzing Active Player Logic:"
echo "Searching for activePlayer assignment..."
grep -n "activePlayer\|get_active\|determine.*active" "$AC2_SOURCE" | head -20
echo ""

# 4. Check if there's a method to set active player
echo "4. Checking for Active Player Setting Methods:"
grep -n "def.*active\|set.*active\|active.*=" "$AC2_SOURCE" | head -20
echo ""

# 5. Check player status endpoint
echo "5. Checking Player Status Endpoint:"
grep -A 30 "/api/player/status\|@.*route.*status" "$AC2_SOURCE" | head -50
echo ""

# 6. Check command endpoint
echo "6. Checking Command Endpoint:"
grep -B 5 -A 40 "/api/player/command\|@.*route.*command" "$AC2_SOURCE" | head -60
echo ""

echo "=========================================="
echo "Next Steps:"
echo "=========================================="
echo "1. Review the code above to understand how activePlayer is set"
echo "2. Look for where it should automatically select MPD when playing"
echo "3. Create a patch to fix the logic"
echo ""
echo "Common fixes:"
echo "- Auto-select player when only one is playing"
echo "- Set activePlayer in status endpoint when player is playing"
echo "- Fix command endpoint to handle None activePlayer gracefully"

