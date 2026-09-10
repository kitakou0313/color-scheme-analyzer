import Testing
import ColorAnalysis

/// ANA-08: 代表色を HSB から sRGB 8bit に戻す（四捨五入）。期待値は blueprint 6.2 の手計算による。
struct RGBFromHSBTests {
    /// 1 ケース分の入力と期待値
    struct Case: Sendable {
        let hsb: HSB
        let rgb: RGB8
    }

    static let cases: [Case] = [
        Case(hsb: HSB(hue: 0, saturation: 1, brightness: 1), rgb: RGB8(r: 255, g: 0, b: 0)),
        Case(hsb: HSB(hue: 120, saturation: 1, brightness: 1), rgb: RGB8(r: 0, g: 255, b: 0)),
        Case(hsb: HSB(hue: 0, saturation: 0.25, brightness: 0.8), rgb: RGB8(r: 204, g: 153, b: 153)),
        Case(hsb: HSB(hue: 240, saturation: 0.7490196078, brightness: 1), rgb: RGB8(r: 64, g: 64, b: 255)),
        Case(hsb: HSB(hue: nil, saturation: 0, brightness: 187.0 / 255.0), rgb: RGB8(r: 187, g: 187, b: 187)),
        Case(hsb: HSB(hue: nil, saturation: 0, brightness: 0.5), rgb: RGB8(r: 128, g: 128, b: 128)),
        Case(hsb: HSB(hue: 60, saturation: 1, brightness: 1), rgb: RGB8(r: 255, g: 255, b: 0)),
        Case(hsb: HSB(hue: 300, saturation: 1, brightness: 1), rgb: RGB8(r: 255, g: 0, b: 255)),
        Case(hsb: HSB(hue: 360 - 60 * 128.0 / 255.0, saturation: 1, brightness: 1), rgb: RGB8(r: 255, g: 0, b: 128)),
        Case(hsb: HSB(hue: nil, saturation: 0, brightness: 0), rgb: RGB8(r: 0, g: 0, b: 0)),
    ]

    /// 各 HSB が期待どおりの RGB8 に変換される
    @Test(arguments: cases)
    func convertsHSBToRGB8(_ c: Case) {
        #expect(RGB8(c.hsb) == c.rgb)
    }
}
