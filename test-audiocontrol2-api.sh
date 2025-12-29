#!/bin/bash
# Test AudioControl2 API to see why commands are failing

echo "=========================================="
echo "Testing AudioControl2 API"
echo "=========================================="
echo ""

# 1. Check API is accessible
echo "1. Testing API Accessibility:"
curl -s http://127.0.0.1:81/api/player/status > /dev/null && echo "✓ API is accessible" || echo "✗ API not accessible"
echo ""

# 2. Get full player status
echo "2. Full Player Status:"
curl -s http://127.0.0.1:81/api/player/status | python3 -m json.tool 2>/dev/null || curl -s http://127.0.0.1:81/api/player/status
echo ""

# 3. Test different API endpoints
echo "3. Testing API Endpoints:"
echo "Testing /api/player/command endpoint..."
RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X POST http://127.0.0.1:81/api/player/command \
  -H "Content-Type: application/json" \
  -d '{"player":"mpd","command":"status"}' 2>&1)
HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE" | cut -d: -f2)
BODY=$(echo "$RESPONSE" | grep -v "HTTP_CODE")
echo "HTTP Code: ${HTTP_CODE:-unknown}"
echo "Response: ${BODY:-none}"
echo ""

# 4. Try different command formats
echo "4. Trying Different Command Formats:"
echo "Format 1: playpause"
curl -s -X POST http://127.0.0.1:81/api/player/command \
  -H "Content-Type: application/json" \
  -d '{"player":"mpd","command":"playpause"}' && echo "" || echo "Failed"
echo ""

echo "Format 2: pause"
curl -s -X POST http://127.0.0.1:81/api/player/command \
  -H "Content-Type: application/json" \
  -d '{"player":"mpd","command":"pause"}' && echo "" || echo "Failed"
echo ""

# 5. Check AudioControl2 logs for API errors
echo "5. Recent API Errors in Logs:"
journalctl -u audiocontrol2 -n 50 --no-pager 2>/dev/null | grep -i "api\|command\|error\|failed" | tail -10 || echo "No errors found"
echo ""

# 6. Try direct MPD control as comparison
echo "6. Direct MPD Control (for comparison):"
echo "Current state:"
mpc status 2>/dev/null | head -3
echo ""
echo "Sending pause via mpc (this should work):"
mpc pause 2>&1
sleep 1
echo "State after mpc pause:"
mpc status 2>/dev/null | head -3
echo ""

# 7. Check if there's a different API endpoint
echo "7. Checking for Alternative API Endpoints:"
# Try the web UI endpoint
curl -s http://127.0.0.1:81/ 2>/dev/null | head -5 | grep -i "api\|player" || echo "Web UI accessible"
echo ""

echo "=========================================="
echo "Summary:"
echo "=========================================="
echo "If API commands are failing:"
echo "1. AudioControl2 API might require different format"
echo "2. Check AudioControl2 API documentation"
echo "3. Try using mpc directly as workaround"
echo "4. Check if UI uses different endpoint than /api/player/command"

