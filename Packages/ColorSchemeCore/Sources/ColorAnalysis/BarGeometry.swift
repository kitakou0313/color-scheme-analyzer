/// 棒の高さに使う値の種類
public enum BarMetric: Hashable, Sendable {
    case saturation
    case brightness
}

/// 3D 棒グラフの形状データ（BAR-01〜BAR-04, BAR-11）。セル幅を 1 単位とし、+y を上、画像の上辺を −z、左辺を −x に置く。
public struct BarGeometry: Hashable, Sendable {
    /// 棒 1 本。(x, z) は底面中心、height は高さ、color は代表色
    public struct Bar: Hashable, Sendable {
        public let x: Float
        public let z: Float
        public let height: Float
        public let color: RGB8
    }

    public let columns: Int
    public let rows: Int
    public let bars: [Bar]
    /// 棒の断面の一辺（セル幅の 0.8）
    public let barWidth: Float = 0.8
    /// 値 1.0 に対応する高さ（長辺セル数 × 0.5）
    public let maxHeight: Float
    /// BAR-11: 最大値(100%)のサンプルとなる基準棒。グリッド奥の角からセル1個分離れた位置に置く
    public let referenceBar: Bar
    /// 値 0 でも保つ高さの比率（最大高さの 1%）
    public static let minimumHeightRatio: Float = 0.01

    /// 解析結果から棒を並べる。bars は行優先でセルと同じ順序
    public static func make(from result: AnalysisResult, metric: BarMetric) -> BarGeometry {
        let values = metric == .saturation ? result.saturations : result.brightnesses
        let colors = barColors(metric: metric, cellColors: result.colors, brightnesses: result.brightnesses)
        return make(grid: result.grid, values: values, colors: colors, metric: metric)
    }

    /// BAR-04: 棒の色を決める。彩度画面はセルの代表色、明度画面はセルの明度に連動した白〜黒のグレースケール
    /// （代表色の色相は使わない）。保存済みレコードから復元する側（BarChartView）とロジックを共有する。
    public static func barColors(metric: BarMetric, cellColors: [RGB8], brightnesses: [Float]) -> [RGB8] {
        switch metric {
        case .saturation: return cellColors
        case .brightness: return brightnesses.map { RGB8(HSB(hue: nil, saturation: 0, brightness: Double($0))) }
        }
    }

    /// グリッドと、セルごとの値（0–1）・代表色から棒を並べる（保存済みレコードからの復元にも使う）
    public static func make(grid: GridLayout, values: [Float], colors: [RGB8], metric: BarMetric) -> BarGeometry {
        precondition(values.count == grid.cellCount && colors.count == grid.cellCount, "values/colors must match grid")
        let maxHeight = Float(max(grid.columns, grid.rows)) * 0.5
        let bars = values.indices.map { index in
            bar(value: values[index], color: colors[index], at: index, grid: grid, maxHeight: maxHeight)
        }
        let reference = makeReferenceBar(grid: grid, maxHeight: maxHeight, metric: metric)
        return BarGeometry(columns: grid.columns, rows: grid.rows, bars: bars, maxHeight: maxHeight, referenceBar: reference)
    }

    /// セル番号から中心座標を求め、値を高さに変換して棒を作る
    private static func bar(value: Float, color: RGB8, at index: Int, grid: GridLayout, maxHeight: Float) -> Bar {
        let row = index / grid.columns, column = index % grid.columns
        let x = Float(column) - Float(grid.columns - 1) / 2
        let z = Float(row) - Float(grid.rows - 1) / 2
        let height = max(value, minimumHeightRatio) * maxHeight
        return Bar(x: x, z: z, height: height, color: color)
    }

    /// BAR-11: グリッド奥の角（行0・列0のセル中心）から対角線上にさらに1単位外側へ基準棒を置く。高さは常に maxHeight
    private static func makeReferenceBar(grid: GridLayout, maxHeight: Float, metric: BarMetric) -> Bar {
        let x = -Float(grid.columns - 1) / 2 - 1
        let z = -Float(grid.rows - 1) / 2 - 1
        return Bar(x: x, z: z, height: maxHeight, color: referenceColor(metric: metric))
    }

    /// BAR-11: 基準棒の色。彩度画面は純赤(HSB 0°,100%,100%)、明度画面は白（明度100%相当のグレースケール）
    private static func referenceColor(metric: BarMetric) -> RGB8 {
        switch metric {
        case .saturation: return RGB8(HSB(hue: 0, saturation: 1, brightness: 1))
        case .brightness: return RGB8(HSB(hue: nil, saturation: 0, brightness: 1))
        }
    }
}
