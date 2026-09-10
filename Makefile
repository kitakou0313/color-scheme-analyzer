# ローカル開発用のタスク定義
CORE_DIR := Packages/ColorSchemeCore
SIMULATOR := platform=iOS Simulator,name=iPad Pro 13-inch (M5)
SCHEME := ColorSchemeAnalyzer
RESULT_DIR := TestResults/$(shell date +%Y%m%d-%H%M%S)

.PHONY: gen test-core test-ui test

## project.yml から .xcodeproj を生成する
gen:
	xcodegen generate

## Core パッケージの単体テスト（Xcode 不要）
test-core:
	cd $(CORE_DIR) && swift test

## シミュレータ上の E2E テストを実行し、成否にかかわらずスクリーンショットを TestResults/<日時>/screenshots/ に抽出する
test-ui: gen
	scripts/run-ui-tests.sh $(RESULT_DIR)

## すべてのテスト
test: test-core test-ui
