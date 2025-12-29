#!/bin/bash
# Fix stop command - AudioController.stop() doesn't accept 'ignore' parameter

echo "=========================================="
echo "Fixing Stop Command Bug"
echo "=========================================="
echo ""

WEBSERVER="/opt/audiocontrol2/ac2/webserver.py"
BACKUP="${WEBSERVER}.backup.$(date +%Y%m%d_%H%M%S)"

# Check if file exists
if [ ! -f "$WEBSERVER" ]; then
    echo "✗ Webserver file not found"
    exit 1
fi

# Check if already fixed
if grep -q "# Fix: stop doesn't accept ignore parameter" "$WEBSERVER"; then
    echo "✓ Fix already applied!"
    exit 0
fi

# Create backup
echo "1. Creating backup..."
cp "$WEBSERVER" "$BACKUP"
echo "✓ Backup: $BACKUP"
echo ""

# First, let's see what the send_command method looks like
echo "2. Checking current send_command method..."
SEND_CMD_LINE=$(grep -n "def send_command" "$WEBSERVER" | head -1 | cut -d: -f1)
if [ -n "$SEND_CMD_LINE" ] && [ "$SEND_CMD_LINE" -gt 0 ] 2>/dev/null; then
    echo "Found at line $SEND_CMD_LINE:"
    END_LINE=$((SEND_CMD_LINE+50))
    sed -n "${SEND_CMD_LINE},${END_LINE}p" "$WEBSERVER"
    echo ""
fi

# Use Python to fix it - look for the exact pattern
python3 << 'PYTHON_FIX'
import sys
import re

webserver_file = "/opt/audiocontrol2/ac2/webserver.py"

# Read the file
with open(webserver_file, 'r') as f:
    content = f.read()
    lines = content.split('\n')

# Check if already fixed
if "# Fix: stop doesn't accept ignore parameter" in content:
    print("✓ Fix already applied!")
    sys.exit(0)

# Find the line with stop(ignore=ignore)
fixed = False
new_lines = []
i = 0

while i < len(lines):
    line = lines[i]
    
    # Look for stop() call with ignore parameter
    if 'self.player_control.stop(ignore=' in line or 'self.player_control.stop(ignore =' in line:
        # Get indentation
        indent = len(line) - len(line.lstrip())
        indent_str = ' ' * indent
        
        # Replace with fixed version
        new_lines.append(f'{indent_str}# Fix: stop doesn't accept ignore parameter')
        new_lines.append(f'{indent_str}self.player_control.stop()')
        fixed = True
        i += 1
    else:
        new_lines.append(line)
        i += 1

if not fixed:
    print("⚠️  Could not find stop(ignore=...) call")
    print("   Searching for alternative patterns...")
    
    # Try to find it with regex
    pattern = r'self\.player_control\.stop\(ignore\s*=\s*\w+\)'
    if re.search(pattern, content):
        # Replace using regex
        new_content = re.sub(
            r'self\.player_control\.stop\(ignore\s*=\s*\w+\)',
            '# Fix: stop doesn\'t accept ignore parameter\n            self.player_control.stop()',
            content
        )
        with open(webserver_file, 'w') as f:
            f.write(new_content)
        print("✓ Fix applied using regex replacement!")
        sys.exit(0)
    else:
        print("✗ Could not find stop() call with ignore parameter")
        print("   The code might be structured differently")
        sys.exit(1)

# Write the fixed file
with open(webserver_file, 'w') as f:
    f.write('\n'.join(new_lines))

print("✓ Fix applied successfully!")
PYTHON_FIX

if [ $? -ne 0 ]; then
    echo "✗ Fix failed. Restoring backup..."
    cp "$BACKUP" "$WEBSERVER"
    exit 1
fi

# Verify
if grep -q "# Fix: stop doesn't accept ignore parameter" "$WEBSERVER"; then
    echo ""
    echo "3. Showing fixed code:"
    grep -B 2 -A 2 "Fix: stop doesn't accept ignore" "$WEBSERVER"
    echo ""
    echo "=========================================="
    echo "Fix Applied!"
    echo "=========================================="
    echo ""
    echo "Next steps:"
    echo "1. Restart AudioControl2:"
    echo "   systemctl restart audiocontrol2"
    echo ""
    echo "2. Test stop command via UI"
    echo ""
else
    echo "✗ Fix verification failed!"
    cp "$BACKUP" "$WEBSERVER"
    exit 1
fi

