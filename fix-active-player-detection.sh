#!/bin/bash
# Fix controller to correctly set activePlayer based on player state

echo "=========================================="
echo "Fixing Active Player Detection"
echo "=========================================="
echo ""

CONTROLLER="/opt/audiocontrol2/ac2/controller.py"
BACKUP="${CONTROLLER}.backup.$(date +%Y%m%d_%H%M%S)"

if [ ! -f "$CONTROLLER" ]; then
    echo "✗ Controller file not found"
    exit 1
fi

echo "1. Creating backup..."
cp "$CONTROLLER" "$BACKUP"
echo "✓ Backup: $BACKUP"
echo ""

echo "2. Finding how activePlayer is determined..."
grep -B 10 -A 20 "activePlayer\|active_player" "$CONTROLLER" | head -50
echo ""

echo "3. Finding states() method to see if it sets activePlayer..."
grep -B 5 -A 50 "def states(self):" "$CONTROLLER" | head -60
echo ""

echo "4. Fixing states() to include activePlayer based on playing state..."
python3 << 'PYTHON_FIX'
import sys

controller_file = "/opt/audiocontrol2/ac2/controller.py"

with open(controller_file, 'r') as f:
    lines = f.readlines()

fixed = False

# Find states() method
for i, line in enumerate(lines):
    if "def states(self):" in line:
        # Found states() method
        # Look for the return statement
        for j in range(i + 1, min(i + 100, len(lines))):
            if "return {" in lines[j] and '"players"' in lines[j]:
                # Found return statement
                # Check if activePlayer is already set
                if "activePlayer" in "".join(lines[i:j+1]):
                    print("   ⚠ activePlayer already set in states()")
                    # But maybe it's not working correctly
                    break
                
                # Find where the return dict is built
                # Look for the line that builds the return dict
                return_line = j
                indent = len(lines[return_line]) - len(lines[return_line].lstrip())
                indent_str = ' ' * indent
                
                # Insert activePlayer detection before return
                # Find the active player (one with state == "playing")
                active_player_code = [
                    f'{indent_str}# Determine active player (one that is playing)\n',
                    f'{indent_str}active_player = None\n',
                    f'{indent_str}for p in players:\n',
                    f'{indent_str}    if p.get("state", "").lower() == "playing":\n',
                    f'{indent_str}        active_player = p.get("name")\n',
                    f'{indent_str}        break\n',
                    f'{indent_str}# If no player is playing, check for paused\n',
                    f'{indent_str}if active_player is None:\n',
                    f'{indent_str}    for p in players:\n',
                    f'{indent_str}        if p.get("state", "").lower() == "paused":\n',
                    f'{indent_str}            active_player = p.get("name")\n',
                    f'{indent_str}            break\n'
                ]
                
                # Insert before return statement
                lines[return_line:return_line] = active_player_code
                
                # Now modify the return statement to include activePlayer
                # Find the return line again (it moved)
                for k in range(return_line + len(active_player_code), min(return_line + len(active_player_code) + 5, len(lines))):
                    if "return {" in lines[k]:
                        # Replace return statement to include activePlayer
                        original_return = lines[k]
                        if "activePlayer" not in original_return:
                            # Replace with version that includes activePlayer
                            new_return = original_return.replace(
                                '{"players":players',
                                '{"players":players, "activePlayer": active_player'
                            )
                            lines[k] = new_return
                        break
                
                fixed = True
                print(f"   ✓ Added activePlayer detection to states() at line {return_line+1}")
                break
        break

if not fixed:
    print("   ✗ Could not find states() return statement")
    sys.exit(1)

# Write the fixed file
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
PYTHON_FIX

if [ $? -ne 0 ]; then
    echo "✗ Fix failed. Restoring backup..."
    cp "$BACKUP" "$CONTROLLER"
    exit 1
fi

echo ""
echo "5. Showing fixed states() method (last 20 lines):"
grep -A 50 "def states(self):" "$CONTROLLER" | tail -25
echo ""
echo "=========================================="
echo "Fix Applied!"
echo "=========================================="
echo ""
echo "The states() method now:"
echo "1. Determines activePlayer based on playing state"
echo "2. Sets activePlayer to the player with state='playing'"
echo "3. Falls back to 'paused' state if no player is playing"
echo ""
echo "Next steps:"
echo "1. Restart AudioControl2:"
echo "   systemctl restart audiocontrol2"
echo "2. Test - MPD should now be set as activePlayer when playing"
echo ""

