import XCTest

/// LIB-01〜LIB-06, DET-03, DET-04: 一覧・空状態・改名・削除・再解析
final class LibraryUITests: XCTestCase {
    private var app: XCUIApplication!

    /// 各テストで新しいアプリを用意する
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    /// LIB-05, DET-04: 空のストアで起動すると両ペインに案内が出る
    func testEmptyStateShowsGuidance() throws {
        app.launchArguments = ["-uiTestResetStore"]
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["library.emptyState"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.descendants(matching: .any)["detail.emptyState"].exists)
        snapshot("11-empty")
        app.buttons["library.addButton"].tap()
        XCTAssertTrue(app.buttons["import.fromPhotos"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["import.fromFiles"].exists)
        snapshot("12-add-menu")
    }

    /// LIB-01, LIB-04, DET-03, LIB-03: 取り込んだ行の改名 → 再解析 → 削除
    func testRenameReanalyzeAndDelete() throws {
        app.launchArguments = ["-uiTestResetStore", "-uiTestFixture", "hatching"]
        app.launch()
        importWithResolution("32")
        let row = app.descendants(matching: .any)["library.row"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 15))
        XCTAssertTrue(row.label.contains("hatching") && row.label.contains("32×32"), row.label)
        snapshot("13-library-row")
        rename(row, to: "ハッチング")
        XCTAssertTrue(app.navigationBars["ハッチング"].waitForExistence(timeout: 10))
        reanalyze(to: "128")
        XCTAssertTrue(app.descendants(matching: .any)["library.row"].firstMatch.label.contains("128×128"))
        snapshot("14-reanalyzed")
        deleteFirstRow()
        XCTAssertTrue(app.descendants(matching: .any)["library.emptyState"].waitForExistence(timeout: 10))
        snapshot("15-deleted")
    }

    /// LIB-02: 再起動直後は未選択に戻り、一覧の行をタップすると詳細が開く
    func testTappingRowOpensDetail() throws {
        app.launchArguments = ["-uiTestResetStore", "-uiTestFixture", "hatching"]
        app.launch()
        importWithResolution("32")
        XCTAssertTrue(app.descendants(matching: .any)["library.row"].firstMatch.waitForExistence(timeout: 15))
        app.terminate()
        app.launchArguments = []
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["detail.emptyState"].waitForExistence(timeout: 15), "再起動直後は未選択")
        let row = app.descendants(matching: .any)["library.row"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.tap()
        XCTAssertTrue(app.navigationBars["hatching"].waitForExistence(timeout: 10), "行タップで詳細が開く")
        snapshot("19-row-tap-opens-detail")
    }

    /// 解像度を選んで開始し、詳細が開くまで待つ
    private func importWithResolution(_ cells: String) {
        let start = app.buttons["import.resolution.start"]
        XCTAssertTrue(start.waitForExistence(timeout: 15))
        app.segmentedControls["import.resolution.picker"].buttons[cells].tap()
        start.tap()
        XCTAssertTrue(app.segmentedControls["detail.segment"].waitForExistence(timeout: 60))
    }

    /// コンテキストメニューから改名する
    private func rename(_ row: XCUIElement, to name: String) {
        row.press(forDuration: 1.0)
        app.buttons["名前を変更"].tap()
        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 5), "改名アラート")
        let field = alert.textFields.firstMatch
        field.tap()
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 20))
        field.typeText(name)
        alert.buttons["保存"].firstMatch.tap()
    }

    /// 再解析ボタンから解像度を変えて上書きする
    private func reanalyze(to cells: String) {
        app.buttons["detail.reanalyze"].tap()
        importWithResolution(cells)
    }

    /// スワイプで削除し、確認ダイアログを承認する
    private func deleteFirstRow() {
        app.descendants(matching: .any)["library.row"].firstMatch.swipeLeft()
        app.buttons["削除"].firstMatch.tap()
        let confirm = app.buttons["library.confirmDelete"].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()
    }

    /// 画面全体のスクリーンショットを添付として残す
    private func snapshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
