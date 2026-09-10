import Foundation
import Testing
import UniformTypeIdentifiers
import ColorAnalysis
import ImageDecoding
import TestSupport

/// ANA-01, ANA-02: ImageIO でデコードし、EXIF 回転・4096px 上限・白合成を適用して PixelImage にする。
struct ImageDecoderTests {
    typealias RGBA = TestImageFactory.RGBA

    /// 不透明な PNG はそのままの色で読める
    @Test func decodesOpaquePNG() throws {
        let data = TestImageFactory.encode(width: 2, height: 1, pixels: [
            RGBA(r: 255, g: 0, b: 0, a: 255), RGBA(r: 0, g: 0, b: 255, a: 255),
        ], type: .png)
        let image = try ImageDecoder.decode(data)
        #expect(image.width == 2 && image.height == 1)
        #expect(image.pixels == [RGB8(r: 255, g: 0, b: 0), RGB8(r: 0, g: 0, b: 255)])
    }

    /// ANA-02: 透過ピクセルは白と合成する（半透明の赤 → 桃色、全透明 → 白）
    @Test func compositesAlphaOverWhite() throws {
        let data = TestImageFactory.encode(width: 3, height: 1, pixels: [
            RGBA(r: 255, g: 0, b: 0, a: 128), RGBA(r: 0, g: 0, b: 0, a: 0), RGBA(r: 0, g: 255, b: 0, a: 255),
        ], type: .png)
        let image = try ImageDecoder.decode(data)
        expectClose(image.pixels[0], RGB8(r: 255, g: 127, b: 127), tolerance: 1)
        #expect(image.pixels[1] == RGB8(r: 255, g: 255, b: 255))
        #expect(image.pixels[2] == RGB8(r: 0, g: 255, b: 0))
    }

    /// ANA-01: 長辺が 4096px を超える画像は 4096px に縮小する（8192×16 → 4096×8）
    @Test func capsLongSideAt4096() throws {
        let data = TestImageFactory.solid(width: 8192, height: 16, color: RGBA(r: 10, g: 20, b: 30, a: 255), type: .png)
        let image = try ImageDecoder.decode(data)
        #expect(image.width == 4096 && image.height == 8)
        #expect(image.pixels[0] == RGB8(r: 10, g: 20, b: 30))
    }

    /// ANA-01: 4096px 以下の画像は縮小しない
    @Test func keepsSizeUpTo4096() throws {
        let data = TestImageFactory.solid(width: 4096, height: 2, color: RGBA(r: 1, g: 2, b: 3, a: 255), type: .png)
        let image = try ImageDecoder.decode(data)
        #expect(image.width == 4096 && image.height == 2)
    }

    /// ANA-01: EXIF/TIFF の向き 6（90° 時計回り）を適用する。横 2×1 [赤, 青] → 縦 1×2 [赤; 青]
    @Test func appliesOrientation() throws {
        let data = TestImageFactory.encode(width: 2, height: 1, pixels: [
            RGBA(r: 255, g: 0, b: 0, a: 255), RGBA(r: 0, g: 0, b: 255, a: 255),
        ], type: .tiff, orientation: 6)
        let image = try ImageDecoder.decode(data)
        #expect(image.width == 1 && image.height == 2)
        #expect(image[x: 0, y: 0] == RGB8(r: 255, g: 0, b: 0))
        #expect(image[x: 0, y: 1] == RGB8(r: 0, g: 0, b: 255))
    }

    /// IMP-06: 画像でないデータは unsupportedData を投げる
    @Test func rejectsNonImageData() {
        #expect(throws: ImageDecodingError.unsupportedData) {
            try ImageDecoder.decode(Data("not an image".utf8))
        }
    }

    /// 各成分が tolerance 以内で一致することを確かめる
    private func expectClose(_ a: RGB8, _ b: RGB8, tolerance: Int) {
        let close = abs(Int(a.r) - Int(b.r)) <= tolerance && abs(Int(a.g) - Int(b.g)) <= tolerance
            && abs(Int(a.b) - Int(b.b)) <= tolerance
        #expect(close, "\(a) ≠ \(b)")
    }
}
