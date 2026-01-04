#!/bin/bash
# Ensure MPDControl takes priority over MPRIS for MPD

echo "=========================================="
echo "Fixing MPDControl Priority Over MPRIS"
echo "=========================================="
echo ""

CONTROLLER="/opt/audiocontrol2/ac2/controller.py"
BACKUP="${CONTROLLER}.backup.$(date +%Y%m%d_%H%M%S)"

# Check if file exists
if [ ! -f "$CONTROLLER" ]; then
    echo "✗ Controller file not found"
    exit 1
fi

# Create backup
echo "1. Creating backup..."
cp "$CONTROLLER" "$BACKUP"
echo "✓ Backup: $BACKUP"
echo ""

echo "2. Checking how players are selected..."
grep -B 5 -A 15 "get.*player\|players\[" "$CONTROLLER" | grep -A 10 "mpd\|MPD" | head -20
echo ""

echo "3. The issue: MPRIS MPD player is taking priority over MPDControl."
echo "   We need to either:"
echo "   a) Disable MPRIS for MPD specifically"
echo "   b) Ensure non-MPRIS players take priority over MPRIS"
echo "   c) Filter out MPRIS MPD player"
echo ""

echo "4. Checking if we can filter MPRIS MPD player..."
python3 << 'PYTHON_CHECK'
import sys

controller_file = "/opt/audiocontrol2/ac2/controller.py"

with open(controller_file, 'r') as f:
    lines = f.readlines()

# Find where MPRIS connects and registers players
for i, line in enumerate(lines):
    if "connect_dbus" in line or "mpris.connect" in line:
        print(f"   Found MPRIS connection at line {i+1}")
        # Show context
        for j in range(max(0, i-3), min(len(lines), i+10)):
            print(f"      {j+1}: {lines[j].rstrip()}")
        break

# Find where players are retrieved/selected
for i, line in enumerate(lines):
    if "def get" in line and "player" in line.lower():
        print(f"   Found player getter at line {i+1}: {line.strip()}")
        # Show context
        for j in range(i, min(i+15, len(lines))):
            if lines[j].strip() and not lines[j].strip().startswith('#'):
                print(f"      {j+1}: {lines[j].rstrip()}")
                if j > i + 10:
                    break
        break
PYTHON_CHECK
echo ""

echo "5. Since MPRIS is needed for other players, the best solution is to"
echo "   ensure MPDControl (non-MPRIS) takes priority when both exist."
echo "   This may require modifying AudioControl2's player selection logic."
echo ""
echo "   For now, try checking AudioControl2 logs for player selection:"
echo "   journalctl -u audiocontrol2 | grep -i 'mpd\|player.*select'"
echo ""

