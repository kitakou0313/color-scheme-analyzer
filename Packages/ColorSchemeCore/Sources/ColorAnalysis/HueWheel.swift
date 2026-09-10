import Foundation

/// 色相画面の数値表示（HUE-07, HUE-08）。H は整数度 0–359、S/B は整数 %。
public struct HueReadout: Hashable, Sendable {
    /// これ未満の彩度は無彩色として扱い、色相を表示しない
    public static let achromaticThreshold = CellAnalyzer.chromaThreshold

    public let color: RGB8
    public let isAchromatic: Bool
    public let hueDegrees: Int?
    public let saturationPercent: Int
    public let brightnessPercent: Int

    /// 選択ピクセルの色から表示値を計算する
    public init(_ rgb: RGB8) {
        let hsb = HSB(rgb)
        color = rgb
        isAchromatic = hsb.hue == nil || hsb.saturation < HueReadout.achromaticThreshold
        hueDegrees = isAchromatic ? nil : hsb.hue.map { Int($0.rounded()) % 360 }
        saturationPercent = Int((hsb.saturation * 100).rounded())
        brightnessPercent = Int((hsb.brightness * 100).rounded())
    }
}

/// 色相環の幾何（HUE-05）。赤（0°）を真上に置き、時計回りに色相が増える。
public enum HueWheel {
    /// 画面座標上の点（中心原点、y 下向き）
    public struct Point: Hashable, Sendable {
        public let x: Double
        public let y: Double
    }

    /// 色相角を「真上 0・時計回り正」のラジアンにする
    public static func angle(forHue hue: Double) -> Double {
        hue * .pi / 180
    }

    /// 半径 radius の環上でのマーカー位置（中心原点、y 下向き）
    public static func markerPosition(hue: Double, radius: Double) -> Point {
        let a = angle(forHue: hue)
        return Point(x: radius * sin(a), y: -radius * cos(a))
    }
}
