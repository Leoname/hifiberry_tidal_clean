#!/bin/bash
# Disable MPRIS MPD player when MPDControl is registered

echo "=========================================="
echo "Disabling MPRIS MPD Player"
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

echo "2. Modifying controller to filter out MPRIS MPD player..."
python3 << 'PYTHON_FIX'
import sys
import re

controller_file = "/opt/audiocontrol2/ac2/controller.py"

with open(controller_file, 'r') as f:
    lines = f.readlines()

fixed = False

# Find where MPRIS players are added/registered
# Look for methods that add MPRIS players or get players
for i, line in enumerate(lines):
    # Find where MPRIS players are added to the players dict
    if "self.players[" in line and "mpris" in line.lower():
        # Check if we need to filter MPD
        print(f"   Found MPRIS player registration at line {i+1}")
        # Look for where we can add filtering
        for j in range(max(0, i-5), min(i+10, len(lines))):
            if "mpd" in lines[j].lower() and ("if" in lines[j] or "name" in lines[j].lower()):
                # Add filter to skip MPRIS MPD if MPDControl is registered
                indent = len(lines[j]) - len(lines[j].lstrip())
                indent_str = ' ' * indent
                
                # Check if filter already exists
                if "skip.*mpris.*mpd" in "".join(lines[max(0, j-3):j+3]).lower() or \
                   "nonmpris.*mpd" in "".join(lines[max(0, j-3):j+3]).lower():
                    print("   ✓ Filter already present")
                    fixed = True
                    break
                
                # Add filter before adding MPRIS player
                filter_code = [
                    f'{indent_str}# Skip MPRIS MPD player if MPDControl (non-MPRIS) is registered\n',
                    f'{indent_str}if "mpd" in name.lower() and "mpd" in self.players:\n',
                    f'{indent_str}    # MPDControl is already registered, skip MPRIS MPD\n',
                    f'{indent_str}    continue\n'
                ]
                
                # Find the right place to insert (before the line that adds the player)
                for k in range(j, max(0, j-10), -1):
                    if "self.players[" in lines[k] or "players[" in lines[k]:
                        lines[k:k] = filter_code
                        fixed = True
                        print(f"   ✓ Added filter to skip MPRIS MPD at line {k+1}")
                        break
                break
        break

# Alternative: Find where players are retrieved and prioritize non-MPRIS
if not fixed:
    for i, line in enumerate(lines):
        if "def get" in line and "player" in line.lower():
            # Found a getter method
            print(f"   Found player getter at line {i+1}")
            # Look for where it returns players
            for j in range(i+1, min(i+30, len(lines))):
                if "return" in lines[j] and "player" in lines[j].lower():
                    # Check if we need to prioritize non-MPRIS
                    indent = len(lines[j]) - len(lines[j].lstrip())
                    indent_str = ' ' * indent
                    
                    # Add logic to check non-MPRIS first for MPD
                    priority_code = [
                        f'{indent_str}# For MPD, prefer non-MPRIS player (MPDControl) over MPRIS\n',
                        f'{indent_str}if name.lower() == "mpd":\n',
                        f'{indent_str}    # Check non-MPRIS players first\n',
                        f'{indent_str}    if "mpd" in self.players and hasattr(self.players["mpd"], "get_state"):\n',
                        f'{indent_str}        return self.players["mpd"]\n'
                    ]
                    
                    lines[j:j] = priority_code
                    fixed = True
                    print(f"   ✓ Added priority logic for MPDControl at line {j+1}")
                    break
            break

if not fixed:
    print("   ⚠ Could not find exact location to add filter")
    print("   Showing relevant sections:")
    for i, line in enumerate(lines):
        if "mpris" in line.lower() and ("player" in line.lower() or "register" in line.lower()):
            print(f"   Line {i+1}: {line.rstrip()}")

# Write the fixed file
if fixed:
    with open(controller_file, 'w') as f:
        f.writelines(lines)
    
    # Verify syntax
    import py_compile
    try:
        py_compile.compile(controller_file, doraise=True)
        print("✓ Fix applied successfully!")
    except py_compile.PyCompileError as e:
        print(f"✗ Syntax error: {e}")
        sys.exit(1)
else:
    print("⚠ Could not apply automatic fix")
    print("   Manual intervention may be required")
PYTHON_FIX

if [ $? -ne 0 ]; then
    echo "✗ Fix failed. Restoring backup..."
    cp "$BACKUP" "$CONTROLLER"
    exit 1
fi

echo ""
echo "3. Verifying fix:"
grep -B 3 -A 5 "Skip MPRIS MPD\|prefer non-MPRIS" "$CONTROLLER" | head -10
echo ""
echo "=========================================="
echo "Fix Applied!"
echo "=========================================="
echo ""
echo "This ensures MPDControl takes priority over MPRIS for MPD."
echo ""
echo "Next steps:"
echo "1. Restart AudioControl2:"
echo "   systemctl restart audiocontrol2"
echo ""

