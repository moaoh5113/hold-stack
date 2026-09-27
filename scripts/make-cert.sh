#!/bin/sh
# 이 컴퓨터 전용 서명 인증서를 로그인 키체인에 만든다. 한 번만 돌리면 된다.
# 재빌드해도 macOS 가 같은 앱으로 알아봐서 손쉬운 사용 권한이 유지된다.
# 인증서에는 이름만 들어간다. 이메일이나 사람 이름을 넣지 않는다.
# 지우기: security delete-identity -c "HoldStack Local Signing"
set -e
NAME="HoldStack Local Signing"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"

if security find-certificate -c "$NAME" "$KEYCHAIN" >/dev/null 2>&1; then
  echo "이미 있다: $NAME"
  exit 0
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
PASS=$(/usr/bin/openssl rand -hex 16)

cat > "$TMP/cert.cnf" <<CNF
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = $NAME
[ext]
basicConstraints = critical, CA:false
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
CNF

/usr/bin/openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
  -config "$TMP/cert.cnf" -keyout "$TMP/key.pem" -out "$TMP/cert.pem" 2>/dev/null
/usr/bin/openssl pkcs12 -export -inkey "$TMP/key.pem" -in "$TMP/cert.pem" \
  -name "$NAME" -out "$TMP/id.p12" -passout "pass:$PASS"
security import "$TMP/id.p12" -k "$KEYCHAIN" -P "$PASS" -T /usr/bin/codesign >/dev/null
echo "만들었다: $NAME"
