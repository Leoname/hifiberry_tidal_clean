#!/usr/bin/env python3
"""
Fix for AudioControl2 active player bug.
When activePlayer is None but a player is playing, auto-activate that player.
"""

import sys
import re

WEBSERVER_FILE = "/opt/audiocontrol2/ac2/webserver.py"

def apply_fix():
    # Read the file
    try:
        with open(WEBSERVER_FILE, 'r') as f:
            lines = f.readlines()
    except FileNotFoundError:
        print(f"✗ File not found: {WEBSERVER_FILE}")
        sys.exit(1)
    
    # Check if already fixed
    content = ''.join(lines)
    if "Auto-activating playing player" in content:
        print("✓ Fix already applied!")
        return True
    
    # Find the playercontrol_handler function
    handler_start = None
    for i, line in enumerate(lines):
        if 'def playercontrol_handler(self, command):' in line:
            handler_start = i
            break
    
    if handler_start is None:
        print("✗ Could not find playercontrol_handler function")
        sys.exit(1)
    
    # Find the line with "if not(self.send_command(command)):"
    target_line = None
    for i in range(handler_start, min(handler_start + 20, len(lines))):
        if 'if not(self.send_command(command)):' in lines[i]:
            target_line = i
            break
    
    if target_line is None:
        print("✗ Could not find target line to replace")
        sys.exit(1)
    
    # Get indentation from the target line
    indent = len(lines[target_line]) - len(lines[target_line].lstrip())
    indent_str = ' ' * indent
    
    # Create the replacement code
    replacement = [
        f'{indent_str}# Try to send command\n',
        f'{indent_str}result = self.send_command(command)\n',
        f'{indent_str}\n',
        f'{indent_str}# If command failed because active_player is None, try to auto-select playing player\n',
        f'{indent_str}if not result and self.player_control is not None:\n',
        f'{indent_str}    states = self.player_control.states()\n',
        f'{indent_str}    # Find the first playing player\n',
        f'{indent_str}    for player in states.get("players", []):\n',
        f'{indent_str}        if player.get("state", "").lower() == "playing":\n',
        f'{indent_str}            player_name = player.get("name")\n',
        f'{indent_str}            if player_name:\n',
        f'{indent_str}                logging.info("Auto-activating playing player: %s", player_name)\n',
        f'{indent_str}                # Activate the playing player\n',
        f'{indent_str}                if self.activate_player(player_name):\n',
        f'{indent_str}                    # Retry the command\n',
        f'{indent_str}                    result = self.send_command(command)\n',
        f'{indent_str}                    break\n',
        f'{indent_str}\n',
        f'{indent_str}if not result:\n',
    ]
    
    # Replace the old line with the new code
    new_lines = lines[:target_line] + replacement + lines[target_line + 1:]
    
    # Write the modified file
    try:
        with open(WEBSERVER_FILE, 'w') as f:
            f.writelines(new_lines)
    except Exception as e:
        print(f"✗ Failed to write file: {e}")
        sys.exit(1)
    
    # Verify
    with open(WEBSERVER_FILE, 'r') as f:
        if "Auto-activating playing player" in f.read():
            print("✓ Fix applied successfully!")
            return True
        else:
            print("✗ Fix verification failed!")
            sys.exit(1)

if __name__ == '__main__':
    apply_fix()

