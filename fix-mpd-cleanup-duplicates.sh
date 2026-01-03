#!/bin/bash
# Clean up duplicate code in MPDControl

echo "=========================================="
echo "Cleaning Up Duplicate Code in MPDControl"
echo "=========================================="
echo ""

MPD_CONTROL="/opt/audiocontrol2/ac2/players/mpdcontrol.py"
BACKUP="${MPD_CONTROL}.backup.$(date +%Y%m%d_%H%M%S)"

# Check if file exists
if [ ! -f "$MPD_CONTROL" ]; then
    echo "✗ MPDControl file not found"
    exit 1
fi

# Create backup
echo "1. Creating backup..."
cp "$MPD_CONTROL" "$BACKUP"
echo "✓ Backup: $BACKUP"
echo ""

echo "2. Finding and removing duplicate code..."
python3 << 'PYTHON_FIX'
import sys
import re

mpd_control_file = "/opt/audiocontrol2/ac2/players/mpdcontrol.py"

with open(mpd_control_file, 'r') as f:
    lines = f.readlines()

# Find duplicate if statements in get_meta()
# Look for: "if current_song_id != self.last_song_id or current_title != self.last_title:"
duplicate_found = False
for i, line in enumerate(lines):
    if "if current_song_id != self.last_song_id or current_title != self.last_title:" in line:
        # Check if the next few lines have the same pattern
        for j in range(i+1, min(i+10, len(lines)))):
            if "if current_song_id != self.last_song_id or current_title != self.last_title:" in lines[j] and j != i:
                print(f"   Found duplicate if statement at lines {i+1} and {j+1}")
                # Remove the duplicate (keep the first one)
                # Find the end of the duplicate block
                duplicate_end = j
                for k in range(j+1, min(j+10, len(lines))):
                    if lines[k].strip() and not lines[k].strip().startswith('#'):
                        if "self.last_song_id = current_song_id" in lines[k]:
                            # This is part of the duplicate, find where it ends
                            for m in range(k+1, min(k+5, len(lines))):
                                if lines[m].strip() and not lines[m].strip().startswith('#'):
                                    if "md = Metadata()" in lines[m] or "if song is not None:" in lines[m]:
                                        duplicate_end = m
                                        break
                            break
                # Remove duplicate lines
                if duplicate_end > j:
                    print(f"   Removing duplicate lines {j+1} to {duplicate_end}")
                    lines[j:duplicate_end] = []
                    duplicate_found = True
                    break
        if duplicate_found:
            break

# Also remove duplicate "Get fresh song data" comments
for i in range(len(lines) - 1, 0, -1):
    if "# Get fresh song data from MPD (not cached)" in lines[i]:
        if i > 0 and "# Get fresh song data from MPD (not cached)" in lines[i-1]:
            print(f"   Removing duplicate comment at line {i+1}")
            lines.pop(i)
            duplicate_found = True

if not duplicate_found:
    print("   ✓ No duplicates found")
else:
    print("   ✓ Duplicates removed")

# Write the fixed file
with open(mpd_control_file, 'w') as f:
    f.writelines(lines)

# Verify syntax
import py_compile
try:
    py_compile.compile(mpd_control_file, doraise=True)
    print("✓ Cleanup successful!")
except py_compile.PyCompileError as e:
    print(f"✗ Syntax error: {e}")
    sys.exit(1)
PYTHON_FIX

if [ $? -ne 0 ]; then
    echo "✗ Cleanup failed. Restoring backup..."
    cp "$BACKUP" "$MPD_CONTROL"
    exit 1
fi

echo ""
echo "3. Verifying cleanup:"
echo "   Checking for duplicates..."
grep -n "if current_song_id != self.last_song_id" "$MPD_CONTROL" | wc -l | xargs -I {} echo "   Found {} instances (should be 1)"
echo ""
echo "=========================================="
echo "Cleanup Complete!"
echo "=========================================="
echo ""

