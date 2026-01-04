#!/bin/bash
# Fix AudioControl2 to prioritize MPDControl over MPRIS for MPD

echo "=========================================="
echo "Fixing AudioControl2 Player Selection"
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

echo "2. Checking how players are registered..."
grep -B 5 -A 15 "MPDControl\|mpris" "$CONTROLLER" | head -30
echo ""

echo "3. The issue: AudioControl2 has both MPDControl and MPRIS MPD players."
echo "   MPDControl returns correct data, but AudioControl2 might be using MPRIS."
echo "   We need to either:"
echo "   a) Disable MPRIS for MPD"
echo "   b) Ensure MPDControl is checked first"
echo "   c) Force AudioControl2 to refresh player state/metadata"
echo ""

echo "4. Checking if we can modify player registration order..."
python3 << 'PYTHON_CHECK'
import sys

controller_file = "/opt/audiocontrol2/ac2/controller.py"

with open(controller_file, 'r') as f:
    lines = f.readlines()

# Find where MPDControl is instantiated
mpdcontrol_found = False
mpris_found = False

for i, line in enumerate(lines):
    if "MPDControl()" in line or "MPDControl(" in line:
        print(f"   Found MPDControl instantiation at line {i+1}")
        mpdcontrol_found = True
        # Show context
        for j in range(max(0, i-3), min(len(lines), i+5)):
            print(f"      {j+1}: {lines[j].rstrip()}")
    
    if "MPRIS()" in line or "MPRIS(" in line:
        print(f"   Found MPRIS instantiation at line {i+1}")
        mpris_found = True
        # Show context
        for j in range(max(0, i-3), min(len(lines), i+5)):
            print(f"      {j+1}: {lines[j].rstrip()}")

if not mpdcontrol_found:
    print("   ⚠ MPDControl not found in controller")
if not mpris_found:
    print("   ⚠ MPRIS not found in controller")
PYTHON_CHECK
echo ""

echo "5. Since MPDControl works correctly, the issue is AudioControl2's player selection."
echo "   The best fix is to ensure AudioControl2 refreshes player state/metadata more frequently,"
echo "   or to disable MPRIS for MPD if possible."
echo ""
echo "   For now, try restarting AudioControl2 to force it to re-initialize players:"
echo "   systemctl restart audiocontrol2"
echo ""
echo "   If that doesn't work, we may need to modify AudioControl2's player refresh logic."
echo ""

