/// 解析画像。sRGB 8bit・不透明の RGB ピクセルを行優先で持つ。
public struct PixelImage: Hashable, Sendable {
    public let width: Int
    public let height: Int
    public let pixels: [RGB8]

    /// サイズとピクセル列（width × height 個、行優先）から生成する
    public init(width: Int, height: Int, pixels: [RGB8]) {
        precondition(pixels.count == width * height, "pixel count must be width × height")
        self.width = width
        self.height = height
        self.pixels = pixels
    }

    /// 座標 (x, y) のピクセル。左上が (0, 0)
    public subscript(x x: Int, y y: Int) -> RGB8 {
        pixels[y * width + x]
    }

    /// 座標が画像内に収まっているか
    public func contains(x: Int, y: Int) -> Bool {
        x >= 0 && y >= 0 && x < width && y < height
    }
}
