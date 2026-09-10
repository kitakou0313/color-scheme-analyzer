import Testing
import ColorAnalysis

/// ANA-03: sRGB 8bit 成分から HSB を計算する。期待値は blueprint 6.1 の表と手計算による。
struct HSBConversionTests {
    /// 1 ケース分の入力と期待値
    struct Case: Sendable {
        let rgb: RGB8
        let hue: Double?
        let saturation: Double
        let brightness: Double
    }

    static let cases: [Case] = [
        Case(rgb: RGB8(r: 255, g: 0, b: 0), hue: 0, saturation: 1, brightness: 1),
        Case(rgb: RGB8(r: 0, g: 255, b: 0), hue: 120, saturation: 1, brightness: 1),
        Case(rgb: RGB8(r: 0, g: 0, b: 255), hue: 240, saturation: 1, brightness: 1),
        Case(rgb: RGB8(r: 255, g: 255, b: 0), hue: 60, saturation: 1, brightness: 1),
        Case(rgb: RGB8(r: 0, g: 255, b: 255), hue: 180, saturation: 1, brightness: 1),
        Case(rgb: RGB8(r: 255, g: 0, b: 255), hue: 300, saturation: 1, brightness: 1),
        Case(rgb: RGB8(r: 128, g: 128, b: 255), hue: 240, saturation: 127.0 / 255.0, brightness: 1),
        Case(rgb: RGB8(r: 255, g: 0, b: 128), hue: 360 - 60 * 128.0 / 255.0, saturation: 1, brightness: 1),
        Case(rgb: RGB8(r: 187, g: 187, b: 187), hue: nil, saturation: 0, brightness: 187.0 / 255.0),
        Case(rgb: RGB8(r: 0, g: 0, b: 0), hue: nil, saturation: 0, brightness: 0),
        Case(rgb: RGB8(r: 255, g: 255, b: 255), hue: nil, saturation: 0, brightness: 1),
        Case(rgb: RGB8(r: 204, g: 153, b: 153), hue: 0, saturation: 0.25, brightness: 0.8),
    ]

    /// 各 RGB が期待どおりの H/S/B に変換される
    @Test(arguments: cases)
    func convertsRGBToHSB(_ c: Case) {
        let hsb = HSB(c.rgb)
        #expect(approximatelyEqual(hsb.hue, c.hue), "hue of \(c.rgb)")
        #expect(abs(hsb.saturation - c.saturation) < 1e-9, "saturation of \(c.rgb)")
        #expect(abs(hsb.brightness - c.brightness) < 1e-9, "brightness of \(c.rgb)")
    }

    /// 色相どうしを比較する。両方 nil なら等しい、片方だけ nil なら異なる
    private func approximatelyEqual(_ a: Double?, _ b: Double?) -> Bool {
        switch (a, b) {
        case (nil, nil): return true
        case let (x?, y?): return abs(x - y) < 1e-9
        default: return false
        }
    }
}
