/// 画像全体の解析結果。cells は行優先（左上から右へ、次に下の行）。
public struct AnalysisResult: Hashable, Sendable {
    public let grid: GridLayout
    public let longSideCells: Int
    public let cells: [CellValue]

    /// グリッドとセル値から生成する
    public init(grid: GridLayout, longSideCells: Int, cells: [CellValue]) {
        self.grid = grid
        self.longSideCells = longSideCells
        self.cells = cells
    }

    /// 各セルの代表色（棒の色、cell_color）
    public var colors: [RGB8] { cells.map(\.color) }

    /// 各セルの平均彩度（彩度チャートの高さ、cell_saturation）
    public var saturations: [Float] { cells.map { Float($0.saturation) } }

    /// 各セルの平均明度（明度チャートの高さ、cell_brightness）
    public var brightnesses: [Float] { cells.map { Float($0.brightness) } }
}

/// 画像をグリッドに分け、各セルを最頻色相法で解析する（ANA-04〜ANA-10）。
public enum ImageAnalyzer {
    /// 解析方式の識別子。手法を変えたら更新する（analysis_version）
    public static let version = "hsb-dominant-v1"

    /// 画像を長辺 N セルで解析する。1 行ごとにキャンセルを確認し、キャンセル時は CancellationError を投げる
    public static func analyze(_ image: PixelImage, longSideCells: Int) async throws -> AnalysisResult {
        let grid = GridLayout(imageWidth: image.width, imageHeight: image.height, longSideCells: longSideCells)
        var cells: [CellValue] = []
        cells.reserveCapacity(grid.cellCount)
        for row in 0..<grid.rows {
            try Task.checkCancellation()
            for column in 0..<grid.columns { cells.append(analyzeCell(image, grid, row: row, column: column)) }
        }
        return AnalysisResult(grid: grid, longSideCells: longSideCells, cells: cells)
    }

    /// セル (row, column) が覆うピクセルを集めて解析する
    private static func analyzeCell(_ image: PixelImage, _ grid: GridLayout, row: Int, column: Int) -> CellValue {
        let xs = grid.columnRange(column), ys = grid.rowRange(row)
        let pixels = ys.flatMap { y in xs.map { x in image[x: x, y: y] } }
        return CellAnalyzer.analyze(pixels)
    }
}
