import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// テストと E2E フィクスチャ用の画像データを ImageIO で生成する。ピクセルは非乗算アルファの RGBA（sRGB）。
public enum TestImageFactory {
    /// RGBA 1 ピクセル
    public struct RGBA: Sendable {
        public let r: UInt8, g: UInt8, b: UInt8, a: UInt8

        /// 各成分を指定して生成する
        public init(r: UInt8, g: UInt8, b: UInt8, a: UInt8 = 255) {
            self.r = r
            self.g = g
            self.b = b
            self.a = a
        }
    }

    /// 指定サイズ・ピクセル列の画像を type 形式でエンコードする。orientation は EXIF/TIFF の向き（1–8）
    public static func encode(width: Int, height: Int, pixels: [RGBA], type: UTType, orientation: Int = 1) -> Data {
        let image = makeCGImage(width: width, height: height, pixels: pixels)
        let data = NSMutableData()
        let destination = CGImageDestinationCreateWithData(data, type.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, image, [kCGImagePropertyOrientation: orientation] as CFDictionary)
        precondition(CGImageDestinationFinalize(destination), "failed to encode test image")
        return data as Data
    }

    /// 単色で塗った画像を生成する
    public static func solid(width: Int, height: Int, color: RGBA, type: UTType) -> Data {
        encode(width: width, height: height, pixels: [RGBA](repeating: color, count: width * height), type: type)
    }

    /// blueprint 6.1 の 4×4 フィクスチャを PNG にする
    public static func sample4x4PNG() -> Data {
        let R = RGBA(r: 255, g: 0, b: 0), G = RGBA(r: 0, g: 255, b: 0), Y = RGBA(r: 187, g: 187, b: 187)
        let B = RGBA(r: 0, g: 0, b: 255), L = RGBA(r: 128, g: 128, b: 255)
        return encode(width: 4, height: 4, pixels: [R, R, G, G, R, R, G, R, Y, Y, B, L, Y, R, L, B], type: .png)
    }

    /// 非乗算 RGBA バイト列から CGImage を作る
    private static func makeCGImage(width: Int, height: Int, pixels: [RGBA]) -> CGImage {
        precondition(pixels.count == width * height)
        let bytes = pixels.flatMap { [$0.r, $0.g, $0.b, $0.a] }
        let provider = CGDataProvider(data: Data(bytes) as CFData)!
        let info = CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue | CGBitmapInfo.byteOrder32Big.rawValue)
        return CGImage(
            width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: info, provider: provider,
            decode: nil, shouldInterpolate: false, intent: .defaultIntent
        )!
    }
}
