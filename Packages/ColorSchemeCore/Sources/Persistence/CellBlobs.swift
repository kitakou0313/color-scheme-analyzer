import ColorAnalysis
import Foundation

/// セル配列と BLOB の相互変換（PER-04）。色は RGB8 × 3 バイト、数値は Float32 リトルエンディアン。
enum CellBlobs {
    /// 代表色の配列を RGB8 連結バイト列にする
    static func encodeColors(_ colors: [RGB8]) -> Data {
        Data(colors.flatMap { [$0.r, $0.g, $0.b] })
    }

    /// Float 配列を Float32 リトルエンディアンのバイト列にする
    static func encodeFloats(_ values: [Float]) -> Data {
        var data = Data(capacity: values.count * 4)
        for value in values {
            withUnsafeBytes(of: value.bitPattern.littleEndian) { data.append(contentsOf: $0) }
        }
        return data
    }

    /// RGB8 連結バイト列を代表色の配列に戻す
    static func decodeColors(_ data: Data) -> [RGB8] {
        let bytes = [UInt8](data)
        return stride(from: 0, to: bytes.count - bytes.count % 3, by: 3).map {
            RGB8(r: bytes[$0], g: bytes[$0 + 1], b: bytes[$0 + 2])
        }
    }

    /// Float32 リトルエンディアンのバイト列を Float 配列に戻す
    static func decodeFloats(_ data: Data) -> [Float] {
        let bytes = [UInt8](data)
        return stride(from: 0, to: bytes.count - bytes.count % 4, by: 4).map { i in
            let bits = UInt32(bytes[i]) | UInt32(bytes[i + 1]) << 8 | UInt32(bytes[i + 2]) << 16 | UInt32(bytes[i + 3]) << 24
            return Float(bitPattern: bits)
        }
    }
}
