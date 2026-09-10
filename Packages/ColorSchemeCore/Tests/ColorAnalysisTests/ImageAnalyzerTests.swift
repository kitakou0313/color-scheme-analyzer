import Testing
import ColorAnalysis

/// ANA-04〜ANA-10: 画像全体をグリッドに分けて解析する。期待値は blueprint 6.1〜6.2 の 4×4 フィクスチャによる。
struct ImageAnalyzerTests {
    static let R = RGB8(r: 255, g: 0, b: 0)
    static let G = RGB8(r: 0, g: 255, b: 0)
    static let Y = RGB8(r: 187, g: 187, b: 187)
    static let B = RGB8(r: 0, g: 0, b: 255)
    static let L = RGB8(r: 128, g: 128, b: 255)

    /// blueprint 6.1 の 4×4 フィクスチャ（行優先）
    static let fixture = PixelImage(width: 4, height: 4, pixels: [
        R, R, G, G,
        R, R, G, R,
        Y, Y, B, L,
        Y, R, L, B,
    ])

    /// N=2 で解析すると 2×2 グリッドになり、各セルが blueprint 6.2 の値になる
    @Test func analyzesFixtureIntoExpectedCells() async throws {
        let result = try await ImageAnalyzer.analyze(Self.fixture, longSideCells: 2)
        #expect(result.grid.columns == 2 && result.grid.rows == 2)
        #expect(result.longSideCells == 2)
        #expect(result.colors == [Self.R, Self.G, RGB8(r: 204, g: 153, b: 153), RGB8(r: 64, g: 64, b: 255)])
        expectClose(result.saturations, [1, 1, 0.25, 0.7490196])
        expectClose(result.brightnesses, [1, 1, 0.8, 1])
    }

    /// セルの並びは行優先（左上 A、右上 B、左下 C、右下 D）
    @Test func cellsAreRowMajor() async throws {
        let result = try await ImageAnalyzer.analyze(Self.fixture, longSideCells: 2)
        #expect(result.cells[result.grid.cellIndex(row: 1, column: 0)].color == RGB8(r: 204, g: 153, b: 153))
    }

    /// ANA-09: 同じ入力と N に対して常に同じ結果を返す
    @Test func isDeterministic() async throws {
        let first = try await ImageAnalyzer.analyze(Self.fixture, longSideCells: 2)
        let second = try await ImageAnalyzer.analyze(Self.fixture, longSideCells: 2)
        #expect(first == second)
    }

    /// 画像より大きい N を指定しても、セルは画像サイズに丸められ 1 ピクセル 1 セルになる
    @Test func largeCellCountFallsBackToPixels() async throws {
        let result = try await ImageAnalyzer.analyze(Self.fixture, longSideCells: 64)
        #expect(result.grid.columns == 4 && result.grid.rows == 4)
        #expect(result.colors[7] == Self.R)
    }

    /// ANA-10: キャンセル済みのタスクからは CancellationError を投げる
    @Test func throwsWhenCancelled() async {
        let task = Task<AnalysisResult, Error> {
            while !Task.isCancelled { await Task.yield() }
            return try await ImageAnalyzer.analyze(Self.fixture, longSideCells: 2)
        }
        task.cancel()
        await #expect(throws: CancellationError.self) { try await task.value }
    }

    /// Float 配列を 1e-6 の許容で比較する
    private func expectClose(_ actual: [Float], _ expected: [Float]) {
        #expect(actual.count == expected.count)
        for (a, e) in zip(actual, expected) { #expect(abs(a - e) < 1e-6, "\(a) ≠ \(e)") }
    }
}
