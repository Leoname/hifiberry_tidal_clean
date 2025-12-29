#!/bin/bash
# Find AudioControl2 API endpoints using broader search

AC2_SOURCE="/opt/audiocontrol2/audiocontrol2.py"

if [ ! -f "$AC2_SOURCE" ]; then
    echo "AudioControl2 source not found"
    exit 1
fi

echo "=========================================="
echo "Finding AudioControl2 API Endpoints"
echo "=========================================="
echo ""

# 1. Check what framework is used
echo "1. Framework Detection:"
grep -i "flask\|bottle\|cherrypy\|tornado\|from.*import" "$AC2_SOURCE" | head -10
echo ""

# 2. Find all route decorators
echo "2. All Route Decorators:"
grep -n "@.*route\|@.*app\|def.*api" "$AC2_SOURCE" | head -30
echo ""

# 3. Search for "command" more broadly
echo "3. Searching for 'command' in code:"
grep -n -i "command" "$AC2_SOURCE" | head -30
echo ""

# 4. Search for "player" endpoints
echo "4. Searching for 'player' endpoints:"
grep -n -i "player.*status\|player.*command\|/api/player" "$AC2_SOURCE" | head -30
echo ""

# 5. Show file structure (first 100 lines)
echo "5. File Structure (first 100 lines):"
head -100 "$AC2_SOURCE"
echo ""

# 6. Check if there's a webserver module
echo "6. Checking for webserver module:"
if [ -d "/opt/audiocontrol2/ac2" ]; then
    echo "ac2 directory found, listing:"
    ls -la /opt/audiocontrol2/ac2/ | head -20
    echo ""
    if [ -f "/opt/audiocontrol2/ac2/webserver.py" ]; then
        echo "webserver.py found:"
        grep -n "player.*command\|player.*status" /opt/audiocontrol2/ac2/webserver.py | head -20
    fi
fi
echo ""

# 7. Search entire directory
echo "7. Searching entire AudioControl2 directory:"
find /opt/audiocontrol2 -name "*.py" -exec grep -l "player.*command\|api/player" {} \; 2>/dev/null
echo ""

echo "=========================================="
echo "Try these commands manually:"
echo "=========================================="
echo "1. Find webserver file:"
echo "   find /opt/audiocontrol2 -name '*webserver*' -o -name '*api*'"
echo ""
echo "2. Search all Python files:"
echo "   grep -r 'api/player/command' /opt/audiocontrol2/"
echo ""
echo "3. List all Python files:"
echo "   find /opt/audiocontrol2 -name '*.py' | head -20"

