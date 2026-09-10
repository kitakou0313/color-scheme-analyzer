# color-scheme-analyzer

iPadOS 向けアプリ。画像を取り込み、色を **彩度・明度・色相** に分けて可視化する。

- 彩度 / 明度: 画像をセルに分割し、セルごとの値を 3D 棒グラフで表示（RealityKit）
- 色相: 画像上のピクセルを指や Apple Pencil で選ぶと、色相環上の位置と H/S/B の数値を表示
- 解析結果は端末内の SQLite に保存し、あとから開き直せる

仕様のマスターデータは `docs/color-scheme-analyzer-blueprint.html`、開発方針と決定の経緯は `CLAUDE.md` にある。

## 構成

```
App/ColorSchemeAnalyzer/        SwiftUI アプリ（薄い View と ViewModel）
App/ColorSchemeAnalyzerUITests/ XCUITest（シミュレータ E2E、スクリーンショット付き）
Packages/ColorSchemeCore/       ロジック（swift test で検証）
  ColorAnalysis     HSB 変換、グリッド分割、最頻色相法、棒ジオメトリ、色相環、カメラ
  ImageDecoding     ImageIO デコード（EXIF 回転・4096px 上限・白合成）、サムネイル
  Persistence       GRDB による保存（テーブル analyses と Documents/images/）
  AnalysisWorkflow  取り込み・再解析の一連の処理
docs/                           blueprint（機能要件・データ実例・進捗）
scripts/                        フィクスチャ生成、E2E 実行、スクリーンショット抽出
```

## ビルドとテスト

前提: Xcode 26、XcodeGen（`brew install xcodegen`）。

```sh
make gen        # project.yml から ColorSchemeAnalyzer.xcodeproj を生成（git 管理外）
make test-core  # Core の単体テスト（Xcode 不要）
make test-ui    # iPad Pro 13-inch (M5) シミュレータで E2E。スクショは TestResults/<日時>/screenshots/
```

E2E は起動引数 `-uiTestResetStore` と `-uiTestFixture <name>` で、写真ピッカーを経由せずにバンドル内の画像を取り込む（Debug ビルドのみ）。
