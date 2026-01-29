#!/bin/bash

# Launch iPhone 17 (already booted or boot it)
xcrun simctl boot "iPhone 17" 2>/dev/null || true
open -a Simulator --args -CurrentDeviceUDID $(xcrun simctl list devices | grep "iPhone 17 (" | head -1 | awk -F '[()]' '{print $2}')

# Launch iPhone 17 Pro
xcrun simctl boot "iPhone 17 Pro" 2>/dev/null || true
open -a Simulator --args -CurrentDeviceUDID $(xcrun simctl list devices | grep "iPhone 17 Pro (" | head -1 | awk -F '[()]' '{print $2}')

echo "Launched iPhone 17 and iPhone 17 Pro"
echo "You can now run the app on both simulators from Xcode or by selecting the destination."
