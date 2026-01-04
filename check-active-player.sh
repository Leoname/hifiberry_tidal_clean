#!/bin/bash
# Quick check of activePlayer in API response

echo "=========================================="
echo "Checking Active Player Status"
echo "=========================================="
echo ""

echo "1. MPD Actual State:"
mpc status 2>/dev/null | head -1
echo ""

echo "2. AudioControl2 API - Full Response:"
curl -s http://localhost:81/api/player/status | python3 -c "
import sys, json
data = json.load(sys.stdin)
print(f'Active Player: {data.get(\"activePlayer\", \"None\")}')
print('')
print('All Players:')
for p in data.get('players', []):
    name = p.get('name', 'unknown')
    state = p.get('state', 'unknown')
    is_active = ' ⭐ ACTIVE' if name == data.get('activePlayer') else ''
    print(f'  - {name}: state={state}{is_active}')
"
echo ""

echo "3. MPD Player Details:"
curl -s http://localhost:81/api/player/status | python3 -c "
import sys, json
data = json.load(sys.stdin)
mpd_players = [p for p in data.get('players', []) if p.get('name') == 'mpd']
if mpd_players:
    p = mpd_players[0]
    print(f'  Name: {p.get(\"name\")}')
    print(f'  State: {p.get(\"state\")}')
    print(f'  Artist: {p.get(\"artist\")}')
    print(f'  Title: {p.get(\"title\")}')
    print(f'  Is Active Player: {p.get(\"name\") == data.get(\"activePlayer\")}')
    print(f'  Active Player Value: {data.get(\"activePlayer\", \"None\")}')
else:
    print('  No MPD player found')
"
echo ""

echo "=========================================="
echo "Summary"
echo "=========================================="
echo "If activePlayer is not 'mpd' when MPD is playing:"
echo "1. The activePlayer detection logic may need adjustment"
echo "2. Check if state is exactly 'playing' (case-sensitive)"
echo "3. Restart AudioControl2 if fixes were just applied"
echo ""

