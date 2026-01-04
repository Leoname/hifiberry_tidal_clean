#!/bin/bash
# Fix webserver to filter out MPRIS MPD player from API response

echo "=========================================="
echo "Fixing Webserver to Filter MPRIS MPD"
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

echo "2. Finding playerstatus_handler method..."
grep -A 50 "def playerstatus_handler" "$WEBSERVER" | head -60
echo ""

echo "3. Modifying playerstatus_handler to filter MPRIS MPD..."
python3 << 'PYTHON_FIX'
import sys

webserver_file = "/opt/audiocontrol2/ac2/webserver.py"

with open(webserver_file, 'r') as f:
    lines = f.readlines()

fixed = False

# Find playerstatus_handler method
for i, line in enumerate(lines):
    if "def playerstatus_handler(self):" in line:
        print(f"   Found playerstatus_handler at line {i+1}")
        
        # Look for where players list is built or returned
        for j in range(i + 1, min(i + 100, len(lines))):
            # Look for where players are collected or returned
            if "players" in lines[j].lower() and ("=" in lines[j] or "return" in lines[j] or "json" in lines[j].lower()):
                # Check if this is where we build the response
                indent = len(lines[j]) - len(lines[j].lstrip())
                indent_str = ' ' * indent
                
                # Look for return statement with players
                for k in range(j, min(j + 20, len(lines))):
                    if "return" in lines[k] and ("json" in lines[k].lower() or "players" in lines[k].lower()):
                        # Add filtering before return
                        # Find the line that builds the players list or dict
                        for m in range(k, max(k-30, i), -1):
                            if "players" in lines[m].lower() and ("=" in lines[m] or "[" in lines[m] or "{" in lines[m]):
                                # Add filter after players list is built
                                filter_code = [
                                    f'{indent_str}# Filter out MPRIS MPD player if MPDControl exists\n',
                                    f'{indent_str}# MPDControl has 11 commands, MPRIS has 5 commands\n',
                                    f'{indent_str}if isinstance(players, list):\n',
                                    f'{indent_str}    mpd_players = [p for p in players if p.get("name") == "mpd"]\n',
                                    f'{indent_str}    if len(mpd_players) > 1:\n',
                                    f'{indent_str}        # Keep only MPDControl (has more commands)\n',
                                    f'{indent_str}        mpd_control = [p for p in mpd_players if len(p.get("supported_commands", [])) > 5]\n',
                                    f'{indent_str}        if mpd_control:\n',
                                    f'{indent_str}            # Remove all MPD players, add only MPDControl\n',
                                    f'{indent_str}            players = [p for p in players if p.get("name") != "mpd"]\n',
                                    f'{indent_str}            players.extend(mpd_control)\n'
                                ]
                                
                                # Insert before the return statement
                                lines[k:k] = filter_code
                                fixed = True
                                print(f"   ✓ Added filtering logic at line {k+1}")
                                break
                        break
                break
        break

if not fixed:
    print("   ⚠ Could not find exact location, trying alternative approach...")
    # Try to find where players dict/list is returned
    for i, line in enumerate(lines):
        if "def playerstatus_handler(self):" in line:
            # Look for return statement in this method
            for j in range(i + 1, min(i + 100, len(lines))):
                if "return" in lines[j] and j - i < 100:  # Within method
                    # Check if it returns players data
                    if "json" in lines[j].lower() or "players" in lines[j].lower() or "{" in lines[j]:
                        # Add filter before return
                        indent = len(lines[j]) - len(lines[j].lstrip())
                        indent_str = ' ' * indent
                        
                        # Look backwards to find where players is defined
                        for k in range(j, max(j-30, i), -1):
                            if "players" in lines[k].lower() and ("=" in lines[k] or "[" in lines[k]):
                                # Add filter after players is built
                                filter_code = [
                                    f'{indent_str}# Filter out MPRIS MPD player, keep only MPDControl\n',
                                    f'{indent_str}if isinstance(players, list):\n',
                                    f'{indent_str}    mpd_players = [p for p in players if p.get("name") == "mpd"]\n',
                                    f'{indent_str}    if len(mpd_players) > 1:\n',
                                    f'{indent_str}        mpd_control = [p for p in mpd_players if len(p.get("supported_commands", [])) > 5]\n',
                                    f'{indent_str}        if mpd_control:\n',
                                    f'{indent_str}            players = [p for p in players if p.get("name") != "mpd"]\n',
                                    f'{indent_str}            players.extend(mpd_control)\n'
                                ]
                                
                                lines[j:j] = filter_code
                                fixed = True
                                print(f"   ✓ Added filtering logic (alternative) at line {j+1}")
                                break
                        break
            break

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
    print("   Need to manually inspect playerstatus_handler method")
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
echo "This filters out MPRIS MPD player from API response."
echo ""
echo "Next steps:"
echo "1. Restart AudioControl2:"
echo "   systemctl restart audiocontrol2"
echo ""

