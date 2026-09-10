/// 色相画面のズーム/パン状態（HUE-09）。表示は「anchor を中心に scale 倍し、offset だけ平行移動」とする。
public struct ViewTransform: Hashable, Sendable {
    public var scale: Double
    public var offsetX: Double
    public var offsetY: Double

    /// 等倍・移動なし
    public static let identity = ViewTransform(scale: 1, offsetX: 0, offsetY: 0)
    /// 縮小はせず、最大 8 倍まで
    public static let scaleRange = 1.0...8.0

    /// 各値を指定して生成する
    public init(scale: Double, offsetX: Double, offsetY: Double) {
        self.scale = scale
        self.offsetX = offsetX
        self.offsetY = offsetY
    }

    /// ピンチ倍率を掛ける（1〜8 倍に収める）
    public mutating func magnify(by factor: Double) {
        scale = min(max(scale * factor, ViewTransform.scaleRange.lowerBound), ViewTransform.scaleRange.upperBound)
    }

    /// 平行移動を加える
    public mutating func pan(dx: Double, dy: Double) {
        offsetX += dx
        offsetY += dy
    }

    /// 等倍・移動なしに戻す
    public mutating func reset() {
        self = .identity
    }

    /// 画面上の点を、変換前（等倍・移動なし）の座標に戻す
    public func unapply(x: Double, y: Double, anchorX: Double, anchorY: Double) -> (x: Double, y: Double) {
        ((x - offsetX - anchorX) / scale + anchorX, (y - offsetY - anchorY) / scale + anchorY)
    }

    /// 変換前の座標を、画面上の点にする（マーカー表示用。unapply の逆）
    public func apply(x: Double, y: Double, anchorX: Double, anchorY: Double) -> (x: Double, y: Double) {
        ((x - anchorX) * scale + anchorX + offsetX, (y - anchorY) * scale + anchorY + offsetY)
    }
}
