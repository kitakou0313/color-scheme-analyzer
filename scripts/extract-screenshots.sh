#!/bin/bash
# xcresult からスクリーンショット添付を取り出し、manifest.json をもとに
# <出力>/screenshots/<テスト名>/<添付名>.png に並べ替える（blueprint 8 章）。
# 使い方: scripts/extract-screenshots.sh <result.xcresult> <出力ディレクトリ>
set -euo pipefail

XCRESULT="$1"
OUT="$2/screenshots"
RAW="$2/attachments-raw"
mkdir -p "$OUT" "$RAW"
xcrun xcresulttool export attachments --path "$XCRESULT" --output-path "$RAW" >/dev/null

python3 - "$RAW" "$OUT" <<'EOF'
import json, re, shutil, sys
from pathlib import Path

raw, out = Path(sys.argv[1]), Path(sys.argv[2])
manifest = json.load(open(raw / "manifest.json"))
count = 0
for test in manifest:
    test_dir = out / re.sub(r"[^A-Za-z0-9_.-]+", "_", test.get("testIdentifier", "unknown"))
    for attachment in test.get("attachments", []):
        exported = raw / attachment["exportedFileName"]
        if exported.suffix.lower() != ".png":
            continue
        # 添付名は "<name>_0_<UUID>.png" なので先頭の name だけを使う
        name = re.sub(r"_\d+_[0-9A-Fa-f-]{36}\.png$", "", attachment.get("suggestedHumanReadableName", exported.name))
        test_dir.mkdir(parents=True, exist_ok=True)
        shutil.copy(exported, test_dir / f"{name}.png")
        count += 1
print(f"{count} screenshots -> {out}")
for path in sorted(out.rglob("*.png")):
    print(path.relative_to(out))
EOF
