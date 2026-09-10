/// 解析画像をセルに分割する規則（ANA-04）。長辺のセル数 N を基準に、短辺はアスペクト比を維持して決める。
public struct GridLayout: Hashable, Sendable {
    public let imageWidth: Int
    public let imageHeight: Int
    public let columns: Int
    public let rows: Int

    /// 画像サイズと長辺のセル数からグリッドを決める。長辺が N より小さいときは N を長辺 px に丸める。
    public init(imageWidth: Int, imageHeight: Int, longSideCells: Int) {
        self.imageWidth = imageWidth
        self.imageHeight = imageHeight
        let longSide = max(imageWidth, imageHeight), shortSide = min(imageWidth, imageHeight)
        let longCells = max(1, min(longSideCells, longSide))
        let shortCells = GridLayout.shortSideCells(longCells: longCells, longSide: longSide, shortSide: shortSide)
        (columns, rows) = imageWidth >= imageHeight ? (longCells, shortCells) : (shortCells, longCells)
    }

    /// 短辺のセル数 = max(1, round(N × 短辺 / 長辺))
    private static func shortSideCells(longCells: Int, longSide: Int, shortSide: Int) -> Int {
        let ratio = Double(shortSide) / Double(longSide)
        return max(1, Int((Double(longCells) * ratio).rounded()))
    }

    /// セル総数（columns × rows）
    public var cellCount: Int { columns * rows }

    /// 列 c が覆うピクセル範囲 [floor(c·W/columns), floor((c+1)·W/columns))
    public func columnRange(_ column: Int) -> Range<Int> {
        column * imageWidth / columns ..< (column + 1) * imageWidth / columns
    }

    /// 行 r が覆うピクセル範囲 [floor(r·H/rows), floor((r+1)·H/rows))
    public func rowRange(_ row: Int) -> Range<Int> {
        row * imageHeight / rows ..< (row + 1) * imageHeight / rows
    }

    /// 行優先のセル番号（左上が 0、右へ進み、次の行へ）
    public func cellIndex(row: Int, column: Int) -> Int {
        row * columns + column
    }
}
