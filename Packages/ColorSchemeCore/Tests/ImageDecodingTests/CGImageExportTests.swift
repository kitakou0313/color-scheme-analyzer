import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
import ColorAnalysis
import ImageDecoding

/// HUE-01, BAR-06: 解析画像（PixelImage）を表示用の CGImage にする。ピクセルは変えない。
struct CGImageExportTests {
    /// 2×1 の赤・青が同じサイズ・同じ色の CGImage になる（PNG を経由して読み戻す）
    @Test func roundTripsPixels() throws {
        let image = PixelImage(width: 2, height: 1, pixels: [RGB8(r: 255, g: 0, b: 0), RGB8(r: 0, g: 0, b: 255)])
        let cgImage = try #require(ImageDecoder.makeCGImage(image))
        #expect(cgImage.width == 2 && cgImage.height == 1)
        let decoded = try ImageDecoder.decode(try encodePNG(cgImage))
        #expect(decoded == image)
    }

    /// 4×4 フィクスチャの行順が保たれる（左下 (0,3) はグレー、(1,3) は赤）
    @Test func keepsRowOrder() throws {
        var pixels = [RGB8](repeating: RGB8(r: 187, g: 187, b: 187), count: 16)
        pixels[13] = RGB8(r: 255, g: 0, b: 0)
        let cgImage = try #require(ImageDecoder.makeCGImage(PixelImage(width: 4, height: 4, pixels: pixels)))
        let decoded = try ImageDecoder.decode(try encodePNG(cgImage))
        #expect(decoded[x: 1, y: 3] == RGB8(r: 255, g: 0, b: 0) && decoded[x: 0, y: 3] == RGB8(r: 187, g: 187, b: 187))
    }

    /// CGImage を PNG にエンコードする
    private func encodePNG(_ image: CGImage) throws -> Data {
        let data = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))
        return data as Data
    }
}
