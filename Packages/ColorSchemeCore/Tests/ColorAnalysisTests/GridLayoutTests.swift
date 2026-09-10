import Testing
import ColorAnalysis

/// ANA-04: 画像をセルに分割する規則。期待値は blueprint 4 章の式と手計算による。
struct GridLayoutTests {
    /// 4×4 画像を N=2 で分割すると 2×2 になる（blueprint 6.1）
    @Test func fourByFourWithTwoCells() {
        let grid = GridLayout(imageWidth: 4, imageHeight: 4, longSideCells: 2)
        #expect(grid.columns == 2)
        #expect(grid.rows == 2)
    }

    /// 横長 4000×3000 を N=64 で分割すると 64×48 になる
    @Test func landscapeKeepsAspectRatio() {
        let grid = GridLayout(imageWidth: 4000, imageHeight: 3000, longSideCells: 64)
        #expect(grid.columns == 64)
        #expect(grid.rows == 48)
    }

    /// 縦長 3000×4000 では長辺が高さになり 48×64 になる
    @Test func portraitKeepsAspectRatio() {
        let grid = GridLayout(imageWidth: 3000, imageHeight: 4000, longSideCells: 64)
        #expect(grid.columns == 48)
        #expect(grid.rows == 64)
    }

    /// 画像の長辺が N より小さいときは N を長辺 px に丸める（4×4, N=64 → 4×4）
    @Test func capsCellsToImageSize() {
        let grid = GridLayout(imageWidth: 4, imageHeight: 4, longSideCells: 64)
        #expect(grid.columns == 4)
        #expect(grid.rows == 4)
    }

    /// 極端に細長い画像でも短辺は最低 1 セル（1000×10, N=32 → 32×1 ではなく round(0.32)=0 → 1）
    @Test func shortSideIsAtLeastOneCell() {
        let grid = GridLayout(imageWidth: 1000, imageHeight: 10, longSideCells: 32)
        #expect(grid.columns == 32)
        #expect(grid.rows == 1)
    }

    /// 短辺のセル数は round(N × 短辺 / 長辺)（100×10, N=32 → round(3.2)=3）
    @Test func shortSideIsRounded() {
        let grid = GridLayout(imageWidth: 100, imageHeight: 10, longSideCells: 32)
        #expect(grid.columns == 32)
        #expect(grid.rows == 3)
    }

    /// セル i の範囲は [floor(i·W/gridW), floor((i+1)·W/gridW))（W=10, 3 列 → [0,3) [3,6) [6,10)）
    @Test func cellRangesPartitionWidthWithoutGapsOrOverlap() {
        let grid = GridLayout(imageWidth: 10, imageHeight: 3, longSideCells: 3)
        #expect(grid.columnRange(0) == 0..<3)
        #expect(grid.columnRange(1) == 3..<6)
        #expect(grid.columnRange(2) == 6..<10)
        #expect(grid.rowRange(0) == 0..<3)
    }

    /// セルは行優先で番号付けされる（2×2 の (row 1, col 0) は index 2）
    @Test func cellIndexIsRowMajor() {
        let grid = GridLayout(imageWidth: 4, imageHeight: 4, longSideCells: 2)
        #expect(grid.cellIndex(row: 1, column: 0) == 2)
        #expect(grid.cellCount == 4)
    }
}
