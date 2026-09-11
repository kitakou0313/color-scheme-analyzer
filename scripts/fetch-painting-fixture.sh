#!/bin/bash
# E2E 用の実写フィクスチャ（starry-night.png）を、著作権の切れたパブリックドメインの
# 絵画から取得する。ネットワークが必要。取得結果は git に commit 済みなので通常は
# 再実行不要（ソースの提供元がファイルを差し替えた場合などにのみ再取得する）。
#
# 出典: Vincent van Gogh, "The Starry Night" (1889)
# 所蔵: The Museum of Modern Art, New York
# 収録: Wikimedia Commons
#   https://commons.wikimedia.org/wiki/File:Van_Gogh_-_Starry_Night_-_Google_Art_Project.jpg
# ライセンス: パブリックドメイン（PD-Art, PD-old-100-expired, CC-PD-Mark）。
#   ゴッホは 1890 年没で著作権保護期間（没後 70〜100 年）をいずれの基準でも
#   超過している。二次元美術品の忠実な複製写真に新たな著作権は生じない
#   （Bridgeman Art Library v. Corel Corp., 米国判例）。
set -euo pipefail

OUT_DIR="$(cd "$(dirname "$0")/.." && pwd)/App/ColorSchemeAnalyzer/Fixtures"
SRC_URL="https://commons.wikimedia.org/wiki/Special:FilePath/Van_Gogh_-_Starry_Night_-_Google_Art_Project.jpg?width=960"
TMP_JPG="$(mktemp -t starry-night-XXXX).jpg"
TMP_RESIZED="$(mktemp -t starry-night-resized-XXXX).jpg"

curl -sL -A "color-scheme-analyzer-dev (test fixture download)" "$SRC_URL" -o "$TMP_JPG"
sips -Z 512 "$TMP_JPG" --out "$TMP_RESIZED" >/dev/null
sips -s format png "$TMP_RESIZED" --out "$OUT_DIR/starry-night.png" >/dev/null
rm -f "$TMP_JPG" "$TMP_RESIZED"

echo "wrote $OUT_DIR/starry-night.png"
sips -g pixelWidth -g pixelHeight "$OUT_DIR/starry-night.png"
