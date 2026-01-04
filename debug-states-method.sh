#!/bin/bash
# Debug why states() method returns wrong data even though MPDControl works directly

echo "=========================================="
echo "Debugging states() Method vs Direct Calls"
echo "=========================================="
echo ""

echo "1. Testing MPDControl directly:"
python3 << 'PYTHON_DIRECT'
import sys
sys.path.insert(0, '/opt/audiocontrol2')
try:
    from ac2.players.mpdcontrol import MPDControl
    
    mpd = MPDControl()
    mpd.start()
    
    print("  Direct MPDControl calls:")
    state = mpd.get_state()
    meta = mpd.get_meta()
    print(f"    get_state(): {state}")
    print(f"    get_meta(): artist={meta.artist if meta and hasattr(meta, 'artist') else 'None'}, title={meta.title if meta and hasattr(meta, 'title') else 'None'}")
    print(f"    is_active(): {mpd.is_active()}")
except Exception as e:
    print(f"  Error: {e}")
    import traceback
    traceback.print_exc()
PYTHON_DIRECT
echo ""

echo "2. Testing player_control.states() method:"
python3 << 'PYTHON_STATES'
import sys
sys.path.insert(0, '/opt/audiocontrol2')
try:
    from ac2.controller import AudioController
    
    controller = AudioController()
    controller.start()
    
    states = controller.player_control.states()
    
    print("  states() method result:")
    print(f"    Type: {type(states)}")
    if isinstance(states, dict):
        print(f"    Keys: {list(states.keys())}")
        if "players" in states:
            mpd_players = [p for p in states["players"] if p.get("name") == "mpd"]
            print(f"    MPD players in states(): {len(mpd_players)}")
            for i, p in enumerate(mpd_players, 1):
                print(f"      Player {i}:")
                print(f"        state: {p.get('state')}")
                print(f"        artist: {p.get('artist')}")
                print(f"        title: {p.get('title')}")
                print(f"        commands: {len(p.get('supported_commands', []))}")
    
    # Also check what player_control.players contains
    print("  player_control.players:")
    if hasattr(controller.player_control, 'players'):
        for name, player in controller.player_control.players.items():
            if name == "mpd":
                print(f"    Found 'mpd' player: {type(player)}")
                if hasattr(player, 'get_state'):
                    try:
                        direct_state = player.get_state()
                        print(f"      Direct get_state(): {direct_state}")
                    except Exception as e:
                        print(f"      Direct get_state() error: {e}")
                if hasattr(player, 'get_meta'):
                    try:
                        direct_meta = player.get_meta()
                        if direct_meta:
                            print(f"      Direct get_meta(): artist={direct_meta.artist if hasattr(direct_meta, 'artist') else 'None'}, title={direct_meta.title if hasattr(direct_meta, 'title') else 'None'}")
                        else:
                            print(f"      Direct get_meta(): None")
                    except Exception as e:
                        print(f"      Direct get_meta() error: {e}")
except Exception as e:
    print(f"  Error: {e}")
    import traceback
    traceback.print_exc()
PYTHON_STATES
echo ""

echo "3. Checking how states() serializes player data:"
python3 << 'PYTHON_SERIALIZE'
import sys
sys.path.insert(0, '/opt/audiocontrol2')
try:
    # Try to find where states() is implemented
    import inspect
    from ac2.controller import AudioController
    
    controller = AudioController()
    controller.start()
    
    # Get the states method
    states_method = controller.player_control.states
    print(f"  states() method location: {inspect.getfile(states_method)}")
    print(f"  states() method code (first 50 lines):")
    try:
        source = inspect.getsource(states_method)
        lines = source.split('\n')
        for i, line in enumerate(lines[:50], 1):
            print(f"    {i:3}: {line}")
    except:
        print("    Could not get source")
except Exception as e:
    print(f"  Error: {e}")
    import traceback
    traceback.print_exc()
PYTHON_SERIALIZE
echo ""

echo "=========================================="
echo "Summary"
echo "=========================================="
echo "This will show:"
echo "1. What MPDControl returns when called directly"
echo "2. What states() method returns"
echo "3. How states() serializes the player data"
echo ""

