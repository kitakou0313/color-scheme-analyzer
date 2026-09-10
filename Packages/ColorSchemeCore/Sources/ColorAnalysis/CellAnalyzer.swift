import Foundation

/// セル 1 個の解析結果（ANA-08）。saturation / brightness はセル内全ピクセルの平均。
public struct CellValue: Hashable, Sendable {
    public let hue: Double?
    public let saturation: Double
    public let brightness: Double

    /// 各値を指定して生成する
    public init(hue: Double?, saturation: Double, brightness: Double) {
        self.hue = hue
        self.saturation = saturation
        self.brightness = brightness
    }

    /// 代表色。hue が nil（無彩色セル）のときは S = 0 のグレー（ANA-07）
    public var color: RGB8 {
        RGB8(HSB(hue: hue, saturation: hue == nil ? 0 : saturation, brightness: brightness))
    }
}

/// 最頻色相法でセルを解析する（ANA-05〜ANA-08）。
public enum CellAnalyzer {
    /// これ未満の彩度のピクセルは色相投票に参加しない
    public static let chromaThreshold = 0.05
    static let binCount = 72
    static let binWidth = 5.0
    static let selectionHalfWidth = 15.0

    /// 色相投票 1 件（色相角と重み = 彩度）
    typealias Vote = (hue: Double, weight: Double)

    /// 集計途中の値
    private struct Accumulator {
        var sumS = 0.0
        var sumB = 0.0
        var count = 0
        var votes: [Vote] = []
    }

    /// ピクセル列から代表色相と平均 S/B を求める。空のセルは無彩色の黒として扱う
    public static func analyze(_ pixels: some Sequence<RGB8>) -> CellValue {
        var acc = Accumulator()
        for pixel in pixels { accumulate(HSB(pixel), into: &acc) }
        guard acc.count > 0 else { return CellValue(hue: nil, saturation: 0, brightness: 0) }
        let n = Double(acc.count)
        return CellValue(hue: dominantHue(acc.votes), saturation: acc.sumS / n, brightness: acc.sumB / n)
    }

    /// S/B を合計し、S ≥ 閾値の有彩色ピクセルだけを色相投票に加える
    private static func accumulate(_ hsb: HSB, into acc: inout Accumulator) {
        acc.sumS += hsb.saturation
        acc.sumB += hsb.brightness
        acc.count += 1
        if let hue = hsb.hue, hsb.saturation >= chromaThreshold { acc.votes.append((hue, hsb.saturation)) }
    }

    /// 色相ヒストグラムのピーク近傍（±15°）の円周平均を代表色相とする。投票がなければ nil
    static func dominantHue(_ votes: [Vote]) -> Double? {
        guard !votes.isEmpty else { return nil }
        let peak = peakIndex(of: smoothed(histogram(of: votes)))
        let center = (Double(peak) + 0.5) * binWidth
        return circularMean(of: votes.filter { circularDistance($0.hue, center) <= selectionHalfWidth })
    }

    /// 5° 刻み 72 ビンに重み（彩度）を積む
    private static func histogram(of votes: [Vote]) -> [Double] {
        var bins = [Double](repeating: 0, count: binCount)
        for vote in votes { bins[Int(vote.hue / binWidth) % binCount] += vote.weight }
        return bins
    }

    /// 隣接ビン（±1、循環）を足して平滑化する
    private static func smoothed(_ bins: [Double]) -> [Double] {
        bins.indices.map { i in bins[(i + binCount - 1) % binCount] + bins[i] + bins[(i + 1) % binCount] }
    }

    /// 最大値のビン番号。同値なら番号の小さい方（ANA-06）
    private static func peakIndex(of bins: [Double]) -> Int {
        var best = 0
        for i in bins.indices where bins[i] > bins[best] { best = i }
        return best
    }

    /// 2 つの色相角の円周上の距離（0–180）
    private static func circularDistance(_ a: Double, _ b: Double) -> Double {
        let d = abs(a - b).truncatingRemainder(dividingBy: 360)
        return min(d, 360 - d)
    }

    /// 重み付き円周平均 [0, 360)
    private static func circularMean(of votes: [Vote]) -> Double {
        var x = 0.0, y = 0.0
        for vote in votes {
            let radians = vote.hue * .pi / 180
            x += vote.weight * cos(radians)
            y += vote.weight * sin(radians)
        }
        let degrees = atan2(y, x) * 180 / .pi
        return degrees < 0 ? degrees + 360 : degrees
    }
}
