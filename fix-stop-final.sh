#!/bin/bash
# Final fix for stop command - restore backup and apply correctly

echo "=========================================="
echo "Final Fix for Stop Command"
echo "=========================================="
echo ""

WEBSERVER="/opt/audiocontrol2/ac2/webserver.py"

# Find the most recent backup
BACKUP=$(ls -t /opt/audiocontrol2/ac2/webserver.py.backup.* 2>/dev/null | head -1)

if [ -z "$BACKUP" ]; then
    echo "✗ No backup found"
    exit 1
fi

echo "1. Restoring from backup: $BACKUP"
cp "$BACKUP" "$WEBSERVER"
echo "✓ Restored"
echo ""

# Check Python syntax
echo "2. Checking Python syntax..."
python3 -m py_compile "$WEBSERVER" 2>&1
if [ $? -ne 0 ]; then
    echo "✗ Syntax error in backup"
    exit 1
fi
echo "✓ Syntax is valid"
echo ""

# Apply fix using sed - simpler and more reliable
echo "3. Applying fix..."

# First, add subprocess import if needed
if ! grep -q "^import subprocess" "$WEBSERVER"; then
    # Find the first import line and add subprocess after it
    sed -i '/^import /a import subprocess' "$WEBSERVER" 2>/dev/null || \
    sed -i '0,/^import /{/^import /a\
import subprocess
}' "$WEBSERVER"
fi

# Find the send_command("Stop") line and insert clearing code before it
# Use a more specific pattern to find the right location
sed -i '/self\.player_control\.send_command("Stop")/i\                    # Clear playlist to prevent auto-resume\n                    try:\n                        subprocess.run(["mpc", "clear"], check=False, capture_output=True, timeout=2)\n                    except:\n                        pass  # Ignore errors if mpc is not available' "$WEBSERVER"

# Verify syntax
echo "4. Verifying Python syntax..."
python3 -m py_compile "$WEBSERVER" 2>&1
if [ $? -eq 0 ]; then
    echo "✓ Syntax is valid"
    echo ""
    echo "5. Showing fixed code:"
    grep -B 5 -A 3 "# Clear playlist to prevent auto-resume" "$WEBSERVER" | head -10
    echo ""
    echo "=========================================="
    echo "Fix Applied Successfully!"
    echo "=========================================="
    echo ""
    echo "Next steps:"
    echo "1. Restart AudioControl2:"
    echo "   systemctl restart audiocontrol2"
    echo ""
    echo "2. Test stop command via UI"
    echo ""
else
    echo "✗ Syntax error - restoring backup"
    cp "$BACKUP" "$WEBSERVER"
    exit 1
fi

