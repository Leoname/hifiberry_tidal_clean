#!/bin/bash
# Ensure MPDControl is registered in AudioControl2 controller

echo "=========================================="
echo "Registering MPDControl in AudioControl2"
echo "=========================================="
echo ""

CONTROLLER="/opt/audiocontrol2/audiocontrol2.py"
BACKUP="${CONTROLLER}.backup.$(date +%Y%m%d_%H%M%S)"

# Check if file exists
if [ ! -f "$CONTROLLER" ]; then
    echo "✗ audiocontrol2.py not found"
    exit 1
fi

# Create backup
echo "1. Creating backup..."
cp "$CONTROLLER" "$BACKUP"
echo "✓ Backup: $BACKUP"
echo ""

echo "2. Checking current player registration..."
grep -B 5 -A 15 "MPDControl\|register.*mpd" "$CONTROLLER" | head -30
echo ""

echo "3. Ensuring MPDControl is registered..."
python3 << 'PYTHON_FIX'
import sys

controller_file = "/opt/audiocontrol2/audiocontrol2.py"

with open(controller_file, 'r') as f:
    lines = f.readlines()

# Check if MPDControl is imported
mpdcontrol_imported = False
for i, line in enumerate(lines):
    if "from ac2.players.mpdcontrol import MPDControl" in line or "import MPDControl" in line:
        mpdcontrol_imported = True
        print(f"   ✓ MPDControl is imported at line {i+1}")
        break

if not mpdcontrol_imported:
    print("   ⚠ MPDControl is not imported")
    # Find where other players are imported
    for i, line in enumerate(lines):
        if "from ac2.players" in line:
            print(f"   Found player import at line {i+1}: {line.strip()}")
            # Add MPDControl import after this
            if "MPDControl" not in "".join(lines[max(0, i-5):i+5]):
                lines.insert(i + 1, "from ac2.players.mpdcontrol import MPDControl\n")
                print(f"   ✓ Added MPDControl import at line {i+2}")
                mpdcontrol_imported = True
                break

# Check if MPDControl is instantiated and registered
mpdcontrol_registered = False
for i, line in enumerate(lines):
    if "MPDControl()" in line or "MPDControl(" in line:
        print(f"   ✓ MPDControl is instantiated at line {i+1}")
        # Check if it's registered
        for j in range(i, min(i+10, len(lines))):
            if "register" in lines[j] and "mpd" in lines[j].lower():
                mpdcontrol_registered = True
                print(f"   ✓ MPDControl is registered at line {j+1}")
                break
        if not mpdcontrol_registered:
            print(f"   ⚠ MPDControl is instantiated but not registered")
        break

if not mpdcontrol_registered:
    # Find where players are registered
    for i, line in enumerate(lines):
        if "register" in line.lower() and ("player" in line.lower() or "control" in line.lower()):
            print(f"   Found registration at line {i+1}: {line.strip()}")
            # Check if MPDControl registration is nearby
            found_mpd = False
            for j in range(max(0, i-5), min(i+10, len(lines))):
                if "MPDControl" in lines[j]:
                    found_mpd = True
                    break
            if not found_mpd:
                # Add MPDControl registration
                indent = len(line) - len(line.lstrip())
                indent_str = ' ' * indent
                # Try to find the pattern
                if "controller.register" in line:
                    lines.insert(i + 1, f'{indent_str}controller.register(MPDControl(), "mpd")\n')
                    print(f"   ✓ Added MPDControl registration at line {i+2}")
                    mpdcontrol_registered = True
                    break

# Write the fixed file
if mpdcontrol_imported or mpdcontrol_registered:
    with open(controller_file, 'w') as f:
        f.writelines(lines)
    print("✓ Fix applied!")
else:
    print("⚠ MPDControl may already be registered, or registration pattern is different")
    print("   Showing relevant sections:")
    for i, line in enumerate(lines):
        if "mpd" in line.lower() or "MPDControl" in line:
            print(f"   Line {i+1}: {line.rstrip()}")
PYTHON_FIX

if [ $? -ne 0 ]; then
    echo "✗ Fix failed. Restoring backup..."
    cp "$BACKUP" "$CONTROLLER"
    exit 1
fi

echo ""
echo "4. Verifying registration:"
grep -B 2 -A 5 "MPDControl" "$CONTROLLER" | head -15
echo ""
echo "=========================================="
echo "Fix Applied!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Restart AudioControl2:"
echo "   systemctl restart audiocontrol2"
echo ""
echo "2. MPDControl should now be registered alongside MPRIS"
echo ""

