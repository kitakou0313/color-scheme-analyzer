import ColorAnalysis
import CoreGraphics
import Foundation

extension ImageDecoder {
    /// 解析画像を sRGB・不透明の CGImage にする（色相画面の表示、床テクスチャ、棒の色テクスチャに使う）
    public static func makeCGImage(_ image: PixelImage) -> CGImage? {
        guard let provider = CGDataProvider(data: rgbxData(image) as CFData) else { return nil }
        return CGImage(
            width: image.width, height: image.height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: image.width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent
        )
    }

    /// ピクセル列を RGBX（4 バイト/px）のバイト列に展開する
    private static func rgbxData(_ image: PixelImage) -> Data {
        var data = Data(count: image.pixels.count * 4)
        data.withUnsafeMutableBytes { (buffer: UnsafeMutableRawBufferPointer) in
            for (i, pixel) in image.pixels.enumerated() {
                buffer[i * 4] = pixel.r
                buffer[i * 4 + 1] = pixel.g
                buffer[i * 4 + 2] = pixel.b
                buffer[i * 4 + 3] = 255
            }
        }
        return data
    }
}
