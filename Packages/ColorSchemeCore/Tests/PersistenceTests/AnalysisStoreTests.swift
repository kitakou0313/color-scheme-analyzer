import Foundation
import Testing
import ColorAnalysis
import Persistence

/// PER-01〜PER-07, LIB-03/04/07: 解析レコードの保存・一覧・改名・削除・再解析の上書き。
struct AnalysisStoreTests {
    /// blueprint 6.2 の 2×2 解析結果
    static let result = AnalysisResult(
        grid: GridLayout(imageWidth: 4, imageHeight: 4, longSideCells: 2),
        longSideCells: 2,
        cells: [
            CellValue(hue: 0, saturation: 1, brightness: 1),
            CellValue(hue: 120, saturation: 1, brightness: 1),
            CellValue(hue: 0, saturation: 0.25, brightness: 0.8),
            CellValue(hue: 240, saturation: 0.7490196, brightness: 1),
        ]
    )
    static let imageBytes = Data([0x89, 0x50, 0x4E, 0x47, 1, 2, 3, 4])
    static let thumbnailBytes = Data([0xFF, 0xD8, 9, 9])

    /// 一時ディレクトリにインメモリ DB と画像ディレクトリを用意する
    private func makeStore() throws -> (AnalysisStore, URL) {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return (try AnalysisStore.inMemory(imagesDirectory: dir), dir)
    }

    /// 保存する新規解析の入力
    private func newAnalysis(name: String = "sample-4x4", createdAt: Date = Date()) -> NewAnalysis {
        NewAnalysis(
            name: name, createdAt: createdAt, imageData: Self.imageBytes, fileExtension: "png",
            imageWidth: 4, imageHeight: 4, result: Self.result, thumbnail: Self.thumbnailBytes,
            analysisVersion: "hsb-dominant-v1"
        )
    }

    /// PER-02, PER-04: 保存すると画像がそのままコピーされ、行の値と BLOB が往復で一致する
    @Test func saveCopiesImageAndStoresBlobs() throws {
        let (store, dir) = try makeStore()
        let record = try store.save(newAnalysis())
        #expect(record.name == "sample-4x4" && record.gridWidth == 2 && record.gridHeight == 2)
        #expect(record.imageWidth == 4 && record.longSideCells == 2 && record.analysisVersion == "hsb-dominant-v1")
        #expect(record.imagePath == "images/\(record.id.uuidString).png")
        #expect(try Data(contentsOf: dir.appendingPathComponent("\(record.id.uuidString).png")) == Self.imageBytes)
        #expect(record.colors == Self.result.colors)
        #expect(record.saturations == Self.result.saturations && record.brightnesses == Self.result.brightnesses)
    }

    /// PER-04: cell_color は RGB8 × 4 = 12 バイト、cell_saturation は Float32 リトルエンディアン
    @Test func blobLayoutMatchesSpec() throws {
        let (store, _) = try makeStore()
        let record = try store.save(newAnalysis())
        #expect(record.cellColor == Data([255, 0, 0, 0, 255, 0, 204, 153, 153, 64, 64, 255]))
        #expect(record.cellSaturation.count == 16)
        #expect(record.cellSaturation.prefix(4) == Data([0, 0, 0x80, 0x3F]), "1.0 as Float32 LE")
    }

    /// LIB-01: 一覧は作成日時の降順
    @Test func listIsNewestFirst() throws {
        let (store, _) = try makeStore()
        let older = try store.save(newAnalysis(name: "old", createdAt: Date(timeIntervalSince1970: 1_000)))
        let newer = try store.save(newAnalysis(name: "new", createdAt: Date(timeIntervalSince1970: 2_000)))
        #expect(try store.list().map(\.id) == [newer.id, older.id])
    }

    /// LIB-07: 同じ画像を 2 回保存すると別レコードになる
    @Test func duplicatesAreAllowed() throws {
        let (store, _) = try makeStore()
        _ = try store.save(newAnalysis())
        _ = try store.save(newAnalysis())
        #expect(try store.list().count == 2)
    }

    /// LIB-04: 改名できる。空文字や空白のみは拒否する
    @Test func renameRejectsEmptyName() throws {
        let (store, _) = try makeStore()
        let record = try store.save(newAnalysis())
        try store.rename(id: record.id, to: "renamed")
        #expect(try store.fetch(id: record.id)?.name == "renamed")
        #expect(throws: AnalysisStoreError.emptyName) { try store.rename(id: record.id, to: "   ") }
    }

    /// PER-06: 削除で行と画像ファイルの両方が消える
    @Test func deleteRemovesRowAndFile() throws {
        let (store, dir) = try makeStore()
        let record = try store.save(newAnalysis())
        try store.delete(id: record.id)
        #expect(try store.fetch(id: record.id) == nil)
        #expect(!FileManager.default.fileExists(atPath: dir.appendingPathComponent("\(record.id.uuidString).png").path))
    }

    /// PER-06: 画像ファイルが既にない場合も削除はエラーにならない
    @Test func deleteToleratesMissingFile() throws {
        let (store, dir) = try makeStore()
        let record = try store.save(newAnalysis())
        try FileManager.default.removeItem(at: dir.appendingPathComponent("\(record.id.uuidString).png"))
        try store.delete(id: record.id)
        #expect(try store.fetch(id: record.id) == nil)
    }

    /// PER-05: 再解析はグリッド・セル値・バージョンを上書きし、画像と名前は保持する
    @Test func updateResultOverwritesAnalysis() throws {
        let (store, _) = try makeStore()
        let record = try store.save(newAnalysis())
        let finer = AnalysisResult(
            grid: GridLayout(imageWidth: 4, imageHeight: 4, longSideCells: 4), longSideCells: 4,
            cells: [CellValue](repeating: CellValue(hue: nil, saturation: 0, brightness: 0.5), count: 16)
        )
        try store.updateResult(id: record.id, result: finer, analysisVersion: "hsb-dominant-v2")
        let updated = try #require(try store.fetch(id: record.id))
        #expect(updated.gridWidth == 4 && updated.gridHeight == 4 && updated.longSideCells == 4)
        #expect(updated.cellCount == 16 && updated.colors.count == 16 && updated.analysisVersion == "hsb-dominant-v2")
        #expect(updated.name == record.name && updated.imagePath == record.imagePath)
    }

    /// PER-07: テスト用フックで analysis_version だけを書き換えられる。他の列は変わらない
    @Test func overrideAnalysisVersionChangesOnlyThatColumn() throws {
        let (store, _) = try makeStore()
        let record = try store.save(newAnalysis())
        try store.overrideAnalysisVersion(id: record.id, to: "hsb-dominant-v0")
        let updated = try #require(try store.fetch(id: record.id))
        #expect(updated.analysisVersion == "hsb-dominant-v0")
        #expect(updated.name == record.name && updated.gridWidth == record.gridWidth)
    }

    /// 画像ファイルの絶対 URL を組み立てられる
    @Test func imageURLPointsIntoImagesDirectory() throws {
        let (store, dir) = try makeStore()
        let record = try store.save(newAnalysis())
        #expect(store.imageURL(for: record) == dir.appendingPathComponent("\(record.id.uuidString).png"))
    }
}
