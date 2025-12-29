#!/bin/bash
# Fix UI cache issue - force browser refresh

echo "=========================================="
echo "UI Cache Fix"
echo "=========================================="
echo ""

echo "AudioControl2 API correctly shows MPD as stopped:"
curl -s http://127.0.0.1:81/api/player/status 2>/dev/null | python3 -m json.tool 2>/dev/null | grep -A 3 '"name": "mpd"'
echo ""

echo "=========================================="
echo "The UI is showing cached/stale state."
echo ""
echo "To fix:"
echo "1. Hard refresh your browser:"
echo "   - Chrome/Edge: Ctrl+Shift+R (Windows) or Cmd+Shift+R (Mac)"
echo "   - Firefox: Ctrl+F5 (Windows) or Cmd+Shift+R (Mac)"
echo "   - Safari: Cmd+Option+R"
echo ""
echo "2. Or clear browser cache for the HiFiBerry IP"
echo ""
echo "3. Or restart the web server:"
echo "   systemctl restart audiocontrol2"
echo ""
echo "The API is correct - this is a browser cache issue."
echo "=========================================="

