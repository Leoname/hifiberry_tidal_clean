#!/bin/bash
# Fix states() method to properly serialize MPDControl state and metadata

echo "=========================================="
echo "Fixing states() Serialization"
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

echo "2. Finding states() method..."
grep -A 50 "def states(" "$CONTROLLER" | head -60
echo ""

echo "3. Fixing states() to properly serialize MPDControl state and metadata..."
python3 << 'PYTHON_FIX'
import sys
import re

controller_file = "/opt/audiocontrol2/ac2/controller.py"

with open(controller_file, 'r') as f:
    lines = f.readlines()

fixed = False

# Find states() method
for i, line in enumerate(lines):
    if "def states(self):" in line or "def states(" in line:
        # Look for where player state is retrieved
        # The issue is likely that get_state() returns a STATE constant
        # but it's not being converted to a string properly
        
        # Find where player.get_state() is called
        for j in range(i + 1, min(i + 100, len(lines))):
            if "get_state()" in lines[j] or "player.get_state()" in lines[j]:
                # Check if state is being converted to string
                # Look for state assignment and see if it needs string conversion
                indent = len(lines[j]) - len(lines[j].lstrip())
                indent_str = ' ' * indent
                
                # Check if there's a STATE_MAP or string conversion
                # If get_state() returns a constant, we need to ensure it's converted
                # Look at the next few lines to see how state is used
                for k in range(j, min(j + 10, len(lines))):
                    if "state" in lines[k].lower() and ("=" in lines[k] or ":" in lines[k]):
                        # Check if state needs conversion
                        # STATE constants might need to be converted to strings
                        # Common pattern: state = player.get_state() then state needs to be stringified
                        if "str(" not in lines[k] and "STATE_" in "".join(lines[j:k+1]):
                            # Need to add string conversion
                            # But first, let's check what the actual issue is
                            # Maybe we need to look at how the state dict is built
                            pass
                
                # Actually, let's look for where the player dict is built
                # Find where player data is added to the players list
                for k in range(j, min(j + 30, len(lines))):
                    if '"state"' in lines[k] or "'state'" in lines[k] or "state:" in lines[k]:
                        # Found where state is set in the dict
                        # Check if it's using the raw get_state() result
                        # We might need to convert STATE constants to strings
                        current_line = lines[k]
                        if "get_state()" in current_line or "player.get_state()" in current_line:
                            # State is being set directly from get_state()
                            # Need to ensure it's converted to string
                            # But STATE constants might already be strings, so let's check the mapping
                            pass
                        break
                break
        
        # Actually, a better approach: find where the player dict/list is built
        # and ensure state and metadata are properly extracted
        for j in range(i + 1, min(i + 100, len(lines))):
            # Look for where players are iterated and state/metadata are added
            if "for" in lines[j] and "player" in lines[j] and "in" in lines[j]:
                # Found player iteration
                # Look for where state and metadata are set
                for k in range(j + 1, min(j + 50, len(lines))):
                    if '"state"' in lines[k] or "'state'" in lines[k]:
                        # Found state assignment
                        # Check if it needs fixing
                        indent = len(lines[k]) - len(lines[k].lstrip())
                        indent_str = ' ' * indent
                        
                        # The issue might be that get_state() returns a STATE constant
                        # that needs to be converted to a lowercase string
                        # Or the STATE_MAP might not be working correctly
                        
                        # Let's add explicit state conversion
                        # Check if there's already a conversion
                        if "str(" not in lines[k] and ".lower()" not in lines[k]:
                            # Try to add proper state conversion
                            # But we need to see the actual line first
                            # Let's check what comes before this line
                            if k > 0 and "get_state()" in "".join(lines[max(0,k-5):k+1]):
                                # State is from get_state(), might need conversion
                                # Replace the line with proper conversion
                                original = lines[k]
                                # Try to extract the state assignment
                                # Pattern might be: "state": player.get_state() or state = player.get_state()
                                if ":" in original:
                                    # It's a dict assignment
                                    # Find the value part and wrap it
                                    if "get_state()" in original:
                                        # Replace get_state() with str(get_state()).lower() or similar
                                        new_line = original.replace("get_state()", "str(get_state()).lower() if get_state() else 'unknown'")
                                        # But this is too simplistic - we need to preserve the structure
                                        # Actually, let's check what STATE constants map to
                                        # STATE_PLAYING should map to "playing"
                                        # The issue might be in STATE_MAP
                                        pass
                        break
                break
        
        # Better approach: Look for the actual player dict construction
        # and ensure state is properly converted from STATE constant to string
        for j in range(i + 1, min(i + 100, len(lines))):
            # Look for pattern like: {"name": ..., "state": ..., ...}
            if "{" in lines[j] and "state" in lines[j].lower():
                # Found player dict construction
                # Check if state needs conversion
                # The STATE constants might need explicit string conversion
                pass
        
        # Actually, let's take a different approach
        # Find where get_state() result is used and ensure it's converted properly
        # STATE constants are typically like STATE_PLAYING, STATE_STOPPED, etc.
        # They might need to be converted to lowercase strings: "playing", "stopped"
        
        # Look for STATE_MAP usage or state conversion
        state_map_found = False
        for j in range(i + 1, min(i + 100, len(lines))):
            if "STATE_MAP" in lines[j] or "state_map" in lines[j]:
                state_map_found = True
                break
        
        if not state_map_found:
            # STATE_MAP might not be used, need to add conversion
            # But first, let's see the actual states() implementation
            print("   Need to see actual states() implementation to fix")
            print("   Checking if we can find where state is serialized...")
        
        break

if not fixed:
    print("   ⚠ Could not automatically fix - manual inspection needed")
    print("   The issue is likely in how STATE constants are converted to strings")
    print("   in the states() method")

# Write the file (even if not fixed, to preserve any changes)
with open(controller_file, 'w') as f:
    f.writelines(lines)

print("   Note: This script needs to inspect the actual states() implementation")
print("   to determine the exact fix needed.")
PYTHON_FIX

echo ""
echo "4. The issue is likely that:"
echo "   - get_state() returns STATE constants (like STATE_PLAYING)"
echo "   - But states() needs to convert them to strings ('playing')"
echo "   - Or STATE_MAP is not being used correctly"
echo ""
echo "Next steps:"
echo "1. Run debug-states-method.sh to see the actual states() implementation"
echo "2. Check how STATE constants are converted to strings"
echo "3. Fix the serialization in states() method"
echo ""

