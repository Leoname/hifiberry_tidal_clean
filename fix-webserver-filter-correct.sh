#!/bin/bash
# Fix webserver to correctly filter MPRIS MPD player from states() response

echo "=========================================="
echo "Fixing Webserver Filter (Correct)"
echo "=========================================="
echo ""

WEBSERVER="/opt/audiocontrol2/ac2/webserver.py"
BACKUP="${WEBSERVER}.backup.$(date +%Y%m%d_%H%M%S)"

# Check if file exists
if [ ! -f "$WEBSERVER" ]; then
    echo "✗ Webserver file not found"
    exit 1
fi

# Create backup
echo "1. Creating backup..."
cp "$WEBSERVER" "$BACKUP"
echo "✓ Backup: $BACKUP"
echo ""

echo "2. Fixing playerstatus_handler to filter MPRIS MPD..."
python3 << 'PYTHON_FIX'
import sys

webserver_file = "/opt/audiocontrol2/ac2/webserver.py"

with open(webserver_file, 'r') as f:
    lines = f.readlines()

# Step 1: Remove any old incorrect filter code FIRST (before adding new code)
# Look backwards through the file to find and remove old filter blocks
removed_old_filter = False
i = len(lines) - 1
while i >= 0:
    line = lines[i]
    # Look for old incorrect filter patterns
    if "Filter: Keep only MPDControl" in line or ("if \"players\" in locals()" in line and i > 0 and "Filter" in lines[i-1]):
        # Found start of old filter, find its end
        base_indent = len(line) - len(line.lstrip())
        filter_start = i
        filter_end = i + 1
        
        # Look for the end of this block
        for j in range(i + 1, min(i + 20, len(lines))):
            if lines[j].strip() and not lines[j].strip().startswith('#'):
                line_indent = len(lines[j]) - len(lines[j].lstrip())
                # If we hit a line at same or less indentation, it's the end
                if line_indent <= base_indent:
                    filter_end = j
                    break
        
        if filter_end > filter_start:
            print(f"   ✓ Removing old incorrect filter at lines {filter_start+1}-{filter_end}")
            del lines[filter_start:filter_end]
            removed_old_filter = True
            i = filter_start - 1  # Continue from before the removed block
            continue
    i -= 1

fixed = False

# Step 2: Find playerstatus_handler method and add new filter code
for i, line in enumerate(lines):
    if "def playerstatus_handler(self):" in line:
        # Find where states() is called and the return statement
        states_line = -1
        return_line = -1
        for j in range(i + 1, min(i + 30, len(lines))):
            if ("states()" in lines[j] or "self.player_control.states()" in lines[j]) and states_line == -1:
                states_line = j
            if "return" in lines[j] and (states_line != -1 or "states" in lines[j]):
                # Make sure this return is part of playerstatus_handler (not next method)
                if j < i + 30:  # Within reasonable distance
                    return_line = j
                    break
        
        if states_line != -1 and return_line != -1:
            # Get the indentation from the return line
            indent = len(lines[return_line]) - len(lines[return_line].lstrip())
            indent_str = ' ' * indent
            
            # Check if states is already assigned to a variable
            if "states = " in lines[states_line]:
                # States is already assigned, just replace the return with filter + return
                new_code = [
                    f'{indent_str}# Filter out MPRIS MPD player, keep only MPDControl\n',
                    f'{indent_str}if "players" in states and isinstance(states["players"], list):\n',
                    f'{indent_str}    mpd_players = [p for p in states["players"] if p.get("name") == "mpd"]\n',
                    f'{indent_str}    if len(mpd_players) > 1:\n',
                    f'{indent_str}        # Keep MPDControl (11 commands), remove MPRIS (5 commands)\n',
                    f'{indent_str}        mpd_control = [p for p in mpd_players if len(p.get("supported_commands", [])) > 5]\n',
                    f'{indent_str}        if mpd_control:\n',
                    f'{indent_str}            # Remove all MPD players, add only MPDControl\n',
                    f'{indent_str}            states["players"] = [p for p in states["players"] if p.get("name") != "mpd"]\n',
                    f'{indent_str}            states["players"].extend(mpd_control)\n',
                    f'{indent_str}return states\n'
                ]
            else:
                # states() is called directly in return, need to assign it first
                new_code = [
                    f'{indent_str}states = self.player_control.states()\n',
                    f'{indent_str}# Filter out MPRIS MPD player, keep only MPDControl\n',
                    f'{indent_str}if "players" in states and isinstance(states["players"], list):\n',
                    f'{indent_str}    mpd_players = [p for p in states["players"] if p.get("name") == "mpd"]\n',
                    f'{indent_str}    if len(mpd_players) > 1:\n',
                    f'{indent_str}        # Keep MPDControl (11 commands), remove MPRIS (5 commands)\n',
                    f'{indent_str}        mpd_control = [p for p in mpd_players if len(p.get("supported_commands", [])) > 5]\n',
                    f'{indent_str}        if mpd_control:\n',
                    f'{indent_str}            # Remove all MPD players, add only MPDControl\n',
                    f'{indent_str}            states["players"] = [p for p in states["players"] if p.get("name") != "mpd"]\n',
                    f'{indent_str}            states["players"].extend(mpd_control)\n',
                    f'{indent_str}return states\n'
                ]
            
            # Replace the return line with new code
            lines[return_line:return_line+1] = new_code
            fixed = True
            print(f"   ✓ Replaced return statement with filtering logic at line {return_line+1}")
            break

if not fixed:
    print("   ✗ Could not find playerstatus_handler return statement")
    sys.exit(1)

# Write the fixed file
with open(webserver_file, 'w') as f:
    f.writelines(lines)

# Verify syntax
import py_compile
try:
    py_compile.compile(webserver_file, doraise=True)
    print("✓ Fix applied successfully!")
except py_compile.PyCompileError as e:
    print(f"✗ Syntax error: {e}")
    sys.exit(1)
PYTHON_FIX

if [ $? -ne 0 ]; then
    echo "✗ Fix failed. Restoring backup..."
    cp "$BACKUP" "$WEBSERVER"
    exit 1
fi

echo ""
echo "3. Verifying fix:"
grep -A 15 "def playerstatus_handler" "$WEBSERVER" | head -20
echo ""
echo "=========================================="
echo "Fix Applied!"
echo "=========================================="
echo ""
echo "This filters MPRIS MPD player from states() response."
echo ""
echo "Next steps:"
echo "1. Restart AudioControl2:"
echo "   systemctl restart audiocontrol2"
echo ""

