#!/bin/bash

# Configuration
SCHEME="lambdas-xi-chapter"
APP_NAME="lambdas-xi-chapter"
DERIVED_DATA_PATH="./build"

# 1. Boot Simulators
echo "Booting simulators..."
xcrun simctl boot "iPhone 17" 2>/dev/null || true
xcrun simctl boot "iPhone 17 Pro" 2>/dev/null || true

# 2. Build the App
echo "Building app for specific simulator..."
# We build for one simulator architecture, it works for all modern ones
xcodebuild -scheme "$SCHEME" \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -configuration Debug \
  clean build | xcbeautify || true 

# Find the .app path
APP_PATH=$(find "$DERIVED_DATA_PATH" -name "*.app" | head -n 1)

if [ -z "$APP_PATH" ]; then
    echo "Error: Could not find .app bundle. Build failed."
    exit 1
fi

echo "Found app at: $APP_PATH"

# 3. Get Bundle Identifier
BUNDLE_ID=$(defaults read "$APP_PATH/Info.plist" CFBundleIdentifier)
echo "Bundle ID: $BUNDLE_ID"

# 4. Install and Launch on both devices
DEVICES=("iPhone 17" "iPhone 17 Pro")

for DEVICE_NAME in "${DEVICES[@]}"; do
    DEVICE_ID=$(xcrun simctl list devices | grep "$DEVICE_NAME (" | head -1 | awk -F '[()]' '{print $2}')
    
    if [ -n "$DEVICE_ID" ]; then
        echo "Installing on $DEVICE_NAME ($DEVICE_ID)..."
        xcrun simctl install "$DEVICE_ID" "$APP_PATH"
        
        echo "Launching on $DEVICE_NAME..."
        xcrun simctl launch "$DEVICE_ID" "$BUNDLE_ID"
    else
        echo "Could not find device: $DEVICE_NAME"
    fi
done

echo "Done! App should be running on both simulators."
