#!/bin/bash
# Fix state_table to refresh from player.get_state() and get_meta() instead of using stale cache

echo "=========================================="
echo "Fixing state_table Refresh"
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

echo "2. Finding states() method and state_table usage..."
grep -B 10 -A 20 "def states(" "$CONTROLLER" | head -35
echo ""

echo "3. Finding where state_table is updated..."
grep -B 5 -A 10 "state_table" "$CONTROLLER" | head -40
echo ""

echo "4. Fixing states() to refresh state_table from player instances..."
python3 << 'PYTHON_FIX'
import sys
import re

controller_file = "/opt/audiocontrol2/ac2/controller.py"

with open(controller_file, 'r') as f:
    lines = f.readlines()

fixed = False

# Find states() method
for i, line in enumerate(lines):
    if "def states(self):" in line:
        # Found states() method
        # Look for the state_table iteration
        for j in range(i + 1, min(i + 30, len(lines))):
            if "for p in self.state_table:" in lines[j] or "for p in self.state_table" in lines[j]:
                # Found the loop that reads from state_table
                # We need to modify it to call get_state() and get_meta() on the actual player
                indent = len(lines[j]) - len(lines[j].lstrip())
                indent_str = ' ' * indent
                
                # Check if we're already calling get_state()/get_meta()
                # Look at the next few lines
                already_fixed = False
                for k in range(j, min(j + 15, len(lines))):
                    if "get_state()" in lines[k] or "get_meta()" in lines[k]:
                        already_fixed = True
                        print("   ⚠ states() already calls get_state()/get_meta()")
                        break
                
                if not already_fixed:
                    # We need to modify the loop to get fresh state/metadata
                    # The current code is:
                    #   for p in self.state_table:
                    #       player = {}
                    #       player["name"] = self.playername(p)
                    #       player["state"] = self.state_table[p].state
                    #       player["artist"] = self.state_table[p].metadata.artist
                    #       player["title"] = self.state_table[p].metadata.title
                    #       ...
                    #
                    # We need to change it to:
                    #   for p in self.state_table:
                    #       player = {}
                    #       player["name"] = self.playername(p)
                    #       # Get fresh state from player instance
                    #       if p in self.players:
                    #           try:
                    #               player["state"] = self.players[p].get_state()
                    #               meta = self.players[p].get_meta()
                    #               if meta:
                    #                   player["artist"] = meta.artist if hasattr(meta, 'artist') else None
                    #                   player["title"] = meta.title if hasattr(meta, 'title') else None
                    #               else:
                    #                   player["artist"] = None
                    #                   player["title"] = None
                    #           except:
                    #               # Fallback to state_table if player call fails
                    #               player["state"] = self.state_table[p].state
                    #               player["artist"] = self.state_table[p].metadata.artist
                    #               player["title"] = self.state_table[p].metadata.title
                    #       else:
                    #           # Fallback to state_table
                    #           player["state"] = self.state_table[p].state
                    #           player["artist"] = self.state_table[p].metadata.artist
                    #           player["title"] = self.state_table[p].metadata.title
                    #       ...
                    
                    # Find where state, artist, title are set
                    state_line = -1
                    artist_line = -1
                    title_line = -1
                    
                    for k in range(j + 1, min(j + 20, len(lines))):
                        if 'player["state"]' in lines[k] or "player['state']" in lines[k]:
                            state_line = k
                        if 'player["artist"]' in lines[k] or "player['artist']" in lines[k]:
                            artist_line = k
                        if 'player["title"]' in lines[k] or "player['title']" in lines[k]:
                            title_line = k
                        if "return" in lines[k] or "def " in lines[k]:
                            break
                    
                    if state_line != -1 and artist_line != -1 and title_line != -1:
                        # Replace the state/artist/title assignments with fresh calls
                        # First, insert the refresh logic before state_line
                        refresh_code = [
                            f'{indent_str}    # Get fresh state and metadata from player instance\n',
                            f'{indent_str}    if p in self.players:\n',
                            f'{indent_str}        try:\n',
                            f'{indent_str}            fresh_state = self.players[p].get_state()\n',
                            f'{indent_str}            fresh_meta = self.players[p].get_meta()\n',
                            f'{indent_str}            # Convert STATE constant to lowercase string if needed\n',
                            f'{indent_str}            if isinstance(fresh_state, str):\n',
                            f'{indent_str}                player["state"] = fresh_state.lower() if fresh_state else "unknown"\n',
                            f'{indent_str}            else:\n',
                            f'{indent_str}                # STATE constant, convert to string\n',
                            f'{indent_str}                player["state"] = str(fresh_state).lower() if fresh_state else "unknown"\n',
                            f'{indent_str}            if fresh_meta:\n',
                            f'{indent_str}                player["artist"] = fresh_meta.artist if hasattr(fresh_meta, "artist") and fresh_meta.artist else None\n',
                            f'{indent_str}                player["title"] = fresh_meta.title if hasattr(fresh_meta, "title") and fresh_meta.title else None\n',
                            f'{indent_str}            else:\n',
                            f'{indent_str}                player["artist"] = None\n',
                            f'{indent_str}                player["title"] = None\n',
                            f'{indent_str}        except Exception as e:\n',
                            f'{indent_str}            # Fallback to state_table if player call fails\n',
                            f'{indent_str}            player["state"] = self.state_table[p].state if hasattr(self.state_table[p], "state") else "unknown"\n',
                            f'{indent_str}            player["artist"] = self.state_table[p].metadata.artist if hasattr(self.state_table[p], "metadata") and hasattr(self.state_table[p].metadata, "artist") else None\n',
                            f'{indent_str}            player["title"] = self.state_table[p].metadata.title if hasattr(self.state_table[p], "metadata") and hasattr(self.state_table[p].metadata, "title") else None\n',
                            f'{indent_str}    else:\n',
                            f'{indent_str}        # Fallback to state_table\n',
                            f'{indent_str}        player["state"] = self.state_table[p].state if hasattr(self.state_table[p], "state") else "unknown"\n',
                            f'{indent_str}        player["artist"] = self.state_table[p].metadata.artist if hasattr(self.state_table[p], "metadata") and hasattr(self.state_table[p].metadata, "artist") else None\n',
                            f'{indent_str}        player["title"] = self.state_table[p].metadata.title if hasattr(self.state_table[p], "metadata") and hasattr(self.state_table[p].metadata, "title") else None\n'
                        ]
                        
                        # Remove the old state/artist/title lines
                        lines_to_remove = []
                        for k in range(state_line, title_line + 1):
                            if 'player["state"]' in lines[k] or "player['state']" in lines[k] or \
                               'player["artist"]' in lines[k] or "player['artist']" in lines[k] or \
                               'player["title"]' in lines[k] or "player['title']" in lines[k]:
                                lines_to_remove.append(k)
                        
                        # Insert refresh code before the first line to remove
                        if lines_to_remove:
                            first_remove = min(lines_to_remove)
                            # Insert before first_remove
                            lines[first_remove:first_remove] = refresh_code
                            # Remove old lines (adjust indices since we inserted)
                            for idx in sorted(lines_to_remove, reverse=True):
                                lines.pop(idx + len(refresh_code))
                            
                            fixed = True
                            print(f"   ✓ Modified states() to refresh from player.get_state()/get_meta() at line {first_remove+1}")
                            break
                break
        break

if not fixed:
    print("   ✗ Could not find states() method or state_table usage")
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
echo "5. Showing fixed states() method:"
grep -A 50 "def states(self):" "$CONTROLLER" | head -60
echo ""
echo "=========================================="
echo "Fix Applied!"
echo "=========================================="
echo ""
echo "The states() method now:"
echo "1. Calls get_state() on each player instance to get fresh state"
echo "2. Calls get_meta() on each player instance to get fresh metadata"
echo "3. Converts STATE constants to lowercase strings"
echo "4. Falls back to state_table if player calls fail"
echo ""
echo "Next steps:"
echo "1. Restart AudioControl2:"
echo "   systemctl restart audiocontrol2"
echo "2. Test - MPD state and metadata should now be correct in API"
echo ""

