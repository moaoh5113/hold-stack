#!/bin/sh
# 배포용 zip 을 만든다: build/release/HoldStack-<버전>.zip (앱과 LICENSE)
set -e
cd "$(dirname "$0")/.."
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Resources/Info.plist)
./scripts/make-app.sh --release
STAGE=build/release/stage
rm -rf "$STAGE" && mkdir -p "$STAGE"
cp -R build/HoldStack.app LICENSE "$STAGE/"
xattr -cr "$STAGE" # 확장 속성이 zip 에 __MACOSX 로 끼지 않게
ZIP="build/release/HoldStack-$VERSION.zip"
rm -f "$ZIP"
(cd "$STAGE" && ditto -c -k --norsrc --noextattr --noqtn . "../$(basename "$ZIP")")
codesign --verify --deep --strict "$STAGE/HoldStack.app"
echo "built $ZIP ($(lipo -archs "$STAGE/HoldStack.app/Contents/MacOS/HoldStack"))"
