import Foundation
import Testing
import AnalysisWorkflow
import ColorAnalysis
import ImageDecoding
import Persistence
import TestSupport

/// IMP-03〜IMP-07, DET-03: 取り込み（デコード → 解析 → サムネイル → 保存）と再解析を一続きで検証する。
struct ImportServiceTests {
    /// 一時ディレクトリにインメモリのストアを用意する
    private func makeStore() throws -> (AnalysisStore, URL) {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        return (try AnalysisStore.inMemory(imagesDirectory: dir), dir)
    }

    /// 4×4 フィクスチャの取り込み要求
    private func fixtureRequest(cells: Int = 2) -> ImportRequest {
        ImportRequest(imageData: TestImageFactory.sample4x4PNG(), fileExtension: "png", name: "sample-4x4", longSideCells: cells)
    }

    /// blueprint 6.4 の行例どおりに保存される
    @Test func importsFixtureIntoExpectedRecord() async throws {
        let (store, _) = try makeStore()
        let record = try await ImportService.run(fixtureRequest(), store: store)
        #expect(record.name == "sample-4x4" && record.imageWidth == 4 && record.imageHeight == 4)
        #expect(record.gridWidth == 2 && record.gridHeight == 2 && record.longSideCells == 2)
        #expect(record.colors == [RGB8(r: 255, g: 0, b: 0), RGB8(r: 0, g: 255, b: 0), RGB8(r: 204, g: 153, b: 153), RGB8(r: 64, g: 64, b: 255)])
        expectClose(record.saturations, [1, 1, 0.25, 0.7490196])
        expectClose(record.brightnesses, [1, 1, 0.8, 1])
        #expect(record.analysisVersion == ImageAnalyzer.version && record.imagePath.hasSuffix(".png"))
        #expect(record.thumbnail.prefix(2) == Data([0xFF, 0xD8]))
    }

    /// 保存後は一覧から取り出せ、画像コピーが元データと一致する（PER-02）
    @Test func savedImageIsByteIdentical() async throws {
        let (store, _) = try makeStore()
        let request = fixtureRequest()
        let record = try await ImportService.run(request, store: store)
        #expect(try store.list().map(\.id) == [record.id])
        #expect(try Data(contentsOf: store.imageURL(for: record)) == request.imageData)
    }

    /// 進捗は 0 から 1 へ単調に進み、最後に 1 を報告する（NFR-03）
    @Test func reportsProgress() async throws {
        let (store, _) = try makeStore()
        let recorder = ProgressRecorder()
        _ = try await ImportService.run(fixtureRequest(), store: store) { recorder.record($0) }
        let values = recorder.values
        #expect(values.last == 1 && values == values.sorted())
    }

    /// IMP-03: キャンセルされたら CancellationError を投げ、何も保存しない
    @Test func cancelSavesNothing() async throws {
        let (store, dir) = try makeStore()
        let request = fixtureRequest()
        let task = Task<AnalysisRecord, Error> {
            while !Task.isCancelled { await Task.yield() }
            return try await ImportService.run(request, store: store)
        }
        task.cancel()
        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(try store.list().isEmpty)
        #expect(try FileManager.default.contentsOfDirectory(atPath: dir.path).isEmpty)
    }

    /// IMP-06: 画像でないデータは unsupportedData を投げ、何も保存しない
    @Test func rejectsNonImageWithoutSaving() async throws {
        let (store, _) = try makeStore()
        let request = ImportRequest(imageData: Data("nope".utf8), fileExtension: "png", name: "x", longSideCells: 64)
        await #expect(throws: ImageDecodingError.unsupportedData) { try await ImportService.run(request, store: store) }
        #expect(try store.list().isEmpty)
    }

    /// DET-03 / PER-05: 再解析は同じレコードを別解像度で上書きする
    @Test func reanalyzeOverwritesSameRecord() async throws {
        let (store, _) = try makeStore()
        let record = try await ImportService.run(fixtureRequest(cells: 2), store: store)
        let updated = try await ImportService.reanalyze(record, longSideCells: 4, store: store)
        #expect(updated.id == record.id && updated.gridWidth == 4 && updated.gridHeight == 4)
        #expect(updated.colors[7] == RGB8(r: 255, g: 0, b: 0))
        #expect(try store.list().count == 1)
    }

    /// 保存した画像を解析画像として読み戻せる（色相画面用）
    @Test func loadsAnalysisImage() async throws {
        let (store, _) = try makeStore()
        let record = try await ImportService.run(fixtureRequest(), store: store)
        let image = try ImportService.loadImage(for: record, store: store)
        #expect(image.width == 4 && image[x: 3, y: 1] == RGB8(r: 255, g: 0, b: 0))
    }

    /// Float 配列を 1e-6 の許容で比較する
    private func expectClose(_ actual: [Float], _ expected: [Float]) {
        #expect(actual.count == expected.count)
        for (a, e) in zip(actual, expected) { #expect(abs(a - e) < 1e-6, "\(a) ≠ \(e)") }
    }
}

/// 進捗値をスレッド安全に記録する
final class ProgressRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: [Double] = []

    /// 値を追加する
    func record(_ value: Double) {
        lock.withLock { stored.append(value) }
    }

    /// 記録した値
    var values: [Double] { lock.withLock { stored } }
}
