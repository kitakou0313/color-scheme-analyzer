import Testing
import ColorAnalysis

/// HUE-05, HUE-07, HUE-08: 色相環上のマーカー位置と数値表示。期待値は blueprint 6.3 の表による。
struct HueWheelTests {
    /// HUE-05: 赤（0°）は真上、90° は右、180° は真下（y 下向きの画面座標、中心原点）
    @Test func markerGoesClockwiseFromTop() {
        expectPoint(HueWheel.markerPosition(hue: 0, radius: 10), x: 0, y: -10)
        expectPoint(HueWheel.markerPosition(hue: 90, radius: 10), x: 10, y: 0)
        expectPoint(HueWheel.markerPosition(hue: 180, radius: 10), x: 0, y: 10)
    }

    /// HUE-05: 240° は真上から時計回りに 240°（8 時の位置 = 左下）
    @Test func blueIsAtEightOClock() {
        let p = HueWheel.markerPosition(hue: 240, radius: 10)
        expectPoint(p, x: -10 * 0.8660254, y: 5)
    }

    /// HUE-07: 赤は H 0 / S 100 / B 100
    @Test func readoutForRed() {
        let r = HueReadout(RGB8(r: 255, g: 0, b: 0))
        #expect(r.hueDegrees == 0 && r.saturationPercent == 100 && r.brightnessPercent == 100)
        #expect(!r.isAchromatic)
    }

    /// HUE-07: (128,128,255) は H 240 / S 50 / B 100（49.8% は 50 に丸める）
    @Test func readoutRoundsPercentages() {
        let r = HueReadout(RGB8(r: 128, g: 128, b: 255))
        #expect(r.hueDegrees == 240 && r.saturationPercent == 50 && r.brightnessPercent == 100)
    }

    /// HUE-07: 色相は整数度に丸め、360 になる場合は 0 にする（(255,0,1) は 359.76° → 0）
    @Test func hueWrapsTo360AsZero() {
        let r = HueReadout(RGB8(r: 255, g: 0, b: 1))
        #expect(r.hueDegrees == 0)
    }

    /// HUE-07: 329.88° は 330 に丸める
    @Test func hueRoundsToNearestDegree() {
        #expect(HueReadout(RGB8(r: 255, g: 0, b: 128)).hueDegrees == 330)
    }

    /// HUE-08: グレー (187,187,187) は無彩色。H なし、S 0、B 73
    @Test func grayIsAchromatic() {
        let r = HueReadout(RGB8(r: 187, g: 187, b: 187))
        #expect(r.isAchromatic && r.hueDegrees == nil)
        #expect(r.saturationPercent == 0 && r.brightnessPercent == 73)
    }

    /// HUE-08: S が 5% 未満なら色相があっても無彩色扱い（(128,128,133) は S≈3.8%）
    @Test func lowSaturationIsAchromatic() {
        let r = HueReadout(RGB8(r: 128, g: 128, b: 133))
        #expect(r.isAchromatic && r.hueDegrees == nil)
        #expect(r.saturationPercent == 4)
    }

    /// 点の一致を 1e-6 の許容で確かめる
    private func expectPoint(_ p: HueWheel.Point, x: Double, y: Double) {
        #expect(abs(p.x - x) < 1e-6 && abs(p.y - y) < 1e-6, "\(p) ≠ (\(x), \(y))")
    }
}
