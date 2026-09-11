# color-scheme-analyzer

iPadOS向けアプリ。画像を入力とし、その画像について以下を生成する。
- 彩度
  - 画像の各ピクセルごとに彩度の3D棒グラフ
  - 元画像内でのピクセルの配置と同じ場所に配置する
- 明度
  - 画像の各ピクセルごとに明度の3D棒グラフ
  - 元画像内でのピクセルの配置と同じ場所に配置する
- 色相
  - 元画像をそのまま表示する
  - 画像内のピクセルを選択すると、そのピクセルの色の色相が同画面内の色相環のうちどの部分かが表示される
  - 画像上を指やApple Pencilでなぞり選択されたピクセルが変化すると色相環上のポイントも追従して変化すること

- ある画像について上記の画面を生成したら永続化しておき、後で再度開けるようにすること（画像間での比較のため）

## ビルド/テスト
- 前提: Xcode 26 と XcodeGen（`brew install xcodegen`）。`.xcodeproj` は生成物なので `make gen` で作る（git 管理外）
- `make test-core`: `Packages/ColorSchemeCore` の単体テスト（Swift Testing）。Xcode 本体なしで `swift test` が回る
- `make test-ui`: iPad Pro 13-inch (M5) シミュレータで XCUITest を実行し、スクリーンショットを `TestResults/<日時>/screenshots/` に抽出する（git 管理外）
- `python3 scripts/make-fixtures.py`: E2E 用フィクスチャ画像を `App/ColorSchemeAnalyzer/Fixtures/` に再生成する
- E2E 用の起動引数（Debug ビルドのみ有効）: `-uiTestResetStore`（DB と画像を消してから起動）、`-uiTestFixture <name>`（sample-4x4 / hatching / gradient / starry-night をピッカーなしで取り込みフローに流す。starry-night はパブリックドメインの実写絵画。出典は `App/ColorSchemeAnalyzer/Fixtures/ATTRIBUTION.md`、取得は `scripts/fetch-painting-fixture.sh`）
- 実機での実行は Xcode で Apple ID（Personal Team）を設定して署名する。自動化の対象外

## 開発方針
- 仕様、アーキテクチャなどの管理ファイル
  - 以下のファイルを機能要件のマスターデータとして用いる
    - ./docs/color-scheme-analyzer-blueprint.html
    - 記載すべき内容
      - 各画面の機能要件
      - データの実例
    - 仕様の変更や進捗の更新があった場合、このファイルに*必ず*反映すること
- 動作検証を行うことを前提にすすめる
- 基本的に動作検証も自動化可能な形で実装することを前提とする

### 基本的な方針
- view以外のロジックの部分
  - TDDで進める
    - 失敗するテストを先に作成
      - ユーザーが求めている要件を満たしていることを演繹的に確認できるテスト
      - エッジケースを考慮したテスト
    - テストを通過するコードを実装
    - リファクタリングを実施
  - SwiftUIのViewは薄く保ち、ロジックはViewModel/Serviceに寄せてテスト可能にする
  - UIKit非依存のロジックは可能な限り `Packages/ColorSchemeCore` に置き、Xcode本体なしでも `swift test` でTDDできるようにする。
- viewのテスト
  - TDDで進める
    - 失敗するテストを先に作成
    - ユーザーが求めている要件を満たしていることを演繹的に確認できるテスト
    - エッジケースを考慮したテスト
    - テストを通過するコードを実装
    - リファクタリングを実施
  - 可能な限りXCodeのSimulator上でのe2e testを実装する
  - 可能な限りe2e testは自動化して実装する
  - 自動化テスト中の画面はスクリーンショットを撮影しテスト実行ごとに保存する
    - スクリーンショット自体はgitの追跡から外すこと

### コーディングスタイル
- 各関数の長さは*必ず*10行程度に抑える
- 各関数には*必ず*コメントでどのような処理を行っているのかを明記する
- 上記 2 ルールの適用範囲は本番コード・テスト・SwiftUI の `body` すべて。`body` は子 View に、テストはヘルパー関数に分割して守る
- 配列リテラル・SQL 文字列・期待値テーブルなどの宣言的な列挙は行数に数えない

### 開発時のフロー
- TDDをベースに進める
  - 求められている要件を満たすことを演繹的に検証できる検証方法を設計する
  - 検証に必要なコードなどを生成する
  - 実装方針を考える
  - 実装を実施する
  - 設計した検証方法で実装を検証する
      - 検証を通過するまで進める

## 設計上の制約
- 永続化はローカル(Documentsディレクトリ)上のSQLiteを利用する(Apple Personal Team(無料アカウント)がiCloud capabilityに対応していないため)。

各制約の理由や実装の意思決定経緯、現在の実装状況は auto memory(`/memory`から参照可能)にある。

## 設計決定ログ（要件ヒアリング）
2026-09-07 のヒアリングで確定した事項。未決の項目は後続ラウンドで追記する。

### 解析
- 解析グリッド: 画像をダウンサンプリングし、セル単位で棒を立てる。長辺のセル数はユーザー選択（32 / 64 / 128）、既定値 64。短辺はアスペクト比を維持して決める。セル色は最頻色相法によるセルの代表色（下記）。
- 解像度は取り込み時に選択し、後から詳細画面で再解析して上書きできる（画像コピーは保持し、解析結果のみ差し替える）。
- セル値の定義（最頻色相法）: セル内の各ピクセルを HSB に変換し、S が 5% 未満のピクセルを除いて色相を 5° 刻み 72 ビンに彩度を重みとして積み、隣接ビンと平滑化してピークを取る。ピーク ±15° のピクセルの色相を円周平均したものをセルの代表色相とする。代表色の S/B と棒の高さは、セル内全ピクセルの S・B それぞれの単純平均。有彩色ピクセルがないセルは無彩色（平均グレー）として扱う。平均色（sRGB 平均・リニア光平均）方式は混色で元画像に存在しない色相を作るため不採用。ピーク同数時のタイブレーク規則は実装時に定義しテストで固定する。
- 色プロファイル: デコード時に sRGB へ統一し、HSB は sRGB 成分から計算する（Display P3 の高彩度がクリップされることは許容）。
- デコードは Core 側で ImageIO（CGImageSource）を使い RGBA8 バッファに展開する。UIKit 非依存。長辺 4096px を上限に縮小し、解析と色相画面の表示・選択の両方に同じ画像を使う（色相画面の「元ピクセル」は上限適用後の画像のピクセル）。
- 透過（アルファ）ピクセルは白で合成してから解析する。
- 画像の向き: デコード時に EXIF の回転を適用し、写真アプリで見る向きに揃える（ImageIO のサムネイル変換オプションで実現）。
- 色空間: HSB。Procreate のカラーパネル「Value」タブと同じ定義（H: 0–360°、赤で始まり赤で終わる / S: 0–100% / B: 0–100%）。変換は Core 側で抽象化し、将来の別色空間追加に備える。

### 画像入力
- v1 は PhotosPicker（写真ライブラリ）と Files（ドキュメントピッカー）。ドラッグ&ドロップは v2。カメラは非対応。

### 3D 棒グラフ（彩度・明度）
- 描画: RealityKit。全棒を 1 メッシュに結合し 1 エンティティで描く（SceneKit は iOS 26 で非推奨のため不採用）。
- 棒の高さ = 値（彩度 or 明度）。棒の色は画面ごとに異なる（2026-09-11 変更）: 彩度画面はセルの代表色（最頻色相法。「解析」節を参照）。明度画面はセルの明度（cell_brightness）に連動した白〜黒のグレースケール（HSB(hue: なし, S: 0, B: cell_brightness) を sRGB に変換。代表色の色相は使わない）。
- 床面に元画像をテクスチャとして貼るトグルを持つ。
- 操作: 1本指ドラッグで回転、ピンチでズーム、リセットボタン、真上からの俯瞰プリセット。棒タップでの値表示は v2。
- 棒の形状: 正方形断面、太さはセル幅の 0.8（隙間 20%、隙間から床の元画像が見える）。値 0 の棒は最大高さの 1% を最小高さとする。値 100% の高さはグリッド長辺の 0.5 倍。基準面・目盛りは v1 では出さず、画面隅に「高さ = 彩度 0–100%」等の凡例テキストのみ。
- 見た目の既定値: 床テクスチャ ON、背景はダークグレー、ライティングは RealityKit 既定。初期カメラは仰角 45°・方位 30° でグリッド全体が収まる位置。ズームは 0.5〜4 倍に制限。
- 明度画面の色をグレースケールにしたことで暗いセルの棒は依然として暗い（それが明度マップとしての意図）。基準面・目盛り・カラーマップの選択式切替は引き続き v1 では出さず v2。
- 3D 上の配置: 初期カメラから見て画像の上辺が奥、左辺が左（床に置いた写真を斜め上から見る配置）。ジオメトリ生成のテストでこの座標対応を固定する。

### 色相画面
- 元画像をそのまま表示し、選択は元画像のピクセル単位。
- 指・Apple Pencil ともにタッチとして DragGesture で追従。Pencil ホバーは対象外。
- 色相環: 色相角マーカー + 数値（H°, S%, B%）+ 選択色スウォッチ。S が 5% 未満はマーカーを消し「無彩色」と表示。
- 色相環の向き: 赤（0°）を真上（12 時）に置き時計回りに増える。数値表示は H を整数度（0–359、360 は 0）、S/B を整数 % で表示する。
- 選択フィードバック: 選択中ピクセルに白黒二重線の十字マーカーを表示し、指を離しても残す。初期状態は未選択で「画像をタップまたはなぞって色を選択」のヒント文を表示。ルーペ（拡大表示）は v2。
- ズーム/パン: 2 本指ピンチと 2 本指ドラッグでズーム/パンする（v1 に含む）。1 本指ドラッグは選択専用。

### 永続化
- 保存内容: 元画像のコピー（Documents/images/）+ 解析結果（代表色・彩度・明度の配列を SQLite の BLOB）+ メタデータ（名前・日時・グリッドサイズ・サムネイル）。
- SQLite アクセス層: GRDB.swift。
- v1 は保存済み一覧と再オープンまで。データモデルは複数選択を前提に設計し、並列比較は v2。
- 画像コピー: 再エンコードせずバイト列をそのまま `Documents/images/<UUID>.<拡張子>` に保存（HEIC/JPEG/PNG を維持）。サムネイルは長辺 256px の JPEG を BLOB で保存。
- 名前・並び・重複・削除: 既定名は Files 経由なら元ファイル名、写真ライブラリ経由なら取り込み日時。あとから改名可。同一画像の重複取り込みは許す。一覧は作成日時の降順、v1 は検索なし。削除はサイドバーのスワイプ → 確認ダイアログ → DB 行と画像ファイルの両方を削除。
- DB ファイル: `Documents/color-scheme-analyzer.sqlite`。再解析は image_path の画像から計算し、cell_* と grid_* を上書きする。
- スキーマ（単一テーブル `analyses`）:

```
id TEXT PRIMARY KEY          -- UUID
name TEXT NOT NULL
created_at TEXT NOT NULL     -- ISO8601
image_path TEXT NOT NULL     -- Documents からの相対パス（元バイト列のコピー）
image_width INTEGER, image_height INTEGER   -- 4096px 上限適用後のサイズ
grid_width INTEGER, grid_height INTEGER, long_side_cells INTEGER
cell_color BLOB              -- RGB8 × セル数（代表色。棒の色）
cell_saturation BLOB         -- Float32 × セル数（0–1。彩度チャートの高さ）
cell_brightness BLOB         -- Float32 × セル数（0–1。明度チャートの高さ）
thumbnail BLOB               -- JPEG
analysis_version TEXT        -- 例 hsb-dominant-v1（手法変更時の再解析判定に使う）
```

### 画面構成 / 対応環境
- NavigationSplitView。サイドバー = 保存済み一覧、詳細 = 解析画面（セグメントで彩度 / 明度 / 色相を切替）。
- 取り込みフロー: サイドバーのツールバー「＋」→ メニュー「写真から / ファイルから」→ ピッカー → 解像度シート（32/64/128、既定 64、前回値を記憶）→ 進捗表示 → 自動保存 → 詳細を開く。明示的な「保存」ボタンは置かない。未選択時の詳細画面は空状態メッセージと取り込みボタン。
- 解析中のキャンセルと失敗: 進捗表示にキャンセルボタンを置き、キャンセル時は何も保存しない。デコード不能・非対応形式はアラートを出して保存しない。ディスク書き込み失敗もアラートを出し、途中生成物（画像コピー）を削除する。
- 最小 iPadOS 26.0、iPad のみ（iPhone 非対応）、縦横両対応。
- UI は日本語、コード識別子は英語。ローカライズは後回し。

### プロジェクト構成 / テスト
- XcodeGen の project.yml から .xcodeproj を生成し、.xcodeproj は git 管理外。
- UIKit 非依存ロジックは `Packages/ColorSchemeCore`（ローカル SwiftPM）に置き `swift test` で回す。
- E2E: XCUITest + XCTAttachment。`xcodebuild test -resultBundlePath` の結果から `xcresulttool` で `TestResults/<日時>/` に抽出し gitignore。
- 3D はジオメトリ生成（棒の位置・高さ・色）を Core の単体テストで検証し、E2E は表示確認とスクショにとどめる。
- 自動 E2E はシミュレータのみ。実機（Pencil）は手動確認。
- 命名: アプリターゲット `ColorSchemeAnalyzer`、表示名「Color Scheme Analyzer」、Bundle ID `dev.kitakou.ColorSchemeAnalyzer`。
- Core パッケージ構成: `Packages/ColorSchemeCore` 1 パッケージに 3 ターゲット。`ColorAnalysis`（純 Swift: HSB 変換、最頻色相法、セル平均、棒ジオメトリ生成）、`ImageDecoding`（ImageIO デコード、4096px 上限縮小、sRGB 統一、白合成）、`Persistence`（GRDB モデル、リポジトリ、マイグレーション）。Swift 6 strict concurrency 有効。
- E2E フィクスチャ: PhotosPicker は別プロセスで操作不可のため、起動引数（例 `-uiTestFixture sample01`）でテストバンドル内の画像を直接取り込む経路を用意する。フィクスチャはテスト時に生成する既知色の小画像（4×4 等、演繹的検証用）と、テストリソースの小さな実写 2〜3 枚。対象シミュレータは iPad Pro 13-inch (M5) に固定。
- ローカル実行: Makefile に `make gen`（XcodeGen）、`make test-core`（`swift test`）、`make test-ui`（シミュレータ E2E + スクショ抽出）。CI（GitHub Actions 等）は v1 では置かない。
- blueprint HTML: ヒアリング終了時に決定ログから各画面の機能要件とデータ実例（スキーマの行例、4×4 フィクスチャの代表色・彩度・明度の値例）を起こして `docs/color-scheme-analyzer-blueprint.html` を作成し、実装着手前にユーザーが確認する。
- テストフレームワーク: Core は Swift Testing（`@Test` / `#expect`）、E2E は XCTest（XCUITest）。
- コーディングルールの適用範囲は「コーディングスタイル」節に記載（全コードに適用、宣言的列挙は数えない）。
- Git 運用: コミットはユーザーが行う。Claude は作業ツリーの変更までとし、コミット・push はしない。

### 実装上の決定（2026-09-10、v1 実装時）
- 棒の色付け: 全棒を 1 メッシュにし、色はセル数と同じ大きさのテクスチャで与える（各棒の UV をテクセル中心に固定、ミップマップなし）。頂点色は使わない。
- 床テクスチャの ON/OFF: テクスチャ付きの床と無地の床の 2 エンティティを `isEnabled` で切り替える。
- カメラ: Core の `OrbitCamera` が床面中心を注視点に位置を決める。フィット距離は縦横の視野角の狭い方で決める（縦画面で切れないように）。
- 色相画面の入力: SwiftUI の DragGesture は指の本数を区別できないため、UIKit の認識器（1 本指専用のカスタム認識器・2 本指パン・ピンチ）を `UIGestureRecognizerRepresentable` で使う。
- 並行性: アプリターゲットは `SWIFT_DEFAULT_ACTOR_ISOLATION=MainActor`。UI テストターゲットは XCTestCase のオーバーライドが nonisolated のため `nonisolated` に戻す。Core の重い処理は `@concurrent` で呼び出し側のアクターから外す。
- RealityView のコンテンツ型は iOS では `RealityViewCameraContent`（visionOS の `RealityViewContent` とは別）。
- XCUITest: アラート・確認ダイアログ・RealityView のボタン/要素は複数一致することがあるので `firstMatch` で取る。スクショは `xcresulttool export attachments` で取り出し、manifest.json の名前で `screenshots/<テスト>/<名前>.png` に並べる。
