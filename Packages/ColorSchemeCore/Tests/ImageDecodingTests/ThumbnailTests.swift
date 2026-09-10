import Foundation
import Testing
import UniformTypeIdentifiers
import ImageDecoding
import TestSupport

/// PER-03: 長辺 256px の JPEG サムネイルを作る。
struct ThumbnailTests {
    /// 400×200 の画像から 256×128 の JPEG ができる
    @Test func makesJPEGWithLongSide256() throws {
        let source = TestImageFactory.solid(width: 400, height: 200, color: .init(r: 200, g: 100, b: 50, a: 255), type: .png)
        let jpeg = try ImageDecoder.thumbnailJPEG(from: source, maxPixelSize: 256, quality: 0.8)
        #expect(jpeg.prefix(2) == Data([0xFF, 0xD8]), "JPEG SOI marker")
        let decoded = try ImageDecoder.decode(jpeg)
        #expect(decoded.width == 256 && decoded.height == 128)
    }

    /// 小さい画像は拡大しない（4×4 → 4×4）
    @Test func doesNotUpscale() throws {
        let source = TestImageFactory.solid(width: 4, height: 4, color: .init(r: 0, g: 0, b: 0, a: 255), type: .png)
        let decoded = try ImageDecoder.decode(try ImageDecoder.thumbnailJPEG(from: source, maxPixelSize: 256, quality: 0.8))
        #expect(decoded.width == 4 && decoded.height == 4)
    }

    /// 画像でないデータからは unsupportedData を投げる
    @Test func rejectsNonImageData() {
        #expect(throws: ImageDecodingError.unsupportedData) {
            try ImageDecoder.thumbnailJPEG(from: Data("nope".utf8), maxPixelSize: 256, quality: 0.8)
        }
    }
}
