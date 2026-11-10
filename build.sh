#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")"
APP="$PWD/Float Recorder.app"
mkdir -p "$APP/Contents/MacOS" .build/module-cache
swiftc Sources/main.swift -o "$APP/Contents/MacOS/FloatRecorder" -target arm64-apple-macos15.0 -module-cache-path "$PWD/.build/module-cache" -framework AppKit -framework SwiftUI -framework ScreenCaptureKit -framework AVFoundation
cp Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - --identifier com.pollen.floatrecorder "$APP"
echo "Built: $APP"
