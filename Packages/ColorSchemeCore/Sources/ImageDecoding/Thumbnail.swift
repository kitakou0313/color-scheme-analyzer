import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

extension ImageDecoder {
    /// 長辺 maxPixelSize 以下の JPEG サムネイルを作る（PER-03）。向きを適用し、拡大はしない
    public static func thumbnailJPEG(from data: Data, maxPixelSize: Int, quality: Double) throws -> Data {
        let image = try orientedImage(from: try makeSource(data), maxPixelSize: maxPixelSize)
        return try encodeJPEG(image, quality: quality)
    }

    /// CGImage を指定品質の JPEG にエンコードする
    private static func encodeJPEG(_ image: CGImage, quality: Double) throws -> Data {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil) else {
            throw ImageDecodingError.decodingFailed
        }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw ImageDecodingError.decodingFailed }
        return data as Data
    }
}
