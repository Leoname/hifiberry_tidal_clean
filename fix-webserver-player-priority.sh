#!/bin/bash
# Fix webserver to prioritize MPDControl over MPRIS when returning player status

echo "=========================================="
echo "Fixing Webserver Player Priority"
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

echo "2. Finding where player status is returned..."
grep -B 3 -A 10 "api/player/status\|def.*player.*status" "$WEBSERVER" | head -20
echo ""

echo "3. Modifying webserver to prioritize MPDControl..."
python3 << 'PYTHON_FIX'
import sys

webserver_file = "/opt/audiocontrol2/ac2/webserver.py"

with open(webserver_file, 'r') as f:
    lines = f.readlines()

fixed = False

# Find where player status is returned (usually in a route handler)
for i, line in enumerate(lines):
    # Look for player status endpoint or method that returns player list
    if "/api/player/status" in line or "def.*player.*status" in line or \
       ("players" in line.lower() and "return" in lines[max(0, i-5):i+5]):
        # Found potential location
        print(f"   Found player status handler around line {i+1}")
        
        # Look for where players are iterated or returned
        for j in range(i, min(i+50, len(lines))):
            # Find where players list is built or returned
            if "players" in lines[j].lower() and ("=" in lines[j] or "return" in lines[j] or "[" in lines[j]):
                # Check if we need to filter/prioritize
                indent = len(lines[j]) - len(lines[j].lstrip())
                indent_str = ' ' * indent
                
                # Look for where we can add filtering logic
                # We want to filter out MPRIS MPD player if MPDControl exists
                for k in range(j, min(j+20, len(lines))):
                    if "return" in lines[k] and "players" in lines[k].lower():
                        # Add filtering before return
                        filter_code = [
                            f'{indent_str}# Filter out MPRIS MPD player if MPDControl (non-MPRIS) exists\n',
                            f'{indent_str}# This ensures MPDControl takes priority\n',
                            f'{indent_str}if isinstance(players, list):\n',
                            f'{indent_str}    # Find MPD players\n',
                            f'{indent_str}    mpd_players = [p for p in players if p.get("name") == "mpd"]\n',
                            f'{indent_str}    if len(mpd_players) > 1:\n',
                            f'{indent_str}        # Multiple MPD players - keep only non-MPRIS (MPDControl)\n',
                            f'{indent_str}        # MPDControl has more supported commands (11 vs 5)\n',
                            f'{indent_str}        mpd_control = [p for p in mpd_players if len(p.get("supported_commands", [])) > 5]\n',
                            f'{indent_str}        if mpd_control:\n',
                            f'{indent_str}            # Remove all MPD players and add only MPDControl\n',
                            f'{indent_str}            players = [p for p in players if p.get("name") != "mpd"]\n',
                            f'{indent_str}            players.extend(mpd_control)\n'
                        ]
                        
                        lines[k:k] = filter_code
                        fixed = True
                        print(f"   ✓ Added filtering logic at line {k+1}")
                        break
                break
        break

if not fixed:
    print("   ⚠ Could not find exact location to add filter")
    print("   Showing relevant sections:")
    for i, line in enumerate(lines):
        if "player" in line.lower() and ("status" in line.lower() or "api" in line.lower()):
            print(f"   Line {i+1}: {line.rstrip()}")

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
else:
    print("⚠ Could not apply automatic fix")
    print("   Manual intervention may be required")
PYTHON_FIX

if [ $? -ne 0 ]; then
    echo "✗ Fix failed. Restoring backup..."
    cp "$BACKUP" "$WEBSERVER"
    exit 1
fi

echo ""
echo "4. Verifying fix:"
grep -B 2 -A 8 "Filter out MPRIS MPD player" "$WEBSERVER" | head -12
echo ""
echo "=========================================="
echo "Fix Applied!"
echo "=========================================="
echo ""
echo "This ensures only MPDControl (not MPRIS) is returned in player status API."
echo ""
echo "Next steps:"
echo "1. Restart AudioControl2:"
echo "   systemctl restart audiocontrol2"
echo ""

