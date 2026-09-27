#!/bin/sh
# 코드의 L("…") 문구 가운데 영어 번역표에 없는 것을 찾는다. 없으면 종료 코드 0.
cd "$(dirname "$0")/.."
python3 - <<'PY'
import re, glob, sys
used = set()
for f in glob.glob('Sources/HoldStack/*.swift') + glob.glob('Sources/HoldCore/*.swift'):
    for m in re.finditer(r'\bL\("((?:[^"\\]|\\.)*)"', open(f).read()):
        used.add(m.group(1))
table = open('Sources/HoldCore/Localization.swift').read()
known = set(re.findall(r'^\s*"((?:[^"\\]|\\.)*)":', table, flags=re.M))
missing = sorted(used - known)
unused = sorted(known - used)
for k in missing: print("번역 없음:", k)
for k in unused: print("쓰지 않는 번역:", k)
print(f"문구 {len(used)}개, 번역 없음 {len(missing)}개, 쓰지 않음 {len(unused)}개")
sys.exit(1 if missing else 0)
PY
