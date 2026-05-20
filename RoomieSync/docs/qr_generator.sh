#!/usr/bin/env bash
# GitHub 리포지토리 QR 생성 — docs/qr.png 출력
# 작성자: 엄민욱 (2091188)
#
# 사용:
#   bash docs/qr_generator.sh https://github.com/eomminwook/roomiesync

set -e
URL="${1:-https://github.com/eomminwook/roomiesync}"
OUT="docs/qr.png"

if command -v qrencode >/dev/null 2>&1; then
    qrencode -o "$OUT" -s 12 -m 2 "$URL"
elif command -v python3 >/dev/null 2>&1; then
    python3 -c "
import qrcode
img = qrcode.make('$URL')
img.save('$OUT')
"
else
    echo "❌ qrencode 또는 python3+qrcode 필요. brew install qrencode 또는 pip install qrcode[pil]"
    exit 1
fi

echo "✅ QR 생성 완료: $OUT  (URL: $URL)"
