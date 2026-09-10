import Testing
import ColorAnalysis

/// BAR-01〜BAR-04: 解析結果から棒の位置・高さ・色を決める。期待値は blueprint 6.2 の座標表による。
struct BarGeometryTests {
    /// blueprint 6.2 の 2×2 解析結果（A, B, C, D）
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

    /// BAR-01: 棒の中心はセル位置に対応し、画像の上辺（行 0）が −z、左辺（列 0）が −x
    @Test func barsArePlacedAtCellCenters() {
        let g = BarGeometry.make(from: Self.result, metric: .saturation)
        #expect(g.bars.map(\.x) == [-0.5, 0.5, -0.5, 0.5])
        #expect(g.bars.map(\.z) == [-0.5, -0.5, 0.5, 0.5])
    }

    /// BAR-02: 彩度画面の高さは値 × 最大高さ（2 セルなら最大 1.0）
    @Test func saturationHeightsScaleWithMaxHeight() {
        let g = BarGeometry.make(from: Self.result, metric: .saturation)
        #expect(g.maxHeight == 1)
        expectClose(g.bars.map(\.height), [1, 1, 0.25, 0.7490196])
    }

    /// BAR-02: 明度画面では明度を高さに使う
    @Test func brightnessMetricUsesBrightness() {
        let g = BarGeometry.make(from: Self.result, metric: .brightness)
        expectClose(g.bars.map(\.height), [1, 1, 0.8, 1])
    }

    /// BAR-02: 値 0 の棒は最大高さの 1% を保つ
    @Test func zeroValueKeepsMinimumHeight() {
        let zero = AnalysisResult(
            grid: GridLayout(imageWidth: 1, imageHeight: 1, longSideCells: 1),
            longSideCells: 1,
            cells: [CellValue(hue: nil, saturation: 0, brightness: 0)]
        )
        let g = BarGeometry.make(from: zero, metric: .saturation)
        #expect(abs(g.bars[0].height - 0.01 * g.maxHeight) < 1e-6)
    }

    /// BAR-03: 棒の断面はセル幅の 0.8
    @Test func barWidthIsEightyPercentOfCell() {
        let g = BarGeometry.make(from: Self.result, metric: .saturation)
        #expect(g.barWidth == 0.8)
    }

    /// BAR-04: 棒の色はセルの代表色
    @Test func barColorsAreCellColors() {
        let g = BarGeometry.make(from: Self.result, metric: .saturation)
        #expect(g.bars.map(\.color) == Self.result.colors)
    }

    /// 64×48 グリッドでは最大高さ 32、x は −31.5〜31.5、z は −23.5〜23.5
    @Test func largeGridExtents() {
        let cells = [CellValue](repeating: CellValue(hue: nil, saturation: 0, brightness: 0), count: 64 * 48)
        let r = AnalysisResult(grid: GridLayout(imageWidth: 4000, imageHeight: 3000, longSideCells: 64), longSideCells: 64, cells: cells)
        let g = BarGeometry.make(from: r, metric: .brightness)
        #expect(g.maxHeight == 32)
        #expect(g.bars.first?.x == -31.5 && g.bars.first?.z == -23.5)
        #expect(g.bars.last?.x == 31.5 && g.bars.last?.z == 23.5)
    }

    /// Float 配列を 1e-6 の許容で比較する
    private func expectClose(_ actual: [Float], _ expected: [Float]) {
        #expect(actual.count == expected.count)
        for (a, e) in zip(actual, expected) { #expect(abs(a - e) < 1e-6, "\(a) ≠ \(e)") }
    }
}
