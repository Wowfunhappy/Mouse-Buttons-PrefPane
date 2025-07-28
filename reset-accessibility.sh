#!/bin/bash

echo "Resetting Accessibility Database..."

# Kill the helper if it's running
echo "Stopping helper..."
killall MouseSideButtonsHelper 2>/dev/null || true
launchctl unload ~/Library/LaunchAgents/Wowfunhappy.sidebuttons.helper.plist 2>/dev/null || true

sudo tccutil reset Accessibility

# Remove the helper app from accessibility database
echo "Removing from accessibility database..."
sudo tccutil reset Accessibility Wowfunhappy.sidebuttons.helper 2>/dev/null || true

# For older macOS versions, you might need to manually edit the database
if [ -f "/Library/Application Support/com.apple.TCC/TCC.db" ]; then
    echo "Cleaning TCC database..."
    sudo sqlite3 "/Library/Application Support/com.apple.TCC/TCC.db" "DELETE FROM access WHERE client LIKE '%MouseButtons%' OR client LIKE '%Wowfunhappy.sidebuttons%';" 2>/dev/null || true
fi

# Clean up any cached references
echo "Cleaning up..."
rm -rf ~/Library/Caches/com.mousesidebuttons* 2>/dev/null || true
rm -rf ~/Library/Caches/Wowfunhappy.sidebuttons* 2>/dev/null || true
rm -rf ~/Library/Preferences/com.mousesidebuttons* 2>/dev/null || true
rm -rf ~/Library/Preferences/Wowfunhappy.sidebuttons* 2>/dev/null || true

# Restart accessibility daemon
echo "Restarting accessibility services..."
sudo killall tccd 2>/dev/null || true