#!/bin/bash
# シミュレータで XCUITest を実行し、成否にかかわらずスクリーンショットを抽出する。
# 使い方: scripts/run-ui-tests.sh <出力ディレクトリ> [シミュレータ名]
set -uo pipefail

RESULT_DIR="$1"
SIMULATOR="${2:-iPad Pro 13-inch (M5)}"
SCHEME="ColorSchemeAnalyzer"
mkdir -p "$RESULT_DIR"

xcodebuild test -project "$SCHEME.xcodeproj" -scheme "$SCHEME" \
  -destination "platform=iOS Simulator,name=$SIMULATOR" \
  -resultBundlePath "$RESULT_DIR/result.xcresult" \
  -only-testing:ColorSchemeAnalyzerUITests \
  | tee "$RESULT_DIR/xcodebuild.log" | grep -E "Test Case|Executed|error:|\*\* TEST"
STATUS=${PIPESTATUS[0]}

"$(dirname "$0")/extract-screenshots.sh" "$RESULT_DIR/result.xcresult" "$RESULT_DIR"
echo "xcodebuild exit status: $STATUS (log: $RESULT_DIR/xcodebuild.log)"
exit "$STATUS"
