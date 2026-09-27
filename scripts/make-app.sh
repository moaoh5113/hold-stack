#!/bin/sh
# release 빌드 후 build/HoldStack.app 으로 묶는다.
set -e
cd "$(dirname "$0")/.."
swift build -c release --product HoldStack
APP=build/HoldStack.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$(swift build -c release --show-bin-path)/HoldStack" "$APP/Contents/MacOS/"
cp Resources/Info.plist "$APP/Contents/"
cp Resources/AppIcon.icns "$APP/Contents/Resources/"
codesign --force --sign - "$APP"
echo "built $APP"
