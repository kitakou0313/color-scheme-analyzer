/// sRGB 8bit の色。
public struct RGB8: Hashable, Sendable {
    public var r: UInt8
    public var g: UInt8
    public var b: UInt8

    /// 成分を指定して生成する
    public init(r: UInt8, g: UInt8, b: UInt8) {
        self.r = r
        self.g = g
        self.b = b
    }
}

/// HSB 色。hue は度 [0, 360)。無彩色（最大成分 = 最小成分）のとき hue は nil。
public struct HSB: Hashable, Sendable {
    public var hue: Double?
    public var saturation: Double
    public var brightness: Double

    /// 各成分を指定して生成する
    public init(hue: Double?, saturation: Double, brightness: Double) {
        self.hue = hue
        self.saturation = saturation
        self.brightness = brightness
    }
}

extension HSB {
    /// sRGB 8bit 成分から HSB を計算する（ANA-03）。B = max/255、S = (max-min)/max、max = 0 なら S = 0。
    public init(_ rgb: RGB8) {
        let r = Double(rgb.r) / 255, g = Double(rgb.g) / 255, b = Double(rgb.b) / 255
        let maxC = max(r, g, b), minC = min(r, g, b)
        let delta = maxC - minC
        self.brightness = maxC
        self.saturation = maxC == 0 ? 0 : delta / maxC
        self.hue = HSB.hueDegrees(r: r, g: g, b: b, maxC: maxC, delta: delta)
    }

    /// 最大成分がどれかに応じて色相角 [0, 360) を求める。delta が 0（無彩色）なら nil。
    private static func hueDegrees(r: Double, g: Double, b: Double, maxC: Double, delta: Double) -> Double? {
        guard delta > 0 else { return nil }
        let sector: Double
        if maxC == r { sector = ((g - b) / delta).truncatingRemainder(dividingBy: 6) }
        else if maxC == g { sector = (b - r) / delta + 2 }
        else { sector = (r - g) / delta + 4 }
        let degrees = sector * 60
        return degrees < 0 ? degrees + 360 : degrees
    }
}

extension RGB8 {
    /// HSB から sRGB 8bit に変換する（ANA-08）。各成分は 0–255 に四捨五入する。
    public init(_ hsb: HSB) {
        let (r, g, b) = RGB8.unitComponents(hsb)
        self.init(r: RGB8.byte(r), g: RGB8.byte(g), b: RGB8.byte(b))
    }

    /// 0–1 の成分を 255 倍して四捨五入し、UInt8 に収める
    private static func byte(_ value: Double) -> UInt8 {
        UInt8(clamping: Int((value * 255).rounded(.toNearestOrAwayFromZero)))
    }

    /// HSB を 0–1 の (R, G, B) に展開する。hue が nil なら明度のみのグレー
    private static func unitComponents(_ hsb: HSB) -> (Double, Double, Double) {
        guard let hue = hsb.hue else { return (hsb.brightness, hsb.brightness, hsb.brightness) }
        let chroma = hsb.brightness * hsb.saturation
        let sector = (hue / 60).truncatingRemainder(dividingBy: 6)
        let x = chroma * (1 - abs(sector.truncatingRemainder(dividingBy: 2) - 1))
        let m = hsb.brightness - chroma
        let (r, g, b) = sectorComponents(Int(sector), chroma: chroma, x: x)
        return (r + m, g + m, b + m)
    }

    /// 60° 区画ごとの (R, G, B) の並びを返す
    private static func sectorComponents(_ sector: Int, chroma c: Double, x: Double) -> (Double, Double, Double) {
        switch sector {
        case 0: return (c, x, 0)
        case 1: return (x, c, 0)
        case 2: return (0, c, x)
        case 3: return (0, x, c)
        case 4: return (x, 0, c)
        default: return (c, 0, x)
        }
    }
}
