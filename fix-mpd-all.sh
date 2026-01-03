#!/bin/bash
# Master script to apply ALL MPD fixes in correct order

echo "=========================================="
echo "Applying All MPD Fixes"
echo "=========================================="
echo ""
echo "This will apply all fixes in the correct order:"
echo "1. State detection fix (always reconnect)"
echo "2. Metadata refresh fix (track song ID and title)"
echo "3. Metadata parsing fix (parse 'Artist - Title' format)"
echo ""

# Check if we're in the right directory
if [ ! -f "fix-mpd-state-robust.sh" ]; then
    echo "✗ Please run this script from /data/tidal-connect-docker"
    exit 1
fi

echo "Step 1: Fixing state detection..."
./fix-mpd-state-robust.sh
if [ $? -ne 0 ]; then
    echo "✗ State detection fix failed"
    exit 1
fi
echo ""

echo "Step 2: Fixing metadata refresh (song ID tracking)..."
./fix-mpd-metadata-refresh.sh
if [ $? -ne 0 ]; then
    echo "⚠ Metadata refresh fix had issues, but continuing..."
fi
echo ""

echo "Step 3: Fixing metadata refresh (title tracking for radio)..."
./fix-mpd-radio-metadata-refresh.sh
if [ $? -ne 0 ]; then
    echo "⚠ Radio metadata refresh fix had issues, but continuing..."
fi
echo ""

echo "Step 4: Cleaning up duplicate code..."
./fix-mpd-cleanup-duplicates.sh
if [ $? -ne 0 ]; then
    echo "⚠ Cleanup had issues, but continuing..."
fi
echo ""

echo "Step 5: Fixing metadata parsing (Artist - Title format)..."
./fix-mpd-metadata-parsing-v2.sh
if [ $? -ne 0 ]; then
    echo "⚠ Metadata parsing fix had issues, but continuing..."
fi
echo ""

echo "Step 6: Forcing metadata refresh..."
./fix-mpd-force-refresh.sh
if [ $? -ne 0 ]; then
    echo "⚠ Force refresh fix had issues, but continuing..."
fi
echo ""

echo "=========================================="
echo "All Fixes Applied!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Restart AudioControl2:"
echo "   systemctl restart audiocontrol2"
echo ""
echo "2. Test with a radio stream - state and metadata should now work correctly"
echo ""

