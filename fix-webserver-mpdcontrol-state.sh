#!/bin/bash
# Fix webserver to ensure MPDControl state is retrieved correctly

echo "=========================================="
echo "Fixing Webserver MPDControl State"
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

echo "2. Reading playerstatus_handler to understand structure..."
grep -A 100 "def playerstatus_handler" "$WEBSERVER" | head -120 > /tmp/playerstatus_method.txt
cat /tmp/playerstatus_method.txt
echo ""

echo "3. The issue: MPDControl shows 'unknown' state in API but returns 'playing' directly."
echo "   This suggests the webserver is calling get_state() on wrong player instance."
echo ""
echo "   We need to ensure:"
echo "   1. MPDControl is used (not MPRIS) when getting state"
echo "   2. MPRIS MPD player is filtered out from response"
echo ""

echo "4. Creating targeted fix..."
python3 << 'PYTHON_FIX'
import sys
import re

webserver_file = "/opt/audiocontrol2/ac2/webserver.py"

with open(webserver_file, 'r') as f:
    content = f.read()

# Find playerstatus_handler method
match = re.search(r'def playerstatus_handler\(self\):.*?(?=\n    def |\Z)', content, re.DOTALL)
if not match:
    print("✗ Could not find playerstatus_handler method")
    sys.exit(1)

method_content = match.group(0)
print(f"   Found playerstatus_handler method ({len(method_content)} chars)")

# Check if filtering is already present
if "Filter out MPRIS MPD" in method_content or "mpd_players" in method_content:
    print("   ⚠ Filtering logic may already be present")
    
# The method content shows the structure, but we need to modify the actual file
# Let's read the file as lines to make precise edits
with open(webserver_file, 'r') as f:
    lines = f.readlines()

# Find the method
method_start = -1
for i, line in enumerate(lines):
    if "def playerstatus_handler(self):" in line:
        method_start = i
        break

if method_start == -1:
    print("✗ Could not find method start")
    sys.exit(1)

# Find where players are built/returned
# Look for patterns like: players = [...] or return {...}
fixed = False
for i in range(method_start, min(method_start + 150, len(lines))):
    # Look for return statement with players or json
    if "return" in lines[i] and ("json" in lines[i].lower() or "players" in lines[i].lower() or "{" in lines[i]):
        # Check if it's returning player data
        # Add filter before return
        indent = len(lines[i]) - len(lines[i].lstrip())
        indent_str = ' ' * indent
        
        # Look for where 'players' variable is used/defined before return
        for j in range(i, max(i-50, method_start), -1):
            if "players" in lines[j].lower() and ("=" in lines[j] or "[" in lines[j] or "{" in lines[j] or "json" in lines[j].lower()):
                # Found where players is used - add filter before return
                filter_code = [
                    f'{indent_str}# Filter: Keep only MPDControl, remove MPRIS MPD player\n',
                    f'{indent_str}if "players" in locals() or "players" in globals():\n',
                    f'{indent_str}    try:\n',
                    f'{indent_str}        if isinstance(players, list):\n',
                    f'{indent_str}            mpd_players = [p for p in players if p.get("name") == "mpd"]\n',
                    f'{indent_str}            if len(mpd_players) > 1:\n',
                    f'{indent_str}                # Keep MPDControl (11 commands), remove MPRIS (5 commands)\n',
                    f'{indent_str}                mpd_control = [p for p in mpd_players if len(p.get("supported_commands", [])) > 5]\n',
                    f'{indent_str}                if mpd_control:\n',
                    f'{indent_str}                    players = [p for p in players if p.get("name") != "mpd"]\n',
                    f'{indent_str}                    players.extend(mpd_control)\n',
                    f'{indent_str}    except:\n',
                    f'{indent_str}        pass  # If filtering fails, continue with original players\n'
                ]
                
                lines[i:i] = filter_code
                fixed = True
                print(f"   ✓ Added filtering logic at line {i+1}")
                break
        break

if not fixed:
    print("   ⚠ Could not automatically add filter")
    print("   Manual inspection needed")

# Write the fixed file
if fixed:
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
echo "5. Verifying fix:"
grep -B 2 -A 10 "Filter: Keep only MPDControl" "$WEBSERVER" | head -15
echo ""
echo "=========================================="
echo "Fix Applied!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Restart AudioControl2:"
echo "   systemctl restart audiocontrol2"
echo ""

