import ColorAnalysis
import CoreGraphics
import Foundation
import ImageIO

/// デコードの失敗理由
public enum ImageDecodingError: Error, Equatable, Sendable {
    /// 画像として認識できないデータ
    case unsupportedData
    /// 認識はできたが展開に失敗した
    case decodingFailed
}

/// ImageIO で画像を読み、EXIF 回転・長辺 4096px 上限・白合成・sRGB 統一を適用して PixelImage にする（ANA-01, ANA-02）。
public enum ImageDecoder {
    /// 解析画像の長辺の上限（px）
    public static let maxLongSide = 4096

    /// データをデコードして解析画像を作る
    public static func decode(_ data: Data) throws -> PixelImage {
        let source = try makeSource(data)
        return try rasterize(try orientedImage(from: source, maxPixelSize: maxLongSide))
    }

    /// ファイルを読んでデコードする
    public static func decode(contentsOf url: URL) throws -> PixelImage {
        try decode(Data(contentsOf: url))
    }

    /// データから画像ソースを開く。画像として認識できなければ unsupportedData
    static func makeSource(_ data: Data) throws -> CGImageSource {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil), CGImageSourceGetCount(source) > 0 else {
            throw ImageDecodingError.unsupportedData
        }
        return source
    }

    /// 向き（EXIF/TIFF Orientation）を適用し、長辺を maxPixelSize に収めた CGImage を取り出す（拡大はしない）
    static func orientedImage(from source: CGImageSource, maxPixelSize: Int) throws -> CGImage {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw ImageDecodingError.decodingFailed
        }
        return image
    }

    /// 白で塗った sRGB の RGBX ビットマップに描いて合成し、RGB8 の配列に読み出す
    private static func rasterize(_ image: CGImage) throws -> PixelImage {
        let width = image.width, height = image.height
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        try bytes.withUnsafeMutableBytes { buffer in
            let context = try makeContext(buffer.baseAddress!, width: width, height: height)
            context.setFillColor(gray: 1, alpha: 1)
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        return PixelImage(width: width, height: height, pixels: rgbPixels(from: bytes))
    }

    /// 与えたバッファを使う sRGB・8bit・RGBX（アルファなし）のビットマップコンテキストを作る
    private static func makeContext(_ pointer: UnsafeMutableRawPointer, width: Int, height: Int) throws -> CGContext {
        let context = CGContext(
            data: pointer, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        )
        guard let context else { throw ImageDecodingError.decodingFailed }
        return context
    }

    /// RGBX のバイト列（行優先、上の行が先頭）を RGB8 配列にする
    private static func rgbPixels(from bytes: [UInt8]) -> [RGB8] {
        stride(from: 0, to: bytes.count, by: 4).map { i in RGB8(r: bytes[i], g: bytes[i + 1], b: bytes[i + 2]) }
    }
}
