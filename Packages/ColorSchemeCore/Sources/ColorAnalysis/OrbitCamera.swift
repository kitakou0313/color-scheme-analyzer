import Foundation

/// 3D 棒グラフを眺めるカメラの状態（BAR-07）。床面の中心を注視点とし、方位・仰角・ズームで位置を決める。
public struct OrbitCamera: Hashable, Sendable {
    /// 3 次元ベクトル
    public struct Vector: Hashable, Sendable {
        public let x: Float
        public let y: Float
        public let z: Float

        /// 各成分を指定して生成する
        public init(x: Float, y: Float, z: Float) {
            self.x = x
            self.y = y
            self.z = z
        }
    }

    /// 方位（度）。0 で +z（手前）、増えると +x 側へ回る
    public var azimuth: Double
    /// 仰角（度）。0 で水平、90 で真上
    public var elevation: Double
    /// ズーム倍率。1 でグリッド全体が収まる距離
    public var zoom: Double

    /// 初期カメラ（方位 30°・仰角 45°・ズーム 1）
    public static let initial = OrbitCamera(azimuth: 30, elevation: 45, zoom: 1)
    /// ドラッグ 1pt あたりの回転角（度）
    public static let degreesPerPoint = 0.5
    public static let elevationRange = 5.0...89.9
    public static let zoomRange = 0.5...4.0

    /// 各値を指定して生成する
    public init(azimuth: Double, elevation: Double, zoom: Double) {
        self.azimuth = azimuth
        self.elevation = elevation
        self.zoom = zoom
    }

    /// ドラッグ量で回転する。右で方位が増え、上（dragY < 0）で仰角が増える
    public mutating func rotate(dragX: Double, dragY: Double) {
        let wrapped = (azimuth + dragX * OrbitCamera.degreesPerPoint).truncatingRemainder(dividingBy: 360)
        azimuth = wrapped < 0 ? wrapped + 360 : wrapped
        elevation = OrbitCamera.clamp(elevation - dragY * OrbitCamera.degreesPerPoint, to: OrbitCamera.elevationRange)
    }

    /// ピンチ倍率でズームする（0.5〜4 倍に収める）
    public mutating func zoom(by scale: Double) {
        zoom = OrbitCamera.clamp(zoom * scale, to: OrbitCamera.zoomRange)
    }

    /// 初期カメラに戻す
    public mutating func reset() {
        self = .initial
    }

    /// 真上からの俯瞰にする（ズームは保つ）
    public mutating func topDown() {
        azimuth = 0
        elevation = OrbitCamera.elevationRange.upperBound
    }

    /// 注視点（床面中心）から見たカメラ位置。距離は fitDistance / zoom
    public func position(fitDistance: Double) -> Vector {
        let distance = fitDistance / zoom
        let el = elevation * .pi / 180, az = azimuth * .pi / 180
        return Vector(x: Float(distance * cos(el) * sin(az)), y: Float(distance * sin(el)), z: Float(distance * cos(el) * cos(az)))
    }

    /// グリッド全体（幅・奥行き・最大高さ）を包む球が視野に収まる距離。
    /// fovDegrees は縦方向の視野角、aspectRatio は表示領域の幅 / 高さ。縦長の画面では横方向の視野角の方が狭いので、狭い方で決める
    public static func fitDistance(columns: Int, rows: Int, maxHeight: Float, fovDegrees: Double, aspectRatio: Double = 1) -> Double {
        let halfWidth = Double(columns) / 2, halfDepth = Double(rows) / 2, height = Double(maxHeight)
        let radius = (halfWidth * halfWidth + halfDepth * halfDepth + height * height).squareRoot()
        let halfVertical = fovDegrees / 2 * .pi / 180
        let halfHorizontal = atan(tan(halfVertical) * max(aspectRatio, 0.01))
        return radius / sin(min(halfVertical, halfHorizontal))
    }

    /// 値を範囲に収める
    private static func clamp(_ value: Double, to range: ClosedRange<Double>) -> Double {
        min(max(value, range.lowerBound), range.upperBound)
    }
}
