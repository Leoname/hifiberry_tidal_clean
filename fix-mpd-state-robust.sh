#!/bin/bash
# Robust fix: Ensure get_state() always returns correct state by reconnecting and getting fresh data

echo "=========================================="
echo "Fixing MPDControl State Detection (Robust)"
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

echo "2. Reading current get_state() method..."
grep -A 30 "def get_state(self):" "$MPD_CONTROL" | head -35
echo ""

echo "3. Applying robust fix..."
python3 << 'PYTHON_FIX'
import sys
import re

mpd_control_file = "/opt/audiocontrol2/ac2/players/mpdcontrol.py"

with open(mpd_control_file, 'r') as f:
    lines = f.readlines()

# Find get_state() method
get_state_start = -1
for i, line in enumerate(lines):
    if "def get_state(self):" in line:
        get_state_start = i
        break

if get_state_start == -1:
    print("✗ Could not find get_state() method")
    sys.exit(1)

# Find the end of get_state() method (next def or class)
get_state_end = len(lines)
for i in range(get_state_start + 1, len(lines)):
    if lines[i].strip().startswith("def ") or lines[i].strip().startswith("class "):
        get_state_end = i
        break

# Extract get_state method
get_state_lines = lines[get_state_start:get_state_end]
get_state_content = "".join(get_state_lines)

# Check if we need to add connection check
needs_fix = True
if "self.client.ping()" in get_state_content or ("if self.client is None" in get_state_content and "self.reconnect()" in get_state_content):
    print("✓ Connection check already present, but enhancing...")
    needs_fix = True

# Build new get_state method
new_get_state = []
new_get_state.append("    def get_state(self):\n")
new_get_state.append("        \"\"\"Get current MPD state - always reconnects and gets fresh state\"\"\"\n")
new_get_state.append("        # Ensure connection is active\n")
new_get_state.append("        if self.client is None:\n")
new_get_state.append("            self.reconnect()\n")
new_get_state.append("        \n")
new_get_state.append("        # Test connection\n")
new_get_state.append("        try:\n")
new_get_state.append("            self.client.ping()\n")
new_get_state.append("        except:\n")
new_get_state.append("            # Connection broken, reconnect\n")
new_get_state.append("            self.reconnect()\n")
new_get_state.append("        \n")
new_get_state.append("        # Get fresh state from MPD\n")
new_get_state.append("        try:\n")
new_get_state.append("            status = self.client.status()\n")
new_get_state.append("            state = status.get(\"state\", \"stop\")\n")
new_get_state.append("            return STATE_MAP.get(state, STATE_STOPPED)\n")
new_get_state.append("        except Exception as e:\n")
new_get_state.append("            # Connection error, try reconnecting once more\n")
new_get_state.append("            try:\n")
new_get_state.append("                self.reconnect()\n")
new_get_state.append("                status = self.client.status()\n")
new_get_state.append("                state = status.get(\"state\", \"stop\")\n")
new_get_state.append("                return STATE_MAP.get(state, STATE_STOPPED)\n")
new_get_state.append("            except:\n")
new_get_state.append("                # Still failed, return stopped state\n")
new_get_state.append("                return STATE_STOPPED\n")

# Replace get_state method in lines
new_lines = lines[:get_state_start] + new_get_state + lines[get_state_end:]

# Write the fixed file
with open(mpd_control_file, 'w') as f:
    f.writelines(new_lines)

# Verify syntax
import py_compile
try:
    py_compile.compile(mpd_control_file, doraise=True)
    print("✓ Fix applied successfully!")
except py_compile.PyCompileError as e:
    print(f"✗ Syntax error: {e}")
    sys.exit(1)
PYTHON_FIX

if [ $? -ne 0 ]; then
    echo "✗ Fix failed. Restoring backup..."
    cp "$BACKUP" "$MPD_CONTROL"
    exit 1
fi

echo ""
echo "4. Showing new get_state() method:"
grep -A 30 "def get_state(self):" "$MPD_CONTROL" | head -35
echo ""
echo "=========================================="
echo "Fix Applied!"
echo "=========================================="
echo ""
echo "The get_state() method now:"
echo "1. Always checks if connection exists"
echo "2. Pings MPD to test connection"
echo "3. Reconnects if connection is broken"
echo "4. Gets fresh state from MPD"
echo "5. Retries once if connection fails"
echo ""
echo "Next steps:"
echo "1. Restart AudioControl2:"
echo "   systemctl restart audiocontrol2"
echo ""
echo "2. Test - state should now always be correct"
echo ""

