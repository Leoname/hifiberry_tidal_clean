#!/bin/bash
# Force AudioControl2 to set MPD as active player

echo "=========================================="
echo "Forcing MPD as Active Player in AudioControl2"
echo "=========================================="
echo ""

# 1. Check current state
echo "1. Current State:"
mpc status 2>/dev/null | head -3
echo ""
curl -s http://127.0.0.1:81/api/player/status 2>/dev/null | python3 -c "
import sys, json
d = json.load(sys.stdin)
print('Active Player:', d.get('activePlayer'))
for p in d.get('players', []):
    if p['name'] == 'mpd':
        print(f\"MPD: {p.get('state')}\")
" || echo "Could not query"
echo ""

# 2. Try to send a command to MPD via AudioControl2 API
# This might trigger it to become active
echo "2. Sending test command to MPD via AudioControl2..."
curl -s -X POST http://127.0.0.1:81/api/player/command \
  -H "Content-Type: application/json" \
  -d '{"player":"mpd","command":"status"}' 2>/dev/null || echo "Command failed"
echo ""

# 3. Try play/pause toggle to force state update
echo "3. Toggling play/pause to force state refresh..."
curl -s -X POST http://127.0.0.1:81/api/player/command \
  -H "Content-Type: application/json" \
  -d '{"player":"mpd","command":"playpause"}' 2>/dev/null || echo "Command failed"
sleep 1
curl -s -X POST http://127.0.0.1:81/api/player/command \
  -H "Content-Type: application/json" \
  -d '{"player":"mpd","command":"playpause"}' 2>/dev/null || echo "Command failed"
sleep 2
echo ""

# 4. Check state after commands
echo "4. State After Commands:"
curl -s http://127.0.0.1:81/api/player/status 2>/dev/null | python3 -c "
import sys, json
d = json.load(sys.stdin)
active = d.get('activePlayer')
print('Active Player:', active if active else 'None')
for p in d.get('players', []):
    if p['name'] == 'mpd':
        print(f\"MPD: {p.get('state')}\")
        if active == 'mpd':
            print('✓ MPD is now the active player!')
        elif p.get('state') == 'playing':
            print('⚠️  MPD is playing but not set as active player')
            print('   This is an AudioControl2 internal issue')
" || echo "Could not query"
echo ""

# 5. If still not active, check AudioControl2 logic
echo "5. Checking AudioControl2 Configuration:"
if [ -f "/opt/audiocontrol2/audiocontrol2.py" ]; then
    echo "Checking how AudioControl2 determines active player..."
    grep -A 10 "activePlayer\|get_active_player\|determine.*active" /opt/audiocontrol2/audiocontrol2.py 2>/dev/null | head -20 || echo "Could not find active player logic"
else
    echo "AudioControl2 main file not found"
fi
echo ""

echo "=========================================="
echo "Summary:"
echo "=========================================="
echo "If MPD is playing but not set as active:"
echo "1. This is likely an AudioControl2 internal logic issue"
echo "2. AudioControl2 may require a player to explicitly claim 'active' status"
echo "3. Try restarting AudioControl2 while MPD is playing:"
echo "   systemctl restart audiocontrol2"
echo "4. Check AudioControl2 source code for active player selection logic"
echo ""
echo "Workaround: Try using the UI controls anyway - they might work"
echo "even if activePlayer shows as None, as long as MPD state is 'playing'"

