import XCTest

/// IMP-02〜IMP-04, DET-01, BAR-*, HUE-*: フィクスチャを取り込み、3 画面を操作して確認する
final class ImportFlowUITests: XCTestCase {
    private var app: XCUIApplication!

    /// アプリのインスタンスだけ用意する。起動は各テストが launch(fixture:) で行う
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    /// 解像度シート → 解析 → 詳細（彩度・明度・色相）を一続きで確認する（4×4 フィクスチャ、期待値は blueprint 6.1〜6.3）
    func testImportFixtureAndInspectAllTabs() throws {
        launch(fixture: "sample-4x4")
        importFixture()
        snapshot("02-saturation")
        segment.buttons["明度"].tap()
        snapshot("03-brightness")
        segment.buttons["色相"].tap()
        inspectHue()
    }

    /// BAR-07: リセット・俯瞰・ピンチ・床トグルを操作してスクリーンショットを残す
    func testBarChartControls() throws {
        launch(fixture: "sample-4x4")
        importFixture()
        let view = app.descendants(matching: .any)["bar.view"].firstMatch
        view.swipeLeft()
        snapshot("07-bar-rotated")
        app.buttons["bar.topDown"].tap()
        snapshot("08-bar-topdown")
        app.buttons["bar.reset"].tap()
        view.pinch(withScale: 2, velocity: 1)
        snapshot("09-bar-zoomed")
        app.descendants(matching: .any)["bar.floorToggle"].firstMatch.tap()
        snapshot("10-bar-floor-off")
    }

    /// blueprint 6.5: 実写フィクスチャ（パブリックドメインの絵画、出典は Fixtures/ATTRIBUTION.md）は
    /// 期待値を持たず、例外なく解析が完了し 3 画面とも表示されることだけを確認する
    func testRealPaintingFixtureCompletesAndDisplaysAllTabs() throws {
        launch(fixture: "starry-night")
        importFixture()
        snapshot("16-painting-saturation")
        segment.buttons["明度"].tap()
        snapshot("17-painting-brightness")
        segment.buttons["色相"].tap()
        XCTAssertTrue(app.images["hue.image"].waitForExistence(timeout: 15), "色相画面に画像が表示される")
        snapshot("18-painting-hue")
    }

    /// HUE-09: 色相画面でも 2 本指ピンチで画像がズームする（2 本指パンは XCUITest に多指ドラッグ API がなく手動確認）
    func testHueScreenPinchZoom() throws {
        launch(fixture: "sample-4x4")
        importFixture()
        segment.buttons["色相"].tap()
        let image = app.images["hue.image"]
        XCTAssertTrue(image.waitForExistence(timeout: 15))
        let widthBeforePinch = image.frame.width
        image.pinch(withScale: 2, velocity: 1)
        XCTAssertTrue(image.frame.width > widthBeforePinch, "ピンチで画像が拡大される")
        snapshot("19-hue-zoomed")
    }

    /// IMP-03, NFR-03: 解析中は進捗表示が見え、キャンセルすると何も保存されない
    /// -uiTestSlowAnalysis で解析開始直後に待ちを入れ、進捗表示とキャンセル操作を確実に間に合わせる
    func testCancelDuringAnalysisSavesNothing() throws {
        app.launchArguments = ["-uiTestResetStore", "-uiTestFixture", "sample-4x4", "-uiTestSlowAnalysis"]
        app.launch()
        let start = app.buttons["import.resolution.start"]
        XCTAssertTrue(start.waitForExistence(timeout: 15))
        start.tap()
        XCTAssertTrue(app.descendants(matching: .any)["import.progress"].waitForExistence(timeout: 10), "進捗表示が見える")
        snapshot("20-analyzing-progress")
        app.buttons["import.progress.cancel"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["library.emptyState"].waitForExistence(timeout: 10), "キャンセルすると何も保存されない")
        snapshot("21-cancelled-empty")
    }

    /// IMP-06: 非画像データを取り込むとアラートが出て、何も保存されない
    func testCorruptFileShowsUnreadableAlertAndSavesNothing() throws {
        launch(fixture: "corrupt-data")
        let start = app.buttons["import.resolution.start"]
        XCTAssertTrue(start.waitForExistence(timeout: 15))
        start.tap()
        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 10), "読み込めないアラートが出る")
        XCTAssertTrue(alert.staticTexts["この画像は読み込めません"].exists)
        alert.buttons.firstMatch.tap()
        XCTAssertTrue(app.descendants(matching: .any)["library.emptyState"].waitForExistence(timeout: 10), "何も保存されない")
        snapshot("22-corrupt-file-alert")
    }

    /// PER-07: 解析方式が古いレコードを開くと更新案内バナーが出て、再解析すると消える
    func testStaleAnalysisVersionShowsBannerUntilReanalyzed() throws {
        app.launchArguments = ["-uiTestResetStore", "-uiTestFixture", "sample-4x4", "-uiTestStaleVersion"]
        app.launch()
        importFixture()
        XCTAssertTrue(app.staticTexts["detail.versionBanner"].waitForExistence(timeout: 10), "古い解析方式のバナーが出る")
        snapshot("23-stale-version-banner")
        app.buttons["detail.reanalyze"].tap()
        importFixture()
        XCTAssertFalse(app.staticTexts["detail.versionBanner"].exists, "再解析すると消える")
        snapshot("24-reanalyzed-banner-gone")
    }

    /// NFR-02: 縦横回転してもセグメントと画面が保たれる
    func testRotatesBetweenPortraitAndLandscape() throws {
        launch(fixture: "sample-4x4")
        importFixture()
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(segment.waitForExistence(timeout: 10), "横向きでも表示できる")
        snapshot("25-landscape")
        XCUIDevice.shared.orientation = .portrait
        XCTAssertTrue(segment.waitForExistence(timeout: 10), "縦向きに戻せる")
        snapshot("26-portrait")
    }

    /// ストアを空にし、指定フィクスチャで取り込みフローを開始した状態でアプリを起動する
    private func launch(fixture: String) {
        app.launchArguments = ["-uiTestResetStore", "-uiTestFixture", fixture]
        app.launch()
    }

    /// IMP-02〜IMP-04: 64 を選んで開始し、詳細が開くまで待つ
    private func importFixture() {
        let start = app.buttons["import.resolution.start"]
        XCTAssertTrue(start.waitForExistence(timeout: 15), "解像度シートが表示される")
        snapshot("01-resolution-sheet")
        app.segmentedControls["import.resolution.picker"].buttons["64"].tap()
        start.tap()
        XCTAssertTrue(segment.waitForExistence(timeout: 60), "解析後に詳細が開く")
        XCTAssertTrue(app.descendants(matching: .any)["bar.view"].firstMatch.waitForExistence(timeout: 15), "彩度の 3D ビュー")
    }

    /// HUE-02〜HUE-08: 赤・青・無彩色のピクセルを選び、数値表示を確認する
    private func inspectHue() {
        let image = app.images["hue.image"]
        XCTAssertTrue(image.waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["hue.hint"].exists, "初期状態はヒント表示")
        image.coordinate(withNormalizedOffset: CGVector(dx: 0.125, dy: 0.125)).tap()
        XCTAssertTrue(readoutLabel.contains("H 0°") && readoutLabel.contains("S 100%"), readoutLabel)
        snapshot("04-hue-red")
        image.coordinate(withNormalizedOffset: CGVector(dx: 0.125, dy: 0.125))
            .press(forDuration: 0.2, thenDragTo: image.coordinate(withNormalizedOffset: CGVector(dx: 0.875, dy: 0.875)))
        XCTAssertTrue(readoutLabel.contains("H 240°"), readoutLabel)
        snapshot("05-hue-blue")
        image.coordinate(withNormalizedOffset: CGVector(dx: 0.125, dy: 0.625)).tap()
        XCTAssertTrue(readoutLabel.contains("無彩色") && readoutLabel.contains("B 73%"), readoutLabel)
        snapshot("06-hue-achromatic")
    }

    /// 詳細のセグメントコントロール
    private var segment: XCUIElement { app.segmentedControls["detail.segment"] }

    /// 数値表示の文言
    private var readoutLabel: String { app.staticTexts["hue.readout"].label }

    /// 画面全体のスクリーンショットを添付として残す
    private func snapshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
