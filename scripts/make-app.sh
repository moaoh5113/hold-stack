#!/bin/sh
# release 빌드 후 build/HoldStack.app 으로 묶는다.
#   ./scripts/make-app.sh            이 컴퓨터용. make-cert.sh 인증서가 있으면 그걸로 서명
#   ./scripts/make-app.sh --release  배포용. 인텔과 Apple Silicon 겸용, 임시 서명만 해서 개인 인증서가 들어가지 않는다
set -e
cd "$(dirname "$0")/.."
IDENTITY="HoldStack Local Signing"

# 배포용은 인텔과 Apple Silicon 에서 모두 돌게 만든다
ARCHS=""
[ "$1" = "--release" ] && ARCHS="--arch arm64 --arch x86_64"
swift build -c release --product HoldStack $ARCHS
APP=build/HoldStack.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$(swift build -c release $ARCHS --show-bin-path)/HoldStack" "$APP/Contents/MacOS/"
cp Resources/Info.plist "$APP/Contents/"
cp Resources/AppIcon.icns "$APP/Contents/Resources/"

if [ "$1" != "--release" ] && security find-certificate -c "$IDENTITY" >/dev/null 2>&1; then
  codesign --force --sign "$IDENTITY" "$APP"
  echo "built $APP (signed: $IDENTITY)"
else
  codesign --force --sign - "$APP"
  [ "$1" = "--release" ] || echo "note: ./scripts/make-cert.sh 를 한 번 돌리면 재빌드해도 권한이 유지된다"
  echo "built $APP (signed: ad-hoc)"
fi
