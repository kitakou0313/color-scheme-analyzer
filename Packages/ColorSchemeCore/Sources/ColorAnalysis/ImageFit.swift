/// 表示領域にアスペクト比を保って収めた画像の配置と、画面座標とピクセル座標の相互変換（HUE-02）。
public struct ImageFit: Hashable, Sendable {
    /// 画面座標上の矩形
    public struct Rect: Hashable, Sendable {
        public let x: Double
        public let y: Double
        public let width: Double
        public let height: Double

        /// 各値を指定して生成する
        public init(x: Double, y: Double, width: Double, height: Double) {
            self.x = x
            self.y = y
            self.width = width
            self.height = height
        }
    }

    /// 画像のピクセル座標（左上が (0, 0)）
    public struct Pixel: Hashable, Sendable {
        public let x: Int
        public let y: Int

        /// 各値を指定して生成する
        public init(x: Int, y: Int) {
            self.x = x
            self.y = y
        }
    }

    /// 画面座標上の点
    public struct Point: Hashable, Sendable {
        public let x: Double
        public let y: Double
    }

    public let imageWidth: Int
    public let imageHeight: Int
    /// 画像が描かれる矩形（表示領域の座標系）
    public let frame: Rect
    /// 画像 1px あたりの画面上の長さ
    public let scale: Double

    /// 表示領域の中央にアスペクト比を保って収めたときの配置を求める
    public static func aspectFit(imageWidth: Int, imageHeight: Int, viewWidth: Double, viewHeight: Double) -> ImageFit {
        let scale = min(viewWidth / Double(imageWidth), viewHeight / Double(imageHeight))
        let width = Double(imageWidth) * scale, height = Double(imageHeight) * scale
        let frame = Rect(x: (viewWidth - width) / 2, y: (viewHeight - height) / 2, width: width, height: height)
        return ImageFit(imageWidth: imageWidth, imageHeight: imageHeight, frame: frame, scale: scale)
    }

    /// 画面座標に対応するピクセル。画像の外なら nil
    public func pixel(atViewX x: Double, viewY y: Double) -> Pixel? {
        let fx = (x - frame.x) / scale, fy = (y - frame.y) / scale
        guard fx >= 0, fy >= 0, fx < Double(imageWidth), fy < Double(imageHeight) else { return nil }
        return Pixel(x: Int(fx), y: Int(fy))
    }

    /// ピクセル中心の画面座標（マーカー表示用）
    public func viewPoint(ofPixel pixel: Pixel) -> Point {
        Point(x: frame.x + (Double(pixel.x) + 0.5) * scale, y: frame.y + (Double(pixel.y) + 0.5) * scale)
    }
}
