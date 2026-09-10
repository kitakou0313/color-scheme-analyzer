import Testing
import ColorAnalysis

/// ANA-05〜ANA-08: セル内ピクセルから代表色相・平均 S/B・代表色を求める。期待値は blueprint 6.2 の手計算による。
struct CellAnalyzerTests {
    static let red = RGB8(r: 255, g: 0, b: 0)
    static let green = RGB8(r: 0, g: 255, b: 0)
    static let gray = RGB8(r: 187, g: 187, b: 187)
    static let blue = RGB8(r: 0, g: 0, b: 255)
    static let lightBlue = RGB8(r: 128, g: 128, b: 255)

    /// セル A: 赤 4 個 → 0°, S 1, B 1, (255,0,0)
    @Test func uniformRedCell() {
        let v = CellAnalyzer.analyze([Self.red, Self.red, Self.red, Self.red])
        expectHue(v.hue, 0)
        #expect(v.saturation == 1 && v.brightness == 1)
        #expect(v.color == Self.red)
    }

    /// セル B: 緑 3 + 赤 1 → 多数派の緑 120° が代表色相。平均色（約 100°）にはならない
    @Test func dominantHueWinsOverAverage() {
        let v = CellAnalyzer.analyze([Self.green, Self.green, Self.green, Self.red])
        expectHue(v.hue, 120)
        #expect(v.saturation == 1 && v.brightness == 1)
        #expect(v.color == Self.green)
    }

    /// セル C: グレー 3 + 赤 1 → グレーは除外され赤 0°。S 平均 0.25、B 平均 0.8、色 (204,153,153)
    @Test func grayPixelsAreExcludedFromHueHistogram() {
        let v = CellAnalyzer.analyze([Self.gray, Self.gray, Self.gray, Self.red])
        expectHue(v.hue, 0)
        #expect(abs(v.saturation - 0.25) < 1e-9)
        #expect(abs(v.brightness - 0.8) < 1e-9)
        #expect(v.color == RGB8(r: 204, g: 153, b: 153))
    }

    /// セル D: 青 2 + 淡い青 2 → 240°。S 平均 0.7490、B 1、色 (64,64,255)
    @Test func averagesSaturationAcrossAllPixels() {
        let v = CellAnalyzer.analyze([Self.blue, Self.lightBlue, Self.lightBlue, Self.blue])
        expectHue(v.hue, 240)
        #expect(abs(v.saturation - (2 + 2 * 127.0 / 255.0) / 4) < 1e-9)
        #expect(v.brightness == 1)
        #expect(v.color == RGB8(r: 64, g: 64, b: 255))
    }

    /// ANA-07: 有彩色ピクセルがないセルは色相 nil、色は平均 B のグレー
    @Test func achromaticCellHasNoHue() {
        let v = CellAnalyzer.analyze([Self.gray, Self.gray, RGB8(r: 51, g: 51, b: 51), RGB8(r: 51, g: 51, b: 51)])
        #expect(v.hue == nil)
        #expect(v.saturation == 0)
        #expect(abs(v.brightness - (187.0 + 51.0) / 255.0 / 2) < 1e-9)
        #expect(v.color == RGB8(r: 119, g: 119, b: 119))
    }

    /// S が 5% 未満のピクセルはヒストグラムに入らない（(128,128,133) は S≈0.038）
    @Test func nearGrayPixelsDoNotVote() {
        let nearGray = RGB8(r: 128, g: 128, b: 133)
        let v = CellAnalyzer.analyze([nearGray, nearGray, nearGray, Self.red])
        expectHue(v.hue, 0)
    }

    /// ANA-06: ピークが同値なら色相角の小さいビンを選ぶ（赤 2 + 緑 2 → 0°）
    @Test func tieBreaksTowardSmallerHue() {
        let v = CellAnalyzer.analyze([Self.green, Self.red, Self.green, Self.red])
        expectHue(v.hue, 0)
    }

    /// 0°/360° 境界をまたぐ色相は円周平均で 0° 付近にまとまる（358° と 2° → 0°）
    @Test func circularMeanAcrossZeroBoundary() {
        let h358 = RGB8(r: 255, g: 0, b: 8)   // hue ≈ 358.1
        let h2 = RGB8(r: 255, g: 8, b: 0)     // hue ≈ 1.9
        let v = CellAnalyzer.analyze([h358, h2])
        #expect(v.hue != nil && min(v.hue!, 360 - v.hue!) < 0.5)
    }

    /// 色相の一致を 1e-6 の許容で確かめる
    private func expectHue(_ actual: Double?, _ expected: Double) {
        #expect(actual != nil && abs(actual! - expected) < 1e-6, "hue \(String(describing: actual)) ≠ \(expected)")
    }
}
